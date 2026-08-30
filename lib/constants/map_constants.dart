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

  /// Cấu hình hiển thị Marker Symbol trên bản đồ
  static const double symbolTextSize = 11.0;
  static const double symbolTextHaloWidth = 1.5;
  static const double symbolIconSize = 1.05;
  static const double selectedSymbolTextSize = 12.0;
  static const double selectedSymbolIconSize = 1.35;
  static const double selectedSymbolTextHaloWidth = 2.0;
}
