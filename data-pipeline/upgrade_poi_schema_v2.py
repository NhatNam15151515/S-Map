#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Nâng cấp POI database lên schema v2 (tìm kiếm theo phạm vi hành chính).

Giữ nguyên bảng `poi` và `id` của từng POI (trie_index.bin tham chiếu theo id),
chỉ bổ sung:

  poi            + province_code, province_legacy_code, district_code,
                   street_id, street_core, house_no, house_no_main,
                   admin_source, scope
  poi_fts        dựng lại, thêm cột `scope` ("p79 d760 s123") để FTS5 giao
                 posting list theo tỉnh/quận ngay trong inverted index
  admin_unit     tỉnh cũ/mới + quận cũ, có tên không dấu và có dấu
  admin_alias    viết tắt / tên lóng / tên cũ → mã tỉnh
  admin_neighbor tỉnh kề nhau (cho cascade tìm kiếm)
  street         đường gom theo (tỉnh mới, quận cũ, tên đường)
  db_meta        schema_version = 2

Ví dụ:
    python data-pipeline/upgrade_poi_schema_v2.py assets/database/poi.db
    python data-pipeline/upgrade_poi_schema_v2.py \
        data-pipeline/data/output_poi_db/vietnam_poi.db
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import sqlite3
import sys
import tempfile
import time
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import address_normalizer as AN  # noqa: E402

SCHEMA_VERSION = 2

NEW_POI_COLUMNS = (
    ("province_code", "TEXT"),
    ("province_legacy_code", "TEXT"),
    ("district_code", "TEXT"),
    ("street_id", "INTEGER"),
    ("street_core", "TEXT"),
    ("house_no", "TEXT"),
    ("house_no_main", "INTEGER"),
    ("admin_source", "TEXT"),
    ("scope", "TEXT"),
)

_LEADING_HOUSE_RAW = re.compile(r"^\s*(?:số\s*)?\d+[\w]*(?:\s*[/-]\s*\d+\w*)*\s+", re.IGNORECASE)


def new_province_code(gaz: AN.Gazetteer, old_code: str | None) -> str | None:
    """Mã tỉnh mới = mã GSO của tỉnh giữ tên sau sáp nhập 07/2025."""
    name = gaz.new_province_of.get(old_code or "")
    if not name:
        return None
    core, _, _ = AN._split_admin_name(name, AN.PROVINCE_PREFIXES)
    return gaz.province_by_core.get(core) or gaz.province_by_core.get(
        AN.PROVINCE_EXTRA_ALIASES.get(core, "")
    )


def _street_display_name(address: str | None, name: str, category: str | None) -> str:
    if category == "street":
        return name
    first = (address or "").split(",")[0].strip()
    return _LEADING_HOUSE_RAW.sub("", first).strip() or first


def normalize_records(conn: sqlite3.Connection, gaz: AN.Gazetteer):
    """Parse toàn bộ POI, KNN điền khuyết/sửa lệch. Trả về (records, voter, stats)."""
    voter = AN.ProvinceGridVoter()
    records = []
    sql = ("SELECT id, name, category, lat, lon, address, city, street, housenumber "
           "FROM poi")
    for poi_id, name, category, lat, lon, address, city, street, house in conn.execute(sql):
        parsed = AN.parse_address(address or "", city or "", gaz)

        if category == "street":
            core, _ = AN.strip_prefix(AN.normalize(name), ("duong", "pho", "d"))
            parsed.street = core
            parsed.house_no, parsed.house_no_main = "", None
        else:
            # Trường OSM gốc (addr:street / addr:housenumber) đáng tin hơn text.
            if street:
                core, _ = AN.strip_prefix(AN.normalize(street), ("duong", "pho", "d"))
                parsed.street = core or parsed.street
            if house and not parsed.house_no:
                house_norm = re.sub(r"\s+", "", AN.normalize(house))
                main = re.match(r"\d+", house_norm)
                parsed.house_no = house_norm
                parsed.house_no_main = int(main.group()) if main else None

        if parsed.source == "text":
            voter.add(lat, lon, parsed.province_code)
        records.append([poi_id, name, category, lat, lon, address, parsed])

    stats = Counter()
    for rec in records:
        parsed, lat, lon = rec[6], rec[3], rec[4]
        if parsed.source == "none":
            AN.resolve_with_knn(parsed, lat, lon, voter)
        elif parsed.source == "text" and AN.province_conflicts_with_neighbors(
            parsed, lat, lon, voter, gaz.new_province_of
        ):
            # Địa chỉ text mâu thuẫn tọa độ: phạm vi tìm kiếm phải theo vị trí
            # thật trên bản đồ, nên lấy tỉnh theo POI lân cận.
            votes = voter.votes(lat, lon, max_ring=1)
            parsed.province_code = votes.most_common(1)[0][0]
            parsed.district_code = None
            parsed.source = "knn_override"
        stats[parsed.source] += 1
    return records, voter, stats


def compute_neighbors(voter: AN.ProvinceGridVoter, gaz: AN.Gazetteer) -> set[tuple[str, str]]:
    """Hai tỉnh mới là láng giềng nếu có ô lưới kề nhau thuộc hai tỉnh đó."""
    dominant = {}
    for cell, votes in voter._grid.items():
        code, _ = votes.most_common(1)[0]
        new = new_province_code(gaz, code)
        if new:
            dominant[cell] = new
    pairs = set()
    for (cy, cx), prov in dominant.items():
        for dy, dx in ((0, 1), (1, 0), (1, 1), (1, -1)):
            other = dominant.get((cy + dy, cx + dx))
            if other and other != prov:
                pairs.add((prov, other))
                pairs.add((other, prov))
    return pairs


def _write_admin_tables(conn: sqlite3.Connection, gaz: AN.Gazetteer, neighbors):
    cur = conn.cursor()
    cur.executescript("""
        DROP TABLE IF EXISTS admin_unit;
        DROP TABLE IF EXISTS admin_alias;
        DROP TABLE IF EXISTS admin_neighbor;
        CREATE TABLE admin_unit (
            code TEXT NOT NULL,
            level INTEGER NOT NULL,          -- 4 = tỉnh, 6 = quận/huyện (cũ)
            name TEXT NOT NULL,
            name_core TEXT NOT NULL,         -- không dấu, bỏ tiền tố
            accent_core TEXT NOT NULL,       -- có dấu, bỏ tiền tố
            kind TEXT,                       -- quan | huyen | thi xa | thanh pho | tinh
            parent_code TEXT,                -- quận → tỉnh cũ
            successor_code TEXT,             -- tỉnh mới (07/2025)
            successor_name TEXT,
            is_legacy INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (level, code)
        );
        CREATE INDEX idx_admin_core ON admin_unit(level, name_core);
        CREATE TABLE admin_alias (
            alias_core TEXT PRIMARY KEY,     -- "hcm", "sai gon", "binh duong"...
            province_code TEXT NOT NULL      -- mã tỉnh cũ, map tiếp qua successor
        ) WITHOUT ROWID;
        CREATE TABLE admin_neighbor (
            province_code TEXT NOT NULL,
            neighbor_code TEXT NOT NULL,
            PRIMARY KEY (province_code, neighbor_code)
        ) WITHOUT ROWID;
    """)

    rows = []
    for code, unit in gaz.provinces.items():
        succ = new_province_code(gaz, code)
        rows.append((code, 4, unit.name, unit.core, unit.accent_core, "tinh", None,
                     succ, gaz.new_province_of.get(code), int(succ != code)))
    for units in gaz.districts_by_core.values():
        for u in units:
            rows.append((u.code, 6, u.name, u.core, u.accent_core, u.kind,
                         u.province_code, new_province_code(gaz, u.province_code), None, 1))
    cur.executemany("INSERT INTO admin_unit VALUES (?,?,?,?,?,?,?,?,?,?)", rows)

    unit_cores = {u.core for u in gaz.provinces.values()}
    aliases = [(core, code) for core, code in gaz.province_by_core.items()
               if core not in unit_cores]
    cur.executemany("INSERT OR IGNORE INTO admin_alias VALUES (?,?)", aliases)
    cur.executemany("INSERT INTO admin_neighbor VALUES (?,?)", sorted(neighbors))


def _ensure_poi_columns(conn: sqlite3.Connection):
    existing = {row[1] for row in conn.execute("PRAGMA table_info(poi)")}
    for column, col_type in NEW_POI_COLUMNS:
        if column not in existing:
            conn.execute(f"ALTER TABLE poi ADD COLUMN {column} {col_type}")


def _rebuild_fts(conn: sqlite3.Connection):
    conn.executescript("""
        DROP TRIGGER IF EXISTS poi_ai;
        DROP TABLE IF EXISTS poi_fts;
        CREATE VIRTUAL TABLE poi_fts USING fts5(
            name,
            name_ascii,
            category,
            address,
            address_ascii,
            admin_aliases,
            scope,
            content='poi',
            content_rowid='id'
        );
        INSERT INTO poi_fts(poi_fts) VALUES('rebuild');
        INSERT INTO poi_fts(poi_fts) VALUES('optimize');
        CREATE TRIGGER poi_ai AFTER INSERT ON poi BEGIN
            INSERT INTO poi_fts(rowid, name, name_ascii, category, address,
                                address_ascii, admin_aliases, scope)
            VALUES (new.id, new.name, new.name_ascii, new.category, new.address,
                    new.address_ascii, new.admin_aliases, new.scope);
        END;
    """)


def upgrade_connection(conn: sqlite3.Connection, gaz: AN.Gazetteer) -> dict:
    t0 = time.time()
    print("  ⏳ Chuẩn hóa địa chỉ...")
    records, voter, stats = normalize_records(conn, gaz)
    t_parse = time.time() - t0

    print("  ⏳ Gom đường + ghi cột mới...")
    street_ids: dict[tuple, int] = {}
    street_agg: dict[int, dict] = {}
    updates = []
    for poi_id, name, category, lat, lon, address, p in records:
        prov_new = new_province_code(gaz, p.province_code)
        sid = None
        if p.street and prov_new:
            key = (prov_new, p.district_code, p.street)
            sid = street_ids.get(key)
            if sid is None:
                sid = street_ids[key] = len(street_ids) + 1
                street_agg[sid] = {
                    "names": Counter(), "n": 0, "houses": 0,
                    "lat": 0.0, "lon": 0.0,
                    "min_lat": lat, "max_lat": lat, "min_lon": lon, "max_lon": lon,
                }
            agg = street_agg[sid]
            agg["names"][_street_display_name(address, name, category)] += 1
            agg["n"] += 1
            agg["houses"] += bool(p.house_no)
            agg["lat"] += lat
            agg["lon"] += lon
            agg["min_lat"] = min(agg["min_lat"], lat)
            agg["max_lat"] = max(agg["max_lat"], lat)
            agg["min_lon"] = min(agg["min_lon"], lon)
            agg["max_lon"] = max(agg["max_lon"], lon)

        scope = " ".join(t for t in (
            f"p{prov_new}" if prov_new else "",
            f"lp{p.province_code}" if p.province_code and p.province_code != prov_new else "",
            f"d{p.district_code}" if p.district_code else "",
            f"s{sid}" if sid else "",
        ) if t)
        updates.append((
            prov_new, p.province_code, p.district_code, sid, p.street or None,
            p.house_no or None, p.house_no_main, p.source, scope or None, poi_id,
        ))

    _ensure_poi_columns(conn)
    conn.executemany("""
        UPDATE poi SET province_code = ?, province_legacy_code = ?, district_code = ?,
                       street_id = ?, street_core = ?, house_no = ?, house_no_main = ?,
                       admin_source = ?, scope = ?
        WHERE id = ?
    """, updates)

    conn.executescript("""
        DROP TABLE IF EXISTS street;
        CREATE TABLE street (
            id INTEGER PRIMARY KEY,
            province_code TEXT NOT NULL,
            district_code TEXT,
            name TEXT NOT NULL,
            name_core TEXT NOT NULL,
            poi_count INTEGER NOT NULL,
            house_count INTEGER NOT NULL,
            center_lat REAL NOT NULL, center_lon REAL NOT NULL,
            min_lat REAL, max_lat REAL, min_lon REAL, max_lon REAL
        );
    """)
    street_rows = []
    for (prov, dist, core), sid in street_ids.items():
        a = street_agg[sid]
        street_rows.append((
            sid, prov, dist, a["names"].most_common(1)[0][0], core, a["n"], a["houses"],
            a["lat"] / a["n"], a["lon"] / a["n"],
            a["min_lat"], a["max_lat"], a["min_lon"], a["max_lon"],
        ))
    conn.executemany("INSERT INTO street VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)", street_rows)

    print("  ⏳ Bảng hành chính + láng giềng...")
    neighbors = compute_neighbors(voter, gaz)
    _write_admin_tables(conn, gaz, neighbors)

    print("  ⏳ Index...")
    conn.executescript("""
        DROP INDEX IF EXISTS idx_poi_street_house;
        DROP INDEX IF EXISTS idx_poi_province_cat;
        CREATE INDEX idx_poi_street_house ON poi(street_id, house_no_main);
        CREATE INDEX idx_poi_province_cat ON poi(province_code, category);
        CREATE INDEX idx_street_province ON street(province_code, name_core);
        CREATE INDEX idx_street_district ON street(district_code, name_core);
    """)

    print("  ⏳ Dựng lại FTS5 với cột scope...")
    _rebuild_fts(conn)

    conn.executescript("""
        DROP TABLE IF EXISTS db_meta;
        CREATE TABLE db_meta (key TEXT PRIMARY KEY, value TEXT) WITHOUT ROWID;
    """)
    meta = {
        "schema_version": str(SCHEMA_VERSION),
        "upgraded_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "poi_count": str(len(records)),
        "street_count": str(len(street_rows)),
        "neighbor_pairs": str(len(neighbors) // 2),
        **{f"admin_source_{k}": str(v) for k, v in stats.items()},
    }
    conn.executemany("INSERT INTO db_meta VALUES (?, ?)", meta.items())
    conn.commit()
    conn.execute("ANALYZE")
    conn.commit()

    return {
        "records": len(records), "streets": len(street_rows),
        "neighbor_pairs": len(neighbors) // 2, "stats": dict(stats),
        "t_parse": t_parse, "t_total": time.time() - t0,
    }


def upgrade_database(db_path: Path, gaz: AN.Gazetteer | None = None,
                     vacuum: bool = True) -> dict:
    """Nâng cấp trên bản sao tạm rồi thay thế nguyên tử, tránh hỏng DB gốc."""
    gaz = gaz or AN.load_gazetteer(AN.DEFAULT_GAZETTEER, AN.DEFAULT_ALIASES)
    fd, tmp_name = tempfile.mkstemp(prefix=f"{db_path.stem}_v2_", suffix=".db",
                                    dir=db_path.parent)
    os.close(fd)
    tmp_path = Path(tmp_name)
    try:
        shutil.copy2(db_path, tmp_path)
        conn = sqlite3.connect(tmp_path)
        try:
            conn.execute("PRAGMA journal_mode = OFF")
            conn.execute("PRAGMA synchronous = OFF")
            conn.execute("PRAGMA temp_store = MEMORY")
            conn.execute("PRAGMA cache_size = -400000")
            result = upgrade_connection(conn, gaz)
            if vacuum:
                print("  ⏳ VACUUM...")
                conn.execute("VACUUM")
            conn.execute("PRAGMA journal_mode = DELETE")
        finally:
            conn.close()
        tmp_path.replace(db_path)
        return result
    finally:
        if tmp_path.exists():
            tmp_path.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("db_paths", type=Path, nargs="+")
    parser.add_argument("--no-vacuum", action="store_true")
    args = parser.parse_args()

    gaz = AN.load_gazetteer(AN.DEFAULT_GAZETTEER, AN.DEFAULT_ALIASES)
    for db_path in args.db_paths:
        size_before = db_path.stat().st_size
        print(f"🔧 {db_path} ({size_before / 1024 / 1024:.1f} MB)")
        r = upgrade_database(db_path, gaz, vacuum=not args.no_vacuum)
        size_after = db_path.stat().st_size
        print(
            f"✅ {r['records']:,} POI, {r['streets']:,} đường, "
            f"{r['neighbor_pairs']} cặp tỉnh kề, nguồn={r['stats']} | "
            f"{size_before / 1024 / 1024:.1f} → {size_after / 1024 / 1024:.1f} MB | "
            f"{r['t_total']:.0f}s"
        )


if __name__ == "__main__":
    main()
