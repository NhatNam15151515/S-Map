import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/utils/map_route_manager.dart';

void main() {
  group('MapRouteManager Unit Tests', () {
    test('parseRoutePoints parses 2D coordinate lists into LatLng instances', () {
      final raw = [
        [21.0285, 105.8542],
        [21.0350, 105.8450],
        [1.0], // invalid - should be skipped
        <double>[], // invalid - should be skipped
      ];

      final parsed = MapRouteManager.parseRoutePoints(raw);
      expect(parsed.length, equals(2));
      expect(parsed[0].latitude, closeTo(21.0285, 0.0001));
      expect(parsed[0].longitude, closeTo(105.8542, 0.0001));
      expect(parsed[1].latitude, closeTo(21.0350, 0.0001));
      expect(parsed[1].longitude, closeTo(105.8450, 0.0001));
    });

    test('calculateRouteBounds returns null when points list is empty', () {
      final bounds = MapRouteManager.calculateRouteBounds([]);
      expect(bounds, isNull);
    });

    test('calculateRouteBounds calculates correct bounding box for valid coordinates', () {
      final points = MapRouteManager.parseRoutePoints([
        [21.0200, 105.8000],
        [21.0500, 105.8500],
        [21.0300, 105.8700],
      ]);

      final bounds = MapRouteManager.calculateRouteBounds(points);
      expect(bounds, isNotNull);
      expect(bounds!.southwest.latitude, closeTo(21.0200, 0.0001));
      expect(bounds.southwest.longitude, closeTo(105.8000, 0.0001));
      expect(bounds.northeast.latitude, closeTo(21.0500, 0.0001));
      expect(bounds.northeast.longitude, closeTo(105.8700, 0.0001));
    });
  });
}
