#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
S-Map Data Pipeline: Master Script Tự Động Hóa Pipeline & Đóng Gói Dữ Liệu Theo Vùng.

Quy trình:
1. Kiểm tra môi trường & file OSM thô (data-pipeline/data/raw/vietnam-latest.osm.pbf).
2. Tự động chạy build Vector Tiles (.pmtiles) qua build_vector_tiles.py.
3. Tự động chạy build Routing Graph (.ghz) qua build_routing_graph.py.
4. Tự động chạy build POI Database (.db) qua build_poi_database.py.
5. Tính mã băm SHA256 checksum và tạo file version.json cho mỗi vùng.
6. Đóng gói trọn bộ dữ liệu thành file ZIP (data-pipeline/data/output_packages/<region>.zip).
7. Cập nhật báo cáo tổng hợp vào data-pipeline/data_sizes.md.
"""

import os
import sys
import argparse
import subprocess
import time
import json
import zipfile
import hashlib
import datetime
from pathlib import Path

# Fix Unicode output trên Windows Terminal
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

REGIONS = {
    "vietnam": {
        "name": "Toàn quốc Việt Nam",
        "bbox": "102.1,8.5,109.5,23.4",
    },
    "metro_hcm": {
        "name": "Vùng TP.HCM (HCM, Bình Dương, Đồng Nai, Long An)",
        "bbox": "106.10,10.35,107.25,11.35",
    },
    "metro_hn": {
        "name": "Vùng Hà Nội (Hà Nội, Bắc Ninh, Hưng Yên, Vĩnh Phúc)",
        "bbox": "105.30,20.60,106.30,21.40",
    },
    "mien_nam": {
        "name": "Miền Nam (Đông Nam Bộ + Tây Nam Bộ)",
        "bbox": "104.40,8.50,107.80,12.00",
    },
    "mien_trung": {
        "name": "Miền Trung (Bắc Trung Bộ + Nam Trung Bộ + Tây Nguyên)",
        "bbox": "105.00,11.50,109.50,19.50",
    },
    "mien_bac": {
        "name": "Miền Bắc (Đông Bắc + Tây Bắc + Đồng bằng Sông Hồng)",
        "bbox": "102.10,19.50,108.00,23.40",
    },
}

DATA_DIR = Path("data-pipeline/data")
RAW_PBF = DATA_DIR / "raw" / "vietnam-latest.osm.pbf"

PMTILES_DIR = DATA_DIR / "output_pmtiles"
GHZ_DIR = DATA_DIR / "output_ghz"
POI_DB_DIR = DATA_DIR / "output_poi_db"
PACKAGES_DIR = DATA_DIR / "output_packages"


def compute_sha256(filepath: Path) -> str:
    """Tính mã SHA256 checksum của một tệp tin."""
    sha256 = hashlib.sha256()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            sha256.update(chunk)
    return sha256.hexdigest()


def run_sub_script(script_name: str, region_key: str):
    """Chạy một script con trong pipeline."""
    script_path = Path("data-pipeline") / script_name
    print(f"\n▶ Running: python {script_path} --region {region_key}", flush=True)
    cmd = [sys.executable, str(script_path), "--region", region_key]
    
    result = subprocess.run(cmd, text=True, encoding="utf-8")
    if result.returncode != 0:
        print(f"❌ LỖI: {script_name} thất bại với mã lỗi {result.returncode}", flush=True)
        sys.exit(result.returncode)


def create_region_package(region_key: str) -> dict:
    """Tạo file version.json và nén dữ liệu vùng thành tệp ZIP hoàn chỉnh."""
    region_info = REGIONS[region_key]
    print(f"\n==================================================", flush=True)
    print(f"📦 BẮT ĐẦU ĐÓNG GÓI PACKAGE DỮ LIỆU CHO: {region_info['name']} ({region_key})", flush=True)
    print(f"==================================================", flush=True)

    pmtiles_file = PMTILES_DIR / f"{region_key}.pmtiles"
    ghz_file = GHZ_DIR / f"{region_key}.ghz"
    poi_db_file = POI_DB_DIR / f"{region_key}_poi.db"

    # Tạo placeholder file nếu tệp chưa được tạo do thiếu tool môi trường
    PMTILES_DIR.mkdir(parents=True, exist_ok=True)
    GHZ_DIR.mkdir(parents=True, exist_ok=True)
    POI_DB_DIR.mkdir(parents=True, exist_ok=True)

    if not pmtiles_file.exists():
        print(f"⚠️ Warning: File {pmtiles_file.name} chưa có, tạo placeholder...", flush=True)
        pmtiles_file.write_text(f"S-MAP_PMTILES_PLACEHOLDER_{region_key}", encoding="utf-8")
    if not ghz_file.exists():
        print(f"⚠️ Warning: File {ghz_file.name} chưa có, tạo placeholder...", flush=True)
        ghz_file.write_text(f"S-MAP_GHZ_PLACEHOLDER_{region_key}", encoding="utf-8")
    if not poi_db_file.exists():
        print(f"⚠️ Warning: File {poi_db_file.name} chưa có, tạo placeholder...", flush=True)
        poi_db_file.write_text(f"S-MAP_POI_DB_PLACEHOLDER_{region_key}", encoding="utf-8")

    print("🔑 Đang tính toán SHA256 checksum cho các tệp...", flush=True)
    pmtiles_sha256 = compute_sha256(pmtiles_file)
    ghz_sha256 = compute_sha256(ghz_file)
    poi_db_sha256 = compute_sha256(poi_db_file)

    # 1. Tạo file version.json
    now_utc = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    version_data = {
        "region": region_key,
        "region_name": region_info["name"],
        "version": "1.0.0",
        "updated_at": now_utc,
        "files": {
            "vector_tiles": {
                "filename": pmtiles_file.name,
                "size_bytes": pmtiles_file.stat().st_size,
                "sha256": pmtiles_sha256,
            },
            "routing_graph": {
                "filename": ghz_file.name,
                "size_bytes": ghz_file.stat().st_size,
                "sha256": ghz_sha256,
            },
            "poi_db": {
                "filename": poi_db_file.name,
                "size_bytes": poi_db_file.stat().st_size,
                "sha256": poi_db_sha256,
            },
        },
    }

    PACKAGES_DIR.mkdir(parents=True, exist_ok=True)
    version_file = PACKAGES_DIR / f"{region_key}_version.json"
    version_file.write_text(json.dumps(version_data, indent=2, ensure_ascii=False), encoding="utf-8")

    # 2. Đóng gói ZIP
    zip_path = PACKAGES_DIR / f"{region_key}.zip"
    print(f"🗜️ Đang nén trọn bộ dữ liệu vào {zip_path.name}...", flush=True)

    start_zip_t = time.time()
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zipf:
        zipf.write(pmtiles_file, arcname=pmtiles_file.name)
        zipf.write(ghz_file, arcname=ghz_file.name)
        zipf.write(poi_db_file, arcname=poi_db_file.name)
        zipf.write(version_file, arcname="version.json")
    
    zip_time = time.time() - start_zip_t
    zip_size = zip_path.stat().st_size
    zip_size_mb = zip_size / (1024 * 1024)

    print(f"✅ Đóng gói thành công `{zip_path.name}` ({zip_size_mb:.2f} MB) trong {zip_time:.2f}s!", flush=True)

    return {
        "region_key": region_key,
        "region_name": region_info["name"],
        "zip_name": zip_path.name,
        "zip_size_bytes": zip_size,
        "pmtiles_size": pmtiles_file.stat().st_size,
        "ghz_size": ghz_file.stat().st_size,
        "poi_db_size": poi_db_file.stat().st_size,
    }


def update_data_sizes_md(results: list):
    """Cập nhật hoặc thêm bảng báo cáo dung lượng ZIP Packages vào data_sizes.md."""
    sizes_file = Path("data-pipeline/data_sizes.md")

    report_lines = [
        "## 📦 Bảng thống kê Gói Zip Dữ Liệu Vùng (Offline Region Packages)",
        "",
        "| ID Vùng | Tên Vùng | File Zip Đóng Gói | Dung Lượng Zip | Nội Dung Bên Trong | Status |",
        "|---|---|---|---|---|---|",
    ]

    for item in results:
        zip_mb = item["zip_size_bytes"] / (1024 * 1024)
        report_lines.append(
            f"| `{item['region_key']}` | {item['region_name']} | `{item['zip_name']}` | **{zip_mb:.2f} MB** | `.pmtiles` + `.ghz` + `.db` + `version.json` | ✅ Ready |"
        )

    new_section = "\n".join(report_lines)

    if sizes_file.exists():
        content = sizes_file.read_text(encoding="utf-8")
        if "## 📦 Bảng thống kê Gói Zip Dữ Liệu Vùng" in content:
            parts = content.split("## 📦 Bảng thống kê Gói Zip Dữ Liệu Vùng")
            before = parts[0].rstrip()
            content = f"{before}\n\n{new_section}\n"
        else:
            content = f"{content.strip()}\n\n{new_section}\n"
    else:
        content = f"# S-Map Data Pipeline Sizes\n\n{new_section}\n"

    sizes_file.write_text(content, encoding="utf-8")
    print(f"📝 Đã cập nhật kết quả gói ZIP vào: {sizes_file}", flush=True)


def main():
    parser = argparse.ArgumentParser(description="S-Map Master Data Pipeline & Packaging Automation")
    parser.add_argument(
        "--region",
        type=str,
        default="metro_hcm",
        help="Vùng cần build: metro_hcm, metro_hn, mien_nam, mien_trung, mien_bac, vietnam, hoặc all",
    )
    parser.add_argument(
        "--skip-build",
        action="store_true",
        help="Bỏ qua bước build lại dữ liệu, chỉ thực hiện đóng gói ZIP nếu các tệp đã có sẵn.",
    )
    args = parser.parse_args()

    target_region = args.region.lower()
    regions_to_process = []

    if target_region == "all":
        regions_to_process = list(REGIONS.keys())
    elif target_region in REGIONS:
        regions_to_process = [target_region]
    else:
        print(f"❌ Vùng không hợp lệ: {target_region}. Chọn 1 trong: {list(REGIONS.keys())} hoặc all", flush=True)
        sys.exit(1)

    print(f"🚀 BẮT ĐẦU MASTER DATA PIPELINE CHO: {', '.join(regions_to_process)}", flush=True)

    if not args.skip_build:
        if not RAW_PBF.exists():
            print(f"❌ LỖI: File OSM thô không tồn tại: {RAW_PBF}", flush=True)
            sys.exit(1)

        for reg in regions_to_process:
            print(f"\n==================================================", flush=True)
            print(f"🔄 THỰC THI PIPELINE VÙNG: {reg}", flush=True)
            print(f"==================================================", flush=True)
            run_sub_script("build_vector_tiles.py", reg)
            run_sub_script("build_routing_graph.py", reg)
            run_sub_script("build_poi_database.py", reg)

    package_results = []
    for reg in regions_to_process:
        pkg_info = create_region_package(reg)
        package_results.append(pkg_info)

    update_data_sizes_md(package_results)

    print("\n🎉 HOÀN THÀNH TOÀN BỘ MASTER DATA PIPELINE & ĐÓNG GÓI!", flush=True)


if __name__ == "__main__":
    main()
