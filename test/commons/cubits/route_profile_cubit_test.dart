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
    try {
      return storage.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveTrip(TripRecordModel trip) async {
    storage.add(trip);
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

  final now = DateTime.now();

  final tripMotorcycle = TripRecordModel(
    id: 't_moto',
    startTime: now.subtract(const Duration(hours: 2)),
    endTime: now.subtract(const Duration(hours: 1, minutes: 30)),
    durationMs: 1800000, // 0.5h
    distanceMeters: 15000.0, // 15km
    avgSpeedKmh: 30.0,
    topSpeedKmh: 50.0,
    hasArrived: true,
    vehicleProfile: 'motorcycle',
    createdAt: now.subtract(const Duration(hours: 1, minutes: 30)),
  );

  final tripCar = TripRecordModel(
    id: 't_car',
    startTime: now.subtract(const Duration(hours: 4)),
    endTime: now.subtract(const Duration(hours: 3, minutes: 30)),
    durationMs: 1800000, // 0.5h
    distanceMeters: 30000.0, // 30km
    avgSpeedKmh: 60.0,
    topSpeedKmh: 90.0,
    hasArrived: true,
    vehicleProfile: 'car',
    createdAt: now.subtract(const Duration(hours: 3, minutes: 30)),
  );

  late MockTripRepository mockRepo;
  late RouteProfileCubit cubit;

  setUp(() {
    mockRepo = MockTripRepository();
    cubit = RouteProfileCubit(repository: mockRepo);
  });

  tearDown(() async {
    await cubit.close();
    await mockRepo.dispose();
  });

  group('RouteProfileCubit Statistics Calculation Tests', () {
    test('initial state has empty stats and initial status', () {
      expect(cubit.state.status, equals(RouteProfileStatus.initial));
      expect(cubit.state.stats, equals(const TripStatsModel.empty()));
      expect(cubit.state.hasStats, isFalse);
      expect(cubit.state.allTrips, isEmpty);
      expect(cubit.state.filteredTrips, isEmpty);
      expect(cubit.state.profileFilter, isNull);
      expect(cubit.state.timeRange, equals(StatsTimeRange.thisWeek));
      expect(cubit.state.chartData, equals(const TripChartData.empty()));
    });

    test('loadStats aggregates data correctly across all trips and generates chartData', () async {
      mockRepo.storage.addAll([tripMotorcycle, tripCar]);

      await cubit.loadStats();

      expect(cubit.state.status, equals(RouteProfileStatus.success));
      expect(cubit.state.hasStats, isTrue);
      expect(cubit.state.stats.totalTrips, equals(2));
      expect(cubit.state.stats.completedTrips, equals(2));
      expect(cubit.state.stats.totalDistanceKm, equals(45.0)); // 15 + 30
      expect(cubit.state.stats.totalDurationMinutes, equals(60.0)); // 30 + 30
      expect(cubit.state.stats.avgSpeedKmh, closeTo(45.0, 0.01)); // 45km / 1h
      expect(cubit.state.stats.topSpeedKmh, equals(90.0));
      expect(cubit.state.stats.tripsByProfile['motorcycle'], equals(1));
      expect(cubit.state.stats.tripsByProfile['car'], equals(1));
      expect(cubit.state.chartData.isNotEmpty, isTrue);
      expect(cubit.state.chartData.totalDistanceKm, equals(45.0));
    });

    test('setProfileFilter filters stats to selected vehicle profile', () async {
      mockRepo.storage.addAll([tripMotorcycle, tripCar]);
      await cubit.loadStats();

      // Lọc xe máy
      cubit.setProfileFilter('motorcycle');

      expect(cubit.state.profileFilter, equals('motorcycle'));
      expect(cubit.state.filteredTrips.length, equals(1));
      expect(cubit.state.stats.totalTrips, equals(1));
      expect(cubit.state.stats.totalDistanceKm, equals(15.0));
      expect(cubit.state.stats.avgSpeedKmh, closeTo(30.0, 0.01));
      expect(cubit.state.stats.topSpeedKmh, equals(50.0));
      expect(cubit.state.chartData.totalDistanceKm, equals(15.0));

      // Lọc ô tô
      cubit.setProfileFilter('car');

      expect(cubit.state.profileFilter, equals('car'));
      expect(cubit.state.filteredTrips.length, equals(1));
      expect(cubit.state.stats.totalDistanceKm, equals(30.0));
      expect(cubit.state.stats.avgSpeedKmh, closeTo(60.0, 0.01));
      expect(cubit.state.stats.topSpeedKmh, equals(90.0));

      // Bỏ lọc -> trở lại 2 trips
      cubit.setProfileFilter(null);
      expect(cubit.state.profileFilter, isNull);
      expect(cubit.state.filteredTrips.length, equals(2));
      expect(cubit.state.stats.totalDistanceKm, equals(45.0));
    });

    test('setTimeRange updates timeRange and re-aggregates stats and chartData', () async {
      mockRepo.storage.addAll([tripMotorcycle, tripCar]);
      await cubit.loadStats();

      cubit.setTimeRange(StatsTimeRange.today);
      expect(cubit.state.timeRange, equals(StatsTimeRange.today));
      expect(cubit.state.chartData.timeRange, equals(StatsTimeRange.today));

      cubit.setTimeRange(StatsTimeRange.allTime);
      expect(cubit.state.timeRange, equals(StatsTimeRange.allTime));
      expect(cubit.state.chartData.timeRange, equals(StatsTimeRange.allTime));
      expect(cubit.state.filteredTrips.length, equals(2));
    });

    test('deleteTrip removes single trip via repository', () async {
      mockRepo.storage.addAll([tripMotorcycle, tripCar]);
      await cubit.init(autoWatch: true);
      expect(cubit.state.stats.totalTrips, equals(2));

      await cubit.deleteTrip(tripMotorcycle.id);

      expect(cubit.state.stats.totalTrips, equals(1));
      expect(cubit.state.filteredTrips.first.id, equals('t_car'));
    });

    test('clearAllTrips removes all trips via repository', () async {
      mockRepo.storage.addAll([tripMotorcycle, tripCar]);
      await cubit.init(autoWatch: true);
      expect(cubit.state.stats.totalTrips, equals(2));

      await cubit.clearAllTrips();

      expect(cubit.state.stats.totalTrips, equals(0));
      expect(cubit.state.filteredTrips, isEmpty);
    });

    test('init() loads stats and synchronizes realtime on watch stream emissions', () async {
      mockRepo.storage.add(tripMotorcycle);

      await cubit.init(autoWatch: true);

      expect(cubit.state.stats.totalTrips, equals(1));
      expect(mockRepo.watchCallCount, equals(1));

      // Thêm tripCar vào storage và phát stream
      mockRepo.storage.add(tripCar);
      mockRepo.emitTrips(List.unmodifiable(mockRepo.storage));

      await cubit.stream.firstWhere((s) => s.stats.totalTrips == 2);
      expect(cubit.state.stats.totalTrips, equals(2));
      expect(cubit.state.stats.totalDistanceKm, equals(45.0));
    });

    test('loadStats with clearFilter=true removes existing profileFilter and calculates all trips', () async {
      mockRepo.storage.addAll([tripMotorcycle, tripCar]);
      await cubit.loadStats(profileFilter: 'motorcycle');
      expect(cubit.state.profileFilter, equals('motorcycle'));
      expect(cubit.state.stats.totalTrips, equals(1));

      await cubit.loadStats(clearFilter: true);
      expect(cubit.state.profileFilter, isNull);
      expect(cubit.state.stats.totalTrips, equals(2));
      expect(cubit.state.stats.totalDistanceKm, equals(45.0));
    });

    test('repository exception emits error status with message', () async {
      mockRepo.shouldThrow = true;

      await cubit.loadStats();
      expect(cubit.state.status, equals(RouteProfileStatus.error));
      expect(cubit.state.errorMessage, contains('Database read error'));
    });

    test('watch stream error emits error status', () async {
      await cubit.startWatching();
      final errorExpectation = expectLater(
        cubit.stream,
        emitsThrough(
          predicate<RouteProfileState>(
            (s) => s.status == RouteProfileStatus.error &&
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

      expect(cubit.state.status, equals(RouteProfileStatus.error));
      expect(cubit.state.errorMessage, contains('Synchronous watch initialization failed'));
    });

    test('loadStats race condition: slower previous loadStats does not overwrite newer state', () async {
      mockRepo.storage.addAll([tripMotorcycle, tripCar]);
      mockRepo.getTripsCompleter = Completer<void>();

      // Bắt đầu loadStats lần 1 (bị nghẽn bởi completer)
      final pendingLoad1 = cubit.loadStats(profileFilter: 'motorcycle');

      // Đổi filter sang 'car'
      cubit.setProfileFilter('car');
      expect(cubit.state.profileFilter, equals('car'));

      // Hoàn tất loadStats lần 1
      mockRepo.getTripsCompleter!.complete();
      await pendingLoad1;

      // Filter vẫn phải giữ nguyên là 'car', không bị lần 1 ghi đè thành 'motorcycle'
      expect(cubit.state.profileFilter, equals('car'));
    });
  });
}
