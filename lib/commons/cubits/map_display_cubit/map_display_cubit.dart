import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/mixin/app_mixin.dart';
import 'package:s_map/constants/map_constants.dart';
import 'package:s_map/interfaces/i_location_service.dart';
import 'package:s_map/services/location_services.dart';
import 'map_display_state.dart';

class MapDisplayCubit extends Cubit<MapDisplayState> with AppMixin {
  MapLibreMapController? controller;
  final ILocationService _locationService;

  MapDisplayCubit({ILocationService? locationService})
      : _locationService = locationService ?? LocationService.instance,
        super(const MapDisplayState(status: MapDisplayStatus.initial));

  /// Safe emit guard rule mandatory for all Cubits/Blocs
  @override
  void emit(MapDisplayState state) {
    if (isClosed) return;
    super.emit(state);
  }

  void onMapCreated(MapLibreMapController mapController) {
    controller = mapController;
    emit(state.copyWith(status: MapDisplayStatus.loading));
  }

  Future<void> onStyleLoaded() async {
    emit(state.copyWith(status: MapDisplayStatus.ready));
    await locateMe();
  }

  Future<void> locateMe() async {
    // Phase 1: Instant Flyback (<50ms) - Bay ngay về vị trí đã lưu nếu có
    final cachedPos = state.currentPosition;
    if (cachedPos != null) {
      emit(state.copyWith(
        center: cachedPos,
        isFollowingUser: true,
        clearError: true,
      ));
      controller?.animateCamera(
        CameraUpdate.newLatLngZoom(cachedPos, MapConstants.locateMeZoom),
      );
    } else {
      try {
        final lastKnown = await _locationService.getLastKnownPosition();
        if (lastKnown != null && state.currentPosition == null) {
          final latLng = LatLng(lastKnown.latitude, lastKnown.longitude);
          emit(state.copyWith(
            currentPosition: latLng,
            center: latLng,
            isFollowingUser: true,
            clearError: true,
          ));
          controller?.animateCamera(
            CameraUpdate.newLatLngZoom(latLng, MapConstants.locateMeZoom),
          );
        }
      } catch (_) {}
    }

    // Phase 2: Fresh GPS Fix - Lấy tọa độ mới nhất và tinh chỉnh nhẹ camera
    try {
      final pos = await _locationService.getCurrentPosition();
      final latLng = LatLng(pos.latitude, pos.longitude);
      final isFirstLocate = cachedPos == null;

      emit(state.copyWith(
        status: MapDisplayStatus.ready,
        currentPosition: latLng,
        center: latLng,
        isFollowingUser: true,
        clearError: true,
      ));

      if (controller != null &&
          (isFirstLocate ||
              (state.isFollowingUser &&
                  (cachedPos.latitude != latLng.latitude ||
                      cachedPos.longitude != latLng.longitude)))) {
        await controller!.animateCamera(
          CameraUpdate.newLatLngZoom(latLng, MapConstants.locateMeZoom),
        );
      }
    } on LocationServiceDisabledException catch (e) {
      DLog.error('Dịch vụ định vị đang tắt: $e');
      _fallbackToDefaultLocation(
        errorMessageKey: 'map.location_service_disabled',
      );
    } on PermissionDeniedException catch (e) {
      DLog.error('Quyền vị trí bị từ chối: $e');
      _fallbackToDefaultLocation(
        errorMessageKey: 'map.location_permission_denied',
      );
    } on LocationPermissionDeniedForeverException catch (e) {
      DLog.error('Quyền vị trí bị từ chối vĩnh viễn: $e');
      _fallbackToDefaultLocation(
        errorMessageKey: 'map.location_permission_denied_forever',
      );
    } catch (e) {
      DLog.error('Lỗi lấy vị trí hiện tại: $e');
      _fallbackToDefaultLocation(
        errorMessageKey: 'map.locate_error',
      );
    }
  }

  void _fallbackToDefaultLocation({String? errorMessageKey}) {
    emit(state.copyWith(
      currentPosition: state.currentPosition ?? MapConstants.defaultLocation,
      isFollowingUser: false,
      errorMessageKey: errorMessageKey,
    ));
  }

  void onCameraMove(CameraPosition position) {
    emit(state.copyWith(
      center: position.target,
      zoom: position.zoom,
      rotation: position.bearing,
      clearError: true, // Xóa thông báo lỗi khi người dùng di chuyển bản đồ
    ));
  }

  void onCameraTrackingDismissed() {
    emit(state.copyWith(isFollowingUser: false));
  }

  void clearError() {
    if (state.errorMessageKey != null) {
      emit(state.copyWith(clearError: true));
    }
  }

  void setError(String messageKey) {
    DLog.error('Lỗi bản đồ: $messageKey');
    emit(state.copyWith(
      status: MapDisplayStatus.error,
      errorMessageKey: messageKey,
    ));
  }

  void zoomIn() {
    controller?.animateCamera(CameraUpdate.zoomIn());
  }

  void zoomOut() {
    controller?.animateCamera(CameraUpdate.zoomOut());
  }
}
