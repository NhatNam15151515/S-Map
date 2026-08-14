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
}
