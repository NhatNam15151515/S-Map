import 'package:s_map/models/models.dart';

abstract class IRegionRepository {
  /// Lấy danh sách vùng kèm trạng thái tải hiện tại
  Future<List<RegionModel>> getRegions();

  /// Tải vùng dữ liệu theo ID
  Future<void> downloadRegion(
    String regionId, {
    void Function(double progress)? onProgress,
  });

  /// Xóa vùng dữ liệu theo ID
  Future<void> deleteRegion(String regionId);

  /// Kiểm tra bản cập nhật cho tất cả các vùng đã tải
  Future<List<RegionModel>> checkForUpdates();

  /// Hủy tiến trình tải của một vùng
  Future<void> cancelDownload(String regionId);

  /// Lấy tổng dung lượng bộ nhớ đang sử dụng cho bản đồ offline
  Future<int> getTotalStorageUsage();

  /// Stream cập nhật tiến trình tải các vùng (Map<regionId, progress>)
  Stream<Map<String, double>> get downloadProgressStream;
}
