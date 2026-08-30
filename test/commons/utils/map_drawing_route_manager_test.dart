import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/models/models.dart';

class FakeMapController extends Fake implements MapLibreMapController {
  final List<LineOptions> addedLines = [];
  final List<Line> removedLines = [];
  final Set<Line> activeLines = {};
  final Map<String, Map<String, dynamic>> geoJsonSources = {};
  final List<String> addedSymbolLayers = [];
  int _nextId = 1;

  @override
  Future<void> addImage(String name, Uint8List bytes, [bool defer = false]) async {}

  @override
  Future<void> addGeoJsonSource(String sourceId, Map<String, dynamic> geojson, {String? promoteId}) async {
    geoJsonSources[sourceId] = geojson;
  }

  @override
  Future<void> setGeoJsonSource(String sourceId, Map<String, dynamic> geojson) async {
    geoJsonSources[sourceId] = geojson;
  }

  @override
  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    SymbolLayerProperties properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    bool enableInteraction = true,
  }) async {
    addedSymbolLayers.add(layerId);
  }

  @override
  Future<Line> addLine(LineOptions options, [Map<String, dynamic>? data]) async {
    addedLines.add(options);
    final line = Line('line_${_nextId++}', options);
    activeLines.add(line);
    return line;
  }

  @override
  Future<void> removeLine(Line line) async {
    activeLines.remove(line);
    removedLines.add(line);
  }

  int animateCameraCalls = 0;

  @override
  Future<bool?> animateCamera(CameraUpdate cameraUpdate, {Duration? duration}) async {
    animateCameraCalls++;
    return true;
  }
}

class DelayedFakeMapController extends FakeMapController {
  Completer<void>? lineGate;
  final Completer<void> lineReached = Completer<void>();

  @override
  Future<Line> addLine(LineOptions options, [Map<String, dynamic>? data]) async {
    if (!lineReached.isCompleted) {
      lineReached.complete();
    }
    if (lineGate != null && !lineGate!.isCompleted) {
      await lineGate!.future;
    }
    return super.addLine(options, data);
  }
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
      // 3 waypoints via GeoJSON source
      final wpSource = fakeController.geoJsonSources['smap-drawing-waypoints-source'];
      expect(wpSource, isNotNull);
      final features = wpSource!['features'] as List;
      expect(features.length, 3);
      expect(features[0]['properties']['name'], 'A');
      expect(features[1]['properties']['name'], '1');
      expect(features[2]['properties']['name'], 'B');

      // Test clear removes all
      await manager.clear(fakeController);
      expect(fakeController.removedLines.length, 2);
      final clearedWpSource = fakeController.geoJsonSources['smap-drawing-waypoints-source'];
      expect((clearedWpSource!['features'] as List), isEmpty);
    });

    test('drawCustomRoute cancels previous render when new render starts and cleans up orphaned lines', () async {
      final delayedController = DelayedFakeMapController();
      delayedController.lineGate = Completer<void>();

      final waypoints1 = [
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
      final polyline1 = [
        const RoutePoint(lat: 10.7, lon: 106.7),
        const RoutePoint(lat: 10.8, lon: 106.8),
      ];

      final waypoints2 = [
        const SnappedRoadPoint(
          isSnapped: true,
          originalLat: 10.1,
          originalLon: 106.1,
          snappedLat: 10.1,
          snappedLon: 106.1,
        ),
        const SnappedRoadPoint(
          isSnapped: true,
          originalLat: 10.2,
          originalLon: 106.2,
          snappedLat: 10.2,
          snappedLon: 106.2,
        ),
      ];
      final polyline2 = [
        const RoutePoint(lat: 10.1, lon: 106.1),
        const RoutePoint(lat: 10.2, lon: 106.2),
      ];

      // Start first render (will be paused at addLine)
      final firstRenderFuture = manager.drawCustomRoute(
        controller: delayedController,
        points: waypoints1,
        fullPolyline: polyline1,
      );

      // Wait until first render reaches addLine
      await delayedController.lineReached.future;

      // Start second render with distinct geometry (bumps generation)
      final secondRenderFuture = manager.drawCustomRoute(
        controller: delayedController,
        points: waypoints2,
        fullPolyline: polyline2,
      );

      // Now release first line gate
      delayedController.lineGate!.complete();

      final firstResult = await firstRenderFuture;
      final secondResult = await secondRenderFuture;

      expect(firstResult, isFalse);
      expect(secondResult, isTrue);

      // Assert first render's casing line was removed exactly once
      expect(delayedController.removedLines.length, 1);
      expect(
        delayedController.removedLines.first.options.geometry?.first.latitude,
        closeTo(10.7, 0.0001),
      );

      // Assert only the two lines from the second render remain active
      expect(delayedController.activeLines.length, 2);
      for (final activeLine in delayedController.activeLines) {
        expect(activeLine.options.geometry?.first.latitude, closeTo(10.1, 0.0001));
      }
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

      await manager.fitRouteBounds(
        controller: fakeController,
        points: waypoints,
      );

      expect(fakeController.animateCameraCalls, 1);
    });
  });
}
