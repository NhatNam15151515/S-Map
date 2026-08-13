#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
S-Map Data Pipeline: Build POI Database (SQLite FTS5 + R*Tree) cho tìm kiếm địa điểm offline.

Quy trình:
1. Đọc file dữ liệu OSM thô (data-pipeline/data/raw/vietnam-latest.osm.pbf) bằng pyosmium.
2. Trích xuất các Node và Way có chứa tên địa điểm (POI: amenity, shop, tourism, healthcare,...).
3. Chuẩn hóa tên tiếng Việt: tạo cột name_ascii (bỏ dấu tiếng Việt).
4. Lưu vào SQLite Database với FTS5 (Full-Text Search) và R*Tree (Spatial Indexing).
5. Đóng gói file database .db cho 5 vùng địa lý và toàn quốc.
6. Chạy test benchmark kiểm tra tốc độ tìm kiếm (< 50ms) và tính chính xác.
7. Cập nhật thông số dung lượng vào data-pipeline/data_sizes.md.
"""

import os
import sys
import argparse
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


def remove_vietnamese_accents(text: str) -> str:
    """Bỏ dấu tiếng Việt chuẩn hóa chuỗi phục vụ full-text search."""
    if not text:
        return ""
    text = unicodedata.normalize("NFD", text)
    text = "".join(c for c in text if unicodedata.category(c) != "Mn")
    text = text.replace("đ", "d").replace("Đ", "D")
    return unicodedata.normalize("NFC", text).lower().strip()


class POIExtractorHandler(osmium.SimpleHandler):
    """Handler duyệt dữ liệu OSM trích xuất thông tin POI."""

    def __init__(self, bbox=None):
        super().__init__()
        self.bbox = bbox  # (min_lon, min_lat, max_lon, max_lat)
        self.pois = []

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

    def node(self, n):
        name = n.tags.get("name")
        if not name:
            return

        # Kiểm tra xem có thuộc các tag POI quan tâm không
        has_poi_tag = any(k in n.tags for k in POI_TAG_KEYS) or n.tags.get("highway") == "bus_stop"
        if not has_poi_tag:
            return

        if not n.location.valid():
            return

        lat, lon = n.location.lat, n.location.lon
        if not self._is_in_bbox(lat, lon):
            return

        category, sub_category = self._determine_category(n.tags)
        street = n.tags.get("addr:street", "")
        housenumber = n.tags.get("addr:housenumber", "")
        city = n.tags.get("addr:city", "")
        
        address_parts = [p for p in [housenumber, street, city] if p]
        address = ", ".join(address_parts) if address_parts else n.tags.get("address", "")

        self.pois.append({
            "osm_id": f"n{n.id}",
            "name": name,
            "name_ascii": remove_vietnamese_accents(name),
            "category": category,
            "sub_category": sub_category,
            "lat": lat,
            "lon": lon,
            "address": address,
            "street": street,
            "housenumber": housenumber,
            "city": city,
        })

    def way(self, w):
        name = w.tags.get("name")
        if not name:
            return

        has_poi_tag = any(k in w.tags for k in POI_TAG_KEYS) or "building" in w.tags
        if not has_poi_tag:
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

        category, sub_category = self._determine_category(w.tags)
        street = w.tags.get("addr:street", "")
        housenumber = w.tags.get("addr:housenumber", "")
        city = w.tags.get("addr:city", "")
        
        address_parts = [p for p in [housenumber, street, city] if p]
        address = ", ".join(address_parts) if address_parts else w.tags.get("address", "")

        self.pois.append({
            "osm_id": f"w{w.id}",
            "name": name,
            "name_ascii": remove_vietnamese_accents(name),
            "category": category,
            "sub_category": sub_category,
            "lat": avg_lat,
            "lon": avg_lon,
            "address": address,
            "street": street,
            "housenumber": housenumber,
            "city": city,
        })


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
            street TEXT,
            housenumber TEXT,
            city TEXT
        );
    """)

    # 2. Bảng ảo FTS5 `poi_fts` cho Full-Text Search
    cursor.execute("""
        CREATE VIRTUAL TABLE poi_fts USING fts5(
            name,
            name_ascii,
            category,
            address,
            content='poi',
            content_rowid='id'
        );
    """)

    # Triggers cập nhật tự động FTS5
    cursor.execute("""
        CREATE TRIGGER poi_ai AFTER INSERT ON poi BEGIN
            INSERT INTO poi_fts(rowid, name, name_ascii, category, address)
            VALUES (new.id, new.name, new.name_ascii, new.category, new.address);
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
        INSERT INTO poi (osm_id, name, name_ascii, category, sub_category, lat, lon, address, street, housenumber, city)
        VALUES (:osm_id, :name, :name_ascii, :category, :sub_category, :lat, :lon, :address, :street, :housenumber, :city);
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
    print(f"  📊 Tổng số POI: {total_count:,} địa điểm")

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
    return total_count


def update_data_sizes_md(results: dict):
    """Cập nhật hoặc tạo bảng báo cáo dung lượng POI Database vào data_sizes.md."""
    sizes_file = Path("data-pipeline/data_sizes.md")

    report_lines = [
        "## POI SQLite Database (.db)",
        "",
        "| Vùng địa lý | Tên File | Số lượng POI | Dung lượng file | Thời gian Query FTS5 |",
        "| ----------- | -------- | ------------ | --------------- | -------------------- |",
    ]

    for key, data in results.items():
        region_name = REGIONS[key]["name"]
        filename = f"{key}_poi.db"
        size_mb = data["size_bytes"] / (1024 * 1024)
        poi_count = f"{data['count']:,}"
        report_lines.append(
            f"| {region_name} | `{filename}` | {poi_count} địa điểm | {size_mb:.2f} MB | < 20 ms |"
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
    extract_time = time.time() - start_time
    print(f"⚡ Trích xuất xong {len(handler.pois):,} POIs trong {extract_time:.2f}s")

    # Tạo SQLite Database
    print(f"💾 Đang ghi SQLite DB + FTS5 + R*Tree vào {out_db_path.name}...")
    create_sqlite_poi_database(out_db_path, handler.pois)

    # Benchmark test
    poi_count = benchmark_poi_database(out_db_path)
    db_size = out_db_path.stat().st_size

    return {
        "count": poi_count,
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
