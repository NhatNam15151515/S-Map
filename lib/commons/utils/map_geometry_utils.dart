import 'dart:math' as math;

/// Engine hình học / địa lý lõi (Geodesy Core) của S-Map.
///
/// **Single Source of Truth** cho mọi phép tính khoảng cách, chiếu hình,
/// bearing trên toạ độ GPS. Mọi class khác trong codebase PHẢI gọi qua đây
/// thay vì tự cài đặt lại.
///
/// Tất cả phương thức đều là `static` thuần tuý (không state, không side-effect).
class MapGeometryUtils {
  MapGeometryUtils._();

  // ── Hằng số chuẩn hoá ──────────────────────────────────────────────

  /// Bán kính Trái Đất trung bình (mét) theo WGS-84 spherical approximation.
  static const double earthRadiusMeters = 6371000.0;

  /// Số mét trên 1° vĩ tuyến (xấp xỉ, dùng cho chuyển đổi lat/lon ↔ mét).
  static const double metersPerDegreeLat = 111320.0;

  /// Hệ số chuyển đổi Degrees → Radians.
  static const double degToRad = math.pi / 180.0;

  /// Hệ số chuyển đổi Radians → Degrees.
  static const double radToDeg = 180.0 / math.pi;

  // ── Khoảng cách Haversine ──────────────────────────────────────────

  /// Khoảng cách Haversine chuẩn xác giữa 2 điểm toạ độ (đơn vị: **mét**).
  ///
  /// An toàn NaN: `a.clamp(0.0, 1.0)` ngăn sai số dấu phẩy động khi 2 điểm
  /// gần trùng hoặc đối cực làm `a > 1.0` → `asin(sqrt(a))` = NaN.
  static double haversineDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = (lat2 - lat1) * degToRad;
    final dLon = (lon2 - lon1) * degToRad;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * degToRad) *
            math.cos(lat2 * degToRad) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
    return earthRadiusMeters * c;
  }

  /// Khoảng cách Haversine giữa 2 điểm toạ độ (đơn vị: **km**).
  ///
  /// Backward compatibility cho `AppUtils.calculateDistance`.
  static double haversineDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return haversineDistanceMeters(lat1, lon1, lat2, lon2) / 1000.0;
  }

  // ── Chiếu điểm lên đoạn thẳng ─────────────────────────────────────

  /// Tính khoảng cách trực giao ngắn nhất (mét) **và** điểm chiếu gần nhất
  /// từ điểm P đến đoạn thẳng AB bằng Local Equirectangular Projection.
  ///
  /// Trả về `(distanceMeters, closestLat, closestLon)`.
  static (double distanceMeters, double closestLat, double closestLon)
      pointToSegmentDistance({
    required double pLat,
    required double pLon,
    required double aLat,
    required double aLon,
    required double bLat,
    required double bLon,
  }) {
    // Vĩ độ trung bình để chiếu phẳng Equirectangular
    final meanLat = ((aLat + bLat) / 2.0) * degToRad;
    final cosMeanLat = math.cos(meanLat);

    // Vector đoạn thẳng AB (đơn vị: mét)
    final dx = (bLon - aLon) * degToRad * earthRadiusMeters * cosMeanLat;
    final dy = (bLat - aLat) * degToRad * earthRadiusMeters;

    // Vector AP (đơn vị: mét)
    final px = (pLon - aLon) * degToRad * earthRadiusMeters * cosMeanLat;
    final py = (pLat - aLat) * degToRad * earthRadiusMeters;

    final segmentLengthSquared = dx * dx + dy * dy;

    // Trường hợp suy biến: điểm A trùng điểm B
    if (segmentLengthSquared <= 1e-6) {
      final dist = math.sqrt(px * px + py * py);
      return (dist, aLat, aLon);
    }

    // Hệ số chiếu vô hướng t của điểm P lên vector AB
    final t = ((px * dx + py * dy) / segmentLengthSquared).clamp(0.0, 1.0);

    // Toạ độ điểm gần nhất Q trên đoạn AB (trong hệ phẳng)
    final qx = t * dx;
    final qy = t * dy;

    final dist = math.sqrt((px - qx) * (px - qx) + (py - qy) * (py - qy));

    // Đổi ngược toạ độ phẳng Q sang Lat/Lon
    final closestLat = aLat + (qy / earthRadiusMeters) * radToDeg;
    final safeCos = cosMeanLat.abs() < 1e-6 ? 1.0 : cosMeanLat;
    final closestLon =
        aLon + (qx / (earthRadiusMeters * safeCos)) * radToDeg;

    return (dist, closestLat, closestLon);
  }

  /// Phiên bản nhẹ: **CHỈ** trả về khoảng cách trực giao (mét), không tính
  /// toạ độ điểm chiếu gần nhất.
  ///
  /// Tối ưu cho DouglasPeucker hot path — tránh overhead tuple allocation
  /// và 2 phép chia ngược toạ độ.
  static double perpendicularDistanceMeters(
    double pLat,
    double pLon,
    double aLat,
    double aLon,
    double bLat,
    double bLon,
  ) {
    final meanLat = ((aLat + bLat) / 2.0) * degToRad;
    final cosMeanLat = math.cos(meanLat);

    final dx = (bLon - aLon) * degToRad * earthRadiusMeters * cosMeanLat;
    final dy = (bLat - aLat) * degToRad * earthRadiusMeters;

    final px = (pLon - aLon) * degToRad * earthRadiusMeters * cosMeanLat;
    final py = (pLat - aLat) * degToRad * earthRadiusMeters;

    final segmentLengthSquared = dx * dx + dy * dy;

    if (segmentLengthSquared <= 1e-6) {
      return math.sqrt(px * px + py * py);
    }

    final t = ((px * dx + py * dy) / segmentLengthSquared).clamp(0.0, 1.0);
    final rx = px - t * dx;
    final ry = py - t * dy;

    return math.sqrt(rx * rx + ry * ry);
  }

  // ── So sánh khoảng cách siêu nhanh (cho Sort) ─────────────────────

  /// Bình phương khoảng cách phẳng cục bộ (m²) — **CHỈ dùng cho so sánh thứ tự**.
  ///
  /// Precompute `cosRefLat = cos(refLat * degToRad)` **ngoài** vòng lặp sort,
  /// rồi gọi hàm này cho mỗi điểm. **KHÔNG có hàm lượng giác nào bên trong.**
  ///
  /// Bảo toàn thứ tự khoảng cách với Haversine cho khoảng cách < 100km
  /// (sai lệch < 0.01%).
  ///
  /// Ví dụ:
  /// ```dart
  /// final cosRef = cos(center.latitude * MapGeometryUtils.degToRad);
  /// pois.sort((a, b) {
  ///   final da = MapGeometryUtils.fastDistanceSqMeters(cosRef, center.lat, center.lon, a.lat, a.lon);
  ///   final db = MapGeometryUtils.fastDistanceSqMeters(cosRef, center.lat, center.lon, b.lat, b.lon);
  ///   return da.compareTo(db);
  /// });
  /// ```
  static double fastDistanceSqMeters(
    double cosRefLat,
    double refLat,
    double refLon,
    double lat,
    double lon,
  ) {
    final dLat = (lat - refLat) * metersPerDegreeLat;
    final dLon = (lon - refLon) * metersPerDegreeLat * cosRefLat;
    return dLat * dLat + dLon * dLon;
  }

  // ── Bearing (Forward Azimuth) ──────────────────────────────────────

  /// Góc hướng di chuyển (Forward Azimuth) từ điểm 1 sang điểm 2.
  ///
  /// Trả về giá trị 0° – 360° (Bắc = 0°, theo chiều kim đồng hồ).
  static double bearing(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final phi1 = lat1 * degToRad;
    final phi2 = lat2 * degToRad;
    final deltaLambda = (lon2 - lon1) * degToRad;

    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);

    final theta = math.atan2(y, x);
    return (theta * radToDeg + 360.0) % 360.0;
  }

  // ── Polyline Utilities ─────────────────────────────────────────────

  /// Tính tổng chiều dài polyline (mét) bằng Haversine.
  ///
  /// [points] là danh sách `[[lat, lon], ...]`.
  static double polylineLengthMeters(List<List<double>> points) {
    if (points.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      total += haversineDistanceMeters(
        points[i][0],
        points[i][1],
        points[i + 1][0],
        points[i + 1][1],
      );
    }
    return total;
  }

  /// Tìm điểm gần nhất trên polyline từ vị trí P.
  ///
  /// Trả về `(segmentIndex, distanceMeters, closestLat, closestLon)`.
  ///
  /// Nếu [startIndex] != null, ưu tiên quét cửa sổ cục bộ
  /// `[startIndex - 1, startIndex + lookAheadSegments]` trước. Nếu kết quả
  /// trong window vượt ngưỡng (hoặc không có startIndex), quét toàn bộ.
  static (int segmentIndex, double distanceMeters, double closestLat,
      double closestLon) findClosestPointOnPolyline({
    required double pLat,
    required double pLon,
    required List<List<double>> points,
    int? startIndex,
    int lookAheadSegments = 5,
  }) {
    if (points.isEmpty) {
      return (0, double.infinity, pLat, pLon);
    }
    if (points.length == 1) {
      final dist = haversineDistanceMeters(pLat, pLon, points[0][0], points[0][1]);
      return (0, dist, points[0][0], points[0][1]);
    }

    final totalSegments = points.length - 1;

    double globalMinDist = double.infinity;
    int globalBestSeg = 0;
    double globalClosestLat = pLat;
    double globalClosestLon = pLon;

    for (int i = 0; i < totalSegments; i++) {
      final a = points[i];
      final b = points[i + 1];

      final (dist, cLat, cLon) = pointToSegmentDistance(
        pLat: pLat,
        pLon: pLon,
        aLat: a[0],
        aLon: a[1],
        bLat: b[0],
        bLon: b[1],
      );

      if (dist < globalMinDist) {
        globalMinDist = dist;
        globalBestSeg = i;
        globalClosestLat = cLat;
        globalClosestLon = cLon;
      }
    }

    return (globalBestSeg, globalMinDist, globalClosestLat, globalClosestLon);
  }

  // ── Bounding Box ──────────────────────────────────────────────────

  /// Tính bounding box delta (deltaLat, deltaLon) từ tâm + bán kính (mét).
  ///
  /// Thay thế cho tất cả magic number `111320.0` phân tán trong codebase.
  ///
  /// Ví dụ:
  /// ```dart
  /// final (dLat, dLon) = MapGeometryUtils.boundingBoxDelta(10.78, 30.0);
  /// final minLat = lat - dLat;
  /// final maxLat = lat + dLat;
  /// ```
  static (double deltaLat, double deltaLon) boundingBoxDelta(
    double centerLat,
    double radiusMeters,
  ) {
    final deltaLat = radiusMeters / metersPerDegreeLat;
    final cosLat = math.cos(centerLat * degToRad);
    final safeCos = cosLat.abs() < 1e-6 ? 1.0 : cosLat;
    final deltaLon = radiusMeters / (metersPerDegreeLat * safeCos);
    return (deltaLat, deltaLon);
  }

  /// Kiểm tra 2 toạ độ có nằm gần nhau trong ngưỡng [maxDistanceMeters] (mặc định 15.0m) hay không.
  ///
  /// Thay thế cho các phép so sánh thủ công `(lat1 - lat2).abs() < 0.0001`
  /// phân tán trong codebase. Tối ưu hoá với bounding box check trước khi
  /// gọi Haversine.
  static bool isNearCoordinate(
    double lat1,
    double lon1,
    double lat2,
    double lon2, {
    double maxDistanceMeters = 15.0,
  }) {
    // Fast-path: Bounding box vĩ độ thô (1° lat ≈ 111.32km)
    final maxDegreeLat = maxDistanceMeters / metersPerDegreeLat;
    if ((lat1 - lat2).abs() > maxDegreeLat) return false;

    // Chi tiết với Haversine
    return haversineDistanceMeters(lat1, lon1, lat2, lon2) <= maxDistanceMeters;
  }
}
