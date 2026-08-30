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
7. Cập nhật báo cáo tổng hợp vào data-pipeline/data_sizes.md bằng Regex safe matching.
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
import re
from pathlib import Path

# Thêm data-pipeline vào sys.path để import config
sys.path.append(str(Path(__file__).parent))
from config import REGIONS, RAW_PBF, PMTILES_DIR, GHZ_DIR, POI_DB_DIR, PACKAGES_DIR

MIN_REAL_PMTILES_BYTES = 1024 * 1024
MIN_REAL_GHZ_BYTES = 1024 * 1024
MIN_REAL_POI_DB_BYTES = 1024 * 1024


def _has_real_data_file(path: Path, minimum_bytes: int) -> bool:
    return path.exists() and path.stat().st_size >= minimum_bytes


def _has_address_search_data(path: Path) -> bool:
    """Kiểm tra package có DB tìm kiếm số nhà và street index mới hay chưa."""
    if not _has_real_data_file(path, MIN_REAL_POI_DB_BYTES):
        return False
    try:
        import sqlite3

        with sqlite3.connect(path) as conn:
            columns = {row[1] for row in conn.execute("PRAGMA table_info(poi)")}
            if not {"housenumber", "street", "admin_aliases"}.issubset(columns):
                return False
            address_count = conn.execute(
                "SELECT COUNT(*) FROM poi WHERE category = 'address'"
            ).fetchone()[0]
            street_count = conn.execute(
                "SELECT COUNT(*) FROM poi WHERE category = 'street'"
            ).fetchone()[0]
            return address_count > 0 and street_count > 0
    except (OSError, sqlite3.Error):
        return False

# Fix Unicode output trên Windows Terminal
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")


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

    # Fix Critical: Kiểm tra nghiêm ngặt sự tồn tại của file nhị phân, KHÔNG tạo file text giả (placeholder)
    missing_files = []
    for file_path, label, minimum_bytes in [
        (pmtiles_file, "Vector Tiles (.pmtiles)", MIN_REAL_PMTILES_BYTES),
        (ghz_file, "Routing Graph (.ghz)", MIN_REAL_GHZ_BYTES),
    ]:
        if not _has_real_data_file(file_path, minimum_bytes):
            missing_files.append(f"  - {label}: {file_path}")

    if not _has_address_search_data(poi_db_file):
        missing_files.append(
            "  - POI Database (.db) thiếu bảng số nhà/street index/alias hoặc là placeholder: "
            f"{poi_db_file}"
        )

    if missing_files:
        raise FileNotFoundError(
            f"❌ LỖI ĐÓNG GÓI ({region_key}): Thiếu hoặc hỏng các file thành phần sau:\n"
            + "\n".join(missing_files)
            + "\nVui lòng kiểm tra lại quá trình build trước khi nén ZIP!"
        )

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
    }


def update_data_sizes_md(results: list):
    """Fix Medium: Cập nhật an toàn báo cáo gói ZIP vào data_sizes.md bằng HTML Comment tags và Regex."""
    sizes_file = Path("data-pipeline/data_sizes.md")

    # Khi đóng gói từng vùng, giữ lại các vùng đã có trong báo cáo thay vì
    # xóa chúng. Điều này giúp số liệu HCM và toàn quốc luôn xuất hiện cùng nhau.
    existing_rows = {}
    existing_content = sizes_file.read_text(encoding="utf-8") if sizes_file.exists() else ""
    existing_block = re.search(
        r"<!-- START_ZIP_TABLE_METRICS -->.*?<!-- END_ZIP_TABLE_METRICS -->",
        existing_content,
        flags=re.DOTALL,
    )
    if existing_block:
        for line in existing_block.group(0).splitlines():
            row_match = re.match(r"\| `([^`]+)` \|", line)
            if row_match:
                existing_rows[row_match.group(1)] = line

    report_lines = [
        "<!-- START_ZIP_TABLE_METRICS -->",
        "## 📦 Bảng thống kê Gói Zip Dữ Liệu Vùng (Offline Region Packages)",
        "",
        "| ID Vùng | Tên Vùng | File Zip Đóng Gói | Dung Lượng Zip | Nội Dung Bên Trong | Status |",
        "|---|---|---|---|---|---|",
    ]

    for item in results:
        zip_mb = item["zip_size_bytes"] / (1024 * 1024)
        existing_rows[item["region_key"]] = (
            f"| `{item['region_key']}` | {item['region_name']} | `{item['zip_name']}` | **{zip_mb:.2f} MB** | `.pmtiles` + `.ghz` + `.db` + `version.json` | ✅ Ready |"
        )

    for row in existing_rows.values():
        report_lines.append(row)

    report_lines.append("<!-- END_ZIP_TABLE_METRICS -->")
    new_table_str = "\n".join(report_lines)

    if sizes_file.exists():
        content = sizes_file.read_text(encoding="utf-8")
        placeholder_regex = r"<!-- START_ZIP_TABLE_METRICS -->.*?<!-- END_ZIP_TABLE_METRICS -->"
        if re.search(placeholder_regex, content, re.DOTALL):
            content = re.sub(placeholder_regex, new_table_str, content, flags=re.DOTALL)
        else:
            content = f"{content.strip()}\n\n{new_table_str}\n"
    else:
        content = f"# S-Map Data Pipeline Sizes\n\n{new_table_str}\n"

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
        try:
            pkg_info = create_region_package(reg)
            package_results.append(pkg_info)
        except FileNotFoundError as e:
            print(f"\n{e}", flush=True)
            sys.exit(1)

    update_data_sizes_md(package_results)

    print("\n🎉 HOÀN THÀNH TOÀN BỘ MASTER DATA PIPELINE & ĐÓNG GÓI!", flush=True)


if __name__ == "__main__":
    main()
