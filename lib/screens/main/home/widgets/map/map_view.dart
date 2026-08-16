import 'dart:math';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/constants/constants.dart';

class MapView extends StatelessWidget {
  final String styleString;
  final MapCreatedCallback onMapCreated;
  final VoidCallback onStyleLoadedCallback;
  final VoidCallback? onCameraTrackingDismissed;
  final void Function(CameraPosition position)? onCameraMove;
  final void Function(MyLocationTrackingMode mode)? onCameraTrackingChanged;
  final VoidCallback? onCameraIdle;
  final void Function(Point<double> point, LatLng latLng)? onMapLongClick;

  const MapView({
    super.key,
    required this.styleString,
    required this.onMapCreated,
    required this.onStyleLoadedCallback,
    this.onCameraTrackingDismissed,
    this.onCameraMove,
    this.onCameraTrackingChanged,
    this.onCameraIdle,
    this.onMapLongClick,
  });

  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      styleString: styleString,
      initialCameraPosition: const CameraPosition(
        target: MapConstants.defaultLocation,
        zoom: MapConstants.defaultZoom,
      ),
      minMaxZoomPreference: const MinMaxZoomPreference(
        MapConstants.minZoom,
        MapConstants.maxZoom,
      ),
      onMapCreated: onMapCreated,
      onStyleLoadedCallback: onStyleLoadedCallback,
      myLocationEnabled: true,
      myLocationTrackingMode: MyLocationTrackingMode.tracking,
      myLocationRenderMode: MyLocationRenderMode.normal,
      compassEnabled: true,
      compassViewPosition: CompassViewPosition.topLeft,
      compassViewMargins: const Point(16, 120),
      trackCameraPosition: true,
      onCameraMove: onCameraMove,
      onCameraTrackingDismissed: onCameraTrackingDismissed,
      onCameraTrackingChanged: onCameraTrackingChanged,
      onCameraIdle: onCameraIdle,
      onMapLongClick: onMapLongClick,
    );
  }
}
