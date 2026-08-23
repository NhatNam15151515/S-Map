import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';

/// Quản lý vẽ và xóa Polyline và Marker cho chế độ Vẽ tuyến đường (Route Drawing) trên MapLibre.
class MapDrawingRouteManager {
  Line? _routeLine;
  Line? _casingLine;
  final List<Symbol> _waypointSymbols = [];
  int _renderGeneration = 0;
  bool _isAssetLoaded = false;

  /// Nạp icon marker vào engine MapLibre
  Future<void> loadMarkerAssets(MapLibreMapController? controller) async {
    if (controller == null || _isAssetLoaded) return;
    try {
      final byteData = await rootBundle.load(AppAsset.redMarker.fullPath);
      final bytes = byteData.buffer.asUint8List();
      await controller.addImage(RoutingConstants.markerImageKey, bytes);
      _isAssetLoaded = true;
      DLog.info(
          '🗺️ [MapDrawingRouteManager] Marker asset "${RoutingConstants.markerImageKey}" loaded into map engine (${AppAsset.redMarker.fullPath})');
    } catch (e, stack) {
      DLog.warning(
          '⚠️ [MapDrawingRouteManager] Failed to load marker asset: $e', stack);
    }
  }

  /// Chuyển đổi danh sách [RoutePoint] sang List<LatLng> an toàn
  static List<LatLng> parseRoutePoints(List<RoutePoint> rawPoints) {
    return rawPoints.map((p) => LatLng(p.lat, p.lon)).toList();
  }

  /// Tính toán LatLngBounds bao quanh toàn bộ các điểm
  static LatLngBounds? calculateBounds(List<LatLng> points) {
    if (points.isEmpty) return null;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLon = points.first.longitude;
    double maxLon = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLon),
      northeast: LatLng(maxLat, maxLon),
    );
  }

  /// Xóa toàn bộ line và marker đang vẽ và tăng thế hệ render để hủy các render đang chạy
  Future<void> clear(MapLibreMapController? controller) async {
    _renderGeneration++;
    await _removeExisting(controller);
  }

  /// Helper xóa các đối tượng trên bản đồ mà không tăng thế hệ render
  Future<void> _removeExisting(MapLibreMapController? controller) async {
    if (controller == null) return;
    try {
      if (_routeLine != null) {
        final line = _routeLine!;
        _routeLine = null;
        await controller.removeLine(line);
      }
      if (_casingLine != null) {
        final casing = _casingLine!;
        _casingLine = null;
        await controller.removeLine(casing);
      }
      if (_waypointSymbols.isNotEmpty) {
        final symbolsToRemove = List<Symbol>.from(_waypointSymbols);
        _waypointSymbols.clear();
        for (final sym in symbolsToRemove) {
          await controller.removeSymbol(sym);
        }
      }
    } catch (e) {
      DLog.warning(
          '⚠️ [MapDrawingRouteManager] Error clearing lines/symbols: $e');
    }
  }

  /// Vẽ toàn bộ lộ trình tùy chỉnh và các waypoint markers
  Future<bool> drawCustomRoute({
    required MapLibreMapController? controller,
    required List<SnappedRoadPoint> points,
    required List<RoutePoint> fullPolyline,
  }) async {
    if (controller == null) return false;
    final generation = ++_renderGeneration;

    try {
      await loadMarkerAssets(controller);
      if (generation != _renderGeneration) return false;

      await _removeExisting(controller);
      if (generation != _renderGeneration) return false;

      // 1. Vẽ Polyline kết nối (nếu có từ 2 điểm trở lên và fullPolyline có dữ liệu)
      final polylineLatLngs = parseRoutePoints(fullPolyline);
      if (polylineLatLngs.length >= 2) {
        final casing = await controller.addLine(
          LineOptions(
            geometry: polylineLatLngs,
            lineColor: AppColors.sMapDarkTeal.toHex,
            lineWidth: RoutingConstants.routeCasingLineWidth,
            lineOpacity: 0.9,
            lineJoin: RoutingConstants.routeLineJoin,
          ),
        );
        if (generation != _renderGeneration) {
          await controller.removeLine(casing);
          return false;
        }
        _casingLine = casing;

        final mainLine = await controller.addLine(
          LineOptions(
            geometry: polylineLatLngs,
            lineColor: AppColors.sMapTeal.toHex,
            lineWidth: RoutingConstants.routeMainLineWidth,
            lineOpacity: 1.0,
            lineJoin: RoutingConstants.routeLineJoin,
          ),
        );
        if (generation != _renderGeneration) {
          await controller.removeLine(mainLine);
          return false;
        }
        _routeLine = mainLine;
      }

      // 2. Vẽ Waypoint Symbols cho từng điểm
      for (int i = 0; i < points.length; i++) {
        if (generation != _renderGeneration) break;
        final pt = points[i];
        final latLng = LatLng(pt.snappedLat, pt.snappedLon);

        String label;
        if (i == 0) {
          label = 'A';
        } else if (i == points.length - 1 && points.length > 1) {
          label = 'B';
        } else {
          label = '$i';
        }

        final symbol = await controller.addSymbol(
          SymbolOptions(
            geometry: latLng,
            iconImage: RoutingConstants.markerImageKey,
            iconSize: i == 0 || i == points.length - 1 ? 0.75 : 0.6,
            iconAnchor: 'bottom',
            textField: label,
            textSize: 12.0,
            textColor: AppColors.white.toHex,
            textHaloColor: AppColors.mapSymbolText.toHex,
            textHaloWidth: 1.5,
            textOffset: const Offset(0, -1.8),
            textAnchor: 'center',
          ),
        );

        if (generation == _renderGeneration) {
          _waypointSymbols.add(symbol);
        } else {
          await controller.removeSymbol(symbol);
          return false;
        }
      }

      return true;
    } catch (e, stack) {
      DLog.error('❌ [MapDrawingRouteManager] Error drawing custom route: $e', e,
          stack);
      return false;
    }
  }

  /// Tự động zoom camera bao quanh các điểm đã vẽ
  Future<void> fitRouteBounds({
    required MapLibreMapController? controller,
    required List<SnappedRoadPoint> points,
    List<RoutePoint>? fullPolyline,
  }) async {
    if (controller == null || points.isEmpty) return;

    List<LatLng> allPoints = [];
    if (fullPolyline != null && fullPolyline.isNotEmpty) {
      allPoints = parseRoutePoints(fullPolyline);
    } else {
      allPoints =
          points.map((p) => LatLng(p.snappedLat, p.snappedLon)).toList();
    }

    final bounds = calculateBounds(allPoints);
    if (bounds == null) return;

    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: RoutingConstants.routeFitPaddingLeft,
          right: RoutingConstants.routeFitPaddingRight,
          top: RoutingConstants.routeFitPaddingTop,
          bottom: RoutingConstants.routeFitPaddingBottom,
        ),
      );
    } catch (e) {
      DLog.warning('⚠️ [MapDrawingRouteManager] Error fitting bounds: $e');
    }
  }
}
