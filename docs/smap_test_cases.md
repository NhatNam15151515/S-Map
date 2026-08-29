# S-Map Test Case Design — Đối chiếu chuẩn Google Maps Workflow

> **Nguyên tắc**: Không nuông chiều S-Map. Logic test bám sát hành vi Google Maps.
> Nếu S-Map vi phạm chuẩn Google Maps → test case phải **FAIL** để phát hiện sai lệch.

---

## Mục lục

1. [Module 1: MapDisplayCubit — Khám phá Bản đồ](#module-1-mapdisplaycubit--khám-phá-bản-đồ)
2. [Module 2: SearchCubit — Tìm kiếm](#module-2-searchcubit--tìm-kiếm)
3. [Module 3: ViewportSearchBloc — Tìm kiếm theo Viewport](#module-3-viewportsearchbloc--tìm-kiếm-theo-viewport)
4. [Module 4: RoutePreviewCubit — Xem trước Lộ trình](#module-4-routepreviewcubit--xem-trước-lộ-trình)
5. [Module 5: RouteProfileCubit — Chuyển đổi Phương tiện](#module-5-routeprofilecubit--chuyển-đổi-phương-tiện)
6. [Module 6: NavigationBloc — Dẫn đường Turn-by-Turn](#module-6-navigationbloc--dẫn-đường-turn-by-turn)
7. [Module 7: DownloadRegionCubit — Tải Bản đồ Ngoại tuyến](#module-7-downloadregioncubit--tải-bản-đồ-ngoại-tuyến)
8. [Module 8: FavoritesCubit — Địa điểm Yêu thích](#module-8-favoritescubit--địa-điểm-yêu-thích)
9. [Module 9: TripHistoryCubit — Lịch sử Chuyến đi](#module-9-triphistorycubit--lịch-sử-chuyến-đi)
10. [Module 10: SyncBloc — Đồng bộ Offline](#module-10-syncbloc--đồng-bộ-offline)
11. [Module 11: AuthCubit — Xác thực & Onboarding](#module-11-authcubit--xác-thực--onboarding)
12. [Module 12: RouteDrawingBloc — Vẽ Lộ trình Tùy chỉnh](#module-12-routedrawingbloc--vẽ-lộ-trình-tùy-chỉnh)
13. [Cross-Cutting: Tương tác giữa các Module](#cross-cutting-tương-tác-giữa-các-module)
14. [Integration Tests: MethodChannel Native Bridge](#integration-tests-methodchannel-native-bridge)

---

## Module 1: MapDisplayCubit — Khám phá Bản đồ

> **Chuẩn GG Maps**: Khi mở app → camera tại GPS hiện tại. Tap GPS button → animate về vị trí. Tap lần 2 → chế độ la bàn (Heading-up). Kéo bản đồ → ngừng follow user.

### Unit Tests

| ID | Test Case | Setup | Action | Expected | S-Map Code |
|---|---|---|---|---|---|
| MAP-01 | Camera khởi tạo tại GPS hiện tại khi `onStyleLoaded` | Mock `ILocationService.getCurrentPosition()` → `(10.762, 106.660)` | `cubit.onStyleLoaded()` | State: `status == ready`, `currentPosition == LatLng(10.762, 106.660)`, `isFollowingUser == true`, `cameraAction.type == animateToPosition` | `MapDisplayCubit.onStyleLoaded()` → `locateMe()` |
| MAP-02 | Fallback về `defaultLocation` khi GPS bị từ chối quyền | Mock `ILocationService` throw `PermissionDeniedException` | `cubit.locateMe()` | State: `currentPosition == MapConstants.defaultLocation`, `isFollowingUser == false`, `errorMessageKey == 'map.location_permission_denied'` | `MapDisplayCubit._fallbackToDefaultLocation()` |
| MAP-03 | Fallback về `defaultLocation` khi GPS bị tắt service | Mock `ILocationService` throw `LocationServiceDisabledException` | `cubit.locateMe()` | State: `errorMessageKey == 'map.location_service_disabled'` | `MapDisplayCubit._resolveLocationErrorKey()` |
| MAP-04 | Instant Flyback — Dùng `lastKnownPosition` trước khi chờ fresh GPS | Mock `getLastKnownPosition()` → `(10.1, 106.1)` (50ms), `getCurrentPosition()` → `(10.2, 106.2)` (500ms) | `cubit.locateMe()` | Emit thứ 1: `currentPosition == (10.1, 106.1)`. Emit thứ 2: `currentPosition == (10.2, 106.2)`. Cả 2 có `cameraAction.type == animateToPosition` | `MapDisplayCubit.locateMe()` Phase 1 → Phase 2 |
| MAP-05 | Tap GPS lần 1 → `locateMe()`, lần 2 → `setHeadingUp()` (chế độ la bàn) | Cubit ở trạng thái `northUp`, GPS ready | `cubit.locateMe()` → `cubit.toggleOrientationMode()` | State: `orientationMode == headingUp`, `isFollowingUser == true`. Compass stream được subscribe. | `MapDisplayCubit.toggleOrientationMode()` |
| MAP-06 | Heading-up: Camera xoay theo la bàn với bộ lọc Anti-jitter (deadband 1.5°) | Cubit ở `headingUp` mode. `_lastRotatedHeading = 90.0` | Stream phát `heading = 90.5` rồi `heading = 95.0` | Heading 90.5°: **bị bỏ qua** (diff 0.5° < 1.5° deadband). Heading 95.0°: Emit state với `rotation == 95.0`, `cameraAction.type == bearingTo` | `MapDisplayCubit._handleHeadingUpdate()` |
| MAP-07 | Kéo bản đồ → ngừng follow user, chuyển về North-up | Cubit ở `headingUp`, `isFollowingUser == true` | `cubit.onCameraTrackingDismissed()` | State: `isFollowingUser == false`, `orientationMode == northUp`. Compass stream bị cancel. | `MapDisplayCubit.onCameraTrackingDismissed()` |
| MAP-08 | `onCameraMove` không emit trùng lặp nếu camera position không đổi | State hiện tại: `center == (10,106)`, `zoom == 14`, `rotation == 0` | `cubit.onCameraMove(CameraPosition(target: LatLng(10,106), zoom: 14, bearing: 0))` | **Không emit state mới** (tối ưu performance) | `MapDisplayCubit.onCameraMove()` |
| MAP-09 | `selectPoi` animate camera tới POI và tắt follow user | POI: `lat=10.8, lon=106.7, name="Landmark 81"` | `cubit.selectPoi(poi)` | State: `selectedPoi == poi`, `center == LatLng(10.8, 106.7)`, `isFollowingUser == false`, `cameraAction.zoom == 16.0` | `MapDisplayCubit.selectPoi()` |
| MAP-10 | `zoomIn` clamp tối đa `MapConstants.maxZoom` | State hiện tại: `zoom == MapConstants.maxZoom` | `cubit.zoomIn()` | State: `zoom == MapConstants.maxZoom` (không vượt giới hạn). `cameraAction.type == zoomIn` | `MapDisplayCubit.zoomIn()` |
| MAP-11 | `zoomOut` clamp tối thiểu `MapConstants.minZoom` | State hiện tại: `zoom == MapConstants.minZoom` | `cubit.zoomOut()` | State: `zoom == MapConstants.minZoom` (không xuống dưới giới hạn) | `MapDisplayCubit.zoomOut()` |
| MAP-12 | Dark mode toggle cập nhật map style ngay lập tức | Mock `IMapStyleService.getStyleJson(isDarkMode: true)` → `'dark_style.json'` | `cubit.updateMapTheme(isDarkMode: true)` | State: `styleString == 'dark_style.json'`, `isNightMode == true` | `MapDisplayCubit.updateMapTheme()` |
| MAP-13 | Dark mode toggle KHÔNG emit nếu style không đổi | State hiện tại: `isNightMode == true`, `styleString == 'dark'`. Mock trả `'dark'` | `cubit.updateMapTheme(isDarkMode: true)` | **Không emit state mới** | `MapDisplayCubit.updateMapTheme()` |

---

## Module 2: SearchCubit — Tìm kiếm

> **Chuẩn GG Maps**: Debounce 300ms. Kết quả sắp xếp theo khoảng cách. Race condition guard (stale response). Lịch sử tìm kiếm tự động lưu. Gợi ý = Recent + DB suggestions hợp nhất.

### Unit Tests

| ID | Test Case | Setup | Action | Expected | S-Map Code |
|---|---|---|---|---|---|
| SCH-01 | Debounce 300ms — Chỉ gọi API 1 lần khi gõ liên tục | Mock `IPoiRepository.search()` | `cubit.onQueryChanged('ca')` → 100ms → `cubit.onQueryChanged('cafe')` | API chỉ được gọi **1 lần** với query `'cafe'` (không bao giờ gọi `'ca'`). Timer bị cancel/restart. | `SearchCubit.onQueryChanged()` |
| SCH-02 | Query rỗng (xóa hết text) → reset về `initial`, xóa results | State đang có results | `cubit.onQueryChanged('')` | State: `status == initial`, `query == ''`, `results == []`, `suggestions == []` | `SearchCubit.onQueryChanged()` |
| SCH-03 | Query không hợp lệ (injection / quá dài) → reset, không gọi API | Mock validator reject | `cubit.onQueryChanged('DROP TABLE;')` | State: `status == initial`, `results == []`. API search **KHÔNG được gọi**. | `Validator.isValidSearchQuery()` |
| SCH-04 | Kết quả tìm kiếm sắp xếp theo khoảng cách gần nhất GPS | Mock trả về 3 POI ở khoảng cách: 5km, 1km, 3km. `userLocation = (10.7, 106.6)` | `cubit.search('quán ăn')` | `results[0]` là POI 1km, `results[1]` là POI 3km, `results[2]` là POI 5km | `PoiCategoryHelper.sortPoisByDistance()` |
| SCH-05 | Race condition guard — Response cũ bị bỏ qua | Gọi `search('A')` (delay 500ms) → ngay lập tức gọi `search('B')` (delay 100ms) | Response `'B'` trả về trước | State cuối cùng: `query == 'B'`, `results` = kết quả của `'B'`. Response `'A'` bị **bỏ qua** nhờ guard `state.query != query`. | `SearchCubit._fetchSuggestionsAndResults()` dòng 100 |
| SCH-06 | `search()` tự động lưu vào Recent Searches | Mock `IRecentSearchService` | `cubit.search('Bưu điện thành phố')` | `_recentSearchService.addRecentSearch('Bưu điện thành phố')` được gọi. State: `recentSearches` chứa query mới. | `SearchCubit.search()` dòng 178 |
| SCH-07 | Gợi ý (Suggestions) = Recent Searches + DB Suggestions, loại bỏ trùng lặp | Recent: `['Cafe', 'Quán ăn']`. DB suggestions: `['Cafe Trung Nguyên', 'cafe sữa']` | `cubit.onQueryChanged('cafe')` | `suggestions` chứa: `['Cafe', 'Cafe Trung Nguyên', 'cafe sữa']` (không trùng lặp). Recent được ưu tiên trước. | `SearchCubit._fetchSuggestionsAndResults()` dòng 114-129 |
| SCH-08 | Gợi ý tối đa 10 mục | Mock trả về 15 suggestions | `cubit.onQueryChanged('test')` | `suggestions.length <= 10` | `SearchCubit._fetchSuggestionsAndResults()` dòng 134 `.take(10)` |
| SCH-09 | API lỗi → emit `error` state | Mock `IPoiRepository.search()` throw `Exception` | `cubit.search('xyz')` | State: `status == error`, `errorMessage` chứa thông tin lỗi | `SearchCubit.search()` catch block |
| SCH-10 | `clearSearch()` hủy timer debounce và reset state | Cubit đang có results + đang chờ debounce | `cubit.clearSearch()` | State: `status == initial`, `query == ''`, `results == []`, `suggestions == []`. Timer bị cancel. | `SearchCubit.clearSearch()` |
| SCH-11 | `updateUserLocation` sắp xếp lại kết quả hiện có theo vị trí mới | Cubit đang có 3 results. Vị trí cũ: `(10, 106)` | `cubit.updateUserLocation(LatLng(11, 107))` | `results` được sắp xếp lại theo khoảng cách tới `(11, 107)`. Không gọi API mới. | `SearchCubit.updateUserLocation()` |
| SCH-12 | `removeRecentSearch` xóa đúng 1 mục khỏi Recent | Recent: `['A', 'B', 'C']` | `cubit.removeRecentSearch('B')` | `recentSearches == ['A', 'C']` | `SearchCubit.removeRecentSearch()` |
| SCH-13 | `clearRecentSearches` xóa sạch toàn bộ | Recent: `['A', 'B', 'C']` | `cubit.clearRecentSearches()` | `recentSearches == []` | `SearchCubit.clearRecentSearches()` |

---

## Module 3: ViewportSearchBloc — Tìm kiếm theo Viewport

> **Chuẩn GG Maps**: Category pills tìm POI trong viewport. Kéo bản đồ → nút "Tìm kiếm ở khu vực này". Debounce viewport changes.

| ID | Test Case | Setup | Action | Expected | S-Map Code |
|---|---|---|---|---|---|
| VPS-01 | Debounce 250ms cho viewport search | Mock `IPoiRepository` | Dispatch `SearchInViewportRequested` 2 lần nhanh trong 100ms | API chỉ gọi **1 lần** (request đầu bị cancel bởi `debounceRestartable`) | `ViewportSearchBloc` transformer |
| VPS-02 | Đổi category filter → gọi lại search | Category hiện tại: `'all'` | Dispatch `ViewportCategoryFilterChanged(category: 'restaurant')` | API gọi lại với category `'restaurant'`. State: `results` cập nhật. | `ViewportSearchBloc._onCategoryFilterChanged()` |
| VPS-03 | "Search This Area" → tìm kiếm với bounds mới | Bounds cũ: `(10,106)-(11,107)` | Dispatch `SearchThisAreaPressed(bounds: newBounds)` | API gọi với `newBounds`. State: results cập nhật cho vùng mới. | `ViewportSearchBloc._onSearchThisArea()` |
| VPS-04 | `ClearViewportSearch` reset toàn bộ state | State đang có results | Dispatch `ClearViewportSearch()` | State: `status == initial`, `results == []` | `ViewportSearchBloc._onClearViewportSearch()` |
| VPS-05 | Stale event guard — Ignore events trước thời điểm clear | Clear xảy ra tại `T=100`. Event tạo tại `T=50` đến muộn. | Event `T=50` được xử lý sau clear | **Bị bỏ qua** nhờ `_lastClearedAt` guard | `ViewportSearchBloc._onSearchInViewport()` dòng 45 |
| VPS-06 | Generation guard — Response cũ bị bỏ qua | 2 requests liên tiếp, response request 1 đến sau request 2 | Response 1 trả về muộn | Response 1 bị **bỏ qua** nhờ `_queryGeneration` | `ViewportSearchBloc._executeViewportQuery()` |

---

## Module 4: RoutePreviewCubit — Xem trước Lộ trình

> **Chuẩn GG Maps**: Tap "Chỉ đường" → tính route. Hiển thị polyline + thời gian + khoảng cách. Đổi phương tiện → tính lại. Generation guard chống stale response.

| ID | Test Case | Setup | Action | Expected | S-Map Code |
|---|---|---|---|---|---|
| RTP-01 | `previewRouteToPoi` tính route từ GPS → POI | Mock GPS `(10.7, 106.6)`, POI `(10.8, 106.7)`. Mock `calculateRoute` → success | `cubit.previewRouteToPoi(poi)` | State: `status == success`, `routeResult.distance > 0`, `routeResult.points.isNotEmpty`, `origin`, `destination` đúng | `RoutePreviewCubit.previewRouteToPoi()` |
| RTP-02 | GPS thất bại → fallback `defaultLocation` làm origin | Mock `ILocationService` throw Exception | `cubit.previewRouteToPoi(poi)` | Origin = `MapConstants.defaultLocation`. Route vẫn được tính với origin fallback. | `RoutePreviewCubit._getUserPosition()` |
| RTP-03 | Route calculation thất bại → emit error state | Mock `calculateRoute` → `isSuccess == false` | `cubit.getRoute(origin, destination)` | State: `status == error`, `errorMessageKey != null`, `routeResult == null` | `RoutePreviewCubit.getRoute()` |
| RTP-04 | Generation guard — Stale response bị bỏ qua | Gọi `getRoute(A→B)` (slow) → ngay lập tức gọi `getRoute(A→C)` (fast) | Response `A→B` trả về muộn | State cuối: route = `A→C`. Response `A→B` bị bỏ qua nhờ `_currentGeneration`. | `RoutePreviewCubit.getRoute()` dòng 105 |
| RTP-05 | `changeProfile` tự động tính lại route | State có `origin + destination`, profile = `'motorcycle'` | `cubit.changeProfile('car')` | `getRoute` được gọi lại với `profile == 'car'`. State: route mới. | `RoutePreviewCubit.changeProfile()` |
| RTP-06 | `changeProfile` KHÔNG tính lại nếu profile giống và đã có route | State: `profile == 'motorcycle'`, `hasRoute == true` | `cubit.changeProfile('motorcycle')` | **Không gọi API**. State không đổi. | `RoutePreviewCubit.changeProfile()` dòng 152 |
| RTP-07 | `clearRoute` increment generation và reset state | State đang có route | `cubit.clearRoute()` | State = `RoutePreviewState()` (mặc định). `_currentGeneration` tăng lên (block stale). | `RoutePreviewCubit.clearRoute()` |
| RTP-08 | Exception trong `getRoute` → emit error với `routing_error_generic` | Mock `calculateRoute` throw Exception | `cubit.getRoute(origin, destination)` | State: `status == error`, `errorMessageKey == LocaleKeys.routing_error_generic` | `RoutePreviewCubit.getRoute()` catch block |

---

## Module 5: RouteProfileCubit — Chuyển đổi Phương tiện

| ID | Test Case | Setup | Action | Expected | S-Map Code |
|---|---|---|---|---|---|
| RPF-01 | Đổi profile emit state mới ngay lập tức | State: `profile == 'motorcycle'` | `cubit.setProfile('car')` | State: `profile == 'car'` | `RouteProfileCubit.setProfile()` |
| RPF-02 | Profile không đổi → KHÔNG emit | State: `profile == 'motorcycle'` | `cubit.setProfile('motorcycle')` | **Không emit state mới** | `RouteProfileCubit.setProfile()` |

---

## Module 6: NavigationBloc — Dẫn đường Turn-by-Turn

> **Chuẩn GG Maps**: GPS tracking 1Hz. Off-route detection > 30m trong 3s → reroute. Reroute cooldown 2s. Auto-save session 30s. Resume trip after app killed. Voice guidance tại 1km/500m/200m/50m.

| ID | Test Case | Setup | Action | Expected | S-Map Code |
|---|---|---|---|---|---|
| NAV-01 | `StartNavigation` khởi tạo GPS stream + emit `navigating` | Mock `ILocationService.getPositionStream()`, RouteResult hợp lệ | Dispatch `StartNavigation(initialRoute, origin, dest)` | State: `status == navigating`, `currentRoute == initialRoute`, `instructions.isNotEmpty`. GPS stream được subscribe. | `NavigationBloc._onStartNavigation()` |
| NAV-02 | `LocationUpdated` snap vị trí lên polyline + cập nhật chỉ dẫn rẽ | Route có instruction "Rẽ phải sau 200m tại Nguyễn Huệ" | Dispatch `LocationUpdated(lat, lon)` gần instruction point | State: `currentInstruction` = instruction tương ứng, `distanceToNextTurn` cập nhật, `currentPosition` được snap. | `NavigationBloc._onLocationUpdated()` |
| NAV-03 | Off-route detection: GPS cách polyline > 30m → trigger reroute | GPS liên tục ở vị trí cách polyline > 30m | 3 lần `LocationUpdated` liên tiếp cách polyline > 30m | Dispatch `RerouteRequested` tự động. State: `isRerouting == true`. | `IOffRouteDetector`, `NavigationBloc._onLocationUpdated()` |
| NAV-04 | Reroute cooldown 2 giây — Không reroute liên tục | Vừa reroute xong 1 giây trước | Off-route detected lại | **KHÔNG trigger reroute** (cooldown chưa hết). `_lastRerouteTime` guard. | `NavigationBloc._rerouteCooldown` |
| NAV-05 | `RerouteRequested` tính route mới từ vị trí GPS hiện tại | GPS: `(10.8, 106.7)`, destination giữ nguyên | Dispatch `RerouteRequested(currentPosition)` | API `calculateRoute` gọi với origin = `(10.8, 106.7)`. State: `currentRoute` = route mới. `isRerouting == false` sau khi xong. | `NavigationBloc._onRerouteRequested()` |
| NAV-06 | `StopNavigation` dừng GPS stream + lưu trip | Đang navigate | Dispatch `StopNavigation()` | GPS stream cancel. State: `status == stopped`. Trip được lưu vào `ITripRepository`. Auto-save timer cancel. | `NavigationBloc._onStopNavigation()` |
| NAV-07 | Auto-save session snapshot mỗi 30 giây | Đang navigate | Chờ 30 giây (mock timer) | `IActiveTripService.saveSnapshot()` được gọi. | `NavigationBloc._autoSaveTimer`, `_autoSaveInterval` |
| NAV-08 | `CheckActiveSession` phát hiện session dang dở | Mock `IActiveTripService.getActiveSession()` → snapshot hợp lệ | Dispatch `CheckActiveSession()` | State: `pendingResumeSnapshot == snapshot` (để UI hiển thị dialog resume). | `NavigationBloc._onCheckActiveSession()` |
| NAV-09 | `ResumeNavigation` khôi phục trip từ snapshot | Snapshot chứa route + position + instructions | Dispatch `ResumeNavigation(snapshot)` | State: `status == navigating`, route + instructions được khôi phục. GPS stream restart. | `NavigationBloc._onResumeNavigation()` |
| NAV-10 | Generation guard cho reroute — stale reroute bị bỏ qua | 2 reroute requests liên tiếp, response 1 đến muộn | Response 1 trả về | Bị bỏ qua nhờ `_requestGeneration`. State giữ route từ response 2. | `NavigationBloc._onRerouteRequested()` |
| NAV-11 | Battery optimization dialog flow | Device chưa được whitelist | `StartNavigation` → emit prompt | State: `showBatteryOptimizationPrompt == true`. Sau `AllowBatteryOptimization` → gọi `IDeviceInfoService`. | `NavigationBloc._onAllowBatteryOptimization()` |
| NAV-12 | `ClearNavigation` reset toàn bộ state | State đang `stopped` với trip summary | Dispatch `ClearNavigation()` | State = `NavigationState()` (mặc định). Session snapshot bị xóa. | `NavigationBloc._onClearNavigation()` |

---

## Module 7: DownloadRegionCubit — Tải Bản đồ Ngoại tuyến

> **Chuẩn GG Maps**: Load danh sách regions. Download với progress stream. Cancel download. Delete region. Hiển thị storage usage.

| ID | Test Case | Setup | Action | Expected | S-Map Code |
|---|---|---|---|---|---|
| DLR-01 | `loadRegions` tải danh sách thành công | Mock `IRegionRepository.getRegions()` → 3 regions | `cubit.loadRegions()` | State: `status == loaded`, `regions.length == 3`, `totalStorageBytes > 0` | `DownloadRegionCubit.loadRegions()` |
| DLR-02 | `loadRegions` thất bại → emit error | Mock throw Exception | `cubit.loadRegions()` | State: `status == error`, `errorMessage != null` | `DownloadRegionCubit.loadRegions()` catch |
| DLR-03 | `downloadRegion` emit `downloading` + set `currentlyDownloadingRegionId` | Mock `IRegionRepository.downloadRegion()` future | `cubit.downloadRegion('north_vn')` | State: `status == downloading`, `currentlyDownloadingRegionId == 'north_vn'` | `DownloadRegionCubit.downloadRegion()` |
| DLR-04 | Progress stream cập nhật `progressMap` realtime | Stream emit `{'north_vn': 0.5}` | Progress stream fires | State: `progressMap['north_vn'] == 0.5` | `DownloadRegionCubit._initProgressSubscription()` |
| DLR-05 | Download thành công → emit `loaded` + success message | Mock download completes successfully | Download hoàn tất | State: `status == loaded`, `successMessage == DownloadRegionMessages.downloadSuccess`, regions danh sách cập nhật. | `DownloadRegionCubit.downloadRegion()` |
| DLR-06 | `cancelDownload` hủy tải + clear downloading ID | Đang download `'north_vn'` | `cubit.cancelDownload('north_vn')` | `IRegionRepository.cancelDownload('north_vn')` được gọi. State: `status == loaded`, `currentlyDownloadingRegionId == null`. | `DownloadRegionCubit.cancelDownload()` |
| DLR-07 | `deleteRegion` xóa thành công | Region `'north_vn'` đã downloaded | `cubit.deleteRegion('north_vn')` | State: `status == loaded`, `successMessage == DownloadRegionMessages.deleteSuccess`. Region bị xóa khỏi danh sách. | `DownloadRegionCubit.deleteRegion()` |
| DLR-08 | `isClosed` guard — Không emit sau khi Cubit bị dispose | Cubit bị close | Progress stream emit | **Không throw StateError**. Emit bị chặn bởi `if (isClosed) return`. | `DownloadRegionCubit.emit()` override |
| DLR-09 | NaN safety trong progress | Progress stream emit `double.nan` | Progress stream fires với NaN | App **KHÔNG crash**. Progress nên được xử lý an toàn. | `RegionCard._buildStatusBadge()` safeProgress |

---

## Module 8: FavoritesCubit — Địa điểm Yêu thích

> **Chuẩn GG Maps**: Toggle save/unsave. Danh sách favorites persist local. Optimistic UI update.

| ID | Test Case | Setup | Action | Expected | S-Map Code |
|---|---|---|---|---|---|
| FAV-01 | `loadFavorites` tải danh sách thành công | Mock `IFavoritesService.getFavorites()` → 2 POIs | Auto-load trong constructor | State: `status == success`, `favorites.length == 2`, `favoriteIds` chứa 2 keys | `FavoritesCubit.loadFavorites()` |
| FAV-02 | `toggleFavorite` thêm POI mới (chưa có) | POI `'landmark81'` chưa trong favorites | `cubit.toggleFavorite(poi)` | `addFavorite` được gọi. State: `favorites` chứa `poi`, `favoriteIds` chứa key. | `FavoritesCubit.toggleFavorite()` nhánh `!isFav` |
| FAV-03 | `toggleFavorite` gỡ POI đã có | POI `'landmark81'` đang trong favorites | `cubit.toggleFavorite(poi)` | `removeFavorite` được gọi. State: `favorites` KHÔNG chứa `poi`, `favoriteIds` KHÔNG chứa key. | `FavoritesCubit.toggleFavorite()` nhánh `isFav` |
| FAV-04 | `toggleFavorite` lỗi service → emit error | Mock `addFavorite` throw Exception | `cubit.toggleFavorite(poi)` | State: `status == error`, `errorMessage` chứa thông tin lỗi | `FavoritesCubit.toggleFavorite()` catch |
| FAV-05 | `isFavorite` check chính xác qua `favoriteIds` Set | `favoriteIds = {'key1', 'key2'}` | `state.isFavorite('key1')` → `true`. `state.isFavorite('key3')` → `false` | Trả về chính xác. O(1) lookup qua Set. | `FavoritesState.isFavorite()` |
| FAV-06 | `loadFavorites` lỗi service → emit error | Mock throw Exception | `cubit.loadFavorites()` | State: `status == error` | `FavoritesCubit.loadFavorites()` catch |

---

## Module 9: TripHistoryCubit — Lịch sử Chuyến đi

> **Chuẩn GG Maps**: Timeline — lịch sử tất cả các chuyến đi. Realtime watch stream. Delete trip.

| ID | Test Case | Setup | Action | Expected | S-Map Code |
|---|---|---|---|---|---|
| TRP-01 | `loadTrips` tải danh sách thành công | Mock `ITripRepository.getTrips()` → 5 trips | `cubit.loadTrips()` | State: `status == success`, `trips.length == 5` | `TripHistoryCubit.loadTrips()` |
| TRP-02 | `startWatching` lắng nghe realtime stream | Mock `watchTrips()` stream emit updated list | `cubit.startWatching()` → stream fires | State: `trips` cập nhật theo stream data | `TripHistoryCubit.startWatching()` |
| TRP-03 | `deleteTrip` xóa thành công và reload | Trip `'trip_123'` tồn tại | `cubit.deleteTrip('trip_123')` | `ITripRepository.deleteTrip('trip_123')` được gọi. State: `trips` không chứa `trip_123`. | `TripHistoryCubit.deleteTrip()` |
| TRP-04 | Generation guard — stale loadTrips response bị bỏ qua | 2 lần gọi `loadTrips` nhanh, response 1 đến muộn | Response 1 trả về | Bị bỏ qua nhờ `_loadGeneration` guard | `TripHistoryCubit.loadTrips()` dòng 50 |
| TRP-05 | `close()` guard — Không emit khi `_isClosing == true` | Cubit đang close | Stream emit data | **Không throw StateError**. Emit bị chặn. | `TripHistoryCubit.emit()` override |
| TRP-06 | `init()` kết hợp `loadTrips()` + `startWatching()` | Mock cả hai | `cubit.init()` | `loadTrips` gọi trước, `startWatching` gọi sau. Cả hai thành công. | `TripHistoryCubit.init()` |

---

## Module 10: SyncBloc — Đồng bộ Offline

> **Chuẩn GG Maps**: Offline-First. Queue trip khi offline. Sync khi có mạng. Watch queue count realtime.

| ID | Test Case | Setup | Action | Expected | S-Map Code |
|---|---|---|---|---|---|
| SYN-01 | `SyncStarted` đồng bộ trips pending | Mock `ISyncRepository` → 3 pending trips. Mock Firebase auth OK. | Dispatch `SyncStarted()` | State: `status == syncing` → `status == success`. `syncedCount == 3`. | `SyncBloc._onSyncStarted()` |
| SYN-02 | `SyncStarted` với queue rỗng → không gọi API | Mock `getPendingSyncCount() → 0` | Dispatch `SyncStarted()` | State: `status == idle`. API upload **KHÔNG được gọi**. | `SyncBloc._onSyncStarted()` |
| SYN-03 | `SyncTripQueued` thêm trip vào queue | Trip `'trip_456'` cần sync | Dispatch `SyncTripQueued('trip_456')` | `ISyncRepository.enqueueTripForSync('trip_456')` được gọi. | `SyncBloc._onSyncTripQueued()` |
| SYN-04 | Queue count watcher cập nhật realtime | Stream emit count `5` → `3` → `0` | Stream fires | State: `pendingCount` cập nhật tương ứng: `5 → 3 → 0`. | `SyncBloc._initQueueWatcher()` |
| SYN-05 | Sync lỗi mạng → emit error, giữ nguyên queue | Mock upload throw network exception | Dispatch `SyncStarted()` | State: `status == error`. Queue KHÔNG bị xóa (retry later). | `SyncBloc._onSyncStarted()` catch |
| SYN-06 | `SyncReset` reset state về idle | State đang error | Dispatch `SyncReset()` | State: `status == idle`, `pendingCount == 0` | `SyncBloc._onSyncReset()` |
| SYN-07 | `droppable` transformer — 2 SyncStarted song song, cái sau bị drop | SyncStarted đang chạy | Dispatch SyncStarted lần 2 | Lần 2 bị **drop** nhờ `droppable()` transformer. Chỉ 1 sync chạy tại 1 thời điểm. | `SyncBloc` constructor `transformer: droppable()` |

---

## Module 11: AuthCubit — Xác thực & Onboarding

> **Chuẩn GG Maps**: First launch → Onboarding. Complete onboarding → guest mode. Google Sign In.

| ID | Test Case | Setup | Action | Expected | S-Map Code |
|---|---|---|---|---|---|
| AUT-01 | Lần đầu mở app → emit `onboarding` | Mock `getOnboardingCompleted() → false` | `cubit.onAppStarted()` | State: `stateType == onboarding` | `AuthCubit.onAppStarted()` |
| AUT-02 | Đã hoàn thành onboarding → emit `unAuthenticated` | Mock `getOnboardingCompleted() → true` | `cubit.onAppStarted()` | State: `stateType == unAuthenticated` | `AuthCubit.onAppStarted()` |
| AUT-03 | `completeOnboarding` lưu flag + chuyển authenticated guest | | `cubit.completeOnboarding()` | `saveOnboardingCompleted(true)` được gọi. State: `stateType == authenticated`. | `AuthCubit.completeOnboarding()` |
| AUT-04 | `signInWithGoogle` thành công | Mock Firebase OK | `cubit.signInWithGoogle()` | State: `stateType == loading` → `stateType == authenticated`, `user != null` | `AuthCubit.signInWithGoogle()` |
| AUT-05 | `signInWithGoogle` user hủy (null) → return false | Mock Google Sign In → null | `cubit.signInWithGoogle()` | Return `false`. State: **không thay đổi** (giữ nguyên trạng thái trước). | `AuthCubit.signInWithGoogle()` |
| AUT-06 | `signInWithGoogle` exception → graceful error | Mock throw Exception | `cubit.signInWithGoogle()` | State: `stateType == unAuthenticated`. Error được log, app không crash. | `AuthCubit.signInWithGoogle()` catch |
| AUT-07 | `isClosed` guard sau mỗi `await` | Cubit bị close giữa chừng `onAppStarted()` | `await` xong, cubit đã closed | **Không emit**. Guard `if (isClosed) return` chặn an toàn. | `AuthCubit.onAppStarted()` isClosed guards |
| AUT-08 | `getOnboardingCompleted` throw → fallback onboarding | Mock throw Exception | `cubit.onAppStarted()` | State: `stateType == onboarding` (an toàn, không crash) | `AuthCubit.onAppStarted()` catch |
| AUT-09 | `completeOnboarding` vẫn hoạt động khi save throw | Mock `saveOnboardingCompleted` throw | `cubit.completeOnboarding()` | State: `stateType == authenticated` (vẫn chuyển trạng thái, log error) | `AuthCubit.completeOnboarding()` catch |

---

## Module 12: RouteDrawingBloc — Vẽ Lộ trình Tùy chỉnh

> **Tính năng riêng S-Map** (Google Maps không có trực tiếp). Test logic vẽ route segment, undo/redo, save/load.

| ID | Test Case | Setup | Action | Expected | S-Map Code |
|---|---|---|---|---|---|
| RDR-01 | Tap điểm đầu tiên → chỉ lưu waypoint, chưa tính route | Bloc trống | Dispatch `RouteDrawingPointTapped(point1)` | State: `waypoints == [point1]`, `segments == []` (chưa có đủ 2 điểm) | `RouteDrawingBloc._onPointTapped()` |
| RDR-02 | Tap điểm thứ 2 → tính route segment | Waypoint 1 đã có | Dispatch `RouteDrawingPointTapped(point2)` | API `calculateRoute(point1 → point2)` được gọi. State: `segments.length == 1`, `fullPolyline.isNotEmpty` | `RouteDrawingBloc._onPointTapped()` |
| RDR-03 | Undo → xóa segment cuối | 3 waypoints, 2 segments | Dispatch `RouteDrawingUndoLastPoint()` | State: `waypoints.length == 2`, `segments.length == 1`. Waypoint 3 vào `_redoStack`. | `RouteDrawingBloc._onUndoLastPoint()` |
| RDR-04 | Redo → khôi phục segment đã undo | Undo vừa xong | Dispatch `RouteDrawingRedoPoint()` | State: `waypoints.length == 3`, `segments.length == 2`. Route tính lại. | `RouteDrawingBloc._onRedoPoint()` |
| RDR-05 | `ClearRoute` reset toàn bộ | Đang có route | Dispatch `RouteDrawingClearRoute()` | State = `RouteDrawingState()` (mặc định) | `RouteDrawingBloc._onClearRoute()` |
| RDR-06 | `SaveRoute` lưu vào local storage | Route hợp lệ, tên "Đường đi chợ" | Dispatch `RouteDrawingSaveRoute(name: 'Đường đi chợ')` | `ICustomRouteRepository.saveRoute()` được gọi. State: `saveStatus == success`. | `RouteDrawingBloc._onSaveRoute()` |
| RDR-07 | `LoadRoute` khôi phục route đã lưu | Route "Đường đi chợ" trong storage | Dispatch `RouteDrawingLoadRoute(routeId)` | State: `waypoints`, `segments`, `fullPolyline` khôi phục từ saved data. | `RouteDrawingBloc._onLoadRoute()` |
| RDR-08 | `_buildFullPolyline` loại bỏ trùng lặp tại điểm giao nhau | 2 segments: `[A, B, C]` và `[C, D, E]` | `_buildFullPolyline([seg1, seg2])` | Result: `[A, B, C, D, E]` (C không bị lặp) | `RouteDrawingBloc._buildFullPolyline()` |
| RDR-09 | Generation guard cho route tính toán | 2 `PointTapped` liên tiếp, response 1 đến muộn | Response 1 trả về | Bị bỏ qua nhờ `_currentGeneration`. | `RouteDrawingBloc._onPointTapped()` |

---

## Cross-Cutting: Tương tác giữa các Module

> **Chuẩn GG Maps**: Navigation KHÔNG BAO GIỜ bị gián đoạn. Search trong Navigation = "Search Along Route". Route Preview bị hủy khi Search mới.

| ID | Test Case | Mô tả | Expected Behavior |
|---|---|---|---|
| CC-01 | Search trong khi Navigation đang chạy | User mở Search overlay khi đang dẫn đường | NavigationBloc **KHÔNG bị ảnh hưởng**. GPS tracking + voice guidance tiếp tục. Search kết quả nên được lọc theo route (nếu có tính năng Search Along Route). |
| CC-02 | Route Preview bị hủy khi bắt đầu Search mới | User tap Search khi đang Route Preview | `RoutePreviewCubit.clearRoute()` phải được gọi. Polyline bị xóa khỏi bản đồ. |
| CC-03 | Offline Download không ảnh hưởng Navigation | Download đang chạy, user bắt đầu Navigation | Navigation hoạt động bình thường. Download tiếp tục chạy ngầm. |
| CC-04 | `selectPoi` tắt follow user nhưng Navigation GPS vẫn chạy | Đang Navigation, user tap POI marker | `MapDisplayCubit.isFollowingUser == false`. Nhưng `NavigationBloc` vẫn tracking GPS. Nút Re-center xuất hiện. |
| CC-05 | `StopNavigation` lưu trip → `TripHistoryCubit` phản ánh | User dừng Navigation | Trip được lưu vào `ITripRepository`. `TripHistoryCubit` (nếu đang watch) nhận được trip mới qua stream. |
| CC-06 | App killed → Resume Navigation | App bị kill giữa Navigation | `CheckActiveSession` phát hiện snapshot. `ResumeNavigation` khôi phục toàn bộ state. |

---

## Integration Tests: MethodChannel Native Bridge

> **Chuẩn GG Maps**: Routing < 500ms. Offline routing hoạt động khi không có mạng.

| ID | Test Case | Mô tả | Expected |
|---|---|---|---|
| INT-01 | **Performance**: Routing response < 500ms | Tính route 10km trong thành phố | Response time < 500ms consistently | 
| INT-02 | **MethodChannel**: `calculateRoute` trả về `RouteResult` hợp lệ | Gọi native routing engine qua MethodChannel | `RouteResult.isSuccess == true`, `points.isNotEmpty`, `distance > 0`, `time > 0` |
| INT-03 | **MethodChannel**: `calculateRoute` handle native exception | Native engine throw platform exception | Flutter nhận `PlatformException`, `RouteResult.isSuccess == false` |
| INT-04 | **Offline Routing**: Tính route khi mất mạng (có offline data) | Tắt network, vùng có offline map | Route vẫn tính được. `RouteResult.isSuccess == true`. |
| INT-05 | **Region Download**: Native download engine callback progress | Gọi native download, listen progress stream | Progress stream emit giá trị `0.0 → 1.0` incrementally. Không emit `NaN` hoặc `Infinity`. |
| INT-06 | **Stress Test**: 10 concurrent routing requests | Gọi `calculateRoute` 10 lần song song | Tất cả trả về kết quả hợp lệ (hoặc graceful error). Không crash, không deadlock. |

---

## Tổng kết số lượng Test Cases

| Module | Số Test Cases |
|---|:---:|
| MapDisplayCubit | 13 |
| SearchCubit | 13 |
| ViewportSearchBloc | 6 |
| RoutePreviewCubit | 8 |
| RouteProfileCubit | 2 |
| NavigationBloc | 12 |
| DownloadRegionCubit | 9 |
| FavoritesCubit | 6 |
| TripHistoryCubit | 6 |
| SyncBloc | 7 |
| AuthCubit | 9 |
| RouteDrawingBloc | 9 |
| Cross-Cutting | 6 |
| Integration Tests | 6 |
| **Tổng cộng** | **112** |
