import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/services/services.dart';
import 'trip_repository.dart';

class SyncRepositoryImpl implements ISyncRepository {
  final ITripSyncService _syncService;
  final ITripRepository _tripRepository;
  final IFireStoreService _fireStoreService;

  SyncRepositoryImpl({
    ITripSyncService? syncService,
    ITripRepository? tripRepository,
    IFireStoreService? fireStoreService,
  })  : _syncService = syncService ?? TripSyncServiceImpl.instance,
        _tripRepository = tripRepository ?? TripRepositoryImpl(tripService: TripServiceImpl.instance),
        _fireStoreService = fireStoreService ?? FireStoreService.instance;

  @override
  Future<List<String>> syncPendingTrips(String userId) async {
    final queuedIds = await _syncService.getQueuedTripIds();
    if (queuedIds.isEmpty) return [];

    final List<TripRecordModel> tripsToSync = [];
    for (final id in queuedIds) {
      final trip = await _tripRepository.getTripById(id);
      if (trip != null) {
        tripsToSync.add(trip);
      } else {
        // Bản ghi không còn tồn tại trong local storage, loại bỏ khỏi queue
        await _syncService.removeQueuedTrip(id);
      }
    }

    if (tripsToSync.isEmpty) return [];

    try {
      // 1. Ghi toàn bộ chuyến đi và cập nhật daily stats lên Cloud Firestore
      await _fireStoreService.syncTripsBatch(userId, tripsToSync);

      // 2. Đánh dấu isSynced = true cục bộ và xóa khỏi hàng đợi offline
      final List<String> syncedIds = [];
      for (final trip in tripsToSync) {
        await _tripRepository.markTripAsSynced(trip.id);
        await _syncService.removeQueuedTrip(trip.id);
        syncedIds.add(trip.id);
      }

      DLog.info('✅ [SyncRepository] Đã đồng bộ thành công ${syncedIds.length} chuyến đi lên Firestore');
      return syncedIds;
    } catch (e) {
      DLog.error('❌ [SyncRepository] Lỗi đồng bộ chuyến đi lên Firestore: $e');
      rethrow;
    }
  }

  @override
  Future<void> enqueueTripForSync(String tripId) => _syncService.enqueueTrip(tripId);

  @override
  Future<int> getPendingSyncCount() => _syncService.getQueueCount();

  @override
  Stream<int> watchPendingSyncCount() => _syncService.watchQueueCount();
}

/// Fallback implementation cho môi trường Testing hoặc khi chưa khởi tạo storage
class NoOpSyncRepository implements ISyncRepository {
  const NoOpSyncRepository();

  @override
  Future<List<String>> syncPendingTrips(String userId) async => const [];

  @override
  Future<void> enqueueTripForSync(String tripId) async {}

  @override
  Future<int> getPendingSyncCount() async => 0;

  @override
  Stream<int> watchPendingSyncCount() => Stream.value(0);
}
