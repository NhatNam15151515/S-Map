---
name: api-architecture
description: |
  Quy tắc và pattern cho API networking trong dự án S-Map Flutter.
  Bao gồm BaseAPIClient, Repository pattern, Dio interceptors, ErrorResponse,
  APIRoute/APIType, và cách đăng ký endpoint mới.
  Trigger khi: tạo API endpoint mới, tạo repository mới, xử lý error handling,
  cần caching, thêm interceptor.
---

# API Architecture Skill — S-Map

## Tổng quan kiến trúc API

```
Feature Code
    ↓ gọi
Repository (abstract → impl)
    ↓ gọi
BaseAPIClient.request<T>()
    ↓ qua
Dio + Interceptor Chain
    ↓
Server
```

### 3 API Client đã setup sẵn trong `AppCubit`

| Client | Mục đích | Interceptors |
|--------|----------|-------------|
| `apiClient` | API call thông thường | Auth → Log → Error |
| `cacheAPIClient` | API có Hive cache | HiveCache → Log → Error |
| `fireStoreCacheAPIClient` | API cache qua Firestore | FirestoreCache → Log → Error |

---

## Thêm API Endpoint Mới

### Bước 1: Thêm `APIType` enum value
```dart
// File: lib/services/api_service/api_routes/api_routes.dart
enum APIType {
  // ... existing types
  myNewEndpoint, // ← Thêm ở đây
}
```

### Bước 2: Config route trong `APIRoute`
```dart
// Trong cùng file, thêm case
case APIType.myNewEndpoint:
  return RequestOptions(
    path: '/api/v1/my-endpoint',
    method: 'GET', // hoặc POST, PUT, DELETE
  );
```

### Bước 3: Tạo Repository

```dart
// File: lib/repos/my_repos.dart

// ✅ Abstract class định nghĩa interface
abstract class MyRepos {
  Future<MyModel?> getData(int id);
  Future<List<MyModel>?> getList({int page = 1});
  Future<MyModel?> create(Map<String, dynamic> body);
}

// ✅ Implementation inject BaseAPIClient
class MyReposImpl extends MyRepos {
  final BaseAPIClient apiClient;
  MyReposImpl(this.apiClient);

  @override
  Future<MyModel?> getData(int id) async {
    final response = await apiClient.request<APIResponse<MyModel>>(
      route: APIRoute(apiType: APIType.myGetData),
      extraPath: '/$id',
      create: (res) => APIResponse<MyModel>(
        response: res,
        decodedData: MyModel(),
      ),
    );
    return response.decodedData;
  }

  @override
  Future<List<MyModel>?> getList({int page = 1}) async {
    final response = await apiClient.request<APIResponse<List<MyModel>>>(
      route: APIRoute(apiType: APIType.myGetList),
      params: {'page': page},
      create: (res) => APIResponse<List<MyModel>>(
        response: res,
        decodedData: <MyModel>[],
      ),
    );
    return response.decodedData;
  }

  @override
  Future<MyModel?> create(Map<String, dynamic> body) async {
    final response = await apiClient.request<APIResponse<MyModel>>(
      route: APIRoute(apiType: APIType.myCreate),
      body: body,
      create: (res) => APIResponse<MyModel>(
        response: res,
        decodedData: MyModel(),
      ),
    );
    return response.decodedData;
  }
}
```

### Bước 4: Đăng ký trong `AppReposProvider`
```dart
// File: lib/commons/cubits/app_cubit/app_cubit.dart
class AppReposProvider {
  final BaseAPIClient apiClient;
  final BaseAPIClient cacheApiClient;
  final BaseAPIClient fireStoreCacheAPIClient;

  AppReposProvider(this.apiClient, this.cacheApiClient, this.fireStoreCacheAPIClient);

  // Existing repos
  AuthRepos get authRepos => AuthReposImpl(apiClient);
  NotificationRepos get notiRepos => NotificationReposImpl(apiClient);

  // ← Thêm repo mới ở đây
  MyRepos get myRepos => MyReposImpl(apiClient);
  // Nếu cần cache:
  MyRepos get myCachedRepos => MyReposImpl(cacheApiClient);
}
```

---

## Model Pattern

### Data Model chuẩn
```dart
// File: lib/models/my_model.dart
import 'package:boilerplate/services/api_service/decoder.dart';

class MyModel extends Decoder {
  String? id;
  String? name;
  DateTime? createdAt;

  MyModel({this.id, this.name, this.createdAt});

  @override
  void decode(dynamic json) {
    super.decode(json);
    id = json['id']?.toString();
    name = json['name']?.toString();
    createdAt = json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'].toString())
        : null;
  }
}
```

---

## Error Handling

### Trong Repository — không cần try-catch (GenericCubit lo)
```dart
// ✅ Repository chỉ throw, không catch
Future<MyModel?> getData() async {
  final response = await apiClient.request<APIResponse<MyModel>>(...);
  return response.decodedData;
  // ErrorResponse tự throw từ APIClient nếu lỗi
}
```

### Trong Cubit — đã có sẵn trong GenericCubit
```dart
// GenericCubit.getData() đã xử lý:
// - on ErrorResponse catch(e) → emit error state
// - catch(e) → emit error state với defaultError
```

### Nếu cần custom error handling
```dart
try {
  final result = await repos.getData();
  // handle success
} on ErrorResponse catch (e) {
  // ✅ Catch ErrorResponse, KHÔNG catch DioException
  DLog.error(e.statusMessage ?? 'Unknown error');
} catch (e) {
  DLog.error(e.toString());
}
```

---

## Caching

### Hive Cache (offline-first)
```dart
// Dùng cacheAPIClient thay vì apiClient
MyRepos get myCachedRepos => MyReposImpl(cacheApiClient);
```

### Firestore Cache (server-side cache)
```dart
// Dùng fireStoreCacheAPIClient
MyRepos get myFirestoreCachedRepos => MyReposImpl(fireStoreCacheAPIClient);
```

---

## Upload File (Multipart)

```dart
Future<MyModel?> uploadImage(File file) async {
  final formData = FormData.fromMap({
    'file': await MultipartFile.fromFile(file.path, filename: file.path.split('/').last),
  });

  final response = await apiClient.request<APIResponse<MyModel>>(
    route: APIRoute(apiType: APIType.uploadImage),
    formData: formData,
    create: (res) => APIResponse<MyModel>(
      response: res,
      decodedData: MyModel(),
    ),
  );
  return response.decodedData;
}
```

---

## Anti-patterns CẤM

| # | Sai | Đúng |
|---|-----|------|
| 1 | Tạo `Dio()` instance riêng | Dùng `BaseAPIClient.request()` |
| 2 | Hardcode `"https://api.example.com"` | Dùng `Flavor.instance.baseUrl` |
| 3 | Catch `DioException` trong feature | Catch `ErrorResponse` |
| 4 | Không tạo abstract class cho repos | Luôn abstract → impl |
| 5 | Gọi API trực tiếp trong widget | Gọi qua Cubit → Repos |
| 6 | Tạo model mà không extends `Decoder` | Extends `Decoder` để dùng `decode()` |
| 7 | Response type mismatch không handle | `APIClient` đã throw `ErrorResponse` cho case này |
