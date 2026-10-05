import 'package:s_map/models/models.dart';

abstract class IRegionDownloadService {
  /// Lấy danh sách toàn bộ các vùng có sẵn (bao gồm cả 5 vùng trọng điểm)
  Future<List<RegionModel>> getAvailableRegions();

  /// Lấy danh sách các vùng đã được tải về máy
  Future<List<RegionModel>> getDownloadedRegions();

  /// Kiểm tra phiên bản mới của vùng trên server
  Future<RegionModel?> checkRegionVersion(String regionId);

  /// Tải về và giải nén gói dữ liệu zip của một vùng (stream phát ra tiến trình 0.0 -> 1.0)
  Stream<double> downloadAndExtractRegion(
    RegionModel region, {
    void Function(double progress)? onProgress,
    String? customDownloadUrl,
  });

  /// Xóa dữ liệu offline của một vùng đã tải
  Future<void> deleteRegion(String regionId);

  /// Hủy quá trình tải xuống đang diễn ra của một vùng
  Future<void> cancelDownload(String regionId);

  /// Lấy tổng dung lượng bộ nhớ (bytes) mà dữ liệu offline đang chiếm dụng
  Future<int> getTotalOfflineStorageUsage();
}
