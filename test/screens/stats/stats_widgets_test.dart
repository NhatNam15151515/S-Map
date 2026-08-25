import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/stats/widgets/widgets.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
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
            home: Scaffold(
              body: child,
            ),
          );
        },
      ),
    );
  }

  group('Stats Widgets Tests', () {
    testWidgets('StatsTimeRangeSelector renders all chips and handles selection', (tester) async {
      StatsTimeRange? selected;

      await tester.pumpWidget(buildTestableWidget(
        StatsTimeRangeSelector(
          selectedRange: StatsTimeRange.thisWeek,
          onRangeSelected: (range) => selected = range,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stats_range_today')), findsOneWidget);
      expect(find.byKey(const Key('stats_range_thisWeek')), findsOneWidget);
      expect(find.byKey(const Key('stats_range_thisMonth')), findsOneWidget);
      expect(find.byKey(const Key('stats_range_thisYear')), findsOneWidget);
      expect(find.byKey(const Key('stats_range_allTime')), findsOneWidget);

      await tester.tap(find.byKey(const Key('stats_range_today')));
      await tester.pumpAndSettle();

      expect(selected, equals(StatsTimeRange.today));
    });

    testWidgets('StatsVehicleFilterChips renders vehicle chips and handles moped_vn under motorcycle profile', (tester) async {
      String? selected;

      await tester.pumpWidget(buildTestableWidget(
        StatsVehicleFilterChips(
          selectedProfile: null,
          profileCounts: const {
            'moped_vn': 2,
            'motorcycle': 1,
            'car': 1,
            'walking': 1,
          },
          onProfileSelected: (p) => selected = p,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stats_profile_all')), findsOneWidget);
      expect(find.byKey(const Key('stats_profile_motorcycle')), findsOneWidget);
      expect(find.byKey(const Key('stats_profile_car')), findsOneWidget);
      expect(find.byKey(const Key('stats_profile_walking')), findsOneWidget);

      // Motorcycle count should aggregate motorcycle (1) + moped_vn (2) = 3
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.byKey(const Key('stats_profile_motorcycle')));
      await tester.pumpAndSettle();

      expect(selected, equals('motorcycle'));
    });

    testWidgets('StatsSummaryCards renders KPI values and subtitles accurately', (tester) async {
      const stats = TripStatsModel(
        totalTrips: 5,
        completedTrips: 4,
        totalDistanceMeters: 45000, // 45km
        totalDurationMs: 3600000, // 1h
        avgSpeedKmh: 45.0,
        topSpeedKmh: 80.0,
      );

      await tester.pumpWidget(buildTestableWidget(
        const StatsSummaryCards(stats: stats),
      ));
      await tester.pumpAndSettle();

      expect(find.text('45.0'), findsOneWidget);
      expect(find.text('1 giờ'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.textContaining('80 km/h'), findsOneWidget);
    });

    testWidgets('StatsTripHistoryList renders trip items and handles delete confirmation', (tester) async {
      final now = DateTime.now();
      final trips = [
        TripRecordModel(
          id: 'trip_1',
          startTime: now.subtract(const Duration(hours: 1)),
          endTime: now,
          durationMs: 3600000,
          distanceMeters: 20000,
          avgSpeedKmh: 20.0,
          topSpeedKmh: 40.0,
          hasArrived: true,
          originName: 'Nhà',
          destinationName: 'Công ty',
          vehicleProfile: 'motorcycle',
          createdAt: now,
        ),
      ];

      String? deletedId;
      TripRecordModel? tappedTrip;

      await tester.pumpWidget(buildTestableWidget(
        StatsTripHistoryList(
          trips: trips,
          onTapTrip: (t) => tappedTrip = t,
          onDeleteTrip: (id) => deletedId = id,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Công ty'), findsOneWidget);
      expect(find.textContaining('20.0 km'), findsOneWidget);

      // Tap trip
      await tester.tap(find.text('Công ty'));
      await tester.pumpAndSettle();
      expect(tappedTrip?.id, equals('trip_1'));

      // Tap delete button -> opens dialog -> confirm
      await tester.tap(find.byKey(const Key('delete_trip_btn_trip_1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('confirm_delete_trip_btn')), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm_delete_trip_btn')));
      await tester.pumpAndSettle();

      expect(deletedId, equals('trip_1'));
    });
  });
}
