#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Offline unit tests for the Overture POI adapter and merge rules."""

import importlib.util
import sys
import unittest
from pathlib import Path


PIPELINE_DIR = Path(__file__).parent
sys.path.insert(0, str(PIPELINE_DIR))
MODULE_SPEC = importlib.util.spec_from_file_location(
    "build_poi_database", PIPELINE_DIR / "build_poi_database.py"
)
BUILD = importlib.util.module_from_spec(MODULE_SPEC)
MODULE_SPEC.loader.exec_module(BUILD)


class OverturePoiTests(unittest.TestCase):
    def test_load_geojsonseq_maps_and_filters_records(self):
        fixture_path = PIPELINE_DIR / "testdata" / "overture_places.geojsonseq"
        pois = list(
            BUILD.load_overture_places(
                fixture_path, bbox=(102.1, 8.5, 109.5, 23.4)
            )
        )

        self.assertEqual(len(pois), 2)
        cafe = next(poi for poi in pois if poi["osm_id"] == "overture:cafe-1")
        self.assertEqual(cafe["category"], "coffee")
        self.assertEqual(cafe["sub_category"], "cafe")
        self.assertEqual(cafe["street"], "Nguyễn Huệ")
        self.assertEqual(cafe["housenumber"], "12")
        self.assertIn("Hồ Chí Minh", cafe["admin_aliases"])

        legacy = next(
            poi for poi in pois if poi["osm_id"] == "overture:restaurant-legacy"
        )
        self.assertEqual(legacy["category"], "food")
        self.assertEqual(legacy["sub_category"], "restaurant")

    def test_merge_is_conditional_and_fills_missing_fields(self):
        osm = {
            "osm_id": "n1",
            "name": "Cafe Mẫu",
            "name_ascii": "cafe mau",
            "category": "amenity",
            "sub_category": "cafe",
            "lat": 10.776900,
            "lon": 106.700100,
            "address": "",
            "address_ascii": "",
            "street": "",
            "housenumber": "",
            "city": "",
            "admin_aliases": "",
            "_source": "osm",
            "_source_updated_at": "2026-08-01T00:00:00Z",
        }
        matching_overture = {
            "osm_id": "overture:cafe-1",
            "name": "Cà Phê Mẫu",
            "name_ascii": "ca phe mau",
            "category": "coffee",
            "sub_category": "cafe",
            "lat": 10.776905,
            "lon": 106.700105,
            "address": "12 Nguyễn Huệ, Hồ Chí Minh",
            "address_ascii": "12 nguyen hue, ho chi minh",
            "street": "Nguyễn Huệ",
            "housenumber": "12",
            "city": "Hồ Chí Minh",
            "admin_aliases": "Hồ Chí Minh",
            "_source": "overture",
            "_source_updated_at": "2026-08-20T00:00:00Z",
            "_confidence": 0.9,
        }
        unrelated_name = dict(matching_overture)
        unrelated_name.update(
            {
                "osm_id": "overture:other",
                "name": "Quán Bên Cạnh",
                "name_ascii": "quan ben canh",
                "lat": 10.77691,
                "lon": 106.70011,
            }
        )

        merged, stats = BUILD.merge_overture_pois(
            [osm], [matching_overture, unrelated_name]
        )

        self.assertEqual(stats["overture_merged"], 1)
        self.assertEqual(stats["overture_added"], 1)
        self.assertEqual(len(merged), 2)
        self.assertEqual(merged[0]["housenumber"], "12")
        self.assertEqual(merged[0]["street"], "Nguyễn Huệ")

    def test_sqlite_insert_strips_internal_merge_metadata(self):
        poi = {
            "osm_id": "overture:test",
            "name": "Điểm test",
            "name_ascii": "diem test",
            "category": "shop",
            "sub_category": "test",
            "lat": 10.0,
            "lon": 106.0,
            "address": "",
            "address_ascii": "",
            "street": "",
            "housenumber": "",
            "city": "",
            "admin_aliases": "",
            "_source": "overture",
            "_source_updated_at": "2026-08-20T00:00:00Z",
            "_confidence": 0.8,
        }
        db_path = PIPELINE_DIR / ".test_overture_poi.db"
        for suffix in ("", "-wal", "-shm"):
            candidate = Path(str(db_path) + suffix)
            if candidate.exists():
                candidate.unlink()
        BUILD.create_sqlite_poi_database(db_path, [poi])
        import sqlite3

        connection = sqlite3.connect(db_path)
        try:
            columns = {
                row[1] for row in connection.execute("PRAGMA table_info(poi)")
            }
            row = connection.execute(
                "SELECT osm_id, name FROM poi"
            ).fetchone()
        finally:
            connection.close()

        for suffix in ("", "-wal", "-shm"):
            candidate = Path(str(db_path) + suffix)
            if candidate.exists():
                candidate.unlink()

        self.assertNotIn("_source", columns)
        self.assertEqual(row, ("overture:test", "Điểm test"))


if __name__ == "__main__":
    unittest.main()
