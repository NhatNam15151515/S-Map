import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart';

class MapConstants {
  MapConstants._();

  /// Tọa độ trung tâm mặc định (TP. Hồ Chí Minh)
  static const LatLng defaultLocation = LatLng(10.7769, 106.7009);

  /// Mức zoom mặc định cho bản đồ
  static const double defaultZoom = 14.0;

  /// Mức zoom khi định vị vị trí người dùng
  static const double locateMeZoom = 16.0;

  /// Zoom tối thiểu và tối đa
  static const double minZoom = 3.0;
  static const double maxZoom = 19.0;

  /// Ngưỡng khoảng cách di chuyển camera tối thiểu (km) để kích hoạt nút "Tìm trong khu vực này"
  static const double viewportSearchDistanceThresholdKm = 0.4;

  /// Cấu hình progressive area search.
  ///
  /// Zoom chỉ là cách biểu diễn UX của location bias. Engine vẫn dùng bán
  /// kính để tìm category gần tâm, còn text search sẽ bổ sung ứng viên toàn
  /// dataset để không biến vùng bias thành một rào chắn cứng.
  static const double areaSearchInitialZoom = 13.0;
  static const double areaSearchMinZoom = 5.5;
  static final Map<double, double> areaSearchZoomToRadiusKm =
      Map.unmodifiable({
    13.0: 8.0,
    12.0: 16.0,
    11.0: 32.0,
    10.0: 64.0,
    9.0: 128.0,
    8.0: 256.0,
    7.0: 500.0,
    6.0: 800.0,
    5.5: 1200.0,
  });

  /// Tạo bounding box xấp xỉ từ tâm + bán kính. Kết quả thực tế luôn được
  /// lọc lại bằng khoảng cách địa lý trước khi trả về cho UI.
  static LatLngBounds boundsFromCenter(LatLng center, double radiusKm) {
    final latDelta = radiusKm / 111.0;
    final cosLatitude = math.cos(center.latitude * math.pi / 180).abs();
    final safeCosLatitude = math.max(cosLatitude, 0.1).toDouble();
    final lonDelta = radiusKm / (111.0 * safeCosLatitude);

    return LatLngBounds(
      southwest: LatLng(
        math.max(-90.0, center.latitude - latDelta).toDouble(),
        math.max(-180.0, center.longitude - lonDelta).toDouble(),
      ),
      northeast: LatLng(
        math.min(90.0, center.latitude + latDelta).toDouble(),
        math.min(180.0, center.longitude + lonDelta).toDouble(),
      ),
    );
  }

  /// Cấu hình hiển thị Marker Symbol trên bản đồ
  /// Scale chung cho ảnh redmarker; giữ nguyên tỉ lệ giữa marker thường và
  /// marker được chọn nhưng giảm kích thước hiển thị khoảng 30%.
  static const double markerIconScale = 0.7;
  static const double symbolTextSize = 11.0;
  static const double symbolTextHaloWidth = 1.5;
  static const double symbolIconSize = 1.05 * markerIconScale;
  static const double selectedSymbolTextSize = 12.0;
  static const double selectedSymbolIconSize = 1.35 * markerIconScale;
  static const double selectedSymbolTextHaloWidth = 2.0;
}
