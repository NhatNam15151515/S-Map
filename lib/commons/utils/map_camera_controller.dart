import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/cubits/map_display_cubit/map_display_state.dart';
import 'package:s_map/commons/utils/app_utils.dart';
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

  /// Reset vị trí tìm kiếm đã lưu
  void reset() {
    lastSearchedBounds = null;
  }
}
