import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class MockRegionRepository implements IRegionRepository {
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

  final StreamController<Map<String, double>> _progressController =
      StreamController<Map<String, double>>.broadcast();
  final Set<String> downloadedIds = {};
  final Set<String> cancelledIds = {};
  bool shouldThrow = false;

  void emitProgress(Map<String, double> progress) {
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }

  @override
  Stream<Map<String, double>> get downloadProgressStream =>
      _progressController.stream;

  @override
  Future<List<RegionModel>> getRegions() async {
    if (shouldThrow) throw Exception('Fetch regions failed');
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
  Future<void> downloadRegion(
    String regionId, {
    void Function(double progress)? onProgress,
  }) async {
    if (shouldThrow) throw Exception('Download region failed');
    _progressController.add({regionId: 0.5});
    onProgress?.call(0.5);
    await Future.delayed(const Duration(milliseconds: 10));
    if (cancelledIds.contains(regionId)) {
      throw const DownloadCancelledException();
    }
    downloadedIds.add(regionId);
    _progressController.add({regionId: 1.0});
    onProgress?.call(1.0);
  }

  @override
  Future<void> deleteRegion(String regionId) async {
    if (shouldThrow) throw Exception('Delete region failed');
    downloadedIds.remove(regionId);
  }

  @override
  Future<List<RegionModel>> checkForUpdates() async {
    if (shouldThrow) throw Exception('Check for updates failed');
    return regions.map((r) {
      if (downloadedIds.contains(r.id)) {
        return r.copyWith(status: RegionDownloadStatus.updateAvailable);
      }
      return r;
    }).toList();
  }

  @override
  Future<void> cancelDownload(String regionId) async {
    if (shouldThrow) throw Exception('Cancel download failed');
    cancelledIds.add(regionId);
    _progressController.add({});
  }

  @override
  Future<int> getTotalStorageUsage() async {
    if (shouldThrow) throw Exception('Storage calculation failed');
    return downloadedIds.length * 4509903;
  }

  void dispose() {
    _progressController.close();
  }
}

void main() {
  late MockRegionRepository mockRepository;
  late DownloadRegionCubit cubit;

  setUp(() async {
    mockRepository = MockRegionRepository();
    cubit = DownloadRegionCubit(repository: mockRepository);
    await cubit.loadRegions();
  });

  tearDown(() async {
    await cubit.close();
    mockRepository.dispose();
  });

  group('DownloadRegionCubit Tests', () {
    test(
        'initial state and loadRegions loads available regions and storage usage',
        () async {
      expect(cubit.state.status, equals(DownloadRegionStatus.loaded));
      expect(cubit.state.regions.length, equals(2));
      expect(cubit.state.totalStorageBytes, equals(0));
      expect(cubit.state.downloadedRegionsCount, equals(0));
      expect(cubit.state.formattedTotalStorage, equals('0 MB'));
    });

    test(
        'downloadRegion triggers downloading state, progress stream updates and completes with success',
        () async {
      final states = <DownloadRegionState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.downloadRegion('metro_hcm');

      await sub.cancel();

      expect(cubit.state.status, equals(DownloadRegionStatus.success));
      expect(cubit.state.downloadedRegionsCount, equals(1));
      expect(cubit.state.totalStorageBytes, equals(4509903));
      expect(cubit.state.isDownloading('metro_hcm'), isFalse);
      expect(cubit.state.getRegion('metro_hcm')?.isDownloaded, isTrue);
    });

    test('deleteRegion removes downloaded region and updates storage',
        () async {
      await cubit.downloadRegion('metro_hcm');
      expect(cubit.state.downloadedRegionsCount, equals(1));

      await cubit.deleteRegion('metro_hcm');
      expect(cubit.state.downloadedRegionsCount, equals(0));
      expect(cubit.state.totalStorageBytes, equals(0));
    });

    test('checkForUpdates updates region status to updateAvailable', () async {
      await cubit.downloadRegion('metro_hcm');
      await cubit.checkForUpdates();

      final region = cubit.state.getRegion('metro_hcm');
      expect(region?.hasUpdate, isTrue);
    });

    test(
        'cancelDownload cancels active download and clears downloading region and keeps loaded state',
        () async {
      final downloadFuture = cubit.downloadRegion('metro_hcm');
      await Future.delayed(const Duration(milliseconds: 1));
      expect(cubit.state.currentlyDownloadingRegionId, equals('metro_hcm'));

      await cubit.cancelDownload('metro_hcm');
      await downloadFuture;

      expect(cubit.state.status, equals(DownloadRegionStatus.loaded));
      expect(cubit.state.currentlyDownloadingRegionId, isNull);
      expect(cubit.state.isDownloading('metro_hcm'), isFalse);
    });

    test('downloadRegion handles exception gracefully and emits error state',
        () async {
      mockRepository.shouldThrow = true;

      await cubit.downloadRegion('metro_hcm');
      expect(cubit.state.status, equals(DownloadRegionStatus.error));
      expect(cubit.state.errorMessage, isNotNull);
      expect(cubit.state.isDownloadingAny, isFalse);
    });
    test(
        '[DLR-08] isClosed guard — progress stream emit after close does not throw',
        () async {
      await cubit.loadRegions();
      expect(cubit.state.status, equals(DownloadRegionStatus.loaded));

      await cubit.close();

      // Emitting on the progress stream after cubit is closed should NOT throw
      mockRepository.emitProgress({'metro_hcm': 0.5});
      await pumpEventQueue();

      // If we reach here, no StateError was thrown
      expect(cubit.isClosed, isTrue);
    });

    test('[DLR-09] NaN progress value does not crash the cubit', () async {
      await cubit.loadRegions();
      expect(cubit.state.status, equals(DownloadRegionStatus.loaded));

      // Emit NaN progress — app should NOT crash
      mockRepository.emitProgress({'metro_hcm': double.nan});
      await pumpEventQueue();

      // The cubit should still be alive and state should reflect the progress map
      expect(cubit.state.progressMap.containsKey('metro_hcm'), isTrue);
      // Value is NaN but cubit didn't crash
      expect(cubit.state.progressMap['metro_hcm']?.isNaN, isTrue);
    });
  });
}
