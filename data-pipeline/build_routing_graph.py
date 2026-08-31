#!/usr/bin/env python3
"""
S-Map Data Pipeline: Build GraphHopper Routing Graph (.ghz) cho các vùng của Việt Nam.

Quy trình:
1. Tải vietnam-latest.osm.pbf từ Geofabrik (nếu chưa có).
2. Trích xuất (extract) PBF theo 5 vùng (metro_hcm, metro_hn, mien_nam, mien_trung, mien_bac).
3. Chạy GraphHopper import để sinh graph cache cho từng vùng + toàn quốc.
4. Đóng gói thư mục graph-cache thành file .ghz (zip archive) để tải offline trong app Flutter.
5. Cập nhật bảng dung lượng vào data_sizes.md.
"""

import os
import sys
import shutil
import subprocess
import zipfile
import time
from pathlib import Path

# Fix Unicode output on Windows terminal
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

# Cấu hình vùng dữ liệu
REGIONS = {
    "vietnam": {
        "name": "Toàn quốc Việt Nam",
        "bbox": "102.1,8.5,109.5,23.4",
        "boundary": None,
    },
    "metro_hcm": {
        "name": "Vùng TP.HCM (HCM, Bình Dương, Đồng Nai, Long An)",
        "bbox": "106.10,10.35,107.25,11.35",
        "boundary": "boundaries/metro_hcm.geojson",
    },
    "metro_hn": {
        "name": "Vùng Hà Nội (Hà Nội, Bắc Ninh, Hưng Yên, Vĩnh Phúc)",
        "bbox": "105.30,20.60,106.30,21.40",
        "boundary": "boundaries/metro_hn.geojson",
    },
    "mien_nam": {
        "name": "Miền Nam (Đông Nam Bộ + Tây Nam Bộ)",
        "bbox": "104.40,8.50,107.80,12.00",
        "boundary": "boundaries/mien_nam.geojson",
    },
    "mien_trung": {
        "name": "Miền Trung (Bắc Trung Bộ + Nam Trung Bộ + Tây Nguyên)",
        "bbox": "105.00,11.50,109.50,19.50",
        "boundary": "boundaries/mien_trung.geojson",
    },
    "mien_bac": {
        "name": "Miền Bắc (Đông Bắc + Tây Bắc + Đồng bằng Sông Hồng)",
        "bbox": "102.10,19.50,108.00,23.40",
        "boundary": "boundaries/mien_bac.geojson",
    },
}

OSM_URL = "https://download.geofabrik.de/asia/vietnam-latest.osm.pbf"
DATA_DIR = Path("data-pipeline/data")
RAW_PBF = DATA_DIR / "raw" / "vietnam-latest.osm.pbf"
OUTPUT_DIR = DATA_DIR / "output_ghz"
GRAPH_CACHE_DIR = DATA_DIR / "graph-cache"
GH_JAR = Path("data-pipeline/graphhopper-web.jar")
GH_CONFIG = Path("data-pipeline/graphhopper-config.yml")
MIN_REAL_GHZ_BYTES = 1024 * 1024

def format_size(size_bytes):
    """Chuyển bytes sang MB/KB dễ đọc"""
    if size_bytes >= 1024 * 1024:
        return f"{size_bytes / (1024 * 1024):.2f} MB"
    elif size_bytes >= 1024:
        return f"{size_bytes / 1024:.2f} KB"
    return f"{size_bytes} B"

def check_tools():
    """Kiểm tra môi trường Java & osmium, trả về (has_java, has_osmium)"""
    print("=== 1. Kiểm tra môi trường ===")
    
    # Kiểm tra Java
    has_java = False
    try:
        java_out = subprocess.check_output(["java", "-version"], stderr=subprocess.STDOUT).decode()
        print(f"[OK] Java: {java_out.splitlines()[0]}")
        has_java = True
    except Exception:
        print("[WARNING] Java không khả dụng. Bạn cần Java 11+ để build GraphHopper graph.")

    # Kiểm tra osmium
    has_osmium = False
    try:
        subprocess.check_output(["osmium", "--version"], stderr=subprocess.STDOUT)
        has_osmium = True
        print("[OK] osmium CLI available.")
    except Exception:
        print("[INFO] osmium CLI chưa được cài đặt. Sẽ dùng fallback bbox/skip extract nếu chưa có pbf theo vùng.")
        
    return has_java, has_osmium

def download_osm_data():
    """Tải OSM data Việt Nam từ Geofabrik nếu chưa có"""
    print("\n=== 2. Tải OSM Data Việt Nam ===")
    RAW_PBF.parent.mkdir(parents=True, exist_ok=True)
    if RAW_PBF.exists():
        size = RAW_PBF.stat().st_size
        print(f"[OK] File {RAW_PBF} đã tồn tại ({format_size(size)}).")
        return True

    print(f"Đang tải {OSM_URL}...")
    try:
        import urllib.request
        import ssl
        # Sử dụng SSL context mặc định của hệ thống (có xác thực certificate)
        ctx = ssl.create_default_context()
        
        with urllib.request.urlopen(OSM_URL, context=ctx) as response, open(RAW_PBF, 'wb') as out_file:
            shutil.copyfileobj(response, out_file)
            
        size = os.path.getsize(RAW_PBF)
        print(f"[SUCCESS] Tải thành công {RAW_PBF} ({format_size(size)}).")
        return True
    except Exception as e:
        print(f"[ERROR] Tải thất bại: {e}")
        return False

def zip_directory(src_dir, target_ghz):
    """Nén thư mục graph-cache thành file .ghz (zip archive)"""
    with zipfile.ZipFile(target_ghz, 'w', zipfile.ZIP_DEFLATED) as ziph:
        for root, dirs, files in os.walk(src_dir):
            for file in files:
                file_path = os.path.join(root, file)
                arcname = os.path.relpath(file_path, src_dir)
                ziph.write(file_path, arcname)


def prepare_graphhopper_config(region_id, region_pbf, graph_cache):
    """Tạo config import đúng PBF/cache của vùng đang build.

    GraphHopper bản hiện tại nhận config bằng positional argument sau lệnh
    ``import``; các tham số ``datareader.file=...`` cũ không còn hợp lệ.
    """
    if not GH_CONFIG.exists():
        return None

    config_path = DATA_DIR / f"{region_id}_graphhopper_config.yml"
    pbf_path = region_pbf.resolve().as_posix()
    graph_path = graph_cache.resolve().as_posix()
    config_lines = []
    for line in GH_CONFIG.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped.startswith("datareader.file:"):
            line = f"  datareader.file: {pbf_path}"
        elif stripped.startswith("graph.location:"):
            line = f"  graph.location: {graph_path}"
        config_lines.append(line)

    config_path.write_text("\n".join(config_lines) + "\n", encoding="utf-8")
    return config_path

def extract_region_pbf(region_id, region_info, has_osmium):
    """Trích xuất PBF cho 1 vùng bằng osmium hoặc skip nếu không có tool.
    
    Returns:
        Path to region PBF file, or None nếu không extract được.
    """
    # Toàn quốc dùng file gốc, không cần extract
    if region_id == "vietnam":
        return RAW_PBF if RAW_PBF.exists() else None
    
    region_pbf = DATA_DIR / "raw" / f"{region_id}.osm.pbf"
    
    # Đã extract trước đó
    if region_pbf.exists():
        print(f"  [OK] PBF vùng {region_id} đã tồn tại ({format_size(region_pbf.stat().st_size)}).")
        return region_pbf
    
    if not has_osmium:
        print(f"  [SKIP] Không có osmium CLI, không thể extract PBF cho vùng {region_id}.")
        return None
    
    if not RAW_PBF.exists():
        print(f"  [SKIP] Chưa có file PBF gốc ({RAW_PBF}).")
        return None
    
    boundary_path = region_info.get("boundary")
    if boundary_path:
        # Dùng boundary polygon để extract chính xác
        print(f"  Đang extract PBF bằng osmium (boundary: {boundary_path})...")
        try:
            subprocess.run([
                "osmium", "extract",
                "-p", boundary_path,
                str(RAW_PBF),
                "-o", str(region_pbf),
                "--overwrite"
            ], check=True, capture_output=True, text=True)
            print(f"  [OK] Extract xong: {region_pbf} ({format_size(region_pbf.stat().st_size)})")
            return region_pbf
        except subprocess.CalledProcessError as e:
            print(f"  [ERROR] osmium extract thất bại: {e.stderr}")
            return None
    else:
        # Fallback: dùng bbox
        bbox = region_info.get("bbox")
        if bbox:
            print(f"  Đang extract PBF bằng osmium (bbox: {bbox})...")
            try:
                subprocess.run([
                    "osmium", "extract",
                    "-b", bbox,
                    str(RAW_PBF),
                    "-o", str(region_pbf),
                    "--overwrite"
                ], check=True, capture_output=True, text=True)
                print(f"  [OK] Extract xong: {region_pbf} ({format_size(region_pbf.stat().st_size)})")
                return region_pbf
            except subprocess.CalledProcessError as e:
                print(f"  [ERROR] osmium extract thất bại: {e.stderr}")
                return None
    
    return None

def build_graphhopper_graph(region_id, region_pbf, has_java, force=False):
    """Chạy GraphHopper import để sinh graph-cache cho 1 vùng.
    
    Returns:
        Path to graph-cache directory, or None nếu không build được.
    """
    graph_cache = GRAPH_CACHE_DIR / region_id
    ghz_file = OUTPUT_DIR / f"{region_id}.ghz"
    
    if ghz_file.exists() and ghz_file.stat().st_size >= MIN_REAL_GHZ_BYTES and not force:
        print(f"  [OK] File {ghz_file} đã tồn tại ({format_size(ghz_file.stat().st_size)}). Skip build.")
        return graph_cache

    if ghz_file.exists() and force:
        print(f"  [INFO] --force: sẽ tạo lại routing graph và gói .ghz cho {region_id}.")
    if ghz_file.exists():
        print(f"  [WARNING] File {ghz_file} là placeholder ({format_size(ghz_file.stat().st_size)}). Xóa để build lại.")
        ghz_file.unlink()

    if (graph_cache / "nodes").exists() and not force:
        print(f"  [OK] Graph cache {graph_cache} đã có sẵn. Tái sử dụng để đóng gói.")
        return graph_cache

    if not has_java:
        print(f"  [SKIP] Không có Java, không thể build GraphHopper graph cho {region_id}.")
        return None
    
    if not GH_JAR.exists():
        print(f"  [SKIP] Không tìm thấy GraphHopper JAR ({GH_JAR}). Cần tải graphhopper-web.jar trước.")
        return None
    
    if region_pbf is None or not region_pbf.exists():
        print(f"  [SKIP] Không có PBF file cho vùng {region_id}.")
        return None
    
    # Xóa graph-cache cũ nếu có
    if graph_cache.exists():
        shutil.rmtree(graph_cache)
    graph_cache.mkdir(parents=True, exist_ok=True)
    
    print(f"  Đang build GraphHopper graph cho {region_id}...")
    try:
        config_path = prepare_graphhopper_config(region_id, region_pbf, graph_cache)
        if config_path is None:
            print(f"  [SKIP] Không tìm thấy config GraphHopper ({GH_CONFIG}).")
            return None

        cmd = [
            "java", "-Xmx2g",
            "-jar", str(GH_JAR),
            "import",
            str(config_path),
        ]
        
        subprocess.run(cmd, check=True, capture_output=True, text=True)
        print(f"  [OK] Build graph xong: {graph_cache}")
        return graph_cache
    except subprocess.CalledProcessError as e:
        print(f"  [ERROR] GraphHopper import thất bại: {e.stderr[:500]}")
        return None

def package_ghz(region_id, graph_cache):
    """Đóng gói graph-cache thành file .ghz.
    
    Returns:
        Path to .ghz file, or None nếu không đóng gói được.
    """
    ghz_file = OUTPUT_DIR / f"{region_id}.ghz"
    
    if ghz_file.exists() and ghz_file.stat().st_size >= MIN_REAL_GHZ_BYTES:
        return ghz_file

    if ghz_file.exists():
        ghz_file.unlink()
    
    if graph_cache is None or not graph_cache.exists():
        return None
    
    print(f"  Đang đóng gói {graph_cache} -> {ghz_file}...")
    zip_directory(str(graph_cache), str(ghz_file))
    print(f"  [OK] Đóng gói xong: {ghz_file} ({format_size(ghz_file.stat().st_size)})")
    return ghz_file

def generate_sizes_report(benchmark_results):
    """Tạo báo cáo data_sizes.md trong data-pipeline/"""
    report_path = Path("data-pipeline/data_sizes.md")
    content = """# S-Map Data Pipeline: Dung lượng Routing Graph (.ghz)

Bảng tổng hợp dung lượng các file routing graph `.ghz` (GraphHopper location cache cho moped)
được đóng gói cho 5 vùng địa lý và toàn quốc Việt Nam.

## 📊 Bảng thống kê dung lượng & thời gian build

| ID Vùng | Tên vùng | File PBF | File .ghz | Dung lượng | Thời gian build | Target MVP | Status |
|---|---|---|---|---|---|---|---|
"""
    for region_id, info in benchmark_results.items():
        name = REGIONS[region_id]["name"]
        pbf_size = format_size(info["pbf_size"]) if info["pbf_size"] else "N/A"
        ghz_size = format_size(info["ghz_size"]) if info["ghz_size"] else "N/A"
        build_time = f"{info['build_time']:.1f}s" if info["build_time"] else "N/A"
        target = "< 50MB" if "metro" in region_id else "< 200MB"
        status = "✅ Built" if info["success"] else "⬜ Pending (thiếu tool)"
        content += f"| `{region_id}` | {name} | {pbf_size} | `{region_id}.ghz` | **{ghz_size}** | {build_time} | {target} | {status} |\n"

    content += """
---

## ⚡ Tiêu chuẩn tối ưu kích thước cho Mobile Offline

1. **`metro_hcm.ghz` & `metro_hn.ghz`**: Target **< 50MB** để tải cực nhanh trên mạng 4G/Wifi.
2. **`vietnam.ghz`**: Target **< 200MB** cho toàn quốc, vừa vặn lưu trong bộ nhớ máy.
3. **Mã nén**: Zip compression level standard (DEFLATED).
4. **Contraction Hierarchies (CH)**: Được bật sẵn để query route < 500ms trực tiếp trên thiết bị Android/iOS.
"""
    with open(report_path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"\n[OK] Đã cập nhật báo cáo dung lượng vào {report_path}")

def main():
    import argparse

    parser = argparse.ArgumentParser(description="S-Map Routing Graph Builder (.ghz)")
    parser.add_argument(
        "--region",
        type=str,
        default="all",
        help="Vùng cần build: vietnam, metro_hcm, metro_hn, mien_nam, mien_trung, mien_bac, hoặc all",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Xóa cache/.ghz của vùng chọn và import lại từ PBF sau khi đổi profile/model.",
    )
    args = parser.parse_args()

    print("=== S-Map Routing Graph Builder (.ghz) ===")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    GRAPH_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    
    has_java, has_osmium = check_tools()
    download_osm_data()
    
    benchmark_results = {}
    
    target_region = args.region.lower()
    if target_region == "all":
        regions_to_build = REGIONS.items()
    elif target_region in REGIONS:
        regions_to_build = [(target_region, REGIONS[target_region])]
    else:
        print(f"[ERROR] Vùng không hợp lệ: {target_region}")
        sys.exit(1)

    for region_id, region_info in regions_to_build:
        print(f"\n---> Đang xử lý vùng: {region_id} ({region_info['name']})")
        start_time = time.time()
        
        # Bước 1: Extract PBF cho vùng (nếu có osmium)
        region_pbf = extract_region_pbf(region_id, region_info, has_osmium)
        
        # Bước 2: Build GraphHopper graph (nếu có Java + JAR)
        graph_cache = build_graphhopper_graph(region_id, region_pbf, has_java, force=args.force)
        
        # Bước 3: Đóng gói graph-cache thành .ghz
        ghz_file = package_ghz(region_id, graph_cache)
        
        elapsed = time.time() - start_time
        
        # Thu thập kết quả thực tế
        pbf_size = region_pbf.stat().st_size if region_pbf and region_pbf.exists() else 0
        ghz_size = ghz_file.stat().st_size if ghz_file and ghz_file.exists() else 0
        
        benchmark_results[region_id] = {
            "pbf_size": pbf_size,
            "ghz_size": ghz_size,
            "build_time": elapsed,
            "success": ghz_file is not None and ghz_file.exists()
        }
        
        status = "DONE" if benchmark_results[region_id]["success"] else "SKIPPED"
        print(f"[{status}] Vùng {region_id} ({elapsed:.1f}s)")

    generate_sizes_report(benchmark_results)

if __name__ == "__main__":
    main()
