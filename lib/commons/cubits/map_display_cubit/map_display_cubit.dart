import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/constants/map_constants.dart';
import 'package:s_map/interfaces/i_compass_service.dart';
import 'package:s_map/interfaces/i_location_service.dart';
import 'package:s_map/services/compass_service.dart';
import 'package:s_map/services/location_services.dart';
import 'map_display_state.dart';

class MapDisplayCubit extends Cubit<MapDisplayState> {
  final ILocationService _locationService;
  final ICompassService _compassService;

  StreamSubscription<double?>? _compassSubscription;
  double? _lastRotatedHeading;

  /// Minimum angular delta (in degrees) required to rotate camera (Anti-jitter filter)
  static const double _headingDeadband = 1.5;

  MapDisplayCubit({
    ILocationService? locationService,
    ICompassService? compassService,
  })  : _locationService = locationService ?? LocationService.instance,
        _compassService = compassService ?? CompassService.instance,
        super(const MapDisplayState(status: MapDisplayStatus.initial));

  /// Safe emit guard rule mandatory for all Cubits/Blocs
  @override
  void emit(MapDisplayState state) {
    if (isClosed) return;
    super.emit(state);
  }

  void onMapCreated() {
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
      _animateToTargetPosition(cachedPos);
    } else {
      try {
        final lastKnown = await _locationService.getLastKnownPosition();
        if (lastKnown != null && state.currentPosition == null) {
          _animateToTargetPosition(
            LatLng(lastKnown.latitude, lastKnown.longitude),
          );
        }
      } catch (_) {}
    }

    // Phase 2: Fresh GPS Fix - Lấy tọa độ mới nhất và tinh chỉnh nhẹ camera
    try {
      final pos = await _locationService.getCurrentPosition();
      final latLng = LatLng(pos.latitude, pos.longitude);

      final shouldAnimate = cachedPos == null ||
          (state.isFollowingUser &&
              (cachedPos.latitude != latLng.latitude ||
                  cachedPos.longitude != latLng.longitude));

      if (shouldAnimate) {
        _animateToTargetPosition(latLng);
      } else {
        emit(state.copyWith(
          status: MapDisplayStatus.ready,
          currentPosition: latLng,
          center: latLng,
          isFollowingUser: true,
          clearError: true,
        ));
      }
    } catch (e) {
      DLog.error('Lỗi lấy vị trí hiện tại: $e');
      _fallbackToDefaultLocation(errorMessageKey: _resolveLocationErrorKey(e));
    }
  }

  /// Helper tập trung logic cập nhật state vị trí và gửi cameraAction
  void _animateToTargetPosition(LatLng target) {
    emit(state.copyWith(
      status: MapDisplayStatus.ready,
      currentPosition: target,
      center: target,
      isFollowingUser: true,
      clearError: true,
      cameraAction: MapCameraAction(
        type: MapCameraActionType.animateToPosition,
        target: target,
        zoom: MapConstants.locateMeZoom,
        timestamp: DateTime.now().microsecondsSinceEpoch,
      ),
    ));
  }

  /// Ánh xạ exception từ dịch vụ định vị sang translation key tương ứng
  String _resolveLocationErrorKey(Object error) {
    if (error is LocationServiceDisabledException) {
      return 'map.location_service_disabled';
    }
    if (error is PermissionDeniedException) {
      return 'map.location_permission_denied';
    }
    if (error is LocationPermissionDeniedForeverException) {
      return 'map.location_permission_denied_forever';
    }
    return 'map.locate_error';
  }

  void _fallbackToDefaultLocation({String? errorMessageKey}) {
    emit(state.copyWith(
      currentPosition: state.currentPosition ?? MapConstants.defaultLocation,
      isFollowingUser: false,
      errorMessageKey: errorMessageKey,
    ));
  }

  /// Toggle between North-up and Heading-up orientation modes
  Future<void> toggleOrientationMode() async {
    if (state.orientationMode == MapOrientationMode.headingUp) {
      await setNorthUp();
    } else {
      await setHeadingUp();
    }
  }

  /// Switch to North-up mode (bearing = 0° / North at the top)
  Future<void> setNorthUp() async {
    await _stopCompassListening();
    emit(state.copyWith(
      orientationMode: MapOrientationMode.northUp,
      rotation: 0.0,
      clearError: true,
      cameraAction: MapCameraAction(
        type: MapCameraActionType.bearingTo,
        bearing: 0.0,
        timestamp: DateTime.now().microsecondsSinceEpoch,
      ),
    ));
  }

  /// Switch to Heading-up mode (camera follows device compass heading)
  Future<void> setHeadingUp() async {
    emit(state.copyWith(
      orientationMode: MapOrientationMode.headingUp,
      isFollowingUser: true,
      clearError: true,
    ));
    _startCompassListening();
  }

  void _startCompassListening() {
    _compassSubscription?.cancel();
    _compassSubscription = _compassService.compassHeadingStream.listen(
      (heading) {
        if (heading != null) {
          _handleHeadingUpdate(heading);
        }
      },
      onError: (err) {
        DLog.error('Lỗi nhận dữ liệu la bàn: $err');
      },
    );
  }

  Future<void> _stopCompassListening() async {
    await _compassSubscription?.cancel();
    _compassSubscription = null;
    _lastRotatedHeading = null;
  }

  /// Anti-jitter heading handler with shortest angular distance calculation
  void _handleHeadingUpdate(double heading) {
    if (state.orientationMode != MapOrientationMode.headingUp) return;

    final normalizedHeading = (heading % 360 + 360) % 360;

    if (_lastRotatedHeading != null) {
      double diff = (normalizedHeading - _lastRotatedHeading!).abs();
      if (diff > 180) {
        diff = 360 - diff;
      }
      if (diff < _headingDeadband) {
        return; // Skip jitter below threshold
      }
    }

    _lastRotatedHeading = normalizedHeading;
    emit(state.copyWith(
      compassHeading: normalizedHeading,
      rotation: normalizedHeading,
      cameraAction: MapCameraAction(
        type: MapCameraActionType.bearingTo,
        bearing: normalizedHeading,
        timestamp: DateTime.now().microsecondsSinceEpoch,
      ),
    ));
  }

  void onCameraMove(CameraPosition position) {
    // Tránh emit trùng lặp nếu thông số camera không đổi
    if (state.center == position.target &&
        state.zoom == position.zoom &&
        state.rotation == position.bearing &&
        state.errorMessageKey == null) {
      return;
    }

    emit(state.copyWith(
      center: position.target,
      zoom: position.zoom,
      rotation: position.bearing,
      clearError: true, // Xóa thông báo lỗi khi người dùng di chuyển bản đồ
    ));
  }

  void onCameraTrackingDismissed() {
    // When user manually pans map, stop tracking & reset to North-up
    _stopCompassListening();
    emit(state.copyWith(
      isFollowingUser: false,
      orientationMode: MapOrientationMode.northUp,
    ));
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
    final nextZoom = (state.zoom + 1).clamp(MapConstants.minZoom, MapConstants.maxZoom);
    emit(state.copyWith(
      zoom: nextZoom,
      cameraAction: MapCameraAction(
        type: MapCameraActionType.zoomIn,
        zoom: nextZoom,
        timestamp: DateTime.now().microsecondsSinceEpoch,
      ),
    ));
  }

  void zoomOut() {
    final nextZoom = (state.zoom - 1).clamp(MapConstants.minZoom, MapConstants.maxZoom);
    emit(state.copyWith(
      zoom: nextZoom,
      cameraAction: MapCameraAction(
        type: MapCameraActionType.zoomOut,
        zoom: nextZoom,
        timestamp: DateTime.now().microsecondsSinceEpoch,
      ),
    ));
  }

  @override
  Future<void> close() async {
    await _stopCompassListening();
    return super.close();
  }
}
