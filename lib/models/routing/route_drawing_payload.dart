import 'package:equatable/equatable.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/models/poi_model.dart';

class RouteDrawingPayload extends Equatable {
  final LatLng? initialOrigin;
  final LatLng? initialDestination;
  final String? destinationName;
  final PoiModel? destinationPoi;

  const RouteDrawingPayload({
    this.initialOrigin,
    this.initialDestination,
    this.destinationName,
    this.destinationPoi,
  });

  @override
  List<Object?> get props => [
        initialOrigin,
        initialDestination,
        destinationName,
        destinationPoi,
      ];
}
