import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/models/models.dart';

class FakeMapController extends Fake implements MapLibreMapController {
  final List<LineOptions> addedLines = [];
  final List<SymbolOptions> addedSymbols = [];
  final List<Line> removedLines = [];
  final List<Symbol> removedSymbols = [];
  int _nextId = 1;

  @override
  Future<void> addImage(String name, Uint8List bytes, [bool defer = false]) async {}

  @override
  Future<Line> addLine(LineOptions options, [Map<String, dynamic>? data]) async {
    addedLines.add(options);
    return Line('line_${_nextId++}', options);
  }

  @override
  Future<Symbol> addSymbol(SymbolOptions options, [Map<String, dynamic>? data]) async {
    addedSymbols.add(options);
    return Symbol('symbol_${_nextId++}', options);
  }

  @override
  Future<void> removeLine(Line line) async {
    removedLines.add(line);
  }

  @override
  Future<void> removeSymbol(Symbol symbol) async {
    removedSymbols.add(symbol);
  }

  @override
  Future<bool?> animateCamera(CameraUpdate cameraUpdate, {Duration? duration}) async => true;
}

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

    test('drawCustomRoute renders lines and waypoint symbols with FakeMapController', () async {
      final fakeController = FakeMapController();
      final waypoints = [
        const SnappedRoadPoint(
          isSnapped: true,
          originalLat: 10.7,
          originalLon: 106.7,
          snappedLat: 10.7,
          snappedLon: 106.7,
        ),
        const SnappedRoadPoint(
          isSnapped: true,
          originalLat: 10.75,
          originalLon: 106.75,
          snappedLat: 10.75,
          snappedLon: 106.75,
        ),
        const SnappedRoadPoint(
          isSnapped: true,
          originalLat: 10.8,
          originalLon: 106.8,
          snappedLat: 10.8,
          snappedLon: 106.8,
        ),
      ];
      final polyline = [
        const RoutePoint(lat: 10.7, lon: 106.7),
        const RoutePoint(lat: 10.75, lon: 106.75),
        const RoutePoint(lat: 10.8, lon: 106.8),
      ];

      final result = await manager.drawCustomRoute(
        controller: fakeController,
        points: waypoints,
        fullPolyline: polyline,
      );

      expect(result, isTrue);
      // 2 lines: casing line + main line
      expect(fakeController.addedLines.length, 2);
      // 3 symbols for 3 waypoints: A, 1, B
      expect(fakeController.addedSymbols.length, 3);
      expect(fakeController.addedSymbols[0].textField, 'A');
      expect(fakeController.addedSymbols[1].textField, '1');
      expect(fakeController.addedSymbols[2].textField, 'B');

      // Test clear removes all
      await manager.clear(fakeController);
      expect(fakeController.removedLines.length, 2);
      expect(fakeController.removedSymbols.length, 3);
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

    test('fitRouteBounds animates camera on valid points with FakeMapController', () async {
      final fakeController = FakeMapController();
      final waypoints = [
        const SnappedRoadPoint(
          isSnapped: true,
          originalLat: 10.7,
          originalLon: 106.7,
          snappedLat: 10.7,
          snappedLon: 106.7,
        ),
        const SnappedRoadPoint(
          isSnapped: true,
          originalLat: 10.8,
          originalLon: 106.8,
          snappedLat: 10.8,
          snappedLon: 106.8,
        ),
      ];

      await expectLater(
        manager.fitRouteBounds(
          controller: fakeController,
          points: waypoints,
        ),
        completes,
      );
    });
  });
}
