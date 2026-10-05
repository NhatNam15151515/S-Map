import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

/// Kết quả đầu ra của thuật toán tìm kiếm khu vực mở rộng tiệm tiến
class ProgressiveAreaSearchResult {
  final List<PoiModel> pois;
  final LatLngBounds? bounds;
  final double resolvedZoomLevel;
  final bool isSuccess;

  const ProgressiveAreaSearchResult.success({
    required this.pois,
    required this.bounds,
    required this.resolvedZoomLevel,
  }) : isSuccess = true;

  const ProgressiveAreaSearchResult.empty({
    required this.resolvedZoomLevel,
  })  : pois = const [],
        bounds = null,
        isSuccess = false;
}

/// Domain UseCase: Xử lý nghiệp vụ tìm kiếm địa điểm mở rộng bán kính theo mức Zoom
/// (Progressive Area Search Algorithm)
///
/// Nguyên lý Google Maps:
/// 1. Bắt đầu từ mức zoom hiện tại của camera, mở rộng dần bán kính tìm kiếm (radius expansion).
/// 2. Với text query, sử dụng location bias thay vì hard radius (lấy thêm ứng viên toàn cục).
/// 3. Hợp nhất (merge) và xếp hạng (rank) theo độ liên quan ngữ nghĩa + khoảng cách thực tế.
class ProgressiveAreaSearchUseCase {
  final IPoiRepository _poiRepository;

  const ProgressiveAreaSearchUseCase({required IPoiRepository poiRepository})
      : _poiRepository = poiRepository;

  Future<ProgressiveAreaSearchResult> execute({
    required LatLng center,
    required double initialZoom,
    required String? query,
    required String category,
    required int limit,
    required bool Function() isCancelled,
  }) async {
    var globalTextCandidates = const <PoiModel>[];
    var globalTextLoaded = false;

    for (final entry in MapConstants.areaSearchZoomToRadiusKm.entries) {
      if (entry.key > initialZoom) continue;
      if (isCancelled()) {
        return const ProgressiveAreaSearchResult.empty(
          resolvedZoomLevel: MapConstants.areaSearchMinZoom,
        );
      }

      final radiusKm = entry.value;
      final bounds = MapConstants.boundsFromCenter(center, radiusKm);
      final localCandidates = await _poiRepository.searchInBounds(
        minLat: bounds.southwest.latitude,
        maxLat: bounds.northeast.latitude,
        minLon: bounds.southwest.longitude,
        maxLon: bounds.northeast.longitude,
        query: query,
        category: category == CategoryConstants.all ? null : category,
        limit: limit,
      );

      if (query != null && !globalTextLoaded) {
        globalTextLoaded = true;
        // Text search của Google dùng location bias, không phải hard radius.
        // Lấy thêm ứng viên toàn cục rồi rank relevance + distance.
        globalTextCandidates = await _poiRepository.search(
          query,
          limit: limit < 100 ? 100 : limit,
        );
      }

      final radiusCandidates = localCandidates
          .where((poi) => _isWithinRadius(poi, center, radiusKm))
          .toList();
      final candidates = query == null
          ? radiusCandidates
          : [...radiusCandidates, ...globalTextCandidates];

      if (candidates.isNotEmpty) {
        final pois = SearchResultRanker.rank(
          candidates,
          center: center,
          query: query,
          limit: limit,
        );
        if (pois.isEmpty) continue;

        if (isCancelled()) {
          return const ProgressiveAreaSearchResult.empty(
            resolvedZoomLevel: MapConstants.areaSearchMinZoom,
          );
        }

        return ProgressiveAreaSearchResult.success(
          pois: pois,
          bounds: bounds,
          resolvedZoomLevel: entry.key,
        );
      }
    }

    return const ProgressiveAreaSearchResult.empty(
      resolvedZoomLevel: MapConstants.areaSearchMinZoom,
    );
  }

  static bool _isWithinRadius(PoiModel poi, LatLng center, double radiusKm) {
    final distance = AppUtils.instance.calculateDistance(
      center.latitude,
      center.longitude,
      poi.lat,
      poi.lon,
    );
    return distance <= radiusKm * 1.05;
  }
}
