import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/cubits/map_display_cubit/map_display_state.dart';
import 'package:s_map/commons/utils/app_utils.dart';
import 'package:s_map/commons/utils/circular_ema_filter.dart';
import 'package:s_map/constants/constants.dart';

/// Quản lý các thao tác điều khiển camera, tính toán tâm khung nhìn và ngưỡng dịch chuyển camera.
class MapCameraController {
  LatLngBounds? lastSearchedBounds;

  /// Thực thi action camera từ MapDisplayCubit
  void applyCameraAction(
    MapLibreMapController? controller,
    MapCameraAction action,
  ) {
    if (controller == null) return;
    switch (action.type) {
      case MapCameraActionType.animateToPosition:
        if (action.target != null) {
          controller.animateCamera(
            CameraUpdate.newLatLngZoom(
              action.target!,
              action.zoom ?? MapConstants.locateMeZoom,
            ),
          );
        }
        break;
      case MapCameraActionType.zoomIn:
        controller.animateCamera(CameraUpdate.zoomIn());
        break;
      case MapCameraActionType.zoomOut:
        controller.animateCamera(CameraUpdate.zoomOut());
        break;
      case MapCameraActionType.bearingTo:
        if (action.bearing != null) {
          controller.moveCamera(CameraUpdate.bearingTo(action.bearing!));
        }
        break;
    }
  }

  /// Tính tâm của một khung nhìn LatLngBounds (thuần túy)
  static LatLng getCenter(LatLngBounds bounds) {
    return LatLng(
      (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
      (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
    );
  }

  /// Kiểm tra xem camera đã di chuyển vượt quá ngưỡng khoảng cách so với vị trí tìm kiếm trước đó hay chưa
  static bool hasMovedBeyondThreshold({
    required LatLngBounds currentBounds,
    required LatLngBounds? lastBounds,
    double thresholdKm = MapConstants.viewportSearchDistanceThresholdKm,
  }) {
    if (lastBounds == null) return false;
    final currentCenter = getCenter(currentBounds);
    final lastCenter = getCenter(lastBounds);
    final distKm = AppUtils.instance.calculateDistance(
      currentCenter.latitude,
      currentCenter.longitude,
      lastCenter.latitude,
      lastCenter.longitude,
    );
    return distKm > thresholdKm;
  }

  /// Xử lý khi camera dừng lại (Idle)
  void handleCameraIdle({
    required MapLibreMapController? controller,
    required void Function(LatLngBounds bounds) onInitialSearch,
    required void Function(bool visible) onSearchAreaVisibilityChanged,
  }) {
    if (controller == null) return;
    controller.getVisibleRegion().then((bounds) {
      if (lastSearchedBounds == null) {
        lastSearchedBounds = bounds;
        onInitialSearch(bounds);
        onSearchAreaVisibilityChanged(false);
      } else {
        final moved = hasMovedBeyondThreshold(
          currentBounds: bounds,
          lastBounds: lastSearchedBounds,
        );
        if (moved) {
          onSearchAreaVisibilityChanged(true);
        }
      }
    }).catchError((_) {});
  }

  /// Thực thi một hành động với LatLngBounds của khung nhìn hiện tại
  void executeInVisibleRegion(
    MapLibreMapController? controller,
    void Function(LatLngBounds bounds) onBounds,
  ) {
    if (controller == null) return;
    controller.getVisibleRegion().then((bounds) {
      lastSearchedBounds = bounds;
      onBounds(bounds);
    }).catchError((_) {});
  }

  /// Tính toán mức zoom camera linh hoạt theo tốc độ di chuyển
  static double calculateDynamicZoom(double? speedKmh) {
    if (speedKmh == null ||
        speedKmh <= RoutingConstants.navLowSpeedThresholdKmh) {
      return RoutingConstants.navZoomLowSpeed;
    }
    if (speedKmh <= RoutingConstants.navHighSpeedThresholdKmh) {
      return RoutingConstants.navZoomMidSpeed;
    }
    return RoutingConstants.navZoomHighSpeed;
  }

  final CircularEmaFilter _bearingFilter = CircularEmaFilter(defaultAlpha: 0.25);
  double? _lastValidBearing;

  /// Cập nhật Camera theo góc nhìn dẫn đường 3D (Heading-up + Tilt + Dynamic Zoom)
  /// Cập nhật Camera theo góc nhìn dẫn đường 3D (Heading-up + Tilt + Dynamic Zoom)
  ///
  /// Áp dụng bộ lọc Circular EMA và chiến lược Sensor Fusion thực thụ (GPS Bearing + Hardware Compass):
  /// * Tốc độ >= 8.0 km/h: Ưu tiên GPS motion vector (gpsHeading) vì độ ổn định cực cao khi chuyển động (alpha = 0.25).
  /// * Tốc độ từ 3.0 đến 8.0 km/h: Chuyển tiếp kết hợp giữa GPS và La bàn (alpha = 0.15).
  /// * Tốc độ < 3.0 km/h (đứng yên/dừng đèn đỏ): GPS không thể tính vector. Chuyển sang cảm biến La bàn từ trường
  ///   (compassHeading) với alpha = 0.08 để chống rung chấn tay lái xe máy nhưng vẫn mượt mà xoay theo góc quay đầu xe.
  void updateNavigationCamera({
    required MapLibreMapController? controller,
    required double lat,
    required double lon,
    required double? gpsHeading,
    double? compassHeading,
    required double? speedKmh,
    double tilt = RoutingConstants.navCameraTilt,
  }) {
    if (controller == null) return;
    final zoom = calculateDynamicZoom(speedKmh);

    final double targetBearing;
    final double alpha;

    if (gpsHeading != null && (speedKmh == null || speedKmh >= 8.0)) {
      targetBearing = gpsHeading;
      alpha = 0.25;
      _lastValidBearing = gpsHeading;
    } else if (speedKmh != null && speedKmh >= 3.0) {
      targetBearing = gpsHeading ?? compassHeading ?? _lastValidBearing ?? 0.0;
      alpha = 0.15;
      if (gpsHeading != null) _lastValidBearing = gpsHeading;
    } else {
      // Khi dừng đèn đỏ hoặc đứng yên: Ưu tiên la bàn phần cứng (compassHeading)
      targetBearing = compassHeading ?? _lastValidBearing ?? gpsHeading ?? 0.0;
      alpha = 0.08;
    }

    final effectiveBearing = _bearingFilter.filter(targetBearing, alpha: alpha);

    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(lat, lon),
          zoom: zoom,
          bearing: effectiveBearing,
          tilt: tilt,
        ),
      ),
    );
  }

  /// Reset vị trí tìm kiếm đã lưu và bộ lọc la bàn
  void reset() {
    lastSearchedBounds = null;
    _lastValidBearing = null;
    _bearingFilter.reset();
  }
}
