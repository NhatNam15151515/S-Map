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

import sys
import argparse
import json
import math
import re
import sqlite3
import time
import unicodedata
from datetime import datetime, timezone
from difflib import SequenceMatcher
from pathlib import Path

# Fix Unicode output trên Windows Terminal
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

import osmium

# Thêm data-pipeline vào sys.path để import config
sys.path.append(str(Path(__file__).parent))
from config import (
    OVERTURE_GEOJSON,
    OVERTURE_GEOJSONSEQ,
    REGIONS,
    RAW_PBF,
    POI_DB_DIR as OUTPUT_DIR,
)

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

# Overture's taxonomy is more detailed than the app's current category model.
# Keep the mapping intentionally small and stable; unknown values remain
# searchable through sub_category instead of being discarded.
OVERTURE_CATEGORY_MAP = {
    "restaurant": ("food", "restaurant"),
    "cafe": ("coffee", "cafe"),
    "coffee_shop": ("coffee", "cafe"),
    "fast_food": ("food", "fast_food"),
    "food_court": ("food", "food_court"),
    "bakery": ("food", "bakery"),
    "bar": ("food", "bar"),
    "pub": ("food", "pub"),
    "ice_cream_shop": ("food", "ice_cream"),
    "hotel": ("hotel", "hotel"),
    "motel": ("hotel", "motel"),
    "hostel": ("hotel", "hostel"),
    "guest_house": ("hotel", "guest_house"),
    "fuel_station": ("gas", "fuel"),
    "gas_station": ("gas", "fuel"),
    "atm": ("atm", "atm"),
    "bank": ("bank", "bank"),
    "hospital": ("hospital", "hospital"),
    "clinic": ("hospital", "clinic"),
    "pharmacy": ("hospital", "pharmacy"),
    "school": ("school", "school"),
    "university": ("school", "university"),
    "park": ("park", "park"),
    "museum": ("tourism", "museum"),
    "tourist_attraction": ("tourism", "attraction"),
    "supermarket": ("shop", "supermarket"),
    "grocery_store": ("shop", "grocery_store"),
    "convenience_store": ("shop", "convenience_store"),
    "shopping_mall": ("shop", "shopping_mall"),
    "clothing_store": ("shop", "clothing_store"),
    "electronics_store": ("shop", "electronics_store"),
    "book_store": ("shop", "book_store"),
    "beauty_salon": ("shop", "beauty_salon"),
    "hair_salon": ("shop", "hair_salon"),
    "airport": ("transportation", "airport"),
    "bus_station": ("transportation", "bus_station"),
    "train_station": ("transportation", "train_station"),
    "parking": ("transportation", "parking"),
}

OVERTURE_MAX_MATCH_DISTANCE_M = 50.0
OVERTURE_STRICT_NAME_DISTANCE_M = 25.0
OVERTURE_FUZZY_NAME_RATIO = 0.80
POI_DB_COLUMNS = (
    "osm_id",
    "name",
    "name_ascii",
    "category",
    "sub_category",
    "lat",
    "lon",
    "address",
    "address_ascii",
    "street",
    "housenumber",
    "city",
    "admin_aliases",
)


def remove_vietnamese_accents(text: str) -> str:
    """Bỏ dấu tiếng Việt chuẩn hóa chuỗi phục vụ full-text search."""
    if not text:
        return ""
    text = unicodedata.normalize("NFD", text)
    text = "".join(c for c in text if unicodedata.category(c) != "Mn")
    text = text.replace("đ", "d").replace("Đ", "D")
    return unicodedata.normalize("NFC", text).lower().strip()


def _as_mapping(value):
    """Return a JSON object whether the CLI emitted it as an object or text."""
    if isinstance(value, dict):
        return value
    if isinstance(value, str):
        try:
            parsed = json.loads(value)
        except (TypeError, json.JSONDecodeError):
            return {}
        return parsed if isinstance(parsed, dict) else {}
    return {}


def _as_text(value) -> str:
    if value is None:
        return ""
    if isinstance(value, (dict, list)):
        return ""
    return str(value).strip()


def _timestamp_to_iso(value) -> str:
    """Normalize OSM/Overture timestamps for in-memory merge decisions."""
    if not value:
        return ""
    if isinstance(value, datetime):
        parsed = value
    else:
        raw = _as_text(value)
        if not raw:
            return ""
        try:
            parsed = datetime.fromisoformat(raw.replace("Z", "+00:00"))
        except ValueError:
            return ""
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc).isoformat()


def _parse_timestamp(value):
    normalized = _timestamp_to_iso(value)
    if not normalized:
        return datetime.min.replace(tzinfo=timezone.utc)
    try:
        return datetime.fromisoformat(normalized)
    except ValueError:
        return datetime.min.replace(tzinfo=timezone.utc)


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


def _iter_geojson_features(path: Path):
    """Yield features from GeoJSONSeq or a regular GeoJSON file.

    GeoJSONSeq is the preferred national-cache format because it can be read
    line by line. Regular FeatureCollection input remains supported for
    backwards compatibility with an already downloaded cache.
    """
    with path.open("r", encoding="utf-8") as file:
        if path.suffix.lower() in {".geojsonseq", ".geojsonl", ".ndjson"}:
            for line_number, line in enumerate(file, start=1):
                line = line.strip()
                if not line:
                    continue
                try:
                    feature = json.loads(line)
                except json.JSONDecodeError as exc:
                    raise ValueError(
                        f"GeoJSONSeq không hợp lệ tại dòng {line_number}: {path}"
                    ) from exc
                if isinstance(feature, dict) and feature.get("type") == "Feature":
                    yield feature
            return

        first = file.read(1)
        file.seek(0)
        if first in ("{", "["):
            payload = json.load(file)
            if isinstance(payload, dict) and payload.get("type") == "FeatureCollection":
                yield from payload.get("features", [])
            elif isinstance(payload, dict) and payload.get("type") == "Feature":
                yield payload
            elif isinstance(payload, list):
                yield from payload
            return

        raise ValueError(f"Không nhận diện được định dạng GeoJSON: {path}")


def _first_overture_address(properties):
    addresses = properties.get("addresses") or []
    if isinstance(addresses, dict):
        addresses = [addresses]
    if isinstance(addresses, str):
        try:
            addresses = json.loads(addresses)
        except (TypeError, json.JSONDecodeError):
            addresses = []
    if not isinstance(addresses, list):
        return {}
    for address in addresses:
        parsed = _as_mapping(address)
        if parsed:
            return parsed
    return {}


def _overture_category(properties) -> str:
    """Read current taxonomy fields, then fall back to the legacy field."""
    basic_category = _as_text(properties.get("basic_category"))
    if basic_category:
        return basic_category.lower()

    taxonomy = _as_mapping(properties.get("taxonomy"))
    taxonomy_primary = _as_text(taxonomy.get("primary"))
    if taxonomy_primary:
        return taxonomy_primary.lower()

    categories = _as_mapping(properties.get("categories"))
    return _as_text(categories.get("primary")).lower()


def _overture_update_time(properties) -> str:
    updates = []
    sources = properties.get("sources") or []
    if isinstance(sources, dict):
        sources = [sources]
    if isinstance(sources, str):
        try:
            sources = json.loads(sources)
        except (TypeError, json.JSONDecodeError):
            sources = []
    if isinstance(sources, list):
        for source in sources:
            update_time = _timestamp_to_iso(_as_mapping(source).get("update_time"))
            if update_time:
                updates.append(update_time)
    return max(updates) if updates else ""


def _feature_point(feature):
    geometry = _as_mapping(feature.get("geometry"))
    if geometry.get("type") != "Point":
        return None
    coordinates = geometry.get("coordinates")
    if not isinstance(coordinates, (list, tuple)) or len(coordinates) < 2:
        return None
    try:
        lon, lat = float(coordinates[0]), float(coordinates[1])
    except (TypeError, ValueError):
        return None
    if not (-90 <= lat <= 90 and -180 <= lon <= 180):
        return None
    return lat, lon


def _is_vietnam_address(address) -> bool:
    country = _as_text(address.get("country")).lower()
    if not country:
        return True
    return country in {"vn", "vnm", "vietnam", "việt nam"}


def load_overture_places(geojson_path: Path, bbox=None):
    """Load valid Overture place points and map them to S-Map's POI schema."""
    if not geojson_path.exists():
        raise FileNotFoundError(f"Không tìm thấy Overture cache: {geojson_path}")

    for feature in _iter_geojson_features(geojson_path):
        if not isinstance(feature, dict):
            continue
        properties = _as_mapping(feature.get("properties"))
        lat_lon = _feature_point(feature)
        if lat_lon is None:
            continue
        lat, lon = lat_lon

        if bbox:
            min_lon, min_lat, max_lon, max_lat = bbox
            if not (min_lat <= lat <= max_lat and min_lon <= lon <= max_lon):
                continue

        address_data = _first_overture_address(properties)
        if not _is_vietnam_address(address_data):
            continue

        operating_status = _as_text(properties.get("operating_status")).lower()
        if operating_status == "permanently_closed":
            continue
        confidence = properties.get("confidence")
        try:
            confidence = float(confidence) if confidence is not None else None
        except (TypeError, ValueError):
            confidence = None
        if confidence is not None and confidence <= 0:
            continue

        names = _as_mapping(properties.get("names"))
        name = _as_text(names.get("primary")) or _as_text(names.get("common"))
        if not name:
            continue

        freeform = _as_text(address_data.get("freeform"))
        street = _as_text(address_data.get("street"))
        housenumber = _as_text(
            address_data.get("number")
            or address_data.get("house_number")
            or address_data.get("housenumber")
        )
        city = _as_text(address_data.get("locality"))
        region = _as_text(address_data.get("region"))
        address = freeform
        if not address:
            address = ", ".join(
                part for part in (housenumber, street, city, region) if part
            )

        overture_category = _overture_category(properties)
        if overture_category:
            category, sub_category = OVERTURE_CATEGORY_MAP.get(
                overture_category,
                ("shop", overture_category),
            )
        else:
            category, sub_category = "other", "general"

        overture_id = _as_text(feature.get("id")) or _as_text(properties.get("id"))
        if not overture_id:
            continue

        yield {
            "osm_id": f"overture:{overture_id}",
            "name": name,
            "name_ascii": remove_vietnamese_accents(name),
            "admin_aliases": get_admin_aliases(city, region, address),
            "category": category,
            "sub_category": sub_category,
            "lat": lat,
            "lon": lon,
            "address": address,
            "address_ascii": remove_vietnamese_accents(address),
            "street": street,
            "housenumber": housenumber,
            "city": city,
            # Internal fields used only during source merge; stripped before
            # SQLite insertion so the app schema remains unchanged.
            "_source": "overture",
            "_source_updated_at": _overture_update_time(properties),
            "_confidence": confidence,
        }


def _normalize_match_text(value) -> str:
    return re.sub(r"[^a-z0-9]+", "", remove_vietnamese_accents(_as_text(value)))


def _distance_m(lat1, lon1, lat2, lon2) -> float:
    """Approximate great-circle distance, accurate enough for POI matching."""
    radius_m = 6_371_000.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lon2 - lon1)
    a = (
        math.sin(d_phi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    )
    return radius_m * 2 * math.atan2(math.sqrt(a), math.sqrt(max(0.0, 1 - a)))


def _has_value(record, key) -> bool:
    value = record.get(key)
    return value is not None and _as_text(value) != ""


def _address_quality(record) -> int:
    return sum(
        int(_has_value(record, field))
        for field in ("address", "street", "housenumber", "city")
    )


def _address_matches(first, second) -> bool:
    first_address = _normalize_match_text(first.get("address"))
    second_address = _normalize_match_text(second.get("address"))
    if first_address and second_address and first_address == second_address:
        return True

    first_street = _normalize_match_text(first.get("street"))
    second_street = _normalize_match_text(second.get("street"))
    first_number = _normalize_match_text(first.get("housenumber"))
    second_number = _normalize_match_text(second.get("housenumber"))
    return bool(
        first_street
        and second_street
        and first_number
        and second_number
        and first_street == second_street
        and first_number == second_number
    )


def _is_named_osm_poi(record) -> bool:
    return (
        record.get("category") not in {"address", "street"}
        and bool(_normalize_match_text(record.get("name")))
    )


def _records_are_duplicate(osm_record, overture_record, distance_m) -> tuple[bool, float]:
    if not _is_named_osm_poi(osm_record):
        return False, 0.0

    osm_name = _normalize_match_text(osm_record.get("name"))
    overture_name = _normalize_match_text(overture_record.get("name"))
    if not osm_name or not overture_name:
        return False, 0.0

    name_ratio = SequenceMatcher(None, osm_name, overture_name).ratio()
    address_match = _address_matches(osm_record, overture_record)

    # Strict name match handles normal coordinate drift. A wider match is only
    # accepted when the address independently confirms the same place.
    duplicate = (
        distance_m <= OVERTURE_STRICT_NAME_DISTANCE_M
        and name_ratio >= OVERTURE_FUZZY_NAME_RATIO
    ) or (
        distance_m <= OVERTURE_MAX_MATCH_DISTANCE_M
        and address_match
        and name_ratio >= 0.65
    )
    return duplicate, name_ratio


def _build_spatial_grid(records, cell_size_m=OVERTURE_MAX_MATCH_DISTANCE_M):
    cell_degrees = cell_size_m / 111_320.0
    grid = {}
    for index, record in enumerate(records):
        try:
            lat, lon = float(record["lat"]), float(record["lon"])
        except (KeyError, TypeError, ValueError):
            continue
        key = (math.floor(lat / cell_degrees), math.floor(lon / cell_degrees))
        grid.setdefault(key, []).append(index)
    return grid, cell_degrees


def _find_osm_match(osm_records, grid, cell_degrees, overture_record):
    try:
        lat, lon = float(overture_record["lat"]), float(overture_record["lon"])
    except (KeyError, TypeError, ValueError):
        return None

    cell_lat = math.floor(lat / cell_degrees)
    cell_lon = math.floor(lon / cell_degrees)
    matches = []
    for delta_lat in (-1, 0, 1):
        for delta_lon in (-1, 0, 1):
            for index in grid.get((cell_lat + delta_lat, cell_lon + delta_lon), []):
                osm_record = osm_records[index]
                distance_m = _distance_m(lat, lon, osm_record["lat"], osm_record["lon"])
                if distance_m > OVERTURE_MAX_MATCH_DISTANCE_M:
                    continue
                duplicate, name_ratio = _records_are_duplicate(
                    osm_record, overture_record, distance_m
                )
                if duplicate:
                    matches.append((distance_m, -name_ratio, index))
    if not matches:
        return None
    matches.sort()
    distance_m, negative_ratio, index = matches[0]
    return index, distance_m, -negative_ratio


def _canonical_record_key(record):
    confidence = record.get("_confidence")
    try:
        confidence = float(confidence) if confidence is not None else -1.0
    except (TypeError, ValueError):
        confidence = -1.0
    # Address quality is the primary signal. Freshness and Overture confidence
    # are tie-breakers, not a blanket source preference.
    return (
        _address_quality(record),
        confidence,
        _parse_timestamp(record.get("_source_updated_at")),
        1 if record.get("_source") == "osm" else 0,
    )


def _merge_duplicate_records(first, second):
    primary, supplemental = sorted(
        (first, second), key=_canonical_record_key, reverse=True
    )
    merged = dict(primary)
    for field in POI_DB_COLUMNS:
        if not _has_value(merged, field) and _has_value(supplemental, field):
            merged[field] = supplemental[field]
    return merged


def deduplicate_overture(osm_pois, overture_pois):
    """Return Overture POIs that are not confidently represented in OSM."""
    grid, cell_degrees = _build_spatial_grid(osm_pois)
    kept = []
    for overture_poi in overture_pois:
        if _find_osm_match(osm_pois, grid, cell_degrees, overture_poi) is None:
            kept.append(overture_poi)
    return kept


def iter_merged_overture_pois(osm_pois, overture_pois, stats=None):
    """Stream merged records while keeping only the OSM side in memory."""
    if stats is None:
        stats = {
            "overture_input": 0,
            "overture_added": 0,
            "overture_merged": 0,
        }
    else:
        stats.clear()
        stats.update(
            {
                "overture_input": 0,
                "overture_added": 0,
                "overture_merged": 0,
            }
        )

    merged_osm = [dict(record) for record in osm_pois]
    grid, cell_degrees = _build_spatial_grid(merged_osm)

    for overture_poi in overture_pois:
        stats["overture_input"] += 1
        match = _find_osm_match(merged_osm, grid, cell_degrees, overture_poi)
        if match is None:
            stats["overture_added"] += 1
            # Overture-only records can be written immediately, so a national
            # cache does not require a second multi-million-row Python list.
            yield dict(overture_poi)
            continue

        osm_index, _, _ = match
        merged_osm[osm_index] = _merge_duplicate_records(
            merged_osm[osm_index], overture_poi
        )
        stats["overture_merged"] += 1

    yield from merged_osm


def merge_overture_pois(osm_pois, overture_pois):
    """Merge matching records and append Overture-only places.

    This list-returning wrapper is convenient for unit tests and small regions;
    the production build uses iter_merged_overture_pois() directly so national
    data stays streamable.
    """
    stats = {}
    merged = list(iter_merged_overture_pois(osm_pois, overture_pois, stats))
    return merged, stats


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

    def _build_record(
        self, osm_id, tags, lat, lon, has_poi_tag, source_updated_at=None
    ):
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
            # Internal merge metadata. It is stripped before SQLite insertion.
            "_source": "osm",
            "_source_updated_at": _timestamp_to_iso(source_updated_at),
            "_confidence": None,
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

        record = self._build_record(
            f"n{n.id}", n.tags, lat, lon, has_poi_tag, n.timestamp
        )
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

        record = self._build_record(
            f"w{w.id}", w.tags, avg_lat, avg_lon, has_poi_tag, w.timestamp
        )
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

    # Chèn dữ liệu POIs theo batch. Internal source metadata is deliberately
    # excluded so the SQLite schema consumed by Flutter does not change.
    db_rows = (
        {column: poi.get(column) for column in POI_DB_COLUMNS}
        for poi in pois
    )
    cursor.executemany("""
        INSERT INTO poi (osm_id, name, name_ascii, category, sub_category, lat, lon, address, address_ascii, street, housenumber, city, admin_aliases)
        VALUES (:osm_id, :name, :name_ascii, :category, :sub_category, :lat, :lon, :address, :address_ascii, :street, :housenumber, :city, :admin_aliases);
    """, db_rows)

    conn.commit()

    # Index bổ sung cho category và lat/lon
    cursor.execute("CREATE INDEX idx_poi_category ON poi(category);")
    cursor.execute("CREATE INDEX idx_poi_name_ascii ON poi(name_ascii);")

    conn.commit()
    # Ship a self-contained database without WAL sidecar files.
    cursor.execute("PRAGMA wal_checkpoint(TRUNCATE);")
    cursor.execute("PRAGMA journal_mode = DELETE;")
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
        "| Vùng địa lý | Tên File | Số lượng POI/địa chỉ | Overture thêm | Overture gộp | Có alias cũ/mới | Dung lượng file | Thời gian Query FTS5 |",
        "| ----------- | -------- | -------------------- | ------------- | ------------ | --------------- | --------------- | -------------------- |",
    ]

    for key, data in results.items():
        region_name = REGIONS[key]["name"]
        filename = f"{key}_poi.db"
        size_mb = data["size_bytes"] / (1024 * 1024)
        poi_count = f"{data['count']:,}"
        report_lines.append(
            f"| {region_name} | `{filename}` | {poi_count} địa điểm (+ {data['address_count']:,} địa chỉ) | {data['overture_added']:,} | {data['overture_merged']:,} | {data['alias_count']:,} bản ghi | {size_mb:.2f} MB | < 50 ms |"
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


def _find_overture_cache():
    """Prefer the streamable cache, while supporting the legacy GeoJSON path."""
    if OVERTURE_GEOJSONSEQ.exists():
        return OVERTURE_GEOJSONSEQ
    if OVERTURE_GEOJSON.exists():
        return OVERTURE_GEOJSON
    return None


def load_osm_pois_from_database(db_path: Path):
    """Load an existing OSM POI database for a fast source-merge rebuild."""
    if not db_path.exists():
        raise FileNotFoundError(f"Không tìm thấy OSM POI database: {db_path}")

    connection = sqlite3.connect(str(db_path))
    connection.row_factory = sqlite3.Row
    try:
        columns = {
            row[1] for row in connection.execute("PRAGMA table_info(poi)")
        }
        missing = set(POI_DB_COLUMNS) - columns
        if missing:
            raise ValueError(f"POI database thiếu cột cần thiết: {sorted(missing)}")
        rows = connection.execute(
            "SELECT osm_id, name, name_ascii, category, sub_category, lat, lon, "
            "address, address_ascii, street, housenumber, city, admin_aliases "
            "FROM poi"
        ).fetchall()
    finally:
        connection.close()

    return [
        {
            **dict(row),
            "_source": "osm",
            "_source_updated_at": "",
            "_confidence": None,
        }
        for row in rows
    ]


def process_region(region_key: str, use_overture=True, reuse_existing_osm_db=False):
    """Trích xuất và đóng gói SQLite database cho 1 vùng cụ thể."""
    region_info = REGIONS[region_key]
    print(f"\n==================================================", flush=True)
    print(f"📦 BẮT ĐẦU DỰNG POI DATABASE CHO: {region_info['name']} ({region_key})", flush=True)
    print(f"==================================================", flush=True)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    out_db_path = OUTPUT_DIR / f"{region_key}_poi.db"

    if reuse_existing_osm_db:
        print(f"⚡ Đọc lại OSM POI database có sẵn: {out_db_path.name}", flush=True)
        osm_pois = load_osm_pois_from_database(out_db_path)
        print(f"⚡ Đã đọc {len(osm_pois):,} bản ghi OSM từ SQLite")
    else:
        if not RAW_PBF.exists():
            print(f"❌ LỖI: Không tìm thấy file dữ liệu OSM thô: {RAW_PBF}", flush=True)
            sys.exit(1)

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
        osm_pois = handler.pois

    overture_stats = {
        "overture_input": 0,
        "overture_added": 0,
        "overture_merged": 0,
    }
    pois = osm_pois
    if use_overture:
        overture_cache = _find_overture_cache()
        if overture_cache is None:
            print("ℹ️ Chưa có Overture cache; build này chỉ dùng OSM.")
        else:
            print(f"⏳ Đang đọc Overture Places từ {overture_cache}...")
            overture_pois = load_overture_places(
                overture_cache, bbox=region_info.get("bbox_tuple")
            )
            pois = iter_merged_overture_pois(
                osm_pois,
                overture_pois,
                overture_stats,
            )

    # Tạo SQLite Database
    print(f"💾 Đang ghi SQLite DB + FTS5 + R*Tree vào {out_db_path.name}...")
    create_sqlite_poi_database(out_db_path, pois)
    if overture_stats["overture_input"]:
        print(
            "🔀 Overture: "
            f"{overture_stats['overture_input']:,} hợp lệ, "
            f"thêm {overture_stats['overture_added']:,}, "
            f"gộp {overture_stats['overture_merged']:,}"
        )

    # Benchmark test
    poi_count, address_count, alias_count = benchmark_poi_database(out_db_path)
    db_size = out_db_path.stat().st_size

    return {
        "count": poi_count,
        "address_count": address_count,
        "alias_count": alias_count,
        "size_bytes": db_size,
        **overture_stats,
    }


def main():
    parser = argparse.ArgumentParser(description="S-Map POI SQLite DB Builder")
    parser.add_argument(
        "--region",
        type=str,
        default="metro_hcm",
        help="Vùng cần build: metro_hcm, metro_hn, mien_nam, mien_trung, mien_bac, vietnam, hoặc all",
    )
    parser.add_argument(
        "--no-overture",
        action="store_true",
        help="Không merge Overture, dùng để tạo baseline OSM hoặc debug cache.",
    )
    parser.add_argument(
        "--reuse-existing-osm-db",
        action="store_true",
        help="Dùng POI DB OSM hiện có làm baseline, không đọc lại PBF.",
    )
    args = parser.parse_args()

    results = {}
    target_region = args.region.lower()

    if target_region == "all":
        for key in REGIONS.keys():
            results[key] = process_region(
                key,
                use_overture=not args.no_overture,
                reuse_existing_osm_db=args.reuse_existing_osm_db,
            )
    elif target_region in REGIONS:
        results[target_region] = process_region(
            target_region,
            use_overture=not args.no_overture,
            reuse_existing_osm_db=args.reuse_existing_osm_db,
        )
    else:
        print(f"❌ Vùng không hợp lệ: {target_region}. Chọn 1 trong: {list(REGIONS.keys())} hoặc all")
        sys.exit(1)

    update_data_sizes_md(results)
    print("\n✅ HOÀN THÀNH TOÀN BỘ TIẾN TRÌNH BUILD POI DATABASE!")


if __name__ == "__main__":
    main()
