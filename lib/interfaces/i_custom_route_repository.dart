import 'package:s_map/models/models.dart';

/// Repository interface quản lý nghiệp vụ lộ trình tùy biến của người dùng
abstract class ICustomRouteRepository {
  /// Lấy toàn bộ danh sách lộ trình đã lưu
  Future<List<CustomRouteModel>> getSavedRoutes();

  /// Lấy chi tiết lộ trình theo [id]
  Future<CustomRouteModel?> getRouteById(String id);

  /// Lưu hoặc cập nhật một lộ trình
  Future<void> saveRoute(CustomRouteModel route);

  /// Xóa một lộ trình theo [id]
  Future<void> deleteRoute(String id);

  /// Xóa toàn bộ lộ trình đã lưu
  Future<void> clearAllRoutes();

  /// Stream theo dõi thay đổi danh sách lộ trình realtime
  Stream<List<CustomRouteModel>> watchSavedRoutes();
}
