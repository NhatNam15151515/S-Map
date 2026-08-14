import 'dart:math';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/services/map_style_service.dart';

class MapView extends StatelessWidget {
  final MapCreatedCallback onMapCreated;
  final VoidCallback onStyleLoadedCallback;
  final VoidCallback? onCameraTrackingDismissed;
  final void Function(CameraPosition position)? onCameraMove;
  final void Function(MyLocationTrackingMode mode)? onCameraTrackingChanged;

  const MapView({
    super.key,
    required this.onMapCreated,
    required this.onStyleLoadedCallback,
    this.onCameraTrackingDismissed,
    this.onCameraMove,
    this.onCameraTrackingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      styleString: MapStyleService.instance.styleJson,
      initialCameraPosition: const CameraPosition(
        target: LatLng(10.7769, 106.7009), // Trung tâm TP.HCM
        zoom: 14.0,
      ),
      minMaxZoomPreference: const MinMaxZoomPreference(3.0, 19.0),
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
    );
  }
}
