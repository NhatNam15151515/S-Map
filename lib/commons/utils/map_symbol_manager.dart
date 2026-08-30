import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';

/// Quản lý Symbol/Marker và tính toán Camera Bounds độc lập khỏi tầng UI.
class MapSymbolManager {
  final Map<String, PoiModel> _renderedSymbols = {};
  final List<Symbol> _searchResultSymbols = [];
  Symbol? _selectedSymbol;
  PoiModel? _selectedPoi;
  int _renderGeneration = 0;
  int _selectedGeneration = 0;

  /// Lấy POI tương ứng từ symbol ID khi người dùng bấm vào marker
  PoiModel? getPoiBySymbolId(String symbolId) => _renderedSymbols[symbolId];

  /// Lấy POI đang được chọn
  PoiModel? get selectedPoi => _selectedPoi;

  /// Nạp icon ảnh ghim đỏ vào MapLibre Sprite Engine
  Future<void> loadMarkerAssets(MapLibreMapController? controller) async {
    if (controller == null) return;
    try {
      final byteData = await rootBundle.load(AppAsset.redMarker.fullPath);
      final bytes = byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
      await controller.addImage(RoutingConstants.markerImageKey, bytes);
      DLog.info(
          '🗺️ [MapSymbolManager] Marker asset "${RoutingConstants.markerImageKey}" loaded into map engine');
    } catch (e, stack) {
      DLog.warning(
          '⚠️ [MapSymbolManager] Failed to load marker asset: $e', stack);
    }
  }

  /// Render danh sách POI (kết quả tìm kiếm/danh mục) độc lập, không làm mất ghim của POI đang chọn
  Future<void> renderPoiList(
    MapLibreMapController? controller,
    List<PoiModel> pois,
  ) async {
    if (controller == null) return;
    final generation = ++_renderGeneration;

    try {
      await loadMarkerAssets(controller);
      if (generation != _renderGeneration) return;

      // Xóa các symbol kết quả tìm kiếm cũ (KHÔNG xóa _selectedSymbol)
      for (final s in _searchResultSymbols) {
        _renderedSymbols.remove(s.id);
        try {
          await controller.removeSymbol(s);
        } catch (_) {}
      }
      _searchResultSymbols.clear();

      if (generation != _renderGeneration) return;

      for (final poi in pois) {
        if (generation != _renderGeneration) break;
        // Nếu POI này là POI đang được chọn thì bỏ qua vì đã có ghim nổi bật riêng
        if (_selectedPoi != null && _selectedPoi!.id == poi.id) continue;

        try {
          final symbol = await controller.addSymbol(
            SymbolOptions(
              geometry: LatLng(poi.lat, poi.lon),
              iconImage: RoutingConstants.markerImageKey,
              iconSize: 0.65,
              iconAnchor: 'bottom',
              textField: poi.name,
              textSize: MapConstants.symbolTextSize,
              textColor: AppColors.mapSymbolText.toHex,
              textHaloColor: AppColors.mapSymbolHalo.toHex,
              textHaloWidth: MapConstants.symbolTextHaloWidth,
              textOffset: const Offset(0, 0.6),
              textAnchor: 'top',
            ),
          );
          if (generation == _renderGeneration) {
            _searchResultSymbols.add(symbol);
            _renderedSymbols[symbol.id] = poi;
          }
        } catch (_) {
          // Fallback: nếu lỗi render text font glyphs, vẽ chỉ icon
          try {
            final symbol = await controller.addSymbol(
              SymbolOptions(
                geometry: LatLng(poi.lat, poi.lon),
                iconImage: RoutingConstants.markerImageKey,
                iconSize: 0.65,
                iconAnchor: 'bottom',
              ),
            );
            if (generation == _renderGeneration) {
              _searchResultSymbols.add(symbol);
              _renderedSymbols[symbol.id] = poi;
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Hiển thị ghim đỏ nổi bật bền vững cho một POI được chọn (chỉ mất khi người dùng đóng thẻ)
  Future<void> setSelectedPoiMarker(
    MapLibreMapController? controller,
    PoiModel poi,
  ) async {
    _selectedPoi = poi;
    if (controller == null) return;
    final generation = ++_selectedGeneration;

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

      if (generation != _selectedGeneration) return;

      Symbol? symbol;
      try {
        symbol = await controller.addSymbol(
          SymbolOptions(
            geometry: LatLng(poi.lat, poi.lon),
            iconImage: RoutingConstants.markerImageKey,
            iconSize: 0.85,
            iconAnchor: 'bottom',
            textField: poi.name,
            textSize: 12.0,
            textColor: AppColors.mapSymbolText.toHex,
            textHaloColor: AppColors.mapSymbolHalo.toHex,
            textHaloWidth: MapConstants.symbolTextHaloWidth,
            textOffset: const Offset(0, 0.6),
            textAnchor: 'top',
          ),
        );
      } catch (e) {
        DLog.warning(
            '⚠️ [MapSymbolManager] Symbol with text failed, falling back to icon only: $e');
        // Fallback icon only
        symbol = await controller.addSymbol(
          SymbolOptions(
            geometry: LatLng(poi.lat, poi.lon),
            iconImage: RoutingConstants.markerImageKey,
            iconSize: 0.85,
            iconAnchor: 'bottom',
          ),
        );
      }

      if (generation == _selectedGeneration) {
        _selectedSymbol = symbol;
        _renderedSymbols[symbol.id] = poi;
        DLog.info(
            '📍 [MapSymbolManager] Selected POI marker placed: "${poi.name}" at (${poi.lat}, ${poi.lon})');
      }
    } catch (e, stack) {
      DLog.error(
          '❌ [MapSymbolManager] Failed to add selected POI symbol: $e', stack);
    }
  }

  /// Xóa ghim đơn lẻ khi người dùng đóng thẻ POI
  void clearSelectedPoiMarker(MapLibreMapController? controller) {
    _selectedPoi = null;
    _selectedGeneration++;
    if (controller == null || _selectedSymbol == null) return;
    final symbolToRemove = _selectedSymbol!;
    _selectedSymbol = null;
    _renderedSymbols.remove(symbolToRemove.id);
    controller.removeSymbol(symbolToRemove).catchError((_) {});
    DLog.info('📍 [MapSymbolManager] Selected POI marker cleared');
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
    try {
      // 1. Quần đảo Hoàng Sa (Việt Nam)
      final hoangSaSymbol = await controller.addSymbol(
        const SymbolOptions(
          geometry: LatLng(16.5367, 112.3394),
          textField: 'Quần đảo Hoàng Sa\n(Việt Nam)',
          textSize: 13.0,
          textColor: '#D32F2F',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 2.0,
          textAnchor: 'center',
        ),
      );
      _renderedSymbols[hoangSaSymbol.id] = const PoiModel(
        id: 999901,
        name: 'Quần đảo Hoàng Sa (Việt Nam)',
        nameAscii: 'Quan dao Hoang Sa (Viet Nam)',
        lat: 16.5367,
        lon: 112.3394,
        category: 'island',
        address: 'Thành phố Đà Nẵng, Việt Nam',
      );

      // 2. Quần đảo Trường Sa (Việt Nam)
      final truongSaSymbol = await controller.addSymbol(
        const SymbolOptions(
          geometry: LatLng(8.6433, 111.9197),
          textField: 'Quần đảo Trường Sa\n(Việt Nam)',
          textSize: 13.0,
          textColor: '#D32F2F',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 2.0,
          textAnchor: 'center',
        ),
      );
      _renderedSymbols[truongSaSymbol.id] = const PoiModel(
        id: 999902,
        name: 'Quần đảo Trường Sa (Việt Nam)',
        nameAscii: 'Quan dao Truong Sa (Viet Nam)',
        lat: 8.6433,
        lon: 111.9197,
        category: 'island',
        address: 'Tỉnh Khánh Hòa, Việt Nam',
      );

      // 3. Biển Đông
      await controller.addSymbol(
        const SymbolOptions(
          geometry: LatLng(13.5000, 113.5000),
          textField: 'BIỂN ĐÔNG',
          textSize: 15.0,
          textColor: '#1976D2',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 2.0,
          textAnchor: 'center',
          textLetterSpacing: 0.2,
        ),
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
    _renderedSymbols.clear();
    _searchResultSymbols.clear();
    _selectedSymbol = null;
    if (controller != null) {
      try {
        await controller.clearSymbols();
      } catch (_) {}
      await renderSovereigntySymbols(controller);
    }
  }
}
