import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/commons/utils/app_utils.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';

/// Quản lý vẽ và xóa Polyline và Marker lộ trình trên MapLibre độc lập khỏi UI.
class MapRouteManager {
  Line? _routeLine;
  Line? _routeCasingLine;
  Symbol? _destinationSymbol;
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
    } catch (e, stack) {
      DLog.warning('Failed to load marker asset in MapRouteManager: $e', stack);
    }
  }

  /// Chuyển đổi danh sách [lat, lon] sang List<LatLng> an toàn
  static List<LatLng> parseRoutePoints(List<List<double>> rawPoints) {
    final points = <LatLng>[];
    for (final p in rawPoints) {
      if (p.length >= 2) {
        points.add(LatLng(p[0], p[1]));
      }
    }
    return points;
  }

  /// Tính toán LatLngBounds bao quanh toàn bộ lộ trình
  static LatLngBounds? calculateRouteBounds(List<LatLng> points) {
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

  /// Vẽ Polyline lộ trình và gắn Marker điểm đầu / điểm cuối
  Future<void> drawRoute({
    required MapLibreMapController? controller,
    required RouteResult routeResult,
    required RoutePoint origin,
    required RoutePoint destination,
    String? destinationName,
  }) async {
    if (controller == null || !routeResult.isSuccess || !routeResult.hasPoints) {
      return;
    }

    final generation = ++_renderGeneration;
    final latLngs = parseRoutePoints(routeResult.points);
    if (latLngs.isEmpty) return;

    try {
      await loadMarkerAssets(controller);
      if (generation != _renderGeneration) return;

      // Xóa đường và marker cũ trước khi vẽ mới
      await _clearLinesAndSymbols(controller);
      if (generation != _renderGeneration) return;

      // 1. Tạo Casing Line (Viền đậm bên dưới tạo độ nổi khối)
      final casingLine = await controller.addLine(
        LineOptions(
          geometry: latLngs,
          lineColor: AppColors.routeCasingColor.toHex,
          lineWidth: RoutingConstants.routeCasingLineWidth,
          lineOpacity: RoutingConstants.routeCasingOpacity,
          lineJoin: RoutingConstants.routeLineJoin,
        ),
      );

      // 2. Tạo Main Route Line (Màu xanh Google Blue chính)
      final mainLine = await controller.addLine(
        LineOptions(
          geometry: latLngs,
          lineColor: AppColors.routeMainColor.toHex,
          lineWidth: RoutingConstants.routeMainLineWidth,
          lineOpacity: RoutingConstants.routeMainOpacity,
          lineJoin: RoutingConstants.routeLineJoin,
        ),
      );

      // 3. Tạo Marker điểm đến (Destination)
      final destSymbol = await controller.addSymbol(
        SymbolOptions(
          geometry: LatLng(destination.lat, destination.lon),
          iconImage: RoutingConstants.markerImageKey,
          iconSize: MapConstants.selectedSymbolIconSize,
          iconAnchor: 'bottom',
          textField: destinationName ?? '',
          textSize: MapConstants.selectedSymbolTextSize,
          textColor: AppColors.mapSymbolText.toHex,
          textHaloColor: AppColors.mapSymbolHalo.toHex,
          textHaloWidth: MapConstants.selectedSymbolTextHaloWidth,
          textOffset: const Offset(0, 0.6),
          textAnchor: 'top',
        ),
      );

      if (generation != _renderGeneration) {
        await _removeOrphan(controller, line: casingLine);
        await _removeOrphan(controller, line: mainLine);
        await _removeOrphan(controller, symbol: destSymbol);
        return;
      }

      _routeCasingLine = casingLine;
      _routeLine = mainLine;
      _destinationSymbol = destSymbol;
    } catch (e, stack) {
      DLog.error('Error drawing route in MapRouteManager: $e', stack);
    }
  }

  /// Căn chỉnh Camera ôm trọn lộ trình với khoảng cách an toàn (tránh đè BottomSheet)
  void fitRouteBounds({
    required MapLibreMapController? controller,
    required RouteResult routeResult,
    RoutePoint? origin,
    RoutePoint? destination,
  }) {
    if (controller == null || !routeResult.isSuccess) return;

    final latLngs = parseRoutePoints(routeResult.points);
    if (latLngs.isEmpty) return;

    // Kiểm tra nếu 2 điểm quá gần (< 50m) thì animate zoom cố định
    if (origin != null && destination != null) {
      final distKm = AppUtils.instance.calculateDistance(
        origin.lat,
        origin.lon,
        destination.lat,
        destination.lon,
      );
      if (distKm < RoutingConstants.minDistanceForFitBoundsKm) {
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(destination.lat, destination.lon),
            RoutingConstants.closeDistanceZoomLevel,
          ),
        );
        return;
      }
    }

    final bounds = calculateRouteBounds(latLngs);
    if (bounds != null) {
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: RoutingConstants.routeFitPaddingLeft,
          top: RoutingConstants.routeFitPaddingTop,
          right: RoutingConstants.routeFitPaddingRight,
          bottom: RoutingConstants.routeFitPaddingBottom,
        ),
      );
    }
  }

  /// Xóa toàn bộ đường đi và marker lộ trình
  Future<void> clearRoute(MapLibreMapController? controller) async {
    _renderGeneration++;
    await _clearLinesAndSymbols(controller);
  }

  Future<void> _removeOrphan(
    MapLibreMapController? controller, {
    Line? line,
    Symbol? symbol,
  }) async {
    if (controller == null) return;
    if (line != null) {
      try {
        await controller.removeLine(line);
      } catch (e) {
        DLog.warning('Failed to remove orphan line in MapRouteManager: $e');
      }
    }
    if (symbol != null) {
      try {
        await controller.removeSymbol(symbol);
      } catch (e) {
        DLog.warning('Failed to remove orphan symbol in MapRouteManager: $e');
      }
    }
  }

  Future<void> _clearLinesAndSymbols(MapLibreMapController? controller) async {
    if (controller == null) return;

    if (_routeLine != null) {
      try {
        await controller.removeLine(_routeLine!);
      } catch (e) {
        DLog.warning('Failed to remove _routeLine in MapRouteManager: $e');
      }
      _routeLine = null;
    }

    if (_routeCasingLine != null) {
      try {
        await controller.removeLine(_routeCasingLine!);
      } catch (e) {
        DLog.warning('Failed to remove _routeCasingLine in MapRouteManager: $e');
      }
      _routeCasingLine = null;
    }

    if (_destinationSymbol != null) {
      try {
        await controller.removeSymbol(_destinationSymbol!);
      } catch (e) {
        DLog.warning('Failed to remove _destinationSymbol in MapRouteManager: $e');
      }
      _destinationSymbol = null;
    }
  }
}
