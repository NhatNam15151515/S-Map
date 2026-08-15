# CLAUDE.md — S-Map Flutter Project

## Project Overview
S-Map là ứng dụng Flutter mobile (Android & iOS only) sử dụng Firebase backend.
Luôn trả lời bằng tiếng Việt.

## AI Tools đã cài sẵn — TỰ ĐỘNG SỬ DỤNG

### UI/UX Pro Max (Design Intelligence)
Khi cần chọn màu, font, UI style, hoặc UX patterns cho Flutter, TỰ ĐỘNG chạy search:

```bash
python "c:\Nhat Nam\intern flutter\S-map\.ai-tools\ui-ux-pro-max-skill\src\ui-ux-pro-max\scripts\search.py" "<query>" --stack flutter --domain <domain>
```

Domains: `style`, `color`, `typography`, `ux`, `icons`, `chart`, `landing`, `product`

### OpenSpace (Skill Management)
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
