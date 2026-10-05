import 'package:s_map/models/models.dart';

abstract class IFavoritesService {
  /// Khởi tạo và mở Hive box
  Future<void> init();

  /// Lấy toàn bộ danh sách địa điểm đã lưu
  Future<List<PoiModel>> getFavorites();

  /// Thêm địa điểm vào danh sách yêu thích
  Future<void> addFavorite(PoiModel poi);

  /// Xóa địa điểm khỏi danh sách yêu thích theo POI identifier (id hoặc osmId hoặc name)
  Future<void> removeFavorite(String poiId);

  /// Kiểm tra xem địa điểm đã được yêu thích hay chưa
  Future<bool> isFavorite(String poiId);

  /// Xóa toàn bộ danh sách yêu thích
  Future<void> clearFavorites();

  /// Stream lắng nghe cập nhật realtime của danh sách yêu thích
  Stream<List<PoiModel>> watchFavorites();
}
