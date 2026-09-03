import 'dart:math' as math;

/// Thuật toán Ramer-Douglas-Peucker đơn giản hoá chuỗi toạ độ Polyline
///
/// Giảm tải số lượng đỉnh hình học (vertices) của lộ trình trước khi nạp vào
/// MapLibre GPU renderer, duy trì tốc độ khung hình 60/120 FPS và tiết kiệm pin.
class DouglasPeucker {
  DouglasPeucker._();

  static const double _earthRadiusMeters = 6371000.0;
  static const double _degToRad = math.pi / 180.0;

  /// Đơn giản hoá danh sách toạ độ `[[lat, lon], ...]`
  /// [toleranceMeters]: Ngưỡng sai số trực giao cho phép (mặc định 2.5 mét)
  static List<List<double>> simplify(
    List<List<double>> points, {
    double toleranceMeters = 2.5,
  }) {
    if (points.length <= 2) return points;

    return _simplifyRecursive(points, 0, points.length - 1, toleranceMeters);
  }

  static List<List<double>> _simplifyRecursive(
    List<List<double>> points,
    int first,
    int last,
    double toleranceMeters,
  ) {
    var maxDistance = 0.0;
    var index = first;

    final pFirst = points[first];
    final pLast = points[last];

    for (var i = first + 1; i < last; i++) {
      final dist = _perpendicularDistanceMeters(points[i], pFirst, pLast);
      if (dist > maxDistance) {
        maxDistance = dist;
        index = i;
      }
    }

    if (maxDistance > toleranceMeters) {
      final left = _simplifyRecursive(points, first, index, toleranceMeters);
      final right = _simplifyRecursive(points, index, last, toleranceMeters);

      // Nối 2 nửa kết quả (bỏ bớt 1 điểm chung ở vị trí index)
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [points[first], points[last]];
    }
  }

  /// Tính khoảng cách trực giao từ điểm P đến đoạn thẳng AB bằng phép chiếu phẳng Equirectangular cục bộ
  static double _perpendicularDistanceMeters(
    List<double> p,
    List<double> a,
    List<double> b,
  ) {
    final meanLat = ((a[0] + b[0]) / 2.0) * _degToRad;
    final cosMeanLat = math.cos(meanLat);

    final dx = (b[1] - a[1]) * _degToRad * _earthRadiusMeters * cosMeanLat;
    final dy = (b[0] - a[0]) * _degToRad * _earthRadiusMeters;

    final px = (p[1] - a[1]) * _degToRad * _earthRadiusMeters * cosMeanLat;
    final py = (p[0] - a[0]) * _degToRad * _earthRadiusMeters;

    final segmentLengthSquared = dx * dx + dy * dy;

    if (segmentLengthSquared <= 1e-6) {
      return math.sqrt(px * px + py * py);
    }

    final t = ((px * dx + py * dy) / segmentLengthSquared).clamp(0.0, 1.0);
    final qx = t * dx;
    final qy = t * dy;

    final rx = px - qx;
    final ry = py - qy;

    return math.sqrt(rx * rx + ry * ry);
  }
}
