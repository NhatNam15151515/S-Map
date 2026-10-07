import 'dart:async';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/services/services.dart';

class RegionRepositoryImpl implements IRegionRepository {
  final IRegionDownloadService _service;
  final StreamController<Map<String, double>> _progressController =
      StreamController<Map<String, double>>.broadcast();
  final Map<String, double> _currentProgressMap = {};

  RegionRepositoryImpl({IRegionDownloadService? service})
      : _service = service ?? RegionDownloadServiceImpl.instance;

  static final RegionRepositoryImpl instance = RegionRepositoryImpl();

  @override
  Stream<Map<String, double>> get downloadProgressStream =>
      _progressController.stream;

  @override
  Future<List<RegionModel>> getRegions() async {
    return _service.getAvailableRegions();
  }

  @override
  Future<void> downloadRegion(
    String regionId, {
    void Function(double progress)? onProgress,
  }) async {
    final regions = await _service.getAvailableRegions();
    final region = regions.firstWhere(
      (r) => r.id == regionId,
      orElse: () => throw ArgumentError('Không tìm thấy vùng với mã ID: $regionId'),
    );

    _currentProgressMap[regionId] = 0.0;
    _progressController.add(Map.unmodifiable(_currentProgressMap));

    try {
      await for (final progress in _service.downloadAndExtractRegion(region)) {
        _currentProgressMap[regionId] = progress;
        _progressController.add(Map.unmodifiable(_currentProgressMap));
        onProgress?.call(progress);
      }
    } catch (e) {
      DLog.error('❌ [RegionRepository] Lỗi tải vùng $regionId: $e');
      rethrow;
    } finally {
      _currentProgressMap.remove(regionId);
      _progressController.add(Map.unmodifiable(_currentProgressMap));
    }
  }

  @override
  Future<void> deleteRegion(String regionId) async {
    await _service.deleteRegion(regionId);
  }

  @override
  Future<List<RegionModel>> checkForUpdates() async {
    final regions = await _service.getAvailableRegions();
    final updatedList = <RegionModel>[];

    for (final region in regions) {
      final latest = await _service.checkRegionVersion(region.id);
      if (latest != null &&
          region.isDownloaded &&
          latest.version != region.localVersion) {
        updatedList.add(region.copyWith(
          version: latest.version,
          downloadUrl: latest.downloadUrl,
          sizeBytes: latest.sizeBytes,
          status: RegionDownloadStatus.updateAvailable,
        ));
      } else {
        updatedList.add(region.copyWith(
          version: latest?.version ?? region.version,
          downloadUrl: latest?.downloadUrl ?? region.downloadUrl,
          sizeBytes: latest?.sizeBytes ?? region.sizeBytes,
        ));
      }
    }

    return updatedList;
  }

  @override
  Future<void> cancelDownload(String regionId) async {
    await _service.cancelDownload(regionId);
    _currentProgressMap.remove(regionId);
    _progressController.add(Map.unmodifiable(_currentProgressMap));
  }

  @override
  Future<int> getTotalStorageUsage() async {
    return _service.getTotalOfflineStorageUsage();
  }

  void dispose() {
    _progressController.close();
  }
}
