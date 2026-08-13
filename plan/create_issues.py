# -*- coding: utf-8 -*-
"""Create GitHub issues for S-Map project."""
import subprocess
import time
import sys
import json

REPO = "NhatNam15151515/S-Map"

def ensure_milestone(title):
    cmd_list = ["gh", "api", f"repos/{REPO}/milestones", "--paginate", "-q", ".[].title"]
    try:
        res = subprocess.run(cmd_list, capture_output=True, text=True, encoding="utf-8", timeout=30)
        if res.returncode == 0 and title in res.stdout.splitlines():
            return
    except Exception:
        pass
    
    cmd_create = ["gh", "api", f"repos/{REPO}/milestones", "-f", f"title={title}"]
    try:
        subprocess.run(cmd_create, capture_output=True, text=True, encoding="utf-8", timeout=30)
    except Exception:
        pass

def get_existing_issue_titles():
    cmd = ["gh", "issue", "list", "--repo", REPO, "--state", "all", "--limit", "500", "--json", "title"]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", timeout=30)
        if res.returncode == 0:
            data = json.loads(res.stdout)
            return {item["title"] for item in data}
    except Exception as e:
        print(f"  Warning checking existing issues: {e}")
    return set()

def create_issue(title, body, labels, milestone):
    cmd = ["gh", "issue", "create", "--repo", REPO, "--title", title, "--body", body]
    for label in labels:
        cmd.extend(["--label", label])
    cmd.extend(["--milestone", milestone])
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", timeout=60)
        if result.returncode == 0:
            url = result.stdout.strip()
            print(f"  OK: {url}")
            return True
        else:
            print(f"  FAIL: {result.stderr.strip()}")
            return False
    except subprocess.TimeoutExpired:
        print("  FAIL: gh issue create timed out")
        return False
    except Exception as e:
        print(f"  FAIL: {e}")
        return False

# ================================================================
M1 = "W1-W2: Setup & Data Pipeline"
M2 = "W3-W4: Core Map & Search"
M3 = "W5-W6: Routing & Navigation"
M4 = "W7-W8: Features & Polish"

issues = [
    # ── SETUP ──────────────────────────────────────
    {
        "title": "Setup: Khởi tạo Flutter project với Clean Architecture",
        "labels": ["type: setup", "priority: critical", "scope: mvp", "epic: map-display"],
        "milestone": M1,
        "body": """## Mục tiêu
Khởi tạo Flutter project S-Map với cấu trúc Clean Architecture, sẵn sàng cho development.

## Phạm vi công việc
- Restructure project theo Clean Architecture convention
- Config `pubspec.yaml` với dependencies cơ bản
- Setup build flavors: dev / sta / pro
- Config Montserrat font, AppColors, AppTextTheme
- Verify build thành công trên Android emulator

## Yêu cầu chức năng
- Cấu trúc thư mục:
  ```
  lib/
  ├── commons/        # shared widgets, utils, extensions
  ├── constants/
  ├── models/
  ├── repos/
  ├── services/       # native bridge, GPS, Firebase
  ├── screens/
  │   ├── map/
  │   ├── search/
  │   ├── navigation/
  │   ├── route_drawing/
  │   ├── stats/
  │   └── settings/
  └── routers/
  ```
- Dependencies: `flutter_bloc`, `go_router`, `hive`, `sqflite`, `geolocator`, `easy_localization`, `maplibre_gl`
- 3 build flavors hoạt động

## Acceptance Criteria
- [ ] `flutter build apk --flavor dev` thành công
- [ ] Cấu trúc thư mục đúng convention
- [ ] Montserrat font + AppColors + AppTextTheme có sẵn
- [ ] go_router setup với route mẫu

## Ngoài phạm vi
- Chưa tích hợp MapLibre, Firebase, hay logic nghiệp vụ
"""
    },

    # ── DATA PIPELINE ──────────────────────────────
    {
        "title": "Setup: Cài đặt data pipeline tools trên PC",
        "labels": ["type: setup", "priority: critical", "scope: mvp", "epic: data-pipeline"],
        "milestone": M1,
        "body": """## Mục tiêu
Cài đặt và verify toàn bộ tools cần thiết để build offline data (chạy trên PC, không trong app).

## Phạm vi công việc
- Cài Java JDK 17+, osmium-tool, Planetiler JAR, GraphHopper CLI
- Tải `vietnam-latest.osm.pbf` từ Geofabrik (~170MB)
- Tải boundary polygon files cho 5 vùng tải
- Verify mỗi tool chạy được

## Yêu cầu chức năng
- `java -version` → JDK 17+
- `osmium --version` hoạt động
- Planetiler + GraphHopper JAR chạy `--help` OK
- `vietnam-latest.osm.pbf` tải xong
- 5 boundary polygons: metro_hcm, metro_hn, mien_nam, mien_trung, mien_bac

## Acceptance Criteria
- [ ] 4 tools cài và chạy được
- [ ] `.osm.pbf` tải thành công
- [ ] 5 boundary polygons sẵn sàng
- [ ] `osmium fileinfo` hiển thị metadata đúng

## Ngoài phạm vi
- Chưa build data, chưa viết custom model
"""
    },
    {
        "title": "Data: Viết custom_model xe máy cho GraphHopper",
        "labels": ["type: feature", "priority: critical", "scope: mvp", "epic: data-pipeline"],
        "milestone": M1,
        "body": """## Mục tiêu
Viết `custom_model_moped.json` định nghĩa profile routing riêng cho xe máy VN — điểm khác biệt cốt lõi so với Google Maps.

## Phạm vi công việc
- Viết `custom_model_moped.json`
- Định nghĩa: đường nào xe máy được đi / cấm
- Cấu hình tốc độ ước tính theo loại đường VN
- Test 5 route mẫu, so sánh Google Maps

## Yêu cầu chức năng
- Quy tắc:
  - Hẻm rộng >1.5m → cho phép
  - `motor_vehicle=no` + `moped=yes` → cho phép
  - `highway=motorway/trunk` + `motorcycle=no` → cấm
  - Ưu tiên đường nhỏ song song thay vì quốc lộ
- Tốc độ: hẻm 15-20, nội thành 30-40, quốc lộ 50-60 km/h
- 5 test case: hẻm SG, tránh cao tốc, route dài, nội thành ngắn, đường 1 chiều

## Acceptance Criteria
- [ ] `custom_model_moped.json` syntax valid
- [ ] GraphHopper build `.ghz` thành công
- [ ] 5/5 route test case hợp lý (không đi đường cấm)
- [ ] So sánh GG Maps: không chênh quá 30% quãng đường
- [ ] Ghi chú khác biệt vào `route_comparison.md`

## Ngoài phạm vi
- Chưa tích hợp Flutter, chỉ test trên PC
"""
    },
    {
        "title": "Data: Build routing graph (.ghz) cho Việt Nam",
        "labels": ["type: feature", "priority: critical", "scope: mvp", "epic: data-pipeline"],
        "milestone": M1,
        "body": """## Mục tiêu
Build file `.ghz` (routing graph) từ OSM data với custom model xe máy.

## Phạm vi công việc
- Lọc tag không cần bằng osmium
- Build `.ghz` cho metro_hcm (test nhanh)
- Build `.ghz` toàn VN
- Clip + build cho 5 vùng
- Đo kích thước + thời gian build

## Yêu cầu chức năng
- Input: `.osm.pbf` + `custom_model_moped.json`
- Contraction Hierarchies (CH) enabled
- Output: 5 file `.ghz` per region + 1 toàn VN

## Acceptance Criteria
- [ ] `metro_hcm.ghz` < 50MB
- [ ] `vietnam.ghz` toàn quốc < 200MB
- [ ] Route query < 500ms (toàn quốc)
- [ ] 5 file per-region build OK
- [ ] Log sizes vào `data_sizes.md`

## Ngoài phạm vi
- Chưa tích hợp Android native module
"""
    },
    {
        "title": "Data: Build vector tiles (PMTiles) cho bản đồ",
        "labels": ["type: feature", "priority: critical", "scope: mvp", "epic: data-pipeline"],
        "milestone": M1,
        "body": """## Mục tiêu
Build PMTiles từ OSM data cho hiển thị bản đồ offline. PMTiles nhỏ hơn MBTiles 10-15%.

## Phạm vi công việc
- Build PMTiles metro_hcm bằng Planetiler (test trước)
- Verify tiếng Việt có dấu, zoom 0-14
- Build cho toàn VN + 5 vùng
- Fallback: build MBTiles nếu PMTiles gặp issue

## Yêu cầu chức năng
- Zoom level 0-14
- Tiếng Việt hiển thị đúng 100% ký tự có dấu
- Hẻm nhỏ hiển thị ở zoom 13-14

## Acceptance Criteria
- [ ] `metro_hcm.pmtiles` build OK
- [ ] Tiếng Việt đúng dấu trong MapLibre viewer
- [ ] 5 file per-region build OK
- [ ] Tổng VN < 500MB

## Ngoài phạm vi
- Chưa tích hợp Flutter, chưa viết style.json
"""
    },
    {
        "title": "Data: Build POI database (SQLite FTS5) tìm kiếm offline",
        "labels": ["type: feature", "priority: critical", "scope: mvp", "epic: data-pipeline"],
        "milestone": M1,
        "body": """## Mục tiêu
Script Python extract POI từ OSM vào SQLite, hỗ trợ search tiếng Việt có dấu và không dấu.

## Phạm vi công việc
- Script Python extract POI từ `.osm.pbf`
- SQLite: FTS5 + R*Tree
- Bảng phụ `name_ascii` (bỏ dấu)
- Test search, build cho 5 vùng

## Yêu cầu chức năng
- Schema: `poi(id, name, name_ascii, lat, lon, type, address)`
- FTS5 virtual table cho full-text search
- R*Tree cho spatial query (bounding box)
- Bỏ dấu: "phở" → "pho", "bệnh viện" → "benh vien"

## Acceptance Criteria
- [ ] Script chạy OK với metro_hcm
- [ ] Search "phở" → có kết quả
- [ ] Search "pho" (không dấu) → cùng kết quả
- [ ] R*Tree query < 50ms
- [ ] Build cho 5 vùng OK

## Ngoài phạm vi
- Chưa tích hợp sqflite trong Flutter
"""
    },
    {
        "title": "Data: Script tự động hóa pipeline + đóng gói theo vùng",
        "labels": ["type: setup", "priority: high", "scope: mvp", "epic: data-pipeline"],
        "milestone": M1,
        "body": """## Mục tiêu
Script tự động hóa toàn bộ data pipeline, 1 lệnh build 5 vùng.

## Phạm vi công việc
- Shell script / Makefile chạy full pipeline
- Clip → build .ghz + .pmtiles + .db per region
- Tạo `version.json` mỗi vùng
- Đóng gói zip

## Acceptance Criteria
- [ ] 1 lệnh → build 5 vùng thành công
- [ ] Mỗi vùng: ghz + pmtiles + db + version.json
- [ ] Tổng < 700MB
- [ ] Script idempotent (chạy lại OK)

## Ngoài phạm vi
- Chưa có server hosting, chưa có diff-based update
"""
    },

    # ── CORE: MAP DISPLAY ──────────────────────────
    {
        "title": "Core: Tích hợp MapLibre GL hiển thị bản đồ offline",
        "labels": ["type: feature", "priority: critical", "scope: mvp", "epic: map-display"],
        "milestone": M2,
        "body": """## Mục tiêu
Tích hợp MapLibre GL Native vào Flutter, đọc PMTiles local hiển thị bản đồ VN offline.

## Phạm vi công việc
- Tích hợp `maplibre_gl`
- Copy `metro_hcm.pmtiles` vào device
- Viết `style.json` (tham khảo OSM Bright)
- Verify font glyph tiếng Việt
- Hiển thị bản đồ offline

## Yêu cầu chức năng
- MapLibre đọc PMTiles local (airplane mode)
- Style layers: road, building, water, landuse, labels
- Font glyph SDF hỗ trợ Vietnamese (Latin Extended Additional)
- Pan/zoom/rotate GPU rendering mượt

## Acceptance Criteria
- [ ] Bản đồ HCM hiển thị offline (airplane mode ON)
- [ ] Tiếng Việt đúng 100% dấu
- [ ] 60fps pan/zoom/rotate trên thiết bị tầm trung
- [ ] Không crash khi xoay liên tục

## Ngoài phạm vi
- Chưa có GPS blue dot, search bar, dark mode
"""
    },
    {
        "title": "Core: MapDisplayCubit + GPS vị trí hiện tại (blue dot)",
        "labels": ["type: feature", "priority: critical", "scope: mvp", "epic: map-display"],
        "milestone": M2,
        "body": """## Mục tiêu
Implement `MapDisplayCubit` + tích hợp GPS hiển thị blue dot vị trí hiện tại.

## Phạm vi công việc
- `MapDisplayCubit`: center, zoom, rotation, isFollowingUser
- `geolocator`: request permission, lấy vị trí
- Blue dot + FAB locate me
- Override `emit()` guard

## Yêu cầu chức năng
- State: center, zoom, rotation, isFollowingUser, userLocation
- FAB: tap → camera animate + zoom 15 + follow ON
- Pan thủ công → follow mode tự OFF

## Acceptance Criteria
- [ ] Blue dot hiển thị đúng vị trí
- [ ] FAB locate me → camera animate mượt
- [ ] Follow mode ON/OFF đúng logic
- [ ] Unit test cho state transitions

## Ngoài phạm vi
- Heading-up mode (issue riêng)
"""
    },
    {
        "title": "Core: Heading-up mode (xoay bản đồ theo hướng đầu xe)",
        "labels": ["type: feature", "priority: high", "scope: mvp", "epic: map-display"],
        "milestone": M2,
        "body": """## Mục tiêu
Tích hợp compass xoay bản đồ theo hướng xe máy (heading-up mode).

## Phạm vi công việc
- `flutter_compass` package
- Toggle north-up / heading-up
- Xoay camera theo heading real-time

## Acceptance Criteria
- [ ] Compass hoạt động trên thiết bị thật
- [ ] Toggle north-up / heading-up OK
- [ ] Bản đồ xoay mượt (không giật)

## Ngoài phạm vi
- Chưa tích hợp vào navigation flow
"""
    },
    {
        "title": "UI/UX: Layout chính map screen (search bar, FAB, bottom sheet)",
        "labels": ["type: feature", "priority: high", "scope: mvp", "epic: map-display"],
        "milestone": M2,
        "body": """## Mục tiêu
Xây dựng UI shell cho map screen giống Google Maps.

## Phạm vi công việc
- Search bar nổi trên cùng (placeholder, chưa logic)
- FAB locate góc phải dưới
- Bottom sheet draggable
- Safe area / padding

## Yêu cầu chức năng
- Search bar: rounded, shadow, icon search + profile
- FAB: kết nối MapDisplayCubit.locateMe
- Bottom sheet: collapsed/expanded, draggable
- Montserrat font toàn bộ

## Acceptance Criteria
- [ ] Search bar hiển thị đúng vị trí
- [ ] FAB hoạt động
- [ ] Bottom sheet kéo lên/xuống mượt
- [ ] Không bị che bởi system UI

## Ngoài phạm vi
- Logic search, navigation panel
"""
    },

    # ── CORE: SEARCH ──────────────────────────────
    {
        "title": "Core: Setup sqflite đọc POI database + PoiRepository",
        "labels": ["type: feature", "priority: critical", "scope: mvp", "epic: search"],
        "milestone": M2,
        "body": """## Mục tiêu
Setup `sqflite` đọc `poi.db` và tạo `PoiRepository`.

## Phạm vi công việc
- `sqflite` đọc `poi.db` read-only
- `PoiModel` data class
- `PoiRepository` (abstract + impl): searchByName, searchByNameAscii, searchInBounds

## Yêu cầu chức năng
- FTS5 search: `SELECT * FROM poi_fts WHERE poi_fts MATCH ?`
- Auto-detect: query không dấu → search cả FTS5 + ascii
- R*Tree: spatial query bounding box

## Acceptance Criteria
- [ ] `sqflite` mở `poi.db` OK
- [ ] Search "phở" + "pho" → cùng kết quả
- [ ] R*Tree query bounding box OK
- [ ] Query < 50ms cho 10k+ POI
- [ ] Unit test PoiRepository

## Ngoài phạm vi
- SearchCubit, search UI
"""
    },
    {
        "title": "Core: SearchCubit + logic tìm kiếm có dấu/không dấu",
        "labels": ["type: feature", "priority: critical", "scope: mvp", "epic: search"],
        "milestone": M2,
        "body": """## Mục tiêu
Implement `SearchCubit` với debounce, hỗ trợ tiếng Việt có dấu/không dấu.

## Phạm vi công việc
- `SearchCubit`: idle / loading / results / error
- Debounce 300ms bằng `Timer`
- Lưu recent search vào Hive

## Acceptance Criteria
- [ ] Debounce 300ms hoạt động
- [ ] "bệnh viện" + "benh vien" → cùng kết quả
- [ ] Recent search lưu + hiển thị
- [ ] Unit test: debounce, state transitions

## Ngoài phạm vi
- Search UI, viewport search
"""
    },
    {
        "title": "UI/UX: Search overlay + suggestion list",
        "labels": ["type: feature", "priority: high", "scope: mvp", "epic: search"],
        "milestone": M2,
        "body": """## Mục tiêu
Full-screen search overlay với suggestion list real-time.

## Phạm vi công việc
- Tap search bar → full-screen overlay
- Suggestion list real-time
- Icon POI type + tên + địa chỉ
- Tap → dismiss + camera animate + marker

## Acceptance Criteria
- [ ] Overlay mở/đóng mượt
- [ ] Suggestions cập nhật real-time
- [ ] Icon POI type đúng
- [ ] Tap → camera animate + marker
- [ ] Recent search hiển thị

## Ngoài phạm vi
- Viewport search, favorites
"""
    },
    {
        "title": "Core: ViewportSearchBloc + tìm trong khu vực hiển thị",
        "labels": ["type: feature", "priority: high", "scope: mvp", "epic: search"],
        "milestone": M2,
        "body": """## Mục tiêu
`ViewportSearchBloc` (Bloc + `restartable()`) tìm POI trong viewport bản đồ.

## Phạm vi công việc
- `ViewportSearchBloc` với `restartable()` transformer
- Event `ViewportChanged(bbox)` khi pan/zoom
- R*Tree query, hiển thị POI markers
- Nút "Tìm trong khu vực này"

## Acceptance Criteria
- [ ] Pan nhanh → chỉ query cuối cùng (restartable)
- [ ] POI markers hiển thị đúng (max 50)
- [ ] Nút "Tìm trong khu vực này" OK
- [ ] Unit test restartable behavior

## Ngoài phạm vi
- Favorites / bookmark
"""
    },
    {
        "title": "Feature: Favorites + Recent search (Hive local)",
        "labels": ["type: feature", "priority: medium", "scope: mvp", "epic: search"],
        "milestone": M2,
        "body": """## Mục tiêu
Lưu địa điểm yêu thích + lịch sử tìm kiếm vào Hive.

## Phạm vi công việc
- Hive box favorites + recent_search
- UI bookmark icon trên bottom sheet
- Favorites list

## Acceptance Criteria
- [ ] Bookmark/un-bookmark POI
- [ ] Recent search hiển thị khi mở search
- [ ] Favorites list + tap navigate

## Ngoài phạm vi
- Sync favorites lên Firebase
"""
    },

    # ── CORE: ROUTING ──────────────────────────────
    {
        "title": "Core: GraphHopper native Android module (Kotlin)",
        "labels": ["type: feature", "priority: critical", "scope: mvp", "epic: routing"],
        "milestone": M3,
        "body": """## Mục tiêu
Viết native Android module (Kotlin) load GraphHopper `.ghz` — phần kỹ thuật phức tạp nhất.

## Phạm vi công việc
- Kotlin `GraphHopperService` trong `android/app/src/main/kotlin/`
- GraphHopper core dependency
- `init(graphFolder)`, `route(from, to)`, `dispose()`
- Load `.ghz` qua mmap
- Test standalone (không qua Flutter)

## Yêu cầu chức năng
- `route(fromLat, fromLon, toLat, toLon)` → polyline + distance + duration + instructions
- Memory: mmap, không load full RAM

## Acceptance Criteria
- [ ] GraphHopper dependency resolve OK
- [ ] `.ghz` load thành công
- [ ] Route nội thành < 200ms
- [ ] Route toàn quốc < 500ms
- [ ] Không crash OOM

## Ngoài phạm vi
- MethodChannel bridge, ProGuard test
"""
    },
    {
        "title": "Core: MethodChannel bridge Flutter - GraphHopper + ProGuard test",
        "labels": ["type: feature", "priority: critical", "scope: mvp", "epic: routing"],
        "milestone": M3,
        "body": """## Mục tiêu
Tạo MethodChannel bridge + **test release build (R8/ProGuard)** — critical risk.

## Phạm vi công việc
- `MethodChannel("com.smap/routing")` trong `MainActivity.kt`
- Dart `RoutingService` + `RoutingRepository`
- **CRITICAL: Release build test + ProGuard rules**

## Yêu cầu chức năng
- Channel methods: `initGraphHopper`, `getRoute`, `disposeGraphHopper`
- JSON serialization Kotlin ↔ Dart
- ProGuard rules cho GraphHopper reflection

## Acceptance Criteria
- [ ] Dart `getRoute()` → polyline + distance + duration
- [ ] Release build (R8 minify) KHÔNG crash
- [ ] ProGuard config đúng
- [ ] 20 route requests → avg < 300ms
- [ ] Unit test RoutingRepository

## Ngoài phạm vi
- Route preview UI
"""
    },
    {
        "title": "Core: RoutePreviewCubit + hiển thị route trên map",
        "labels": ["type: feature", "priority: critical", "scope: mvp", "epic: routing"],
        "milestone": M3,
        "body": """## Mục tiêu
`RoutePreviewCubit` hiển thị route preview trước khi navigate.

## Phạm vi công việc
- RoutePreviewCubit: idle / loading / routeReady / error
- Long press hoặc "Chỉ đường" → tính route → polyline
- Bottom sheet: distance, duration, nút "Bắt đầu"
- Camera fit bounds

## Yêu cầu chức năng
- Polyline: màu xanh, width 5, shadow
- Markers: origin (xanh) + destination (đỏ)
- Bottom sheet: `12.5 km · 25 phút · [Bắt đầu]`

## Acceptance Criteria
- [ ] Long press → route preview
- [ ] Search → "Chỉ đường" → route preview
- [ ] Distance + duration hiển thị đúng
- [ ] Camera fit bounds
- [ ] Unit test state transitions

## Ngoài phạm vi
- Navigation turn-by-turn, multiple alternatives
"""
    },

    # ── CORE: NAVIGATION ──────────────────────────
    {
        "title": "Core: NavigationBloc + GPS stream tracking",
        "labels": ["type: feature", "priority: critical", "scope: mvp", "epic: navigation"],
        "milestone": M3,
        "body": """## Mục tiêu
`NavigationBloc` (Bloc + event transformers) quản lý navigation state.

## Phạm vi công việc
- Events: StartNavigation, LocationUpdated, OffRouteDetected, RerouteRequested, StopNavigation
- Transformers: `sequential()` / `restartable()` / `droppable()`
- GPS stream 1s interval
- Tính tốc độ, map auto-follow

## Acceptance Criteria
- [ ] GPS events liên tục
- [ ] Tốc độ tính đúng (km/h)
- [ ] Map auto-follow
- [ ] GPS processing < 16ms
- [ ] Unit test state transitions

## Ngoài phạm vi
- Off-route, turn-by-turn UI, background GPS
"""
    },
    {
        "title": "Core: Off-route detection + tự động tính lại đường",
        "labels": ["type: feature", "priority: critical", "scope: mvp", "epic: navigation"],
        "milestone": M3,
        "body": """## Mục tiêu
Phát hiện xe lệch route > 50m → tự động reroute.

## Phạm vi công việc
- Point-to-polyline distance (optimize: segment hiện tại + 5 tiếp)
- Ngưỡng 50m → trigger reroute
- `restartable()` cho reroute
- Update polyline + instructions

## Acceptance Criteria
- [ ] Lệch > 50m → reroute tự động
- [ ] Route mới từ vị trí hiện tại
- [ ] Thông báo "Đang tính lại đường..."
- [ ] Unit test off-route detection

## Ngoài phạm vi
- Voice notification (TTS)
"""
    },
    {
        "title": "Core: Turn-by-turn instruction engine + advance logic",
        "labels": ["type: feature", "priority: critical", "scope: mvp", "epic: navigation"],
        "milestone": M3,
        "body": """## Mục tiêu
Parse instructions từ GraphHopper + advance khi đến gần waypoint.

## Phạm vi công việc
- Parse: TURN_LEFT, RIGHT, STRAIGHT, ROUNDABOUT, ARRIVE
- Advance: < 30m → next instruction
- Pre-announce: 200m trước

## Acceptance Criteria
- [ ] Parse instructions đúng
- [ ] Advance logic OK
- [ ] Pre-announce 200m trước
- [ ] Unit test advance logic

## Ngoài phạm vi
- TTS voice, navigation UI panel
"""
    },
    {
        "title": "UI/UX: Navigation panel (hướng rẽ + tốc độ + ETA)",
        "labels": ["type: feature", "priority: critical", "scope: mvp", "epic: navigation"],
        "milestone": M3,
        "body": """## Mục tiêu
Navigation UI: panel hướng rẽ, bar tốc độ/ETA, trip summary.

## Phạm vi công việc
- Top bar: icon rẽ + distance + tên đường
- Bottom bar: tốc độ, km còn lại, ETA
- Map: heading-up, auto-follow, dim đường đã đi, zoom theo tốc độ
- Nút "Kết thúc" → trip summary

## Acceptance Criteria
- [ ] Top panel instruction đúng
- [ ] Bottom bar real-time
- [ ] Heading-up + auto-follow
- [ ] Dim polyline phía sau
- [ ] Trip summary hiển thị stats

## Ngoài phạm vi
- Dark mode navigation
"""
    },
    {
        "title": "Core: Background location service (foreground service)",
        "labels": ["type: feature", "priority: critical", "scope: mvp", "epic: navigation"],
        "milestone": M3,
        "body": """## Mục tiêu
Foreground service cho GPS tracking khi tắt màn hình.

## Phạm vi công việc
- Foreground service + persistent notification
- GPS tiếp tục khi background
- Battery optimization exemption
- Test Samsung, Xiaomi

## Acceptance Criteria
- [ ] Tắt màn hình 10 phút → vị trí đúng
- [ ] Notification persistent
- [ ] Samsung: GPS không bị kill
- [ ] Xiaomi: GPS không bị kill

## Ngoài phạm vi
- Resume trip sau force kill
"""
    },

    # ── FEATURES: ROUTE DRAWING ────────────────────
    {
        "title": "Core: Snap-to-road service (GraphHopper LocationIndex)",
        "labels": ["type: feature", "priority: high", "scope: mvp", "epic: route-drawing"],
        "milestone": M4,
        "body": """## Mục tiêu
Extend GraphHopper native với snap-to-road: snap tọa độ vào road gần nhất.

## Phạm vi công việc
- Kotlin: `nearestPoint(lat, lon)` dùng `LocationIndex.findClosest()`
- MethodChannel: thêm `snapToRoad`
- Dart: `RoutingService.snapToRoad()`

## Acceptance Criteria
- [ ] Snap random point → nằm trên đường
- [ ] Trả snapped lat/lon + tên đường
- [ ] < 50ms

## Ngoài phạm vi
- RouteDrawingBloc
"""
    },
    {
        "title": "Feature: RouteDrawingBloc + tap-to-add + auto-connect",
        "labels": ["type: feature", "priority: high", "scope: mvp", "epic: route-drawing"],
        "milestone": M4,
        "body": """## Mục tiêu
`RouteDrawingBloc` tap điểm → snap-to-road → auto-connect route.

## Phạm vi công việc
- Bloc + `restartable()` cho snap
- Events: PointTapped, Undo, Redo, Clear, Save
- Tap → snap → marker
- 2+ points → auto-connect bằng `getRoute()`

## Acceptance Criteria
- [ ] Tap → snap → marker
- [ ] 2+ points → polyline nối
- [ ] Tap nhanh → chỉ snap cuối cùng
- [ ] Warning khi không nối được
- [ ] Unit test state

## Ngoài phạm vi
- Drag waypoint
"""
    },
    {
        "title": "Feature: Undo/redo + lưu/load custom routes",
        "labels": ["type: feature", "priority: medium", "scope: mvp", "epic: route-drawing"],
        "milestone": M4,
        "body": """## Mục tiêu
Undo/redo cho route drawing + lưu routes vào Hive.

## Phạm vi công việc
- Undo/redo stack
- Save route → Hive
- Load + list saved routes

## Acceptance Criteria
- [ ] Undo/redo đúng
- [ ] Save → load lại đúng
- [ ] Clear OK
"""
    },

    # ── FEATURES: STATS & SYNC ─────────────────────
    {
        "title": "Feature: Trip storage local + RouteProfileCubit thống kê",
        "labels": ["type: feature", "priority: high", "scope: mvp", "epic: stats"],
        "milestone": M4,
        "body": """## Mục tiêu
Lưu trip data vào Hive + `RouteProfileCubit` tính aggregate stats.

## Phạm vi công việc
- Trip model + Hive storage
- Lưu trip khi navigate xong
- `RouteProfileCubit` + `TripHistoryCubit`

## Acceptance Criteria
- [ ] Trip lưu khi navigate xong
- [ ] Stats aggregate đúng
- [ ] Unit test calculation
"""
    },
    {
        "title": "UI/UX: Stats dashboard + charts (fl_chart)",
        "labels": ["type: feature", "priority: medium", "scope: mvp", "epic: stats"],
        "milestone": M4,
        "body": """## Mục tiêu
Stats dashboard với charts trực quan.

## Phạm vi công việc
- Dashboard: stats hôm nay/tháng/năm
- Bar chart quãng đường (`fl_chart`)
- Trip history list
- Tap trip → route trên map

## Acceptance Criteria
- [ ] Dashboard stats đúng
- [ ] Chart render OK
- [ ] Trip history list
- [ ] Tap trip → route hiển thị
"""
    },
    {
        "title": "Feature: Firebase Auth anonymous + Firestore sync",
        "labels": ["type: feature", "priority: medium", "scope: enhancement", "epic: firebase-sync"],
        "milestone": M4,
        "body": """## Mục tiêu
Firebase Auth anonymous + sync trip data lên Firestore.

## Phạm vi công việc
- Anonymous sign-in + `AuthCubit`
- `SyncBloc` (`droppable()`)
- Offline queue (Hive) → flush khi online
- Firestore write: trips + daily stats

## Acceptance Criteria
- [ ] Anonymous auth OK
- [ ] Trip sync lên Firestore
- [ ] Offline queue: 3 trips → bật mạng → sync all
- [ ] SyncBloc droppable

## Ngoài phạm vi
- Email/password auth, Cloud Functions
"""
    },

    # ── FEATURES: REGION & POLISH ──────────────────
    {
        "title": "Feature: DownloadRegionCubit + quản lý vùng offline",
        "labels": ["type: feature", "priority: high", "scope: mvp", "epic: region-mgmt"],
        "milestone": M4,
        "body": """## Mục tiêu
Quản lý tải/xóa data offline theo 5 vùng.

## Phạm vi công việc
- `DownloadRegionCubit`: idle/downloading/done/error
- Region list UI: 5 vùng + trạng thái + nút tải/xóa
- Download zip → extract → app storage
- Version check + dung lượng

## Acceptance Criteria
- [ ] Tải vùng OK
- [ ] Xóa vùng OK
- [ ] Version check
- [ ] Progress hiển thị đúng
"""
    },
    {
        "title": "Feature: Resume trip sau app kill + edge cases",
        "labels": ["type: feature", "priority: high", "scope: mvp", "epic: navigation"],
        "milestone": M4,
        "body": """## Mục tiêu
Resume navigation khi app bị kill giữa chừng.

## Phạm vi công việc
- Lưu navigation state vào Hive mỗi 30s
- Mở app → check → prompt resume
- Edge cases: hết storage, download fail

## Acceptance Criteria
- [ ] Kill app → mở lại → prompt "Tiếp tục?"
- [ ] Resume đúng vị trí
- [ ] Warning hết storage
"""
    },
    {
        "title": "UI/UX: Dark mode + night map style",
        "labels": ["type: feature", "priority: medium", "scope: enhancement", "epic: map-display"],
        "milestone": M4,
        "body": """## Mục tiêu
Dark mode app + night map style cho chạy xe đêm.

## Phạm vi công việc
- Night style.json cho MapLibre
- App dark theme
- Auto-switch / manual toggle

## Acceptance Criteria
- [ ] Night style hiển thị đúng
- [ ] App dark theme nhất quán
- [ ] Toggle hoạt động
"""
    },
    {
        "title": "UI/UX: Onboarding flow lần đầu mở app",
        "labels": ["type: feature", "priority: medium", "scope: enhancement", "epic: region-mgmt"],
        "milestone": M4,
        "body": """## Mục tiêu
Onboarding: chào mừng → chọn vùng → download → ready.

## Phạm vi công việc
- Welcome screen
- Region picker
- Download progress
- Ready → map

## Acceptance Criteria
- [ ] Lần đầu → onboarding
- [ ] Chọn vùng → tải → map
- [ ] Lần sau → skip
"""
    },

    # ── TESTING ────────────────────────────────────
    {
        "title": "Test: Unit + Integration tests cho toàn bộ Cubits/Blocs",
        "labels": ["type: test", "priority: high", "scope: mvp"],
        "milestone": M4,
        "body": """## Mục tiêu
Test suite bao phủ toàn bộ state management + native bridge.

## Phạm vi công việc
- Unit tests Cubits: MapDisplay, Search, RoutePreview, RouteProfile, TripHistory, DownloadRegion, Auth
- Unit tests Blocs: ViewportSearch, RouteDrawing, Navigation, Sync
- Integration test: MethodChannel routing bridge
- Performance benchmark

## Acceptance Criteria
- [ ] > 80% coverage Cubits/Blocs
- [ ] Integration test pass
- [ ] Route < 500ms consistently
- [ ] All tests pass
"""
    },
    {
        "title": "Test: Test thực địa - chạy xe máy thực tế",
        "labels": ["type: test", "priority: high", "scope: mvp"],
        "milestone": M4,
        "body": """## Mục tiêu
Test thực tế trên xe máy, verify toàn bộ flow navigation.

## Phạm vi công việc
- 3 chuyến xe > 5km mỗi chuyến
- So sánh route với Google Maps
- Verify: turn-by-turn, off-route, reroute, background GPS
- Check battery drain
- Tune custom_model nếu route sai

## Acceptance Criteria
- [ ] 3 chuyến test > 5km
- [ ] Turn-by-turn hoạt động thực tế
- [ ] Off-route + reroute OK
- [ ] Background GPS OK khi tắt màn hình
- [ ] Battery drain < 15% cho 2 giờ navigate
- [ ] Ghi chú issue phát hiện → tạo bug tickets
"""
    },
]

# ── RUN ────────────────────────────────────────────
print("Ensuring milestones exist...")
for m in [M1, M2, M3, M4]:
    ensure_milestone(m)

print("Checking existing issues for idempotency...")
existing_titles = get_existing_issue_titles()

print(f"\nProcessing {len(issues)} issues...")
created = 0
skipped = 0
failed = 0

for i, issue in enumerate(issues, 1):
    print(f"[{i}/{len(issues)}] {issue['title']}")
    if issue["title"] in existing_titles:
        print("  SKIP: Issue already exists.")
        skipped += 1
        continue

    success = create_issue(issue["title"], issue["body"], issue["labels"], issue["milestone"])
    if success:
        created += 1
    else:
        failed += 1
    time.sleep(1)

print(f"\n{'='*50}")
print(f"DONE! Created {created} issues, skipped {skipped}, failed {failed}.")
print(f"{'='*50}")

if failed > 0:
    sys.exit(1)

