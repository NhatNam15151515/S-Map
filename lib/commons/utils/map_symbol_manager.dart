import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';

/// Quản lý Symbol/Marker bằng GeoJSON source + Symbol layer riêng
/// để tránh collision detection của SymbolManager mặc định gây mất ghim khi zoom.
class MapSymbolManager {
  // --- Trạng thái nội bộ ---
  final List<PoiModel> _searchResultPois = [];
  PoiModel? _selectedPoi;
  bool _isAssetLoaded = false;
  bool _layersInitialized = false;

  // Layer IDs cho GeoJSON custom layers
  static const String _searchSourceId = 'smap-search-results-source';
  static const String _searchLayerId = 'smap-search-results-layer';
  static const String _selectedSourceId = 'smap-selected-poi-source';
  static const String _selectedLayerId = 'smap-selected-poi-layer';
  static const String _sovereigntySourceId = 'smap-sovereignty-source';
  static const String _sovereigntyLayerId = 'smap-sovereignty-layer';

  /// Map từ POI key → PoiModel để hỗ trợ tra cứu khi tap trên bản đồ
  final Map<String, PoiModel> _poiLookup = {};

  /// Lấy POI tương ứng từ symbol ID khi người dùng bấm vào marker
  /// Dùng queryRenderedFeatures để xác định POI từ tọa độ thay vì symbol ID
  PoiModel? getPoiBySymbolId(String symbolId) => null;

  /// Tra cứu POI gần nhất tại tọa độ (cho map tap handler)
  PoiModel? getPoiAtLocation(double lat, double lon, {double toleranceDeg = 0.0005}) {
    for (final poi in _poiLookup.values) {
      if ((poi.lat - lat).abs() < toleranceDeg && (poi.lon - lon).abs() < toleranceDeg) {
        return poi;
      }
    }
    return null;
  }

  /// Lấy POI đang được chọn
  PoiModel? get selectedPoi => _selectedPoi;

  /// Reset cờ đã nạp asset (khi đổi map style)
  void resetAssetLoaded() {
    _isAssetLoaded = false;
    _layersInitialized = false;
  }

  /// Nạp icon ảnh ghim đỏ vào MapLibre Sprite Engine
  Future<void> loadMarkerAssets(MapLibreMapController? controller, {bool force = false}) async {
    if (controller == null) return;
    if (_isAssetLoaded && !force) return;
    try {
      final byteData = await rootBundle.load(AppAsset.redMarker.fullPath);
      final bytes = byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
      await controller.addImage(RoutingConstants.markerImageKey, bytes);
      _isAssetLoaded = true;
      DLog.info(
          '🗺️ [MapSymbolManager] Marker asset "${RoutingConstants.markerImageKey}" loaded into map engine');
    } catch (e, stack) {
      DLog.warning(
          '⚠️ [MapSymbolManager] Failed to load marker asset: $e', stack);
    }
  }

  /// Khởi tạo custom GeoJSON sources + Symbol layers với icon-allow-overlap: true
  /// Gọi 1 lần duy nhất sau khi style loaded
  Future<void> initLayers(MapLibreMapController? controller) async {
    if (controller == null || _layersInitialized) return;

    try {
      // 1. Search results layer (danh sách ghim nhỏ)
      await controller.addGeoJsonSource(_searchSourceId, _emptyFeatureCollection());
      await controller.addSymbolLayer(
        _searchSourceId,
        _searchLayerId,
        SymbolLayerProperties(
          iconImage: RoutingConstants.markerImageKey,
          iconSize: [
            Expressions.get,
            'iconSize',
          ],
          iconAnchor: 'bottom',
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          textField: [Expressions.get, 'name'],
          textSize: [Expressions.get, 'textSize'],
          textColor: AppColors.mapSymbolText.toHex,
          textHaloColor: AppColors.mapSymbolHalo.toHex,
          textHaloWidth: MapConstants.symbolTextHaloWidth,
          textOffset: const [0, 0.6],
          textAnchor: 'top',
          textMaxWidth: 8.0,
          textAllowOverlap: true,
          textIgnorePlacement: true,
          symbolSortKey: [Expressions.get, 'zIndex'],
        ),
        enableInteraction: true,
      );

      // 2. Selected POI layer (ghim to nổi bật)
      await controller.addGeoJsonSource(_selectedSourceId, _emptyFeatureCollection());
      await controller.addSymbolLayer(
        _selectedSourceId,
        _selectedLayerId,
        SymbolLayerProperties(
          iconImage: RoutingConstants.markerImageKey,
          iconSize: [
            Expressions.get,
            'iconSize',
          ],
          iconAnchor: 'bottom',
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          textField: [Expressions.get, 'name'],
          textSize: [Expressions.get, 'textSize'],
          textColor: AppColors.mapSymbolText.toHex,
          textHaloColor: AppColors.mapSymbolHalo.toHex,
          textHaloWidth: MapConstants.selectedSymbolTextHaloWidth,
          textOffset: const [0, 0.6],
          textAnchor: 'top',
          textMaxWidth: 10.0,
          textAllowOverlap: true,
          textIgnorePlacement: true,
          symbolSortKey: [Expressions.get, 'zIndex'],
        ),
        enableInteraction: true,
      );

      // 3. Sovereignty labels layer (Hoàng Sa, Trường Sa, Biển Đông)
      await controller.addGeoJsonSource(_sovereigntySourceId, _emptyFeatureCollection());
      await controller.addSymbolLayer(
        _sovereigntySourceId,
        _sovereigntyLayerId,
        const SymbolLayerProperties(
          textField: [Expressions.get, 'name'],
          textSize: [Expressions.get, 'textSize'],
          textColor: [Expressions.get, 'textColor'],
          textHaloColor: '#FFFFFF',
          textHaloWidth: 2.0,
          textAnchor: 'center',
          textLetterSpacing: [Expressions.get, 'letterSpacing'],
          textAllowOverlap: true,
          textIgnorePlacement: true,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
        ),
        enableInteraction: false,
      );

      _layersInitialized = true;
      DLog.info('🗺️ [MapSymbolManager] Custom GeoJSON layers initialized (icon-allow-overlap: true)');
    } catch (e, stack) {
      DLog.error('❌ [MapSymbolManager] Failed to initialize custom layers: $e', stack);
    }
  }

  /// Render danh sách POI (kết quả tìm kiếm/danh mục) bằng cách cập nhật GeoJSON source
  Future<void> renderPoiList(
    MapLibreMapController? controller,
    List<PoiModel> pois,
  ) async {
    if (controller == null) return;

    await loadMarkerAssets(controller);
    if (!_layersInitialized) await initLayers(controller);

    _searchResultPois
      ..clear()
      ..addAll(pois);

    // Cập nhật lookup map
    _poiLookup.clear();
    for (final poi in pois) {
      _poiLookup[_poiKey(poi)] = poi;
    }
    if (_selectedPoi != null) {
      _poiLookup[_poiKey(_selectedPoi!)] = _selectedPoi!;
    }

    // Build GeoJSON features cho search results (trừ POI đang chọn)
    final features = <Map<String, dynamic>>[];
    for (final poi in pois) {
      if (_selectedPoi != null && _selectedPoi!.id == poi.id) continue;
      features.add(_poiToFeature(
        poi,
        iconSize: MapConstants.symbolIconSize,
        textSize: MapConstants.symbolTextSize,
        zIndex: 1,
      ));
    }

    try {
      await controller.setGeoJsonSource(
        _searchSourceId,
        _buildFeatureCollection(features),
      );
      DLog.info(
          '📍 [MapSymbolManager] Rendered ${features.length} search result markers via GeoJSON source');
    } catch (e) {
      DLog.warning('⚠️ [MapSymbolManager] Failed to update search GeoJSON source: $e');
    }
  }

  /// Hiển thị ghim đỏ nổi bật bền vững cho một POI được chọn
  Future<void> setSelectedPoiMarker(
    MapLibreMapController? controller,
    PoiModel poi,
  ) async {
    if (_selectedPoi?.id == poi.id) return;

    _selectedPoi = poi;
    _poiLookup[_poiKey(poi)] = poi;
    if (controller == null) return;

    await loadMarkerAssets(controller);
    if (!_layersInitialized) await initLayers(controller);

    // 1. Cập nhật selected layer với 1 feature duy nhất
    try {
      await controller.setGeoJsonSource(
        _selectedSourceId,
        _buildFeatureCollection([
          _poiToFeature(
            poi,
            iconSize: MapConstants.selectedSymbolIconSize,
            textSize: MapConstants.selectedSymbolTextSize,
            zIndex: 10,
          ),
        ]),
      );
      DLog.info(
          '📍 [MapSymbolManager] Selected POI marker placed: "${poi.name}" at (${poi.lat}, ${poi.lon})');
    } catch (e) {
      DLog.warning('⚠️ [MapSymbolManager] Failed to update selected POI GeoJSON source: $e');
    }

    // 2. Cập nhật lại search results để loại bỏ POI đang chọn (tránh ghim trùng)
    if (_searchResultPois.isNotEmpty) {
      final features = <Map<String, dynamic>>[];
      for (final p in _searchResultPois) {
        if (p.id == poi.id) continue;
        features.add(_poiToFeature(
          p,
          iconSize: MapConstants.symbolIconSize,
          textSize: MapConstants.symbolTextSize,
          zIndex: 1,
        ));
      }
      try {
        await controller.setGeoJsonSource(
          _searchSourceId,
          _buildFeatureCollection(features),
        );
      } catch (_) {}
    }
  }

  /// Xóa ghim đơn lẻ khi người dùng đóng thẻ POI
  Future<void> clearSelectedPoiMarker(MapLibreMapController? controller) async {
    final previousSelectedPoi = _selectedPoi;
    _selectedPoi = null;
    if (controller == null) return;

    // Xóa selected source
    try {
      await controller.setGeoJsonSource(_selectedSourceId, _emptyFeatureCollection());
      DLog.info('📍 [MapSymbolManager] Selected POI marker cleared');
    } catch (_) {}

    // Khôi phục lại ghim POI cũ vào search results (nếu nó nằm trong danh sách)
    if (previousSelectedPoi != null && _searchResultPois.isNotEmpty) {
      final features = <Map<String, dynamic>>[];
      for (final p in _searchResultPois) {
        features.add(_poiToFeature(
          p,
          iconSize: MapConstants.symbolIconSize,
          textSize: MapConstants.symbolTextSize,
          zIndex: 1,
        ));
      }
      try {
        await controller.setGeoJsonSource(
          _searchSourceId,
          _buildFeatureCollection(features),
        );
      } catch (_) {}
    }
  }

  /// Tính toán khung bao LatLngBounds từ danh sách POIs (thuần túy, dễ viết test)
  static LatLngBounds? calculateBoundingBox(List<PoiModel> pois) {
    if (pois.isEmpty) return null;
    double minLat = pois.first.lat;
    double maxLat = pois.first.lat;
    double minLon = pois.first.lon;
    double maxLon = pois.first.lon;

    for (final p in pois) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lon < minLon) minLon = p.lon;
      if (p.lon > maxLon) maxLon = p.lon;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLon),
      northeast: LatLng(maxLat, maxLon),
    );
  }

  /// Tính toán khung bao LatLngBounds có giới hạn bán kính và đệm an toàn theo chuẩn Google Maps
  static LatLngBounds calculateBalancedBounds(
    List<PoiModel> pois, {
    double minSpanDegrees = 0.015,
    double maxSpanDegrees = 0.06,
  }) {
    if (pois.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(10.75, 106.65),
        northeast: const LatLng(10.80, 106.70),
      );
    }

    // Lấy tối đa 10 địa điểm đầu tiên (phù hợp nhất / gần nhất) để tính toán vùng nhìn trọng tâm
    final focusPois = pois.take(10).toList();

    double minLat = focusPois.first.lat;
    double maxLat = focusPois.first.lat;
    double minLon = focusPois.first.lon;
    double maxLon = focusPois.first.lon;

    for (final p in focusPois) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lon < minLon) minLon = p.lon;
      if (p.lon > maxLon) maxLon = p.lon;
    }

    double latSpan = maxLat - minLat;
    double lonSpan = maxLon - minLon;

    // 1. Mở rộng tối thiểu nếu quá gần nhau (tránh zoom quá sâu)
    if (latSpan < minSpanDegrees) {
      final centerLat = (minLat + maxLat) / 2;
      minLat = centerLat - minSpanDegrees / 2;
      maxLat = centerLat + minSpanDegrees / 2;
    }
    if (lonSpan < minSpanDegrees) {
      final centerLon = (minLon + maxLon) / 2;
      minLon = centerLon - minSpanDegrees / 2;
      maxLon = centerLon + minSpanDegrees / 2;
    }

    // 2. Giới hạn tối đa nếu quá xa nhau (tránh zoom quá nhỏ nhìn toàn quốc gia)
    if (latSpan > maxSpanDegrees || lonSpan > maxSpanDegrees) {
      final centerLat = focusPois.first.lat;
      final centerLon = focusPois.first.lon;
      minLat = centerLat - maxSpanDegrees / 2;
      maxLat = centerLat + maxSpanDegrees / 2;
      minLon = centerLon - maxSpanDegrees / 2;
      maxLon = centerLon + maxSpanDegrees / 2;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLon),
      northeast: LatLng(maxLat, maxLon),
    );
  }

  /// Hiển thị danh sách kết quả tìm kiếm và tự động fit camera bao quanh vừa phải theo chuẩn Google Maps
  void showSearchResults(
    MapLibreMapController? controller,
    List<PoiModel> pois,
  ) {
    if (controller == null || pois.isEmpty) return;
    renderPoiList(controller, pois);

    if (pois.length > 1) {
      final bounds = calculateBalancedBounds(pois);
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: 48,
          top: 110,
          right: 48,
          bottom: 180,
        ),
      );
    } else {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(pois.first.lat, pois.first.lon),
          15.2,
        ),
      );
    }
  }

  /// Render các nhãn khẳng định chủ quyền biển đảo Việt Nam (Hoàng Sa & Trường Sa & Biển Đông)
  Future<void> renderSovereigntySymbols(MapLibreMapController? controller) async {
    if (controller == null) return;
    if (!_layersInitialized) await initLayers(controller);

    final features = <Map<String, dynamic>>[
      // 1. Quần đảo Hoàng Sa (Việt Nam)
      {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [112.3394, 16.5367],
        },
        'properties': {
          'name': 'Quần đảo Hoàng Sa\n(Việt Nam)',
          'textSize': 13.0,
          'textColor': '#D32F2F',
          'letterSpacing': 0.0,
        },
      },
      // 2. Quần đảo Trường Sa (Việt Nam)
      {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [111.9197, 8.6433],
        },
        'properties': {
          'name': 'Quần đảo Trường Sa\n(Việt Nam)',
          'textSize': 13.0,
          'textColor': '#D32F2F',
          'letterSpacing': 0.0,
        },
      },
      // 3. Biển Đông
      {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [113.5000, 13.5000],
        },
        'properties': {
          'name': 'BIỂN ĐÔNG',
          'textSize': 15.0,
          'textColor': '#1976D2',
          'letterSpacing': 0.2,
        },
      },
    ];

    try {
      await controller.setGeoJsonSource(
        _sovereigntySourceId,
        _buildFeatureCollection(features),
      );
      DLog.info('🇻🇳 [MapSymbolManager] Vietnam sovereignty symbols (Hoàng Sa, Trường Sa, Biển Đông) rendered');
    } catch (e) {
      DLog.warning('⚠️ [MapSymbolManager] Failed to add sovereignty symbols: $e');
    }
  }

  /// Dọn sạch toàn bộ marker tìm kiếm nhưng khôi phục lại nhãn chủ quyền
  Future<void> clearAll(MapLibreMapController? controller) async {
    _selectedPoi = null;
    _searchResultPois.clear();
    _poiLookup.clear();

    if (controller != null && _layersInitialized) {
      try {
        await controller.setGeoJsonSource(_searchSourceId, _emptyFeatureCollection());
        await controller.setGeoJsonSource(_selectedSourceId, _emptyFeatureCollection());
      } catch (_) {}
      await renderSovereigntySymbols(controller);
    }
  }

  // --- Helpers ---

  /// Chuyển đổi PoiModel thành GeoJSON Feature
  Map<String, dynamic> _poiToFeature(
    PoiModel poi, {
    required double iconSize,
    required double textSize,
    required int zIndex,
  }) {
    return {
      'type': 'Feature',
      'id': poi.id,
      'geometry': {
        'type': 'Point',
        'coordinates': [poi.lon, poi.lat],
      },
      'properties': {
        'poiId': poi.id,
        'name': poi.name,
        'iconSize': iconSize,
        'textSize': textSize,
        'zIndex': zIndex,
      },
    };
  }

  /// Tạo GeoJSON FeatureCollection trống
  Map<String, dynamic> _emptyFeatureCollection() {
    return {
      'type': 'FeatureCollection',
      'features': <Map<String, dynamic>>[],
    };
  }

  /// Tạo GeoJSON FeatureCollection từ danh sách features
  Map<String, dynamic> _buildFeatureCollection(List<Map<String, dynamic>> features) {
    return {
      'type': 'FeatureCollection',
      'features': features,
    };
  }

  /// Tạo key duy nhất cho POI (dùng id nếu có, fallback sang tọa độ)
  String _poiKey(PoiModel poi) => poi.id != null
      ? 'id_${poi.id}'
      : 'loc_${poi.lat}_${poi.lon}';
}
