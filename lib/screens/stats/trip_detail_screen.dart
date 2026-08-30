import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/utils/map_drawing_route_manager.dart';
import 'package:s_map/constants/map_constants.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/stats/widgets/trip_detail_panel.dart';
import 'package:s_map/services/map_style_service.dart';

class TripDetailScreen extends StatefulWidget {
  final TripRecordModel trip;
  final IMapStyleService? mapStyleService;
  final Widget Function(
      BuildContext context, MapLibreMapController? controller)? mapLayerBuilder;

  const TripDetailScreen({
    super.key,
    required this.trip,
    this.mapStyleService,
    this.mapLayerBuilder,
  });

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  MapLibreMapController? _mapController;
  final MapDrawingRouteManager _routeManager = MapDrawingRouteManager();
  bool _isMapReady = false;

  @override
  void dispose() {
    _routeManager.clear(_mapController);
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  void _onStyleLoaded() {
    _isMapReady = true;
    _drawTripPolyline();
  }

  Future<void> _drawTripPolyline() async {
    if (_mapController == null || !_isMapReady) return;

    final rawPolyline = widget.trip.polyline;
    if (rawPolyline == null || rawPolyline.length < 2) return;

    await _routeManager.clear(_mapController);

    final latLngs = rawPolyline.map((p) => LatLng(p[0], p[1])).toList();
    final waypoints = [
      SnappedRoadPoint(
        isSnapped: true,
        originalLat: latLngs.first.latitude,
        originalLon: latLngs.first.longitude,
        snappedLat: latLngs.first.latitude,
        snappedLon: latLngs.first.longitude,
      ),
      SnappedRoadPoint(
        isSnapped: true,
        originalLat: latLngs.last.latitude,
        originalLon: latLngs.last.longitude,
        snappedLat: latLngs.last.latitude,
        snappedLon: latLngs.last.longitude,
      ),
    ];

    final routePoints = latLngs
        .map((l) => RoutePoint(lat: l.latitude, lon: l.longitude))
        .toList();

    await _routeManager.drawCustomRoute(
      controller: _mapController,
      points: waypoints,
      fullPolyline: routePoints,
    );

    await _routeManager.fitRouteBounds(
      controller: _mapController,
      points: waypoints,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final trip = widget.trip;
    final startLatLng = trip.polyline?.isNotEmpty == true
        ? LatLng(trip.polyline!.first[0], trip.polyline!.first[1])
        : MapConstants.defaultLocation;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Map Layer
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.48,
            child: widget.mapLayerBuilder != null
                ? widget.mapLayerBuilder!(context, _mapController)
                : MapLibreMap(
                    styleString: (widget.mapStyleService ?? MapStyleService.instance)
                        .getStyleJson(
                      isDarkMode: colorScheme.brightness == Brightness.dark,
                    ),
                    initialCameraPosition: CameraPosition(
                      target: startLatLng,
                      zoom: 14.0,
                    ),
                    onMapCreated: _onMapCreated,
                    onStyleLoadedCallback: _onStyleLoaded,
                    // Waypoint markers are GeoJSON symbol layers, not
                    // draggable annotations. Keeping drag disabled avoids
                    // the Android bitmap-atlas flicker during zoom.
                    dragEnabled: false,
                    myLocationEnabled: false,
                    attributionButtonMargins: const Point(-100, -100),
                  ),
          ),

          // 2. Floating Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),

              child: IconButton(
                key: const Key('trip_detail_back_btn'),
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: colorScheme.onSurface,
                ),
                onPressed: () => context.pop(),
              ),
            ),
          ),

          // 3. Bottom Detail Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: TripDetailPanel(trip: trip),
          ),
        ],
      ),
    );
  }
}
