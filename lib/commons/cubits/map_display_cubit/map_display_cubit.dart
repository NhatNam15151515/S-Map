import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/mixin/app_mixin.dart';
import 'package:s_map/services/location_services.dart';
import 'map_display_state.dart';

class MapDisplayCubit extends Cubit<MapDisplayState> with AppMixin {
  MapLibreMapController? controller;
  final LocationService _locationService;

  MapDisplayCubit({LocationService? locationService})
      : _locationService = locationService ?? LocationService.instance,
        super(const MapDisplayState(status: MapDisplayStatus.initial));

  void onMapCreated(MapLibreMapController mapController) {
    controller = mapController;
    emit(state.copyWith(status: MapDisplayStatus.loading));
  }

  Future<void> onStyleLoaded() async {
    emit(state.copyWith(status: MapDisplayStatus.ready));
    await locateMe();
  }

  Future<void> locateMe() async {
    try {
      final pos = await _locationService.getCurrentPosition();
      final latLng = LatLng(pos.latitude, pos.longitude);
      emit(state.copyWith(
        status: MapDisplayStatus.ready,
        currentPosition: latLng,
        center: latLng,
        isFollowingUser: true,
      ));

      if (controller != null) {
        await controller!.animateCamera(
          CameraUpdate.newLatLngZoom(latLng, 16.0),
        );
      }
    } on LocationServiceDisabledException catch (e) {
      DLog.error('Dịch vụ định vị đang tắt: $e');
      _fallbackToDefaultLocation(
        errorMessage: 'Dịch vụ định vị (GPS) đang tắt. Vui lòng bật định vị để tiếp tục.',
      );
    } on PermissionDeniedException catch (e) {
      DLog.error('Quyền vị trí bị từ chối: $e');
      _fallbackToDefaultLocation(
        errorMessage: 'Ứng dụng cần quyền truy cập vị trí để định vị.',
      );
    } on LocationPermissionDeniedForeverException catch (e) {
      DLog.error('Quyền vị trí bị từ chối vĩnh viễn: $e');
      _fallbackToDefaultLocation(
        errorMessage: 'Quyền vị trí bị từ chối vĩnh viễn. Vui lòng cấp quyền trong Cài đặt.',
      );
    } catch (e) {
      DLog.error('Lỗi lấy vị trí hiện tại: $e');
      _fallbackToDefaultLocation(
        errorMessage: 'Không thể xác định vị trí hiện tại.',
      );
    }
  }

  void _fallbackToDefaultLocation({String? errorMessage}) {
    emit(state.copyWith(
      currentPosition: state.currentPosition ?? const LatLng(10.7769, 106.7009),
      isFollowingUser: false,
      errorMessage: errorMessage,
    ));
  }

  void onCameraMove(CameraPosition position) {
    emit(state.copyWith(
      center: position.target,
      zoom: position.zoom,
      rotation: position.bearing,
    ));
  }

  void onCameraTrackingDismissed() {
    emit(state.copyWith(isFollowingUser: false));
  }

  void setError(String message) {
    DLog.error('Lỗi bản đồ: $message');
    emit(state.copyWith(
      status: MapDisplayStatus.error,
      errorMessage: message,
    ));
  }

  void zoomIn() {
    controller?.animateCamera(CameraUpdate.zoomIn());
  }

  void zoomOut() {
    controller?.animateCamera(CameraUpdate.zoomOut());
  }

  @override
  void emit(MapDisplayState state) {
    if (isClosed) return;
    super.emit(state);
  }
}
