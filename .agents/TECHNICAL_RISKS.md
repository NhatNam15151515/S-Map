# S-MAP: DANH MỤC RỦI RO KỸ THUẬT & HƯỚNG DẪN PHÒNG TRÁNH TOÀN DIỆN
> **Dành cho:** Kỹ sư phát triển hệ thống S-Map (Flutter, Offline-First GIS, GraphHopper Routing, SQLite FTS5, MapLibre Native & Firebase)  
> **Mục tiêu:** Nhận diện, phòng ngừa và xử lý triệt để toàn bộ rủi ro kỹ thuật từ tầng Native Engine, Thuật toán Định tuyến, Xử lý Không gian đến Kiến trúc Ứng dụng và Build Release.

---

## MỤC LỤC
1. [Bản Đồ & Native GIS Engine (MapLibre GL & Vector Tiles)](#1-bản-đồ--native-gis-engine-maplibre-gl--vector-tiles)
2. [Thuật Toán Định Tuyến & Native GraphHopper Engine](#2-thuật-toán-định-tuyến--native-graphhopper-engine)
3. [Định Vị (Location), Cảm Biến La Bàn & Quản Lý Pin](#3-định-vị-location-cảm-biến-la-bàn--quản-lý-pin)
4. [Cơ Sở Dữ Liệu Cục Bộ (SQLite FTS5, Spatial Index & Caching)](#4-cơ-sở-dữ-liệu-cục-bộ-sqlite-fts5-spatial-index--caching)
5. [Kiến Trúc Flutter, BLoC State Management & Concurrency](#5-kiến-trúc-flutter-bloc-state-management--concurrency)
6. [Data Pipeline, Đóng Gói Vùng & Cập Nhật Dữ Liệu (Data Lifecycle)](#6-data-pipeline-đóng-gói-vùng--cập-nhật-dữ-liệu-data-lifecycle)
7. [Native Android/iOS Build, R8/ProGuard & Release Hazards](#7-native-androidios-build-r8proguard--release-hazards)
8. [Backend Firebase, Đồng Bộ & Xử Lý Ngoại Lệ Mạng](#8-backend-firebase-đồng-bộ--xử-lý-ngoại-lệ-mạng)
9. [Bảo Mật Ứng Dụng & Toàn Vẹn Dữ Liệu Cục Bộ](#9-bảo-mật-ứng-dụng--toàn-vẹn-dữ-liệu-cục-bộ)
10. [Quy Chuẩn Kiểm Thử & Đo Lường Hiệu Năng (Testing Standards)](#10-quy-chuẩn-kiểm-thử--đo-lường-hiệu-năng-testing-standards)

---

## 1. BẢN ĐỒ & NATIVE GIS ENGINE (MAPLIBRE GL & VECTOR TILES)

### 1.1. Tràn Bộ Nhớ Native GPU/Texture do Add Hàng Nghìn Marker/Symbol Riêng Lẻ
* **Hiện tượng:** Ứng dụng giật lag (frame drop dưới 15 FPS) khi zoom/pan bản đồ có nhiều POI, hoặc crash đột ngột với mã lỗi `OOM` / `OpenGL Out of Memory` trên Android/iOS.
* **Nguyên nhân gốc rễ:** Dùng vòng lặp gọi `mapController.addSymbol()` cho từng điểm POI. Mỗi Symbol tạo ra một đối tượng Native riêng trên bộ nhớ C++, làm nghẽn Native Bridge và vượt quá giới hạn Texture GPU.
* **Hậu quả:** Trải nghiệm người dùng cực kỳ gián đoạn, hao pin nhanh, crash app trên máy tầm trung và yếu.
* **Giải pháp phòng tránh:**
  1. Gom toàn bộ POIs thành một **GeoJSON FeatureCollection** duy nhất.
  2. Nạp dữ liệu qua `GeoJsonSource` và hiển thị bằng `SymbolLayer` / `CircleLayer` của MapLibre.
  3. Bật tính năng **Clustering** ở cấp độ Source (`cluster: true`, `clusterMaxZoom`, `clusterRadius`) để gom cụm tự động trên GPU.
  4. Sử dụng Sprite Sheet duy nhất cho tất cả các icon thay vì nạp ảnh động rời rạc.

### 1.2. Race Condition khi Gọi Map Controller Trước khi Style Bản Đồ Sẵn Sàng
* **Hiện tượng:** Gặp lỗi `PlatformException: Map not initialized` hoặc `Cannot add layer to null style`, dẫn đến việc đường đi (Polyline) hoặc Marker không hiển thị dù API đã trả về kết quả.
* **Nguyên nhân:** Khởi tạo thao tác vẽ (vẽ route, add marker, animate camera) ngay khi `onMapCreated` vừa chạy, trong khi file `style.json` hoặc Vector Tile source chưa được nạp và parse xong trên Native.
* **Giải pháp:**
  - Chỉ thực hiện các thao tác thêm Layer/Source/Symbol bên trong callback `onStyleLoadedCallback` (hoặc đợi `Completer<void>` kích hoạt sau khi style đã load).
  - Tách riêng `MapCameraController`, `MapSymbolManager`, `MapRouteManager` và chỉ truyền controller vào sau khi style sẵn sàng.

### 1.3. Rò Rỉ Bộ Nhớ (Memory Leak) Do Không Hủy Controller & Stream Lắng Nghe
* **Hiện tượng:** Bộ nhớ RAM tăng liên tục mỗi lần người dùng chuyển màn hình (từ Home -> Search -> Detail -> Home), sau 5-10 phút app bị hệ điều hành tắt ngấm.
* **Nguyên nhân:** Không hủy đăng ký các listener của `MapLibreMapController`, các StreamSubscription (`onCameraMove`, `onFeatureClick`) trong hàm `dispose()` của Widget/Stateful class.
* **Giải pháp:**
  - Luôn hủy toàn bộ `StreamSubscription` trong `dispose()`.
  - Gọi `controller.dispose()` nếu controller tự quản lý.
  - Tuân thủ quy tắc: **Không lưu UI Controller bên trong Cubit/BLoC** để tránh giữ tham chiếu vòng đời UI ngoài ý muốn.

### 1.4. Đọc Lỗi File Định Dạng PMTiles / MBTiles Khi Chạy Đa Luồng
* **Hiện tượng:** Khi tải hoặc đọc bản đồ offline, xuất hiện lỗi `Invalid PMTiles header` hoặc `Corrupted archive`.
* **Nguyên nhân:** Ứng dụng đọc file nén/archive vector tiles trong lúc file đang được stream/ghi dở dang, hoặc nhiều isolate cùng mở khóa ghi đè cùng 1 file.
* **Giải pháp:**
  - Sử dụng cơ chế ghi nguyên tử (Atomic Write): Tải vào file tạm `.tmp`, xác thực SHA-256 / Header bytes, sau đó đổi tên (rename) sang file chính thức `.pmtiles`.

---

## 2. THUẬT TOÁN ĐỊNH TUYẾN & NATIVE GRAPHHOPPER ENGINE

### 2.1. Nghẽn UI Thread (Jank & Freeze) do Tính Toán và Parse Dữ Liệu Lớn Trên Main Isolate
* **Hiện tượng:** Màn hình bị đơ cứng (1-3 giây) khi người dùng bấm "Tìm đường" hoặc khi bắt đầu tính toán lộ trình dài.
* **Nguyên nhân:**
  1. Serialization / Deserialization mảng tọa độ Polyline lớn (hàng nghìn điểm lat/lon, turn instructions) chạy trực tiếp trên Root Isolate của Flutter.
  2. Tính toán khoảng cách hoặc giải mã Bounding Box trên Main Thread.
* **Giải pháp:**
  - Mọi logic giải mã Polyline, chuẩn hóa tọa độ và tính toán Haversine phải được đẩy sang **Background Isolate** bằng `compute()` hoặc `Isolate.run()`.
  - Giới hạn độ dài chuỗi trả về từ Native C++/Java qua MethodChannel (chỉ gửi danh sách tọa độ nén Polyline 6 thay vì mảng đối tượng JSON cồng kềnh).

### 2.2. Tràn Bộ Nhớ RAM (OOM Crash) Khi Khởi Tạo GraphHopper Trên Thiết Bị Di Động
* **Hiện tượng:** Native crash (`SIGSEGV` hoặc `java.lang.OutOfMemoryError`) ngay lúc gọi `initGraphHopper()`, đặc biệt với các file đồ thị lớn (> 100MB).
* **Nguyên nhân:** Mặc định GraphHopper nạp toàn bộ Node, Edge và Shortcut CH (Contraction Hierarchies) vào heap RAM (`RAM_STORE`). Trên mobile, giới hạn heap của một ứng dụng thường chỉ từ 192MB - 512MB.
* **Giải pháp:**
  - Cấu hình GraphHopper Data Access sang chế độ **Memory-Mapped Files** (`DAT_MMAP` / `MMAP_STORE`).
  - Chia nhỏ đồ thị theo từng vùng địa lý (Vùng TP.HCM, Vùng Hà Nội, Miền Nam, Miền Bắc) thay vì nạp đồ thị toàn quốc một lần.
  - Giải phóng bộ nhớ (`disposeGraphHopper`) của vùng cũ trước khi nạp vùng mới khi người dùng di chuyển sang địa phận khác.

### 2.3. Bão Tính Toán Lại Lộ Trình (Re-routing Storm) Do Nhiễu GPS
* **Hiện tượng:** Khi đang dẫn đường, ứng dụng liên tục báo "Đang tính lại lộ trình" mỗi 1-2 giây làm giật lag và hao pin nghiêm trọng.
* **Nguyên nhân:** Thuật toán phát hiện lệch đường (Off-route Detection) quá nhạy, chỉ dựa vào 1 tọa độ GPS đơn lẻ mà không có bộ lọc nhiễu. Khi người dùng đi gần các tòa nhà cao tầng, GPS bị nhảy điểm (drift).
* **Giải pháp:**
  - Sử dụng thuật toán **Off-Route Debounce & Consecutiveness**: Chỉ kích hoạt Re-routing khi có ít nhất **3 điểm GPS liên tiếp** nằm ngoài hành lang lộ trình cho phép (ví dụ: khoảng cách > 25 mét tính từ đoạn Polyline gần nhất).
  - Áp dụng kỹ thuật **Map Matching / Snap-to-Edge** trước khi kiểm tra khoảng cách lệch.

### 2.4. Mất Đồng Bộ Logic giữa Cấu Hình Data Pipeline và Mobile Engine
* **Hiện tượng:** Lộ trình tính trên Mobile đi vào đường cấm xe máy, đi ngược chiều hoặc không thể tìm thấy đường dù trên bản đồ có đường.
* **Nguyên nhân:** File `custom_model_moped.json` trong Python data-pipeline dùng cờ (flag) mã hóa khác với phiên bản GraphHopper Java/Native nhúng trong Flutter app (ví dụ: khác biệt cờ `access`, `speed`, `turn_costs`).
* **Giải pháp:**
  - Đồng bộ hóa chặt chẽ schema cấu hình và bộ `FlagEncoder` giữa Pipeline và Mobile Engine.
  - Bắt buộc kiểm thử hồi quy bằng bộ test case tọa độ thực tế (`route_test_cases.md`) trước khi đóng gói dữ liệu.

---

## 3. ĐỊNH VỊ (LOCATION), CẢM BIẾN LA BÀN & QUẢN LÝ PIN

### 3.1. Nhiễu Tọa Độ GPS (Jitter, Multi-path Interference) Trong Nhà & Đô Thị
* **Hiện tượng:** Marker vị trí người dùng nhảy giật liên tục qua lại giữa các làn đường, nhảy xuyên qua tòa nhà khi người dùng đang đứng yên hoặc đi bộ chậm.
* **Nguyên nhân:** Hiện tượng phản xạ sóng vệ tinh từ các tòa nhà cao tầng (Urban Canyon) và độ chính xác thấp của chip GPS rẻ tiền.
* **Giải pháp:**
  - Cài đặt bộ lọc **Kalman Filter (1D/2D)** để làm mượt chuỗi tọa độ (Smooth Position Stream).
  - Bỏ qua các điểm GPS có độ chính xác quá thấp (`accuracy > 30m`).
  - Khi vận tốc di chuyển `< 0.5 m/s` (đang đứng yên), khóa cứng vị trí và không gửi event cập nhật camera để tránh xoay lắc màn hình.

### 3.2. Dao Động La Bàn Số Tần Số Cao (Compass Bearing Oscillation)
* **Hiện tượng:** Mũi tên chỉ hướng hoặc góc xoay bản đồ quay vòng giật cục liên tục, gây chóng mặt và trải nghiệm thị giác rất xấu.
* **Nguyên nhân:** Cảm biến từ trường (`flutter_compass`) nhạy cảm với nhiễu kim loại xung quanh và bắn sự kiện với tần số quá cao (60-100Hz).
* **Giải pháp:**
  - Áp dụng **Low-pass Filter (Exponential Moving Average)** hoặc **Circular Mean Smoothing** cho góc quay:
    $$\theta_{smooth} = \theta_{prev} + \alpha \cdot \Delta(\theta_{new}, \theta_{prev})$$
  - Throttling luồng la bàn ở mức tối đa 20 - 30 FPS (`rxdart.throttleTime(const Duration(milliseconds: 33))`).
  - Chỉ xoay bản đồ khi độ lệch góc lớn hơn ngưỡng dung sai (ví dụ: $|\Delta \theta| > 2^\circ$).

### 3.3. Cạn Kiệt Pin & Nóng Máy Khi Chạy Dẫn Đường Thời Gian Dài
* **Hiện tượng:** Máy nóng rực, pin tụt 1% mỗi 1-2 phút trong chuyến đi dài 30 phút.
* **Nguyên nhân:** Giữ liên tục màn hình sáng, GPS ở chế độ `LocationAccuracy.bestForNavigation`, chạy render 60 FPS liên tục và không điều chỉnh tần suất cập nhật theo vận tốc.
* **Giải pháp:**
  - Điều chỉnh `distanceFilter` động: Khi xe chạy nhanh (> 40km/h), tăng khoảng cách lọc lên 10-15m; khi đi chậm, hạ xuống 3-5m.
  - Tắt các hiệu ứng hoạt họa (animations) không cần thiết trong chế độ Navigation.

### 3.4. Ứng Dụng Bị Hệ Điều Hành Tắt Khi Chạy Ẩn (Background Termination)
* **Hiện tượng:** Ứng dụng đang phát âm thanh dẫn đường thì bị tắt đột ngột khi người dùng khóa màn hình hoặc chuyển sang ứng dụng khác.
* **Nguyên nhân:** Thiếu cấu hình `Foreground Service` (Android 14+) hoặc thiếu cấp quyền `UIBackgroundModes: location` (iOS).
* **Giải pháp:**
  - Kèm thông báo thường trực (Sticky Foreground Notification) khi ở chế độ Dẫn đường nền trên Android.
  - Khai báo chính xác Foreground Service Type: `android:foregroundServiceType="location"`.

---

## 4. CƠ SỞ DỮ LIỆU CỤC BỘ (SQLITE FTS5, SPATIAL INDEX & CACHING)

### 4.1. Khóa Cơ Sở Dữ Liệu (Database Lock Contention) Do Truy Cập Đa Luồng
* **Hiện tượng:** Lỗi `SqliteException(5): database is locked` hoặc `busy` xuất hiện khi vừa tìm kiếm POI vừa cập nhật lịch sử / yêu thích.
* **Nguyên nhân:** Nhiều kết nối (Connections) cố gắng mở ghi đồng thời trên cùng một file SQLite trên các isolate khác nhau.
* **Giải pháp:**
  - Bật chế độ **WAL (Write-Ahead Logging)** cho SQLite: `PRAGMA journal_mode = WAL;`.
  - Quản lý truy cập thông qua một **Singleton Database Service** duy nhất, kiểm soát hàng đợi ghi tuần tự.
  - Đặt timeout phù hợp (`PRAGMA busy_timeout = 5000;`).

### 4.2. Lỗi Tìm Kiếm Tiếng Việt Trên SQLite FTS5 (Diacritics / Accent Folding)
* **Hiện tượng:** Người dùng gõ "nguyen van cu" không tìm thấy "Nguyễn Văn Cừ", hoặc gõ "đ" không ra "d".
* **Nguyên nhân:** FTS5 mặc định của SQLite sử dụng bộ phân tích từ khóa chuẩn ASCII (tokenizer `simple` hoặc `porter`), không hiểu dấu thanh và ký tự đặc thù Tiếng Việt (đ, Đ, â, ă, ê, ô, ơ, ư).
* **Giải pháp:**
  - Chuẩn hóa dữ liệu ngay trong Data Pipeline: Tạo thêm một cột `search_normalized` đã được loại bỏ dấu, chuyển về chữ thường và chuẩn hóa ký tự `đ -> d`.
  - Khi người dùng nhập từ khóa tìm kiếm, chuẩn hóa chuỗi input tương tự trước khi thực hiện truy vấn `MATCH`.

### 4.3. Quét Toàn Bộ Bảng (Full Table Scan) Khi Truy Vấn Bán Kính POI
* **Hiện tượng:** Truy vấn các địa điểm gần người dùng (Nearby POIs) mất từ 500ms đến 2 giây khi cơ sở dữ liệu có từ 50.000 địa điểm trở lên.
* **Nguyên nhân:** Dùng công thức lượng giác Haversine trực tiếp trong mệnh đề `WHERE` của SQL mà không có Spatial Index hoặc Bounding Box.
* **Giải pháp:**
  - Tạo chỉ mục kết hợp `CREATE INDEX idx_poi_coords ON pois(lat, lon);` hoặc sử dụng bảng ảo `R-Tree` của SQLite.
  - Luôn lọc sơ bộ bằng **Bounding Box vuông** trước:
    ```sql
    WHERE lat BETWEEN (user_lat - delta_lat) AND (user_lat + delta_lat)
      AND lon BETWEEN (user_lon - delta_lon) AND (user_lon + delta_lon)
    ```
  - Sau đó mới tính khoảng cách chính xác trên tập kết quả đã thu hẹp (Top 50-100 điểm).

### 4.4. Phình Bộ Nhớ RAM Do Lưu Cấu Trúc Lớn Trong Hive / SharedPreferences
* **Hiện tượng:** Mở app chậm (Cold start delay > 3 giây) do Hive nạp toàn bộ Box vào RAM lúc khởi động.
* **Nguyên nhân:** Dùng Hive để lưu danh sách địa điểm offline lớn thay vì chỉ lưu cài đặt và token.
* **Giải pháp:**
  - Phân định rõ ràng:
    - **SharedPreferences / FlutterSecureStorage**: Chỉ lưu Key-Value nhỏ, Tokens, User Preferences.
    - **Hive**: Lưu cache phiên ngắn hạn, state nhỏ.
    - **SQLite**: Bắt buộc dùng cho toàn bộ dữ liệu quan hệ, POI, lịch sử tìm kiếm và thống kê.

---

## 5. KIẾN TRÚC FLUTTER, BLOC STATE MANAGEMENT & CONCURRENCY

### 5.1. Vi Phạm Tính Thuần Khiết Của BLoC (BLoC Purity & Controller Pollution)
* **Hiện tượng:** Không thể viết Unit Test cho Cubit, crash do truy cập controller đã bị hủy, giao diện không đồng bộ khi xoay màn hình hoặc tái sử dụng state.
* **Nguyên nhân:** Lưu trữ trực tiếp các đối tượng UI Controller (`MapLibreMapController`, `ScrollController`, `TextEditingController`, `AnimationController`, `BuildContext`) bên trong Cubit/BLoC.
* **Giải pháp Bắt Buộc:**
  - **Cubit/BLoC chỉ chứa State và Logic thuần túy.**
  - Mọi Controller phải được khởi tạo và hủy bên trong State của Widget UI.
  - Widget tương tác với Cubit bằng cách gửi Event/gọi Method, và lắng nghe phản hồi qua `BlocListener` / `BlocConsumer` để điều khiển Controller tương ứng.

### 5.2. Quản Lý Trạng Thái Kép (Dual State Management Anti-Pattern)
* **Hiện tượng:** UI bị giật, hiển thị hai trạng thái mâu thuẫn cùng lúc (ví dụ: Icon báo đang tải nhưng danh sách bên dưới đã xong).
* **Nguyên nhân:** Dùng song song `ValueNotifier` / `ChangeNotifier` / `setState` nội bộ để quản lý cùng một biến trạng thái mà Cubit đang quản lý.
* **Giải pháp:**
  - Tuân thủ nguyên tắc **Single Source of Truth (SSOT)**: Mọi trạng thái cốt lõi của màn hình phải xuất phát từ Cubit State.
  - Loại bỏ hoàn toàn `setState` và `ValueNotifier` trùng lặp trong các màn hình tính năng lớn.

### 5.3. Định Nghĩa Future & Xử Lý Async Tùy Tiện Trong Widget UI
* **Hiện tượng:** Dữ liệu bị fetch lặp đi lặp lại mỗi khi Widget rebuild, xuất hiện lỗi `setState() called after dispose()`.
* **Nguyên nhân:** Viết hàm `async/await`, gọi API, truy vấn database trực tiếp trong `build()` hoặc `initState()` của Widget mà không qua Cubit.
* **Giải pháp:**
  - UI là hàm thuần túy của State ($UI = f(State)$).
  - Mọi tác vụ bất đồng bộ phải nằm trong Repository/Service và được kích hoạt qua Cubit.

### 5.4. Hardcode Chuỗi Text và Bỏ Qua Sinh Mã (Codegen) i18n
* **Hiện tượng:** Ứng dụng bị lỗi hiển thị khi chuyển đổi ngôn ngữ Anh - Việt, phát sinh crash do key dịch không tồn tại khi deploy production.
* **Nguyên nhân:** Viết chuỗi thô (`Text("Tìm kiếm")`) hoặc gõ tay key dịch (`tr("search_title")`) thay vì dùng hằng số định kiểu.
* **Giải pháp:**
  - Bắt buộc dùng `tr(LocaleKeys.xxx)` với các key được sinh tự động từ `easy_localization:generate`.
  - Cấm đặt key trùng tên giữa chuỗi nguyên thủy và Object lồng nhau trong file `vi.json` / `en.json`.

---

## 6. DATA PIPELINE, ĐÓNG GÓI VÙNG & CẬP NHẬT DỮ LIỆU (DATA LIFECYCLE)

### 6.1. Lỗ Hổng Bảo Mật Zip Slip Khi Giải Nén Gói Bản Đồ Vùng
* **Hiện tượng:** Ứng dụng bị từ chối duyệt trên App Store / Google Play hoặc bị tấn công ghi đè file hệ thống độc hại.
* **Nguyên nhân:** Khi giải nén file `.zip` (ví dụ: `metro_hcm.zip`), không kiểm tra đường dẫn đích của từng file entry bên trong (chứa ký tự nguy hiểm `../..`).
* **Giải pháp:**
  - Bắt buộc kiểm tra đường dẫn an toàn trước khi trích xuất:
    ```dart
    final destinationPath = path.normalize(path.join(targetDir, entry.name));
    if (!destinationPath.startsWith(targetDir)) {
      throw SecurityException('Phát hiện Zip Slip traversal trong file!');
    }
    ```

### 6.2. Hỏng Dữ Liệu Do Cập Nhật Không Nguyên Tử (Non-Atomic Updates)
* **Hiện tượng:** Người dùng tắt app hoặc mất nguồn đúng lúc đang tải/giải nén gói bản đồ offline; lần mở app sau bị crash liên tục không thể khởi động lại.
* **Nguyên nhân:** File `.ghz` hoặc `.db` bị ghi đè trực tiếp khi chưa hoàn tất 100%.
* **Giải pháp:**
  - Áp dụng quy trình **Staging & Swap**:
    1. Giải nén toàn bộ vào thư mục tạm `staging/<region_id>/`.
    2. Kiểm tra tính toàn vẹn (file tồn tại, dung lượng > 0, mở thử SQLite connection thành công).
    3. Thực hiện hoán đổi thư mục nguyên tử (Atomic Directory Rename) sang thư mục hoạt động `active/<region_id>/`.
    4. Xóa thư mục phiên bản cũ.

### 6.3. Rác Bộ Nhớ Tạm Làm Đầy Bộ Nhớ Thiết Bị
* **Hiện tượng:** Bộ nhớ app phình to từ vài trăm MB lên nhiều GB sau vài lần cập nhật vùng bản đồ.
* **Nguyên nhân:** File nén `.zip` tải về và các file tạm sau khi giải nén không được dọn dẹp.
* **Giải pháp:**
  - Xóa ngay file `.zip` gốc sau khi giải nén thành công.
  - Có hàm quét và dọn dẹp thư mục tạm (`temp/`) mỗi khi app khởi động.

---

## 7. NATIVE ANDROID/IOS BUILD, R8/PROGUARD & RELEASE HAZARDS

### 7.1. R8 / ProGuard Cắt Bỏ (Stripping) Hàm JNI Khi Build Release APK
* **Hiện tượng:** Bản Debug chạy hoàn hảo, nhưng bản Release (`flutter build apk --release` / `appbundle`) bị crash ngay lập tức khi gọi tính năng tìm đường GraphHopper.
* **Nguyên nhân:** Trình tối ưu hóa R8 nhầm tưởng các class Java/Kotlin của GraphHopper được gọi qua JNI C++ hoặc Reflection là mã nguồn thừa và tự động xóa bỏ.
* **Giải pháp:**
  - Bổ sung quy tắc bảo vệ vào `android/app/proguard-rules.pro`:
    ```proguard
    # Giữ nguyên toàn bộ Native Bridge & Model của GraphHopper
    -keep class com.graphhopper.** { *; }
    -keepclassmembers class com.graphhopper.** { *; }
    -keep class com.smap.routing.** { *; }
    -keepclassmembers class com.smap.routing.** { *; }
    -dontwarn com.graphhopper.**
    ```

### 7.2. Thiếu Thư Viện Native Cho Từng Kiến Trúc CPU (ABI Incompatibility)
* **Hiện tượng:** App crash trên một số dòng máy đời cũ hoặc máy tính bảng (`UnsatisfiedLinkError: dlopen failed: library "libmaplibre.so" not found`).
* **Nguyên nhân:** Cấu hình ABI Split thiếu các kiến trúc phổ biến hoặc thư viện C++ build thiếu target.
* **Giải pháp:**
  - Đảm bảo hỗ trợ đầy đủ các kiến trúc chính trong `android/app/build.gradle`:
    ```groovy
    ndk {
        abiFilters "armeabi-v7a", "arm64-v8a", "x86_64"
    }
    ```

### 7.3. Từ Chối Duyệt Ứng Dụng (App Store / Google Play Rejection) Do Quyền Vị Trí
* **Hiện tượng:** Apple hoặc Google từ chối phát hành app với lý do: *"Ứng dụng yêu cầu quyền vị trí nền nhưng không giải thích rõ ràng mục đích cho người dùng"*.
* **Nguyên nhân:** Chuỗi mô tả quyền trong `Info.plist` (`NSLocationAlwaysAndWhenInUseUsageDescription`) và `AndroidManifest.xml` quá chung chung hoặc thiếu video minh họa tính năng Navigation nền.
* **Giải pháp:**
  - Viết mô tả chi tiết, tường minh: *"S-Map cần quyền vị trí để cung cấp chỉ dẫn đường bằng giọng nói liên tục ngay cả khi màn hình tắt hoặc khi bạn đang sử dụng ứng dụng khác."*
  - Chỉ yêu cầu quyền Vị trí nền (Background Location) khi người dùng thực sự nhấn "Bắt đầu dẫn đường", không yêu cầu ngay từ màn hình Splash/Đăng nhập.

---

## 8. BACKEND FIREBASE, ĐỒNG BỘ & XỬ LÝ NGOẠI LỆ MẠNG

### 8.1. Xung Đột Dữ Liệu Offline Firestore (Cache Mutation Conflicts)
* **Hiện tượng:** Người dùng lưu/xóa địa điểm yêu thích khi mất mạng; khi có mạng trở lại, dữ liệu bị ghi đè sai lệch hoặc khôi phục lại trạng thái cũ.
* **Nguyên nhân:** Xung đột giữa Local Firestore Cache và Cloud Server mà không có cơ chế `merge` hoặc `serverTimestamp` kiểm tra thứ tự ghi.
* **Giải pháp:**
  - Luôn đính kèm `FieldValue.serverTimestamp()` và trường `updated_at` trong mọi tài liệu Firestore.
  - Sử dụng `SetOptions(merge: true)` hoặc `Transaction` khi cập nhật dữ liệu quan trọng.

### 8.2. Mất Phiên Đăng Nhập (Token Expiry) Làm Lặng Lẽ Hỏng Các Tác Vụ Ngầm
* **Hiện tượng:** Các tác vụ đồng bộ lịch sử hoặc gửi log analytics bị treo vô hạn mà không báo lỗi ra UI.
* **Nguyên nhân:** Firebase Auth Token hết hạn nhưng các Repository không bắt mã lỗi `FirebaseAuthException: user-token-expired` để thực hiện làm mới (refresh) hoặc điều hướng về Login.
* **Giải pháp:**
  - Đăng ký lắng nghe Stream `FirebaseAuth.instance.authStateChanges()` tại tầng Root Bloc.
  - Đóng gói lời gọi API qua Interceptor tự động xử lý khi nhận mã lỗi `401 Unauthorized`.

---

## 9. BẢO MẬT ỨNG DỤNG & TOÀN VẸN DỮ LIỆU CỤC BỘ

### 9.1. Lộ Khóa API & Secret Key Trong Mã Nguồn Git
* **Hiện tượng:** Nhận cảnh báo từ Google Cloud / MapLibre vì quota API bị sử dụng trái phép từ IP lạ.
* **Nguyên nhân:** Commit trực tiếp file `firebase_options.dart`, Google Services JSON, hoặc API Keys lên kho mã nguồn công khai/nội bộ.
* **Giải pháp:**
  - Lưu toàn bộ API Keys và biến môi trường trong file `.env` (được đưa vào `.gitignore`).
  - Sử dụng CI/CD Secret Variables khi build tự động.
  - Giới hạn quyền (Restrict API Key) theo Android Package Name + SHA-1 Fingerprint và iOS Bundle ID trên Google Cloud Console.

### 9.2. Dữ Liệu Cục Bộ Bị Can Thiệp / Đánh Cắp
* **Hiện tượng:** Cơ sở dữ liệu POI độc quyền bị trích xuất hoặc người dùng can thiệp sửa đổi file SQLite trên máy đã Root/Jailbreak.
* **Nguyên nhân:** Lưu trữ database dạng plain text ở thư mục công khai (`external storage`).
* **Giải pháp:**
  - Luôn lưu dữ liệu ứng dụng trong thư mục cục bộ an toàn (`getApplicationDocumentsDirectory()`).
  - Mã hóa các thông tin nhạy cảm (Token, User Profile) bằng `FlutterSecureStorage` (sử dụng Keystore trên Android và Keychain trên iOS).

---

## 10. QUY CHUẨN KIỂM THỬ & ĐO LƯỜNG HIỆU NĂNG (TESTING STANDARDS)

### 10.1. "Cạm Bẫy Test Giả" (Fake/Dummy Testing Trap)
* **Hiện tượng:** Test Suite đạt độ phủ (Coverage) 90% nhưng khi phát hành app vẫn gặp lỗi nghiêm trọng (crash, sai đường, sai định dạng).
* **Nguyên nhân:** Viết test giả định, mock hời hợt, chỉ assert chung chung kiểu `expect(result != null, true)` hoặc `expect(true, isTrue)` thay vì kiểm tra dữ liệu thật.
* **Quy tắc Kiểm thử Thực tế Cho S-Map:**
  1. **Tọa độ thực tế:** Bắt buộc test với tọa độ GPS Việt Nam thực tế (TP.HCM, Hà Nội, đường giao nhau, đường cao tốc, cầu vượt).
  2. **Assert sâu toàn diện:** Kiểm tra tính hợp lệ của từng trường dữ liệu trả về (`distance > 0`, `time > 0`, `points.length >= 2`, `instructions` không rỗng, `bbox` bao trùm toàn bộ điểm).
  3. **Kiểm tra Edge Cases:**
     - Điểm xuất phát và điểm đích trùng nhau ($Distance = 0$).
     - Điểm nằm ngoài phạm vi bản đồ offline.
     - Hai điểm không có đường nối hợp lệ (ví dụ: qua sông không có cầu, đường cụt).
     - Dữ liệu rỗng, dữ liệu null, chuỗi JSON biến dạng.

### 10.2. Kiểm Thử Hiệu Năng & Đo Lường Độ Trễ (Performance Benchmark)
* **Quy chuẩn bắt buộc trước khi Release:**
  - **Khởi tạo Routing Engine:** Thời gian `initGraphHopper()` phải $\le 1500\text{ ms}$ trên máy thật.
  - **Thời gian tìm đường:** Thời gian `getRoute()` phải $\le 300\text{ ms}$ cho quãng đường nội đô ($< 30\text{ km}$) qua $\ge 20$ lần lặp đo đạc liên tiếp.
  - **Tìm kiếm POI FTS5:** Tốc độ phản hồi tìm kiếm địa điểm phải $\le 50\text{ ms}$ với bộ dữ liệu $> 40.000$ POIs.
  - **Tốc độ khung hình (Frame Budget):** Duy trì ổn định $\ge 55\text{ FPS}$ khi người dùng pan/zoom bản đồ và xoay la bàn dẫn đường.

---

## BẢNG TỔNG KẾT HÀNH ĐỘNG PHÒNG NGỪA NHANH (QUICK CHECKLIST)

| Hạng mục | Rủi ro chính | Giải pháp cốt lõi | Người phụ trách kiểm tra |
|---|---|---|---|
| **Map Rendering** | Tràn Texture GPU, Crash Native | Dùng `GeoJsonSource` + `Clustering`, không dùng `addSymbol()` đơn lẻ | Flutter Dev |
| **Routing** | Freeze UI, Crash JNI Release | Chuyển parse sang Isolate, cấu hình `proguard-rules.pro` | Mobile & Pipeline Dev |
| **Location & Sensor** | Nhảy điểm GPS, Rung giật La bàn | Áp dụng Kalman Filter, Debounce góc quay la bàn $\le 30\text{ FPS}$ | Flutter Dev |
| **Database** | Lock DB, Quét chậm, Lỗi dấu TV | Bật WAL Mode, Bounding Box Pre-filter, Normalized Column | Data & Backend Dev |
| **Architecture** | Rò rỉ UI Controller trong BLoC | Tuân thủ BLoC Purity, giao tiếp 100% qua State & Interfaces | Toàn bộ Team |
| **Security** | Lộ API Keys, Zip Slip Traversal | Dùng `.env`, kiểm tra chuỗi `destinationPath.startsWith(targetDir)` | Security & Lead Dev |
| **Verification** | Test ảo lọt bug ra Production | Viết Authentic Unit Test, đo benchmark $\ge 20$ iterations | QA & Flutter Dev |

---
*Tài liệu được thiết kế riêng cho dự án S-Map. Cập nhật định kỳ theo từng cột mốc kiến trúc mới.*
