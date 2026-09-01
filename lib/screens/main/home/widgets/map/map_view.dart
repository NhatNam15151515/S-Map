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
  final void Function(Point<double> point, LatLng latLng)? onMapClick;
  final void Function(Point<double> point, LatLng latLng)? onMapLongClick;
  final bool nativeCompassEnabled;

  const MapView({
    super.key,
    required this.styleString,
    required this.onMapCreated,
    required this.onStyleLoadedCallback,
    this.onCameraTrackingDismissed,
    this.onCameraMove,
    this.onCameraTrackingChanged,
    this.onCameraIdle,
    this.onMapClick,
    this.onMapLongClick,
    this.nativeCompassEnabled = true,
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
      // POI markers use native symbols. The 0.26.x Android bridge enables
      // synchronous annotation updates when drag is enabled, which can drop
      // bitmap icons from the texture atlas while zooming. The app does not
      // support draggable map annotations, while pan/zoom gestures remain
      // enabled by this setting.
      dragEnabled: false,
      // Forward feature taps so the screen-level onMapClick handler can
      // resolve the POI and open its details card.
      featureTapsTriggersMapClick: true,
      // POI markers use the native SymbolManager. It is configured by
      // MapSymbolManager with icon/text overlap enabled, so MapLibre does not
      // hide the red pin just because it overlaps a label or another symbol.
      annotationOrder: const [
        AnnotationType.fill,
        AnnotationType.line,
        AnnotationType.circle,
        AnnotationType.symbol,
      ],
      // The screen handles POI taps through queryRenderedFeatures and its
      // coordinate lookup, so symbols must not swallow the map tap. The
      // plugin requires at least one annotation type here; fill is harmless
      // because the app does not create interactive fill annotations.
      annotationConsumeTapEvents: const [AnnotationType.fill],
      onMapCreated: onMapCreated,
      onStyleLoadedCallback: onStyleLoadedCallback,
      myLocationEnabled: true,
      myLocationTrackingMode: MyLocationTrackingMode.tracking,
      myLocationRenderMode: MyLocationRenderMode.normal,
      // Home disables the native compass because MapControls renders the
      // themed compass together with the other map actions. Other map
      // screens keep the native compass unless they opt out explicitly.
      compassEnabled: nativeCompassEnabled,
      compassViewPosition: nativeCompassEnabled
          ? CompassViewPosition.topLeft
          : null,
      compassViewMargins:
          nativeCompassEnabled ? const Point(16, 120) : null,
      trackCameraPosition: true,
      onCameraMove: onCameraMove,
      onCameraTrackingDismissed: onCameraTrackingDismissed,
      onCameraTrackingChanged: onCameraTrackingChanged,
      onCameraIdle: onCameraIdle,
      onMapClick: onMapClick,
      onMapLongClick: onMapLongClick,
    );
  }
}
