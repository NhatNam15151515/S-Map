import 'package:s_map/models/models.dart';

abstract class IPoiRepository {
  /// Tìm kiếm theo tên và địa chỉ (FTS5 có dấu hoặc exact query)
  Future<List<PoiModel>> searchByName(String query, {int limit = 20});

  /// Tìm kiếm theo tên/địa chỉ không dấu (FTS5 name_ascii và address query)
  Future<List<PoiModel>> searchByNameAscii(String query, {int limit = 20});

  /// Tìm kiếm tự động phát hiện có dấu / không dấu và địa chỉ (Unified Search)
  Future<List<PoiModel>> search(String query, {int limit = 20});

  /// Tìm kiếm địa điểm nằm trong Bounding Box sử dụng chỉ mục R*Tree (có thể kết hợp từ khóa lọc)
  Future<List<PoiModel>> searchInBounds({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    String? query,
    String? category,
    int limit = 50,
  });

  /// Lấy danh sách từ khóa gợi ý tìm kiếm (Autocomplete Suggestions)
  Future<List<String>> getSuggestions(String query, {int limit = 10});

  /// Lấy thông tin POI theo ID
  Future<PoiModel?> getPoiById(int id);

}

extension PoiRepositoryBatchExtension on IPoiRepository {
  Future<List<PoiModel>> getPoisByIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final results = <PoiModel>[];
    for (final id in ids) {
      final poi = await getPoiById(id);
      if (poi != null) results.add(poi);
    }
    return results;
  }
}
