import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/stats/trip_detail_screen.dart';

void main() {
  final now = DateTime(2026, 8, 23, 14, 0);
  final testTrip = TripRecordModel(
    id: 'test_detail_trip',
    startTime: now.subtract(const Duration(minutes: 45)),
    endTime: now,
    durationMs: 2700000, // 45m
    distanceMeters: 18500, // 18.5km
    avgSpeedKmh: 24.67,
    topSpeedKmh: 55.0,
    hasArrived: true,
    originName: 'Bến Thành',
    destinationName: 'Sân bay Tân Sơn Nhất',
    vehicleProfile: 'motorcycle',
    polyline: const [
      [10.772, 106.698],
      [10.800, 106.660],
      [10.816, 106.663],
    ],
    createdAt: now,
  );

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  group('TripDetailScreen Tests', () {
    testWidgets('renders all trip metadata and stat boxes', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        TripDetailScreen(
          trip: testTrip,
          mapLayerBuilder: (context, controller) => const SizedBox(
            key: Key('mock_map_layer'),
            height: 200,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mock_map_layer')), findsOneWidget);
      expect(find.byKey(const Key('trip_detail_back_btn')), findsOneWidget);
      expect(find.text('Bến Thành'), findsOneWidget);
      expect(find.text('Sân bay Tân Sơn Nhất'), findsOneWidget);
      expect(find.text('18.5 km'), findsOneWidget);
      expect(find.text('25 km/h'), findsOneWidget); // 24.67 rounded
      expect(find.text('55 km/h'), findsOneWidget);
    });

    testWidgets('tapping back button pops navigator', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    settings: const RouteSettings(name: '/detail'),
                    builder: (_) => TripDetailScreen(
                      trip: testTrip,
                      mapLayerBuilder: (context, controller) => const SizedBox(),
                    ),
                  ),
                );
              },
              child: const Text('Go'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open detail
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('trip_detail_back_btn')), findsOneWidget);

      // Tap back button
      await tester.tap(find.byKey(const Key('trip_detail_back_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Go'), findsOneWidget);
    });
  });
}
