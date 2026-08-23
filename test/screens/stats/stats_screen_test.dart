import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/stats/stats_screen.dart';

class MockTripRepository implements ITripRepository {
  final List<TripRecordModel> storage = [];
  final StreamController<List<TripRecordModel>> _controller =
      StreamController<List<TripRecordModel>>.broadcast();

  @override
  Future<List<TripRecordModel>> getTrips() async {
    return List.unmodifiable(storage);
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
    return _controller.stream;
  }

  Future<void> dispose() async => await _controller.close();
}

void main() {
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

  Widget buildTestableWidget() {
    return MaterialApp(
      home: StatsScreen(cubit: cubit),
    );
  }

  group('StatsScreen Integration Tests', () {
    testWidgets('renders all main sections of the stats dashboard', (tester) async {
      final now = DateTime.now();
      final sampleTrip = TripRecordModel(
        id: 'stats_screen_trip_1',
        startTime: now.subtract(const Duration(minutes: 40)),
        endTime: now,
        durationMs: 2400000,
        distanceMeters: 14000,
        avgSpeedKmh: 21.0,
        topSpeedKmh: 45.0,
        hasArrived: true,
        originName: 'Nhà A',
        destinationName: 'Địa điểm B',
        vehicleProfile: 'motorcycle',
        createdAt: now,
      );

      mockRepo.storage.add(sampleTrip);
      await cubit.init(autoWatch: true);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stats_clear_all_btn')), findsOneWidget);
      expect(find.byKey(const Key('stats_range_thisWeek')), findsOneWidget);
      expect(find.byKey(const Key('stats_profile_all')), findsOneWidget);
      expect(find.byKey(const Key('kpi_card_distance')), findsOneWidget);
      expect(find.byKey(const Key('trip_item_stats_screen_trip_1')), findsOneWidget);
      expect(find.text('Địa điểm B'), findsOneWidget);
    });

    testWidgets('clearing all trips updates UI to empty state', (tester) async {
      final now = DateTime.now();
      final sampleTrip = TripRecordModel(
        id: 'stats_screen_trip_1',
        startTime: now.subtract(const Duration(minutes: 40)),
        endTime: now,
        durationMs: 2400000,
        distanceMeters: 14000,
        avgSpeedKmh: 21.0,
        topSpeedKmh: 45.0,
        hasArrived: true,
        originName: 'Nhà A',
        destinationName: 'Địa điểm B',
        vehicleProfile: 'motorcycle',
        createdAt: now,
      );

      mockRepo.storage.add(sampleTrip);
      await cubit.init(autoWatch: true);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('Địa điểm B'), findsOneWidget);

      // Tap clear all
      await tester.tap(find.byKey(const Key('stats_clear_all_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('confirm_clear_all_btn')), findsOneWidget);

      // Confirm clear
      await tester.tap(find.byKey(const Key('confirm_clear_all_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Địa điểm B'), findsNothing);
      expect(find.byIcon(Icons.explore_off_rounded), findsOneWidget);
    });
  });
}
