import 'package:s_map/interfaces/interfaces.dart';

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
