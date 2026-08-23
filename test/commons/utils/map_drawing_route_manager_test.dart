import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapDrawingRouteManager Unit Tests', () {
    late MapDrawingRouteManager manager;

    setUp(() {
      manager = MapDrawingRouteManager();
    });

    test('parseRoutePoints converts List<RoutePoint> to List<LatLng>', () {
      final points = [
        const RoutePoint(lat: 10.762622, lon: 106.660172),
        const RoutePoint(lat: 10.776530, lon: 106.700980),
      ];

      final latLngs = MapDrawingRouteManager.parseRoutePoints(points);
      expect(latLngs.length, 2);
      expect(latLngs[0].latitude, closeTo(10.762622, 0.0001));
      expect(latLngs[0].longitude, closeTo(106.660172, 0.0001));
      expect(latLngs[1].latitude, closeTo(10.776530, 0.0001));
      expect(latLngs[1].longitude, closeTo(106.700980, 0.0001));
    });

    test('calculateBounds returns null for empty list', () {
      final bounds = MapDrawingRouteManager.calculateBounds([]);
      expect(bounds, isNull);
    });

    test('calculateBounds calculates correct bounding box for points', () {
      final points = [
        const LatLng(10.0, 106.0),
        const LatLng(10.5, 106.8),
        const LatLng(10.2, 106.4),
      ];

      final bounds = MapDrawingRouteManager.calculateBounds(points);
      expect(bounds, isNotNull);
      expect(bounds!.southwest.latitude, closeTo(10.0, 0.0001));
      expect(bounds.southwest.longitude, closeTo(106.0, 0.0001));
      expect(bounds.northeast.latitude, closeTo(10.5, 0.0001));
      expect(bounds.northeast.longitude, closeTo(106.8, 0.0001));
    });

    test('clear handles null controller without throwing', () async {
      await expectLater(manager.clear(null), completes);
    });

    test('drawCustomRoute handles null controller and returns false', () async {
      final result = await manager.drawCustomRoute(
        controller: null,
        points: const [],
        fullPolyline: const [],
      );
      expect(result, isFalse);
    });

    test('fitRouteBounds handles null controller and empty points gracefully', () async {
      await expectLater(
        manager.fitRouteBounds(
          controller: null,
          points: const [],
        ),
        completes,
      );
    });
  });
}
