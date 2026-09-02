import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/sync_repository.dart';

class MockTripSyncService implements ITripSyncService {
  final List<String> queuedIds = [];
  final StreamController<int> _controller = StreamController<int>.broadcast();
  bool shouldThrow = false;

  @override
  Future<void> init() async {}

  @override
  Future<void> enqueueTrip(String tripId) async {
    if (shouldThrow) throw Exception('SyncService enqueue error');
    if (!queuedIds.contains(tripId)) {
      queuedIds.add(tripId);
      _controller.add(queuedIds.length);
    }
  }

  @override
  Future<List<String>> getQueuedTripIds() async {
    if (shouldThrow) throw Exception('SyncService getQueuedTripIds error');
    return List.from(queuedIds);
  }

  @override
  Future<void> removeQueuedTrip(String tripId) async {
    if (shouldThrow) throw Exception('SyncService removeQueuedTrip error');
    queuedIds.remove(tripId);
    _controller.add(queuedIds.length);
  }

  @override
  Future<void> clearQueue() async {
    if (shouldThrow) throw Exception('SyncService clearQueue error');
    queuedIds.clear();
    _controller.add(0);
  }

  @override
  Future<int> getQueueCount() async => queuedIds.length;

  @override
  Stream<int> watchQueueCount() => _controller.stream;
}

class MockTripRepository implements ITripRepository {
  final Map<String, TripRecordModel> trips = {};
  final List<String> markedSyncedIds = [];

  @override
  Future<List<TripRecordModel>> getTrips() async => trips.values.toList();

  @override
  Future<TripRecordModel?> getTripById(String id) async => trips[id];

  @override
  Future<void> saveTrip(TripRecordModel trip) async {
    trips[trip.id] = trip;
  }

  @override
  Future<void> deleteTrip(String id) async {
    trips.remove(id);
  }

  @override
  Future<void> clearAllTrips() async {
    trips.clear();
  }

  @override
  Future<void> markTripAsSynced(String id) async {
    markedSyncedIds.add(id);
    if (trips.containsKey(id)) {
      trips[id] = trips[id]!.copyWith(isSynced: true);
    }
  }

  @override
  Stream<List<TripRecordModel>> watchTrips() => Stream.value(trips.values.toList());
}

class MockFireStoreService implements IFireStoreService {
  final List<TripRecordModel> syncedTrips = [];
  final List<TripRecordModel> dailyStatsUpdated = [];
  bool shouldThrow = false;

  @override
  CollectionReference? get usersCollection => null;
  @override
  CollectionReference? get notificationsCollection => null;
  @override
  CollectionReference? get savedPlacesCollection => null;
  @override
  CollectionReference? get placesCollection => null;
  @override
  CollectionReference? get routesCollection => null;

  @override
  Future<void> saveUserProfile(User user) async {}
  @override
  Future<User?> getUserProfile(String userId) async => null;
  @override
  Future<List<NotificationModel>> getNotifications({int limit = 20}) async => [];
  @override
  Future<List<PlaceModel>> getExplorePlaces({String? category, int limit = 10}) async => [];
  @override
  Stream<List<PlaceModel>> streamExplorePlaces({String? category, int limit = 10}) =>
      Stream.value([]);
  @override
  Future<void> savePlace(String userId, Map<String, dynamic> placeData) async {}
  @override
  Stream<QuerySnapshot?> streamSavedPlaces(String userId) => Stream.value(null);

  @override
  Future<List<Map<String, dynamic>>> getSavedPlaces(String userId) async => [];

  @override
  Future<void> deleteSavedPlace(String userId, String poiKey) async {}

  @override
  Future<void> clearSavedPlaces(String userId) async {}

  @override
  Future<void> saveSearchQuery(String userId, String query) async {}

  @override
  Future<List<String>> getSearchQueries(String userId, {int limit = 20}) async => [];

  @override
  Future<void> deleteSearchQuery(String userId, String query) async {}

  @override
  Future<void> clearSearchQueries(String userId) async {}

  @override
  Future<void> saveVisitedPlace(
      String userId, Map<String, dynamic> placeData) async {}

  @override
  Future<List<Map<String, dynamic>>> getVisitedPlaces(String userId) async => [];

  @override
  Future<void> clearVisitedPlaces(String userId) async {}

  @override
  Future<void> saveCustomRoute(
      String userId, Map<String, dynamic> routeData) async {}

  @override
  Future<List<Map<String, dynamic>>> getCustomRoutes(String userId) async => [];

  @override
  Future<void> deleteCustomRoute(String userId, String routeId) async {}

  @override
  Future<void> clearCustomRoutes(String userId) async {}

  @override
  Future<void> syncTrip(String userId, TripRecordModel trip) async {
    if (shouldThrow) throw Exception('Firestore syncTrip error');
    syncedTrips.add(trip);
  }

  @override
  Future<void> syncTripsBatch(String userId, List<TripRecordModel> trips) async {
    if (shouldThrow) throw Exception('Firestore syncTripsBatch error');
    syncedTrips.addAll(trips);
  }

  @override
  Future<void> updateDailyStats(String userId, DateTime date, TripRecordModel trip) async {
    if (shouldThrow) throw Exception('Firestore updateDailyStats error');
    dailyStatsUpdated.add(trip);
  }

  @override
  Future<List<TripRecordModel>> getSyncedTrips(String userId) async => syncedTrips;
}

void main() {
  late MockTripSyncService mockSyncService;
  late MockTripRepository mockTripRepo;
  late MockFireStoreService mockFirestoreService;
  late SyncRepositoryImpl syncRepo;

  setUp(() {
    mockSyncService = MockTripSyncService();
    mockTripRepo = MockTripRepository();
    mockFirestoreService = MockFireStoreService();

    syncRepo = SyncRepositoryImpl(
      syncService: mockSyncService,
      tripRepository: mockTripRepo,
      fireStoreService: mockFirestoreService,
    );
  });

  TripRecordModel createSampleTrip(String id) {
    return TripRecordModel(
      id: id,
      startTime: DateTime(2026, 8, 23, 10, 0),
      endTime: DateTime(2026, 8, 23, 10, 30),
      durationMs: 1800000,
      distanceMeters: 5000.0,
      avgSpeedKmh: 25.0,
      topSpeedKmh: 45.0,
      destinationName: 'Destination $id',
      originName: 'Origin $id',
      hasArrived: true,
      vehicleProfile: 'motorcycle',
      createdAt: DateTime(2026, 8, 23, 10, 30),
    );
  }

  group('SyncRepositoryImpl Tests', () {
    test('syncPendingTrips returns empty when no trips are queued', () async {
      final result = await syncRepo.syncPendingTrips('user_123');
      expect(result, isEmpty);
      expect(mockFirestoreService.syncedTrips, isEmpty);
    });

    test('syncPendingTrips syncs multiple offline trips, marks them synced and removes from queue', () async {
      final trip1 = createSampleTrip('trip_1');
      final trip2 = createSampleTrip('trip_2');
      final trip3 = createSampleTrip('trip_3');

      await mockTripRepo.saveTrip(trip1);
      await mockTripRepo.saveTrip(trip2);
      await mockTripRepo.saveTrip(trip3);

      await mockSyncService.enqueueTrip('trip_1');
      await mockSyncService.enqueueTrip('trip_2');
      await mockSyncService.enqueueTrip('trip_3');

      expect(await syncRepo.getPendingSyncCount(), 3);

      final syncedIds = await syncRepo.syncPendingTrips('user_123');

      expect(syncedIds, ['trip_1', 'trip_2', 'trip_3']);
      expect(mockFirestoreService.syncedTrips.length, 3);
      expect(mockTripRepo.markedSyncedIds, containsAll(['trip_1', 'trip_2', 'trip_3']));
      expect(await syncRepo.getPendingSyncCount(), 0);
    });

    test('syncPendingTrips cleans up deleted local trips from queue', () async {
      await mockSyncService.enqueueTrip('non_existent_trip');
      expect(await syncRepo.getPendingSyncCount(), 1);

      final syncedIds = await syncRepo.syncPendingTrips('user_123');
      expect(syncedIds, isEmpty);
      expect(await syncRepo.getPendingSyncCount(), 0);
    });

    test('syncPendingTrips propagates firestore exception without clearing queue', () async {
      final trip1 = createSampleTrip('trip_1');
      await mockTripRepo.saveTrip(trip1);
      await mockSyncService.enqueueTrip('trip_1');

      mockFirestoreService.shouldThrow = true;

      await expectLater(
        syncRepo.syncPendingTrips('user_123'),
        throwsA(isA<Exception>()),
      );
      // Queue is kept intact for retry
      expect(await syncRepo.getPendingSyncCount(), 1);
    });

    test('watchPendingSyncCount emits changes', () async {
      final emissions = <int>[];
      final sub = syncRepo.watchPendingSyncCount().listen(emissions.add);

      await syncRepo.enqueueTripForSync('trip_A');
      await syncRepo.enqueueTripForSync('trip_B');
      await Future.delayed(const Duration(milliseconds: 10));

      await sub.cancel();
      expect(emissions, containsAllInOrder([1, 2]));
    });
  });
}
