import 'package:s_map/commons/utils/map_geometry_utils.dart';

/// Thuật toán Ramer-Douglas-Peucker đơn giản hoá chuỗi toạ độ Polyline
///
/// Giảm tải số lượng đỉnh hình học (vertices) của lộ trình trước khi nạp vào
/// MapLibre GPU renderer, duy trì tốc độ khung hình 60/120 FPS và tiết kiệm pin.
class DouglasPeucker {
  DouglasPeucker._();

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
      final p = points[i];
      final dist = MapGeometryUtils.perpendicularDistanceMeters(
        p[0], p[1],
        pFirst[0], pFirst[1],
        pLast[0], pLast[1],
      );
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
}

