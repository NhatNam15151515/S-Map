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
      // Red marker layers use GeoJSON sources. The 0.26.x Android bridge
      // enables synchronous GeoJSON updates when drag is enabled, which can
      // drop bitmap icons from the texture atlas while zooming. The app does
      // not support draggable map annotations, while pan/zoom gestures remain
      // enabled by this setting.
      dragEnabled: false,
      // Custom GeoJSON marker layers handle the native feature tap first.
      // Forward that tap so the screen-level onMapClick handler can resolve
      // the POI and open its details card.
      featureTapsTriggersMapClick: true,
      // Loại bỏ AnnotationType.symbol để không tạo SymbolManager mặc định
      // (SymbolManager mặc định có collision detection gây ẩn/hiện marker khi zoom).
      // Tất cả symbols được quản lý bằng custom GeoJSON source + Symbol layer riêng.
      annotationOrder: const [
        AnnotationType.line,
        AnnotationType.circle,
        AnnotationType.fill,
      ],
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
      onMapClick: onMapClick,
      onMapLongClick: onMapLongClick,
    );
  }
}
