abstract class ISyncRepository {
  /// Thực hiện đồng bộ tất cả chuyến đi đang chờ trong offline queue lên Firestore
  Future<List<String>> syncPendingTrips(String userId);

  /// Đưa chuyến đi vào hàng đợi đồng bộ
  Future<void> enqueueTripForSync(String tripId);

  /// Lấy số lượng chuyến đi đang chờ đồng bộ
  Future<int> getPendingSyncCount();

  /// Theo dõi số lượng chuyến đi đang chờ đồng bộ realtime
  Stream<int> watchPendingSyncCount();
}
