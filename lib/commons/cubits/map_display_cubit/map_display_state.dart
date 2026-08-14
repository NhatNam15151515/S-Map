import 'package:equatable/equatable.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

enum MapDisplayStatus { initial, loading, ready, error }

class MapDisplayState extends Equatable {
  final MapDisplayStatus status;
  final String? errorMessage;
  final LatLng? currentPosition;
  final LatLng? center;
  final double zoom;
  final double rotation;
  final bool isFollowingUser;

  const MapDisplayState({
    required this.status,
    this.errorMessage,
    this.currentPosition,
    this.center,
    this.zoom = 14.0,
    this.rotation = 0.0,
    this.isFollowingUser = false,
  });

  MapDisplayState copyWith({
    MapDisplayStatus? status,
    String? errorMessage,
    LatLng? currentPosition,
    LatLng? center,
    double? zoom,
    double? rotation,
    bool? isFollowingUser,
  }) {
    return MapDisplayState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
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
        errorMessage,
        currentPosition,
        center,
        zoom,
        rotation,
        isFollowingUser,
      ];
}
