import 'dart:math' as math;
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/map_geometry_utils.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/interfaces/i_off_route_detector.dart';

/// Bộ phát hiện lệch tuyến đường (Off-route Detector) tối ưu hóa với thuật toán
/// Local Equirectangular Projection và Sliding Window Search.
class OffRouteDetector implements IOffRouteDetector {

  @override
  final double thresholdMeters;

  const OffRouteDetector({
    this.thresholdMeters = RoutingConstants.defaultOffRouteThresholdMeters,
  });

  /// Tính khoảng cách trực giao ngắn nhất (mét) và điểm chiếu gần nhất từ điểm P đến đoạn thẳng AB.
  ///
  /// Delegate sang [MapGeometryUtils.pointToSegmentDistance].
  static (double distanceMeters, double closestLat, double closestLon)
      calculatePointToSegmentDistance({
    required double pLat,
    required double pLon,
    required double aLat,
    required double aLon,
    required double bLat,
    required double bLon,
  }) {
    return MapGeometryUtils.pointToSegmentDistance(
      pLat: pLat,
      pLon: pLon,
      aLat: aLat,
      aLon: aLon,
      bLat: bLat,
      bLon: bLon,
    );
  }

  @override
  OffRouteStatus checkOffRoute({
    required double currentLat,
    required double currentLon,
    required List<List<double>> routePoints,
    int currentSegmentIndex = 0,
    int lookAheadSegments = 5,
  }) {
    // Trường hợp danh sách điểm không đủ tạo thành đoạn thẳng
    if (routePoints.isEmpty) {
      return const OffRouteStatus(
        isOffRoute: true,
        distanceToRoute: double.infinity,
        segmentIndex: 0,
      );
    }

    if (routePoints.length == 1) {
      final p0 = routePoints.first;
      final dist = _calculateHaversineDistanceMeters(
        currentLat,
        currentLon,
        p0[0],
        p0[1],
      );
      return OffRouteStatus(
        isOffRoute: dist > thresholdMeters,
        distanceToRoute: dist,
        segmentIndex: 0,
        closestPoint: [p0[0], p0[1]],
      );
    }

    final totalSegments = routePoints.length - 1;
    final safeCurrentIndex = currentSegmentIndex.clamp(0, totalSegments - 1);

    // 1. Sliding Window Search: Kiểm tra cửa sổ cục bộ [safeCurrentIndex - 1, safeCurrentIndex + lookAheadSegments]
    final windowStart = math.max(0, safeCurrentIndex - 1);
    final windowEnd =
        math.min(totalSegments - 1, safeCurrentIndex + lookAheadSegments);

    double minDistanceWindow = double.infinity;
    int bestSegmentWindow = safeCurrentIndex;
    List<double> closestPointWindow = [currentLat, currentLon];

    for (int i = windowStart; i <= windowEnd; i++) {
      final a = routePoints[i];
      final b = routePoints[i + 1];

      final (dist, cLat, cLon) = calculatePointToSegmentDistance(
        pLat: currentLat,
        pLon: currentLon,
        aLat: a[0],
        aLon: a[1],
        bLat: b[0],
        bLon: b[1],
      );

      if (dist < minDistanceWindow) {
        minDistanceWindow = dist;
        bestSegmentWindow = i;
        closestPointWindow = [cLat, cLon];
      }
    }

    // Nếu khoảng cách trong cửa sổ trượt <= ngưỡng (50m) -> Đang On-Route
    if (minDistanceWindow <= thresholdMeters) {
      return OffRouteStatus(
        isOffRoute: false,
        distanceToRoute: minDistanceWindow,
        segmentIndex: bestSegmentWindow,
        closestPoint: closestPointWindow,
      );
    }

    // 2. Global Scan Fallback: Khi cửa sổ trượt vượt ngưỡng, quét toàn bộ các đoạn còn lại
    // để tránh báo lệch giả khi người dùng đi tắt (shortcut) nhảy cóc qua nhiều segment
    double globalMinDistance = minDistanceWindow;
    int globalBestSegment = bestSegmentWindow;
    List<double> globalClosestPoint = closestPointWindow;

    for (int i = 0; i < totalSegments; i++) {
      // Bỏ qua các segment đã kiểm tra trong sliding window
      if (i >= windowStart && i <= windowEnd) continue;

      final a = routePoints[i];
      final b = routePoints[i + 1];

      final (dist, cLat, cLon) = calculatePointToSegmentDistance(
        pLat: currentLat,
        pLon: currentLon,
        aLat: a[0],
        aLon: a[1],
        bLat: b[0],
        bLon: b[1],
      );

      if (dist < globalMinDistance) {
        globalMinDistance = dist;
        globalBestSegment = i;
        globalClosestPoint = [cLat, cLon];
      }
    }

    final isOffRoute = globalMinDistance > thresholdMeters;

    if (isOffRoute) {
      DLog.info(
          '🚨 [OffRouteDetector] Vehicle off-route detected: dist=${globalMinDistance.toStringAsFixed(1)}m > ${thresholdMeters.toStringAsFixed(0)}m (Closest seg: $globalBestSegment/$totalSegments)');
    }

    return OffRouteStatus(
      isOffRoute: isOffRoute,
      distanceToRoute: globalMinDistance,
      segmentIndex: globalBestSegment,
      closestPoint: globalClosestPoint,
    );
  }

  /// Delegate sang [MapGeometryUtils.haversineDistanceMeters].
  static double _calculateHaversineDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return MapGeometryUtils.haversineDistanceMeters(lat1, lon1, lat2, lon2);
  }
}
