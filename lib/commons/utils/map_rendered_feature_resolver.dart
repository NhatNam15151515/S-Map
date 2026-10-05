import 'dart:math';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/app_utils.dart';
import 'package:s_map/commons/utils/map_geometry_utils.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';

/// Helper chuyên trách giải mã (decode) và làm giàu (enrich) thông tin POI
/// từ các Map Feature (Vector Tiles) khi người dùng chạm vào bản đồ.
class MapRenderedFeatureResolver {
  final IPoiRepository _poiRepository;

  MapRenderedFeatureResolver({IPoiRepository? poiRepository})
      : _poiRepository = poiRepository ?? AppReposProvider.instance.poiRepos;

  /// Giải mã POI tại vị trí chạm màn hình ([point], [latLng]).
  ///
  /// 1. Query rendered features từ engine MapLibre.
  /// 2. Parse các properties OSM ('name:vi', 'amenity', v.v.).
  /// 3. Chọn candidate tốt nhất theo điểm đánh giá và enrich từ SQLite DB.
  /// 4. Fallback tra cứu SQLite trong bán kính ~80-90m quanh điểm chạm nếu tile thiếu metadata.
  Future<PoiModel?> resolvePoiAtTap({
    required MapLibreMapController? controller,
    required Point<double> point,
    required LatLng latLng,
  }) async {
    if (controller == null) return null;

    try {
      final features =
          await controller.queryRenderedFeatures(point, const [], null);
      final candidates = <PoiModel>[];
      for (final rawFeature in features) {
        if (rawFeature is! Map) continue;
        final rawProperties = rawFeature['properties'];
        if (rawProperties is! Map) continue;
        final properties = Map<String, dynamic>.from(rawProperties);
        final poi = _poiFromRenderedProperties(properties, latLng);
        if (poi != null) candidates.add(poi);
      }

      if (candidates.isNotEmpty) {
        candidates
            .sort((a, b) => _poiFeatureScore(b).compareTo(_poiFeatureScore(a)));
        return await _enrichRenderedPoi(candidates.first);
      }

      // Một số tile chỉ chứa hình học/label, không mang đủ metadata POI.
      // Tra cứu thêm trong DB offline quanh vị trí chạm để lấy thông tin đầy đủ.
      const delta = 0.0008; // khoảng 80–90 m quanh điểm chạm
      final nearby = await _poiRepository.searchInBounds(
        minLat: latLng.latitude - delta,
        maxLat: latLng.latitude + delta,
        minLon: latLng.longitude - delta,
        maxLon: latLng.longitude + delta,
        limit: 10,
      );
      if (nearby.isEmpty) return null;
      final cosRef = cos(latLng.latitude * MapGeometryUtils.degToRad);
      nearby.sort((a, b) {
        final da = MapGeometryUtils.fastDistanceSqMeters(
            cosRef, latLng.latitude, latLng.longitude, a.lat, a.lon);
        final db = MapGeometryUtils.fastDistanceSqMeters(
            cosRef, latLng.latitude, latLng.longitude, b.lat, b.lon);
        return da.compareTo(db);
      });
      return nearby.first;
    } catch (e, stack) {
      DLog.warning(
          '⚠️ [MapRenderedFeatureResolver] Không đọc được feature tại vị trí chạm: $e',
          stack);
      return null;
    }
  }

  PoiModel? _poiFromRenderedProperties(
    Map<String, dynamic> properties,
    LatLng fallbackLocation,
  ) {
    String value(List<String> keys) {
      for (final key in keys) {
        final raw = properties[key];
        if (raw != null && raw.toString().trim().isNotEmpty) {
          return raw.toString();
        }
      }
      return '';
    }

    final name = value(['name:vi', 'name', 'name_vi', 'name:en']);
    final category = value([
      'category',
      'amenity',
      'tourism',
      'shop',
      'leisure',
      'historic',
      'public_transport',
      'place',
    ]);
    if (name.isEmpty ||
        (category.isEmpty &&
            value(['address', 'addr:street', 'street']).isEmpty)) {
      return null;
    }

    final idValue = value(['id', 'osm_id', '@id']);
    return PoiModel(
      id: int.tryParse(idValue),
      osmId: idValue.isEmpty ? null : idValue,
      name: name,
      nameAscii: AppUtils.instance.toAscii(name),
      category: category.isEmpty ? 'place' : category,
      subCategory: value(['sub_category', 'subclass', 'type']),
      lat: fallbackLocation.latitude,
      lon: fallbackLocation.longitude,
      address: value(['address', 'addr:full']),
      street: value(['street', 'addr:street']),
      housenumber: value(['housenumber', 'addr:housenumber']),
      city: value(['city', 'addr:city']),
    );
  }

  int _poiFeatureScore(PoiModel poi) {
    final category = (poi.category ?? '').toLowerCase();
    return category == 'place' ? 1 : 3;
  }

  Future<PoiModel> _enrichRenderedPoi(PoiModel poi) async {
    final nearby = await _poiRepository.searchInBounds(
      minLat: poi.lat - 0.0008,
      maxLat: poi.lat + 0.0008,
      minLon: poi.lon - 0.0008,
      maxLon: poi.lon + 0.0008,
      query: poi.name,
      limit: 5,
    );
    if (nearby.isEmpty) return poi;
    final cosRef = cos(poi.lat * MapGeometryUtils.degToRad);
    nearby.sort((a, b) {
      final da = MapGeometryUtils.fastDistanceSqMeters(
          cosRef, poi.lat, poi.lon, a.lat, a.lon);
      final db = MapGeometryUtils.fastDistanceSqMeters(
          cosRef, poi.lat, poi.lon, b.lat, b.lon);
      return da.compareTo(db);
    });
    return nearby.first;
  }
}
