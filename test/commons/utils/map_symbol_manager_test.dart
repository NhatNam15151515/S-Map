import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/utils/map_symbol_manager.dart';
import 'package:s_map/models/models.dart';

void main() {
  group('MapSymbolManager Tests', () {
    test('calculateBoundingBox returns null when list is empty', () {
      final bounds = MapSymbolManager.calculateBoundingBox([]);
      expect(bounds, isNull);
    });

    test('calculateBoundingBox calculates correct min/max bounds for POIs', () {
      const poi1 = PoiModel(
        id: 1,
        name: 'Điểm 1',
        nameAscii: 'Diem 1',
        lat: 10.7000,
        lon: 106.6000,
      );
      const poi2 = PoiModel(
        id: 2,
        name: 'Điểm 2',
        nameAscii: 'Diem 2',
        lat: 10.8000,
        lon: 106.7500,
      );
      const poi3 = PoiModel(
        id: 3,
        name: 'Điểm 3',
        nameAscii: 'Diem 3',
        lat: 10.6500,
        lon: 106.7000,
      );

      final bounds = MapSymbolManager.calculateBoundingBox([poi1, poi2, poi3]);
      expect(bounds, isNotNull);
      expect(bounds!.southwest.latitude, closeTo(10.6500, 0.0001));
      expect(bounds.southwest.longitude, closeTo(106.6000, 0.0001));
      expect(bounds.northeast.latitude, closeTo(10.8000, 0.0001));
      expect(bounds.northeast.longitude, closeTo(106.7500, 0.0001));
    });

    test('getPoiBySymbolId returns null for non-existent symbol', () {
      final manager = MapSymbolManager();
      expect(manager.getPoiBySymbolId('unknown_id'), isNull);
    });

    test('clearAll resets internal state', () {
      final manager = MapSymbolManager();
      manager.clearAll(null);
      expect(manager.getPoiBySymbolId('any'), isNull);
    });
  });
}
