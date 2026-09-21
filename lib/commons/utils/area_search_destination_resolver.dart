import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/utils/search_result_ranker.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/interfaces/i_poi_repository.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';

/// Giải quyết kết quả Area Search từ màn hình tìm kiếm thành một điểm đến [PoiModel] cụ thể
/// phục vụ cho việc tạo lộ trình (Route Drawing / Navigation).
///
/// Tránh việc khởi tạo trực tiếp Repository trong UI layer và hỗ trợ Dependency Injection.
class AreaSearchDestinationResolver {
  final IPoiRepository _poiRepository;

  AreaSearchDestinationResolver({
    IPoiRepository? poiRepository,
  }) : _poiRepository = poiRepository ?? AppReposProvider.instance.poiRepos;

  Future<PoiModel?> resolve(
    SearchResultPayload payload, {
    required LatLng center,
  }) async {
    final query = payload.submittedQuery?.trim();
    try {
      List<PoiModel> candidates;
      if (query != null && query.isNotEmpty) {
        candidates = await _poiRepository.search(query, limit: 50);
      } else if (payload.searchCategory != null &&
          payload.searchCategory!.trim().isNotEmpty) {
        final bounds = MapConstants.boundsFromCenter(center, 1200.0);
        candidates = await _poiRepository.searchInBounds(
          minLat: bounds.southwest.latitude,
          maxLat: bounds.northeast.latitude,
          minLon: bounds.southwest.longitude,
          maxLon: bounds.northeast.longitude,
          category: payload.searchCategory,
          limit: 50,
        );
      } else {
        return null;
      }

      final ranked = SearchResultRanker.rank(
        candidates,
        center: center,
        query: query,
        limit: 1,
      );
      return ranked.isEmpty ? null : ranked.first;
    } catch (_) {
      return null;
    }
  }
}
