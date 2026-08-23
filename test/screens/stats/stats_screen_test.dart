import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
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
  Future<void> markTripAsSynced(String id) async {
    final index = storage.indexWhere((t) => t.id == id);
    if (index != -1) {
      storage[index] = storage[index].copyWith(isSynced: true);
      _controller.add(List.unmodifiable(storage));
    }
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
    return EasyLocalization(
      supportedLocales: const [Locale('vi'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('vi'),
      startLocale: const Locale('vi'),
      assetLoader: const CodegenLoader(),
      child: Builder(
        builder: (context) {
          return MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: StatsScreen(cubit: cubit),
          );
        },
      ),
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
      await cubit.init(autoWatch: true, initialTimeRange: StatsTimeRange.allTime);

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
      await cubit.init(autoWatch: true, initialTimeRange: StatsTimeRange.allTime);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('trip_item_stats_screen_trip_1')), findsOneWidget);

      // Tap clear all -> opens dialog -> confirm
      await tester.tap(find.byKey(const Key('stats_clear_all_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('confirm_clear_all_btn')), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm_clear_all_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('trip_item_stats_screen_trip_1')), findsNothing);
      expect(find.byKey(const Key('stats_trip_history_empty')), findsOneWidget);
    });
  });
}
