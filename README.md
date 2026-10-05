# S-Map Flutter Application

Ứng dụng bản đồ số và dẫn đường ngoại tuyến chất lượng cao dành cho thị trường Việt Nam.

---

## 🛠️ Công Nghệ Sử Dụng

- **Framework**: Flutter (Target: Android & iOS)
- **State Management**: `flutter_bloc`, `hydrated_bloc`, `rxdart`
- **Routing Engine**: GraphHopper Core (Offline Turn-by-Turn GPS Navigation)
- **Map Renderer**: MapLibre GL Native với vector tiles định dạng PMTiles
- **Database & Cache**:
  - POI Database: SQLite FTS5 (Offline search)
  - Key-Value Cache: Hive, SharedPreferences, FlutterSecureStorage
- **Backend & Cloud Services (Firebase Project: `vn-s-map`)**:
  - Firebase Authentication (Google Sign-In & Anonymous Auth)
  - Cloud Firestore (Multi-tenant sync: Bookmark, Search History, Routes)
  - Firebase Crashlytics & Analytics (Telemetry)
- **Internationalization**: `easy_localization` (Tiếng Việt & English)

---

## 📐 Kiến Trúc Ứng Dụng (Clean Architecture)

- **Presentation Layer**: Widgets & Screens lắng nghe state từ BLoC/Cubit qua `BlocBuilder` / `BlocConsumer`.
- **Domain & Interface Layer (`lib/interfaces/`)**: Áp dụng triệt để nguyên lý Dependency Inversion. Các Cubits và Screen chỉ tương tác qua Interface trừu tượng.
- **Data & Repository Layer (`lib/repos/`, `lib/services/`)**: Hiện thực các kết nối dữ liệu (GraphHopper routing, POI local queries, Firestore sync).

---

## ⚙️ Thiết Lập Môi Trường & Build

### 1. Cài đặt phụ thuộc

```bash
flutter pub get
```

### 2. Sinh mã Localization

```bash
flutter pub run easy_localization:generate -S assets/translations -f keys -o locale_keys.g.dart
flutter pub run easy_localization:generate -S assets/translations
```

### 3. Khởi chạy theo Flavor

```bash
# Môi trường Development
flutter run -t lib/main.dart --dart-define-from-file=.env/dev.json

# Môi trường Production
flutter run -t lib/main.dart --dart-define-from-file=.env/pro.json
```

### 4. Đóng gói ứng dụng (Android APK / Bundle)

```bash
# Release APK Prod
flutter build apk -t lib/main.dart --dart-define-from-file=.env/pro.json

# App Bundle Prod
flutter build appbundle -t lib/main.dart --dart-define-from-file=.env/pro.json
```

---

## 🧪 Kiểm Thử

```bash
# Phân tích tĩnh mã nguồn
dart analyze lib test

# Chạy toàn bộ bộ kiểm thử tự động
flutter test
```
