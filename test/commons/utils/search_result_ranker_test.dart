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

  test('accented query strictly prefers exact diacritic match over unaccented or other accents', () {
    const wrongAccent = PoiModel(
      id: 10,
      name: 'Hổ Tây Quán',
      nameAscii: 'Ho Tay Quan',
      lat: 21.05,
      lon: 105.82,
    );
    const exactAccent = PoiModel(
      id: 20,
      name: 'Hồ Tây',
      nameAscii: 'Ho Tay',
      lat: 21.06,
      lon: 105.83,
    );
    const partialMatch = PoiModel(
      id: 30,
      name: 'Hồ Gươm',
      nameAscii: 'Ho Guom',
      lat: 21.02,
      lon: 105.85,
    );

    final ranked = SearchResultRanker.rank(
      [wrongAccent, partialMatch, exactAccent],
      query: 'Hồ Tây',
    );

    expect(ranked.first.id, 20); // Hồ Tây must be top
    expect(ranked.any((poi) => poi.id == 10), isTrue);
    // exactAccent must rank before wrongAccent
    expect(ranked.indexWhere((p) => p.id == 20), lessThan(ranked.indexWhere((p) => p.id == 10)));
  });

  test('unaccented query still successfully finds and ranks accented POIs', () {
    const poi = PoiModel(
      id: 100,
      name: 'Hồ Hoàn Kiếm',
      nameAscii: 'Ho Hoan Kiem',
      lat: 21.02,
      lon: 105.85,
    );
    const unrelated = PoiModel(
      id: 200,
      name: 'Sân bay Nội Bài',
      nameAscii: 'San bay Noi Bai',
      lat: 21.22,
      lon: 105.80,
    );

    final ranked = SearchResultRanker.rank(
      [unrelated, poi],
      query: 'ho hoan kiem',
    );

    expect(ranked.first.id, 100);
  });

  test('word-boundary prefix match ranks higher than mid-word match', () {
    const wordBoundaryMatch = PoiModel(
      id: 1,
      name: 'Chợ Bến Thành',
      nameAscii: 'Cho Ben Thanh',
      lat: 10.77,
      lon: 106.69,
    );
    const midWordMatch = PoiModel(
      id: 2,
      name: 'Khách sạn Hoàn Thành Đạt',
      nameAscii: 'Khach san Hoan Thanh Dat',
      lat: 10.77,
      lon: 106.69,
    );

    final ranked = SearchResultRanker.rank(
      [midWordMatch, wordBoundaryMatch],
      query: 'Bến Thành',
    );

    expect(ranked.first.id, 1);
  });

  test('decomposed Unicode (NFD) from mobile keyboards matches precomposed NFC', () {
    const poi = PoiModel(
      id: 1,
      name: 'Hồ Tây', // NFC: \u1ED3
      nameAscii: 'Ho Tay',
      lat: 21.05,
      lon: 105.82,
    );
    // NFD: 'H' + 'o' + '\u0302' + '\u0300' + ' ' + 'T' + 'a' + 'y'
    const nfdQuery = 'Ho\u0302\u0300 Tay';

    final ranked = SearchResultRanker.rank(
      [poi],
      query: nfdQuery,
    );

    expect(ranked.first.id, 1);
  });

  test('partial matches blend distance so closer place with similar relevance wins', () {
    const closeCafe = PoiModel(
      id: 1,
      name: 'Quán Cà Phê Gần',
      nameAscii: 'Quan Ca Phe Gan',
      category: 'coffee',
      lat: 10.770,
      lon: 106.690,
    );
    const farCafe = PoiModel(
      id: 2,
      name: 'Quán Cà Phê Rất Xa',
      nameAscii: 'Quan Ca Phe Rat Xa',
      category: 'coffee',
      lat: 11.500, // ~100 km away
      lon: 107.200,
    );

    final ranked = SearchResultRanker.rank(
      [farCafe, closeCafe],
      center: const LatLng(10.770, 106.690),
      query: 'Cà Phê',
    );

    expect(ranked.first.id, 1);
  });

  test('prominence breaks ties for equivalent partial matches', () {
    const prominent = PoiModel(
      id: 1,
      name: 'Khu bệnh viện Chợ Rẫy',
      nameAscii: 'Khu benh vien Cho Ray',
      category: 'hospital',
      prominence: 220,
      lat: 10.76,
      lon: 106.66,
    );
    const ordinary = PoiModel(
      id: 2,
      name: 'Khu bệnh viện tư',
      nameAscii: 'Khu benh vien tu',
      category: 'hospital',
      prominence: 20,
      lat: 10.76,
      lon: 106.66,
    );

    final ranked = SearchResultRanker.rank(
      [ordinary, prominent],
      query: 'ện',
    );

    expect(ranked.first.id, 1);
  });

  test('nearby search excludes distant partial address matches', () {
    const nearby = PoiModel(
      id: 1,
      name: 'Cửa hàng gần đây',
      nameAscii: 'Cua hang gan day',
      address: 'Đường Lý Thường Kiệt',
      lat: 10.781,
      lon: 106.691,
    );
    const distant = PoiModel(
      id: 2,
      name: 'Bánh kem TP Cà Mau',
      nameAscii: 'Banh kem TP Ca Mau',
      address: '116 Đường Lý Thường Kiệt, Cà Mau',
      lat: 9.176,
      lon: 105.15,
    );

    final ranked = SearchResultRanker.rank(
      [distant, nearby],
      center: const LatLng(10.780, 106.690),
      query: 'lý',
      maxDistanceKm: SearchResultRanker.defaultNearbySearchRadiusKm,
    );

    expect(ranked.map((poi) => poi.id), [1]);
  });
}
