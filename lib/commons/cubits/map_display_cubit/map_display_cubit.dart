import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'map_display_fallbacks.dart';
import 'map_display_state.dart';

class MapDisplayCubit extends Cubit<MapDisplayState> {
  final ILocationService _locationService;
  final ICompassService _compassService;
  final IMapStyleService _mapStyleService;

  StreamSubscription<double?>? _compassSubscription;
  StreamSubscription<void>? _mapStyleSubscription;
  double? _lastRotatedHeading;
  Future<LatLng>? _freshPositionRequest;
  bool _hasLoadedStyle = false;

  /// Minimum angular delta (in degrees) required to rotate camera (Anti-jitter filter)
  static const double _headingDeadband = 1.5;

  /// Optional global default service resolvers set by the app shell
  static ILocationService? defaultLocationService;
  static ICompassService? defaultCompassService;
  static IMapStyleService? defaultMapStyleService;
  static bool Function()? defaultDarkModeResolver;

  MapDisplayCubit({
    ILocationService? locationService,
    ICompassService? compassService,
    IMapStyleService? mapStyleService,
    bool? isDarkMode,
  })  : _locationService = locationService ??
            defaultLocationService ??
            const NoOpLocationService(),
        _compassService = compassService ??
            defaultCompassService ??
            const NoOpCompassService(),
        _mapStyleService = mapStyleService ??
            defaultMapStyleService ??
            const NoOpMapStyleService(),
        super(MapDisplayState(
          status: MapDisplayStatus.initial,
          isNightMode: isDarkMode ?? defaultDarkModeResolver?.call() ?? false,
          styleString: (mapStyleService ??
                  defaultMapStyleService ??
                  const NoOpMapStyleService())
              .getStyleJson(
            isDarkMode:
                isDarkMode ?? defaultDarkModeResolver?.call() ?? false,
          ),
        )) {
    // A region download/delete can happen while Home remains alive behind a
    // settings route. Listen to the style facade so the existing native map
    // switches source in place instead of requiring a screen recreation.
    _mapStyleSubscription = _mapStyleService.changes.listen((_) {
      final isDarkMode = state.isNightMode;
      final newStyle = _mapStyleService.getStyleJson(isDarkMode: isDarkMode);
      if (newStyle.isNotEmpty && newStyle != state.styleString) {
        emit(state.copyWith(
          styleString: newStyle,
          // A style change must not replay a previous zoom/locate action.
          clearCameraAction: true,
        ));
      }
    });
  }


  /// Safe emit guard rule mandatory for all Cubits/Blocs
  @override
  void emit(MapDisplayState state) {
    if (isClosed) return;
    super.emit(state);
  }

  void updateMapTheme({required bool isDarkMode}) {
    final newStyle = _mapStyleService.getStyleJson(isDarkMode: isDarkMode);
    if (newStyle.isNotEmpty &&
        (newStyle != state.styleString || isDarkMode != state.isNightMode)) {
      emit(state.copyWith(
        styleString: newStyle,
        isNightMode: isDarkMode,
        // Home listens to both styleString and cameraAction. Clear the old
        // one so toggling map style cannot repeat the last zoomOut action.
        clearCameraAction: true,
      ));
    }
  }

  void updateThemeMode(bool isDarkMode) {
    updateMapTheme(isDarkMode: isDarkMode);
  }

  void toggleNightMode() {
    updateMapTheme(isDarkMode: !state.isNightMode);
  }

  void onMapCreated() {
    emit(state.copyWith(status: MapDisplayStatus.loading));
  }

  Future<void> onStyleLoaded() async {
    final shouldLocate = !_hasLoadedStyle;
    _hasLoadedStyle = true;
    emit(state.copyWith(status: MapDisplayStatus.ready));
    // A style reload (for example, switching light/dark mode) must not
    // restart GPS or the native permission flow. That used to cause a visible
    // map flash and could make the location button appear stuck.
    if (shouldLocate) await locateMe();
  }
  Future<void> locateMe() async {
    // Phase 1: Instant Flyback (<50ms) - Bay ngay về vị trí đã lưu nếu có
    final cachedPos = state.hasRealLocation ? state.currentPosition : null;
    if (cachedPos != null) {
      _animateToTargetPosition(cachedPos);
    } else {
      try {
        final lastKnown = await _locationService.getLastKnownPosition();
        if (lastKnown != null && !state.hasRealLocation) {
          _animateToTargetPosition(
            LatLng(lastKnown.latitude, lastKnown.longitude),
          );
        }
      } catch (_) {}
    }

    // Phase 2: Fresh GPS Fix - Lấy tọa độ mới nhất và tinh chỉnh nhẹ camera
    try {
      final latLng = await _requestFreshPosition();

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

  /// Lấy vị trí GPS thật mà không dùng vị trí mặc định làm fallback.
  ///
  /// Dùng cho các thao tác bắt buộc phải có vị trí người dùng, ví dụ đặt
  /// điểm bắt đầu của route. [locateMe] vẫn giữ fallback để nút định vị bản
  /// đồ ở Home có thể đưa người dùng về vùng mặc định khi GPS lỗi.
  Future<LatLng?> acquireCurrentPosition() async {
    final cachedPosition =
        state.hasRealLocation ? state.currentPosition : null;
    if (cachedPosition != null) {
      if (state.errorMessageKey != null) {
        emit(state.copyWith(clearError: true));
      }
      return cachedPosition;
    }

    try {
      // Let the concrete service handle the complete permission flow. The
      // real LocationService asks Android to enable GPS when necessary; a
      // separate guard here used to return early and skip that prompt.
      final latLng = await _requestFreshPosition();
      final serviceEnabled = await _locationService.isLocationServiceEnabled();
      // NoOpLocationService intentionally returns (0, 0) as a safe value.
      // Never turn that detached-environment fallback into a route origin.
      if (!serviceEnabled && latLng.latitude == 0 && latLng.longitude == 0) {
        throw const LocationServiceDisabledException();
      }
      _animateToTargetPosition(latLng);
      return latLng;
    } catch (error) {
      DLog.error('Không thể lấy GPS thật: $error');
      _setLocationError(error);
      return null;
    }
  }

  /// Shares an in-flight GPS request between map startup and the origin
  /// button. A second tap therefore waits for the existing request instead of
  /// opening another permission/GPS operation.
  Future<LatLng> _requestFreshPosition() async {
    final pending = _freshPositionRequest;
    if (pending != null) return pending;

    final request = Future<Position>.sync(
      _locationService.getCurrentPosition,
    ).then((position) => LatLng(position.latitude, position.longitude));
    _freshPositionRequest = request;
    try {
      return await request;
    } finally {
      if (identical(_freshPositionRequest, request)) {
        _freshPositionRequest = null;
      }
    }
  }

  /// Helper tập trung logic cập nhật state vị trí và gửi cameraAction
  void _animateToTargetPosition(LatLng target) {
    emit(state.copyWith(
      status: MapDisplayStatus.ready,
      currentPosition: target,
      hasRealLocation: true,
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
    if (error is LocationPermissionDeniedForeverException) {
      return 'map.location_permission_denied_forever';
    }
    if (error is PermissionDeniedException) {
      return 'map.location_permission_denied';
    }
    if (error.toString().contains('deniedForever') ||
        error.toString().contains('permanently')) {
      return 'map.location_permission_denied_forever';
    }
    return 'map.locate_error';
  }

  void _fallbackToDefaultLocation({String? errorMessageKey}) {
    emit(state.copyWith(
      currentPosition: state.currentPosition ?? MapConstants.defaultLocation,
      hasRealLocation: state.hasRealLocation,
      isFollowingUser: false,
      errorMessageKey: errorMessageKey,
    ));
  }

  void _setLocationError(Object error) {
    emit(state.copyWith(
      errorMessageKey: _resolveLocationErrorKey(error),
      isFollowingUser: false,
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

  /// Tạm dừng bám theo người dùng khi người dùng lướt/xoay bản đồ thủ công
  void unfollowUser() {
    if (!state.isFollowingUser) return;
    _stopCompassListening();
    emit(state.copyWith(
      isFollowingUser: false,
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

  /// Zoom đến mức chỉ định nhưng giữ nguyên vị trí GPS và trạng thái
  /// following. Nếu có [center] thì đó là tâm camera mới; method này không
  /// ghi đè [currentPosition] vì GPS và tâm bản đồ là hai khái niệm khác nhau.
  void zoomToLevel(double zoom, {LatLng? center}) {
    final target = center ?? state.center ?? state.currentPosition;
    if (target == null) return;

    final clampedZoom = zoom.clamp(
      MapConstants.minZoom,
      MapConstants.maxZoom,
    ).toDouble();
    emit(state.copyWith(
      center: target,
      zoom: clampedZoom,
      isFollowingUser: false,
      clearError: true,
      cameraAction: MapCameraAction(
        type: MapCameraActionType.animateToPosition,
        target: target,
        zoom: clampedZoom,
        timestamp: DateTime.now().microsecondsSinceEpoch,
      ),
    ));
  }

  /// Chọn địa điểm POI từ kết quả tìm kiếm và animate camera tới vị trí đó
  void selectPoi(PoiModel poi) {
    final target = LatLng(poi.lat, poi.lon);
    emit(state.copyWith(
      selectedPoi: poi,
      center: target,
      isFollowingUser: false,
      clearError: true,
      cameraAction: MapCameraAction(
        type: MapCameraActionType.animateToPosition,
        target: target,
        zoom: 16.0,
        timestamp: DateTime.now().microsecondsSinceEpoch,
      ),
    ));
  }

  /// Xóa POI đang được chọn
  void clearSelectedPoi() {
    emit(state.copyWith(clearSelectedPoi: true));
  }

  @override
  Future<void> close() async {
    await _mapStyleSubscription?.cancel();
    _mapStyleSubscription = null;
    await _stopCompassListening();
    return super.close();
  }
}
