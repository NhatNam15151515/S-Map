import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/utils/map_route_manager.dart';
import 'package:s_map/models/models.dart';

class FakeRouteMapController extends Fake implements MapLibreMapController {
  final List<Line> activeLines = [];
  final List<Symbol> activeSymbols = [];
  int _nextId = 1;

  @override
  Future<void> addImage(String name, Uint8List bytes,
      [bool defer = false]) async {}

  @override
  Future<Line> addLine(LineOptions options,
      [Map<String, dynamic>? data]) async {
    final line = Line('line_${_nextId++}', options);
    activeLines.add(line);
    return line;
  }

  @override
  Future<void> removeLine(Line line) async {
    activeLines.remove(line);
  }

  @override
  Future<Symbol> addSymbol(SymbolOptions options,
      [Map<String, dynamic>? data]) async {
    final symbol = Symbol('symbol_${_nextId++}', options, data);
    activeSymbols.add(symbol);
    return symbol;
  }

  @override
  Future<void> removeSymbol(Symbol symbol) async {
    activeSymbols.remove(symbol);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    test('drawRoute keeps a native destination marker and clearRoute removes it', () async {
      final controller = FakeRouteMapController();
      final manager = MapRouteManager();
      const origin = RoutePoint(lat: 10.7000, lon: 106.7000);
      const destination = RoutePoint(lat: 10.8000, lon: 106.8000);
      const route = RouteResult(
        isSuccess: true,
        points: [
          [10.7000, 106.7000],
          [10.7500, 106.7500],
          [10.8000, 106.8000],
        ],
      );

      final drawn = await manager.drawRoute(
        controller: controller,
        routeResult: route,
        origin: origin,
        destination: destination,
        destinationName: 'Điểm đích',
      );

      expect(drawn, isTrue);
      expect(controller.activeSymbols, hasLength(1));
      expect(
        controller.activeSymbols.single.options.geometry,
        equals(const LatLng(10.8000, 106.8000)),
      );

      await manager.clearRoute(controller);
      expect(controller.activeSymbols, isEmpty);
      expect(controller.activeLines, isEmpty);
    });
  });
}
