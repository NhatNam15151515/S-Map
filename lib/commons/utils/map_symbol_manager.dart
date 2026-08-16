import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/constants/map_constants.dart';
import 'package:s_map/models/models.dart';

/// Quản lý Symbol/Marker và tính toán Camera Bounds độc lập khỏi tầng UI.
class MapSymbolManager {
  final Map<String, PoiModel> _renderedSymbols = {};
  Symbol? _singleSelectedSymbol;
  int _renderGeneration = 0;

  /// Lấy POI tương ứng từ symbol ID khi người dùng bấm vào marker
  PoiModel? getPoiBySymbolId(String symbolId) => _renderedSymbols[symbolId];

  /// Nạp icon ảnh ghim đỏ vào MapLibre Sprite Engine
  void loadMarkerAssets(MapLibreMapController? controller) {
    if (controller == null) return;
    rootBundle.load('assets/images/red_marker.png').then((byteData) {
      final bytes = byteData.buffer.asUint8List();
      controller.addImage('red_marker', bytes);
    }).catchError((_) {});
  }

  /// Render danh sách POI thành các Symbol trên bản đồ tuần tự theo thế hệ
  void renderPoiList(
    MapLibreMapController? controller,
    List<PoiModel> pois,
  ) {
    if (controller == null) return;
    final generation = ++_renderGeneration;

    controller.clearSymbols().then((_) async {
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
    }).catchError((_) {});
  }

  /// Hiển thị ghim đỏ nổi bật cho một POI được chọn
  void setSelectedPoiMarker(
    MapLibreMapController? controller,
    PoiModel poi,
  ) {
    if (controller == null) return;
    final generation = ++_renderGeneration;

    final clearOld = _singleSelectedSymbol != null
        ? controller.removeSymbol(_singleSelectedSymbol!)
        : Future<void>.value();

    clearOld.then((_) async {
      if (generation != _renderGeneration) return;
      _singleSelectedSymbol = null;
      try {
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
        if (generation == _renderGeneration) {
          _singleSelectedSymbol = symbol;
          _renderedSymbols[symbol.id] = poi;
        }
      } catch (_) {}
    }).catchError((_) {});
  }

  /// Xóa ghim đơn lẻ khi đóng thẻ POI
  void clearSelectedPoiMarker(MapLibreMapController? controller) {
    if (controller == null || _singleSelectedSymbol == null) return;
    final symbolToRemove = _singleSelectedSymbol!;
    _singleSelectedSymbol = null;
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
    _renderGeneration++;
    _renderedSymbols.clear();
    _singleSelectedSymbol = null;
    if (controller != null) {
      controller.clearSymbols().catchError((_) {});
    }
  }
}
