import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';

class MockTripService implements ITripService {
  final List<TripRecordModel> storage = [];
  final StreamController<List<TripRecordModel>> _controller =
      StreamController<List<TripRecordModel>>.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<List<TripRecordModel>> getTrips() async => List.unmodifiable(storage);

  @override
  Future<TripRecordModel?> getTripById(String id) async =>
      storage.where((t) => t.id == id).firstOrNull;

  @override
  Future<void> saveTrip(TripRecordModel trip) async {
    final index = storage.indexWhere((t) => t.id == trip.id);
    if (index >= 0) {
      storage[index] = trip;
    } else {
      storage.add(trip);
    }
    _controller.add(List.unmodifiable(storage));
  }

  @override
  Future<void> deleteTrip(String id) async {
    storage.removeWhere((t) => t.id == id);
    _controller.add(List.unmodifiable(storage));
  }

  @override
  Future<void> clearAllTrips() async {
    storage.clear();
    _controller.add(List.unmodifiable(storage));
  }

  @override
  Stream<List<TripRecordModel>> watchTrips() => _controller.stream;

  Future<void> dispose() async => await _controller.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockTripService mockService;
  late TripRepositoryImpl repository;

  final sampleTrip = TripRecordModel(
    id: 'repo_trip_1',
    startTime: DateTime(2026, 8, 22, 9, 0),
    endTime: DateTime(2026, 8, 22, 9, 30),
    durationMs: 1800000,
    distanceMeters: 12000.0,
    avgSpeedKmh: 24.0,
    topSpeedKmh: 45.0,
    hasArrived: true,
    vehicleProfile: 'motorcycle',
    createdAt: DateTime(2026, 8, 22, 9, 30),
  );

  setUp(() {
    mockService = MockTripService();
    repository = TripRepositoryImpl(tripService: mockService);
  });

  tearDown(() async {
    await mockService.dispose();
  });

  group('TripRepositoryImpl Tests', () {
    test('getTrips, saveTrip, getTripById, deleteTrip, clearAllTrips delegation', () async {
      expect(await repository.getTrips(), isEmpty);

      await repository.saveTrip(sampleTrip);
      final list = await repository.getTrips();
      expect(list.length, equals(1));
      expect(list.first.id, equals('repo_trip_1'));

      final retrieved = await repository.getTripById('repo_trip_1');
      expect(retrieved, equals(sampleTrip));

      await repository.deleteTrip('repo_trip_1');
      expect(await repository.getTrips(), isEmpty);

      await repository.saveTrip(sampleTrip);
      await repository.clearAllTrips();
      expect(await repository.getTrips(), isEmpty);
    });

    test('watchTrips emits stream from service', () async {
      final expectation = expectLater(
        repository.watchTrips(),
        emitsInOrder([
          hasLength(1),
          isEmpty,
        ]),
      );

      await repository.saveTrip(sampleTrip);
      await repository.clearAllTrips();
      await expectation;
    });
  });

  group('NoOpTripRepository Fallback Tests', () {
    const noOpRepo = NoOpTripRepository();

    test('returns safe defaults without error', () async {
      expect(await noOpRepo.getTrips(), isEmpty);
      expect(await noOpRepo.getTripById('any_id'), isNull);
      await noOpRepo.saveTrip(sampleTrip);
      await noOpRepo.deleteTrip('any_id');
      await noOpRepo.clearAllTrips();

      final stream = noOpRepo.watchTrips();
      await expectLater(stream, emits(isEmpty));
    });
  });
}
