import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';

class MockRegionDownloadService implements IRegionDownloadService {
  final List<RegionModel> regions = [
    const RegionModel(
      id: 'metro_hcm',
      name: 'Vùng TP.HCM',
      description: 'TP.HCM, Bình Dương, Đồng Nai, Long An',
      bbox: [106.10, 10.35, 107.25, 11.35],
      downloadUrl: 'https://example.com/metro_hcm.zip',
      sizeBytes: 4509903,
      version: '1.0.0',
    ),
    const RegionModel(
      id: 'metro_hn',
      name: 'Vùng Hà Nội',
      description: 'Hà Nội, Bắc Ninh, Hưng Yên, Vĩnh Phúc',
      bbox: [105.30, 20.60, 106.30, 21.40],
      downloadUrl: 'https://example.com/metro_hn.zip',
      sizeBytes: 4718592,
      version: '1.0.0',
    ),
  ];

  bool shouldThrow = false;
  final Set<String> downloadedIds = {};

  @override
  Future<List<RegionModel>> getAvailableRegions() async {
    if (shouldThrow) throw Exception('Get available regions failed');
    return regions.map((r) {
      if (downloadedIds.contains(r.id)) {
        return r.copyWith(
          status: RegionDownloadStatus.downloaded,
          localVersion: r.version,
          downloadProgress: 1.0,
        );
      }
      return r;
    }).toList();
  }

  @override
  Future<List<RegionModel>> getDownloadedRegions() async {
    if (shouldThrow) throw Exception('Get downloaded regions failed');
    final all = await getAvailableRegions();
    return all.where((r) => downloadedIds.contains(r.id)).toList();
  }

  @override
  Future<RegionModel?> checkRegionVersion(String regionId) async {
    if (shouldThrow) throw Exception('Check region version failed');
    try {
      final region = regions.firstWhere((r) => r.id == regionId);
      // Return newer version to test update detection
      return region.copyWith(version: '1.1.0');
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<double> downloadAndExtractRegion(
    RegionModel region, {
    void Function(double progress)? onProgress,
    String? customDownloadUrl,
  }) async* {
    if (shouldThrow) throw Exception('Download failed');
    yield 0.25;
    onProgress?.call(0.25);
    yield 0.75;
    onProgress?.call(0.75);
    downloadedIds.add(region.id);
    yield 1.0;
    onProgress?.call(1.0);
  }

  @override
  Future<void> deleteRegion(String regionId) async {
    if (shouldThrow) throw Exception('Delete failed');
    downloadedIds.remove(regionId);
  }

  @override
  Future<void> cancelDownload(String regionId) async {
    if (shouldThrow) throw Exception('Cancel failed');
  }

  @override
  Future<int> getTotalOfflineStorageUsage() async {
    if (shouldThrow) throw Exception('Storage usage failed');
    return downloadedIds.length * 4509903;
  }
}

void main() {
  late MockRegionDownloadService mockService;
  late RegionRepositoryImpl repository;

  setUp(() {
    mockService = MockRegionDownloadService();
    repository = RegionRepositoryImpl(service: mockService);
  });

  tearDown(() {
    repository.dispose();
  });

  group('RegionRepositoryImpl Tests', () {
    test('getRegions returns available regions from service', () async {
      final list = await repository.getRegions();
      expect(list.length, 2);
      expect(list.first.id, equals('metro_hcm'));
    });

    test('downloadRegion emits progress updates to stream and marks region downloaded', () async {
      final progressList = <Map<String, double>>[];
      final sub = repository.downloadProgressStream.listen(progressList.add);

      await repository.downloadRegion('metro_hcm');
      await Future.delayed(const Duration(milliseconds: 10));

      await sub.cancel();
      expect(mockService.downloadedIds, contains('metro_hcm'));

      final regions = await repository.getRegions();
      expect(regions.first.isDownloaded, isTrue);
    });

    test('deleteRegion removes region from downloaded set', () async {
      await repository.downloadRegion('metro_hcm');
      expect(mockService.downloadedIds, contains('metro_hcm'));

      await repository.deleteRegion('metro_hcm');
      expect(mockService.downloadedIds, isNot(contains('metro_hcm')));
    });

    test('checkForUpdates identifies regions with newer remote version while preserving full list', () async {
      mockService.downloadedIds.add('metro_hcm');

      final updated = await repository.checkForUpdates();
      expect(updated.length, 2);
      expect(updated.first.id, equals('metro_hcm'));
      expect(updated.first.status, equals(RegionDownloadStatus.updateAvailable));
      expect(updated[1].id, equals('metro_hn'));
      expect(updated[1].status, equals(RegionDownloadStatus.notDownloaded));
    });

    test('getTotalStorageUsage returns total storage from service', () async {
      mockService.downloadedIds.add('metro_hcm');
      final bytes = await repository.getTotalStorageUsage();
      expect(bytes, equals(4509903));
    });

    test('rethrows exceptions when underlying service fails', () async {
      mockService.shouldThrow = true;
      expect(() => repository.getRegions(), throwsA(isA<Exception>()));
      expect(() => repository.downloadRegion('metro_hcm'), throwsA(isA<Exception>()));
    });
  });

  group('NoOpRegionRepository Tests', () {
    test('NoOpRegionRepository returns safe defaults', () async {
      final noOp = NoOpRegionRepository();
      final regions = await noOp.getRegions();
      expect(regions.isNotEmpty, isTrue);

      await noOp.downloadRegion('metro_hcm');
      await noOp.deleteRegion('metro_hcm');
      expect(await noOp.getTotalStorageUsage(), equals(0));
    });
  });
}
