import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RouteDrawingBloc Waypoint Features Tests', () {
    late _FakeRoutingRepo routingRepo;
    late RouteDrawingBloc bloc;

    setUp(() {
      routingRepo = _FakeRoutingRepo();
      bloc = RouteDrawingBloc(routingRepository: routingRepo);
    });

    tearDown(() async {
      await bloc.close();
    });

    test('RouteDrawingToggleSegmentStraightLine toggles segment between straight and road',
        () async {
      // Thêm 2 điểm ban đầu
      bloc.add(const RouteDrawingPointTapped(lat: 10.1, lon: 106.1));
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const RouteDrawingPointTapped(lat: 10.2, lon: 106.2));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(bloc.state.points.length, 2);
      expect(bloc.state.segments.length, 1);
      expect(bloc.state.segments[0].isStraightLine, isFalse);

      // Toggle segment 0 sang đường chim bay
      bloc.add(const RouteDrawingToggleSegmentStraightLine(0));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.segments[0].isStraightLine, isTrue);

      // Toggle lại sang đường theo map
      bloc.add(const RouteDrawingToggleSegmentStraightLine(0));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.segments[0].isStraightLine, isFalse);
    });

    test('RouteDrawingReorderPoints reorders waypoints and recalculates segments',
        () async {
      bloc.add(const RouteDrawingPointTapped(lat: 10.1, lon: 106.1));
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const RouteDrawingPointTapped(lat: 10.2, lon: 106.2));
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const RouteDrawingPointTapped(lat: 10.3, lon: 106.3));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(bloc.state.points.length, 3);
      expect(bloc.state.points[0].snappedLat, 10.1);
      expect(bloc.state.points[1].snappedLat, 10.2);
      expect(bloc.state.points[2].snappedLat, 10.3);

      // Kéo điểm 0 xuống cuối (chuyển 10.1 về index 2)
      bloc.add(const RouteDrawingReorderPoints(0, 3));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(bloc.state.points.length, 3);
      expect(bloc.state.points[0].snappedLat, 10.2);
      expect(bloc.state.points[1].snappedLat, 10.3);
      expect(bloc.state.points[2].snappedLat, 10.1);
      expect(bloc.state.segments.length, 2);
    });

    test('RouteDrawingRemovePoint removes specific waypoint and updates route',
        () async {
      bloc.add(const RouteDrawingPointTapped(lat: 10.1, lon: 106.1));
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const RouteDrawingPointTapped(lat: 10.2, lon: 106.2));
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const RouteDrawingPointTapped(lat: 10.3, lon: 106.3));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(bloc.state.points.length, 3);

      // Xóa điểm ở giữa (index 1)
      bloc.add(const RouteDrawingRemovePoint(1));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(bloc.state.points.length, 2);
      expect(bloc.state.points[0].snappedLat, 10.1);
      expect(bloc.state.points[1].snappedLat, 10.3);
      expect(bloc.state.segments.length, 1);
    });

    test('RouteDrawingPointTapped appends destination point', () async {
      bloc.add(const RouteDrawingPointTapped(lat: 10.1, lon: 106.1));
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(const RouteDrawingPointTapped(lat: 10.2, lon: 106.2));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(bloc.state.points.length, 2);
      expect(bloc.state.points.last.snappedLat, 10.2);
      expect(bloc.state.segments.length, 1);
    });
  });
}
