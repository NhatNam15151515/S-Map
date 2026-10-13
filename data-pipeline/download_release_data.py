#!/usr/bin/env python3
"""Download and verify an offline map package from the latest GitHub Release."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
import urllib.request
import zipfile
from pathlib import Path, PurePosixPath

from config import DATA_DIR, GHZ_DIR, PACKAGES_DIR, POI_DB_DIR, PMTILES_DIR, REGIONS

RELEASE_BASE_URL = (
    "https://github.com/NhatNam15151515/S-Map/releases/latest/download"
)
CHUNK_SIZE = 1024 * 1024


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(CHUNK_SIZE), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download(url: str, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(url, timeout=60) as response, target.open("wb") as output:
        shutil.copyfileobj(response, output, length=CHUNK_SIZE)


def download_region(region: str, force: bool) -> None:
    if region not in REGIONS:
        raise ValueError(f"Vùng không hợp lệ: {region}. Chọn: {', '.join(REGIONS)}")

    manifest_url = f"{RELEASE_BASE_URL}/{region}_latest.json"
    request = urllib.request.Request(
        manifest_url,
        headers={"User-Agent": "S-Map data-pipeline downloader"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        manifest = json.loads(response.read().decode("utf-8"))

    package = manifest.get("package", {})
    filename = f"{region}.zip"
    package_url = package.get("download_url")
    expected_size = package.get("size_bytes")
    expected_hash = package.get("sha256", "").lower()
    if manifest.get("region") != region:
        raise ValueError("Manifest release không khớp vùng được yêu cầu.")
    if package.get("filename") != filename or not package_url:
        raise ValueError("Manifest release thiếu tên hoặc URL package hợp lệ.")
    if not package_url.startswith(f"{RELEASE_BASE_URL}/"):
        raise ValueError("Từ chối tải package từ URL ngoài GitHub Releases của S-Map.")
    if not isinstance(expected_size, int) or expected_size <= 0:
        raise ValueError("Manifest release thiếu kích thước package hợp lệ.")
    if len(expected_hash) != 64 or any(c not in "0123456789abcdef" for c in expected_hash):
        raise ValueError("Manifest release thiếu SHA-256 hợp lệ.")

    DATA_DIR.mkdir(parents=True, exist_ok=True)
    archive_path = DATA_DIR / filename
    partial_path = archive_path.with_suffix(archive_path.suffix + ".part")
    stage = DATA_DIR / f".{region}_release_staging"
    try:
        print(f"Đang tải {filename} (release {manifest.get('version', 'latest')})...")
        download(package_url, partial_path)
        if partial_path.stat().st_size != expected_size:
            raise ValueError("Kích thước package tải về không khớp manifest.")
        if sha256_file(partial_path) != expected_hash:
            raise ValueError("SHA-256 package tải về không khớp manifest.")

        stage.mkdir(parents=True, exist_ok=True)
        outputs = {
            f"{region}.pmtiles": PMTILES_DIR / f"{region}.pmtiles",
            f"{region}.ghz": GHZ_DIR / f"{region}.ghz",
            f"{region}_poi.db": POI_DB_DIR / f"{region}_poi.db",
            f"{region}_trie_index.bin": POI_DB_DIR / f"{region}_trie_index.bin",
            "version.json": PACKAGES_DIR / f"{region}_version.json",
        }
        with zipfile.ZipFile(partial_path) as archive:
            names = set(archive.namelist())
            if not {"version.json", f"{region}.pmtiles", f"{region}.ghz", f"{region}_poi.db"}.issubset(names):
                raise ValueError("Package thiếu một trong các file bản đồ bắt buộc.")
            if any(
                PurePosixPath(name).is_absolute()
                or ".." in PurePosixPath(name).parts
                or name not in outputs
                for name in names
            ):
                raise ValueError("Package chứa tên file ngoài danh sách cho phép.")

            version_data = json.loads(archive.read("version.json").decode("utf-8"))
            if version_data.get("region") != region:
                raise ValueError("version.json trong package không khớp vùng.")
            staged_hashes = {}
            for name, target in outputs.items():
                if name not in names:
                    continue
                entry = version_data.get("files", {}).get(
                    "vector_tiles" if name.endswith(".pmtiles") else
                    "routing_graph" if name.endswith(".ghz") else
                    "poi_db" if name.endswith("_poi.db") else
                    "trie_index" if name.endswith("_trie_index.bin") else "",
                    {},
                )
                staged_file = stage / name
                digest = hashlib.sha256()
                size = 0
                with archive.open(name) as source, staged_file.open("wb") as output:
                    while chunk := source.read(CHUNK_SIZE):
                        digest.update(chunk)
                        size += len(chunk)
                        output.write(chunk)
                staged_hashes[name] = digest.hexdigest()
                if name != "version.json" and (
                    size != entry.get("size_bytes")
                    or staged_hashes[name] != entry.get("sha256")
                ):
                    raise ValueError(f"File {name} không khớp checksum version.json.")

                if target.exists() and not force and sha256_file(target) != staged_hashes[name]:
                    raise FileExistsError(
                        f"{target} đã tồn tại khác với release; dùng --force để thay thế."
                    )

            for name, target in outputs.items():
                if name not in names:
                    continue
                target.parent.mkdir(parents=True, exist_ok=True)
                (stage / name).replace(target)

        partial_path.replace(archive_path)
        print(f"Đã tải, xác minh và cài dữ liệu {region} vào {DATA_DIR}.")
        print(f"Bản ZIP release được giữ tại {archive_path}.")
    finally:
        partial_path.unlink(missing_ok=True)
        if stage.exists():
            shutil.rmtree(stage)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Tải package bản đồ offline đã phát hành và cài vào data-pipeline/data."
    )
    parser.add_argument("--region", default="vietnam", choices=sorted(REGIONS))
    parser.add_argument(
        "--force",
        action="store_true",
        help="Thay file dữ liệu hiện có bằng bản tải từ release.",
    )
    args = parser.parse_args()
    try:
        download_region(args.region, args.force)
    except Exception as error:
        print(f"Lỗi tải dữ liệu: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
