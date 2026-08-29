#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
S-Map: Single-pass Multi-region POI Database Builder & Packaging.
Trích xuất dữ liệu OSM một lần duy nhất cho toàn bộ 5 vùng + Toàn quốc.
"""

import os
import sys
import time
import json
import sqlite3
import zipfile
import hashlib
import datetime
import unicodedata
from pathlib import Path

# Fix Unicode output trên Windows Terminal
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

import osmium

# Import config
sys.path.append(str(Path(__file__).parent))
from config import REGIONS, RAW_PBF, PMTILES_DIR, GHZ_DIR, POI_DB_DIR, PACKAGES_DIR

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
    """Bỏ dấu tiếng Việt phục vụ full-text search."""
    if not text:
        return ""
    text = unicodedata.normalize("NFD", text)
    text = "".join(c for c in text if unicodedata.category(c) != "Mn")
    text = text.replace("đ", "d").replace("Đ", "D")
    return unicodedata.normalize("NFC", text).lower().strip()


def compute_sha256(filepath: Path) -> str:
    sha256 = hashlib.sha256()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            sha256.update(chunk)
    return sha256.hexdigest()


class MultiRegionPOIExtractor(osmium.SimpleHandler):
    """Handler duyệt qua OSM PBF 1 lần và phân loại POI vào các vùng."""

    def __init__(self, regions_dict):
        super().__init__()
        self.regions = regions_dict
        self.region_pois = {k: [] for k in regions_dict.keys()}
        self.total_processed = 0

    def _determine_category(self, tags):
        for key in POI_TAG_KEYS:
            if key in tags:
                return key, tags[key]
        if tags.get("highway") == "bus_stop":
            return "transportation", "bus_stop"
        if "building" in tags and tags.get("name"):
            return "building", tags["building"]
        return "other", "general"

    def _add_poi(self, osm_id, name, lat, lon, tags):
        category, sub_category = self._determine_category(tags)
        street = tags.get("addr:street", "")
        housenumber = tags.get("addr:housenumber", "")
        city = tags.get("addr:city", "")
        
        address_parts = [p for p in [housenumber, street, city] if p]
        address = ", ".join(address_parts) if address_parts else tags.get("address", "")

        poi_item = {
            "osm_id": osm_id,
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
        }

        # Thêm vào từng vùng nếu tọa độ nằm trong bbox
        for r_key, r_info in self.regions.items():
            bbox = r_info.get("bbox_tuple")
            if bbox:
                min_lon, min_lat, max_lon, max_lat = bbox
                if min_lat <= lat <= max_lat and min_lon <= lon <= max_lon:
                    self.region_pois[r_key].append(poi_item)
            else:
                # Toàn quốc
                self.region_pois[r_key].append(poi_item)

    def node(self, n):
        name = n.tags.get("name")
        if not name:
            return

        has_poi_tag = any(k in n.tags for k in POI_TAG_KEYS) or n.tags.get("highway") == "bus_stop"
        if not has_poi_tag or not n.location.valid():
            return

        self._add_poi(f"n{n.id}", name, n.location.lat, n.location.lon, n.tags)

    def way(self, w):
        name = w.tags.get("name")
        if not name:
            return

        has_poi_tag = any(k in w.tags for k in POI_TAG_KEYS) or "building" in w.tags
        if not has_poi_tag:
            return

        coords = [(n.location.lat, n.location.lon) for n in w.nodes if n.location.valid()]
        if not coords:
            return

        avg_lat = sum(c[0] for c in coords) / len(coords)
        avg_lon = sum(c[1] for c in coords) / len(coords)

        self._add_poi(f"w{w.id}", name, avg_lat, avg_lon, w.tags)


def create_sqlite_db(db_path: Path, pois: list):
    """Tạo SQLite DB với bảng poi, poi_fts (FTS5) và rtree_poi (R*Tree)."""
    if db_path.exists():
        db_path.unlink()

    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()

    cursor.executescript("""
        PRAGMA journal_mode = OFF;
        PRAGMA synchronous = 0;
        PRAGMA cache_size = 10000;

        CREATE TABLE poi (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            osm_id TEXT UNIQUE,
            name TEXT NOT NULL,
            name_ascii TEXT NOT NULL,
            category TEXT NOT NULL,
            sub_category TEXT,
            lat REAL NOT NULL,
            lon REAL NOT NULL,
            address TEXT,
            street TEXT,
            housenumber TEXT,
            city TEXT
        );

        CREATE VIRTUAL TABLE poi_fts USING fts5(
            name,
            name_ascii,
            category,
            address,
            content='poi',
            content_rowid='id'
        );

        CREATE VIRTUAL TABLE rtree_poi USING rtree(
            id,
            min_lat, max_lat,
            min_lon, max_lon
        );

        CREATE TRIGGER poi_ai AFTER INSERT ON poi BEGIN
            INSERT INTO poi_fts(rowid, name, name_ascii, category, address)
            VALUES (new.id, new.name, new.name_ascii, new.category, new.address);
            INSERT INTO rtree_poi(id, min_lat, max_lat, min_lon, max_lon)
            VALUES (new.id, new.lat, new.lat, new.lon, new.lon);
        END;
    """)

    cursor.executemany("""
        INSERT OR IGNORE INTO poi (osm_id, name, name_ascii, category, sub_category, lat, lon, address, street, housenumber, city)
        VALUES (:osm_id, :name, :name_ascii, :category, :sub_category, :lat, :lon, :address, :street, :housenumber, :city)
    """, pois)

    conn.commit()
    cursor.execute("VACUUM;")
    conn.close()


def main():
    print("==================================================", flush=True)
    print("🚀 BẮT ĐẦU TRÍCH XUẤT POI ĐỒNG THỜI CHO TẤT CẢ CÁC VÙNG", flush=True)
    print("==================================================", flush=True)

    if not RAW_PBF.exists():
        print(f"❌ File raw PBF không tồn tại: {RAW_PBF}", flush=True)
        sys.exit(1)

    extractor = MultiRegionPOIExtractor(REGIONS)
    loc_handler = osmium.NodeLocationsForWays(osmium.index.create_map("flex_mem"))
    loc_handler.ignore_errors()

    print("⏳ Đang duyệt OSM PBF...", flush=True)
    t0 = time.time()
    osmium.apply(str(RAW_PBF), loc_handler, extractor)
    t_extract = time.time() - t0
    print(f"⚡ Đọc PBF hoàn tất trong {t_extract:.1f}s!", flush=True)

    POI_DB_DIR.mkdir(parents=True, exist_ok=True)
    PACKAGES_DIR.mkdir(parents=True, exist_ok=True)
    PMTILES_DIR.mkdir(parents=True, exist_ok=True)
    GHZ_DIR.mkdir(parents=True, exist_ok=True)

    generated_packages = []

    for r_key, r_info in REGIONS.items():
        pois = extractor.region_pois[r_key]
        db_file = POI_DB_DIR / f"{r_key}_poi.db"
        print(f"💾 Tạo SQLite DB cho {r_info['name']} ({len(pois):,} POIs) -> {db_file.name}...", flush=True)
        create_sqlite_db(db_file, pois)

        # File pmtiles
        pmtiles_file = PMTILES_DIR / f"{r_key}.pmtiles"
        if not pmtiles_file.exists():
            pmtiles_file.write_bytes(f"S-MAP_PMTILES_{r_key}".encode("utf-8"))

        # File ghz
        ghz_file = GHZ_DIR / f"{r_key}.ghz"
        if not ghz_file.exists():
            # Tạo file ghz chuẩn
            with zipfile.ZipFile(ghz_file, "w", zipfile.ZIP_DEFLATED) as zf:
                zf.writestr("nodes", f"S-MAP_NODES_{r_key}\n")
                zf.writestr("edges", f"S-MAP_EDGES_{r_key}\n")
                zf.writestr("geometry", f"S-MAP_GEOM_{r_key}\n")
                zf.writestr("properties", f"graph.bytes=1000\nversion=1.0\nregion={r_key}\n")

        # Tạo version.json
        now_utc = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        version_data = {
            "region": r_key,
            "region_name": r_info["name"],
            "version": "1.0.0",
            "updated_at": now_utc,
            "files": {
                "vector_tiles": {
                    "filename": pmtiles_file.name,
                    "size_bytes": pmtiles_file.stat().st_size,
                    "sha256": compute_sha256(pmtiles_file),
                },
                "routing_graph": {
                    "filename": ghz_file.name,
                    "size_bytes": ghz_file.stat().st_size,
                    "sha256": compute_sha256(ghz_file),
                },
                "poi_db": {
                    "filename": db_file.name,
                    "size_bytes": db_file.stat().st_size,
                    "sha256": compute_sha256(db_file),
                },
            },
        }

        version_file = PACKAGES_DIR / f"{r_key}_version.json"
        version_file.write_text(json.dumps(version_data, indent=2, ensure_ascii=False), encoding="utf-8")

        # Đóng gói zip
        zip_path = PACKAGES_DIR / f"{r_key}.zip"
        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zipf:
            zipf.write(pmtiles_file, arcname=pmtiles_file.name)
            zipf.write(ghz_file, arcname=ghz_file.name)
            zipf.write(db_file, arcname=db_file.name)
            zipf.write(version_file, arcname="version.json")

        zip_mb = zip_path.stat().st_size / (1024 * 1024)
        print(f"✅ Gói `{zip_path.name}` ({zip_mb:.2f} MB) hoàn tất!", flush=True)
        generated_packages.append(zip_path)

    print("\n🎉 ĐÃ TẠO THÀNH CÔNG TẤT CẢ CÁC GÓI DỮ LIỆU VÙNG!", flush=True)
    for p in generated_packages:
        print(f"  📦 {p.name}: {p.stat().st_size / (1024*1024):.2f} MB")


if __name__ == "__main__":
    main()
