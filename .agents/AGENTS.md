# S-Map Development Rules & AI Tools

> Luôn trả lời bằng tiếng Việt. Tuân thủ TOÀN BỘ quy tắc dưới đây khi viết code.

---

## Available AI Tools

### 1. UI/UX Pro Max (Design Intelligence cho Flutter)

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

> [!IMPORTANT]
> **Bắt buộc** chạy UI/UX Pro Max Skill TRƯỚC khi quyết định bất kỳ màu sắc, font, layout, hay map style nào. Không được tự ý đặt style khi chưa query tool này.

### 2. OpenSpace (Skill Management)

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
screens → cubits → [interfaces: IRepos] → repos → [interfaces: IServices] → services
   ↓         ↓              ↓               ↓               ↓                ↓
   └─────────────────────────── commons (shared layer) ──────────────────────┘
```

- **`interfaces/`** chứa toàn bộ abstract class interface cho Services và Repos (`i_location_service.dart`, `i_auth_repos.dart`, v.v.)
- **`screens/`** có thể import: `cubits/`, `interfaces/`, `repos/`, `services/`, `commons/`, `models/`, `constants/`, `routers/`
- **`cubits/`** có thể import: `interfaces/`, `repos/`, `services/`, `models/`, `commons/`
- **`repos/`** có thể import: `interfaces/`, `services/`, `models/`
- **`services/`** có thể import: `interfaces/`, `models/`, `constants/`, `flavor/` — KHÔNG import ngược lên `repos/`, `cubits/`, `screens/`
- **`models/`** là pure data class — KHÔNG chứa business logic, KHÔNG import bất kỳ layer nào khác
- **`commons/`** là shared layer — chỉ chứa code dùng chung >= 2 features

### Interface-First & Dependency Inversion Rules (BẮT BUỘC)

1. **Mọi Service & Repo phải có Interface**: Mọi Service và Repository mới đều **BẮT BUỘC** khai báo abstract interface tại `lib/interfaces/` (ví dụ: `i_location_service.dart`, `i_auth_repos.dart`).
2. **Export qua Barrel file**: Mọi interface mới phải được export trong `lib/interfaces/interfaces.dart`.
3. **Phụ thuộc vào Interface**: Tầng gọi (Cubit, Screen, Repo) phải phụ thuộc vào Interface (`ILocationService`, `IAuthRepos`), KHÔNG phụ thuộc trực tiếp vào Concrete class.
4. **Hỗ trợ Dependency Injection**: Constructor của Cubit/Bloc/Repo phải cho phép nhận Interface parameter (default về `Service.instance`) để thuận tiện cho việc Mock trong Unit Test.
5. **Mock sạch sẽ trong Unit Test**: Unit test mock bằng cách `implements IService` thay vì `extends ConcreteService` để tránh side-effect từ constructor thật.

### Clean Architecture & UI Separation Rules (BẮT BUỘC)

1. **UI Không gọi trực tiếp Service/Repository**: UI Screens và Widgets **TUYỆT ĐỐI KHÔNG** import `services/` hay gọi các singleton `Service.instance` (ngoại trừ pure UI utilities như `Validator`). Mọi tương tác Service I/O (Auth, Map Style, GPS, Messaging, Storage) phải được bọc trong Cubit / Bloc / Repos.
2. **Pure UI Widgets**: Các Widget con (như `MapView`, `MapControls`, `ExploreBottomSheet`) chỉ nhận data và callback từ parameters (props) do Screen / Cubit truyền xuống, không tự truy xuất Singleton Service.
3. **Barrel Export Convention**: Luôn import từ các barrel export file chuẩn (`models/models.dart`, `services/services.dart`, `repos/repos.dart`, `interfaces/interfaces.dart`, `constants/constants.dart`, `commons/widgets/widgets.dart`, `commons/cubits/cubits.dart`). **CẤM import lẻ tẻ** từng file thành phần khi đã có barrel file.
4. **Type-Safety cho Completer / Async**: Bắt buộc chỉ định rõ generic type cho `Completer<T>` (ví dụ: `Completer<bool>`), không dùng raw type `Completer`.

### Vi phạm kiến trúc nghiêm trọng

- ❌ KHÔNG để UI Screens hoặc Widgets gọi trực tiếp `Service.instance` / `Repo.instance`
- ❌ KHÔNG tạo Service hoặc Repo mà thiếu Interface trong `lib/interfaces/`
- ❌ KHÔNG phụ thuộc trực tiếp vào Concrete Service trong Cubit/Repo nếu đã có Interface
- ❌ KHÔNG import lẻ tẻ từng file khi đã có barrel export file tương ứng
- ❌ KHÔNG import trực tiếp `screens/featureA` từ `screens/featureB` → phải thông qua `commons/` hoặc router
- ❌ KHÔNG tạo circular dependency giữa các layer
- ❌ KHÔNG đặt business logic trong widget `build()` method

---

## 2. State Management Rules (BLoC/Cubit)

### Convention

- **Cubit** là lựa chọn mặc định cho phần lớn use case
- **Single Class State Pattern (BẮT BUỘC)**: Mọi State class của BLoC/Cubit phải sử dụng mô hình **Single Class** với `enum *Status { initial, loading, success, empty, error }`, phương thức `copyWith`, các helper boolean getters (`isInitial`, `isLoading`, `isSuccess`, `isEmpty`, `isError`, v.v.), và override `props` đầy đủ. **TUYỆT ĐỐI KHÔNG** dùng State Inheritance / Subclassing (như `XxxInitial`, `XxxLoading`, `XxxSuccess`) để đảm bảo tính nhất quán trên toàn bộ codebase.
- **Equatable Standard**: Mọi State class của BLoC/Cubit **BẮT BUỘC** `extends Equatable` và override `props`. **TUYỆT ĐỐI KHÔNG** dùng `with EquatableMixin` (đã bị deprecated trong package `equatable`) hoặc tự viết `operator ==` thủ công.
- Cubit/Bloc global (auth, app): đặt trong `commons/cubits/` hoặc `commons/blocs/`
- Cubit/Bloc local (feature-specific): đặt trong `screens/<feature>/cubits/`

### Quy tắc chọn Cubit vs Bloc

- ✅ **Cubit** khi: state thay đổi theo action đơn giản, không có stream event liên tục
- ✅ **Bloc** khi: có event stream cần transformer để kiểm soát concurrency (race condition, debounce, queue)
- ❌ KHÔNG dùng Bloc chỉ vì "muốn tách event" — nếu không cần transformer thì dùng Cubit
- ✅ **Single Class Pattern**: State class duy nhất có `enum Status`, `copyWith` và `props`
- ✅ **extends Equatable**: Tất cả state đều kế thừa `Equatable` và khai báo `props` đầy đủ

### Pattern bắt buộc

```dart
// ✅ Single Class State Pattern với enum Status
enum XxxStatus { initial, loading, success, error }

class XxxState extends Equatable {
  final XxxStatus status;
  final List<Model> items;
  final String? errorMessage;

  const XxxState({
    this.status = XxxStatus.initial,
    this.items = const [],
    this.errorMessage,
  });

  bool get isInitial => status == XxxStatus.initial;
  bool get isLoading => status == XxxStatus.loading;
  bool get isSuccess => status == XxxStatus.success;
  bool get isError => status == XxxStatus.error;

  XxxState copyWith({
    XxxStatus? status,
    List<Model>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return XxxState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, items, errorMessage];
}

// ✅ Concurrency Guard cho Bloc Event Handler với restartable():
Future<void> _onAsyncEvent(
  AsyncEvent event,
  Emitter<XxxState> emit,
) async {
  emit(state.copyWith(status: XxxStatus.loading));
  final results = await _repository.fetchData();
  // BẮT BUỘC: Kiểm tra emit.isDone trước khi emit sau async gap
  if (emit.isDone) return;
  emit(state.copyWith(status: XxxStatus.success, items: results));
}
```

### Anti-patterns (CẤM TUYỆT ĐỐI)

- ❌ KHÔNG dùng `with EquatableMixin` (deprecated) → phải dùng `extends Equatable`
- ❌ KHÔNG tự override `operator ==` / `hashCode` thủ công cho state → dùng `Equatable`
- ❌ KHÔNG giữ UI Controllers (`MapLibreMapController`, `ScrollController`, `TextEditingController`, `AnimationController`) trong Cubit/BLoC → Widget UI giữ controller và lắng nghe state/actions qua `BlocListener` / `BlocConsumer`
- ❌ KHÔNG mixin UI helper (`with AppMixin`) hoặc `BuildContext` vào Cubits, Services, Repositories
- ❌ KHÔNG dùng `ValueNotifier` / `ChangeNotifier` song song với Cubit State cho cùng dữ liệu (No Dual State Management)
- ❌ KHÔNG gọi `getData()` trong constructor cubit → gọi ở `initState()` của widget
- ❌ KHÔNG dùng `setState()` trong StatefulWidget phức tạp → dùng Cubit
- ❌ KHÔNG emit state sau khi cubit đã close (bắt buộc override emit guard)
- ❌ KHÔNG listen stream mà không cancel subscription khi dispose

### Cấu trúc file Cubit/Bloc

```
commons/cubits/<name>/
├── <name>.dart           # Cubit/Bloc class (Pure State/Logic)
├── <name>_state.dart     # State class (extends Equatable)
└── <name>_event.dart     # Event class (chỉ khi dùng Bloc)
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

### Nguyên tắc bất biến — No Hard-code / No God-code

- ❌ **KHÔNG hard-code** màu sắc, font size, spacing, string, magic number thẳng vào widget
- ❌ **KHÔNG viết god-code** — mỗi file chỉ làm đúng MỘT nhiệm vụ (không lẫn UI + logic + state)
- ✅ Mọi giá trị constant dùng từ `lib/constants/` hoặc `lib/commons/styles/`
- ✅ Mọi quyết định UI phải qua UI/UX Pro Max Skill trước

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

### Map Style (MapLibre)

- Style phải gần với Google Maps để thân thiện với người dùng Việt Nam
- Bắt buộc chạy query `map style google maps like` qua UI/UX Pro Max trước khi viết `style.json`
- Palette tham chiếu: nền `#F2EFE9`, đường `#FFFFFF`/`#E8E4DA`, nước `#A8D8EA`, công viên `#C8DEBA`, nhãn `#666666`
- Glyph font phải hỗ trợ **Latin Extended Additional** (tiếng Việt có dấu đầy đủ)

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

### Single Responsibility — Mỗi file chỉ làm 1 nhiệm vụ

- **`<feature>_screen.dart`**: Chỉ scaffold + `BlocProvider` + compose các widget con. **Không** chứa business logic, state, hay inline style.
- **`cubits/<feature>_cubit.dart`**: Chỉ chứa state management logic, gọi repository.
- **`cubits/<feature>_state.dart`**: Chỉ định nghĩa các state class.
- **`widgets/<widget>.dart`**: Từng widget nhỏ, tái sử dụng được, nhận data qua constructor — không tự fetch data.

### Tạo feature mới

```
screens/<feature_name>/
├── <feature_name>_screen.dart    # Presentation: scaffold + compose only
├── cubits/                        # State management (số nhiều, nhất quán với commons/cubits/)
│   ├── <feature>_cubit.dart
│   └── <feature>_state.dart
└── widgets/                       # Các widget con (mỗi widget 1 file)
    └── <widget_name>.dart
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
| Map style JSON                    | `assets/map/`         |

### Import Convention

- ✅ Dùng package import: `import 'package:boilerplate/...';`
- ❌ KHÔNG dùng relative path dài: `import '../../../services/...';` (trừ file cùng thư mục)

---

## 8. Git Workflow Rules

### Quy trình bắt buộc (theo đúng thứ tự):

1. **Checkout đúng nhánh `dev-w*`** tương ứng với sprint hiện tại:
   ```bash
   git checkout dev-w<N>
   git pull origin dev-w<N>
   ```
2. **Tạo nhánh feature mới** từ nhánh `dev-w*` đó:
   ```bash
   git checkout -b feature/uissue-<N>-<short-desc>
   ```
3. Code và commit theo convention: `feat/fix/refactor/chore(scope): mô tả ngắn gọn`
4. Push nhánh feature lên remote rồi **tạo Pull Request** về `dev-w*`:
   ```bash
   git push -u origin feature/issue-<N>-<short-desc>
   gh pr create --base dev-w<N> --title "..."
   ```

> [!CAUTION]
> **KHÔNG push thẳng lên `dev-*` hay `main`** dưới bất kỳ hình thức nào.

---

## 9. Reuse-First Rules — Tận dụng tối đa source sẵn có

Project đã có nền tảng build sẵn rất tốt. **Ưu tiên tái sử dụng và mở rộng** hơn là tạo mới.

### Checklist trước khi tạo file mới:

| Kiểm tra                                           | Nơi tìm                                                |
| --------------------------------------------------- | -------------------------------------------------------- |
| Có Cubit/State chung nào phù hợp chưa?              | `commons/cubits/` (MapDisplayCubit, AppCubit, AuthCubit) |
| Có mixin có sẵn nào giải quyết được chưa? | `commons/mixin/` (AppMixin, AppBarMixin, AuthMixin)   |
| Có widget tái dùng nào sẵn chưa?              | `commons/widgets/` (EmptyWidget, TitleAppBar, ProfileAvatar…) |
| Có service sẵn nào xử lý được chưa?        | `services/` (LocationService, MapStyleService…)       |
| Có extension/util sẵn nào không?                | `commons/extensions/`, `commons/utils/`              |

### Quy tắc:

- ✅ **Mở rộng (extend/mixin)** các class sẵn có thay vì tạo mới từ đầu
- ✅ **Tùy chỉnh linh hoạt** các build sẵn (có thể override, wrap, thêm param) nhưng **không được thay đổi logic gốc** của nó
- ✅ Nếu cần điều chỉnh hành vi: ưu tiên **subclass** hoặc **composition** thay vì sửa trực tiếp
- ❌ **KHÔNG tạo duplicate** của thứ đã có sẵn (ví dụ: không tạo `LocationService2` nếu `LocationService` đã đủ)
- ❌ **KHÔNG rewrite** logic đã hoạt động ổn định mà không có lý do rõ ràng

### Ví dụ áp dụng cho Map:

| Cần                | Dùng sẵn có                                        |
| ------------------- | ----------------------------------------------------- |
| Loading/Error state | `MapDisplayState` từ `MapDisplayCubit`           |
| Lấy GPS position   | `ILocationService` (LocationService.instance)         |
| Thông báo lỗi    | `AppMixin.showError()` / `showWarning()`          |
| Empty/Error UI      | `EmptyWidget` tái dùng lại                       |

---

## 10. Localization & i18n Rules (Quy chuẩn Đa ngôn ngữ & Translation Codegen)

Dự án cấu hình `EasyLocalization` với bộ tải mã nguồn sinh trước `assetLoader: const CodegenLoader()` ([app.dart](lib/app.dart)). Mọi thành viên và AI Agent **BẮT BUỘC** tuân thủ quy trình sau:

### 1. Không Hardcode String
- Mọi chuỗi ký tự hiển thị trên UI (Title, Subtitle, AppBar, BottomNavigationBarItem label, Button, TextField hint/label, Tooltip, Dialog, EmptyWidget, Error toast, v.v.) **TUYỆT ĐỐI KHÔNG HARDCODE**.
- Phải bọc qua `tr(LocaleKeys.xxx)` (Type-safe).

### 2. Quy trình thêm / cập nhật Translation (3 bước bắt buộc):
1. **Khai báo song ngữ**: Luôn cập nhật đồng thời ở cả hai file `assets/translations/vi.json` và `assets/translations/en.json`.
2. **Không xung đột namespace**: Tránh đặt key vừa là String vừa là Map (ví dụ nếu `"notification": "Thông báo"` là String thì tab con phải đặt là `"notification_tabs": { "tab_system": "Hệ thống" }`).
3. **Chạy lệnh Regenerate**:
   ```bash
   dart run easy_localization:generate -S assets/translations -O lib/generated
   dart run easy_localization:generate -S assets/translations -f keys -O lib/generated -o locale_keys.g.dart
   ```
   > [!IMPORTANT]
   > Nếu quên chạy lệnh generate, `CodegenLoader` tại runtime sẽ không tìm thấy key mới và in chuỗi raw string (ví dụ `search_bar.placeholder`) lên thiết bị thật!

### 3. Không dùng `LocaleKeys.xxx` trần trụi
- Các thuộc tính nhận `String` (như `BottomNavigationBarItem.label`, `TitleAppBar.title`, `EmptyWidget.title`) không tự động dịch `LocaleKeys.xxx`. **BẮT BUỘC** phải gọi `tr(LocaleKeys.xxx)`.

---

## 11. Common Anti-patterns (Các lỗi CẤM)

| #  | Anti-pattern                                         | Cách đúng                                     |
| -- | ---------------------------------------------------- | ------------------------------------------------ |
| 1  | `setState()` cho logic phức tạp                  | Dùng Cubit                                      |
| 2  | `TextStyle()` inline                               | Dùng`AppTextTheme` system                     |
| 3  | `Color(0xFF...)` inline trong widget               | Dùng`AppColors.xxx`                           |
| 4  | `withOpacity()`                                    | Dùng`withAlpha()` hoặc `Color.fromRGBO()`  |
| 5  | `MaterialStateProperty`                            | Dùng`WidgetStateProperty`                     |
| 6  | `CardTheme()` trong ThemeData                      | Dùng`CardThemeData()`                         |
| 7  | `print()` debug                                    | Dùng`DLog` (commons/log)                      |
| 8  | Hardcode string hiển thị                           | Dùng`tr(LocaleKeys.xxx)`                      |
| 9  | Quên chạy `easy_localization:generate`             | Chạy generate sau khi sửa `vi.json` / `en.json` |
| 10 | Dùng `LocaleKeys.home` không bọc `tr()`             | Dùng `tr(LocaleKeys.home)`                      |
| 11 | `Navigator.push()`                                 | Dùng`context.go()` / `context.push()`       |
| 12 | Import relative path dài                            | Dùng`package:s_map/...`                       |
| 13 | Tạo Dio instance riêng                             | Dùng`BaseAPIClient.request()`                 |
| 14 | Catch`DioException` trong feature                  | Catch`ErrorResponse`                           |
| 15 | Không override`emit()` trong Cubit                | Thêm`if(isClosed) return;` guard              |
| 16 | Import screen từ screen khác                       | Đi qua`commons/` hoặc router                 |
| 17 | Thêm platform web/desktop                           | Chỉ Android & iOS                               |
| 18 | Viết logic/state trong`_screen.dart`              | Tách ra`cubit/` và `widgets/`              |
| 19 | Tự đặt màu/style map mà không dùng UI/UX tool | Chạy UI/UX Pro Max Skill trước                |
| 20 | Push thẳng lên`dev-*` / `main`                 | Tạo nhánh`feature/...` + Pull Request        |
| 21 | Magic number trong code                              | Đặt vào`constants/` với tên có nghĩa    |
| 22 | Hard-code màu map trong`style.json`               | Dùng palette từ UI/UX skill + gần Google Maps |
| 23 | `with EquatableMixin` (deprecated) / flawed `operator ==` | Dùng `extends Equatable` và khai báo `props` |
| 24 | Sync I/O `File.existsSync()` trong Widget build tree | Dùng path prefix check hoặc async ImageProvider |
| 25 | Stream / RxDart Controller không dispose | Dùng `ListenableBuilder` hoặc `dispose()` triệt để |
| 26 | UI Screen / Widget gọi trực tiếp Singleton Service / Repo | Đóng gói I/O vào Cubit / State và inject props vào Widget |
| 27 | Import lẻ tẻ từng file thành phần | Dùng Barrel export file (`models/models.dart`, `widgets/widgets.dart`...) |
| 28 | Raw type `Completer` không khai báo kiểu generic | Khai báo rõ kiểu: `Completer<bool>` / `Completer<T>` |



