# CLAUDE.md — S-Map Flutter Project

## Project Overview
S-Map là ứng dụng Flutter mobile (Android & iOS only) sử dụng Firebase backend.
Luôn trả lời bằng tiếng Việt.

## AI Tools đã cài sẵn — TỰ ĐỘNG SỬ DỤNG BẮT BUỘC
 
### 1. Codebase Intelligence (`tools/codebase_mcp`)
Mỗi khi khảo sát, refactor hoặc verify codebase, BẮT BUỘC dùng `smap-codebase-intel`:
- **Khảo sát**: `get_repo_map`, `query_symbol`, `get_file_dependencies`
- **Kiểm tra kiến trúc**: `check_architecture_rules`, `get_architecture_report` (yêu cầu 0 violations, 0 circular)
- **Kiểm tra static analysis**: `get_violations_summary`, `run_dart_analyze`
 
### 2. UI/UX Pro Max (Design Intelligence)
Khi cần chọn màu, font, UI style, hoặc UX patterns cho Flutter, TỰ ĐỘNG chạy search:
 
```bash
python "c:\Nhat Nam\intern flutter\S-map\.ai-tools\ui-ux-pro-max-skill\src\ui-ux-pro-max\scripts\search.py" "<query>" --stack flutter --domain <domain>
```
 
Domains: `style`, `color`, `typography`, `ux`, `icons`, `chart`, `landing`, `product`
 
### 3. OpenSpace (Skill Management)
```bash
& "$env:APPDATA\Python\Python313\Scripts\openspace.exe" --query "<task description>"
```

## Tech Stack
- Flutter/Dart, flutter_bloc, go_router, dio, easy_localization
- Firebase: Firestore, Messaging, Analytics, Crashlytics, Remote Config
- Font: Montserrat
- Platforms: Android & iOS ONLY

## Conventions & Clean Architecture Rules
- Dùng `WidgetStateProperty` (không dùng `MaterialStateProperty`)
- Dùng `CardThemeData` (không dùng `CardTheme` trong ThemeData)
- Feature-based architecture with commons layer
- **Interface-First**: Mọi Service và Repository BẮT BUỘC phải có Interface trong `lib/interfaces/`
- **Dependency Inversion**: Tầng trên (Cubit/Screen/Repo) phụ thuộc vào Interface (`ILocationService`, `IAuthRepos`), không phụ thuộc trực tiếp vào Concrete class
- **Unit Test Mocks**: Mock bằng cách `implements Interface` thay vì kế thừa concrete class
- **Equatable Standard**: Mọi BLoC/Cubit state BẮT BUỘC `extends Equatable` (không dùng deprecated `with EquatableMixin`)
- **BLoC/Cubit Purity (Separation of Concerns)**:
  - TUYỆT ĐỐI KHÔNG giữ UI Controllers (`MapLibreMapController`, `ScrollController`, `TextEditingController`, `AnimationController`) trong Cubit/BLoC.
  - Widget UI quản lý controller cục bộ và lắng nghe state/action qua `BlocListener` / `BlocConsumer`.
  - TUYỆT ĐỐI KHÔNG mixin UI helper (`with AppMixin`) hoặc `BuildContext` vào Cubits, Services, Repositories.
  - TUYỆT ĐỐI KHÔNG trộn lẫn `ValueNotifier` / `ChangeNotifier` song song với Cubit State (Single Source of Truth).
- **Localization & i18n Codegen**:
  - TUYỆT ĐỐI KHÔNG hardcode chuỗi text trên UI. Toàn bộ chuỗi hiển thị phải gọi qua `tr(LocaleKeys.xxx)`.
  - Khi cập nhật `assets/translations/vi.json` hoặc `en.json`, BẮT BUỘC chạy sinh mã:
    `dart run easy_localization:generate -S assets/translations -O lib/generated; dart run easy_localization:generate -S assets/translations -f keys -O lib/generated -o locale_keys.g.dart`
  - Không đặt key trùng tên giữa String nguyên thủy và Map lồng nhau để tránh xung đột kiểu.
