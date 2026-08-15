import 'package:equatable/equatable.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

enum MapDisplayStatus { initial, loading, ready, error }

enum MapOrientationMode { northUp, headingUp }

enum MapCameraActionType {
  animateToPosition,
  zoomIn,
  zoomOut,
  bearingTo,
}

class MapCameraAction extends Equatable {
  final MapCameraActionType type;
  final LatLng? target;
  final double? zoom;
  final double? bearing;
  final int timestamp;

  const MapCameraAction({
    required this.type,
    this.target,
    this.zoom,
    this.bearing,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [type, target, zoom, bearing, timestamp];
}

class MapDisplayState extends Equatable {
  final MapDisplayStatus status;
  final String? errorMessageKey;
  final LatLng? currentPosition;
  final LatLng? center;
  final double zoom;
  final double rotation;
  final bool isFollowingUser;
  final MapOrientationMode orientationMode;
  final double? compassHeading;
  final MapCameraAction? cameraAction;

  const MapDisplayState({
    required this.status,
    this.errorMessageKey,
    this.currentPosition,
    this.center,
    this.zoom = 14.0,
    this.rotation = 0.0,
    this.isFollowingUser = false,
    this.orientationMode = MapOrientationMode.northUp,
    this.compassHeading,
    this.cameraAction,
  });

  MapDisplayState copyWith({
    MapDisplayStatus? status,
    String? errorMessageKey,
    bool clearError = false,
    LatLng? currentPosition,
    LatLng? center,
    double? zoom,
    double? rotation,
    bool? isFollowingUser,
    MapOrientationMode? orientationMode,
    double? compassHeading,
    MapCameraAction? cameraAction,
    bool clearCameraAction = false,
  }) {
    return MapDisplayState(
      status: status ?? this.status,
      errorMessageKey:
          clearError ? null : (errorMessageKey ?? this.errorMessageKey),
      currentPosition: currentPosition ?? this.currentPosition,
      center: center ?? this.center,
      zoom: zoom ?? this.zoom,
      rotation: rotation ?? this.rotation,
      isFollowingUser: isFollowingUser ?? this.isFollowingUser,
      orientationMode: orientationMode ?? this.orientationMode,
      compassHeading: compassHeading ?? this.compassHeading,
      cameraAction:
          clearCameraAction ? null : (cameraAction ?? this.cameraAction),
    );
  }

  @override
  List<Object?> get props => [
        status,
        errorMessageKey,
        currentPosition,
        center,
        zoom,
        rotation,
        isFollowingUser,
        orientationMode,
        compassHeading,
        cameraAction,
      ];
}
