import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/services/search_cache_service.dart';

void main() {
  late SearchCacheService service;

  const poi = PoiModel(
    id: 42,
    osmId: 'node-42',
    name: 'Cà phê S-Map',
    nameAscii: 'Ca phe S-Map',
    category: 'coffee',
    lat: 10.78,
    lon: 106.64,
  );

  setUp(() {
    service = SearchCacheService();
    service.clear();
  });

  test('stores and reads POI results with the requested limit', () {
    const key = 'cache-test-pois';
    service.putPois(key, [poi, poi]);

    final results = service.getPois(key, limit: 1);

    expect(results, hasLength(1));
    expect(results!.single.name, poi.name);
    expect(results.single.category, poi.category);
  });

  test('stores and reads autocomplete suggestions', () {
    const key = 'cache-test-suggestions';
    service.putSuggestions(key, ['Cà phê S-Map', 'Cà phê gần đây']);

    final results = service.getSuggestions(key, limit: 1);

    expect(results, ['Cà phê S-Map']);
  });

  test('evicts the oldest entries after reaching the memory limit', () {
    for (var i = 0; i < SearchCacheService.maxEntries + 1; i++) {
      service.putSuggestions('key-$i', ['result-$i']);
    }

    expect(service.getSuggestions('key-0', limit: 1), isNull);
    expect(
      service.getSuggestions(
        'key-${SearchCacheService.maxEntries}',
        limit: 1,
      ),
      ['result-${SearchCacheService.maxEntries}'],
    );
  });
}
