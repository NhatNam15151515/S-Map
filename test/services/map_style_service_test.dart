import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/services/map_style_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapStyleService Tests', () {
    test('instance returns singleton and provides empty strings before init in test', () {
      final service = MapStyleService.instance;
      expect(service.styleJson, isA<String>());
      expect(service.nightStyleJson, isA<String>());
    });

    test('getStyleJson returns appropriate style for day and night', () {
      final service = MapStyleService();
      expect(service.getStyleJson(isDarkMode: false), equals(''));
      expect(service.getStyleJson(isDarkMode: true), equals(''));
    });

    test('init handles missing bundle gracefully without throwing', () async {
      final service = MapStyleService();
      await expectLater(service.init(), completes);
    });

    test('builds a local vector style from the downloaded PMTiles package',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('smap-style-test');
      final pmtiles = File('${tempDir.path}/vietnam.pmtiles');
      await pmtiles.writeAsBytes(List<int>.filled(128, 0));

      try {
        final service = MapStyleService(
          regionDownloadService: _FakeDownloadedRegionService(tempDir.path),
        );
        await service.init();

        final light = jsonDecode(service.getStyleJson()) as Map<String, dynamic>;
        final dark = jsonDecode(
          service.getStyleJson(isDarkMode: true),
        ) as Map<String, dynamic>;

        expect(service.hasOfflineMap, isTrue);
        expect(
          (light['sources'] as Map<String, dynamic>)['smap-vietnam'],
          isNotNull,
        );
        expect(
          ((light['sources'] as Map<String, dynamic>)['smap-vietnam']
              as Map<String, dynamic>)['url'],
          startsWith('pmtiles://file:'),
        );
        expect(service.getStyleJson(), isNot(contains('__')));
        expect(light['layers'], isNotEmpty);
        expect(dark['layers'], isNotEmpty);
        expect(light['layers'], isNot(equals(dark['layers'])));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}

class _FakeDownloadedRegionService implements IRegionDownloadService {
  final String directory;

  _FakeDownloadedRegionService(this.directory);

  @override
  Future<void> cancelDownload(String regionId) async {}

  @override
  Future<RegionModel?> checkRegionVersion(String regionId) async => null;

  @override
  Stream<double> downloadAndExtractRegion(
    RegionModel region, {
    void Function(double progress)? onProgress,
    String? customDownloadUrl,
  }) async* {}

  @override
  Future<void> deleteRegion(String regionId) async {}

  @override
  Future<List<RegionModel>> getAvailableRegions() async => getDownloadedRegions();

  @override
  Future<List<RegionModel>> getDownloadedRegions() async => [
        RegionModel(
          id: 'vietnam',
          name: 'Vietnam',
          description: 'test',
          bbox: const [102.1, 8.5, 109.5, 23.4],
          downloadUrl: 'test://vietnam.zip',
          sizeBytes: 128,
          version: 'test',
          status: RegionDownloadStatus.downloaded,
          localPath: directory,
        ),
      ];

  @override
  Future<int> getTotalOfflineStorageUsage() async => 128;
}
