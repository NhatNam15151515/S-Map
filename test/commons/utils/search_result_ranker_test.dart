import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/utils/search_result_ranker.dart';
import 'package:s_map/models/models.dart';

void main() {
  test('text ranking prefers an exact name over a closer partial match', () {
    const nearbyPartial = PoiModel(
      id: 1,
      name: 'Rex Hotel gần bạn',
      nameAscii: 'Rex Hotel gan ban',
      category: 'hotel',
      lat: 10.78,
      lon: 106.70,
    );
    const exactMatch = PoiModel(
      id: 2,
      name: 'Khách sạn Rex',
      nameAscii: 'Khach san Rex',
      category: 'hotel',
      lat: 10.90,
      lon: 106.70,
    );

    final ranked = SearchResultRanker.rank(
      [nearbyPartial, exactMatch],
      center: const LatLng(10.78, 106.70),
      query: 'Khach san Rex',
    );

    expect(ranked.first.id, 2);
  });

  test('category ranking uses distance when no text query is present', () {
    const near = PoiModel(
      id: 1,
      name: 'Điểm gần',
      nameAscii: 'Diem gan',
      category: 'coffee',
      lat: 10.78,
      lon: 106.70,
    );
    const far = PoiModel(
      id: 2,
      name: 'Điểm xa',
      nameAscii: 'Diem xa',
      category: 'coffee',
      lat: 10.90,
      lon: 106.70,
    );

    final ranked = SearchResultRanker.rank(
      [far, near],
      center: const LatLng(10.78, 106.70),
    );

    expect(ranked.map((poi) => poi.id), [1, 2]);
  });
}
