import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/fallbacks/fallbacks.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/home/widgets/widgets.dart';

class MockRoutingRepo implements IRoutingRepository {
  @override
  Future<RouteResult> calculateRoute({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    String? vehicleProfile,
  }) async =>
      const RouteResult(
          isSuccess: true, distance: 1000, time: 60000, points: []);

  @override
  Future<SnappedRoadPoint> snapToRoad({
    required double lat,
    required double lon,
  }) async =>
      SnappedRoadPoint(
        isSnapped: true,
        originalLat: lat,
        originalLon: lon,
        snappedLat: lat,
        snappedLon: lon,
      );

  @override
  Future<bool> initializeEngine(String graphPath) async => true;

  @override
  Future<bool> isEngineReady() async => true;

  @override
  Future<bool> dispose() async => true;
}

Widget createTestApp({
  required Widget child,
  NavigationBloc? navigationBloc,
}) {
  final bloc = navigationBloc ??
      NavigationBloc(
        routingRepository: MockRoutingRepo(),
        locationService: const NoOpLocationService(),
      );

  return MaterialApp(
    home: Scaffold(
      body: BlocProvider<NavigationBloc>.value(
        value: bloc,
        child: Stack(
          children: [child],
        ),
      ),
    ),
  );
}

void main() {
  group('Navigation UI Widgets Tests', () {
    testWidgets(
        'NavigationTopPanel renders turn instruction, distance, and street name',
        (tester) async {
      final navBloc = NavigationBloc(
        routingRepository: MockRoutingRepo(),
        locationService: const NoOpLocationService(),
      );

      const instruction = RouteInstruction(
        text: 'Rẽ phải vào Đồng Khởi',
        streetName: 'Đồng Khởi',
        distance: 250.0,
        time: 30000,
        sign: 2, // turnRight
        points: [],
      );

      const nextInstruction = RouteInstruction(
        text: 'Rẽ trái vào Lê Thánh Tôn',
        streetName: 'Lê Thánh Tôn',
        distance: 400.0,
        time: 40000,
        sign: -2, // turnLeft
        points: [],
      );

      navBloc.emit(const NavigationState(
        status: NavigationStatus.navigating,
        currentInstruction: instruction,
        nextInstruction: nextInstruction,
        distanceToNextInstruction: 250.0,
        remainingDistance: 1500.0,
        remainingDurationMs: 120000,
        isPreAnnounced: true,
      ));

      await tester.pumpWidget(createTestApp(
        child: const NavigationTopPanel(topPadding: 24),
        navigationBloc: navBloc,
      ));
      await tester.pump();

      expect(find.text('250 m'), findsOneWidget);
      expect(find.text('Đồng Khởi'), findsOneWidget);
      expect(find.textContaining('Lê Thánh Tôn'), findsOneWidget);
      expect(find.byIcon(Icons.turn_right_rounded), findsOneWidget);
    });

    testWidgets(
        'NavigationBottomPanel renders speedometer, remaining distance, ETA and triggers stop callback',
        (tester) async {
      final navBloc = NavigationBloc(
        routingRepository: MockRoutingRepo(),
        locationService: const NoOpLocationService(),
      );

      navBloc.emit(const NavigationState(
        status: NavigationStatus.navigating,
        currentSpeedKmh: 35.0,
        remainingDistance: 2400.0,
        remainingDurationMs: 300000, // 5 mins
      ));

      bool stopped = false;

      await tester.pumpWidget(createTestApp(
        child: NavigationBottomPanel(
          onStopNavigation: () {
            stopped = true;
          },
        ),
        navigationBloc: navBloc,
      ));
      await tester.pump();

      expect(find.text('35'), findsOneWidget);
      expect(
        find.textContaining(RouteFormatHelper.formatDuration(300000)),
        findsOneWidget,
      );
      expect(find.textContaining('2.4 km'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(stopped, isTrue);
    });

    testWidgets(
        'TripSummaryBottomSheet renders trip metrics and handles Done button tap',
        (tester) async {
      bool doneTapped = false;

      const summary = TripSummary(
        duration: Duration(minutes: 14, seconds: 20),
        distanceMeters: 4500.0,
        avgSpeedKmh: 28.5,
        topSpeedKmh: 42.0,
        destinationName: 'Nhà hát Thành phố',
        hasArrived: true,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TripSummaryBottomSheet(
            summary: summary,
            onDone: () {
              doneTapped = true;
            },
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('Nhà hát Thành phố'), findsOneWidget);
      expect(find.textContaining('14'), findsOneWidget);
      expect(find.text('4.5 km'), findsOneWidget);
      expect(find.textContaining('28.5'), findsOneWidget);
      expect(find.textContaining('42.0'), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(doneTapped, isTrue);
    });
  });
}
