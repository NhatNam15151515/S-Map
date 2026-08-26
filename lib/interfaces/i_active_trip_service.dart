import 'package:s_map/models/models.dart';

/// Interface quản lý lưu trữ và khôi phục trạng thái chuyến đi đang hoạt động (Active Navigation Session)
abstract class IActiveTripService {
  /// Khởi tạo và nạp Box lưu trữ phiên chuyến đi
  Future<void> init();

  /// Lưu trạng thái snapshot của chuyến đi hiện tại vào bộ nhớ cục bộ (Hive)
  Future<void> saveActiveSession(ActiveTripSnapshot snapshot);

  /// Lấy snapshot phiên chuyến đi còn lưu lại (nếu có và còn hợp lệ)
  Future<ActiveTripSnapshot?> getActiveSession();

  /// Xóa sạch phiên chuyến đi lưu tạm khi hoàn thành hoặc hủy bỏ
  Future<void> clearActiveSession();

  /// Kiểm tra nhanh xem có session chuyến đi đang lưu hay không
  Future<bool> hasActiveSession();
}
