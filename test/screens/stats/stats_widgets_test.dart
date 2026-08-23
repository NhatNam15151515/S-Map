import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/stats/widgets/widgets.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('StatsTimeRangeSelector Tests', () {
    testWidgets('renders all 5 time ranges and handles selection callback', (tester) async {
      StatsTimeRange selected = StatsTimeRange.thisWeek;

      await tester.pumpWidget(buildTestableWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return StatsTimeRangeSelector(
              selectedRange: selected,
              onRangeSelected: (range) {
                setState(() {
                  selected = range;
                });
              },
            );
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stats_range_today')), findsOneWidget);
      expect(find.byKey(const Key('stats_range_thisWeek')), findsOneWidget);
      expect(find.byKey(const Key('stats_range_thisMonth')), findsOneWidget);
      expect(find.byKey(const Key('stats_range_thisYear')), findsOneWidget);
      expect(find.byKey(const Key('stats_range_allTime')), findsOneWidget);

      // Tap today
      await tester.tap(find.byKey(const Key('stats_range_today')));
      await tester.pumpAndSettle();
      expect(selected, equals(StatsTimeRange.today));

      // Scroll and tap allTime
      await tester.ensureVisible(find.byKey(const Key('stats_range_allTime')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('stats_range_allTime')));
      await tester.pumpAndSettle();
      expect(selected, equals(StatsTimeRange.allTime));
    });
  });

  group('StatsVehicleFilterChips Tests', () {
    testWidgets('renders vehicle filter chips with counts and handles selection', (tester) async {
      String? selectedProfile;

      await tester.pumpWidget(buildTestableWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return StatsVehicleFilterChips(
              selectedProfile: selectedProfile,
              profileCounts: const {
                'motorcycle': 5,
                'car': 2,
                'walking': 1,
              },
              onProfileSelected: (profile) {
                setState(() {
                  selectedProfile = profile;
                });
              },
            );
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stats_profile_all')), findsOneWidget);
      expect(find.byKey(const Key('stats_profile_motorcycle')), findsOneWidget);
      expect(find.byKey(const Key('stats_profile_car')), findsOneWidget);
      expect(find.byKey(const Key('stats_profile_walking')), findsOneWidget);

      // Total count 8 (5 + 2 + 1)
      expect(find.text('8'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Tap car
      await tester.ensureVisible(find.byKey(const Key('stats_profile_car')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('stats_profile_car')));
      await tester.pumpAndSettle();
      expect(selectedProfile, equals('car'));
    });
  });

  group('StatsSummaryCards Tests', () {
    testWidgets('renders all 4 KPI cards with correct values', (tester) async {
      const stats = TripStatsModel(
        totalTrips: 10,
        completedTrips: 9,
        totalDistanceMeters: 125450.0,
        totalDurationMs: 7200000, // 2 hours
        avgSpeedKmh: 42.5,
        topSpeedKmh: 75.0,
      );

      await tester.pumpWidget(buildTestableWidget(
        const StatsSummaryCards(stats: stats),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('kpi_card_distance')), findsOneWidget);
      expect(find.byKey(const Key('kpi_card_duration')), findsOneWidget);
      expect(find.byKey(const Key('kpi_card_trips')), findsOneWidget);
      expect(find.byKey(const Key('kpi_card_speed')), findsOneWidget);

      expect(find.text('125.5'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('43'), findsOneWidget); // 42.5 rounded
    });
  });

  group('StatsTripHistoryList Tests', () {
    testWidgets('renders trip items and handles tap and delete', (tester) async {
      final now = DateTime.now();
      final trip = TripRecordModel(
        id: 'trip_123',
        startTime: now.subtract(const Duration(minutes: 30)),
        endTime: now,
        durationMs: 1800000,
        distanceMeters: 12000,
        avgSpeedKmh: 24.0,
        topSpeedKmh: 45.0,
        hasArrived: true,
        originName: 'Nhà',
        destinationName: 'Công ty S-Map',
        vehicleProfile: 'motorcycle',
        createdAt: now,
      );

      TripRecordModel? tappedTrip;
      String? deletedId;

      await tester.pumpWidget(buildTestableWidget(
        StatsTripHistoryList(
          trips: [trip],
          onTapTrip: (t) => tappedTrip = t,
          onDeleteTrip: (id) => deletedId = id,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Công ty S-Map'), findsOneWidget);
      expect(find.byKey(const Key('trip_item_trip_123')), findsOneWidget);

      // Tap trip
      await tester.tap(find.byKey(const Key('trip_item_trip_123')));
      await tester.pumpAndSettle();
      expect(tappedTrip?.id, equals('trip_123'));

      // Tap delete button -> dialog shows
      await tester.tap(find.byKey(const Key('delete_trip_btn_trip_123')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('confirm_delete_trip_btn')), findsOneWidget);

      // Confirm delete
      await tester.tap(find.byKey(const Key('confirm_delete_trip_btn')));
      await tester.pumpAndSettle();
      expect(deletedId, equals('trip_123'));
    });
  });
}
