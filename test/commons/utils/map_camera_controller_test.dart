import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/utils/map_camera_controller.dart';

void main() {
  group('MapCameraController Tests', () {
    test('getCenter calculates exact middle coordinate of bounds', () {
      final bounds = LatLngBounds(
        southwest: const LatLng(10.0, 106.0),
        northeast: const LatLng(11.0, 108.0),
      );

      final center = MapCameraController.getCenter(bounds);
      expect(center.latitude, closeTo(10.5, 0.0001));
      expect(center.longitude, closeTo(107.0, 0.0001));
    });

    test('hasMovedBeyondThreshold returns false when lastBounds is null', () {
      final currentBounds = LatLngBounds(
        southwest: const LatLng(10.0, 106.0),
        northeast: const LatLng(11.0, 108.0),
      );

      final moved = MapCameraController.hasMovedBeyondThreshold(
        currentBounds: currentBounds,
        lastBounds: null,
      );
      expect(moved, isFalse);
    });

    test('hasMovedBeyondThreshold returns false when camera moved very little', () {
      final b1 = LatLngBounds(
        southwest: const LatLng(10.7700, 106.6900),
        northeast: const LatLng(10.7800, 106.7000),
      );
      // Small 50-meter shift
      final b2 = LatLngBounds(
        southwest: const LatLng(10.7705, 106.6905),
        northeast: const LatLng(10.7805, 106.7005),
      );

      final moved = MapCameraController.hasMovedBeyondThreshold(
        currentBounds: b2,
        lastBounds: b1,
        thresholdKm: 0.8,
      );
      expect(moved, isFalse);
    });

    test('hasMovedBeyondThreshold returns true when camera moved significantly', () {
      final b1 = LatLngBounds(
        southwest: const LatLng(10.7700, 106.6900),
        northeast: const LatLng(10.7800, 106.7000),
      );
      // Large 5km shift
      final b2 = LatLngBounds(
        southwest: const LatLng(10.8200, 106.7400),
        northeast: const LatLng(10.8300, 106.7500),
      );

      final moved = MapCameraController.hasMovedBeyondThreshold(
        currentBounds: b2,
        lastBounds: b1,
        thresholdKm: 0.8,
      );
      expect(moved, isTrue);
    });

    test('reset clears lastSearchedBounds', () {
      final controller = MapCameraController();
      controller.lastSearchedBounds = LatLngBounds(
        southwest: const LatLng(10.0, 106.0),
        northeast: const LatLng(11.0, 108.0),
      );
      expect(controller.lastSearchedBounds, isNotNull);

      controller.reset();
      expect(controller.lastSearchedBounds, isNull);
    });
  });
}
