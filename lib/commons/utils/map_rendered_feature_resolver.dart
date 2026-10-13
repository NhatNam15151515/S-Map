import 'dart:math';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/di/app_repos_provider.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/app_utils.dart';
import 'package:s_map/commons/utils/map_geometry_utils.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class _RenderedPoiCandidate {
  const _RenderedPoiCandidate({required this.poi, required this.feature});

  final PoiModel poi;
  final Map feature;
}

/// Helper chuyên trách giải mã (decode) và làm giàu (enrich) thông tin POI
/// từ các Map Feature (Vector Tiles) khi người dùng chạm vào bản đồ.
class MapRenderedFeatureResolver {
  final IPoiRepository _poiRepository;
  MapLibreMapController? _selectedFeatureController;
  String? _selectedFeatureId;
  PoiModel? _selectedFeaturePoi;

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
      // POI icons are rendered by a static style layer, not by the annotation
      // manager. Query that layer explicitly so overlapping road labels and
      // other vector features cannot steal the tap.
      List<dynamic> poiLayerFeatures = const [];
      try {
        poiLayerFeatures = await controller.queryRenderedFeatures(
          point,
          const ['smap-poi-markers'],
          null,
        );
      } catch (e) {
        // Online styles may not include our offline POI layer.
        DLog.info(
            'ℹ️ [MapRenderedFeatureResolver] POI style layer unavailable: $e');
      }

      final poiLayerCandidates = <_RenderedPoiCandidate>[];
      for (final rawFeature in poiLayerFeatures) {
        if (rawFeature is! Map || rawFeature['properties'] is! Map) continue;
        final poi = _poiFromRenderedProperties(
          Map<String, dynamic>.from(rawFeature['properties'] as Map),
          latLng,
          allowClassCategory: true,
        );
        if (poi != null) {
          poiLayerCandidates.add(
            _RenderedPoiCandidate(poi: poi, feature: rawFeature),
          );
        }
      }
      if (poiLayerCandidates.isNotEmpty) {
        poiLayerCandidates.sort((a, b) =>
            _poiFeatureScore(b.poi).compareTo(_poiFeatureScore(a.poi)));
        final candidate = poiLayerCandidates.first;
        final poi = candidate.poi;
        final enrichedPoi = await _enrichRenderedPoi(poi);
        final featureLocation = _pointFromRenderedFeature(candidate.feature);
        final selectedPoi = featureLocation == null
            ? enrichedPoi
            : _withLocation(enrichedPoi, featureLocation);
        await _hideSelectedPoiFeature(
          controller,
          candidate.feature,
          selectedPoi,
        );
        DLog.info(
            '📍 [MapRenderedFeatureResolver] POI layer hit: ${poi.name} (${poi.category})');
        return selectedPoi;
      }

      // If no custom POI icon was hit, retain taps on other rendered map
      // features as a fallback (for example named places without our icon).
      final features =
          await controller.queryRenderedFeatures(point, const [], null);
      final candidates = _parseFeatures(features, latLng);
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

  /// Reapplies the hidden POI state if the map style has just been reloaded.
  /// A matching selected POI keeps its original icon hidden under the red pin.
  Future<void> keepSelectedPoiFeatureHidden(
    MapLibreMapController? controller,
    PoiModel poi,
  ) async {
    final featureId = _selectedFeatureId;
    final selectedPoi = _selectedFeaturePoi;
    if (controller == null || featureId == null || selectedPoi == null) return;
    if (!selectedPoi.isSamePoi(poi)) {
      await clearSelectedPoiFeature(controller);
      return;
    }
    try {
      await controller.setFeatureState(
        'smap-vietnam',
        featureId,
        const {'selected': true},
        sourceLayer: 'poi',
      );
      _selectedFeatureController = controller;
    } catch (e) {
      DLog.warning(
          '⚠️ [MapRenderedFeatureResolver] Không thể khôi phục trạng thái ẩn POI: $e');
    }
  }

  Future<void> clearSelectedPoiFeature(
    MapLibreMapController? controller,
  ) async {
    final featureId = _selectedFeatureId;
    final featureController = controller ?? _selectedFeatureController;
    _selectedFeatureId = null;
    _selectedFeaturePoi = null;
    _selectedFeatureController = null;
    if (featureId == null || featureController == null) return;
    try {
      await featureController.removeFeatureState(
        'smap-vietnam',
        featureId: featureId,
        stateKey: 'selected',
        sourceLayer: 'poi',
      );
    } catch (e) {
      DLog.warning(
          '⚠️ [MapRenderedFeatureResolver] Không thể khôi phục icon POI: $e');
    }
  }

  Future<void> _hideSelectedPoiFeature(
    MapLibreMapController controller,
    Map feature,
    PoiModel poi,
  ) async {
    await clearSelectedPoiFeature(controller);
    final properties = feature['properties'];
    final rawId = feature['id'] ??
        (properties is Map ? properties['id'] ?? properties['osm_id'] : null);
    final featureId = rawId is num
        ? rawId.toInt().toString()
        : int.tryParse(rawId?.toString() ?? '')?.toString();
    if (featureId == null) {
      DLog.warning(
          '⚠️ [MapRenderedFeatureResolver] POI tile feature không có id; không thể ẩn icon gốc');
      return;
    }
    try {
      await controller.setFeatureState(
        'smap-vietnam',
        featureId,
        const {'selected': true},
        sourceLayer: 'poi',
      );
      _selectedFeatureController = controller;
      _selectedFeatureId = featureId;
      _selectedFeaturePoi = poi;
    } catch (e, stack) {
      DLog.warning(
        '⚠️ [MapRenderedFeatureResolver] Không thể ẩn icon POI gốc ($featureId): $e',
        stack,
      );
    }
  }

  LatLng? _pointFromRenderedFeature(Map feature) {
    final geometry = feature['geometry'];
    if (geometry is! Map) return null;
    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 2) return null;
    final lon = coordinates[0];
    final lat = coordinates[1];
    if (lat is! num || lon is! num) return null;
    return LatLng(lat.toDouble(), lon.toDouble());
  }

  PoiModel _withLocation(PoiModel poi, LatLng location) => PoiModel(
        id: poi.id,
        osmId: poi.osmId,
        name: poi.name,
        nameAscii: poi.nameAscii,
        category: poi.category,
        subCategory: poi.subCategory,
        lat: location.latitude,
        lon: location.longitude,
        address: poi.address,
        street: poi.street,
        housenumber: poi.housenumber,
        city: poi.city,
        prominence: poi.prominence,
        provinceCode: poi.provinceCode,
        provinceLegacyCode: poi.provinceLegacyCode,
        districtCode: poi.districtCode,
        streetId: poi.streetId,
        streetCore: poi.streetCore,
        houseNo: poi.houseNo,
        houseNoMain: poi.houseNoMain,
        adminSource: poi.adminSource,
        scope: poi.scope,
      );

  List<PoiModel> _parseFeatures(
    List<dynamic> features,
    LatLng fallbackLocation, {
    bool allowClassCategory = false,
  }) {
    final candidates = <PoiModel>[];
    for (final rawFeature in features) {
      if (rawFeature is! Map) continue;
      final rawProperties = rawFeature['properties'];
      if (rawProperties is! Map) continue;
      final properties = Map<String, dynamic>.from(rawProperties);
      final poi = _poiFromRenderedProperties(
        properties,
        fallbackLocation,
        allowClassCategory: allowClassCategory,
      );
      if (poi != null) candidates.add(poi);
    }
    return candidates;
  }

  PoiModel? _poiFromRenderedProperties(
    Map<String, dynamic> properties,
    LatLng fallbackLocation, {
    bool allowClassCategory = false,
  }) {
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
      if (allowClassCategory) 'class',
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
