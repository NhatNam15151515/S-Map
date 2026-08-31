#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Ước lượng độ phủ và dung lượng dataset địa chỉ offline từ OSM PBF.

Script này chỉ đọc file PBF, không tạo hoặc thay đổi database. Nó đếm các
element có đủ ``addr:housenumber`` và ``addr:street`` để pipeline có thể
định vị một địa chỉ cụ thể thay vì chỉ tìm POI có sẵn.
"""

import argparse
import sys
import unicodedata
from pathlib import Path

import osmium

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

sys.path.append(str(Path(__file__).resolve().parents[1]))
from config import RAW_PBF, REGIONS


def normalize(text: str) -> str:
    if not text:
        return ""
    text = unicodedata.normalize("NFD", text)
    text = "".join(c for c in text if unicodedata.category(c) != "Mn")
    return text.replace("đ", "d").replace("Đ", "D").lower().strip()


class AddressEstimator(osmium.SimpleHandler):
    def __init__(self, bbox=None):
        super().__init__()
        self.bbox = bbox
        self.counts = {
            "nodes": 0,
            "ways": 0,
            "with_any_address_tag": 0,
            "with_house_and_street": 0,
            "with_house_and_street_named": 0,
            "with_house_and_street_poi": 0,
            "new_address_candidates": 0,
            "nguyen_suy": 0,
            "nguyen_suy_house_142": 0,
        }
        self.samples = []

    def _is_in_bbox(self, lat, lon):
        if not self.bbox:
            return True
        min_lon, min_lat, max_lon, max_lat = self.bbox
        return min_lat <= lat <= max_lat and min_lon <= lon <= max_lon

    def _inspect(self, tags, lat, lon, kind):
        if not self._is_in_bbox(lat, lon):
            return

        self.counts[kind + "s"] += 1
        housenumber = (tags.get("addr:housenumber") or "").strip()
        street = (tags.get("addr:street") or "").strip()
        name = (tags.get("name") or "").strip()
        has_any = any((tags.get(key) or "").strip() for key in (
            "addr:housenumber", "addr:street", "addr:city", "addr:postcode", "addr:place"
        ))
        if has_any:
            self.counts["with_any_address_tag"] += 1
        if not housenumber or not street:
            return

        self.counts["with_house_and_street"] += 1
        if name:
            self.counts["with_house_and_street_named"] += 1

        has_poi_tag = any(key in tags for key in {
            "amenity", "shop", "tourism", "leisure", "healthcare", "historic",
            "office", "craft", "emergency", "place",
        }) or tags.get("highway") == "bus_stop" or "building" in tags
        if has_poi_tag:
            self.counts["with_house_and_street_poi"] += 1
        else:
            self.counts["new_address_candidates"] += 1

        street_ascii = normalize(street)
        if "nguyen suy" in street_ascii or "nguyen suy" in normalize(tags.get("addr:place", "")):
            self.counts["nguyen_suy"] += 1
            if normalize(housenumber).split()[0] == "142":
                self.counts["nguyen_suy_house_142"] += 1
            if len(self.samples) < 5:
                self.samples.append({
                    "kind": kind,
                    "housenumber": housenumber,
                    "street": street,
                    "city": tags.get("addr:city", ""),
                    "name": name,
                })

    def node(self, node):
        if node.location.valid():
            self._inspect(node.tags, node.location.lat, node.location.lon, "node")

    def way(self, way):
        coords = [
            (node.location.lat, node.location.lon)
            for node in way.nodes
            if node.location.valid()
        ]
        if coords:
            lat = sum(coord[0] for coord in coords) / len(coords)
            lon = sum(coord[1] for coord in coords) / len(coords)
            self._inspect(way.tags, lat, lon, "way")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--region", choices=[*REGIONS.keys(), "all"], default="all")
    parser.add_argument("--pbf", type=Path, default=RAW_PBF)
    args = parser.parse_args()

    regions = REGIONS if args.region == "all" else {args.region: REGIONS[args.region]}
    for key, region in regions.items():
        print(f"\n[{key}] {region['name']}")
        estimator = AddressEstimator(region.get("bbox_tuple"))
        locations = osmium.NodeLocationsForWays(osmium.index.create_map("flex_mem"))
        locations.ignore_errors()
        osmium.apply(str(args.pbf), locations, estimator)
        for metric, value in estimator.counts.items():
            print(f"  {metric}: {value:,}")
        if estimator.samples:
            print("  samples:")
            for sample in estimator.samples:
                print(f"    {sample}")


if __name__ == "__main__":
    main()
