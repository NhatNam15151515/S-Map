# -*- coding: utf-8 -*-
"""
S-Map Data Pipeline: Configuration & Region Definitions.
Chứa thông tin cấu hình và ranh giới địa lý dùng chung cho toàn bộ các script pipeline.
"""

from pathlib import Path

DATA_DIR = Path("data-pipeline/data")
RAW_PBF = DATA_DIR / "raw" / "vietnam-latest.osm.pbf"

PMTILES_DIR = DATA_DIR / "output_pmtiles"
GHZ_DIR = DATA_DIR / "output_ghz"
POI_DB_DIR = DATA_DIR / "output_poi_db"
PACKAGES_DIR = DATA_DIR / "output_packages"

# Overture Places is downloaded once for the country and filtered per region
# while building each regional database.  GeoJSONSeq keeps the national cache
# streamable instead of requiring the whole FeatureCollection in memory.
OVERTURE_DIR = DATA_DIR / "overture"
OVERTURE_GEOJSON = OVERTURE_DIR / "vietnam_places.geojson"
OVERTURE_GEOJSONSEQ = OVERTURE_DIR / "vietnam_places.geojsonseq"
OVERTURE_METADATA = OVERTURE_DIR / "vietnam_places.metadata.json"

REGIONS = {
    "vietnam": {
        "name": "Toàn quốc Việt Nam",
        "bbox": "102.1,8.5,109.5,23.4",
        "bbox_tuple": (102.1, 8.5, 109.5, 23.4),
        "boundary": None,
    },
    "metro_hcm": {
        "name": "Vùng TP.HCM (HCM, Bình Dương, Đồng Nai, Long An)",
        "bbox": "106.10,10.35,107.25,11.35",
        "bbox_tuple": (106.10, 10.35, 107.25, 11.35),
        "boundary": "data-pipeline/boundaries/metro_hcm.geojson",
    },
    "metro_hn": {
        "name": "Vùng Hà Nội (Hà Nội, Bắc Ninh, Hưng Yên, Vĩnh Phúc)",
        "bbox": "105.30,20.60,106.30,21.40",
        "bbox_tuple": (105.30, 20.60, 106.30, 21.40),
        "boundary": "data-pipeline/boundaries/metro_hn.geojson",
    },
    "mien_nam": {
        "name": "Miền Nam (Đông Nam Bộ + Tây Nam Bộ)",
        "bbox": "104.40,8.50,107.80,12.00",
        "bbox_tuple": (104.40, 8.50, 107.80, 12.00),
        "boundary": "data-pipeline/boundaries/mien_nam.geojson",
    },
    "mien_trung": {
        "name": "Miền Trung (Bắc Trung Bộ + Nam Trung Bộ + Tây Nguyên)",
        "bbox": "105.00,11.50,109.50,19.50",
        "bbox_tuple": (105.00, 11.50, 109.50, 19.50),
        "boundary": "data-pipeline/boundaries/mien_trung.geojson",
    },
    "mien_bac": {
        "name": "Miền Bắc (Đông Bắc + Tây Bắc + Đồng bằng Sông Hồng)",
        "bbox": "102.10,19.50,108.00,23.40",
        "bbox_tuple": (102.10, 19.50, 108.00, 23.40),
        "boundary": "data-pipeline/boundaries/mien_bac.geojson",
    },
}
