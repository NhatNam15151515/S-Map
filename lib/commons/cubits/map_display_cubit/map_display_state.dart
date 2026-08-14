import 'package:equatable/equatable.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

enum MapDisplayStatus { initial, loading, ready, error }

// ignore: deprecated_member_use
class MapDisplayState with EquatableMixin {
  final MapDisplayStatus status;
  final String? errorMessageKey;
  final LatLng? currentPosition;
  final LatLng? center;
  final double zoom;
  final double rotation;
  final bool isFollowingUser;

  const MapDisplayState({
    required this.status,
    this.errorMessageKey,
    this.currentPosition,
    this.center,
    this.zoom = 14.0,
    this.rotation = 0.0,
    this.isFollowingUser = false,
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
      ];
}
