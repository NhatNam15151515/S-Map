import 'package:s_map/models/models.dart';

/// Interface cho Trip Repository cung cấp dữ liệu chuyến đi cho tầng Business Logic
abstract class ITripRepository {
  /// Lấy toàn bộ danh sách chuyến đi đã lưu
  Future<List<TripRecordModel>> getTrips();

  /// Lấy chi tiết một chuyến đi theo [id]
  Future<TripRecordModel?> getTripById(String id);

  /// Lưu hoặc cập nhật một chuyến đi
  Future<void> saveTrip(TripRecordModel trip);

  /// Xóa một chuyến đi theo [id]
  Future<void> deleteTrip(String id);

  /// Xóa toàn bộ lịch sử chuyến đi
  Future<void> clearAllTrips();

  /// Lắng nghe stream thay đổi của danh sách chuyến đi
  Stream<List<TripRecordModel>> watchTrips();
}
