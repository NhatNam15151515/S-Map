import 'package:equatable/equatable.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

enum MapDisplayStatus { initial, loading, ready, error }

class MapDisplayState with EquatableMixin {
  final MapDisplayStatus status;
  final String? errorMessage;
  final LatLng? currentPosition;

  const MapDisplayState({
    required this.status,
    this.errorMessage,
    this.currentPosition,
  });

  MapDisplayState copyWith({
    MapDisplayStatus? status,
    String? errorMessage,
    LatLng? currentPosition,
  }) {
    return MapDisplayState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      currentPosition: currentPosition ?? this.currentPosition,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage, currentPosition];
}
