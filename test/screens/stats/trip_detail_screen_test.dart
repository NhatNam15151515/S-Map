import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/routers/app_routes.dart';
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

  Widget buildLocalizedWidget(Widget child) {
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
            home: child,
          );
        },
      ),
    );
  }

  group('TripDetailScreen Tests', () {
    testWidgets('renders all trip metadata and stat boxes', (tester) async {
      await tester.pumpWidget(buildLocalizedWidget(
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

    testWidgets('GoRouter navigation opens TripDetailScreen via state.extra and pops with back button', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open_trip_detail_btn'),
                  onPressed: () => context.push(
                    AppRoutes.tripDetail,
                    extra: testTrip,
                  ),
                  child: const Text('Open Detail'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.tripDetail,
            builder: (context, state) {
              final trip = state.extra;
              if (trip is! TripRecordModel) {
                return const Scaffold(
                  body: Center(child: Text('Invalid trip data')),
                );
              }
              return TripDetailScreen(
                trip: trip,
                mapLayerBuilder: (context, controller) => const SizedBox(
                  key: Key('mock_map_layer'),
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('vi'), Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('vi'),
        startLocale: const Locale('vi'),
        assetLoader: const CodegenLoader(),
        child: Builder(
          builder: (context) {
            return MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
            );
          },
        ),
      ));
      await tester.pumpAndSettle();

      // Tap open detail button
      await tester.tap(find.byKey(const Key('open_trip_detail_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mock_map_layer')), findsOneWidget);
      expect(find.text('Bến Thành'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byKey(const Key('trip_detail_back_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('open_trip_detail_btn')), findsOneWidget);
    });

    testWidgets('GoRouter handles invalid or missing extra payload gracefully', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: ElevatedButton(
                key: const Key('open_invalid_btn'),
                onPressed: () => context.push(
                  AppRoutes.tripDetail,
                  extra: 'invalid_string_payload',
                ),
                child: const Text('Invalid'),
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.tripDetail,
            builder: (context, state) {
              final trip = state.extra;
              if (trip is! TripRecordModel) {
                return const Scaffold(
                  body: Center(child: Text('Invalid trip data')),
                );
              }
              return TripDetailScreen(trip: trip);
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(
        routerConfig: router,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_invalid_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Invalid trip data'), findsOneWidget);
    });
  });
}
