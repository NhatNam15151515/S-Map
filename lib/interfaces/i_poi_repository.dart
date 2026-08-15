import 'package:s_map/models/poi_model.dart';

abstract class IPoiRepository {
  /// Tìm kiếm theo tên (FTS5 có dấu hoặc exact query)
  Future<List<PoiModel>> searchByName(String query, {int limit = 20});

  /// Tìm kiếm theo tên không dấu (FTS5 name_ascii query)
  Future<List<PoiModel>> searchByNameAscii(String query, {int limit = 20});

  /// Tìm kiếm tự động phát hiện có dấu / không dấu (Unified Search)
  Future<List<PoiModel>> search(String query, {int limit = 20});

  /// Tìm kiếm địa điểm nằm trong Bounding Box sử dụng chỉ mục R*Tree
  Future<List<PoiModel>> searchInBounds({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    int limit = 50,
  });

  /// Lấy thông tin POI theo ID
  Future<PoiModel?> getPoiById(int id);
}
