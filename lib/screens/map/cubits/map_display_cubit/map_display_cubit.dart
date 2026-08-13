import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/mixin/app_mixin.dart';
import 'package:s_map/services/location_services.dart';
import 'map_display_state.dart';

class MapDisplayCubit extends Cubit<MapDisplayState> with AppMixin {
  MapLibreMapController? controller;

  MapDisplayCubit() : super(const MapDisplayState(status: MapDisplayStatus.initial));

  void onMapCreated(MapLibreMapController mapController) {
    controller = mapController;
    emit(state.copyWith(status: MapDisplayStatus.loading));
  }

  void onStyleLoaded() async {
    emit(state.copyWith(status: MapDisplayStatus.ready));
    await locateMe();
  }

  Future<void> locateMe() async {
    try {
      final pos = await LocationService.instance.getCurrentPosition();
      final latLng = LatLng(pos.latitude, pos.longitude);
      emit(state.copyWith(
        status: MapDisplayStatus.ready,
        currentPosition: latLng,
      ));

      if (controller != null) {
        await controller!.animateCamera(
          CameraUpdate.newLatLngZoom(latLng, 16.0),
        );
      }
    } catch (e, stackTrace) {
      DLog.error('Lỗi lấy vị trí hiện tại: $e');
      // Fallback vị trí mặc định TP.HCM mà không crash app
      emit(state.copyWith(
        currentPosition: state.currentPosition ?? const LatLng(10.7769, 106.7009),
      ));
    }
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
