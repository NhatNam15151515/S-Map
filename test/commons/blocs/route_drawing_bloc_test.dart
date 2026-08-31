import 'dart:async';

import 'package:flutter/foundation.dart';
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
  Completer<void>? snapStartedCompleter;
  Completer<void>? snapReleaseCompleter;
  Completer<void>? routeStartedCompleter;
  Completer<void>? routeReleaseCompleter;
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

    if (routeStartedCompleter != null && !routeStartedCompleter!.isCompleted) {
      routeStartedCompleter!.complete();
    }
    if (routeReleaseCompleter != null) {
      await routeReleaseCompleter!.future;
    }
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
    if (snapStartedCompleter != null && !snapStartedCompleter!.isCompleted) {
      snapStartedCompleter!.complete();
    }
    if (snapReleaseCompleter != null) {
      await snapReleaseCompleter!.future;
    }
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

class MockCustomRouteRepo implements ICustomRouteRepository {
  final List<CustomRouteModel> savedRoutes = [];

  @override
  Future<List<CustomRouteModel>> getSavedRoutes() async => savedRoutes;

  Duration? saveDelay;
  VoidCallback? onSaveStarted;

  @override
  Future<CustomRouteModel?> getRouteById(String id) async =>
      savedRoutes.where((r) => r.id == id).firstOrNull;

  @override
  Future<void> saveRoute(CustomRouteModel route) async {
    onSaveStarted?.call();
    if (saveDelay != null) {
      await Future.delayed(saveDelay!);
    }
    final index = savedRoutes.indexWhere((r) => r.id == route.id);
    if (index >= 0) {
      savedRoutes[index] = route;
    } else {
      savedRoutes.add(route);
    }
  }

  @override
  Future<void> deleteRoute(String id) async {
    savedRoutes.removeWhere((r) => r.id == id);
  }

  @override
  Future<void> clearAllRoutes() async {
    savedRoutes.clear();
  }

  @override
  Stream<List<CustomRouteModel>> watchSavedRoutes() => Stream.value(savedRoutes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockRoutingRepository mockRepository;
  late MockCustomRouteRepo mockCustomRouteRepo;
  late RouteDrawingBloc bloc;

  setUp(() {
    mockRepository = MockRoutingRepository();
    mockCustomRouteRepo = MockCustomRouteRepo();
    bloc = RouteDrawingBloc(
      routingRepository: mockRepository,
      customRouteRepository: mockCustomRouteRepo,
    );
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

    test('Selecting endpoints creates origin before destination atomically', () async {
      final streamExpectation = expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<RouteDrawingState>(
            (s) => s.status == RouteDrawingStatus.loading,
          ),
          predicate<RouteDrawingState>((s) =>
              s.status == RouteDrawingStatus.routeUpdated &&
              s.points.length == 2 &&
              s.points.first.originalLat == 10.7700 &&
              s.points.last.originalLat == 10.7800 &&
              s.totalDistance == 1200.0),
        ]),
      );

      bloc.add(const RouteDrawingEndpointsSelected(
        origin: RoutePoint(lat: 10.7700, lon: 106.7000),
        destination: RoutePoint(lat: 10.7800, lon: 106.7100),
      ));

      await streamExpectation;
      expect(mockRepository.snapToRoadCallCount, 0);
      expect(mockRepository.calculateRouteCallCount, 1);
      expect(mockRepository.lastFromLat, 10.7700);
      expect(mockRepository.lastToLat, 10.7800);
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
        'Auto-connect failure seamlessly connects direct segment and emits routeUpdated',
        () async {
      // Point 1
      bloc.add(const RouteDrawingPointTapped(lat: 10.7730, lon: 106.6990));
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.pointAdded);

      // Route failure for point 2 (e.g. unindexed alley / path)
      mockRepository.nextCalculateResult =
          RouteResult.failure(RoutingConstants.errNoRouteFound);

      final streamExpectation = expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<RouteDrawingState>(
              (s) => s.status == RouteDrawingStatus.loading),
          predicate<RouteDrawingState>((s) =>
              s.status == RouteDrawingStatus.routeUpdated &&
              s.points.length == 2 &&
              s.segments.length == 1 &&
              s.fullPolyline.length == 2 &&
              s.totalDistance > 0),
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

    test(
        'Undo and Redo when latest point failed auto-connect preserves existing segments',
        () async {
      // P1
      bloc.add(const RouteDrawingPointTapped(lat: 10.7730, lon: 106.6990));
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.pointAdded);

      // P2 (success -> 1 segment, 1200m)
      bloc.add(const RouteDrawingPointTapped(lat: 10.7780, lon: 106.7020));
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.routeUpdated);

      // P3 fallback segment connection -> routeUpdated, 3 points, 2 segments
      mockRepository.nextCalculateResult =
          RouteResult.failure(RoutingConstants.errNoRouteFound);

      bloc.add(const RouteDrawingPointTapped(lat: 10.7800, lon: 106.7080));
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.routeUpdated && s.points.length == 3);

      expect(bloc.state.points.length, 3);
      expect(bloc.state.segments.length, 2);
      expect(bloc.state.totalDistance, greaterThan(1200.0));

      // Undo P3: Should pop segment 2
      final streamExpectationUndo = expectLater(
        bloc.stream,
        emits(predicate<RouteDrawingState>((s) =>
            s.status == RouteDrawingStatus.routeUpdated &&
            s.points.length == 2 &&
            s.segments.length == 1 &&
            s.totalDistance == 1200.0 &&
            s.totalTime == 150000 &&
            s.canUndo == true &&
            s.canRedo == true &&
            s.redoPoints.length == 1 &&
            s.redoSegments.length == 1 &&
            s.redoSegments.first != null)),
      );

      bloc.add(const RouteDrawingUndoLastPoint());
      await streamExpectationUndo;

      // Redo P3: Should restore P3 and segment 2
      final streamExpectationRedo = expectLater(
        bloc.stream,
        emits(predicate<RouteDrawingState>((s) =>
            s.status == RouteDrawingStatus.routeUpdated &&
            s.points.length == 3 &&
            s.segments.length == 2 &&
            s.totalDistance > 1200.0 &&
            s.canUndo == true &&
            s.canRedo == false)),
      );

      bloc.add(const RouteDrawingRedoPoint());
      await streamExpectationRedo;
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

    test('Save route with valid route saves to repository and emits saved status', () async {
      bloc.add(const RouteDrawingPointTapped(lat: 10.7730, lon: 106.6990));
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.pointAdded);

      bloc.add(const RouteDrawingPointTapped(lat: 10.7780, lon: 106.7020));
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.routeUpdated);

      final streamExpectation = expectLater(
        bloc.stream,
        emits(predicate<RouteDrawingState>(
            (s) => s.status == RouteDrawingStatus.saved && s.savedRoute != null && s.savedRoute!.name == 'Phượt Tây Bắc')),
      );

      bloc.add(const RouteDrawingSaveRoute(name: 'Phượt Tây Bắc', description: 'Cung đường đẹp'));
      await streamExpectation;

      expect(mockCustomRouteRepo.savedRoutes.length, equals(1));
      expect(mockCustomRouteRepo.savedRoutes.first.name, equals('Phượt Tây Bắc'));
      expect(mockCustomRouteRepo.savedRoutes.first.description, equals('Cung đường đẹp'));
      expect(mockCustomRouteRepo.savedRoutes.first.waypoints.length, equals(2));
      expect(mockCustomRouteRepo.savedRoutes.first.totalDistance, equals(1200.0));
    });

    test('Load saved route into RouteDrawingBloc sets routeUpdated status and restores points/polyline', () async {
      final customRoute = CustomRouteModel(
        id: 'saved_trip_1',
        name: 'Đà Lạt Săn Mây',
        waypoints: const [
          SnappedRoadPoint(
            isSnapped: true,
            originalLat: 11.9404,
            originalLon: 108.4583,
            snappedLat: 11.94045,
            snappedLon: 108.45835,
          ),
          SnappedRoadPoint(
            isSnapped: true,
            originalLat: 11.9500,
            originalLon: 108.4700,
            snappedLat: 11.95005,
            snappedLon: 108.47005,
          ),
        ],
        fullPolyline: const [
          [11.94045, 108.45835],
          [11.94500, 108.46000],
          [11.95005, 108.47005],
        ],
        totalDistance: 3500.0,
        totalTime: 420000,
        profile: RoutingConstants.profileMotorcycle,
        createdAt: DateTime(2026, 8, 22, 14, 0),
        description: 'Tuyến đường đèo',
      );

      final streamExpectation = expectLater(
        bloc.stream,
        emits(predicate<RouteDrawingState>((s) =>
            s.status == RouteDrawingStatus.routeUpdated &&
            s.points.length == 2 &&
            s.fullPolyline.length == 3 &&
            s.totalDistance == 3500.0 &&
            s.totalTime == 420000 &&
            s.savedRoute == customRoute &&
            s.canUndo == true &&
            s.canRedo == false)),
      );

      bloc.add(RouteDrawingLoadRoute(customRoute));
      await streamExpectation;
    });

    test('Saving an already loaded route updates existing record via upsert without creating duplicates', () async {
      final initialRoute = CustomRouteModel(
        id: 'persisted_1',
        name: 'Tuyến gốc',
        waypoints: const [
          SnappedRoadPoint(
            isSnapped: true,
            originalLat: 10.773,
            originalLon: 106.699,
            snappedLat: 10.77305,
            snappedLon: 106.69905,
          ),
          SnappedRoadPoint(
            isSnapped: true,
            originalLat: 10.778,
            originalLon: 106.702,
            snappedLat: 10.77805,
            snappedLon: 106.70205,
          ),
        ],
        fullPolyline: const [
          [10.77305, 106.69905],
          [10.77805, 106.70205],
        ],
        totalDistance: 1200.0,
        totalTime: 150000,
        profile: RoutingConstants.profileMotorcycle,
        createdAt: DateTime(2026, 8, 22, 8, 0),
        description: 'Mô tả ban đầu',
      );

      mockCustomRouteRepo.savedRoutes.add(initialRoute);

      // Load route
      bloc.add(RouteDrawingLoadRoute(initialRoute));
      await bloc.stream.firstWhere((s) => s.status == RouteDrawingStatus.routeUpdated);

      // Save again with new name & description
      final saveExpectation = expectLater(
        bloc.stream,
        emits(predicate<RouteDrawingState>((s) =>
            s.status == RouteDrawingStatus.saved &&
            s.savedRoute?.name == 'Tuyến đã cập nhật' &&
            s.savedRoute?.description == 'Mô tả mới')),
      );

      bloc.add(const RouteDrawingSaveRoute(
        name: 'Tuyến đã cập nhật',
        description: 'Mô tả mới',
      ));
      await saveExpectation;

      // Verify upsert: only 1 record remains in repository
      expect(mockCustomRouteRepo.savedRoutes.length, equals(1));
      final savedInRepo = mockCustomRouteRepo.savedRoutes.first;
      expect(savedInRepo.id, equals('persisted_1'));
      expect(savedInRepo.name, equals('Tuyến đã cập nhật'));
      expect(savedInRepo.description, equals('Mô tả mới'));
      expect(savedInRepo.createdAt, equals(initialRoute.createdAt));
      expect(savedInRepo.totalDistance, equals(1200.0));
    });

    test('Interleaving clear while saving suppresses stale saved status emission', () async {
      final initialRoute = CustomRouteModel(
        id: 'interleaved_1',
        name: 'Tuyến chuẩn bị lưu',
        waypoints: const [
          SnappedRoadPoint(
            isSnapped: true,
            originalLat: 10.773,
            originalLon: 106.699,
            snappedLat: 10.77305,
            snappedLon: 106.69905,
          ),
          SnappedRoadPoint(
            isSnapped: true,
            originalLat: 10.778,
            originalLon: 106.702,
            snappedLat: 10.77805,
            snappedLon: 106.70205,
          ),
        ],
        fullPolyline: const [
          [10.77305, 106.69905],
          [10.77805, 106.70205],
        ],
        totalDistance: 1200.0,
        totalTime: 150000,
        profile: RoutingConstants.profileMotorcycle,
        createdAt: DateTime(2026, 8, 22, 8, 0),
      );

      bloc.add(RouteDrawingLoadRoute(initialRoute));
      await bloc.stream.firstWhere((s) => s.status == RouteDrawingStatus.routeUpdated);

      mockCustomRouteRepo.saveDelay = const Duration(milliseconds: 100);
      final saveStarted = Completer<void>();
      mockCustomRouteRepo.onSaveStarted = () {
        if (!saveStarted.isCompleted) saveStarted.complete();
      };

      bloc.add(const RouteDrawingSaveRoute(name: 'Tuyến thử'));
      await saveStarted.future;

      // Trong lúc save đang chạy, người dùng ấn Clear
      bloc.add(const RouteDrawingClearRoute());
      await Future.delayed(const Duration(milliseconds: 150));

      // State hiện tại phải là initial do Clear, không bị đè bởi Saved status
      expect(bloc.state.status, equals(RouteDrawingStatus.initial));
      expect(bloc.state.points, isEmpty);
    });

    test('Loaded route can have new waypoint added with connected polyline and distance', () async {
      final initialRoute = CustomRouteModel(
        id: 'load_add_1',
        name: 'Tuyến thử nghiệm',
        waypoints: const [
          SnappedRoadPoint(
            isSnapped: true,
            originalLat: 10.773,
            originalLon: 106.699,
            snappedLat: 10.77305,
            snappedLon: 106.69905,
          ),
          SnappedRoadPoint(
            isSnapped: true,
            originalLat: 10.778,
            originalLon: 106.702,
            snappedLat: 10.77805,
            snappedLon: 106.70205,
          ),
        ],
        fullPolyline: const [
          [10.77305, 106.69905],
          [10.77805, 106.70205],
        ],
        totalDistance: 1200.0,
        totalTime: 150000,
        createdAt: DateTime(2026, 8, 22, 8, 0),
      );

      bloc.add(RouteDrawingLoadRoute(initialRoute));
      await bloc.stream.firstWhere((s) => s.status == RouteDrawingStatus.routeUpdated);

      expect(bloc.state.points.length, equals(2));
      expect(bloc.state.segments.length, equals(1));
      expect(bloc.state.totalDistance, equals(1200.0));

      // Thêm waypoint thứ 3 sau khi nạp route
      mockRepository.nextCalculateResult = const RouteResult(
        isSuccess: true,
        distance: 500.0,
        time: 60000,
        points: [
          [10.77805, 106.70205],
          [10.78000, 106.70500],
        ],
      );

      bloc.add(const RouteDrawingPointTapped(lat: 10.780, lon: 106.705));
      await bloc.stream.firstWhere((s) => s.status == RouteDrawingStatus.routeUpdated && s.points.length == 3);

      expect(bloc.state.points.length, equals(3));
      expect(bloc.state.segments.length, equals(2));
      expect(bloc.state.totalDistance, equals(1700.0));
      expect(bloc.state.totalTime, equals(210000));
      expect(bloc.state.fullPolyline.length, equals(3)); // [P1, P2, P3] deduplicated
    });

    test('Loaded route with added waypoint supports undo back to loaded state and redo', () async {
      final initialRoute = CustomRouteModel(
        id: 'load_undo_1',
        name: 'Tuyến kiểm thử undo',
        waypoints: const [
          SnappedRoadPoint(
            isSnapped: true,
            originalLat: 10.773,
            originalLon: 106.699,
            snappedLat: 10.77305,
            snappedLon: 106.69905,
          ),
          SnappedRoadPoint(
            isSnapped: true,
            originalLat: 10.778,
            originalLon: 106.702,
            snappedLat: 10.77805,
            snappedLon: 106.70205,
          ),
        ],
        fullPolyline: const [
          [10.77305, 106.69905],
          [10.77805, 106.70205],
        ],
        totalDistance: 1200.0,
        totalTime: 150000,
        createdAt: DateTime(2026, 8, 22, 8, 0),
      );

      bloc.add(RouteDrawingLoadRoute(initialRoute));
      await bloc.stream.firstWhere((s) => s.status == RouteDrawingStatus.routeUpdated);

      // Thêm waypoint thứ 3
      mockRepository.nextCalculateResult = const RouteResult(
        isSuccess: true,
        distance: 500.0,
        time: 60000,
        points: [
          [10.77805, 106.70205],
          [10.78000, 106.70500],
        ],
      );
      bloc.add(const RouteDrawingPointTapped(lat: 10.780, lon: 106.705));
      await bloc.stream.firstWhere((s) => s.status == RouteDrawingStatus.routeUpdated && s.points.length == 3);

      // Undo waypoint 3 -> quay lại đúng trạng thái đã load
      bloc.add(const RouteDrawingUndoLastPoint());
      await bloc.stream.firstWhere((s) => s.points.length == 2);

      expect(bloc.state.points.length, equals(2));
      expect(bloc.state.segments.length, equals(1));
      expect(bloc.state.totalDistance, equals(1200.0));
      expect(bloc.state.canRedo, isTrue);

      // Redo waypoint 3 -> phục hồi lại
      bloc.add(const RouteDrawingRedoPoint());
      await bloc.stream.firstWhere((s) => s.points.length == 3);

      expect(bloc.state.points.length, equals(3));
      expect(bloc.state.segments.length, equals(2));
      expect(bloc.state.totalDistance, equals(1700.0));
    });

    test('Save route without passing name falls back to state.savedRoute name', () async {
      final initialRoute = CustomRouteModel(
        id: 'load_save_fallback',
        name: 'Tên gốc cố định',
        waypoints: const [
          SnappedRoadPoint(
            isSnapped: true,
            originalLat: 10.773,
            originalLon: 106.699,
            snappedLat: 10.77305,
            snappedLon: 106.69905,
          ),
          SnappedRoadPoint(
            isSnapped: true,
            originalLat: 10.778,
            originalLon: 106.702,
            snappedLat: 10.77805,
            snappedLon: 106.70205,
          ),
        ],
        fullPolyline: const [
          [10.77305, 106.69905],
          [10.77805, 106.70205],
        ],
        totalDistance: 1200.0,
        totalTime: 150000,
        createdAt: DateTime(2026, 8, 22, 8, 0),
      );

      bloc.add(RouteDrawingLoadRoute(initialRoute));
      await bloc.stream.firstWhere((s) => s.status == RouteDrawingStatus.routeUpdated);

      // Save without passing name
      bloc.add(const RouteDrawingSaveRoute());
      await bloc.stream.firstWhere((s) => s.status == RouteDrawingStatus.saved);

      expect(bloc.state.savedRoute?.name, equals('Tên gốc cố định'));
    });

    test('Closing bloc while saveRoute is pending suppresses emissions cleanly without throwing', () async {
      final initialRoute = CustomRouteModel(
        id: 'load_close_1',
        name: 'Tuyến thử đóng bloc',
        waypoints: const [
          SnappedRoadPoint(
            isSnapped: true,
            originalLat: 10.773,
            originalLon: 106.699,
            snappedLat: 10.77305,
            snappedLon: 106.69905,
          ),
          SnappedRoadPoint(
            isSnapped: true,
            originalLat: 10.778,
            originalLon: 106.702,
            snappedLat: 10.77805,
            snappedLon: 106.70205,
          ),
        ],
        fullPolyline: const [
          [10.77305, 106.69905],
          [10.77805, 106.70205],
        ],
        totalDistance: 1200.0,
        totalTime: 150000,
        createdAt: DateTime(2026, 8, 22, 8, 0),
      );

      bloc.add(RouteDrawingLoadRoute(initialRoute));
      await bloc.stream.firstWhere((s) => s.status == RouteDrawingStatus.routeUpdated);

      mockCustomRouteRepo.saveDelay = const Duration(milliseconds: 100);
      final saveStarted = Completer<void>();
      mockCustomRouteRepo.onSaveStarted = () {
        if (!saveStarted.isCompleted) saveStarted.complete();
      };

      bloc.add(const RouteDrawingSaveRoute(name: 'Tuyến đóng'));
      await saveStarted.future;

      // Đóng bloc khi save đang chờ
      await bloc.close();
      await Future.delayed(const Duration(milliseconds: 150));

      expect(bloc.isClosed, isTrue);
    });
  });

  group('RouteDrawingBloc Concurrency & restartable()', () {
    test('Rapid tapping only finishes processing the latest tap event',
        () async {
      mockRepository.snapDelay = const Duration(milliseconds: 50);

      bloc.add(const RouteDrawingPointTapped(lat: 10.1, lon: 106.1));
      bloc.add(const RouteDrawingPointTapped(lat: 10.2, lon: 106.2));
      bloc.add(const RouteDrawingPointTapped(lat: 10.3, lon: 106.3));

      // Chờ state cuối cùng thay vì chờ theo thời gian cố định
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.pointAdded);

      expect(bloc.state.status, RouteDrawingStatus.pointAdded);
      expect(bloc.state.points.length, 1);
      expect(bloc.state.points.first.originalLat, 10.3);
      expect(mockRepository.snapToRoadCallCount, 3);
    });

    test(
        'Undo or clear during route calculation ignores stale route calculation result',
        () async {
      // Add P1
      bloc.add(const RouteDrawingPointTapped(lat: 10.7730, lon: 106.6990));
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.pointAdded);

      final routeStarted = Completer<void>();
      final routeRelease = Completer<void>();
      mockRepository.routeStartedCompleter = routeStarted;
      mockRepository.routeReleaseCompleter = routeRelease;

      // Add P2 (will pause in calculateRoute)
      bloc.add(const RouteDrawingPointTapped(lat: 10.7780, lon: 106.7020));

      // Wait until calculateRoute has started
      await routeStarted.future;

      // User clears route while calculateRoute is in progress
      bloc.add(const RouteDrawingClearRoute());
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.initial);

      // Release calculateRoute to complete
      routeRelease.complete();
      await pumpEventQueue();

      // Assert that state remains initial and clean, stale P2 was discarded
      expect(bloc.state.status, RouteDrawingStatus.initial);
      expect(bloc.state.points, isEmpty);
      expect(bloc.state.segments, isEmpty);
      expect(bloc.state.totalDistance, 0.0);
    });

    test(
        'Undo during snapToRoad of first point invalidates snap result and returns to initial state',
        () async {
      final snapStarted = Completer<void>();
      final snapRelease = Completer<void>();
      mockRepository.snapStartedCompleter = snapStarted;
      mockRepository.snapReleaseCompleter = snapRelease;

      // Tap P1 (will pause in snapToRoad)
      bloc.add(const RouteDrawingPointTapped(lat: 10.7730, lon: 106.6990));

      // Wait until snapToRoad has started
      await snapStarted.future;

      // User hits Undo while P1 is still in flight (points is still empty)
      bloc.add(const RouteDrawingUndoLastPoint());
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.initial);

      // Release snapToRoad
      snapRelease.complete();
      await pumpEventQueue();

      // Assert that state remains initial and clean, stale P1 was discarded
      expect(bloc.state.status, RouteDrawingStatus.initial);
      expect(bloc.state.points, isEmpty);
      expect(bloc.state.segments, isEmpty);
      expect(bloc.state.totalDistance, 0.0);
    });

    test(
        'Clear during snapToRoad ignores stale snap result and prevents adding point',
        () async {
      final snapStarted = Completer<void>();
      final snapRelease = Completer<void>();
      mockRepository.snapStartedCompleter = snapStarted;
      mockRepository.snapReleaseCompleter = snapRelease;

      // Tap P1 (will pause in snapToRoad)
      bloc.add(const RouteDrawingPointTapped(lat: 10.7730, lon: 106.6990));

      // Wait until snapToRoad has started
      await snapStarted.future;

      // User clears route while snapToRoad is in progress
      bloc.add(const RouteDrawingClearRoute());
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.initial);

      // Release snapToRoad
      snapRelease.complete();
      await pumpEventQueue();

      // Assert that state remains initial and clean, stale P1 was discarded
      expect(bloc.state.status, RouteDrawingStatus.initial);
      expect(bloc.state.points, isEmpty);
      expect(bloc.state.segments, isEmpty);
      expect(bloc.state.totalDistance, 0.0);
    });

    test(
        'Redo during initial snapToRoad when redoPoints is empty invalidates snap result and returns to initial state',
        () async {
      final snapStarted = Completer<void>();
      final snapRelease = Completer<void>();
      mockRepository.snapStartedCompleter = snapStarted;
      mockRepository.snapReleaseCompleter = snapRelease;

      // Tap P1 (will pause in snapToRoad)
      bloc.add(const RouteDrawingPointTapped(lat: 10.7730, lon: 106.6990));

      // Wait until snapToRoad has started
      await snapStarted.future;

      // User hits Redo while P1 is still in flight (redoPoints is empty)
      bloc.add(const RouteDrawingRedoPoint());
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.initial);

      // Release snapToRoad
      snapRelease.complete();
      await pumpEventQueue();

      // Assert that state remains initial and clean, stale P1 was discarded
      expect(bloc.state.status, RouteDrawingStatus.initial);
      expect(bloc.state.points, isEmpty);
      expect(bloc.state.segments, isEmpty);
      expect(bloc.state.totalDistance, 0.0);
    });

    test(
        'Redo during route calculation of second point when redoPoints is empty invalidates route calculation and restores pointAdded state',
        () async {
      // Add P1
      bloc.add(const RouteDrawingPointTapped(lat: 10.7730, lon: 106.6990));
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.pointAdded);

      final routeStarted = Completer<void>();
      final routeRelease = Completer<void>();
      mockRepository.routeStartedCompleter = routeStarted;
      mockRepository.routeReleaseCompleter = routeRelease;

      // Add P2 (will pause in calculateRoute)
      bloc.add(const RouteDrawingPointTapped(lat: 10.7780, lon: 106.7020));

      // Wait until calculateRoute has started
      await routeStarted.future;

      // User hits Redo while calculateRoute is in progress (redoPoints is empty)
      bloc.add(const RouteDrawingRedoPoint());
      await bloc.stream
          .firstWhere((s) => s.status == RouteDrawingStatus.pointAdded);

      // Release calculateRoute
      routeRelease.complete();
      await pumpEventQueue();

      // Assert that state remains pointAdded with 1 point, stale P2 was discarded
      expect(bloc.state.status, RouteDrawingStatus.pointAdded);
      expect(bloc.state.points.length, 1);
      expect(bloc.state.segments, isEmpty);
      expect(bloc.state.totalDistance, 0.0);
    });
  });
}
