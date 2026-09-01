#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Download a versioned, streamable Overture Places cache for S-Map.

The official overturemaps CLI selects the latest Overture release and streams
the requested bbox from S3.  S-Map stores GeoJSONSeq so the build step can
process a national cache line by line.
"""

import argparse
import importlib.util
import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.append(str(Path(__file__).parent))
from config import OVERTURE_GEOJSONSEQ, OVERTURE_METADATA, REGIONS

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")


def _validate_bbox(value: str) -> str:
    parts = [part.strip() for part in value.split(",")]
    if len(parts) != 4:
        raise argparse.ArgumentTypeError(
            "bbox phải có dạng west,south,east,north"
        )
    try:
        west, south, east, north = (float(part) for part in parts)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("bbox phải chứa 4 số hợp lệ") from exc
    if west >= east or south >= north:
        raise argparse.ArgumentTypeError("bbox phải có west < east và south < north")
    if not (-180 <= west <= 180 and -180 <= east <= 180):
        raise argparse.ArgumentTypeError("kinh độ bbox không hợp lệ")
    if not (-90 <= south <= 90 and -90 <= north <= 90):
        raise argparse.ArgumentTypeError("vĩ độ bbox không hợp lệ")
    return ",".join(parts)


def _find_cli():
    executable = shutil.which("overturemaps")
    if executable:
        return [executable]

    if shutil.which(sys.executable) and importlib.util.find_spec("overturemaps"):
        return [sys.executable, "-m", "overturemaps"]
    return None


def download_places(bbox: str, output: Path, metadata_path: Path, force=False):
    if output.exists() and not force:
        print(f"[SKIP] Overture cache đã tồn tại: {output}")
        return False

    cli = _find_cli()
    if cli is None:
        raise RuntimeError(
            "Chưa cài overturemaps. Hãy chạy: python -m pip install overturemaps"
        )

    output.parent.mkdir(parents=True, exist_ok=True)
    partial_output = output.with_name(output.name + ".part")
    state_output = Path(str(partial_output) + ".state")
    if partial_output.exists():
        partial_output.unlink()
    if state_output.exists():
        state_output.unlink()

    command = [
        *cli,
        "download",
        f"--bbox={bbox}",
        "-f",
        "geojsonseq",
        "--type=place",
        "-o",
        str(partial_output),
    ]
    print("[RUN] " + " ".join(command), flush=True)
    try:
        subprocess.run(command, check=True)
        if not partial_output.exists() or partial_output.stat().st_size == 0:
            raise RuntimeError("Overture CLI không tạo ra file dữ liệu hợp lệ")
        partial_output.replace(output)
        if state_output.exists():
            state_output.unlink()
    except Exception:
        if partial_output.exists():
            partial_output.unlink()
        if state_output.exists():
            state_output.unlink()
        raise

    metadata = {
        "downloaded_at_utc": datetime.now(timezone.utc).isoformat(),
        "bbox": bbox,
        "type": "place",
        "format": "geojsonseq",
        "output": str(output),
        "cli": "overturemaps",
        "selection": "latest release selected by overturemaps CLI",
    }
    metadata_path.parent.mkdir(parents=True, exist_ok=True)
    metadata_path.write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"[OK] Đã lưu Overture cache: {output}")
    print(f"[OK] Đã lưu metadata: {metadata_path}")
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Download Overture Maps Places cache cho S-Map"
    )
    parser.add_argument(
        "--bbox",
        type=_validate_bbox,
        default=REGIONS["vietnam"]["bbox"],
        help="west,south,east,north; mặc định là bbox toàn quốc",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=OVERTURE_GEOJSONSEQ,
        help="File GeoJSONSeq đầu ra",
    )
    parser.add_argument(
        "--metadata",
        type=Path,
        default=OVERTURE_METADATA,
        help="File metadata của lần tải",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Tải lại và ghi đè cache hiện tại",
    )
    args = parser.parse_args()

    try:
        download_places(args.bbox, args.output, args.metadata, force=args.force)
    except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
