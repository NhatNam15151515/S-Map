$env:GITHUB_TOKEN = ""
$repo = "NhatNam15151515/S-Map"

function New-Issue {
  param([string]$Title, [string]$Body, [string[]]$Labels, [int]$Milestone)
  $labelArgs = @()
  foreach ($l in $Labels) { $labelArgs += "--label"; $labelArgs += $l }
  gh issue create --repo $repo --title $Title --body $Body @labelArgs --milestone $Milestone 2>&1
  Start-Sleep -Milliseconds 500
}

# ================================================================
# ISSUE 1: Setup Flutter project
# ================================================================
New-Issue -Title "Setup: Khởi tạo Flutter project với Clean Architecture" -Milestone 1 -Labels @("type: setup", "priority: critical", "scope: mvp", "epic: map-display") -Body @"
## Mục tiêu

Khởi tạo Flutter project S-Map với cấu trúc Clean Architecture, sẵn sàng cho development. Đây là nền tảng cho toàn bộ dự án.

## Phạm vi công việc

- Init Flutter project (nếu chưa có) hoặc restructure từ boilerplate
- Setup cấu trúc thư mục theo Clean Architecture convention
- Config ``pubspec.yaml`` với dependencies cơ bản
- Setup build flavors: dev / sta / pro
- Config Montserrat font, AppColors, AppTextTheme
- Verify build thành công trên Android emulator

## Yêu cầu chức năng

- Cấu trúc thư mục đúng convention:
  ``````
  lib/
  ├── commons/        # shared widgets, utils, extensions
  ├── constants/      # app-wide constants
  ├── models/         # pure data classes
  ├── repos/          # repositories
  ├── services/       # native bridge, GPS, Firebase
  ├── screens/        # feature screens
  │   ├── map/
  │   ├── search/
  │   ├── navigation/
  │   ├── route_drawing/
  │   ├── stats/
  │   └── settings/
  └── routers/        # go_router setup
  ``````
- Dependencies tối thiểu: ``flutter_bloc``, ``go_router``, ``hive``, ``sqflite``, ``geolocator``, ``easy_localization``, ``maplibre_gl``
- 3 build flavors hoạt động: ``flutter run --dart-define=FLAVOR=dev``

## Acceptance Criteria

- [ ] ``flutter build apk --flavor dev`` thành công
- [ ] Cấu trúc thư mục đúng convention AGENTS.md
- [ ] Montserrat font hiển thị đúng
- [ ] AppColors, AppTextTheme có sẵn
- [ ] go_router setup với ít nhất 1 route mẫu

## Ngoài phạm vi

- Chưa tích hợp MapLibre (issue riêng)
- Chưa setup Firebase (issue riêng)
- Chưa viết logic nghiệp vụ
"@

# ================================================================
# ISSUE 2: Setup data pipeline tools
# ================================================================
New-Issue -Title "Setup: Cài đặt data pipeline tools trên PC" -Milestone 1 -Labels @("type: setup", "priority: critical", "scope: mvp", "epic: data-pipeline") -Body @"
## Mục tiêu

Cài đặt và verify toàn bộ tools cần thiết để build offline data (chạy trên PC, không phải trong app Flutter).

## Phạm vi công việc

- Cài Java JDK 17+ (cho GraphHopper)
- Cài osmium-tool (lọc/clip OSM data)
- Tải Planetiler JAR (build vector tiles)
- Tải GraphHopper CLI/JAR (build routing graph)
- Tải ``vietnam-latest.osm.pbf`` từ Geofabrik
- Tải boundary polygon files cho 5 vùng tải
- Verify mỗi tool chạy được bằng lệnh cơ bản

## Yêu cầu chức năng

- Tools cần cài:
  - ``java -version`` → JDK 17+
  - ``osmium --version``
  - Planetiler ``java -jar planetiler.jar --help``
  - GraphHopper ``java -jar graphhopper-web.jar --help``
- File data cần tải:
  - ``vietnam-latest.osm.pbf`` (~170MB) từ Geofabrik
  - 5 boundary polygons: metro_hcm, metro_hn, mien_nam, mien_trung, mien_bac

## Acceptance Criteria

- [ ] Tất cả 4 tools chạy được trên PC
- [ ] ``vietnam-latest.osm.pbf`` tải thành công
- [ ] 5 boundary polygon files sẵn sàng
- [ ] ``osmium fileinfo vietnam-latest.osm.pbf`` hiển thị metadata đúng

## Ngoài phạm vi

- Chưa build data thực tế (issue riêng cho từng loại data)
- Chưa viết custom model xe máy
"@

# ================================================================
# ISSUE 3: Custom model xe máy
# ================================================================
New-Issue -Title "Data: Viết custom_model xe máy cho GraphHopper" -Milestone 1 -Labels @("type: feature", "priority: critical", "scope: mvp", "epic: data-pipeline") -Body @"
## Mục tiêu

Viết file ``custom_model_moped.json`` định nghĩa profile routing riêng cho xe máy Việt Nam — điểm khác biệt cốt lõi của app so với Google Maps.

## Phạm vi công việc

- Viết ``custom_model_moped.json`` cho GraphHopper
- Định nghĩa quy tắc: đường nào xe máy được đi, đường nào cấm
- Cấu hình tốc độ ước tính theo loại đường VN
- Test với vài route mẫu thực tế, so sánh với Google Maps

## Yêu cầu chức năng

- Quy tắc routing:
  - ✅ Hẻm rộng >1.5m (``highway=residential/service``, ``width>1.5``): **cho phép**
  - ✅ ``motor_vehicle=no`` + ``moped=yes``: **cho phép**
  - ❌ ``highway=motorway/trunk`` + ``motorcycle=no``: **cấm**
  - ❌ Đường có biển cấm xe máy: **cấm**
  - Ưu tiên đường nhỏ song song khi có thay vì quốc lộ
- Tốc độ ước tính:
  - Hẻm: 15-20 km/h
  - Đường nội thành: 30-40 km/h
  - Quốc lộ (được phép): 50-60 km/h
- 5 route test case:
  1. Hẻm Sài Gòn (Q1 → Q4)
  2. Tránh cao tốc (TP.HCM → Biên Hòa)
  3. Route dài (TP.HCM → Vũng Tàu)
  4. Nội thành ngắn (< 2km)
  5. Khu vực đường 1 chiều

## Acceptance Criteria

- [ ] ``custom_model_moped.json`` viết xong, syntax valid
- [ ] GraphHopper build ``.ghz`` thành công với custom model
- [ ] 5/5 route test case cho kết quả hợp lý (không đi qua đường cấm)
- [ ] So sánh với Google Maps: không chênh lệch quá 30% quãng đường
- [ ] Ghi chú khác biệt với GG Maps vào file ``route_comparison.md``

## Ngoài phạm vi

- Chưa tích hợp vào app Flutter
- Chưa test trên thiết bị thật (chỉ test trên PC qua GraphHopper web UI)
"@

# ================================================================
# ISSUE 4: Build routing graph
# ================================================================
New-Issue -Title "Data: Build routing graph (.ghz) cho toàn Việt Nam" -Milestone 1 -Labels @("type: feature", "priority: critical", "scope: mvp", "epic: data-pipeline") -Body @"
## Mục tiêu

Build file ``.ghz`` (GraphHopper routing graph) từ OSM data, sử dụng custom model xe máy. File này sẽ được load trên Android để tính route offline.

## Phạm vi công việc

- Lọc tag không cần thiết từ ``.osm.pbf`` bằng osmium
- Build ``.ghz`` cho metro_hcm (test nhanh trước)
- Build ``.ghz`` cho toàn Việt Nam
- Clip + build riêng cho 5 vùng
- Đo kích thước và thời gian build

## Yêu cầu chức năng

- Input: ``vietnam-latest.osm.pbf`` + ``custom_model_moped.json``
- Output: 5 file ``.ghz`` (mỗi vùng 1 file) + 1 file toàn VN
- Build command mẫu:
  ``````bash
  java -jar graphhopper-web.jar import -p custom_model_moped.json vietnam.osm.pbf
  ``````
- Contraction Hierarchies (CH) enabled cho query nhanh

## Acceptance Criteria

- [ ] ``metro_hcm.ghz`` build thành công, size < 50MB
- [ ] ``vietnam.ghz`` toàn quốc build thành công, size < 200MB
- [ ] Route query qua GraphHopper API < 500ms (toàn quốc)
- [ ] 5 file ``.ghz`` theo vùng build thành công
- [ ] Log kích thước mỗi file vào ``data_sizes.md``

## Ngoài phạm vi

- Chưa tích hợp vào Android native module
"@

# ================================================================
# ISSUE 5: Build vector tiles
# ================================================================
New-Issue -Title "Data: Build vector tiles (PMTiles) cho bản đồ Việt Nam" -Milestone 1 -Labels @("type: feature", "priority: critical", "scope: mvp", "epic: data-pipeline") -Body @"
## Mục tiêu

Build file PMTiles (vector tiles) từ OSM data để hiển thị bản đồ offline trong app. PMTiles được chọn thay MBTiles vì nhỏ hơn 10-15% và MapLibre hỗ trợ native.

## Phạm vi công việc

- Build PMTiles cho metro_hcm bằng Planetiler (test trước)
- Build PMTiles cho toàn Việt Nam
- Verify hiển thị: tên đường tiếng Việt có dấu, zoom level 0-14
- Nếu PMTiles gặp issue → build MBTiles làm fallback
- Clip + build riêng cho 5 vùng

## Yêu cầu chức năng

- Zoom level: 0-14 (đủ chi tiết cho navigation)
- Tiếng Việt: tất cả ký tự có dấu hiển thị đúng (ư, ơ, ă, dấu thanh chồng)
- Hẻm nhỏ hiển thị ở zoom 13-14
- Build bằng Planetiler (nhanh hơn Tilemaker)

## Acceptance Criteria

- [ ] ``metro_hcm.pmtiles`` build thành công
- [ ] Mở trong MapLibre demo viewer → tiếng Việt hiển thị đúng 100%
- [ ] Hẻm nhỏ hiển thị ở zoom 14
- [ ] 5 file PMTiles theo vùng build thành công
- [ ] Tổng size toàn VN < 500MB
- [ ] Ghi log kích thước + thời gian build

## Ngoài phạm vi

- Chưa tích hợp vào Flutter app
- Chưa viết style.json cho MapLibre (issue riêng)
"@

# ================================================================
# ISSUE 6: Build POI database
# ================================================================
New-Issue -Title "Data: Build POI database (SQLite FTS5) cho tìm kiếm offline" -Milestone 1 -Labels @("type: feature", "priority: critical", "scope: mvp", "epic: data-pipeline") -Body @"
## Mục tiêu

Viết script Python extract POI (Point of Interest) từ OSM data vào SQLite database, hỗ trợ full-text search tiếng Việt có dấu và không dấu.

## Phạm vi công việc

- Viết script Python extract POI từ ``.osm.pbf``
- Tạo SQLite database với FTS5 + R*Tree
- Xử lý tiếng Việt: bảng phụ lưu bản không dấu
- Test search functionality
- Build cho 5 vùng

## Yêu cầu chức năng

- Schema SQLite:
  ``````sql
  CREATE TABLE poi (id INTEGER PK, name TEXT, name_ascii TEXT, lat REAL, lon REAL, type TEXT, address TEXT);
  CREATE VIRTUAL TABLE poi_fts USING fts5(name, name_ascii, address, content=poi);
  CREATE VIRTUAL TABLE poi_rtree USING rtree(id, min_lat, max_lat, min_lon, max_lon);
  ``````
- Extract tags: ``name``, ``addr:*``, ``amenity``, ``shop``, ``tourism``, ``highway=bus_stop``, ``place``
- Bỏ dấu tiếng Việt cho ``name_ascii``: ``phở`` → ``pho``, ``bệnh viện`` → ``benh vien``
- R*Tree cho spatial query (tìm theo bounding box)

## Acceptance Criteria

- [ ] Script Python chạy thành công, extract POI từ metro_hcm
- [ ] Search "phở" → có kết quả
- [ ] Search "pho" (không dấu) → cùng kết quả
- [ ] Search "bệnh viện chợ rẫy" → đúng kết quả
- [ ] R*Tree query bounding box trả kết quả < 50ms
- [ ] Build cho 5 vùng thành công

## Ngoài phạm vi

- Chưa tích hợp vào Flutter app (sqflite)
- Chưa có search UI
"@

# ================================================================
# ISSUE 7: Data automation script
# ================================================================
New-Issue -Title "Data: Script tự động hóa pipeline + đóng gói theo vùng" -Milestone 1 -Labels @("type: setup", "priority: high", "scope: mvp", "epic: data-pipeline") -Body @"
## Mục tiêu

Viết script tự động hóa toàn bộ data pipeline, từ tải OSM data đến build + đóng gói 5 vùng. Để rebuild dễ dàng khi OSM update (mỗi 1-3 tháng).

## Phạm vi công việc

- Viết shell script/Makefile chạy toàn bộ pipeline
- Clip OSM data theo 5 boundary polygons
- Build .ghz + .pmtiles + .db cho mỗi vùng
- Tạo ``version.json`` cho mỗi vùng (version, build date, size)
- Đóng gói zip per region

## Yêu cầu chức năng

- 1 lệnh duy nhất build toàn bộ: ``make build-all`` hoặc ``./build_pipeline.sh``
- Output cho mỗi vùng:
  ``````
  output/metro_hcm/
  ├── routing.ghz
  ├── tiles.pmtiles
  ├── poi.db
  └── version.json
  ``````
- ``version.json``: ``{"version": 1, "buildDate": "2026-08-12", "sizeBytes": 123456}``

## Acceptance Criteria

- [ ] Chạy 1 lệnh → build 5 vùng thành công
- [ ] Mỗi vùng có đủ 4 file (ghz + pmtiles + db + version.json)
- [ ] Tổng size toàn VN < 700MB
- [ ] Script có thể chạy lại từ đầu (idempotent)

## Ngoài phạm vi

- Chưa có server hosting cho download
- Chưa có diff-based update (rebuild full mỗi lần)
"@

# ================================================================
# ISSUE 8: MapLibre GL integration
# ================================================================
New-Issue -Title "Core: Tích hợp MapLibre GL hiển thị bản đồ offline" -Milestone 2 -Labels @("type: feature", "priority: critical", "scope: mvp", "epic: map-display") -Body @"
## Mục tiêu

Tích hợp MapLibre GL Native vào Flutter app, đọc PMTiles local để hiển thị bản đồ Việt Nam offline. Đây là foundation cho toàn bộ map features.

## Phạm vi công việc

- Tích hợp package ``maplibre_gl`` vào project
- Copy ``metro_hcm.pmtiles`` vào test device
- Viết ``style.json`` cho MapLibre (tham khảo OSM Bright)
- Verify font glyph hỗ trợ tiếng Việt đầy đủ
- Hiển thị bản đồ metro_hcm offline

## Yêu cầu chức năng

- MapLibre GL đọc PMTiles từ local storage (không cần internet)
- Style.json với layers cơ bản: road, building, water, landuse, labels
- Font glyph SDF hỗ trợ Vietnamese characters (Latin Extended Additional)
- Pan/zoom/rotate gesture mượt (GPU rendering)

## Acceptance Criteria

- [ ] Bản đồ HCM hiển thị offline (airplane mode ON)
- [ ] Tên đường tiếng Việt hiển thị đúng 100% dấu (ư, ơ, ă, dấu thanh)
- [ ] Pan/zoom/rotate mượt 60fps trên thiết bị tầm trung
- [ ] Hẻm nhỏ hiển thị ở zoom cao
- [ ] Không crash khi xoay liên tục

## Ngoài phạm vi

- Chưa có GPS blue dot (issue riêng)
- Chưa có search bar UI
- Chưa có dark mode style
"@

# ================================================================
# ISSUE 9: MapDisplayCubit + GPS
# ================================================================
New-Issue -Title "Core: MapDisplayCubit + GPS vị trí hiện tại (blue dot)" -Milestone 2 -Labels @("type: feature", "priority: critical", "scope: mvp", "epic: map-display") -Body @"
## Mục tiêu

Implement ``MapDisplayCubit`` quản lý state bản đồ và tích hợp GPS hiển thị vị trí hiện tại (blue dot) trên map.

## Phạm vi công việc

- ``MapDisplayCubit``: quản lý center, zoom, rotation, isFollowingUser
- Tích hợp ``geolocator``: request permission, lấy vị trí
- Hiển thị blue dot cho vị trí hiện tại
- FAB "locate me" → animate camera về vị trí hiện tại
- Override ``emit()`` với guard ``if(isClosed) return``

## Yêu cầu chức năng

- State: ``MapDisplayState(center, zoom, rotation, isFollowingUser, userLocation)``
- Methods: ``updateCenter()``, ``updateZoom()``, ``toggleFollowUser()``, ``locateMe()``
- GPS: request permission → lấy vị trí → cập nhật blue dot
- FAB: tap → animate camera + zoom 15 + follow mode ON
- Khi user pan thủ công → follow mode tự OFF

## Acceptance Criteria

- [ ] MapDisplayCubit emit state đúng khi pan/zoom/rotate
- [ ] GPS permission request hoạt động (Android)
- [ ] Blue dot hiển thị tại vị trí hiện tại
- [ ] FAB locate me → camera animate mượt
- [ ] Follow mode tự OFF khi user pan thủ công
- [ ] Unit test cho MapDisplayCubit state transitions

## Ngoài phạm vi

- Chưa có heading-up mode (issue riêng)
- Chưa có search bar
"@

# ================================================================
# ISSUE 10: Heading-up mode
# ================================================================
New-Issue -Title "Core: Heading-up mode (xoay bản đồ theo hướng đầu xe)" -Milestone 2 -Labels @("type: feature", "priority: high", "scope: mvp", "epic: map-display") -Body @"
## Mục tiêu

Tích hợp compass sensor để xoay bản đồ theo hướng đầu xe máy (heading-up mode), critical cho trải nghiệm navigation.

## Phạm vi công việc

- Tích hợp ``flutter_compass`` package
- Thêm heading-up mode vào ``MapDisplayCubit``
- Toggle button: north-up ↔ heading-up
- Xoay camera theo heading real-time

## Yêu cầu chức năng

- Compass heading stream → xoay map camera bearing
- Toggle: north-up (bearing = 0, cố định) ↔ heading-up (bearing = compass heading)
- Khi heading-up: bản đồ xoay mượt theo hướng (debounce nếu cần, tránh giật)
- Icon toggle thay đổi giữa 🧭 (north-up) và 📍 (heading-up)

## Acceptance Criteria

- [ ] Compass heading hoạt động trên thiết bị thật
- [ ] Toggle north-up ↔ heading-up hoạt động
- [ ] Bản đồ xoay mượt theo hướng (không giật)
- [ ] Heading-up tự bật khi bắt đầu navigate (chuẩn bị cho Phase 4)

## Ngoài phạm vi

- Chưa tích hợp vào navigation flow (chỉ hiển thị heading)
"@

# ================================================================
# ISSUE 11: UI Map Shell
# ================================================================
New-Issue -Title "UI/UX: Layout chính cho map screen (search bar, FAB, bottom sheet)" -Milestone 2 -Labels @("type: feature", "priority: high", "scope: mvp", "epic: map-display") -Body @"
## Mục tiêu

Xây dựng UI shell cho map screen giống Google Maps: search bar nổi, FAB, bottom sheet. Đây là khung UI chính cho toàn bộ app.

## Phạm vi công việc

- Search bar nổi trên cùng (placeholder text, chưa có logic search)
- FAB locate ở góc phải dưới
- Bottom sheet (collapsed by default): hiển thị tên vị trí / thông tin
- Proper safe area / padding

## Yêu cầu chức năng

- Layout theo convention Google Maps mobile:
  - Search bar: rounded, shadow, icon search bên trái, icon profile bên phải
  - FAB: icon locate, positioned bottom-right trên bottom sheet
  - Bottom sheet: draggable, collapsed state chỉ hiện 1 dòng, expanded state hiện chi tiết
- Responsive trên mọi kích thước màn hình Android
- Montserrat font cho tất cả text

## Acceptance Criteria

- [ ] Search bar nổi hiển thị đúng vị trí
- [ ] FAB locate hoạt động (kết nối với MapDisplayCubit.locateMe)
- [ ] Bottom sheet kéo lên/xuống mượt
- [ ] Layout không bị che bởi system UI (status bar, navigation bar)

## Ngoài phạm vi

- Logic search thực tế (issue riêng)
- Navigation panel (issue riêng)
"@

# ================================================================
# ISSUE 12: SQLite POI Repository
# ================================================================
New-Issue -Title "Core: Setup sqflite đọc POI database + PoiRepository" -Milestone 2 -Labels @("type: feature", "priority: critical", "scope: mvp", "epic: search") -Body @"
## Mục tiêu

Setup ``sqflite`` đọc file ``poi.db`` (đã build ở data pipeline) và tạo ``PoiRepository`` với các method search cơ bản.

## Phạm vi công việc

- ``sqflite`` setup đọc ``poi.db`` read-only từ local storage
- ``PoiModel``: data class cho POI (id, name, lat, lon, type, address)
- ``PoiRepository`` (abstract + impl):
  - ``searchByName(query, limit)`` → FTS5 query
  - ``searchByNameAscii(query, limit)`` → query bảng không dấu
  - ``searchInBounds(bbox, limit)`` → R*Tree query
  - ``getById(id)``

## Yêu cầu chức năng

- Đọc ``poi.db`` dạng read-only (không modify data)
- FTS5 search: ``SELECT * FROM poi_fts WHERE poi_fts MATCH ?``
- Auto-detect: nếu query không có dấu → search cả FTS5 lẫn ascii
- R*Tree: ``SELECT * FROM poi_rtree WHERE min_lat >= ? AND max_lat <= ? ...``

## Acceptance Criteria

- [ ] ``sqflite`` mở ``poi.db`` thành công
- [ ] ``searchByName("phở")`` trả kết quả
- [ ] ``searchByNameAscii("pho")`` trả cùng kết quả
- [ ] ``searchInBounds`` trả POI trong bounding box
- [ ] Query < 50ms cho database > 10k POI
- [ ] Unit test cho PoiRepository (mock database)

## Ngoài phạm vi

- Chưa có SearchCubit (issue riêng)
- Chưa có search UI
"@

# ================================================================
# ISSUE 13: SearchCubit
# ================================================================
New-Issue -Title "Core: SearchCubit + logic tìm kiếm có dấu/không dấu" -Milestone 2 -Labels @("type: feature", "priority: critical", "scope: mvp", "epic: search") -Body @"
## Mục tiêu

Implement ``SearchCubit`` xử lý logic search với debounce, hỗ trợ tiếng Việt có dấu và không dấu.

## Phạm vi công việc

- ``SearchCubit``: state = idle / loading / results(list) / error
- Debounce 300ms bằng ``Timer``
- Auto-detect query có dấu/không dấu → chọn FTS5 hoặc ascii search
- Lưu recent search vào Hive

## Yêu cầu chức năng

- ``search(query)``: debounce 300ms → query PoiRepository → emit results
- ``clearSearch()``: reset state về idle
- Nếu query < 2 ký tự → không search, hiển thị recent search
- Recent search: lưu 20 query gần nhất vào Hive, hiển thị khi chưa gõ

## Acceptance Criteria

- [ ] Debounce 300ms hoạt động (gõ nhanh chỉ query lần cuối)
- [ ] Search "bệnh viện" → kết quả có dấu
- [ ] Search "benh vien" → cùng kết quả
- [ ] Recent search lưu và hiển thị đúng
- [ ] Unit test: debounce timing, state transitions

## Ngoài phạm vi

- Search UI (issue riêng)
- Viewport search (issue riêng)
"@

# ================================================================
# ISSUE 14: Search UI
# ================================================================
New-Issue -Title "UI/UX: Search overlay + suggestion list" -Milestone 2 -Labels @("type: feature", "priority: high", "scope: mvp", "epic: search") -Body @"
## Mục tiêu

Xây dựng full-screen search overlay với suggestion list real-time, kết nối SearchCubit.

## Phạm vi công việc

- Tap search bar → mở full-screen search overlay
- Text field auto-focus, keyboard hiển thị
- Suggestion list real-time khi gõ
- Mỗi suggestion: icon type + tên + địa chỉ
- Tap suggestion → dismiss search, animate camera tới vị trí, hiện marker
- Recent search hiển thị khi chưa gõ

## Yêu cầu chức năng

- Search overlay: full-screen, back button ở trên
- Suggestion item: ``[🏥] Bệnh viện Chợ Rẫy / 201B Nguyễn Chí Thanh, Q.5``
- Icon theo POI type: 🏥 bệnh viện, ☕ café, 🏪 cửa hàng, 🏧 ATM...
- Tap item → dismiss overlay + map animate + marker hiển thị
- Keyboard dismiss khi scroll suggestion list

## Acceptance Criteria

- [ ] Search overlay mở/đóng mượt
- [ ] Suggestion list cập nhật real-time khi gõ
- [ ] Icon POI type hiển thị đúng
- [ ] Tap suggestion → camera animate tới vị trí
- [ ] Marker hiển thị tại POI đã chọn
- [ ] Recent search hiển thị đúng

## Ngoài phạm vi

- Viewport search "tìm trong khu vực này" (issue riêng)
- Favorites UI (issue riêng)
"@

# ================================================================
# ISSUE 15: ViewportSearchBloc
# ================================================================
New-Issue -Title "Core: ViewportSearchBloc + tìm trong khu vực đang hiển thị" -Milestone 2 -Labels @("type: feature", "priority: high", "scope: mvp", "epic: search") -Body @"
## Mục tiêu

Implement ``ViewportSearchBloc`` (Bloc với ``restartable()`` transformer) để tìm POI trong khu vực bản đồ đang hiển thị, tự động cancel query cũ khi user pan/zoom.

## Phạm vi công việc

- ``ViewportSearchBloc`` (Bloc, không phải Cubit — cần ``restartable()``)
- Event: ``ViewportChanged(bbox)`` bắn khi pan/zoom
- Query R*Tree để lấy POI trong viewport
- Hiển thị POI markers trên map
- Nút "Tìm trong khu vực này"

## Yêu cầu chức năng

- ``restartable()`` transformer: cancel query cũ khi ``ViewportChanged`` mới đến
- Chỉ query khi user dừng pan/zoom > 500ms (debounce trong event)
- Hiển thị markers cho POI trong viewport (max 50 markers)
- Nút "Tìm trong khu vực này" hiển thị khi user pan xa khỏi kết quả cũ

## Acceptance Criteria

- [ ] Pan nhanh liên tục → chỉ query cuối cùng thực thi (restartable)
- [ ] POI markers hiển thị đúng trong viewport
- [ ] Max 50 markers (tránh lag)
- [ ] Nút "Tìm trong khu vực này" hoạt động
- [ ] Unit test: restartable behavior (cancel old events)

## Ngoài phạm vi

- Favorites + bookmark (issue riêng)
"@

# ================================================================
# ISSUE 16: Favorites + Recent search
# ================================================================
New-Issue -Title "Feature: Favorites + Recent search (Hive local)" -Milestone 2 -Labels @("type: feature", "priority: medium", "scope: mvp", "epic: search") -Body @"
## Mục tiêu

Lưu địa điểm yêu thích và lịch sử tìm kiếm gần đây vào Hive (local storage).

## Phạm vi công việc

- Hive box ``favorites``: lưu POI đã bookmark
- Hive box ``recent_search``: lưu 20 query gần nhất
- UI: icon bookmark trên bottom sheet khi xem POI
- UI: list favorites trong settings hoặc search screen

## Acceptance Criteria

- [ ] Bookmark POI → lưu vào Hive → icon đổi thành filled
- [ ] Un-bookmark → xóa khỏi Hive
- [ ] Recent search hiển thị khi mở search overlay
- [ ] Favorites list hiển thị đúng, tap → navigate tới POI

## Ngoài phạm vi

- Sync favorites lên Firebase (issue riêng, scope enhancement)
"@

# ================================================================
# ISSUE 17: GraphHopper native module
# ================================================================
New-Issue -Title "Core: GraphHopper native Android module (Kotlin)" -Milestone 3 -Labels @("type: feature", "priority: critical", "scope: mvp", "epic: routing") -Body @"
## Mục tiêu

Viết native Android module (Kotlin) load GraphHopper ``.ghz`` và expose routing function. Đây là phần kỹ thuật phức tạp nhất của dự án.

## Phạm vi công việc

- Tạo Kotlin class ``GraphHopperService`` trong ``android/app/src/main/kotlin/``
- Add GraphHopper core dependency vào ``build.gradle``
- Implement: ``init(graphFolder)``, ``route(from, to)``, ``dispose()``
- Load ``.ghz`` qua mmap
- Test native code standalone (không qua Flutter)

## Yêu cầu chức năng

- ``GraphHopperService``:
  ``````kotlin
  fun init(graphFolder: String)  // load .ghz, setup GH instance
  fun route(fromLat: Double, fromLon: Double, toLat: Double, toLon: Double): RouteResult
  fun dispose()  // cleanup
  ``````
- ``RouteResult``: polyline (List<LatLng>), distanceKm, durationSec, instructions (List<Instruction>)
- Memory: dùng mmap để load graph, không load full vào RAM

## Acceptance Criteria

- [ ] GraphHopper core dependency resolve thành công
- [ ] ``.ghz`` load thành công trên Android device
- [ ] ``route(10.776, 106.700, 10.780, 106.695)`` trả polyline hợp lệ
- [ ] Route nội thành < 200ms
- [ ] Route toàn quốc < 500ms
- [ ] Không crash khi OOM (graph quá lớn cho device)

## Ngoài phạm vi

- Chưa có MethodChannel bridge (issue riêng)
- Chưa test ProGuard/R8
"@

# ================================================================
# ISSUE 18: MethodChannel bridge
# ================================================================
New-Issue -Title "Core: MethodChannel bridge Flutter ↔ GraphHopper native" -Milestone 3 -Labels @("type: feature", "priority: critical", "scope: mvp", "epic: routing") -Body @"
## Mục tiêu

Tạo MethodChannel bridge giữa Flutter (Dart) và GraphHopper native (Kotlin), cho phép Dart gọi routing function.

## Phạm vi công việc

- Setup ``MethodChannel("com.smap/routing")`` trong ``MainActivity.kt``
- Dart side: ``RoutingService`` class wrap MethodChannel calls
- ``RoutingRepository`` (abstract + impl)
- Test round-trip: Dart → Kotlin → GraphHopper → Kotlin → Dart
- **CRITICAL: Test release build (R8/minify) + config ProGuard rules**

## Yêu cầu chức năng

- Channel methods:
  - ``initGraphHopper(graphFolder)`` → bool
  - ``getRoute(fromLat, fromLon, toLat, toLon)`` → JSON RouteResult
  - ``disposeGraphHopper()`` → void
- Dart ``RoutingService``: convert JSON → Dart models
- ``RoutingRepository``: abstract interface cho DI/testing

## Acceptance Criteria

- [ ] Dart gọi ``getRoute()`` → nhận polyline + distance + duration
- [ ] JSON serialization/deserialization không lỗi
- [ ] Release build (R8 minify) KHÔNG crash
- [ ] ProGuard rules config đúng cho GraphHopper reflection
- [ ] Unit test: RoutingRepository với mock MethodChannel
- [ ] Benchmark: 20 route requests liên tiếp → avg latency < 300ms

## Ngoài phạm vi

- Route preview UI (issue riêng)
- Navigation logic
"@

# ================================================================
# ISSUE 19: RoutePreviewCubit + route display
# ================================================================
New-Issue -Title "Core: RoutePreviewCubit + hiển thị route trên map" -Milestone 3 -Labels @("type: feature", "priority: critical", "scope: mvp", "epic: routing") -Body @"
## Mục tiêu

Implement ``RoutePreviewCubit`` hiển thị route preview trên map trước khi bắt đầu navigate.

## Phạm vi công việc

- ``RoutePreviewCubit``: state = idle / loading / routeReady / error
- UI flow: chọn điểm đích → tính route → hiển thị polyline trên map
- Bottom sheet: khoảng cách, thời gian, nút "Bắt đầu"
- Vẽ polyline route (màu xanh, shadow)

## Yêu cầu chức năng

- Trigger: long press trên map HOẶC chọn POI từ search → nút "Chỉ đường"
- Polyline: màu xanh primary, width 5, shadow đen mờ phía dưới
- Marker: origin (xanh) + destination (đỏ)
- Bottom sheet: ``12.5 km · 25 phút · [Bắt đầu]``
- Camera fit bounds để hiện toàn bộ route

## Acceptance Criteria

- [ ] Long press → tính route → polyline hiển thị
- [ ] Search → select POI → "Chỉ đường" → route hiển thị
- [ ] Bottom sheet hiển thị distance + duration đúng
- [ ] Camera fit bounds hiện toàn bộ route
- [ ] Nút "Bắt đầu" sẵn sàng (chưa navigate, chờ issue Navigation)
- [ ] Unit test: RoutePreviewCubit state transitions

## Ngoài phạm vi

- Turn-by-turn navigation (issue riêng)
- Multiple route alternatives
"@

# ================================================================
# ISSUE 20: NavigationBloc + GPS stream
# ================================================================
New-Issue -Title "Core: NavigationBloc + GPS stream tracking" -Milestone 3 -Labels @("type: feature", "priority: critical", "scope: mvp", "epic: navigation") -Body @"
## Mục tiêu

Implement ``NavigationBloc`` (Bloc với event transformers) quản lý toàn bộ navigation state: GPS tracking, route following, speed calculation.

## Phạm vi công việc

- ``NavigationBloc`` với events + transformers
- Subscribe GPS stream (``geolocator``, interval 1s)
- Tính tốc độ hiện tại từ GPS
- Map auto-follow user position
- Speed tracking buffer (RAM)

## Yêu cầu chức năng

- Events:
  - ``StartNavigation(route)`` | ``LocationUpdated(latLng, speed, heading)``
  - ``OffRouteDetected`` | ``RerouteRequested`` | ``StopNavigation``
- Transformers:
  - ``LocationUpdated`` → ``sequential()``
  - ``RerouteRequested`` → ``restartable()``
  - ``OffRouteDetected`` → ``droppable()``
- State: ``NavigationState(status, currentLocation, currentSpeed, distanceRemaining, eta, currentInstruction)``
- Speed buffer: lưu trong RAM, tính min/max/avg real-time

## Acceptance Criteria

- [ ] NavigationBloc nhận GPS events liên tục
- [ ] Tốc độ hiện tại tính đúng (km/h)
- [ ] Map auto-follow user position
- [ ] GPS event processing < 16ms (không block UI)
- [ ] Unit test: state transitions (start → navigating → arrive)

## Ngoài phạm vi

- Off-route detection (issue riêng)
- Turn-by-turn UI (issue riêng)
- Background location (issue riêng)
"@

# ================================================================
# ISSUE 21: Off-route detection + reroute
# ================================================================
New-Issue -Title "Core: Off-route detection + tự động tính lại đường" -Milestone 3 -Labels @("type: feature", "priority: critical", "scope: mvp", "epic: navigation") -Body @"
## Mục tiêu

Phát hiện khi xe đi lệch route (off-route) và tự động tính lại đường mới từ vị trí hiện tại.

## Phạm vi công việc

- Thuật toán tính khoảng cách từ vị trí → polyline gần nhất
- Ngưỡng off-route: > 50m → trigger reroute
- Gọi GraphHopper route mới: vị trí hiện tại → đích cũ
- Update polyline + instructions trên map
- Thông báo "Đang tính lại đường..."

## Yêu cầu chức năng

- Point-to-line-segment distance (optimize: chỉ check segment hiện tại + 5 tiếp theo)
- Off-route threshold: 50m (configurable)
- Reroute: ``restartable()`` — cancel reroute cũ nếu có cái mới
- Max reroute: 3 lần liên tiếp, sau đó prompt user xác nhận

## Acceptance Criteria

- [ ] Đi lệch > 50m → trigger reroute tự động
- [ ] Route mới tính đúng từ vị trí hiện tại
- [ ] Polyline + instructions update trên map
- [ ] Snackbar "Đang tính lại đường..." hiển thị
- [ ] Unit test: off-route detection với mock GPS points

## Ngoài phạm vi

- Voice notification khi off-route (TTS — scope enhancement)
"@

# ================================================================
# ISSUE 22: Turn-by-turn instructions
# ================================================================
New-Issue -Title "Core: Turn-by-turn instruction engine + advance logic" -Milestone 3 -Labels @("type: feature", "priority: critical", "scope: mvp", "epic: navigation") -Body @"
## Mục tiêu

Parse instruction list từ GraphHopper route và implement advance logic (chuyển sang instruction tiếp theo khi đến gần).

## Phạm vi công việc

- Parse GraphHopper instructions: TURN_LEFT, TURN_RIGHT, STRAIGHT, ROUNDABOUT, ARRIVE
- Advance logic: đến gần instruction point < 30m → advance
- Model: ``NavigationInstruction(type, streetName, distanceToNext, icon)``

## Yêu cầu chức năng

- Instruction types: LEFT, RIGHT, SHARP_LEFT, SHARP_RIGHT, STRAIGHT, ROUNDABOUT_EXIT_N, ARRIVE, DEPART
- Advance: khoảng cách tới waypoint < 30m → chuyển instruction
- Pre-announce: khi còn 200m → "Sau 200m, rẽ trái vào..."

## Acceptance Criteria

- [ ] Parse instructions từ GraphHopper response đúng
- [ ] Advance logic hoạt động khi GPS tiến gần waypoint
- [ ] Pre-announce trigger đúng timing (200m trước)
- [ ] Unit test: advance logic với mock GPS sequence

## Ngoài phạm vi

- TTS voice (scope enhancement)
- Navigation UI panel (issue riêng)
"@

# ================================================================
# ISSUE 23: Navigation UI panel
# ================================================================
New-Issue -Title "UI/UX: Navigation panel (turn instruction + speed + ETA)" -Milestone 3 -Labels @("type: feature", "priority: critical", "scope: mvp", "epic: navigation") -Body @"
## Mục tiêu

Xây dựng navigation UI: panel hướng rẽ phía trên, bar tốc độ/ETA phía dưới, trip summary khi kết thúc.

## Phạm vi công việc

- Top bar: icon hướng rẽ + khoảng cách tới ngã rẽ + tên đường
- Bottom bar: tốc độ hiện tại, quãng đường còn lại, ETA
- Nút "Kết thúc" → trip summary
- Map: heading-up, auto-follow, dim đường đã đi, zoom theo tốc độ

## Yêu cầu chức năng

- Top instruction panel:
  ``[↰] Rẽ trái sau 200m · Nguyễn Trãi``
- Bottom info bar:
  ``45 km/h | Còn 8.2 km | ETA 15:30``
- Map behavior khi navigate:
  - Heading-up bắt buộc
  - Zoom auto: chậm → zoom in (16), nhanh → zoom out (14)
  - Dim polyline phía sau (phần đã đi)
- Trip summary: route đã đi, tốc độ min/max/avg, thời gian, quãng đường

## Acceptance Criteria

- [ ] Top panel hiển thị instruction đúng, icon rõ ràng
- [ ] Bottom bar: tốc độ + distance + ETA cập nhật real-time
- [ ] Heading-up + auto-follow hoạt động
- [ ] Dim polyline phía sau
- [ ] Nút "Kết thúc" → trip summary hiển thị đúng stats

## Ngoài phạm vi

- Dark mode navigation (issue riêng)
"@

# ================================================================
# ISSUE 24: Background location
# ================================================================
New-Issue -Title "Core: Background location service (foreground service)" -Milestone 3 -Labels @("type: feature", "priority: critical", "scope: mvp", "epic: navigation") -Body @"
## Mục tiêu

Setup foreground service cho GPS tracking khi tắt màn hình — bắt buộc cho navigation thực tế.

## Phạm vi công việc

- Foreground service với persistent notification
- GPS tracking tiếp tục khi app background / screen off
- Battery optimization exemption request
- Test trên 2-3 thiết bị thật (Samsung, Xiaomi)

## Yêu cầu chức năng

- Notification: "S-Map đang điều hướng · 12.5 km còn lại"
- GPS interval: 1 giây (giữ nguyên khi background)
- Battery exemption: prompt user cho phép (programmatic)
- Resume: mở app lại → UI update đúng vị trí hiện tại

## Acceptance Criteria

- [ ] Tắt màn hình 10 phút → mở lại → vị trí đúng
- [ ] Notification persistent hiển thị đúng
- [ ] Test Samsung: background GPS không bị kill
- [ ] Test Xiaomi: background GPS không bị kill
- [ ] Battery drain < 5% cho 30 phút navigate

## Ngoài phạm vi

- Resume trip sau khi app bị force kill (issue riêng)
"@

# ================================================================
# ISSUE 25: Snap-to-road service
# ================================================================
New-Issue -Title "Core: Snap-to-road service (GraphHopper LocationIndex)" -Milestone 4 -Labels @("type: feature", "priority: high", "scope: mvp", "epic: route-drawing") -Body @"
## Mục tiêu

Extend GraphHopper native module với chức năng snap-to-road: snap 1 tọa độ vào road network gần nhất.

## Phạm vi công việc

- Extend ``GraphHopperService`` (Kotlin): thêm ``nearestPoint(lat, lon)``
- Dùng GraphHopper ``LocationIndex.findClosest()``
- Extend MethodChannel: thêm method ``snapToRoad``
- Dart side: ``RoutingService.snapToRoad(lat, lon)``

## Acceptance Criteria

- [ ] Snap random point → snapped point nằm trên đường
- [ ] Trả về: snapped lat/lon, tên đường
- [ ] Snap < 50ms
- [ ] Unit test với mock data

## Ngoài phạm vi

- RouteDrawingBloc (issue riêng)
"@

# ================================================================
# ISSUE 26: RouteDrawingBloc
# ================================================================
New-Issue -Title "Feature: RouteDrawingBloc + tap-to-add + auto-connect" -Milestone 4 -Labels @("type: feature", "priority: high", "scope: mvp", "epic: route-drawing") -Body @"
## Mục tiêu

Implement ``RouteDrawingBloc`` cho phép user tap từng điểm trên map → snap-to-road → auto-connect bằng route hợp lệ.

## Phạm vi công việc

- ``RouteDrawingBloc`` (Bloc, cần ``restartable()`` cho snap)
- Events: PointTapped, UndoLastPoint, RedoPoint, ClearRoute, SaveRoute
- Tap → snap to road → marker
- 2+ points → auto-connect bằng ``getRoute()``
- Hiển thị polyline segments

## Yêu cầu chức năng

- ``restartable()`` cho ``PointTapped``: cancel snap cũ nếu tap nhanh liên tiếp
- Auto-connect: dùng ``getRoute(pointN, pointN+1)``
- Nếu 2 điểm không nối được → warning "Không tìm được đường"
- Hiển thị: segment xanh (đã nối), segment xám (đang tính)

## Acceptance Criteria

- [ ] Tap → snap → marker hiển thị
- [ ] 2+ points → polyline segment tự động nối
- [ ] Tap nhanh liên tiếp → chỉ snap cuối cùng
- [ ] Warning khi 2 điểm không nối được
- [ ] Unit test: state transitions

## Ngoài phạm vi

- Kéo waypoint (drag to reroute) — scope enhancement
"@

# ================================================================
# ISSUE 27: Undo/redo + save custom routes
# ================================================================
New-Issue -Title "Feature: Undo/redo + lưu/load custom routes" -Milestone 4 -Labels @("type: feature", "priority: medium", "scope: mvp", "epic: route-drawing") -Body @"
## Mục tiêu

Thêm undo/redo cho custom route drawing và lưu routes vào Hive.

## Phạm vi công việc

- Undo: xóa point cuối + segment → push vào redo stack
- Redo: lấy lại point từ redo stack
- Clear: xóa toàn bộ route
- Save: lưu custom route vào Hive
- Load: list + load saved routes

## Acceptance Criteria

- [ ] Undo/redo hoạt động đúng
- [ ] Save route → load lại → hiển thị đúng
- [ ] Clear xóa toàn bộ

## Ngoài phạm vi

- Export/share route
"@

# ================================================================
# ISSUE 28: Trip storage + stats
# ================================================================
New-Issue -Title "Feature: Trip storage local + RouteProfileCubit thống kê" -Milestone 4 -Labels @("type: feature", "priority: high", "scope: mvp", "epic: stats") -Body @"
## Mục tiêu

Lưu trip data vào Hive khi navigate xong, implement ``RouteProfileCubit`` tính aggregate stats.

## Phạm vi công việc

- Trip model: id, startedAt, endedAt, distanceKm, durationSec, speeds, polyline
- Lưu trip khi NavigationBloc emit completed
- ``RouteProfileCubit``: load trips, tính aggregate
- ``TripHistoryCubit``: danh sách trips

## Acceptance Criteria

- [ ] Trip lưu vào Hive khi navigate xong
- [ ] Load lại trips đúng
- [ ] Stats aggregate: total distance, avg speed, trip count
- [ ] Unit test: aggregate calculation

## Ngoài phạm vi

- Stats UI dashboard (issue riêng)
- Firebase sync (issue riêng)
"@

# ================================================================
# ISSUE 29: Stats dashboard UI
# ================================================================
New-Issue -Title "UI/UX: Stats dashboard + charts (fl_chart)" -Milestone 4 -Labels @("type: feature", "priority: medium", "scope: mvp", "epic: stats") -Body @"
## Mục tiêu

Xây dựng stats dashboard hiển thị thống kê hành trình với charts trực quan.

## Phạm vi công việc

- Dashboard: thống kê hôm nay, tháng, năm
- Bar chart quãng đường theo ngày (``fl_chart``)
- Trip history list
- Tap trip → hiển thị route trên map

## Acceptance Criteria

- [ ] Dashboard hiển thị stats đúng
- [ ] Chart render đúng data
- [ ] Trip history list hoạt động
- [ ] Tap trip → route hiển thị trên map

## Ngoài phạm vi

- Export stats (CSV/PDF)
"@

# ================================================================
# ISSUE 30: Firebase Auth + Sync
# ================================================================
New-Issue -Title "Feature: Firebase Auth anonymous + Firestore sync" -Milestone 4 -Labels @("type: feature", "priority: medium", "scope: enhancement", "epic: firebase-sync") -Body @"
## Mục tiêu

Setup Firebase Auth (anonymous) và sync trip data lên Firestore khi có mạng.

## Phạm vi công việc

- Firebase Auth: anonymous sign-in
- ``AuthCubit``
- ``SyncBloc`` (``droppable()``): sync khi trip xong + có mạng
- Offline queue: lưu pending sync vào Hive, flush khi online
- Firestore write: trips + daily stats

## Acceptance Criteria

- [ ] Anonymous auth thành công
- [ ] Trip data sync lên Firestore
- [ ] Offline queue hoạt động: 3 trips offline → bật mạng → sync tất cả
- [ ] SyncBloc droppable: không sync chồng

## Ngoài phạm vi

- Email/password auth
- Cloud Functions rollup
"@

# ================================================================
# ISSUE 31: Region download management
# ================================================================
New-Issue -Title "Feature: DownloadRegionCubit + quản lý vùng offline" -Milestone 4 -Labels @("type: feature", "priority: high", "scope: mvp", "epic: region-mgmt") -Body @"
## Mục tiêu

Quản lý tải/xóa data offline theo 5 vùng (metro_hcm, metro_hn, mien_nam, mien_trung, mien_bac).

## Phạm vi công việc

- ``DownloadRegionCubit``: idle / downloading(progress) / done / error
- Region list UI: 5 vùng, trạng thái, nút tải/xóa
- Download service: tải zip → extract → lưu app storage
- Version check + update badge
- Hiển thị tổng dung lượng

## Acceptance Criteria

- [ ] Tải vùng thành công → data available offline
- [ ] Xóa vùng → free storage
- [ ] Version check hoạt động
- [ ] Progress hiển thị đúng khi tải

## Ngoài phạm vi

- Resume download giữa chừng (v2)
- Diff-based update
"@

# ================================================================
# ISSUE 32: Resume trip + edge cases
# ================================================================
New-Issue -Title "Feature: Resume trip sau app kill + xử lý edge cases" -Milestone 4 -Labels @("type: feature", "priority: high", "scope: mvp", "epic: navigation") -Body @"
## Mục tiêu

Xử lý edge case: app bị kill giữa navigate → resume khi mở lại.

## Phạm vi công việc

- Lưu navigation state vào Hive mỗi 30 giây
- Khi mở app → check saved state → prompt resume
- Edge cases: hết storage, download fail, xóa vùng đang dùng

## Acceptance Criteria

- [ ] Kill app giữa navigate → mở lại → prompt "Tiếp tục?"
- [ ] Resume → navigation tiếp tục từ vị trí hiện tại
- [ ] Hết storage → warning trước khi tải
- [ ] Xóa vùng đang dùng → warning

## Ngoài phạm vi

- Auto-save route trace cho replay
"@

# ================================================================
# ISSUE 33: Dark mode
# ================================================================
New-Issue -Title "UI/UX: Dark mode + night map style" -Milestone 4 -Labels @("type: feature", "priority: medium", "scope: enhancement", "epic: map-display") -Body @"
## Mục tiêu

Thêm dark mode cho app và night style cho bản đồ (giảm chói khi chạy xe đêm).

## Phạm vi công việc

- Night style.json cho MapLibre (dark colors, muted labels)
- App dark theme (AppColors dark variant)
- Auto-switch theo system setting hoặc manual toggle
- Navigation UI dark mode

## Acceptance Criteria

- [ ] Map night style hiển thị đúng
- [ ] App dark theme nhất quán
- [ ] Toggle manual hoạt động
- [ ] Navigation UI readable trong dark mode
"@

# ================================================================
# ISSUE 34: Onboarding flow
# ================================================================
New-Issue -Title "UI/UX: Onboarding flow (lần đầu mở app)" -Milestone 4 -Labels @("type: feature", "priority: medium", "scope: enhancement", "epic: region-mgmt") -Body @"
## Mục tiêu

Tạo onboarding flow cho lần đầu mở app: chào mừng → chọn vùng tải → đợi download → ready.

## Phạm vi công việc

- Welcome screen: giới thiệu app
- Region picker: chọn vùng cần tải
- Download progress screen
- Ready → navigate tới map

## Acceptance Criteria

- [ ] Lần đầu mở → onboarding hiển thị
- [ ] Chọn vùng → tải → ready → map
- [ ] Lần sau mở → skip onboarding (đã có data)
"@

# ================================================================
# ISSUE 35: Test suite
# ================================================================
New-Issue -Title "Test: Unit tests + Integration tests cho toàn bộ Cubits/Blocs" -Milestone 4 -Labels @("type: test", "priority: high", "scope: mvp") -Body @"
## Mục tiêu

Viết test suite bao phủ toàn bộ Cubits/Blocs và integration tests cho native bridge.

## Phạm vi công việc

- Unit tests cho tất cả Cubits: MapDisplay, Search, RoutePreview, RouteProfile, TripHistory, DownloadRegion, Auth
- Unit tests cho tất cả Blocs: ViewportSearch, RouteDrawing, Navigation, Sync
- Integration test: MethodChannel routing bridge
- Performance test: route latency benchmark

## Acceptance Criteria

- [ ] > 80% code coverage cho Cubits/Blocs
- [ ] Integration test native bridge pass
- [ ] Performance: route < 500ms consistently
- [ ] All tests pass trên CI
"@

Write-Output ""
Write-Output "========================================="
Write-Output "ALL 35 ISSUES CREATED SUCCESSFULLY"
Write-Output "========================================="
