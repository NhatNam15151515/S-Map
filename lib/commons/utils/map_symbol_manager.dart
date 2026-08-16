import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';

/// Quản lý Symbol/Marker và tính toán Camera Bounds độc lập khỏi tầng UI.
class MapSymbolManager {
  final Map<String, PoiModel> _renderedSymbols = {};
  Symbol? _singleSelectedSymbol;
  PoiModel? _selectedPoi;
  int _renderGeneration = 0;
  int _selectedGeneration = 0;
  bool _isAssetLoaded = false;

  /// Lấy POI tương ứng từ symbol ID khi người dùng bấm vào marker
  PoiModel? getPoiBySymbolId(String symbolId) => _renderedSymbols[symbolId];

  /// Nạp icon ảnh ghim đỏ vào MapLibre Sprite Engine
  Future<void> loadMarkerAssets(MapLibreMapController? controller) async {
    if (controller == null || _isAssetLoaded) return;
    try {
      final byteData = await rootBundle.load(AppAsset.redMarker.fullPath);
      final bytes = byteData.buffer.asUint8List();
      await controller.addImage('red_marker', bytes);
      _isAssetLoaded = true;
      DLog.info('🗺️ [MapSymbolManager] Marker asset "red_marker" loaded into map engine');
    } catch (e, stack) {
      DLog.warning('⚠️ [MapSymbolManager] Failed to load marker asset: $e', stack);
    }
  }

  /// Render danh sách POI thành các Symbol trên bản đồ tuần tự theo thế hệ
  Future<void> renderPoiList(
    MapLibreMapController? controller,
    List<PoiModel> pois,
  ) async {
    if (controller == null) return;
    final generation = ++_renderGeneration;

    try {
      await loadMarkerAssets(controller);
      if (generation != _renderGeneration) return;

      await controller.clearSymbols();
      if (generation != _renderGeneration) return;

      _renderedSymbols.clear();
      _singleSelectedSymbol = null;

      for (final poi in pois) {
        if (generation != _renderGeneration) break;
        try {
          final symbol = await controller.addSymbol(
            SymbolOptions(
              geometry: LatLng(poi.lat, poi.lon),
              iconImage: 'red_marker',
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
            _renderedSymbols[symbol.id] = poi;
          }
        } catch (_) {}
      }

      // Giữ lại ghim nổi bật của POI đang chọn nếu có
      if (_selectedPoi != null && generation == _renderGeneration) {
        final poi = _selectedPoi!;
        try {
          final selectedSymbol = await controller.addSymbol(
            SymbolOptions(
              geometry: LatLng(poi.lat, poi.lon),
              iconImage: 'red_marker',
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
          if (generation == _renderGeneration) {
            _singleSelectedSymbol = selectedSymbol;
            _renderedSymbols[selectedSymbol.id] = poi;
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Hiển thị ghim đỏ nổi bật cho một POI được chọn
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

      if (_singleSelectedSymbol != null) {
        final oldSymbol = _singleSelectedSymbol!;
        _singleSelectedSymbol = null;
        _renderedSymbols.remove(oldSymbol.id);
        try {
          await controller.removeSymbol(oldSymbol);
        } catch (_) {}
      }

      if (generation != _selectedGeneration) return;

      final symbol = await controller.addSymbol(
        SymbolOptions(
          geometry: LatLng(poi.lat, poi.lon),
          iconImage: 'red_marker',
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

      if (generation == _selectedGeneration) {
        _singleSelectedSymbol = symbol;
        _renderedSymbols[symbol.id] = poi;
        DLog.info('📍 [MapSymbolManager] Selected POI marker placed: "${poi.name}" at (${poi.lat}, ${poi.lon})');
      }
    } catch (e, stack) {
      DLog.error('❌ [MapSymbolManager] Failed to add selected POI symbol: $e', stack);
    }
  }

  /// Xóa ghim đơn lẻ khi đóng thẻ POI
  void clearSelectedPoiMarker(MapLibreMapController? controller) {
    _selectedPoi = null;
    _selectedGeneration++;
    if (controller == null || _singleSelectedSymbol == null) return;
    final symbolToRemove = _singleSelectedSymbol!;
    _singleSelectedSymbol = null;
    _renderedSymbols.remove(symbolToRemove.id);
    controller.removeSymbol(symbolToRemove).catchError((_) {});
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

  /// Hiển thị danh sách kết quả tìm kiếm và tự động fit camera bao quanh
  void showSearchResults(
    MapLibreMapController? controller,
    List<PoiModel> pois,
  ) {
    if (controller == null || pois.isEmpty) return;
    renderPoiList(controller, pois);

    if (pois.length > 1) {
      final bounds = calculateBoundingBox(pois);
      if (bounds != null) {
        controller.animateCamera(
          CameraUpdate.newLatLngBounds(
            bounds,
            left: 48,
            top: 96,
            right: 48,
            bottom: 160,
          ),
        );
      }
    } else {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(pois.first.lat, pois.first.lon),
          16.0,
        ),
      );
    }
  }

  /// Dọn sạch toàn bộ marker và bộ nhớ tạm
  void clearAll(MapLibreMapController? controller) {
    _selectedPoi = null;
    _renderGeneration++;
    _selectedGeneration++;
    _renderedSymbols.clear();
    _singleSelectedSymbol = null;
    if (controller != null) {
      controller.clearSymbols().catchError((_) {});
    }
  }
}
