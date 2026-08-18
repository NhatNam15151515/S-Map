import 'dart:math' as math;
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/interfaces/i_off_route_detector.dart';

/// Bộ phát hiện lệch tuyến đường (Off-route Detector) tối ưu hóa với thuật toán
/// Local Equirectangular Projection và Sliding Window Search.
class OffRouteDetector implements IOffRouteDetector {
  static const double _earthRadiusMeters = 6371000.0;
  static const double _degToRad = math.pi / 180.0;
  static const double _radToDeg = 180.0 / math.pi;

  @override
  final double thresholdMeters;

  const OffRouteDetector({
    this.thresholdMeters = RoutingConstants.defaultOffRouteThresholdMeters,
  });

  /// Tính khoảng cách trực giao ngắn nhất (mét) và điểm chiếu gần nhất từ điểm P đến đoạn thẳng AB
  static (double distanceMeters, double closestLat, double closestLon)
      calculatePointToSegmentDistance({
    required double pLat,
    required double pLon,
    required double aLat,
    required double aLon,
    required double bLat,
    required double bLon,
  }) {
    // Vĩ độ trung bình để chiếu phẳng Equirectangular
    final meanLat = ((aLat + bLat) / 2.0) * _degToRad;
    final cosMeanLat = math.cos(meanLat);

    // Vector đoạn thẳng AB (đơn vị: mét)
    final dx = (bLon - aLon) * _degToRad * _earthRadiusMeters * cosMeanLat;
    final dy = (bLat - aLat) * _degToRad * _earthRadiusMeters;

    // Vector AP (đơn vị: mét)
    final px = (pLon - aLon) * _degToRad * _earthRadiusMeters * cosMeanLat;
    final py = (pLat - aLat) * _degToRad * _earthRadiusMeters;

    final segmentLengthSquared = dx * dx + dy * dy;

    // Trường hợp suy biến: điểm A trùng điểm B
    if (segmentLengthSquared <= 1e-6) {
      final dist = math.sqrt(px * px + py * py);
      return (dist, aLat, aLon);
    }

    // Hệ số chiếu vô hướng t của điểm P lên vector AB
    final t = (px * dx + py * dy) / segmentLengthSquared;
    final tClamped = t.clamp(0.0, 1.0);

    // Tọa độ điểm gần nhất Q trên đoạn AB
    final qx = tClamped * dx;
    final qy = tClamped * dy;

    final dist = math.sqrt((px - qx) * (px - qx) + (py - qy) * (py - qy));

    // Đổi ngược tọa độ phẳng của Q sang Lat/Lon
    final closestLat = aLat + (qy / _earthRadiusMeters) * _radToDeg;
    final closestLon =
        aLon + (qx / (_earthRadiusMeters * (cosMeanLat.abs() < 1e-6 ? 1.0 : cosMeanLat))) * _radToDeg;

    return (dist, closestLat, closestLon);
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

  static double _calculateHaversineDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = (lat2 - lat1) * _degToRad;
    final dLon = (lon2 - lon1) * _degToRad;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * _degToRad) *
            math.cos(lat2 * _degToRad) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.asin(math.sqrt(a));
    return _earthRadiusMeters * c;
  }
}
