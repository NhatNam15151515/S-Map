import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/services/visited_poi_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDirectory;
  late VisitedPoiServiceImpl service;

  const poi = PoiModel(
    osmId: 'osm-visited-1',
    name: 'Quán đã đến',
    nameAscii: 'Quan da den',
    category: 'cafe',
    lat: 10.7823,
    lon: 106.64346,
  );

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('smap_visited_');
    Hive.init(hiveDirectory.path);
  });

  setUp(() async {
    service = VisitedPoiServiceImpl();
    await service.init();
    await service.clearVisitedPois();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  test('records a visited POI in Hive and deduplicates repeated visits',
      () async {
    await service.recordVisited(poi);
    await service.recordVisited(poi);

    final visited = await service.getVisitedPois();
    expect(visited, hasLength(1));
    expect(visited.single.name, poi.name);
    expect(visited.single.lat, poi.lat);
    expect(visited.single.lon, poi.lon);
  });

  test('clearVisitedPois removes the local visited history', () async {
    await service.recordVisited(poi);
    await service.clearVisitedPois();

    expect(await service.getVisitedPois(), isEmpty);
  });
}
