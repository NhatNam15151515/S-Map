import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class MockTripRepository implements ITripRepository {
  final List<TripRecordModel> storage = [];
  final StreamController<List<TripRecordModel>> _controller =
      StreamController<List<TripRecordModel>>.broadcast();
  bool shouldThrow = false;
  bool throwOnWatch = false;
  Completer<void>? getTripsCompleter;
  int watchCallCount = 0;

  @override
  Future<List<TripRecordModel>> getTrips() async {
    final snapshot = List<TripRecordModel>.unmodifiable(storage);
    if (getTripsCompleter != null) {
      await getTripsCompleter!.future;
    }
    if (shouldThrow) throw Exception('Database read error');
    return snapshot;
  }

  @override
  Future<TripRecordModel?> getTripById(String id) async {
    if (shouldThrow) throw Exception('Database read error');
    try {
      return storage.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveTrip(TripRecordModel trip) async {
    if (shouldThrow) throw Exception('Database write error');
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
    if (shouldThrow) throw Exception('Database delete error');
    storage.removeWhere((t) => t.id == id);
    _controller.add(List.unmodifiable(storage));
  }

  @override
  Future<void> clearAllTrips() async {
    if (shouldThrow) throw Exception('Database clear error');
    storage.clear();
    _controller.add(List.unmodifiable(storage));
  }

  @override
  Stream<List<TripRecordModel>> watchTrips() {
    watchCallCount++;
    if (throwOnWatch) throw Exception('Synchronous watch initialization failed');
    return _controller.stream;
  }

  void emitTrips(List<TripRecordModel> trips) {
    _controller.add(trips);
  }

  void emitError(Object error) {
    _controller.addError(error);
  }

  Future<void> dispose() async => await _controller.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleTrip1 = TripRecordModel(
    id: 'th_1',
    startTime: DateTime(2026, 8, 22, 8, 0),
    endTime: DateTime(2026, 8, 22, 8, 30),
    durationMs: 1800000,
    distanceMeters: 10000.0,
    avgSpeedKmh: 20.0,
    topSpeedKmh: 40.0,
    hasArrived: true,
    vehicleProfile: 'motorcycle',
    createdAt: DateTime(2026, 8, 22, 8, 30),
  );

  final sampleTrip2 = TripRecordModel(
    id: 'th_2',
    startTime: DateTime(2026, 8, 22, 10, 0),
    endTime: DateTime(2026, 8, 22, 10, 45),
    durationMs: 2700000,
    distanceMeters: 25000.0,
    avgSpeedKmh: 33.3,
    topSpeedKmh: 65.0,
    hasArrived: true,
    vehicleProfile: 'car',
    createdAt: DateTime(2026, 8, 22, 10, 45),
  );

  late MockTripRepository mockRepo;
  late TripHistoryCubit cubit;

  setUp(() {
    mockRepo = MockTripRepository();
    cubit = TripHistoryCubit(repository: mockRepo);
  });

  tearDown(() async {
    await cubit.close();
    await mockRepo.dispose();
  });

  group('TripHistoryCubit State Management Tests', () {
    test('initial state has empty trips and initial status', () {
      expect(cubit.state.status, equals(TripHistoryStatus.initial));
      expect(cubit.state.trips, isEmpty);
      expect(cubit.state.isEmpty, isTrue);
      expect(cubit.state.hasTrips, isFalse);
      expect(cubit.state.tripCount, equals(0));
    });

    test('loadTrips successfully emits loading then success state', () async {
      mockRepo.storage.addAll([sampleTrip1, sampleTrip2]);

      final expectation = expectLater(
        cubit.stream,
        emitsInOrder([
          predicate<TripHistoryState>((s) => s.status == TripHistoryStatus.loading),
          predicate<TripHistoryState>((s) =>
              s.status == TripHistoryStatus.success &&
              s.trips.length == 2 &&
              s.hasTrips &&
              s.tripCount == 2),
        ]),
      );

      await cubit.loadTrips();
      await expectation;
    });

    test('init() loads trips and starts watching automatically', () async {
      mockRepo.storage.add(sampleTrip1);

      await cubit.init(autoWatch: true);

      expect(cubit.state.status, equals(TripHistoryStatus.success));
      expect(cubit.state.trips.length, equals(1));
      expect(mockRepo.watchCallCount, equals(1));

      // Thêm trip mới -> cubit cập nhật qua watch stream
      mockRepo.storage.add(sampleTrip2);
      mockRepo.emitTrips(List.unmodifiable(mockRepo.storage));

      await cubit.stream.firstWhere((s) => s.trips.length == 2);
      expect(cubit.state.trips.length, equals(2));
    });

    test('deleteTrip removes single trip and updates state', () async {
      mockRepo.storage.addAll([sampleTrip1, sampleTrip2]);
      await cubit.loadTrips();
      expect(cubit.state.trips.length, equals(2));

      await cubit.deleteTrip('th_1');
      expect(cubit.state.trips.length, equals(1));
      expect(cubit.state.trips.first.id, equals('th_2'));
    });

    test('clearAllTrips empties list and updates state', () async {
      mockRepo.storage.addAll([sampleTrip1, sampleTrip2]);
      await cubit.loadTrips();

      await cubit.clearAllTrips();
      expect(cubit.state.trips, isEmpty);
      expect(cubit.state.isEmpty, isTrue);
    });

    test('repository exception emits error status with message', () async {
      mockRepo.shouldThrow = true;

      await cubit.loadTrips();
      expect(cubit.state.status, equals(TripHistoryStatus.error));
      expect(cubit.state.errorMessage, contains('Database read error'));
    });

    test('watch stream error emits error status', () async {
      await cubit.startWatching();
      final errorExpectation = expectLater(
        cubit.stream,
        emitsThrough(
          predicate<TripHistoryState>(
            (s) => s.status == TripHistoryStatus.error &&
                s.errorMessage == 'Exception: Stream failure',
          ),
        ),
      );

      mockRepo.emitError(Exception('Stream failure'));
      await errorExpectation;
    });

    test('synchronous watch exception emits error status', () async {
      mockRepo.throwOnWatch = true;

      await cubit.startWatching();

      expect(cubit.state.status, equals(TripHistoryStatus.error));
      expect(cubit.state.errorMessage, contains('Synchronous watch initialization failed'));
    });

    test('closing cubit while loadTrips is pending prevents starting watch stream', () async {
      mockRepo.getTripsCompleter = Completer<void>();

      final pendingInit = cubit.init(autoWatch: true);
      // Đóng cubit trước khi getTrips hoàn tất
      await cubit.close();

      // Giải phóng thao tác getTrips
      mockRepo.getTripsCompleter!.complete();
      await pendingInit;

      expect(mockRepo.watchCallCount, equals(0));
    });

    test('loadTrips race condition: slower previous loadTrips does not overwrite newer state from clearAllTrips', () async {
      mockRepo.storage.addAll([sampleTrip1, sampleTrip2]);
      mockRepo.getTripsCompleter = Completer<void>();

      // Bắt đầu loadTrips lần 1 (bị nghẽn bởi completer)
      final pendingLoad = cubit.loadTrips();

      // Clear all trips
      await cubit.clearAllTrips();
      expect(cubit.state.trips, isEmpty);

      // Giải phóng getTrips lần 1
      mockRepo.getTripsCompleter!.complete();
      await pendingLoad;

      // Danh sách trips vẫn phải rỗng, không bị ghi đè bởi loadTrips cũ
      expect(cubit.state.trips, isEmpty);
    });
  });
}
