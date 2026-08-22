import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class MockRoutingRepository implements IRoutingRepository {
  RouteResult nextCalculateResult = const RouteResult(
    isSuccess: true,
    distance: 1200.0,
    time: 150000,
    points: [
      [10.7730, 106.6990],
      [10.7750, 106.7010],
      [10.7766, 106.7032],
    ],
  );

  SnappedRoadPoint nextSnapResult = const SnappedRoadPoint(
    isSnapped: true,
    originalLat: 10.7730,
    originalLon: 106.6990,
    snappedLat: 10.77305,
    snappedLon: 106.69905,
    streetName: 'Lê Duẩn',
    distanceToRoad: 3.2,
  );

  int calculateRouteCallCount = 0;
  int snapToRoadCallCount = 0;
  double? lastFromLat;
  double? lastFromLon;
  double? lastToLat;
  double? lastToLon;
  Duration snapDelay = Duration.zero;
  Duration routeDelay = Duration.zero;
  Exception? snapException;
  Exception? routeException;

  @override
  Future<RouteResult> calculateRoute({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    String? vehicleProfile,
  }) async {
    calculateRouteCallCount++;
    lastFromLat = fromLat;
    lastFromLon = fromLon;
    lastToLat = toLat;
    lastToLon = toLon;

    if (routeDelay > Duration.zero) {
      await Future.delayed(routeDelay);
    }
    if (routeException != null) {
      throw routeException!;
    }
    return nextCalculateResult;
  }

  @override
  Future<SnappedRoadPoint> snapToRoad({
    required double lat,
    required double lon,
  }) async {
    snapToRoadCallCount++;
    if (snapDelay > Duration.zero) {
      await Future.delayed(snapDelay);
    }
    if (snapException != null) {
      throw snapException!;
    }
    return SnappedRoadPoint(
      isSnapped: true,
      originalLat: lat,
      originalLon: lon,
      snappedLat: lat + 0.00005,
      snappedLon: lon + 0.00005,
      streetName: nextSnapResult.streetName,
      distanceToRoad: nextSnapResult.distanceToRoad,
    );
  }

  @override
  Future<bool> isEngineReady() async => true;

  @override
  Future<bool> initializeEngine(String graphPath) async => true;

  @override
  Future<bool> dispose() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockRoutingRepository mockRepository;
  late RouteDrawingBloc bloc;

  setUp(() {
    mockRepository = MockRoutingRepository();
    bloc = RouteDrawingBloc(routingRepository: mockRepository);
  });

  tearDown(() async {
    await bloc.close();
  });

  group('RouteDrawingBloc State Transitions & Lifecycle', () {
    test('Initial state is clean and empty', () {
      expect(bloc.state.status, RouteDrawingStatus.initial);
      expect(bloc.state.points, isEmpty);
      expect(bloc.state.segments, isEmpty);
      expect(bloc.state.fullPolyline, isEmpty);
      expect(bloc.state.totalDistance, 0.0);
      expect(bloc.state.totalTime, 0);
      expect(bloc.state.canUndo, isFalse);
      expect(bloc.state.canRedo, isFalse);
      expect(bloc.state.hasRoute, isFalse);
      expect(bloc.state.pointCount, 0);
    });

    test('Adding first point snaps to road and emits pointAdded', () async {
      final streamExpectation = expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<RouteDrawingState>((s) =>
              s.status == RouteDrawingStatus.loading &&
              s.requestGeneration == 1),
          predicate<RouteDrawingState>((s) =>
              s.status == RouteDrawingStatus.pointAdded &&
              s.points.length == 1 &&
              s.segments.isEmpty &&
              s.fullPolyline.isEmpty &&
              s.canUndo == true &&
              s.canRedo == false &&
              s.totalDistance == 0.0),
        ]),
      );

      bloc.add(const RouteDrawingPointTapped(
        lat: 10.7730,
        lon: 106.6990,
      ));

      await streamExpectation;
      expect(mockRepository.snapToRoadCallCount, 1);
      expect(mockRepository.calculateRouteCallCount, 0);
    });

    test(
        'Adding second point auto-connects route segment and emits routeUpdated',
        () async {
      // Step 1: Add first point
      bloc.add(const RouteDrawingPointTapped(
        lat: 10.7730,
        lon: 106.6990,
      ));
      await bloc.stream.firstWhere(
          (s) => s.status == RouteDrawingStatus.pointAdded);

      // Step 2: Add second point
      final streamExpectation = expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<RouteDrawingState>((s) =>
              s.status == RouteDrawingStatus.loading &&
              s.requestGeneration == 2),
          predicate<RouteDrawingState>((s) =>
              s.status == RouteDrawingStatus.routeUpdated &&
              s.points.length == 2 &&
              s.segments.length == 1 &&
              s.fullPolyline.length == 3 &&
              s.totalDistance == 1200.0 &&
              s.totalTime == 150000 &&
              s.canUndo == true &&
              s.canRedo == false),
        ]),
      );

      bloc.add(const RouteDrawingPointTapped(
        lat: 10.7780,
        lon: 106.7020,
      ));

      await streamExpectation;
      expect(mockRepository.snapToRoadCallCount, 2);
      expect(mockRepository.calculateRouteCallCount, 1);
      expect(mockRepository.lastFromLat, closeTo(10.77305, 0.00001));
    });

    test('Adding third point appends segment and accumulates metrics', () async {
      // Point 1
      bloc.add(const RouteDrawingPointTapped(lat: 10.7730, lon: 106.6990));
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.pointAdded);

      // Point 2
      bloc.add(const RouteDrawingPointTapped(lat: 10.7780, lon: 106.7020));
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.routeUpdated);

      // Setup segment 2 result starting with previous endpoint [10.7766, 106.7032]
      mockRepository.nextCalculateResult = const RouteResult(
        isSuccess: true,
        distance: 800.0,
        time: 90000,
        points: [
          [10.7766, 106.7032],
          [10.78005, 106.70805],
        ],
      );

      // Point 3
      final streamExpectation = expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<RouteDrawingState>(
              (s) => s.status == RouteDrawingStatus.loading),
          predicate<RouteDrawingState>((s) =>
              s.status == RouteDrawingStatus.routeUpdated &&
              s.points.length == 3 &&
              s.segments.length == 2 &&
              s.totalDistance == 2000.0 &&
              s.totalTime == 240000 &&
              s.fullPolyline.length == 4),
        ]),
      );

      bloc.add(const RouteDrawingPointTapped(lat: 10.7800, lon: 106.7080));
      await streamExpectation;
    });

    test(
        'Auto-connect failure emits warning state with message and retains point',
        () async {
      // Point 1
      bloc.add(const RouteDrawingPointTapped(lat: 10.7730, lon: 106.6990));
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.pointAdded);

      // Route failure for point 2
      mockRepository.nextCalculateResult =
          RouteResult.failure(RoutingConstants.errNoRouteFound);

      final streamExpectation = expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<RouteDrawingState>(
              (s) => s.status == RouteDrawingStatus.loading),
          predicate<RouteDrawingState>((s) =>
              s.status == RouteDrawingStatus.warning &&
              s.points.length == 2 &&
              s.segments.isEmpty &&
              s.warningMessageKey == RoutingConstants.errNoRouteFound),
        ]),
      );

      bloc.add(const RouteDrawingPointTapped(lat: 10.7800, lon: 106.7080));
      await streamExpectation;
    });

    test('Repository exception emits error state gracefully', () async {
      mockRepository.snapException = Exception('GraphHopper native error');

      final streamExpectation = expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<RouteDrawingState>(
              (s) => s.status == RouteDrawingStatus.loading),
          predicate<RouteDrawingState>((s) =>
              s.status == RouteDrawingStatus.error &&
              s.errorMessageKey == LocaleKeys.routing_error_generic),
        ]),
      );

      bloc.add(const RouteDrawingPointTapped(lat: 10.7730, lon: 106.6990));
      await streamExpectation;
    });
  });

  group('RouteDrawingBloc Undo, Redo, Clear & Save', () {
    test('Undo from 1 point resets to initial state and enables canRedo',
        () async {
      bloc.add(const RouteDrawingPointTapped(lat: 10.7730, lon: 106.6990));
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.pointAdded);

      final streamExpectation = expectLater(
        bloc.stream,
        emits(predicate<RouteDrawingState>((s) =>
            s.status == RouteDrawingStatus.initial &&
            s.points.isEmpty &&
            s.canUndo == false &&
            s.canRedo == true &&
            s.redoPoints.length == 1)),
      );

      bloc.add(const RouteDrawingUndoLastPoint());
      await streamExpectation;
    });

    test('Undo from 2 points pops segment and recalculates metrics', () async {
      bloc.add(const RouteDrawingPointTapped(lat: 10.7730, lon: 106.6990));
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.pointAdded);

      bloc.add(const RouteDrawingPointTapped(lat: 10.7780, lon: 106.7020));
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.routeUpdated);

      final streamExpectation = expectLater(
        bloc.stream,
        emits(predicate<RouteDrawingState>((s) =>
            s.status == RouteDrawingStatus.pointAdded &&
            s.points.length == 1 &&
            s.segments.isEmpty &&
            s.fullPolyline.isEmpty &&
            s.totalDistance == 0.0 &&
            s.totalTime == 0 &&
            s.canUndo == true &&
            s.canRedo == true &&
            s.redoPoints.length == 1 &&
            s.redoSegments.length == 1)),
      );

      bloc.add(const RouteDrawingUndoLastPoint());
      await streamExpectation;
    });

    test('Redo restores popped point and segment', () async {
      bloc.add(const RouteDrawingPointTapped(lat: 10.7730, lon: 106.6990));
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.pointAdded);

      bloc.add(const RouteDrawingPointTapped(lat: 10.7780, lon: 106.7020));
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.routeUpdated);

      bloc.add(const RouteDrawingUndoLastPoint());
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.pointAdded);

      final streamExpectation = expectLater(
        bloc.stream,
        emits(predicate<RouteDrawingState>((s) =>
            s.status == RouteDrawingStatus.routeUpdated &&
            s.points.length == 2 &&
            s.segments.length == 1 &&
            s.totalDistance == 1200.0 &&
            s.totalTime == 150000 &&
            s.canUndo == true &&
            s.canRedo == false)),
      );

      bloc.add(const RouteDrawingRedoPoint());
      await streamExpectation;
    });

    test('Clear route resets all state and undo/redo stacks', () async {
      bloc.add(const RouteDrawingPointTapped(lat: 10.7730, lon: 106.6990));
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.pointAdded);

      bloc.add(const RouteDrawingPointTapped(lat: 10.7780, lon: 106.7020));
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.routeUpdated);

      final streamExpectation = expectLater(
        bloc.stream,
        emits(predicate<RouteDrawingState>((s) =>
            s.status == RouteDrawingStatus.initial &&
            s.points.isEmpty &&
            s.segments.isEmpty &&
            s.totalDistance == 0.0 &&
            s.canUndo == false &&
            s.canRedo == false)),
      );

      bloc.add(const RouteDrawingClearRoute());
      await streamExpectation;
    });

    test('Save route with insufficient points emits warning', () async {
      bloc.add(const RouteDrawingPointTapped(lat: 10.7730, lon: 106.6990));
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.pointAdded);

      final streamExpectation = expectLater(
        bloc.stream,
        emits(predicate<RouteDrawingState>((s) =>
            s.status == RouteDrawingStatus.warning &&
            s.warningMessageKey == LocaleKeys.routing_error_generic)),
      );

      bloc.add(const RouteDrawingSaveRoute(name: 'My Custom Route'));
      await streamExpectation;
    });

    test('Save route with valid route emits saved status', () async {
      bloc.add(const RouteDrawingPointTapped(lat: 10.7730, lon: 106.6990));
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.pointAdded);

      bloc.add(const RouteDrawingPointTapped(lat: 10.7780, lon: 106.7020));
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.routeUpdated);

      final streamExpectation = expectLater(
        bloc.stream,
        emits(predicate<RouteDrawingState>(
            (s) => s.status == RouteDrawingStatus.saved)),
      );

      bloc.add(const RouteDrawingSaveRoute(name: 'Phượt Tây Bắc'));
      await streamExpectation;
    });
  });

  group('RouteDrawingBloc Concurrency & restartable()', () {
    test('Rapid tapping only finishes processing the latest tap event',
        () async {
      mockRepository.snapDelay = const Duration(milliseconds: 50);

      bloc.add(const RouteDrawingPointTapped(lat: 10.1, lon: 106.1));
      bloc.add(const RouteDrawingPointTapped(lat: 10.2, lon: 106.2));
      bloc.add(const RouteDrawingPointTapped(lat: 10.3, lon: 106.3));

      // Chờ hoàn tất tác vụ cuối cùng
      await Future.delayed(const Duration(milliseconds: 180));

      expect(bloc.state.status, RouteDrawingStatus.pointAdded);
      expect(bloc.state.points.length, 1);
      expect(bloc.state.points.first.originalLat, 10.3);
    });
  });
}
