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

  /// Lấy phiên bản schema hiện tại của cơ sở dữ liệu POI (1: Legacy, 2: Hierarchical Scoped)
  Future<int> getSchemaVersion() async => 1;

  /// Lấy danh sách mã các tỉnh láng giềng kề cận với tỉnh có mã [provinceCode]
  Future<List<String>> getNeighborProvinces(String provinceCode) async => const [];

  /// Tra cứu danh sách tuyến đường trong phạm vi tỉnh / quận
  Future<List<StreetModel>> findStreets({
    required String nameQuery,
    String? provinceCode,
    String? districtCode,
    int limit = 10,
  }) async =>
      const [];

  /// Tra cứu hoặc suy diễn số nhà gần đúng nhất trên một tuyến đường cụ thể
  Future<List<PoiModel>> findHouseNumbers({
    required int streetId,
    int? targetHouseNo,
    int limit = 10,
  }) async =>
      const [];

  /// Tìm kiếm FTS5 có phân vùng phạm vi hành chính (Scoped FTS)
  Future<List<PoiModel>> searchScoped({
    required String query,
    String? provinceCode,
    String? districtCode,
    int? streetId,
    int limit = 20,
  }) async =>
      search(query, limit: limit);

  /// Lấy danh sách các đơn vị hành chính trong CSDL (cấp 4: tỉnh, cấp 6: quận/huyện)
  Future<List<AdminUnitModel>> getAdminUnits({int? level}) async => const [];
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
