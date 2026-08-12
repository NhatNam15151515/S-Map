# S-Map Workspace Agent Rules

## 1. AgentMemory Automatic Integration Rule

- Server AgentMemory đang chạy trên local (`http://localhost:3111`).
- Khi bắt đầu một task lớn hoặc khi cần thông tin về lịch sử dự án/kinh nghiệm/context cũ, AI TỰ ĐỘNG kiểm tra context hoặc chạy script `.ai-tools/sync_memory.py` / CLI `agentmemory` để đọc context và lưu lại các bài học quan trọng.

# S-Map Development Rules & AI Tools

> Luôn trả lời bằng tiếng Việt. Tuân thủ TOÀN BỘ quy tắc dưới đây khi viết code.

---

## Available AI Tools

Khi bắt đầu session, hãy kiểm tra và sử dụng các AI tools đã cài sẵn:

### 1. AgentMemory (Persistent Memory)

- **Server**: http://localhost:3111
- **Viewer**: http://localhost:3113
- **Health check**: Chạy `curl http://localhost:3111/agentmemory/health` để kiểm tra server
- **Nếu server chưa chạy**: Chạy `agentmemory` trong terminal riêng trước khi làm việc
- AgentMemory giúp nhớ context giữa các sessions. Không cần re-explain architecture hoặc decisions đã làm trước đó.

### 2. UI/UX Pro Max (Design Intelligence cho Flutter)

Khi cần design decisions (chọn màu, font, UI style, UX patterns), hãy search từ database:

```powershell
# Biến search path
$uiSearch = "c:\Nhat Nam\intern flutter\S-map\.ai-tools\ui-ux-pro-max-skill\src\ui-ux-pro-max\scripts\search.py"

# Tìm UI style cho Flutter
python $uiSearch "<mô tả>" --stack flutter --domain style

# Tìm color palette
python $uiSearch "<mô tả>" --domain color

# Tìm font pairing
python $uiSearch "<mô tả>" --domain typography

# Tìm UX guidelines
python $uiSearch "<mô tả>" --domain ux

# Tìm icon recommendations
python $uiSearch "<mô tả>" --domain icons
```

**Domains có sẵn**: `style`, `color`, `typography`, `ux`, `icons`, `chart`, `landing`, `product`, `google-fonts`, `gsap`

### 3. OpenSpace (Skill Management)

Khi cần tìm skill hoặc workflow patterns:

```powershell
& "$env:APPDATA\Python\Python313\Scripts\openspace.exe" --query "<mô tả task>"
```

---

## Project Context: S-Map

- **Framework**: Flutter (Dart), SDK >=3.4.0 <4.0.0
- **Target platforms**: Android & iOS ONLY
- **State management**: flutter_bloc (Cubit-only, không dùng Bloc event-based)
- **Routing**: go_router (singleton `Routes.instance`)
- **Localization**: easy_localization
- **HTTP client**: Dio (wrapped trong `BaseAPIClient`)
- **Backend**: Firebase (Firestore, Messaging, Analytics, Crashlytics, Remote Config)
- **Font**: Montserrat (duy nhất)
- **Architecture**: Feature-based structure with commons layer
- **Build flavors**: dev / sta / pro

---

## 1. Architecture Rules (Kiến trúc)

### Dependency Flow (Một chiều, KHÔNG ngược)

```
screens → cubits → repos → services
   ↓         ↓        ↓        ↓
   └── commons (shared layer) ──┘
```

- **`screens/`** có thể import: `cubits/`, `repos/`, `services/`, `commons/`, `models/`, `constants/`, `routers/`
- **`cubits/`** có thể import: `repos/`, `services/`, `models/`, `commons/`
- **`repos/`** có thể import: `services/`, `models/`
- **`services/`** có thể import: `models/`, `constants/`, `flavor/` — KHÔNG import ngược lên `repos/`, `cubits/`, `screens/`
- **`models/`** là pure data class — KHÔNG chứa business logic, KHÔNG import bất kỳ layer nào khác
- **`commons/`** là shared layer — chỉ chứa code dùng chung >= 2 features

### Vi phạm kiến trúc nghiêm trọng

- ❌ KHÔNG import trực tiếp `screens/featureA` từ `screens/featureB` → phải thông qua `commons/` hoặc router
- ❌ KHÔNG tạo circular dependency giữa các layer
- ❌ KHÔNG đặt business logic trong widget `build()` method

---

## 2. State Management Rules (BLoC/Cubit)

### Convention

- **Cubit** là lựa chọn mặc định cho phần lớn use case
- **Bloc** được phép khi cần event transformer (`restartable()`, `droppable()`, `sequential()`) để kiểm soát concurrency — ví dụ: GPS stream, viewport search, reroute logic
- Cubit cho API call: kế thừa pattern từ `GenericCubit<T>` hoặc `GenericNonNullCubit<T>`
- Cubit cho UI state đơn giản: dùng `BaseChangeCubit<T>`
- Cubit/Bloc global (auth, app): đặt trong `commons/cubits/`
- Cubit/Bloc local (feature-specific): đặt trong `screens/<feature>/cubits/`

### Quy tắc chọn Cubit vs Bloc

- ✅ **Cubit** khi: state thay đổi theo action đơn giản, không có stream event liên tục
- ✅ **Bloc** khi: có event stream cần transformer để kiểm soát concurrency (race condition, debounce, queue)
- ❌ KHÔNG dùng Bloc chỉ vì "muốn tách event" — nếu không cần transformer thì dùng Cubit

### Pattern bắt buộc

```dart
// ✅ Override emit() để tránh emit-after-close crash (áp dụng cả Cubit lẫn Bloc)
@override
void emit(GenericState<T> state) {
  if(isClosed) return;
  super.emit(state);
}
```

### Anti-patterns

- ❌ KHÔNG gọi `getData()` trong constructor cubit → gọi ở `initState()` của widget
- ❌ KHÔNG dùng `setState()` trong StatefulWidget phức tạp → dùng Cubit
- ❌ KHÔNG emit state sau khi cubit đã close
- ❌ KHÔNG listen stream mà không cancel subscription khi dispose

### Cấu trúc file Cubit/Bloc

```
commons/cubits/<name>/
├── <name>.dart           # Cubit/Bloc class
├── <name>_state.dart     # State class
├── <name>_event.dart     # Event class (chỉ khi dùng Bloc)
└── <name>_helper.dart    # Extension helpers (nếu cần)
```

---

## 3. API & Repository Rules (Networking)

### API Client

- Mọi API call **PHẢI** đi qua `BaseAPIClient.request<T>()` — KHÔNG tự tạo Dio instance
- Base URL lấy từ `Flavor.instance.baseUrl` — KHÔNG hardcode
- Interceptor chain đã setup: `Auth → Log → Error` (cho `apiClient`) và `Cache → Log → Error` (cho `cacheAPIClient`)

### Repository Pattern

```dart
// ✅ Luôn có abstract class → implementation class
abstract class XxxRepos {
  Future<Model?> getData();
}

class XxxReposImpl extends XxxRepos {
  final BaseAPIClient apiClient;
  XxxReposImpl(this.apiClient);

  @override
  Future<Model?> getData() async {
    final response = await apiClient.request<APIResponse<Model>>(
      route: APIRoute(apiType: APIType.xxx),
      create: (res) => APIResponse<Model>(
        response: res,
        decodedData: Model(),
      ),
    );
    return response.decodedData;
  }
}
```

### Đăng ký Repository mới

1. Thêm abstract + impl class trong `repos/`
2. Thêm getter trong `AppReposProvider` (file `app_cubit.dart`)
3. Thêm enum value vào `APIType` + config route trong `APIRoute`

### Error Handling

- Catch `ErrorResponse` — KHÔNG catch `DioException` trực tiếp trong feature code
- `GenericCubit` đã handle error centralized → feature code chỉ cần lắng nghe `GenericStateType.error`

---

## 4. Routing Rules (Navigation)

### Convention bắt buộc

```dart
// ✅ Mỗi screen PHẢI declare static path
class XxxScreen extends StatefulWidget {
  static const String path = '/xxx';
  // ...
}
```

### Navigation

- Dùng `context.go()` cho replace (tab switch, auth redirect)
- Dùng `context.push()` cho stack navigation
- ❌ KHÔNG dùng `Navigator.push()` hay `Navigator.of(context)`

### Bottom Navigation Tabs

- Dùng `StatefulShellRoute.indexedStack` + `StatefulShellBranch` (đã setup trong `routers.dart`)
- Thêm tab mới: thêm `StatefulShellBranch` trong `branches` list
- ❌ KHÔNG tạo nested Navigator riêng cho mỗi tab

### Route Registration

1. Tạo screen với `static const String path`
2. Thêm `GoRoute` vào `routes` list trong `Routes` constructor
3. Nếu cần auth guard: xử lý trong `applyWithAuthState()`

---

## 5. Theme & Styling Rules

### Truy cập theme

```dart
// ✅ Luôn dùng AppStyle.of(context) để lấy theme
final style = AppStyle.of(context);
style.buttonStyle;
style.colorScheme;
style.blackTextColor;
```

### Màu sắc

- Dùng `AppColors.xxx` từ `commons/utils/app_colors.dart`
- ❌ KHÔNG tạo `Color(0xFF...)` inline trong widget
- ❌ KHÔNG dùng `withOpacity()` (deprecated) → dùng `withAlpha()` hoặc `Color.fromRGBO()`

### Font

- **Montserrat** là font duy nhất — KHÔNG import font khác
- Dùng `AppFontWeight` enum cho font weight: `AppFontWeight.regular.weight`, `AppFontWeight.bold.weight`, etc.
- Text style: dùng `AppTextTheme` system: `.textStyle`, `.boldStyle`, `.subTitleStyle`, `.textTitleStyle`

### Widget API Migration

- ✅ Dùng `WidgetStateProperty` (KHÔNG dùng `MaterialStateProperty` — deprecated)
- ✅ Dùng `CardThemeData` (KHÔNG dùng `CardTheme` khi truyền vào ThemeData)
- ✅ Dùng `withAlpha()` (KHÔNG dùng `withOpacity()` — deprecated)

---

## 6. Platform & Build Rules

### Platform

- Chỉ support **Android & iOS** — ❌ KHÔNG thêm web/desktop/Linux/macOS
- Orientation: Portrait only (`portraitUp`, `portraitDown`)
- Check platform dùng `Platform.isAndroid` / `Platform.isIOS` (đã import `dart:io`)

### Build Flavors

| Flavor      | Enum               | Suffix |
| ----------- | ------------------ | ------ |
| Development | `FlavorEnum.dev` | "D"    |
| Staging     | `FlavorEnum.sta` | "S"    |
| Production  | `FlavorEnum.pro` | ""     |

- ❌ KHÔNG tạo flavor mới khi chưa có approval
- Config qua `--dart-define`: `FLAVOR`, `BASE_URL`, `BUNDLE_ID`, `DISPLAY_NAME`, etc.

### Firebase

- Crashlytics chỉ enable ở production: `kReleaseMode && Flavor.instance.isProd`
- Remote Config dùng `RemoteConfigService` singleton
- Analytics dùng `FirebaseAnalyticsService` singleton

---

## 7. File Organization Rules

### Tạo feature mới

```
screens/<feature_name>/
├── <feature_name>_screen.dart    # Main screen widget
├── cubits/                        # Feature-specific cubits (nếu cần)
│   └── <cubit_name>/
├── widgets/                       # Feature-specific widgets (nếu cần)
└── models/                        # Feature-specific models (nếu cần, hiếm)
```

### Đặt file đúng chỗ

| Loại file                        | Vị trí                |
| --------------------------------- | ----------------------- |
| Widget dùng chung (≥2 features) | `commons/widgets/`    |
| Extension mới                    | `commons/extensions/` |
| Mixin mới                        | `commons/mixin/`      |
| Validator mới                    | `commons/validators/` |
| Data model                        | `models/`             |
| Repository                        | `repos/`              |
| Service (Firebase, API, device)   | `services/`           |
| App-wide constant                 | `constants/`          |
| Enum dùng chung                  | `commons/enums/`      |

### Import Convention

- ✅ Dùng package import: `import 'package:boilerplate/...';`
- ❌ KHÔNG dùng relative path dài: `import '../../../services/...';` (trừ file cùng thư mục)

---

## 8. Common Anti-patterns (Các lỗi CẤM)

| #  | Anti-pattern                          | Cách đúng                                    |
| -- | ------------------------------------- | ----------------------------------------------- |
| 1  | `setState()` cho logic phức tạp   | Dùng Cubit                                     |
| 2  | `TextStyle()` inline                | Dùng`AppTextTheme` system                    |
| 3  | `Color(0xFF...)` inline             | Dùng`AppColors.xxx`                          |
| 4  | `withOpacity()`                     | Dùng`withAlpha()` hoặc `Color.fromRGBO()` |
| 5  | `MaterialStateProperty`             | Dùng`WidgetStateProperty`                    |
| 6  | `CardTheme()` trong ThemeData       | Dùng`CardThemeData()`                        |
| 7  | `print()` debug                     | Dùng`DLog` (commons/log)                     |
| 8  | Hardcode string hiển thị            | Dùng`easy_localization` keys                 |
| 9  | `Navigator.push()`                  | Dùng`context.go()` / `context.push()`      |
| 10 | Import relative path dài             | Dùng`package:boilerplate/...`                |
| 11 | Tạo Dio instance riêng              | Dùng`BaseAPIClient.request()`                |
| 12 | Catch`DioException` trong feature   | Catch`ErrorResponse`                          |
| 13 | Không override`emit()` trong Cubit | Thêm`if(isClosed) return;` guard             |
| 14 | Import screen từ screen khác        | Đi qua`commons/` hoặc router                |
| 15 | Thêm platform web/desktop            | Chỉ Android & iOS                              |
