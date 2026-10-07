import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/commons/utils/app_utils.dart';
import 'package:s_map/commons/utils/douglas_peucker.dart';
import 'package:s_map/commons/utils/map_geometry_utils.dart';
import 'package:s_map/commons/utils/map_marker_helper.dart';
import 'package:s_map/commons/utils/off_route_detector.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';

/// Quản lý vẽ và xóa Polyline và Marker lộ trình trên MapLibre độc lập khỏi UI.
class MapRouteManager {
  Line? _routeLine;
  Line? _routeCasingLine;
  Line? _passedRouteLine;
  final List<Line> _alternativeLines = [];
  int _renderGeneration = 0;
  int _progressGeneration = 0;
  bool _isAssetLoaded = false;
  Symbol? _destinationSymbol;
  int _lastPassedSegmentIndex = -1;
  LatLng? _lastProgressPoint;
  double? _lastProgressDistanceMeters;

  /// Polyline đã simplify lưu lại để updateNavigationProgress dùng trực tiếp,
  /// tránh lệch pha giữa polyline trên bản đồ và raw points.
  List<LatLng>? _displayedLatLngs;
  List<double> _displayedCumulativeMeters = const [];

  /// Nạp icon marker vào engine MapLibre
  Future<void> loadMarkerAssets(MapLibreMapController? controller, {bool force = false}) async {
    if (controller == null) return;
    if (_isAssetLoaded && !force) return;
    try {
      await MapMarkerHelper.loadCommonMapMarkers(controller);
      _isAssetLoaded = true;
      DLog.info('🗺️ [MapRouteManager] Common marker assets loaded into map engine via MapMarkerHelper');
    } catch (e, stack) {
      final errorText = e.toString().toLowerCase();
      if (errorText.contains('already') && errorText.contains('image')) {
        _isAssetLoaded = true;
        DLog.info(
            '🗺️ [MapRouteManager] Marker image already exists; reusing native sprite');
      } else {
        DLog.warning('⚠️ [MapRouteManager] Failed to load marker asset: $e', stack);
      }
    }
  }

  void resetAssetLoaded() {
    _isAssetLoaded = false;
    // setStyle() invalidates native symbol handles. The route is redrawn by
    // HomeInteractiveMapLayer after the new style has loaded.
    _destinationSymbol = null;
  }

  /// Chuyển đổi danh sách [lat, lon] sang List<LatLng> an toàn với tuỳ chọn tối ưu đỉnh
  static List<LatLng> parseRoutePoints(
    List<List<double>> rawPoints, {
    bool simplify = false,
  }) {
    final effectivePoints = (simplify && rawPoints.length > 100)
        ? DouglasPeucker.simplify(rawPoints, toleranceMeters: 0.5)
        : rawPoints;
    final points = <LatLng>[];
    for (final p in effectivePoints) {
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

  /// Vẽ Polyline lộ trình và gắn Marker điểm đầu / điểm cuối (hỗ trợ nhiều lộ trình thay thế)
  Future<bool> drawRoute({
    required MapLibreMapController? controller,
    required RouteResult routeResult,
    required RoutePoint origin,
    required RoutePoint destination,
    String? destinationName,
    List<RouteResult> alternativeRoutes = const [],
    int selectedRouteIndex = 0,
  }) async {
    if (controller == null || !routeResult.isSuccess || !routeResult.hasPoints) {
      return false;
    }

    final generation = ++_renderGeneration;
    final progressGen = ++_progressGeneration;
    final latLngs = parseRoutePoints(routeResult.points, simplify: true);
    if (latLngs.isEmpty) return false;

    _lastPassedSegmentIndex = -1;
    _lastProgressPoint = null;
    _lastProgressDistanceMeters = null;
    _displayedLatLngs = latLngs;
    _displayedCumulativeMeters = _buildCumulativeDistances(latLngs);
    DLog.info('🗺️ [MapRouteManager] Drawing route on map [Gen #$generation]: ${latLngs.length} points | Destination: "$destinationName" | Alternatives: ${alternativeRoutes.length}');

    Line? casingLine;
    Line? mainLine;
    Symbol? destinationSymbol;
    final drawnAltLines = <Line>[];

    try {
      await loadMarkerAssets(controller);
      if (generation != _renderGeneration || progressGen != _progressGeneration) return false;

      // Xóa đường và marker cũ trước khi vẽ mới
      await _clearLinesAndSymbols(controller);
      if (generation != _renderGeneration || progressGen != _progressGeneration) return false;

      // 0. Vẽ các đường phụ (Alternative Routes) trước để nằm bên dưới đường chính
      for (int i = 0; i < alternativeRoutes.length; i++) {
        if (i == selectedRouteIndex) continue;
        final alt = alternativeRoutes[i];
        if (!alt.isSuccess || !alt.hasPoints) continue;
        final altLatLngs = parseRoutePoints(alt.points, simplify: true);
        if (altLatLngs.isEmpty) continue;

        final altLine = await controller.addLine(
          LineOptions(
            geometry: altLatLngs,
            lineColor: AppColors.routeAlternativeColor.toHex,
            lineWidth: RoutingConstants.routeMainLineWidth - 1.0,
            lineOpacity: 0.85,
            lineJoin: RoutingConstants.routeLineJoin,
          ),
        );
        drawnAltLines.add(altLine);
      }

      // 1. Tạo Casing Line (Viền đậm bên dưới tạo độ nổi khối)
      casingLine = await controller.addLine(
        LineOptions(
          geometry: latLngs,
          lineColor: AppColors.routeCasingColor.toHex,
          lineWidth: RoutingConstants.routeCasingLineWidth,
          lineOpacity: RoutingConstants.routeCasingOpacity,
          lineJoin: RoutingConstants.routeLineJoin,
        ),
      );

      // 2. Tạo Main Route Line (Màu xanh Google Blue chính)
      mainLine = await controller.addLine(
        LineOptions(
          geometry: latLngs,
          lineColor: AppColors.routeMainColor.toHex,
          lineWidth: RoutingConstants.routeMainLineWidth,
          lineOpacity: RoutingConstants.routeMainOpacity,
          lineJoin: RoutingConstants.routeLineJoin,
        ),
      );

      // 3. Tạo marker điểm đến bằng native Symbol riêng. Search marker
      // cũng là native Symbol nhưng được MapSymbolManager giữ trong list
      // khác, nên hide search symbols sẽ không thể xóa nhầm destination.
      destinationSymbol = await controller.addSymbol(
        SymbolOptions(
          geometry: LatLng(destination.lat, destination.lon),
          iconImage: RoutingConstants.markerImageKey,
          iconSize: MapConstants.selectedSymbolIconSize,
          iconAnchor: 'bottom',
          zIndex: 100,
        ),
      );

      if (generation != _renderGeneration || progressGen != _progressGeneration) {
        DLog.info('⏭️ [MapRouteManager] Discarding stale drawn route objects (Current #$_renderGeneration vs #$generation)');
        for (final l in drawnAltLines) {
          await _removeOrphan(controller, line: l);
        }
        await _removeOrphan(controller, line: casingLine);
        await _removeOrphan(controller, line: mainLine);
        await _removeOrphan(controller, symbol: destinationSymbol);
        return false;
      }

      _alternativeLines.addAll(drawnAltLines);
      _routeCasingLine = casingLine;
      _routeLine = mainLine;
      _destinationSymbol = destinationSymbol;
      DLog.info('✅ [MapRouteManager] Route line & destination marker drawn successfully on map');
      return true;
    } catch (e, stack) {
      // Nếu native destination symbol lỗi sau khi line đã tạo, dọn cả ba
      // object để route manager không giữ một route thiếu marker.
      for (final l in drawnAltLines) {
        await _removeOrphan(controller, line: l);
      }
      await _removeOrphan(controller, line: casingLine);
      await _removeOrphan(controller, line: mainLine);
      await _removeOrphan(controller, symbol: destinationSymbol);
      DLog.error('❌ [MapRouteManager] Error drawing route on map: $e', stack);
      return false;
    }
  }

  /// Cập nhật trạng thái tiến trình dẫn đường: làm mờ đoạn đường đã đi qua (Dim Passed Polyline)
  ///
  /// Dùng [currentLat]/[currentLon] để tìm điểm cắt chính xác trên polyline đã simplify,
  /// tránh lệch pha giữa số lượng raw points và displayed points.
  Future<void> updateNavigationProgress({
    required MapLibreMapController? controller,
    required List<List<double>> rawPoints,
    required int currentSegmentIndex,
    double? currentLat,
    double? currentLon,
    bool isOffRoute = false,
  }) async {
    if (controller == null || _routeLine == null || isOffRoute) {
      return;
    }

    // Dùng polyline đã simplify (lưu khi drawRoute) thay vì parse lại raw points
    final allPoints = _displayedLatLngs ?? parseRoutePoints(rawPoints);
    if (allPoints.isEmpty || allPoints.length < 2) {
      return;
    }

    // Tìm segment gần nhất trên DISPLAYED polyline dựa trên GPS position hiện tại.
    // Đây là cách chính xác hơn so với dùng currentSegmentIndex từ raw points.
    final match = _findClosestDisplayPosition(
      allPoints,
      currentLat,
      currentLon,
      currentSegmentIndex,
      rawPoints,
    );

    // Không để GPS nhiễu hoặc quay đầu tạm thời kéo tiến độ polyline lùi lại.
    final lastProgressDistance = _lastProgressDistanceMeters;
    if (lastProgressDistance != null &&
        match.progressMeters + 1.0 < lastProgressDistance) {
      return;
    }

    final displaySegmentIndex = match.segmentIndex;
    if (displaySegmentIndex < 0 ||
        displaySegmentIndex >= allPoints.length - 1 ||
        (displaySegmentIndex == _lastPassedSegmentIndex &&
            _lastProgressPoint != null &&
            _distanceBetween(_lastProgressPoint!, match.point) < 2.0)) {
      return;
    }

    final progressGen = ++_progressGeneration;
    final renderGen = _renderGeneration;

    try {
      final passedPoints = allPoints.sublist(0, displaySegmentIndex + 1);
      if (_distanceBetween(passedPoints.last, match.point) >= 1.0) {
        passedPoints.add(match.point);
      }
      final remainingPoints = [match.point, ...allPoints.skip(displaySegmentIndex + 1)];

      // 1. Cập nhật hoặc tạo đường xám mờ cho đoạn đã đi qua
      if (passedPoints.length < 2) {
        // Chưa đi đủ xa từ điểm xuất phát để tạo polyline đã đi.
      } else if (_passedRouteLine == null) {
        final newPassedLine = await controller.addLine(
          LineOptions(
            geometry: passedPoints,
            lineColor: AppColors.routeDimmedColor.toHex,
            lineWidth: RoutingConstants.routeDimmedLineWidth,
            lineOpacity: RoutingConstants.routeDimmedOpacity,
            lineJoin: RoutingConstants.routeLineJoin,
          ),
        );
        if (progressGen != _progressGeneration || renderGen != _renderGeneration) {
          await _removeOrphan(controller, line: newPassedLine);
          return;
        }
        _passedRouteLine = newPassedLine;
      } else {
        await controller.updateLine(
          _passedRouteLine!,
          LineOptions(geometry: passedPoints),
        );
        if (progressGen != _progressGeneration || renderGen != _renderGeneration) {
          return;
        }
      }

      // 2. Thu gọn đường màu xanh chính và viền ngoài vào phần còn lại phía trước
      if (remainingPoints.length >= 2 && _routeLine != null) {
        await controller.updateLine(
          _routeLine!,
          LineOptions(geometry: remainingPoints),
        );
        if (progressGen != _progressGeneration || renderGen != _renderGeneration) {
          return;
        }
        if (_routeCasingLine != null) {
          await controller.updateLine(
            _routeCasingLine!,
            LineOptions(geometry: remainingPoints),
          );
          if (progressGen != _progressGeneration || renderGen != _renderGeneration) {
            return;
          }
        }
      }

      _lastPassedSegmentIndex = displaySegmentIndex;
      _lastProgressPoint = match.point;
      _lastProgressDistanceMeters = match.progressMeters;
    } catch (e) {
      DLog.warning('⚠️ [MapRouteManager] Error updating navigation progress polyline: $e');
    }
  }

  /// Tìm segment gần GPS nhất trên polyline đã simplify (displayed polyline).
  /// Ưu tiên dùng lat/lon GPS với [OffRouteDetector.calculatePointToSegmentDistance],
  /// fallback về ánh xạ tỷ lệ từ raw segment index.
  ({int segmentIndex, double distanceMeters, double progressMeters, LatLng point})
  _findClosestDisplayPosition(
    List<LatLng> displayedPoints,
    double? currentLat,
    double? currentLon,
    int rawSegmentIndex,
    List<List<double>> rawPoints,
  ) {
    // Nếu có GPS position → tìm segment gần nhất trực tiếp trên displayed polyline
    if (currentLat != null && currentLon != null) {
      double minDist = double.infinity;
      int bestIndex = 0;
      LatLng bestPoint = displayedPoints.first;

      final totalSegments = displayedPoints.length - 1;
      for (int i = 0; i < totalSegments; i++) {
        final a = displayedPoints[i];
        final b = displayedPoints[i + 1];

        final (dist, closestLat, closestLon) =
            OffRouteDetector.calculatePointToSegmentDistance(
          pLat: currentLat,
          pLon: currentLon,
          aLat: a.latitude,
          aLon: a.longitude,
          bLat: b.latitude,
          bLon: b.longitude,
        );

        if (dist < minDist) {
          minDist = dist;
          bestIndex = i;
          bestPoint = LatLng(closestLat, closestLon);
        }
      }

      return (
        segmentIndex: bestIndex,
        distanceMeters: minDist,
        progressMeters: _displayedCumulativeMeters[bestIndex] +
            _distanceBetween(displayedPoints[bestIndex], bestPoint),
        point: bestPoint,
      );
    }

    // Fallback: ánh xạ tỷ lệ raw segment index sang displayed segment index
    if (rawPoints.isEmpty || displayedPoints.isEmpty) {
      return (
        segmentIndex: 0,
        distanceMeters: double.infinity,
        progressMeters: 0.0,
        point: const LatLng(0, 0),
      );
    }
    final ratio = rawSegmentIndex / rawPoints.length;
    final segmentIndex = (ratio * displayedPoints.length)
        .round()
        .clamp(0, displayedPoints.length - 2)
        .toInt();
    return (
      segmentIndex: segmentIndex,
      distanceMeters: double.infinity,
      progressMeters: _displayedCumulativeMeters.isEmpty
          ? 0.0
          : _displayedCumulativeMeters[segmentIndex],
      point: displayedPoints[segmentIndex],
    );
  }

  double _distanceBetween(LatLng first, LatLng second) {
    return MapGeometryUtils.haversineDistanceMeters(
      first.latitude,
      first.longitude,
      second.latitude,
      second.longitude,
    );
  }

  List<double> _buildCumulativeDistances(List<LatLng> points) {
    if (points.isEmpty) return const [];
    final cumulative = List<double>.filled(points.length, 0.0);
    for (var i = 1; i < points.length; i++) {
      cumulative[i] = cumulative[i - 1] +
          _distanceBetween(points[i - 1], points[i]);
    }
    return cumulative;
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
        DLog.info('🎥 [MapRouteManager] Points very close (${(distKm * 1000).round()}m) -> Zooming to 16.0');
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
      DLog.info('🎥 [MapRouteManager] Animating camera to fit bounds: SW(${bounds.southwest.latitude.toStringAsFixed(4)}, ${bounds.southwest.longitude.toStringAsFixed(4)}) -> NE(${bounds.northeast.latitude.toStringAsFixed(4)}, ${bounds.northeast.longitude.toStringAsFixed(4)})');
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
    DLog.info('🧹 [MapRouteManager] Clearing route lines & markers from map');
    _renderGeneration++;
    _progressGeneration++;
    _lastPassedSegmentIndex = -1;
    _lastProgressPoint = null;
    _lastProgressDistanceMeters = null;
    _displayedLatLngs = null;
    _displayedCumulativeMeters = const [];
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
        DLog.warning('⚠️ [MapRouteManager] Failed to remove orphan line: $e');
      }
    }
    if (symbol != null) {
      try {
        await controller.removeSymbol(symbol);
      } catch (e) {
        DLog.warning(
            '⚠️ [MapRouteManager] Failed to remove orphan destination symbol: $e');
      }
    }
  }

  Future<void> _clearLinesAndSymbols(MapLibreMapController? controller) async {
    if (controller == null) return;

    for (final altLine in _alternativeLines) {
      try {
        await controller.removeLine(altLine);
      } catch (_) {}
    }
    _alternativeLines.clear();

    if (_passedRouteLine != null) {
      try {
        await controller.removeLine(_passedRouteLine!);
      } catch (e) {
        DLog.warning('⚠️ [MapRouteManager] Failed to remove _passedRouteLine: $e');
      }
      _passedRouteLine = null;
    }

    if (_routeLine != null) {
      try {
        await controller.removeLine(_routeLine!);
      } catch (e) {
        DLog.warning('⚠️ [MapRouteManager] Failed to remove _routeLine: $e');
      }
      _routeLine = null;
    }

    if (_routeCasingLine != null) {
      try {
        await controller.removeLine(_routeCasingLine!);
      } catch (e) {
        DLog.warning('⚠️ [MapRouteManager] Failed to remove _routeCasingLine: $e');
      }
      _routeCasingLine = null;
    }

    if (_destinationSymbol != null) {
      try {
        await controller.removeSymbol(_destinationSymbol!);
      } catch (_) {}
      _destinationSymbol = null;
    }
  }
}
