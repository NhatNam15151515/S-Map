import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/route_drawing/widgets/widgets.dart';

class _FakeRoutingRepo implements IRoutingRepository {
  @override
  Future<RouteResult> calculateRoute({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    String? vehicleProfile,
  }) async {
    return RouteResult(
      isSuccess: true,
      distance: 1000.0,
      time: 60000,
      points: [
        [fromLat, fromLon],
        [toLat, toLon],
      ],
      isStraightLine: false,
    );
  }

  @override
  Future<List<RouteResult>> calculateAlternativeRoutes({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    String? vehicleProfile,
  }) async =>
      [];

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

void main() {
  late RouteDrawingBloc drawingBloc;
  late MapDisplayCubit mapDisplayCubit;
  late RouteDrawingDestinationController destController;
  bool stateChangedCalled = false;

  setUp(() {
    drawingBloc = RouteDrawingBloc(
      routingRepository: _FakeRoutingRepo(),
      customRouteRepository: const NoOpCustomRouteRepository(),
    );
    mapDisplayCubit = MapDisplayCubit();
    stateChangedCalled = false;

    destController = RouteDrawingDestinationController(
      mapDisplayCubit: mapDisplayCubit,
      drawingBloc: drawingBloc,
      areaSearchResolver: AreaSearchDestinationResolver(),
      onStateChanged: () => stateChangedCalled = true,
    );
  });

  tearDown(() {
    drawingBloc.close();
    mapDisplayCubit.close();
  });

  group('RouteDrawingDestinationController applyDestination Rule Tests', () {
    test('when points are empty, applyDestination calls setupInitialRoute', () async {
      expect(drawingBloc.state.points.isEmpty, isTrue);

      const target = LatLng(10.7765, 106.7009);
      destController.applyDestination(target);

      expect(stateChangedCalled, isTrue);
      expect(destController.markerDestination, equals(target));
      expect(destController.isMarkerDestinationActive, isTrue);

      await expectLater(
        drawingBloc.stream,
        emitsThrough(predicate<RouteDrawingState>((state) =>
            state.points.length == 2 &&
            state.points.last.snappedLat == target.latitude)),
      );
    });

    test('when points are not empty, applyDestination calls addWaypointToRoute', () async {
      // Setup initial point
      drawingBloc.emit(const RouteDrawingState(
        points: [
          SnappedRoadPoint(
            originalLat: 10.7626,
            originalLon: 106.6601,
            snappedLat: 10.7626,
            snappedLon: 106.6601,
            isSnapped: true,
            distanceToRoad: 0,
          ),
        ],
      ));

      expect(drawingBloc.state.points.isNotEmpty, isTrue);

      const nextTarget = LatLng(10.7800, 106.7050);
      destController.applyDestination(nextTarget);

      expect(destController.markerDestination, equals(nextTarget));
      expect(destController.isMarkerDestinationActive, isTrue);

      await expectLater(
        drawingBloc.stream,
        emitsThrough(predicate<RouteDrawingState>((state) =>
            state.points.length == 2 &&
            state.points.last.originalLat == nextTarget.latitude)),
      );
    });
  });
}
