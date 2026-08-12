---
name: platform-build
description: |
  Quy tắc và pattern cho platform targeting, build flavors, Firebase integration,
  và deployment trong dự án S-Map Flutter.
  Bao gồm flavor system (dev/sta/pro), Firebase config, Crashlytics,
  Remote Config, và platform-specific code.
  Trigger khi: build app, cấu hình Firebase, thêm platform-specific feature,
  release build, cấu hình CI/CD.
---

# Platform & Build Skill — S-Map

## Platform Support

### Chỉ Android & iOS
- ❌ KHÔNG thêm web, desktop, Linux, macOS, Windows
- ❌ KHÔNG import `dart:html` hay `dart:js`
- Orientation: Portrait only (`portraitUp`, `portraitDown`)

### Platform-specific code
```dart
import 'dart:io';

// ✅ Dùng Platform check
if (Platform.isAndroid) {
  // Android-specific
}
if (Platform.isIOS) {
  // iOS-specific
}

// ❌ KHÔNG dùng kIsWeb (app này không support web)
```

---

## Build Flavors

### 3 Environments

| Flavor | Enum | Suffix | Crashlytics |
|--------|------|--------|-------------|
| Development | `FlavorEnum.dev` | "D" | ❌ Disabled |
| Staging | `FlavorEnum.sta` | "S" | ❌ Disabled |
| Production | `FlavorEnum.pro` | "" | ✅ Enabled |

### Build Commands
```bash
# Development
flutter run --dart-define=FLAVOR=dev --dart-define=BASE_URL=... --dart-define=BUNDLE_ID=...

# Staging
flutter run --dart-define=FLAVOR=sta --dart-define=BASE_URL=... --dart-define=BUNDLE_ID=...

# Production (Release)
flutter build apk --release --dart-define=FLAVOR=pro --dart-define=BASE_URL=...
flutter build ipa --release --dart-define=FLAVOR=pro --dart-define=BASE_URL=...
```

### Truy cập Flavor Config
```dart
// Tất cả config đều qua Flavor singleton
Flavor.instance.baseUrl;        // API base URL
Flavor.instance.bundleId;       // Bundle ID
Flavor.instance.displayName;    // App display name
Flavor.instance.isProd;         // true nếu production
Flavor.instance.subEnv;         // "D", "S", hoặc ""
Flavor.instance.s3AssetUrl;     // S3 asset URL
Flavor.instance.googleClientId; // Google auth client ID
Flavor.instance.iosAppId;       // iOS App Store ID
```

### ❌ KHÔNG làm
- Hardcode base URL, bundle ID, hay bất kỳ config nào
- Tạo flavor mới khi chưa có approval
- Dùng `const String.fromEnvironment()` trực tiếp — luôn qua `Flavor.instance`

---

## Firebase Integration

### Services đã setup sẵn

| Service | Class | Init |
|---------|-------|------|
| Core | `Firebase` | `main.dart` |
| Analytics | `FirebaseAnalyticsService` | Singleton |
| Messaging (FCM) | `FirebaseMessagingService` | `main.dart` |
| Crashlytics | `FirebaseCrashlytics` | `main.dart` |
| Remote Config | `RemoteConfigService` | `main.dart` |
| Firestore | `FirebaseFirestoreService` | On-demand |

### Crashlytics Rules
```dart
// ✅ Chỉ enable ở production release
FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
  kReleaseMode && Flavor.instance.isProd
);
```

### Firebase Analytics
```dart
// ✅ Log event
await FirebaseAnalyticsService().logEvent('my_event', {'key': 'value'});

// ✅ Set user
await FirebaseAnalyticsService().resetUserDetail(profile: user);
```

### Remote Config
```dart
// ✅ Đọc config
final value = RemoteConfigService().getString('my_key');
final maintenance = RemoteConfigService().maintenance;
final mustUpdate = await RemoteConfigService().mustUpdate();
```

### FCM Token
```dart
// ✅ Lấy FCM token
final token = await FirebaseMessagingService.instance.getToken();
```

---

## Notification

### Local Notification
```dart
// Đã setup sẵn trong LocalNotificationService
await LocalNotificationService.instance.init();
// Show notification
LocalNotificationService.instance.showNotification(title, body);
```

### Push Notification (FCM)
- FCM token gửi lên server trong login request body
- Background message handling đã setup trong `FirebaseMessagingService`

---

## App Initialization Order

```dart
// main.dart — THỨ TỰ QUAN TRỌNG, KHÔNG ĐỔI
1. WidgetsFlutterBinding.ensureInitialized()
2. FlutterNativeSplash.preserve()
3. EasyLocalization.ensureInitialized()
4. Firebase.initializeApp()
5. FirebaseMessagingService.instance.init()
6. LocalNotificationService.instance.init()
7. BundleLoadService.instance.init()
8. RemoteConfigService().initialize()
9. Crashlytics setup
10. SystemChrome orientation & UI mode
11. runApp(MyApp())
```

- ❌ KHÔNG thay đổi thứ tự init
- ❌ KHÔNG thêm init step mà không đặt đúng vị trí (Firebase phải trước các Firebase services)

---

## Secure Storage

### Auth Token
```dart
// Lưu
await AppSecureStorage.saveAuthToken(token);

// Đọc
final token = await AppSecureStorage.getStoredAuthToken();

// Xóa (logout)
await AppSecureStorage.onLogOutClear();
```

### Profile
```dart
await AppSecureStorage.saveProfile(user);
final user = await AppSecureStorage.getStoredProfile();
```

---

## Anti-patterns CẤM

| # | Sai | Đúng |
|---|-----|------|
| 1 | Thêm web/desktop platform | Chỉ Android & iOS |
| 2 | Hardcode base URL | Dùng `Flavor.instance.baseUrl` |
| 3 | Enable Crashlytics ở dev | Chỉ `kReleaseMode && isProd` |
| 4 | Thay đổi init order | Giữ nguyên thứ tự `main.dart` |
| 5 | Lưu token bằng SharedPreferences | Dùng `AppSecureStorage` (flutter_secure_storage) |
| 6 | Dùng `String.fromEnvironment` trực tiếp | Dùng `Flavor.instance.xxx` |
| 7 | Import `dart:html` | App không support web |
