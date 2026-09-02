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
  final MyLocationRenderMode myLocationRenderMode;

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
    this.myLocationRenderMode = MyLocationRenderMode.normal,
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
      // Search/selected red POI markers use native symbols. The 0.26.x Android bridge enables
      // synchronous annotation updates when drag is enabled, which can drop
      // bitmap icons from the texture atlas while zooming. The app does not
      // support draggable map annotations, while pan/zoom gestures remain
      // enabled by this setting.
      dragEnabled: false,
      // Feature taps are handled by the Home map layer. Keeping this false is
      // important: true would also emit onMapClick for a red symbol, causing
      // the same tap to be resolved a second time by a nearby POI lookup.
      featureTapsTriggersMapClick: false,
      // Search/selected red POI markers use the native SymbolManager. It is
      // configured by MapSymbolManager with icon/text overlap enabled, so
      // MapLibre does not hide the red pin just because it overlaps a label or
      // another symbol. Saved/visited dots use a separate GeoJSON circle layer.
      annotationOrder: const [
        AnnotationType.fill,
        AnnotationType.line,
        AnnotationType.circle,
        AnnotationType.symbol,
      ],
      // Search/selected POI symbols must consume their own tap. Otherwise
      // MapLibre also forwards the same tap to onMapClick, where a nearby
      // coordinate lookup can resolve the wrong overlapping POI.
      // Vector-tile POIs still go through onMapClick because they are not
      // managed annotations.
      annotationConsumeTapEvents: const [
        AnnotationType.fill,
        AnnotationType.symbol,
      ],
      onMapCreated: onMapCreated,
      onStyleLoadedCallback: onStyleLoadedCallback,
      myLocationEnabled: true,
      myLocationTrackingMode: MyLocationTrackingMode.tracking,
      myLocationRenderMode: myLocationRenderMode,
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
