#!/usr/bin/env python3
"""Add prominence to an existing S-Map POI database without rebuilding OSM."""

import argparse
import os
import shutil
import sqlite3
import tempfile
from pathlib import Path

from build_poi_database import calculate_prominence


def upgrade_database(db_path: Path) -> int:
    temporary_fd, temporary_name = tempfile.mkstemp(
        prefix=f"{db_path.stem}_", suffix=".db", dir=db_path.parent
    )
    os.close(temporary_fd)
    temporary_path = Path(temporary_name)
    try:
        shutil.copy2(db_path, temporary_path)
        connection = sqlite3.connect(temporary_path)
        try:
            columns = {
                row[1] for row in connection.execute("PRAGMA table_info(poi)")
            }
            if "prominence" not in columns:
                connection.execute(
                    "ALTER TABLE poi ADD COLUMN prominence INTEGER NOT NULL DEFAULT 0"
                )
            rows = connection.execute(
                "SELECT id, name, category, sub_category FROM poi"
            ).fetchall()
            connection.executemany(
                "UPDATE poi SET prominence = ? WHERE id = ?",
                [
                    (
                        calculate_prominence(
                            {"name": name}, category or "", sub_category or ""
                        ),
                        poi_id,
                    )
                    for poi_id, name, category, sub_category in rows
                ],
            )
            connection.commit()
        finally:
            connection.close()
        temporary_path.replace(db_path)
        return len(rows)
    finally:
        if temporary_path.exists():
            temporary_path.unlink()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("db_path", type=Path)
    args = parser.parse_args()
    count = upgrade_database(args.db_path)
    print(f"Upgraded prominence for {count:,} POIs: {args.db_path}")


if __name__ == "__main__":
    main()
