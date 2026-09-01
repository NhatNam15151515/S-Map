import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';

/// Quản lý marker POI bằng Symbol native của MapLibre.
///
/// Symbol native được dùng có chủ đích ở đây: khác với một Symbol layer
/// GeoJSON tự tạo, nó được MapLibre tự vẽ lại sau camera movement và cho phép
/// ta giữ handle để xoá/cập nhật chính xác marker đang chọn.
class MapSymbolManager {
  // --- Trạng thái nội bộ ---
  final List<PoiModel> _searchResultPois = [];
  final Map<String, PoiModel> _renderedSymbols = {};
  final List<Symbol> _searchResultSymbols = [];
  Symbol? _selectedSymbol;
  PoiModel? _selectedPoi;
  bool _isAssetLoaded = false;
  bool _layersInitialized = false;
  Future<void>? _assetLoadFuture;
  Future<void>? _layersInitFuture;
  int _layersGeneration = 0;
  int _renderGeneration = 0;
  int _selectedGeneration = 0;

  // Layer IDs cho nhãn chủ quyền GeoJSON cố định.
  static const String _sovereigntySourceId = 'smap-sovereignty-source';
  static const String _sovereigntyLayerId = 'smap-sovereignty-layer';

  /// Map từ POI key → PoiModel để hỗ trợ tra cứu khi tap trên bản đồ
  final Map<String, PoiModel> _poiLookup = {};

  /// Lấy POI tương ứng từ symbol ID khi người dùng bấm vào marker.
  PoiModel? getPoiBySymbolId(String symbolId) => _renderedSymbols[symbolId];

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
    _layersGeneration++;
    _layersInitFuture = null;
    // setStyle() removes the native SymbolManager layer and invalidates all
    // Symbol handles. Keep the POI state so Home can restore it on the new
    // style, but never reuse stale native handles.
    _renderGeneration++;
    _selectedGeneration++;
    _renderedSymbols.clear();
    _searchResultSymbols.clear();
    _selectedSymbol = null;
  }

  /// Nạp icon ảnh ghim đỏ vào MapLibre Sprite Engine
  Future<void> loadMarkerAssets(
    MapLibreMapController? controller, {
    bool force = false,
  }) async {
    if (controller == null) return;
    if (_isAssetLoaded && !force) return;

    // A style load can notify the Cubit and the widget callback in the same
    // frame. Serialize sprite registration so two addImage calls cannot race
    // on the same native image key and make the following addSymbol fail.
    final pending = _assetLoadFuture;
    if (pending != null) {
      await pending;
      return;
    }

    final loadFuture = _loadMarkerAssets(controller);
    _assetLoadFuture = loadFuture;
    try {
      await loadFuture;
    } finally {
      if (identical(_assetLoadFuture, loadFuture)) {
        _assetLoadFuture = null;
      }
    }
  }

  Future<void> _loadMarkerAssets(MapLibreMapController controller) async {
    try {
      final byteData = await rootBundle.load(AppAsset.redMarker.fullPath);
      final bytes = byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
      await controller.addImage(RoutingConstants.markerImageKey, bytes);
      _isAssetLoaded = true;
      DLog.info(
          '🗺️ [MapSymbolManager] Marker asset "${RoutingConstants.markerImageKey}" loaded into map engine');
    } catch (e, stack) {
      // MapRouteManager may have registered the same image key just before
      // this manager. The sprite is already usable in that case.
      final errorText = e.toString().toLowerCase();
      if (errorText.contains('already') && errorText.contains('image')) {
        _isAssetLoaded = true;
        DLog.info(
            '🗺️ [MapSymbolManager] Marker image already exists; reusing native sprite');
      } else {
        DLog.warning(
            '⚠️ [MapSymbolManager] Failed to load marker asset: $e', stack);
        return;
      }
    }

    // addSymbol() has collision enabled by default. Configure the native
    // manager after the image is registered. If a platform does not support
    // one of these optional manager updates, the image remains usable.
    try {
      await controller.setSymbolIconAllowOverlap(true);
      await controller.setSymbolIconIgnorePlacement(true);
      await controller.setSymbolTextAllowOverlap(true);
      await controller.setSymbolTextIgnorePlacement(true);
    } catch (e, stack) {
      DLog.warning(
          '⚠️ [MapSymbolManager] Could not configure symbol overlap: $e', stack);
    }
  }

  /// Khởi tạo GeoJSON layer cho nhãn chủ quyền sau khi style loaded.
  /// POI markers không dùng layer này; chúng đi qua native SymbolManager.
  Future<void> initLayers(MapLibreMapController? controller) async {
    if (controller == null || _layersInitialized) return;

    // onStyleLoaded and the first sovereignty render can arrive in the same
    // frame. Serialize layer creation so both calls cannot pass the boolean
    // guard before addSymbolLayer finishes.
    final pending = _layersInitFuture;
    if (pending != null) {
      await pending;
      return;
    }

    final generation = _layersGeneration;
    final initFuture = _initLayers(controller, generation);
    _layersInitFuture = initFuture;
    try {
      await initFuture;
    } finally {
      if (identical(_layersInitFuture, initFuture)) {
        _layersInitFuture = null;
      }
    }
  }

  Future<void> _initLayers(
    MapLibreMapController controller,
    int generation,
  ) async {
    try {
      // Sovereignty labels layer (Hoàng Sa, Trường Sa, Biển Đông).
      try {
        await controller.addGeoJsonSource(
          _sovereigntySourceId,
          _emptyFeatureCollection(),
        );
      } catch (e, stack) {
        if (!_isAlreadyExistsError(e)) {
          DLog.error(
              '❌ [MapSymbolManager] Failed to initialize sovereignty source: $e',
              stack);
          return;
        }
      }

      try {
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
      } catch (e, stack) {
        if (!_isAlreadyExistsError(e)) {
          DLog.error(
              '❌ [MapSymbolManager] Failed to initialize sovereignty layer: $e',
              stack);
          return;
        }
        DLog.info(
            '🗺️ [MapSymbolManager] Sovereignty layer already exists; reusing it');
      }

      if (generation == _layersGeneration) {
        _layersInitialized = true;
        DLog.info(
            '🗺️ [MapSymbolManager] Custom GeoJSON layers initialized (icon-allow-overlap: true)');
      }
    } catch (e, stack) {
      DLog.error('❌ [MapSymbolManager] Failed to initialize custom layers: $e',
          stack);
    }
  }

  bool _isAlreadyExistsError(Object error) =>
      error.toString().toLowerCase().contains('already exists');

  /// Render danh sách POI (kết quả tìm kiếm/danh mục) bằng native symbols.
  Future<void> renderPoiList(
    MapLibreMapController? controller,
    List<PoiModel> pois,
  ) async {
    if (controller == null) return;
    final generation = ++_renderGeneration;

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

    try {
      await loadMarkerAssets(controller);
      if (generation != _renderGeneration) return;

      // Chỉ xoá các symbol do danh sách tìm kiếm tạo ra; selected marker
      // được quản lý riêng và không bị ảnh hưởng khi danh sách đổi.
      for (final symbol in _searchResultSymbols) {
        _renderedSymbols.remove(symbol.id);
        try {
          await controller.removeSymbol(symbol);
        } catch (_) {}
      }
      _searchResultSymbols.clear();

      for (final poi in pois) {
        if (generation != _renderGeneration) return;
        if (_isSamePoi(_selectedPoi, poi)) continue;

        try {
          // Icon-only avoids the offline font/glyph path hiding the whole
          // native symbol when a style has no matching text glyphs.
          final symbol = await controller.addSymbol(_symbolOptions(
            poi,
            iconSize: MapConstants.symbolIconSize,
          ));
          if (generation != _renderGeneration) {
            try {
              await controller.removeSymbol(symbol);
            } catch (_) {}
            return;
          }
          _searchResultSymbols.add(symbol);
          _renderedSymbols[symbol.id] = poi;
        } catch (e, stack) {
          DLog.warning(
              '⚠️ [MapSymbolManager] Failed to render search marker: $e', stack);
        }
      }
      DLog.info(
          '📍 [MapSymbolManager] Rendered ${_searchResultSymbols.length} search result markers via native symbols');
    } catch (e, stack) {
      DLog.warning('⚠️ [MapSymbolManager] Failed to render search symbols: $e', stack);
    }
  }

  /// Hiển thị ghim đỏ nổi bật bền vững cho một POI được chọn.
  Future<void> setSelectedPoiMarker(
    MapLibreMapController? controller,
    PoiModel poi,
  ) async {
    final samePoi = _isSamePoi(_selectedPoi, poi);
    final generation = ++_selectedGeneration;
    _selectedPoi = poi;
    _poiLookup[_poiKey(poi)] = poi;
    if (controller == null) return;
    // Camera movement and rebuilds do not require recreating a native symbol.
    // Only recreate it after a style reload, when resetAssetLoaded() has
    // cleared the handle.
    if (samePoi && _selectedSymbol != null) return;

    try {
      await loadMarkerAssets(controller);
      if (generation != _selectedGeneration) return;

      if (_selectedSymbol != null) {
        final oldSymbol = _selectedSymbol!;
        _selectedSymbol = null;
        _renderedSymbols.remove(oldSymbol.id);
        try {
          await controller.removeSymbol(oldSymbol);
        } catch (_) {}
      }

      // Keep this marker icon-only as well. A missing offline glyph must not
      // make MapLibre discard the selected red pin together with its label.
      final symbol = await controller.addSymbol(_symbolOptions(
        poi,
        iconSize: MapConstants.selectedSymbolIconSize,
      ));

      if (generation != _selectedGeneration) {
        try {
          await controller.removeSymbol(symbol);
        } catch (_) {}
        return;
      }
      _selectedSymbol = symbol;
      _renderedSymbols[symbol.id] = poi;
      DLog.info(
          '📍 [MapSymbolManager] Selected POI marker placed: "${poi.name}" at (${poi.lat}, ${poi.lon})');
    } catch (e, stack) {
      DLog.error('❌ [MapSymbolManager] Failed to add selected POI symbol: $e', stack);
    }
  }

  /// Xóa ghim đơn lẻ khi người dùng đóng thẻ POI
  Future<void> clearSelectedPoiMarker(MapLibreMapController? controller) async {
    _selectedPoi = null;
    _selectedGeneration++;
    final symbol = _selectedSymbol;
    _selectedSymbol = null;
    if (symbol != null) {
      _renderedSymbols.remove(symbol.id);
      if (controller != null) {
        try {
          await controller.removeSymbol(symbol);
        } catch (_) {}
      }
    }
    DLog.info('📍 [MapSymbolManager] Selected POI marker cleared');

    // POI vừa selected có thể phải quay lại danh sách kết quả.
    if (controller != null && _searchResultPois.isNotEmpty) {
      await renderPoiList(controller, _searchResultPois);
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
    _renderGeneration++;
    _selectedGeneration++;
    _searchResultPois.clear();
    _poiLookup.clear();
    final symbolsToRemove = <Symbol>[
      ..._searchResultSymbols,
      if (_selectedSymbol != null) _selectedSymbol!,
    ];
    _searchResultSymbols.clear();
    _selectedSymbol = null;
    _renderedSymbols.clear();

    if (controller != null) {
      for (final symbol in symbolsToRemove) {
        try {
          await controller.removeSymbol(symbol);
        } catch (_) {}
      }
    }
    if (controller != null && _layersInitialized) {
      await renderSovereigntySymbols(controller);
    }
  }

  // --- Helpers ---

  SymbolOptions _symbolOptions(
    PoiModel poi, {
    required double iconSize,
    double? textSize,
    double? textHaloWidth,
  }) {
    return SymbolOptions(
      geometry: LatLng(poi.lat, poi.lon),
      iconImage: RoutingConstants.markerImageKey,
      iconSize: iconSize,
      iconAnchor: 'bottom',
      textField: textSize == null ? null : poi.name,
      textSize: textSize,
      textColor: textSize == null ? null : AppColors.mapSymbolText.toHex,
      textHaloColor: textSize == null ? null : AppColors.mapSymbolHalo.toHex,
      textHaloWidth: textHaloWidth,
      textOffset: textSize == null ? null : const Offset(0, 0.6),
      textAnchor: textSize == null ? null : 'top',
    );
  }

  bool _isSamePoi(PoiModel? left, PoiModel right) =>
      left?.id == right.id &&
      left?.lat == right.lat &&
      left?.lon == right.lon;

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
