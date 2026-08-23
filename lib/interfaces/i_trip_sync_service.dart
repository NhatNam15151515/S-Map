abstract class ITripSyncService {
  Future<void> init();
  Future<void> enqueueTrip(String tripId);
  Future<List<String>> getQueuedTripIds();
  Future<void> removeQueuedTrip(String tripId);
  Future<void> clearQueue();
  Future<int> getQueueCount();
  Stream<int> watchQueueCount();
}
