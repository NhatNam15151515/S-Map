#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
S-Map Address Normalizer: tách địa chỉ POI thành các field hành chính.

Mục tiêu: biến cặp (address, city) vốn lẫn cấp của OSM/Overture thành
    house_no | street | district (cũ) | province (cũ) | province (mới 2025)
để repository có thể query theo phạm vi tỉnh → quận → đường → số nhà.

Chiến lược:
1. Gazetteer: dựng từ assets/address/db.json (63 tỉnh / 705 quận cũ) và
   admin_aliases.json (34 tỉnh mới). Hệ mới là chuẩn, hệ cũ là fallback.
2. Text parsing: tách theo dấu câu và tiền tố hành chính, quét phải → trái.
   Đoạn trông như tên đường ("12 Lê Lợi", "Đường Hòa Bình") không bao giờ
   được dùng để nhận diện tỉnh/quận. Tỉnh ghi trong address thắng city.
3. Dấu tiếng Việt là tín hiệu phân biệt: nếu input có dấu thì tên hành chính
   phải khớp cả dấu ("Thạnh Trị" ≠ "Thanh Trì"). Loại đơn vị theo tiền tố
   ("Quận Tân Phú" ≠ "Huyện Tân Phú").
4. KNN theo lưới tọa độ: các POI đã có tỉnh rõ ràng làm nhãn; dùng để
   (a) chọn đúng tỉnh khi tên quận trùng giữa nhiều tỉnh ("Châu Thành"),
   (b) suy tỉnh cho POI không có text hành chính.

Chế độ hiện tại: dry-run, chỉ đọc DB và xuất báo cáo chất lượng.

Ví dụ:
    python data-pipeline/address_normalizer.py \
        --db data-pipeline/data/output_poi_db/vietnam_poi.db
"""

from __future__ import annotations

import argparse
import json
import random
import re
import sqlite3
import sys
import time
import unicodedata
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

PIPELINE_DIR = Path(__file__).parent
PROJECT_DIR = PIPELINE_DIR.parent
DEFAULT_GAZETTEER = PROJECT_DIR / "assets" / "address" / "db.json"
DEFAULT_ALIASES = PIPELINE_DIR / "admin_aliases.json"
DEFAULT_DB = PIPELINE_DIR / "data" / "output_poi_db" / "vietnam_poi.db"
DEFAULT_REPORT_DIR = PIPELINE_DIR / "data" / "reports"

# ---------------------------------------------------------------------------
# Hằng số — phải giữ đồng bộ với AddressParser bên Dart.
# ---------------------------------------------------------------------------

PROVINCE_PREFIXES = ("thanh pho", "tinh", "tp")
DISTRICT_PREFIXES = ("thanh pho", "thi xa", "quan", "huyen", "tp", "tx", "q", "h")
STREET_PREFIXES = (
    "duong", "pho", "d", "hem", "ngo", "ngach", "kiet", "ql", "quoc lo",
    "tinh lo", "dt", "dai lo", "tl",
)

# Tiền tố người dùng gõ → tiền tố tên đơn vị trong gazetteer.
DISTRICT_KIND = {
    "quan": "quan", "q": "quan",
    "huyen": "huyen", "h": "huyen",
    "thi xa": "thi xa", "tx": "thi xa",
    "thanh pho": "thanh pho", "tp": "thanh pho",
}

# Viết tắt / tên lóng → tên tỉnh chuẩn (core không dấu).
PROVINCE_EXTRA_ALIASES = {
    "hcm": "ho chi minh",
    "tphcm": "ho chi minh",
    "hcmc": "ho chi minh",
    "sai gon": "ho chi minh",
    "saigon": "ho chi minh",
    "sg": "ho chi minh",
    "ho chi minh city": "ho chi minh",
    "hn": "ha noi",
    "hanoi": "ha noi",
    "brvt": "ba ria vung tau",
    "vung tau": "ba ria vung tau",
    "hue": "thua thien hue",
    "da nang city": "da nang",
}

# Quận cũ đã bị sáp nhập trước khi db.json được chụp → đơn vị kế nhiệm.
DISTRICT_LEGACY_ALIASES = {
    ("ho chi minh", "2"): "thu duc",
    ("ho chi minh", "9"): "thu duc",
}

# Tách đoạn tại tiền tố hành chính nằm giữa chuỗi (khi người dùng không dùng
# dấu phẩy). Bản có dấu luôn an toàn; bản không dấu chỉ dùng khi cả chuỗi
# không có dấu, để tránh "Phố Quán Thánh" bị cắt ở "quan".
_EMBEDDED_ADMIN_ACCENTED = re.compile(
    r"[\s.]+(?=(?:phường|quận|huyện|thị xã|thị trấn|thành phố|tỉnh(?!\s+lộ))\s)"
)
_EMBEDDED_ADMIN_PLAIN = re.compile(
    r"[\s.]+(?=(?:phuong|quan|huyen|thi xa|thi tran|thanh pho|tinh(?!\s+lo))\s)"
)

_HOUSE_TOKEN = r"\d+[a-z]?(?:\s*[/-]\s*\d+[a-z]?)*"
_HOUSE_RE = re.compile(rf"^(?:so\s+)?({_HOUSE_TOKEN})\s+(.+)$")
_HOUSE_ONLY_RE = re.compile(rf"^(?:so\s+)?({_HOUSE_TOKEN})$")
_ABBREV_NUM_RE = re.compile(r"\b(q|p)\s*(\d{1,2})\b")

# Hai kiểu bỏ dấu thanh (cũ "hoà" / mới "hòa") → quy về một dạng.
_TONE_FIX = {
    "oà": "òa", "oá": "óa", "oả": "ỏa", "oã": "õa", "oạ": "ọa",
    "oè": "òe", "oé": "óe", "oẻ": "ỏe", "oẽ": "õe", "oẹ": "ọe",
    "uỳ": "ùy", "uý": "úy", "uỷ": "ủy", "uỹ": "ũy", "uỵ": "ụy",
}


# ---------------------------------------------------------------------------
# Chuẩn hóa text
# ---------------------------------------------------------------------------


def strip_accents(text: str) -> str:
    if not text:
        return ""
    text = unicodedata.normalize("NFD", text)
    text = "".join(c for c in text if unicodedata.category(c) != "Mn")
    return text.replace("đ", "d").replace("Đ", "D")


def tone_lower(text: str) -> str:
    """Lowercase + NFC + thống nhất vị trí dấu thanh; giữ nguyên dấu."""
    text = unicodedata.normalize("NFC", text or "").lower()
    text = re.sub(r"\([^)]*\)", " ", text)  # "(đối diện trường cấp 2)"
    for old, new in _TONE_FIX.items():
        text = text.replace(old, new)
    text = text.replace("–", "-").replace("—", "-")
    text = re.sub(r"(?<=\w)-(?=[^\W\d])", " ", text)  # Phan Rang-Tháp Chàm
    return re.sub(r"\s+", " ", text).strip()


def has_marks(text: str) -> bool:
    return strip_accents(text) != text


def normalize(text: str) -> str:
    """Bỏ dấu, lowercase, chuẩn hóa dấu câu; giữ '/' và '-' cho số nhà."""
    text = strip_accents(tone_lower(text))
    text = re.sub(r"[.\u00b7]", " ", text)
    text = re.sub(r"[^a-z0-9/\- ]+", " ", text)
    text = _ABBREV_NUM_RE.sub(r"\1 \2", text)  # q1 → q 1, p.12 → p 12
    return re.sub(r"\s+", " ", text).strip(" -")


def strip_prefix(core: str, prefixes) -> tuple[str, str | None]:
    """Trả về (phần còn lại, tiền tố khớp) — tiền tố dài được thử trước."""
    for prefix in sorted(prefixes, key=len, reverse=True):
        if core == prefix:
            return "", prefix
        if core.startswith(prefix + " "):
            return core[len(prefix) + 1:].strip(), prefix
    return core, None


@dataclass
class Segment:
    raw: str   # có dấu, lowercase (để kiểm tra dấu)
    norm: str  # không dấu

    @property
    def marked(self) -> bool:
        return has_marks(self.raw)


def split_segments(text: str) -> list[Segment]:
    text = tone_lower(text)
    if not text:
        return []
    parts = re.split(r",|;|\|| - ", text)
    embedded = _EMBEDDED_ADMIN_ACCENTED if has_marks(text) else _EMBEDDED_ADMIN_PLAIN
    segments: list[Segment] = []
    for part in parts:
        for piece in embedded.split(part):
            piece = piece.strip(" .")
            norm = normalize(piece)
            if norm:
                segments.append(Segment(piece, norm))
    # "9, Đường Điện Biên Phủ" → gộp số nhà đứng riêng vào đoạn sau.
    if len(segments) >= 2 and _HOUSE_ONLY_RE.match(segments[0].norm):
        first, second = segments[0], segments[1]
        segments[:2] = [Segment(f"{first.raw} {second.raw}", f"{first.norm} {second.norm}")]
    return segments


def is_street_like(norm: str) -> bool:
    if _HOUSE_RE.match(norm):
        return True
    _, prefix = strip_prefix(norm, STREET_PREFIXES)
    return prefix is not None


# ---------------------------------------------------------------------------
# Gazetteer
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class AdminUnit:
    level: str  # "province" | "district"
    code: str
    name: str
    core: str          # không dấu, bỏ tiền tố
    accent_core: str   # có dấu, bỏ tiền tố
    kind: str          # tiền tố chuẩn: "quan", "huyen", "thi xa", "thanh pho", "tinh"
    province_code: str


@dataclass
class Gazetteer:
    provinces: dict[str, AdminUnit] = field(default_factory=dict)
    province_by_core: dict[str, str] = field(default_factory=dict)
    # Các dạng có dấu hợp lệ của từng tỉnh (tên cũ + tên trong alias).
    province_accents: dict[str, set[str]] = field(
        default_factory=lambda: defaultdict(set)
    )
    districts_by_core: dict[str, list[AdminUnit]] = field(
        default_factory=lambda: defaultdict(list)
    )
    new_province_of: dict[str, str] = field(default_factory=dict)
    max_province_tokens: int = 1


def _split_admin_name(name: str, prefixes) -> tuple[str, str, str]:
    """'Quận Tân Phú' → ('tan phu', 'tân phú', 'quan')."""
    accented = tone_lower(name)
    norm = normalize(accented)
    core, prefix = strip_prefix(norm, prefixes)
    accent_words = accented.split()
    accent_core = " ".join(accent_words[len(prefix.split()):]) if prefix else accented
    return core, accent_core, prefix or ""


def load_gazetteer(db_json: Path, aliases_json: Path) -> Gazetteer:
    payload = json.loads(db_json.read_text(encoding="utf-8"))
    gaz = Gazetteer()

    for item in payload["province"]:
        core, accent_core, kind = _split_admin_name(item["name"], PROVINCE_PREFIXES)
        unit = AdminUnit("province", item["idProvince"], item["name"], core,
                         accent_core, kind, item["idProvince"])
        gaz.provinces[unit.code] = unit
        gaz.province_by_core[core] = unit.code
        gaz.province_by_core[core.replace(" ", "")] = unit.code
        gaz.province_accents[unit.code].add(accent_core)

    for alias, target in PROVINCE_EXTRA_ALIASES.items():
        if target in gaz.province_by_core:
            gaz.province_by_core[alias] = gaz.province_by_core[target]

    for item in payload["district"]:
        core, accent_core, kind = _split_admin_name(item["name"], DISTRICT_PREFIXES)
        unit = AdminUnit("district", item["idDistrict"], item["name"], core,
                         accent_core, DISTRICT_KIND.get(kind, kind), item["idProvince"])
        gaz.districts_by_core[core].append(unit)

    groups = json.loads(aliases_json.read_text(encoding="utf-8")).get("groups", [])
    for group in groups:
        canonical = group["canonical"]
        for name in [canonical, *group.get("aliases", [])]:
            core, accent_core, _ = _split_admin_name(name, PROVINCE_PREFIXES)
            code = gaz.province_by_core.get(core) or gaz.province_by_core.get(
                PROVINCE_EXTRA_ALIASES.get(core, "")
            )
            if code:
                gaz.new_province_of.setdefault(code, canonical)
                if has_marks(accent_core):
                    gaz.province_accents[code].add(accent_core)

    gaz.max_province_tokens = max(len(c.split()) for c in gaz.province_by_core)
    return gaz


# ---------------------------------------------------------------------------
# Parser
# ---------------------------------------------------------------------------


@dataclass
class ParsedAddress:
    house_no: str = ""
    house_no_main: int | None = None
    street: str = ""
    district_code: str | None = None
    province_code: str | None = None
    # Tỉnh ứng viên khi tên quận trùng giữa nhiều tỉnh, chờ KNN xử lý.
    province_candidates: tuple[str, ...] = ()
    source: str = "none"  # text | text+knn | knn | none


def _accent_ok(raw: str, accents: set[str] | str) -> bool:
    """Input không dấu → luôn chấp nhận; có dấu → phải chứa đúng dạng có dấu."""
    if not has_marks(raw):
        return True
    if isinstance(accents, str):
        accents = {accents}
    return any(a in raw for a in accents if a)


def _match_province(seg: Segment, gaz: Gazetteer) -> str | None:
    rest, _ = strip_prefix(seg.norm, PROVINCE_PREFIXES)
    code = gaz.province_by_core.get(rest) or gaz.province_by_core.get(rest.replace(" ", ""))
    if code and rest not in PROVINCE_EXTRA_ALIASES and not _accent_ok(
        seg.raw, gaz.province_accents[code]
    ):
        return None
    return code


def _province_suffix(seg: Segment, gaz: Gazetteer) -> str | None:
    """'12 Trần Phú Thủ Dầu Một Bình Dương' → Bình Dương.

    Chỉ nhận tên tỉnh ≥ 2 từ, và phần còn lại vẫn phải là một tên đường
    có nghĩa (≥ 2 từ sau khi bỏ số nhà/tiền tố), để "154 Đường Tuyên Quang"
    hay "Xã Thạnh Hóa" không bị nhận nhầm.
    """
    tokens = seg.norm.split()
    for n in range(min(gaz.max_province_tokens, len(tokens) - 1), 1, -1):
        tail = " ".join(tokens[-n:])
        code = gaz.province_by_core.get(tail)
        if not code or not _accent_ok(seg.raw, gaz.province_accents[code]):
            continue
        house, _, street = _parse_house_street(" ".join(tokens[:-n]))
        remainder = street if house else " ".join(tokens[:-n])
        remainder, _ = strip_prefix(remainder, STREET_PREFIXES)
        if len(remainder.split()) >= 2 and not remainder.startswith(("xa ", "phuong ")):
            return code
    return None


def _district_units(seg: Segment, gaz: Gazetteer, province_code: str | None,
                    allow_unprefixed: bool) -> list[AdminUnit]:
    core, prefix = strip_prefix(seg.norm, DISTRICT_PREFIXES)
    if not core:
        return []
    if core.isdigit() and prefix not in ("quan", "q"):
        return []  # "1", "phuong 9" không phải quận
    if prefix is None and not allow_unprefixed:
        return []
    numeric = core.isdigit()
    if province_code:
        alias = DISTRICT_LEGACY_ALIASES.get((gaz.provinces[province_code].core, core))
        core = alias or core
    elif core.isdigit():
        alias = DISTRICT_LEGACY_ALIASES.get(("ho chi minh", core))
        core = alias or core
    units = gaz.districts_by_core.get(core, [])
    if not units:
        return []
    if province_code:
        units = [u for u in units if u.province_code == province_code]
    kind = DISTRICT_KIND.get(prefix or "")
    if kind:
        same_kind = [u for u in units if u.kind == kind]
        units = same_kind or units
    if seg.marked:
        units = [u for u in units if u.accent_core in seg.raw] or (
            [] if not numeric else units
        )
    return units


def _parse_house_street(segment: str) -> tuple[str, int | None, str]:
    match = _HOUSE_RE.match(segment)
    if match:
        house = re.sub(r"\s+", "", match.group(1))
        main = int(re.match(r"\d+", house).group())
        street, _ = strip_prefix(match.group(2), ("duong", "pho", "d"))
        return house, main, street
    street, prefix = strip_prefix(segment, ("duong", "pho", "d"))
    return "", None, street if prefix else ""


def parse_address(address: str, city: str, gaz: Gazetteer) -> ParsedAddress:
    result = ParsedAddress()
    addr_segs = split_segments(address)
    city_segs = [s for s in split_segments(city)
                 if s.norm not in {a.norm for a in addr_segs}]

    street_idx = {i for i, s in enumerate(addr_segs) if is_street_like(s.norm)}
    # Thứ tự ưu tiên: address (phải → trái, bỏ đoạn tên đường) rồi tới city.
    admin_order: list[tuple[str, int, Segment]] = [
        ("addr", i, addr_segs[i])
        for i in range(len(addr_segs) - 1, -1, -1) if i not in street_idx
    ] + [("city", i, s) for i, s in reversed(list(enumerate(city_segs)))]

    used: set[tuple[str, int]] = set()

    # Lượt 1: tỉnh.
    for src, i, seg in admin_order:
        code = _match_province(seg, gaz)
        if code:
            result.province_code = code
            used.add((src, i))
            break
    if not result.province_code:
        for seg in reversed(addr_segs):
            code = _province_suffix(seg, gaz)
            if code:
                result.province_code = code
                break

    # Lượt 2: quận/huyện cũ, theo 3 mức tin cậy giảm dần:
    #   (1) đoạn address có tiền tố ("Quận 1", "Huyện Củ Chi")
    #   (2) trường city
    #   (3) đoạn address không tiền tố ("Gò Vấp") — dễ trùng tên xã/địa danh.
    def has_district_prefix(seg: Segment) -> bool:
        return strip_prefix(seg.norm, DISTRICT_PREFIXES)[1] is not None

    district_order = (
        [t for t in admin_order if t[0] == "addr" and has_district_prefix(t[2])]
        + [t for t in admin_order if t[0] == "city"]
        + [t for t in admin_order if t[0] == "addr" and not has_district_prefix(t[2])]
    )
    for src, i, seg in district_order:
        if (src, i) in used:
            continue
        # Đoạn không tiền tố chỉ được coi là quận nếu không phải đoạn đầu của
        # address (thường là tên đường/địa danh nhỏ) hoặc nằm trong city.
        allow_unprefixed = src == "city" or i > 0 or len(addr_segs) == 1
        units = _district_units(seg, gaz, result.province_code, allow_unprefixed)
        if not units:
            continue
        used.add((src, i))
        provinces = sorted({u.province_code for u in units})
        if len(units) == 1:
            result.district_code = units[0].code
            result.province_code = result.province_code or units[0].province_code
        elif len(provinces) == 1:
            result.province_code = result.province_code or provinces[0]
        elif not result.province_code:
            result.province_candidates = tuple(provinces)
        break

    # Lượt 3: số nhà + đường từ đoạn đầu tiên chưa dùng của address.
    for i, seg in enumerate(addr_segs):
        if ("addr", i) in used:
            continue
        house, main, street = _parse_house_street(seg.norm)
        if house or street:
            result.house_no, result.house_no_main, result.street = house, main, street
        break

    # "733 Quang Trung Chư Ty Đức Cơ Gia Lai" → cắt tên tỉnh/quận dính ở đuôi.
    if result.street:
        tails = []
        if result.province_code:
            tails.append(gaz.provinces[result.province_code].core)
        if result.district_code:
            tails += [u.core for us in gaz.districts_by_core.values() for u in us
                      if u.code == result.district_code]
        changed = True
        while changed:
            changed = False
            for tail in tails:
                if result.street.endswith(" " + tail) and len(result.street) > len(tail) + 1:
                    result.street = result.street[: -len(tail) - 1].strip()
                    changed = True

    if result.province_code:
        result.source = "text"
    return result


# ---------------------------------------------------------------------------
# KNN theo lưới tọa độ
# ---------------------------------------------------------------------------

GRID_DEG = 0.02  # ~2.2 km


def _cell(lat: float, lon: float) -> tuple[int, int]:
    return int(lat // GRID_DEG), int(lon // GRID_DEG)


class ProvinceGridVoter:
    def __init__(self):
        self._grid: dict[tuple[int, int], Counter] = defaultdict(Counter)

    def add(self, lat: float, lon: float, province_code: str):
        self._grid[_cell(lat, lon)][province_code] += 1

    def votes(self, lat: float, lon: float, max_ring: int = 3) -> Counter:
        """Mở rộng vòng lưới tới khi có đủ phiếu (tối đa ~15 km)."""
        cy, cx = _cell(lat, lon)
        total = Counter()
        for ring in range(max_ring + 1):
            for dy in range(-ring, ring + 1):
                for dx in range(-ring, ring + 1):
                    if max(abs(dy), abs(dx)) != ring:
                        continue
                    total.update(self._grid.get((cy + dy, cx + dx), {}))
            if sum(total.values()) >= 15:
                break
        return total


def resolve_with_knn(parsed: ParsedAddress, lat, lon, voter: ProvinceGridVoter,
                     min_share: float = 0.6):
    votes = voter.votes(lat, lon)
    if not votes:
        return
    if parsed.province_candidates:
        best = max(parsed.province_candidates, key=lambda c: votes.get(c, 0))
        if votes.get(best, 0) > 0:
            parsed.province_code = best
            parsed.source = "text+knn"
        return
    code, count = votes.most_common(1)[0]
    if count / sum(votes.values()) >= min_share:
        parsed.province_code = code
        parsed.source = "knn"


def province_conflicts_with_neighbors(parsed: ParsedAddress, lat, lon,
                                      voter: ProvinceGridVoter,
                                      new_province_of: dict[str, str],
                                      min_votes: int = 30,
                                      max_share: float = 0.02) -> bool:
    """Nhãn text mà gần như không POI lân cận nào cùng tỉnh MỚI → nghi sai.

    So theo tỉnh mới để "Dĩ An, Bình Dương" sát TP.HCM không bị coi là lệch.
    """
    votes = voter.votes(lat, lon, max_ring=1)
    total = sum(votes.values())
    if total < min_votes:
        return False
    target = new_province_of.get(parsed.province_code)
    same = sum(n for code, n in votes.items() if new_province_of.get(code) == target)
    return same / total < max_share


# ---------------------------------------------------------------------------
# Dry-run report
# ---------------------------------------------------------------------------


def run_dry_run(db_path: Path, gaz: Gazetteer, report_dir: Path, limit: int | None,
                sample_size: int = 200, seed: int = 42):
    started = time.time()
    conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    sql = "SELECT id, osm_id, address, city, lat, lon, category FROM poi"
    if limit:
        sql += f" LIMIT {int(limit)}"

    rows = []
    voter = ProvinceGridVoter()
    unmatched_city = Counter()
    ambiguous_district = Counter()

    print("⏳ Lượt 1: tách text...")
    for poi_id, osm_id, address, city, lat, lon, category in conn.execute(sql):
        parsed = parse_address(address or "", city or "", gaz)
        if parsed.source == "text":
            voter.add(lat, lon, parsed.province_code)
        else:
            if city:
                unmatched_city[city.strip()] += 1
            if parsed.province_candidates:
                ambiguous_district[", ".join(parsed.province_candidates)] += 1
        rows.append((poi_id, osm_id, address, city, lat, lon, category, parsed))
    conn.close()
    t_text = time.time() - started

    print("⏳ Lượt 2: KNN cho bản ghi thiếu/mơ hồ + phát hiện nhãn lệch...")
    conflicts = []
    for row in rows:
        parsed = row[7]
        if parsed.source == "none":
            resolve_with_knn(parsed, row[4], row[5], voter)
        elif parsed.source == "text" and province_conflicts_with_neighbors(
            parsed, row[4], row[5], voter, gaz.new_province_of
        ):
            conflicts.append(row)
    t_total = time.time() - started

    total = len(rows)
    source_counts = Counter(r[7].source for r in rows)
    with_district = sum(1 for r in rows if r[7].district_code)
    with_house = sum(1 for r in rows if r[7].house_no)
    with_street = sum(1 for r in rows if r[7].street)
    new_province_counts = Counter(
        gaz.new_province_of.get(r[7].province_code, "?")
        for r in rows if r[7].province_code
    )
    unmapped_old = sorted(code for code in gaz.provinces if code not in gaz.new_province_of)
    district_names = {
        u.code: u.name for units in gaz.districts_by_core.values() for u in units
    }

    def pct(n):
        return f"{n:,} ({n * 100 / max(total, 1):.1f}%)"

    def row_cells(row):
        _, osm_id, address, city, _, _, _, p = row
        province = gaz.provinces.get(p.province_code)
        cells = [
            osm_id, address or "", city or "", p.house_no, p.street,
            district_names.get(p.district_code, ""),
            province.name if province else "",
            gaz.new_province_of.get(p.province_code, ""),
            p.source,
        ]
        return "| " + " | ".join(str(c).replace("|", "/") for c in cells) + " |"

    table_header = [
        "| osm_id | address | city | → số nhà | → đường | → quận cũ | → tỉnh cũ | → tỉnh mới | nguồn |",
        "|---|---|---|---|---|---|---|---|---|",
    ]

    lines = [
        "# Báo cáo chuẩn hóa địa chỉ (dry-run)",
        "",
        f"- DB: `{db_path.name}`: {total:,} bản ghi",
        f"- Thời gian: tách text {t_text:.1f}s, tổng {t_total:.1f}s",
        "",
        "## Độ phủ",
        "",
        "| Chỉ số | Giá trị |",
        "|---|---|",
        f"| Có tỉnh (tổng) | {pct(total - source_counts['none'])} |",
        f"| └ từ text | {pct(source_counts['text'])} |",
        f"| └ text + KNN (gỡ trùng tên) | {pct(source_counts['text+knn'])} |",
        f"| └ chỉ KNN | {pct(source_counts['knn'])} |",
        f"| Không xác định | {pct(source_counts['none'])} |",
        f"| Nhãn text lệch với hàng xóm (nghi sai) | {pct(len(conflicts))} |",
        f"| Có quận/huyện cũ | {pct(with_district)} |",
        f"| Tách được số nhà | {pct(with_house)} |",
        f"| Tách được tên đường | {pct(with_street)} |",
        "",
        f"Tỉnh cũ chưa map sang tỉnh mới: {unmapped_old or 'không có'}",
        "",
        "## Phân bố theo tỉnh mới (34)",
        "",
        "| Tỉnh mới | Số POI |",
        "|---|---|",
        *[f"| {name} | {count:,} |" for name, count in new_province_counts.most_common()],
        "",
        "## Top 50 giá trị `city` không khớp gazetteer",
        "",
        "| city | Số lần |",
        "|---|---|",
        *[f"| {name} | {count:,} |" for name, count in unmatched_city.most_common(50)],
        "",
        "## Top tên quận trùng nhiều tỉnh (cần KNN)",
        "",
        *[f"- {names}: {count:,}" for names, count in ambiguous_district.most_common(15)],
        "",
        "## 40 mẫu nhãn text lệch với hàng xóm",
        "",
        *table_header,
    ]
    rng = random.Random(seed)
    for row in rng.sample(conflicts, min(40, len(conflicts))):
        lines.append(row_cells(row))
    lines += ["", f"## {sample_size} mẫu ngẫu nhiên", "", *table_header]
    for row in rng.sample(rows, min(sample_size, total)):
        lines.append(row_cells(row))

    report_dir.mkdir(parents=True, exist_ok=True)
    report_path = report_dir / f"address_normalizer_{db_path.stem}.md"
    report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"✅ Xong {total:,} bản ghi trong {t_total:.1f}s")
    for key in ("text", "text+knn", "knn", "none"):
        print(f"   {key:9s} {pct(source_counts[key])}")
    print(f"   lệch      {pct(len(conflicts))}")
    print(f"   quận cũ   {pct(with_district)}")
    print(f"   số nhà    {pct(with_house)}")
    print(f"   đường     {pct(with_street)}")
    print(f"📝 Báo cáo: {report_path}")
    return report_path


def main():
    parser = argparse.ArgumentParser(description="S-Map address normalizer")
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--gazetteer", type=Path, default=DEFAULT_GAZETTEER)
    parser.add_argument("--aliases", type=Path, default=DEFAULT_ALIASES)
    parser.add_argument("--report-dir", type=Path, default=DEFAULT_REPORT_DIR)
    parser.add_argument("--limit", type=int, default=None,
                        help="Chỉ xử lý N bản ghi đầu (debug nhanh).")
    args = parser.parse_args()

    gaz = load_gazetteer(args.gazetteer, args.aliases)
    print(
        f"📚 Gazetteer: {len(gaz.provinces)} tỉnh cũ, "
        f"{sum(len(v) for v in gaz.districts_by_core.values())} quận cũ, "
        f"{len(set(gaz.new_province_of.values()))} tỉnh mới"
    )
    run_dry_run(args.db, gaz, args.report_dir, args.limit)


if __name__ == "__main__":
    main()
