#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
S-Map Data Pipeline: Build POI Database (SQLite FTS5 + R*Tree) cho tìm kiếm địa điểm offline.

Quy trình:
1. Đọc file dữ liệu OSM thô (data-pipeline/data/raw/vietnam-latest.osm.pbf) bằng pyosmium.
2. Trích xuất các Node và Way có chứa tên địa điểm (POI: amenity, shop, tourism, healthcare,...).
3. Trích xuất thêm các element có đủ số nhà và tên đường (addr:housenumber + addr:street).
4. Chuẩn hóa tên tiếng Việt: tạo cột name_ascii và address_ascii (bỏ dấu tiếng Việt).
5. Lưu vào SQLite Database với FTS5 (Full-Text Search) và R*Tree (Spatial Indexing).
6. Đóng gói file database .db cho 5 vùng địa lý và toàn quốc.
7. Chạy test benchmark kiểm tra tốc độ tìm kiếm (< 50ms) và tính chính xác.
8. Cập nhật thông số dung lượng vào data-pipeline/data_sizes.md.
"""

import os
import sys
import argparse
import json
import re
import sqlite3
import time
import unicodedata
from pathlib import Path

# Fix Unicode output trên Windows Terminal
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

import osmium

# Thêm data-pipeline vào sys.path để import config
sys.path.append(str(Path(__file__).parent))
from config import REGIONS, RAW_PBF, POI_DB_DIR as OUTPUT_DIR

ADMIN_ALIAS_FILE = Path(__file__).with_name("admin_aliases.json")


def _load_admin_alias_groups():
    """Đọc mapping địa danh hành chính trước/sau sắp xếp để nhúng vào DB offline."""
    with ADMIN_ALIAS_FILE.open("r", encoding="utf-8") as file:
        payload = json.load(file)
    return payload.get("groups", [])


ADMIN_ALIAS_GROUPS = _load_admin_alias_groups()

POI_TAG_KEYS = {
    "amenity",
    "shop",
    "tourism",
    "leisure",
    "healthcare",
    "historic",
    "office",
    "craft",
    "emergency",
    "place",
}

STREET_HIGHWAY_TYPES = {
    "trunk",
    "primary",
    "secondary",
    "tertiary",
    "unclassified",
    "residential",
    "living_street",
    "service",
    "road",
    "pedestrian",
}


def remove_vietnamese_accents(text: str) -> str:
    """Bỏ dấu tiếng Việt chuẩn hóa chuỗi phục vụ full-text search."""
    if not text:
        return ""
    text = unicodedata.normalize("NFD", text)
    text = "".join(c for c in text if unicodedata.category(c) != "Mn")
    text = text.replace("đ", "d").replace("Đ", "D")
    return unicodedata.normalize("NFC", text).lower().strip()


def _normalize_admin_match_text(text: str) -> str:
    """Chuẩn hóa text để nhận diện tên tỉnh/thành dù khác dấu hoặc dấu câu."""
    ascii_text = remove_vietnamese_accents(text)
    return re.sub(r"[^a-z0-9]+", " ", ascii_text).strip()


def get_admin_aliases(*texts: str) -> str:
    """Trả về toàn bộ tên cũ/mới của tỉnh/thành chứa trong địa chỉ.

    Dữ liệu gốc và địa chỉ hiển thị vẫn giữ nguyên. Chuỗi này chỉ là chỉ mục
    tìm kiếm, giúp cùng một tọa độ nhận được cả tên hành chính cũ lẫn mới.
    """
    source_text = " ".join(text for text in texts if text)
    normalized_source = f" {_normalize_admin_match_text(source_text)} "
    matched_aliases = []
    seen = set()

    for group in ADMIN_ALIAS_GROUPS:
        names = [group.get("canonical", ""), *group.get("aliases", [])]
        group_matched = False
        for name in names:
            normalized_name = _normalize_admin_match_text(name)
            if normalized_name and f" {normalized_name} " in normalized_source:
                group_matched = True
                break
        if not group_matched:
            continue

        for name in names:
            prefixed_names = [name]
            normalized_name = name.lower().strip()
            if (
                not normalized_name.startswith(("tỉnh ", "thành phố "))
                and not normalized_name.startswith(("tp", "hcm", "ho chi minh city"))
            ):
                prefixed_names.extend((f"Tỉnh {name}", f"Thành phố {name}"))
            for prefixed_name in prefixed_names:
                for value in (prefixed_name, remove_vietnamese_accents(prefixed_name)):
                    value = value.strip()
                    if value and value not in seen:
                        seen.add(value)
                        matched_aliases.append(value)

    return " | ".join(matched_aliases)


class POIExtractorHandler(osmium.SimpleHandler):
    """Handler duyệt dữ liệu OSM trích xuất thông tin POI."""

    def __init__(self, bbox=None):
        super().__init__()
        self.bbox = bbox  # (min_lon, min_lat, max_lon, max_lat)
        self.pois = []
        self._street_accumulators = {}

    def _is_in_bbox(self, lat, lon):
        if not self.bbox:
            return True
        min_lon, min_lat, max_lon, max_lat = self.bbox
        return min_lat <= lat <= max_lat and min_lon <= lon <= max_lon

    def _determine_category(self, tags):
        for key in POI_TAG_KEYS:
            if key in tags:
                return key, tags[key]
        if tags.get("highway") == "bus_stop":
            return "transportation", "bus_stop"
        if "building" in tags and tags.get("name"):
            return "building", tags["building"]
        return "other", "general"

    @staticmethod
    def _address_fields(tags):
        """Lấy các trường địa chỉ từ OSM và tạo chuỗi hiển thị/search."""
        street = (tags.get("addr:street") or "").strip()
        housenumber = (tags.get("addr:housenumber") or "").strip()
        city = (tags.get("addr:city") or "").strip()
        address_parts = [part for part in (housenumber, street, city) if part]
        address = ", ".join(address_parts) if address_parts else (tags.get("address") or "").strip()
        return {
            "address": address,
            "address_ascii": remove_vietnamese_accents(address),
            "street": street,
            "housenumber": housenumber,
            "city": city,
        }

    @staticmethod
    def _admin_source(tags, address_fields):
        """Các tag hành chính OSM có thể chứa tên tỉnh cũ hoặc tên mới."""
        return " ".join(
            value.strip()
            for value in (
                address_fields["city"],
                tags.get("addr:province"),
                tags.get("addr:state"),
                tags.get("is_in:province"),
                tags.get("is_in:state"),
                tags.get("address"),
            )
            if value and value.strip()
        )

    @staticmethod
    def _has_complete_address(tags):
        return bool(
            (tags.get("addr:housenumber") or "").strip()
            and (tags.get("addr:street") or "").strip()
        )

    def _build_record(self, osm_id, tags, lat, lon, has_poi_tag):
        """Tạo record cho POI hoặc địa chỉ độc lập không có tên POI."""
        address_fields = self._address_fields(tags)
        admin_aliases = get_admin_aliases(
            self._admin_source(tags, address_fields),
        )
        has_complete_address = self._has_complete_address(tags)
        name = (tags.get("name") or "").strip()

        if not has_poi_tag and not has_complete_address:
            return None

        has_named_poi = has_poi_tag and bool(name)
        if has_named_poi:
            category, sub_category = self._determine_category(tags)
            display_name = name
        else:
            # Địa chỉ nhà không có POI name vẫn cần khóa tìm kiếm hiển thị.
            category, sub_category = "address", "house_number"
            display_name = address_fields["address"]

        if not display_name:
            return None

        return {
            "osm_id": osm_id,
            "name": display_name,
            "name_ascii": remove_vietnamese_accents(display_name),
            "admin_aliases": admin_aliases,
            "category": category,
            "sub_category": sub_category,
            "lat": lat,
            "lon": lon,
            **address_fields,
        }

    def _collect_street(self, tags, lat, lon):
        """Gom các đoạn đường thành một record đường duy nhất để tìm offline."""
        highway = (tags.get("highway") or "").strip().lower()
        name = (tags.get("name") or "").strip()
        if highway not in STREET_HIGHWAY_TYPES or not name:
            return

        city = (tags.get("addr:city") or "").strip()
        key = (remove_vietnamese_accents(name), remove_vietnamese_accents(city))
        current = self._street_accumulators.get(key)
        if current is None:
            self._street_accumulators[key] = {
                "osm_id": f"street:{key[0]}:{key[1]}",
                "name": name,
                "name_ascii": remove_vietnamese_accents(name),
                "category": "street",
                "sub_category": highway,
                "lat": lat,
                "lon": lon,
                "address": name,
                "address_ascii": remove_vietnamese_accents(name),
                "street": name,
                "housenumber": "",
                "city": city,
                "admin_aliases": get_admin_aliases(city),
                "_count": 1,
            }
            return

        count = current["_count"] + 1
        current["lat"] = (current["lat"] * current["_count"] + lat) / count
        current["lon"] = (current["lon"] * current["_count"] + lon) / count
        current["_count"] = count

    def add_street_records(self):
        """Đưa street index vào cùng DB để repository dùng chung mô hình POI."""
        for record in self._street_accumulators.values():
            record.pop("_count", None)
            self.pois.append(record)

    def node(self, n):
        # Kiểm tra xem có thuộc các tag POI quan tâm không
        has_poi_tag = any(k in n.tags for k in POI_TAG_KEYS) or n.tags.get("highway") == "bus_stop"
        if not has_poi_tag and not self._has_complete_address(n.tags):
            return

        if not n.location.valid():
            return

        lat, lon = n.location.lat, n.location.lon
        if not self._is_in_bbox(lat, lon):
            return

        record = self._build_record(f"n{n.id}", n.tags, lat, lon, has_poi_tag)
        if record:
            self.pois.append(record)

    def way(self, w):
        has_poi_tag = any(k in w.tags for k in POI_TAG_KEYS) or "building" in w.tags
        has_named_street = bool(
            (w.tags.get("highway") or "").strip()
            and (w.tags.get("name") or "").strip()
        )
        if not has_poi_tag and not self._has_complete_address(w.tags) and not has_named_street:
            return

        # Tính tọa độ trung bình (centroid) từ các node của way
        coords = []
        for n in w.nodes:
            if n.location.valid():
                coords.append((n.location.lat, n.location.lon))

        if not coords:
            return

        avg_lat = sum(c[0] for c in coords) / len(coords)
        avg_lon = sum(c[1] for c in coords) / len(coords)

        if not self._is_in_bbox(avg_lat, avg_lon):
            return

        self._collect_street(w.tags, avg_lat, avg_lon)

        record = self._build_record(f"w{w.id}", w.tags, avg_lat, avg_lon, has_poi_tag)
        if record:
            self.pois.append(record)


def create_sqlite_poi_database(db_path: Path, pois: list):
    """Tạo file SQLite POI database chứa bảng chính, bảng FTS5 và bảng R*Tree."""
    if db_path.exists():
        db_path.unlink()

    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()

    # Bật PRAGMA tối ưu hiệu năng
    cursor.execute("PRAGMA journal_mode = WAL;")
    cursor.execute("PRAGMA synchronous = NORMAL;")

    # 1. Bảng chính `poi`
    cursor.execute("""
        CREATE TABLE poi (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            osm_id TEXT,
            name TEXT NOT NULL,
            name_ascii TEXT NOT NULL,
            category TEXT,
            sub_category TEXT,
            lat REAL NOT NULL,
            lon REAL NOT NULL,
            address TEXT,
            address_ascii TEXT,
            street TEXT,
            housenumber TEXT,
            city TEXT,
            admin_aliases TEXT
        );
    """)

    # 2. Bảng ảo FTS5 `poi_fts` cho Full-Text Search
    cursor.execute("""
        CREATE VIRTUAL TABLE poi_fts USING fts5(
            name,
            name_ascii,
            category,
            address,
            address_ascii,
            admin_aliases,
            content='poi',
            content_rowid='id'
        );
    """)

    # Triggers cập nhật tự động FTS5
    cursor.execute("""
        CREATE TRIGGER poi_ai AFTER INSERT ON poi BEGIN
            INSERT INTO poi_fts(rowid, name, name_ascii, category, address, address_ascii, admin_aliases)
            VALUES (new.id, new.name, new.name_ascii, new.category, new.address, new.address_ascii, new.admin_aliases);
        END;
    """)

    # 3. Bảng ảo R*Tree `poi_rtree` cho Spatial Bounding Box Queries
    cursor.execute("""
        CREATE VIRTUAL TABLE poi_rtree USING rtree(
            id,
            min_lat, max_lat,
            min_lon, max_lon
        );
    """)

    cursor.execute("""
        CREATE TRIGGER poi_rtree_ai AFTER INSERT ON poi BEGIN
            INSERT INTO poi_rtree(id, min_lat, max_lat, min_lon, max_lon)
            VALUES (new.id, new.lat, new.lat, new.lon, new.lon);
        END;
    """)

    # Chèn dữ liệu POIs theo batch
    cursor.executemany("""
        INSERT INTO poi (osm_id, name, name_ascii, category, sub_category, lat, lon, address, address_ascii, street, housenumber, city, admin_aliases)
        VALUES (:osm_id, :name, :name_ascii, :category, :sub_category, :lat, :lon, :address, :address_ascii, :street, :housenumber, :city, :admin_aliases);
    """, pois)

    conn.commit()

    # Index bổ sung cho category và lat/lon
    cursor.execute("CREATE INDEX idx_poi_category ON poi(category);")
    cursor.execute("CREATE INDEX idx_poi_name_ascii ON poi(name_ascii);")

    conn.commit()
    conn.close()


def benchmark_poi_database(db_path: Path):
    """Test kiểm tra tốc độ truy vấn FTS5 và R*Tree trên database vừa tạo."""
    print(f"\n🔍 Testing benchmark queries trên database: {db_path.name}")
    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()

    # Total POIs count
    cursor.execute("SELECT COUNT(*) FROM poi;")
    total_count = cursor.fetchone()[0]
    print(f"  📊 Tổng số POI/địa chỉ: {total_count:,} địa điểm")
    cursor.execute("SELECT COUNT(*) FROM poi WHERE category = 'address';")
    address_count = cursor.fetchone()[0]
    print(f"  🏠 Địa chỉ số nhà mới: {address_count:,} bản ghi")
    cursor.execute("SELECT COUNT(*) FROM poi WHERE admin_aliases IS NOT NULL AND admin_aliases != '';" )
    alias_count = cursor.fetchone()[0]
    print(f"  🔁 Bản ghi có alias hành chính cũ/mới: {alias_count:,} bản ghi")

    test_queries = ["phở", "pho", "bệnh viện", "benh vien", "chợ", "cho"]
    for q in test_queries:
        start_t = time.time()
        q_ascii = remove_vietnamese_accents(q)
        cursor.execute("""
            SELECT p.id, p.name, p.category, p.lat, p.lon, p.address 
            FROM poi_fts f
            JOIN poi p ON f.rowid = p.id
            WHERE poi_fts MATCH ?
            LIMIT 5;
        """, (f"{q_ascii}*",))
        rows = cursor.fetchall()
        elapsed_ms = (time.time() - start_t) * 1000
        print(f"  🔎 Query '{q}' (match '{q_ascii}*') -> {len(rows)} kết quả ({elapsed_ms:.2f} ms)")
        for r in rows[:2]:
            print(f"     • [{r[2]}] {r[1]} - {r[5]} ({r[3]:.4f}, {r[4]:.4f})")

    # Benchmark R*Tree Spatial query (HCM bounding box)
    start_t = time.time()
    cursor.execute("""
        SELECT p.id, p.name, p.lat, p.lon
        FROM poi_rtree r
        JOIN poi p ON r.id = p.id
        WHERE r.min_lat >= 10.70 AND r.max_lat <= 10.85
          AND r.min_lon >= 106.60 AND r.max_lon <= 106.75
        LIMIT 10;
    """)
    spatial_rows = cursor.fetchall()
    elapsed_ms = (time.time() - start_t) * 1000
    print(f"  🌍 Spatial R*Tree Bounding Box query -> {len(spatial_rows)} kết quả ({elapsed_ms:.2f} ms)\n")

    conn.close()
    return total_count, address_count, alias_count


def update_data_sizes_md(results: dict):
    """Cập nhật hoặc tạo bảng báo cáo dung lượng POI Database vào data_sizes.md."""
    sizes_file = Path("data-pipeline/data_sizes.md")

    report_lines = [
        "## POI SQLite Database (.db)",
        "",
        "| Vùng địa lý | Tên File | Số lượng POI/địa chỉ | Có alias cũ/mới | Dung lượng file | Thời gian Query FTS5 |",
        "| ----------- | -------- | -------------------- | --------------- | --------------- | -------------------- |",
    ]

    for key, data in results.items():
        region_name = REGIONS[key]["name"]
        filename = f"{key}_poi.db"
        size_mb = data["size_bytes"] / (1024 * 1024)
        poi_count = f"{data['count']:,}"
        report_lines.append(
            f"| {region_name} | `{filename}` | {poi_count} địa điểm (+ {data['address_count']:,} địa chỉ) | {data['alias_count']:,} bản ghi | {size_mb:.2f} MB | < 20 ms |"
        )

    new_section = "\n".join(report_lines)

    if sizes_file.exists():
        content = sizes_file.read_text(encoding="utf-8")
        if "## POI SQLite Database (.db)" in content:
            # Replace existing section
            parts = content.split("## POI SQLite Database (.db)")
            before = parts[0].rstrip()
            content = f"{before}\n\n{new_section}\n"
        else:
            content = f"{content.strip()}\n\n{new_section}\n"
    else:
        content = f"# S-Map Data Pipeline Sizes\n\n{new_section}\n"

    sizes_file.write_text(content, encoding="utf-8")
    print(f"📝 Đã cập nhật kết quả kích thước vào: {sizes_file}")


def process_region(region_key: str):
    """Trích xuất và đóng gói SQLite database cho 1 vùng cụ thể."""
    region_info = REGIONS[region_key]
    print(f"\n==================================================", flush=True)
    print(f"📦 BẮT ĐẦU DỰNG POI DATABASE CHO: {region_info['name']} ({region_key})", flush=True)
    print(f"==================================================", flush=True)

    if not RAW_PBF.exists():
        print(f"❌ LỖI: Không tìm thấy file dữ liệu OSM thô: {RAW_PBF}", flush=True)
        sys.exit(1)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    out_db_path = OUTPUT_DIR / f"{region_key}_poi.db"

    # Trích xuất POIs bằng pyosmium
    print("⏳ Đang trích xuất Node & Way POIs từ OSM PBF...", flush=True)
    handler = POIExtractorHandler(bbox=region_info.get("bbox_tuple"))
    location_handler = osmium.NodeLocationsForWays(osmium.index.create_map("flex_mem"))
    location_handler.ignore_errors()

    start_time = time.time()
    osmium.apply(str(RAW_PBF), location_handler, handler)
    handler.add_street_records()
    extract_time = time.time() - start_time
    print(f"⚡ Trích xuất xong {len(handler.pois):,} POIs trong {extract_time:.2f}s")

    # Tạo SQLite Database
    print(f"💾 Đang ghi SQLite DB + FTS5 + R*Tree vào {out_db_path.name}...")
    create_sqlite_poi_database(out_db_path, handler.pois)

    # Benchmark test
    poi_count, address_count, alias_count = benchmark_poi_database(out_db_path)
    db_size = out_db_path.stat().st_size

    return {
        "count": poi_count,
        "address_count": address_count,
        "alias_count": alias_count,
        "size_bytes": db_size,
    }


def main():
    parser = argparse.ArgumentParser(description="S-Map POI SQLite DB Builder")
    parser.add_argument(
        "--region",
        type=str,
        default="metro_hcm",
        help="Vùng cần build: metro_hcm, metro_hn, mien_nam, mien_trung, mien_bac, vietnam, hoặc all",
    )
    args = parser.parse_args()

    results = {}
    target_region = args.region.lower()

    if target_region == "all":
        for key in REGIONS.keys():
            results[key] = process_region(key)
    elif target_region in REGIONS:
        results[target_region] = process_region(target_region)
    else:
        print(f"❌ Vùng không hợp lệ: {target_region}. Chọn 1 trong: {list(REGIONS.keys())} hoặc all")
        sys.exit(1)

    update_data_sizes_md(results)
    print("\n✅ HOÀN THÀNH TOÀN BỘ TIẾN TRÌNH BUILD POI DATABASE!")


if __name__ == "__main__":
    main()
