# CLAUDE.md — S-Map Flutter Project

## Project Overview
S-Map là ứng dụng Flutter mobile (Android & iOS only) sử dụng Firebase backend.
Luôn trả lời bằng tiếng Việt.

## AI Tools đã cài sẵn — TỰ ĐỘNG SỬ DỤNG

### AgentMemory (Persistent Memory)
Server chạy trên http://localhost:3111. Kiểm tra bằng: `curl http://localhost:3111/agentmemory/health`
Nếu chưa chạy, gợi ý user chạy `agentmemory` trong terminal riêng.

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

## Conventions
- Dùng `WidgetStateProperty` (không dùng `MaterialStateProperty`)
- Dùng `CardThemeData` (không dùng `CardTheme` trong ThemeData)
- Feature-based architecture with commons layer
