---
name: routing
description: |
  Quy tắc và pattern cho GoRouter navigation trong dự án S-Map Flutter.
  Bao gồm route registration, bottom tab navigation, auth redirect, deep linking,
  overlay dialogs, và StatefulShellRoute pattern.
  Trigger khi: tạo screen mới, thêm bottom tab, cấu hình deep link,
  xử lý auth redirect, hiển thị dialog/overlay.
---

# Routing Skill — S-Map

## Tổng quan

- **Library**: `go_router` (v14.2.0+)
- **Pattern**: Singleton `Routes.instance` quản lý toàn bộ navigation
- **Root navigator key**: `Routes.instance.rootNavigatorKey`
- **Access context**: `Routes.instance.context`

---

## Thêm Screen Mới

### Bước 1: Tạo screen với static path
```dart
// File: lib/screens/<feature>/<feature>_screen.dart
class MyScreen extends StatefulWidget {
  static const String path = '/my-screen'; // ← BẮT BUỘC

  const MyScreen({super.key});

  @override
  State<MyScreen> createState() => _MyScreenState();
}
```

### Bước 2: Đăng ký route
```dart
// File: lib/routers/routers.dart — trong Routes constructor
routes: <RouteBase>[
  // ... existing routes
  GoRoute(
    path: MyScreen.path,
    builder: (context, state) => const MyScreen(),
  ),
],
```

### Bước 3 (Nếu screen cần params)
```dart
// Route registration
GoRoute(
  path: '${MyScreen.path}/:id',
  builder: (context, state) => MyScreen(
    id: state.pathParameters['id']!,
  ),
),

// Navigation
context.push('${MyScreen.path}/123');
```

### Bước 3b (Nếu screen cần extra object)
```dart
// Route registration
GoRoute(
  path: MyScreen.path,
  builder: (context, state) => MyScreen(
    data: state.extra as MyModel,
  ),
),

// Navigation
context.push(MyScreen.path, extra: myModelInstance);
```

---

## Navigation Methods

### Replace (auth, tab switch)
```dart
context.go(HomeScreen.path); // Replace toàn bộ stack
```

### Stack Push
```dart
context.push(DetailScreen.path); // Push lên stack
context.push(DetailScreen.path, extra: data); // Push với data
```

### Pop
```dart
context.pop(); // Pop 1 level
```

### Pop Until
```dart
Routes.instance.popUntil(HomeScreen.path); // Pop đến route cụ thể
Routes.instance.popUntilFirst(); // Pop đến root
```

---

## Bottom Tab Navigation

Đã setup sẵn với `StatefulShellRoute.indexedStack`:

```dart
StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) {
    return MainScreen(navigationShell);
  },
  branches: [
    // Tab 0: Home
    StatefulShellBranch(routes: [
      GoRoute(path: HomeScreen.path, builder: ...),
    ]),
    // Tab 1: Cart
    StatefulShellBranch(routes: [
      GoRoute(path: CartScreen.path, builder: ...),
    ]),
    // Tab 2: Notification
    StatefulShellBranch(routes: [
      GoRoute(path: NotificationScreen.path, builder: ...),
    ]),
    // Tab 3: User
    StatefulShellBranch(routes: [
      GoRoute(path: UserScreen.path, builder: ...),
    ]),
  ],
),
```

### Thêm tab mới
1. Tạo screen mới trong `screens/main/<feature>/`
2. Thêm `StatefulShellBranch` mới trong `branches` list
3. Cập nhật `MainScreen` bottom bar (widget `main_bottom_bar.dart`)

---

## Auth Redirect Flow

Auth redirect được xử lý tự động qua `applyWithAuthState()`:

```dart
void applyWithAuthState(AuthCubit authCubit) {
  authCubit.stream.listen((event) async {
    await routeMounted.future; // Đợi router mount xong
    switch (event.type) {
      case AuthStateType.unAuthenticated:
        context.go(LoginScreen.path); // → Login
        break;
      case AuthStateType.authenticated:
        context.go(HomeScreen.path);  // → Home
        break;
    }
  });
}
```

- ❌ KHÔNG tự redirect trong screen code — để `AuthCubit` + `Routes` xử lý

---

## Overlay Dialogs

### Loading overlay
```dart
// Hiển thị loading
final overlay = Routes.instance.showLoadingOverlay();

// Ẩn loading
overlay.remove();

// Hoặc dùng helper (auto remove khi future complete)
await Routes.instance.showLoadingDepend(myFuture);
```

### App dialogs (maintenance, update)
```dart
// Đã setup sẵn, gọi sau auth:
await Routes.instance.showMaintenanceAppDialog();
Routes.instance.showUpdateAppDialog();
```

---

## Anti-patterns CẤM

| # | Sai | Đúng |
|---|-----|------|
| 1 | `Navigator.push(context, MaterialPageRoute(...))` | `context.push(MyScreen.path)` |
| 2 | `Navigator.of(context).pop()` | `context.pop()` |
| 3 | Không khai báo `static const path` | Mỗi screen PHẢI có |
| 4 | Tạo nested Navigator cho tab | Dùng `StatefulShellBranch` |
| 5 | Hardcode path string `/my-screen` ở nhiều chỗ | Dùng `MyScreen.path` |
| 6 | Redirect auth trong screen code | Để `applyWithAuthState()` xử lý |
| 7 | Navigate trước khi router mount | Dùng `routeMounted.future` guard |
