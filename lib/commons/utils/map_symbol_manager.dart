import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/commons/utils/poi_category_helper.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';

/// Quản lý redmarker POI bằng Symbol native của MapLibre.
///
/// Symbol native được dùng có chủ đích ở đây: khác với một Symbol layer
/// GeoJSON tự tạo, nó được MapLibre tự vẽ lại sau camera movement và cho phép
/// ta giữ handle để xoá/cập nhật chính xác marker search/đang chọn. Các điểm
/// đã lưu/đã từng đến được quản lý riêng bằng circle layer GeoJSON nhẹ hơn.
class MapSymbolManager {
  // --- Trạng thái nội bộ ---
  final List<PoiModel> _searchResultPois = [];
  final List<PoiModel> _memoryPois = [];
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
  int _memoryRenderGeneration = 0;
  int _selectedGeneration = 0;

  static const String _memoryPoiSourceId = 'smap-memory-poi-source';
  static const String _memoryPoiLayerId = 'smap-memory-poi-layer';

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
    _memoryRenderGeneration++;
    _selectedGeneration++;
    _renderedSymbols.clear();
    _searchResultSymbols.clear();
    _selectedSymbol = null;
    _rebuildPoiLookup();
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

  /// Khởi tạo GeoJSON layer cho POI cá nhân sau khi style loaded.
  /// Nhãn chủ quyền đã nằm sẵn trong style, còn POI search đi qua native
  /// SymbolManager.
  Future<void> initLayers(MapLibreMapController? controller) async {
    if (controller == null || _layersInitialized) return;

    // Các sự kiện style và đồng bộ memory marker có thể đến cùng frame.
    // Serialize layer creation để hai lệnh không cùng vượt qua cờ guard.
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
      // Persistent POIs use a lightweight data-driven circle layer. They are
      // intentionally separate from the red native symbols used by search
      // results and the currently selected POI.
      try {
        await controller.addGeoJsonSource(
          _memoryPoiSourceId,
          _emptyFeatureCollection(),
        );
      } catch (e, stack) {
        if (!_isAlreadyExistsError(e)) {
          DLog.error(
              '❌ [MapSymbolManager] Failed to initialize saved/visited POI source: $e',
              stack);
          return;
        }
      }

      try {
        await controller.addCircleLayer(
          _memoryPoiSourceId,
          _memoryPoiLayerId,
          const CircleLayerProperties(
            circleRadius: [Expressions.get, 'radius'],
            circleColor: [Expressions.get, 'color'],
            circleOpacity: 0.95,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: [Expressions.get, 'strokeWidth'],
            circleStrokeOpacity: 0.9,
          ),
          enableInteraction: false,
        );
      } catch (e, stack) {
        if (!_isAlreadyExistsError(e)) {
          DLog.error(
              '❌ [MapSymbolManager] Failed to initialize saved/visited POI layer: $e',
              stack);
          return;
        }
        DLog.info(
            '🗺️ [MapSymbolManager] Saved/visited POI layer already exists; reusing it');
      }

      if (generation == _layersGeneration) {
        _layersInitialized = true;
        DLog.info(
            '🗺️ [MapSymbolManager] Custom GeoJSON layer initialized (memory dots)');
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
    // Tách khỏi list do caller sở hữu. Khi khôi phục marker sau khi đóng
    // quick card, caller có thể truyền chính `_searchResultPois`; nếu giữ
    // cùng reference thì thao tác clear bên dưới sẽ xoá luôn dữ liệu nguồn.
    final nextPois = List<PoiModel>.of(pois);

    _cacheSearchResultPois(nextPois);

    try {
      await loadMarkerAssets(controller);
      if (generation != _renderGeneration) return;

      // Chỉ xoá các symbol do danh sách tìm kiếm tạo ra; selected marker
      // được quản lý riêng và không bị ảnh hưởng khi danh sách đổi.
      // Snapshot + clear trước khi await. Có thể có hai lần render nối tiếp
      // nhau khi đóng quick card: nếu cùng duyệt list field trong lúc một
      // lần render khác clear list, Dart sẽ ném Concurrent modification.
      final symbolsToRemove = List<Symbol>.of(_searchResultSymbols);
      _searchResultSymbols.clear();
      for (final symbol in symbolsToRemove) {
        _renderedSymbols.remove(symbol.id);
        try {
          await controller.removeSymbol(symbol);
        } catch (_) {}
      }

      for (final poi in nextPois) {
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

  /// Render các POI đã lưu/đã từng đến. Danh sách này là state lâu dài của
  /// người dùng, nên không bị xóa khi search, đóng quick card hoặc chuyển
  /// sang route preview/navigation.
  Future<void> renderMemoryPois(
    MapLibreMapController? controller,
    List<PoiModel> pois,
  ) async {
    final generation = ++_memoryRenderGeneration;
    final nextPois = <String, PoiModel>{};
    for (final poi in pois) {
      // Saved and visited records can have different ids for the same
      // physical destination (visited records use a coordinate fallback).
      // One visual marker per coordinate avoids stacked pins.
      nextPois[_memoryPoiKey(poi)] = poi;
    }
    _memoryPois
      ..clear()
      ..addAll(nextPois.values);
    _rebuildPoiLookup();

    if (controller == null || !_layersInitialized) return;
    try {
      if (generation != _memoryRenderGeneration) return;
      final features = nextPois.values
          .map(_memoryPoiFeature)
          .toList(growable: false);
      await controller.setGeoJsonSource(
        _memoryPoiSourceId,
        _buildFeatureCollection(features),
      );
      DLog.info(
          '📍 [MapSymbolManager] Rendered ${nextPois.length} saved/visited POI dots by category');
    } catch (e, stack) {
      DLog.warning(
          '⚠️ [MapSymbolManager] Failed to render saved/visited POI dots: $e', stack);
    }
  }

  /// Cập nhật snapshot POI mà không tạo native symbol.
  ///
  /// Dùng cho truy vấn chỉ có một kết quả: selected marker sẽ được tạo bởi
  /// luồng chọn POI, còn snapshot vẫn cần tồn tại để route có thể restore.
  void cacheSearchResultPois(List<PoiModel> pois) {
    _cacheSearchResultPois(List<PoiModel>.of(pois));
  }

  void _cacheSearchResultPois(List<PoiModel> pois) {
    _searchResultPois
      ..clear()
      ..addAll(pois);

    _rebuildPoiLookup();
  }

  void _rebuildPoiLookup() {
    _poiLookup.clear();
    for (final poi in _memoryPois) {
      _poiLookup[_poiKey(poi)] = poi;
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
    _rebuildPoiLookup();
    if (controller == null) return;
    // Camera movement and rebuilds do not require recreating a native symbol.
    // Only recreate it after a style reload, when resetAssetLoaded() has
    // cleared the handle.
    if (samePoi && _selectedSymbol != null) {
      // A previous app version could have left the original search symbol
      // underneath the selected symbol. Remove it even when the selected
      // handle is already present.
      await _removeSearchSymbolsAtLocation(controller, poi);
      return;
    }
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

      // Selecting a search result must promote the existing red pin instead
      // of adding a second pin at the same location. The search list remains
      // cached and is rendered again when the detail card closes.
      await _removeSearchSymbolsAtLocation(controller, poi);
      if (generation != _selectedGeneration) return;

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

  /// Xóa marker đang chọn.
  ///
  /// Khi chuyển sang preview/dẫn đường, danh sách POI vẫn phải được giữ lại
  /// trong bộ nhớ nhưng không được render lại ngay. Các luồng đóng quick card
  /// thông thường vẫn khôi phục marker theo mặc định.
  Future<void> clearSelectedPoiMarker(
    MapLibreMapController? controller, {
    bool restoreSearchResults = true,
  }) async {
    _selectedPoi = null;
    _selectedGeneration++;
    final symbol = _selectedSymbol;
    _selectedSymbol = null;
    _rebuildPoiLookup();
    if (symbol != null) {
      _renderedSymbols.remove(symbol.id);
      if (controller != null) {
        try {
          await controller.removeSymbol(symbol);
        } catch (_) {}
      }
    }
    DLog.info('📍 [MapSymbolManager] Selected POI marker cleared');

    if (!restoreSearchResults) return;

    // POI vừa selected có thể phải quay lại danh sách kết quả.
    final poisToRestore = List<PoiModel>.of(_searchResultPois);
    if (controller != null && poisToRestore.isNotEmpty) {
      await renderPoiList(controller, poisToRestore);
    }
  }

  /// Ẩn toàn bộ marker của danh sách tìm kiếm nhưng giữ lại dữ liệu POI.
  ///
  /// Route preview/navigation có destination marker riêng do
  /// [MapRouteManager] quản lý. Vì vậy ở đây chỉ xóa search symbols, không
  /// đụng vào route marker hay danh sách `_searchResultPois` để có thể render
  /// lại sau khi người dùng thoát chỉ đường.
  Future<void> hideSearchResultMarkers(
    MapLibreMapController? controller,
  ) async {
    final generation = ++_renderGeneration;
    final symbolsToRemove = List<Symbol>.of(_searchResultSymbols);
    _searchResultSymbols.clear();

    // Xóa lookup ngay trước các await để tap map không chọn symbol đã ẩn.
    _rebuildPoiLookup();

    for (final symbol in symbolsToRemove) {
      _renderedSymbols.remove(symbol.id);
      if (controller == null) continue;
      try {
        await controller.removeSymbol(symbol);
      } catch (_) {}
    }

    if (generation == _renderGeneration) {
      DLog.info(
          '🙈 [MapSymbolManager] Hidden ${symbolsToRemove.length} search result markers (POI list kept for restore)');
    }
  }

  /// Xóa hẳn ngữ cảnh tìm kiếm hiện tại nhưng giữ lại selected marker và các
  /// POI cá nhân. Dùng khi mở một POI từ màn hình khác, để route preview không
  /// khôi phục nhầm danh sách search cũ.
  Future<void> clearSearchResults(MapLibreMapController? controller) async {
    _renderGeneration++;
    _searchResultPois.clear();
    final symbolsToRemove = List<Symbol>.of(_searchResultSymbols);
    _searchResultSymbols.clear();
    _rebuildPoiLookup();

    for (final symbol in symbolsToRemove) {
      _renderedSymbols.remove(symbol.id);
      if (controller == null) continue;
      try {
        await controller.removeSymbol(symbol);
      } catch (_) {}
    }
  }

  /// Render lại danh sách search marker đã được giữ trong bộ nhớ.
  Future<void> restoreSearchResultMarkers(
    MapLibreMapController? controller,
  ) async {
    final poisToRestore = List<PoiModel>.of(_searchResultPois);
    if (controller == null || poisToRestore.isEmpty) return;
    await renderPoiList(controller, poisToRestore);
    DLog.info(
        '🙉 [MapSymbolManager] Restored ${poisToRestore.length} search result markers');
  }

  Future<void> _removeSearchSymbolsAtLocation(
    MapLibreMapController controller,
    PoiModel poi,
  ) async {
    final matchingSymbols = <Symbol>[];
    for (final symbol in List<Symbol>.of(_searchResultSymbols)) {
      final symbolPoi = _renderedSymbols[symbol.id];
      if (symbolPoi != null && _sameLocation(symbolPoi, poi)) {
        matchingSymbols.add(symbol);
      }
    }
    if (matchingSymbols.isEmpty) return;

    final matchingIds = matchingSymbols.map((symbol) => symbol.id).toSet();
    _searchResultSymbols.removeWhere(
      (symbol) => matchingIds.contains(symbol.id),
    );
    for (final symbol in matchingSymbols) {
      _renderedSymbols.remove(symbol.id);
      try {
        await controller.removeSymbol(symbol);
      } catch (_) {}
    }
    DLog.info(
        '📍 [MapSymbolManager] Promoted selected POI and removed ${matchingSymbols.length} duplicate search marker(s)');
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
    {bool fitBounds = true}) {
    if (controller == null || pois.isEmpty) return;
    renderPoiList(controller, pois);

    if (pois.length > 1 && fitBounds) {
      // Area/text search có thể trả kết quả trên nhiều tỉnh. Không giới hạn
      // còn vài POI đầu ở đây vì như vậy người dùng sẽ không thấy phần còn
      // lại của kết quả nationwide.
      final bounds = _calculateSearchBounds(pois);
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: 48,
          top: 110,
          right: 48,
          bottom: 180,
        ),
      );
    } else if (pois.length == 1) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(pois.first.lat, pois.first.lon),
          15.2,
        ),
      );
    }
  }

  /// Dọn sạch toàn bộ marker tìm kiếm.
  ///
  /// Nhãn chủ quyền là layer cố định của style hiện tại nên không liên quan
  /// đến việc clear marker tìm kiếm; việc render lại chúng ở đây gây thừa.
  Future<void> clearAll(MapLibreMapController? controller) async {
    _selectedPoi = null;
    _renderGeneration++;
    _selectedGeneration++;
    _searchResultPois.clear();
    final symbolsToRemove = <Symbol>[
      ..._searchResultSymbols,
      if (_selectedSymbol != null) _selectedSymbol!,
    ];
    _searchResultSymbols.clear();
    _selectedSymbol = null;
    _rebuildPoiLookup();

    if (controller != null) {
      for (final symbol in symbolsToRemove) {
        try {
          await controller.removeSymbol(symbol);
        } catch (_) {}
      }
    }
  }

  LatLngBounds _calculateSearchBounds(List<PoiModel> pois) {
    final bounds = calculateBoundingBox(pois)!;
    var minLat = bounds.southwest.latitude;
    var maxLat = bounds.northeast.latitude;
    var minLon = bounds.southwest.longitude;
    var maxLon = bounds.northeast.longitude;

    const minimumSpan = 0.015;
    if (maxLat - minLat < minimumSpan) {
      final center = (minLat + maxLat) / 2;
      minLat = center - minimumSpan / 2;
      maxLat = center + minimumSpan / 2;
    }
    if (maxLon - minLon < minimumSpan) {
      final center = (minLon + maxLon) / 2;
      minLon = center - minimumSpan / 2;
      maxLon = center + minimumSpan / 2;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLon),
      northeast: LatLng(maxLat, maxLon),
    );
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
      left != null &&
      left.lat == right.lat &&
      left.lon == right.lon &&
      (left.id != null && right.id != null
          ? left.id == right.id
          : left.osmId != null && right.osmId != null
              ? left.osmId == right.osmId
              : true);

  bool _sameLocation(PoiModel left, PoiModel right) =>
      left.lat == right.lat && left.lon == right.lon;

  Map<String, dynamic> _memoryPoiFeature(PoiModel poi) {
    final color = PoiCategoryHelper.getIconColor(
      poi.category,
      subCategory: poi.subCategory,
    ).toHex;
    return {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [poi.lon, poi.lat],
      },
      'properties': {
        'color': color,
        'radius': 5.5,
        'strokeWidth': 1.5,
      },
    };
  }

  String _memoryPoiKey(PoiModel poi) =>
      'loc:${poi.lat.toStringAsFixed(6)}:${poi.lon.toStringAsFixed(6)}';

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
