import 'package:s_map/models/models.dart';

/// Interface định nghĩa các thao tác lưu trữ cục bộ cho các chuyến đi (Trips)
abstract class ITripService {
  /// Khởi tạo và nạp storage box
  Future<void> init();

  /// Lấy toàn bộ danh sách chuyến đi đã lưu
  Future<List<TripRecordModel>> getTrips();

  /// Lấy chi tiết chuyến đi theo [id]
  Future<TripRecordModel?> getTripById(String id);

  /// Lưu một chuyến đi mới hoặc cập nhật
  Future<void> saveTrip(TripRecordModel trip);

  /// Xóa một chuyến đi theo [id]
  Future<void> deleteTrip(String id);

  /// Xóa toàn bộ lịch sử chuyến đi
  Future<void> clearAllTrips();

  /// Stream theo dõi thay đổi danh sách chuyến đi realtime
  Stream<List<TripRecordModel>> watchTrips();
}
