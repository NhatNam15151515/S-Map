import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/stats/widgets/stats_distance_chart.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('StatsDistanceChart Tests', () {
    testWidgets('renders empty state when chartData has no data', (tester) async {
      const emptyData = TripChartData.empty();

      await tester.pumpWidget(buildTestableWidget(
        const StatsDistanceChart(chartData: emptyData),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
      expect(find.byType(BarChart), findsNothing);
    });

    testWidgets('renders BarChart when chartData contains bars', (tester) async {
      final now = DateTime.now();
      final end = now.add(const Duration(days: 1));
      final chartData = TripChartData(
        timeRange: StatsTimeRange.thisWeek,
        bars: [
          TripChartBarData(
            x: 0,
            label: 'T2',
            distanceKm: 12.5,
            tripCount: 2,
            startDate: now,
            endDate: end,
          ),
          TripChartBarData(
            x: 1,
            label: 'T3',
            distanceKm: 8.0,
            tripCount: 1,
            startDate: now,
            endDate: end,
          ),
          TripChartBarData(
            x: 2,
            label: 'T4',
            distanceKm: 0.0,
            tripCount: 0,
            startDate: now,
            endDate: end,
          ),
        ],
        totalDistanceKm: 20.5,
        maxDistanceKm: 12.5,
      );

      await tester.pumpWidget(buildTestableWidget(
        StatsDistanceChart(chartData: chartData),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(BarChart), findsOneWidget);
      expect(find.text('20.5 km'), findsOneWidget);
    });
  });
}
