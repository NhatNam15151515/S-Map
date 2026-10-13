import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/services/services.dart';

class NoOpRegionRepository implements IRegionRepository {
  final List<RegionModel> _regions;

  NoOpRegionRepository({List<RegionModel>? regions})
      : _regions = regions ?? RegionDownloadServiceImpl.defaultRegions;

  @override
  Stream<Map<String, double>> get downloadProgressStream => const Stream.empty();

  @override
  Future<List<RegionModel>> getRegions() async => _regions;

  @override
  Future<void> downloadRegion(
    String regionId, {
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(1.0);
  }

  @override
  Future<void> deleteRegion(String regionId) async {}

  @override
  Future<List<RegionModel>> checkForUpdates() async => _regions;

  @override
  Future<void> cancelDownload(String regionId) async {}

  @override
  Future<int> getTotalStorageUsage() async => 0;
}
