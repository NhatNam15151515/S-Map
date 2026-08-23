import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/commons/utils/map_drawing_route_manager.dart';
import 'package:s_map/commons/utils/route_format_helper.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

class TripDetailScreen extends StatefulWidget {
  final TripRecordModel trip;
  final Widget Function(BuildContext context, MapLibreMapController? controller)? mapLayerBuilder;

  const TripDetailScreen({
    super.key,
    required this.trip,
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
    _isMapReady = true;
    _drawTripPolyline();
  }

  void _onStyleLoaded() {
    _drawTripPolyline();
  }

  Future<void> _drawTripPolyline() async {
    if (_mapController == null || !_isMapReady) return;

    final rawPolyline = widget.trip.polyline;
    if (rawPolyline == null || rawPolyline.length < 2) return;

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

    final routePoints = latLngs.map((l) => RoutePoint(lat: l.latitude, lon: l.longitude)).toList();

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

  IconData _getVehicleIcon(String profile) {
    switch (profile.toLowerCase()) {
      case 'car':
        return Icons.directions_car_rounded;
      case 'walking':
      case 'foot':
        return Icons.directions_walk_rounded;
      case 'motorcycle':
      case 'moped':
      default:
        return Icons.two_wheeler_rounded;
    }
  }

  String _getVehicleName(String profile) {
    switch (profile.toLowerCase()) {
      case 'car':
        return tr(LocaleKeys.stats_dashboard_filter_car);
      case 'walking':
      case 'foot':
        return tr(LocaleKeys.stats_dashboard_filter_walking);
      case 'motorcycle':
      case 'moped':
      default:
        return tr(LocaleKeys.stats_dashboard_filter_motorcycle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final startLatLng = trip.polyline?.isNotEmpty == true
        ? LatLng(trip.polyline!.first[0], trip.polyline!.first[1])
        : const LatLng(10.7769, 106.7009);

    final durationStr = RouteFormatHelper.formatTripDuration(trip.duration);
    final distanceStr = '${trip.distanceKm.toStringAsFixed(1)} km';
    final startTimeStr = DateFormat('HH:mm, dd/MM/yyyy').format(trip.startTime);
    final endTimeStr = DateFormat('HH:mm, dd/MM/yyyy').format(trip.endTime);

    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      body: Stack(
        children: [
          // 1. Bản đồ lộ trình chuyến đi
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.48,
            child: widget.mapLayerBuilder != null
                ? widget.mapLayerBuilder!(context, _mapController)
                : MapLibreMap(
                    initialCameraPosition: CameraPosition(
                      target: startLatLng,
                      zoom: 14.0,
                    ),
                    onMapCreated: _onMapCreated,
                    onStyleLoadedCallback: _onStyleLoaded,
                    myLocationEnabled: false,
                    attributionButtonMargins: const Point(-100, -100),
                  ),
          ),

          // 2. Nút Back nổi trên Map
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                key: const Key('trip_detail_back_btn'),
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          // 3. Card chi tiết thông số chuyến đi ở nửa dưới màn hình
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.sMapDarkTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getVehicleIcon(trip.vehicleProfile),
                            size: 22,
                            color: AppColors.sMapDarkTeal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr(LocaleKeys.stats_dashboard_detail_title),
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              Text(
                                _getVehicleName(trip.vehicleProfile),
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (trip.hasArrived)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tr(LocaleKeys.stats_dashboard_status_completed),
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tr(LocaleKeys.stats_dashboard_status_stopped),
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Stats Grid Row (Distance, Duration, Avg Speed, Top Speed)
                    Row(
                      children: [
                        Expanded(
                          child: _DetailStatBox(
                            icon: Icons.route_rounded,
                            label: tr(LocaleKeys.stats_dashboard_detail_distance),
                            value: distanceStr,
                            color: AppColors.sMapDarkTeal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DetailStatBox(
                            icon: Icons.schedule_rounded,
                            label: tr(LocaleKeys.stats_dashboard_detail_duration),
                            value: durationStr,
                            color: const Color(0xFFE65100),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _DetailStatBox(
                            icon: Icons.speed_rounded,
                            label: tr(LocaleKeys.stats_dashboard_detail_avg_speed),
                            value: '${trip.avgSpeedKmh.round()} km/h',
                            color: const Color(0xFF1565C0),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DetailStatBox(
                            icon: Icons.flash_on_rounded,
                            label: tr(LocaleKeys.stats_dashboard_detail_top_speed),
                            value: '${trip.topSpeedKmh.round()} km/h',
                            color: const Color(0xFF7B1FA2),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Origin & Destination Info
                    _LocationTimelineItem(
                      isOrigin: true,
                      label: tr(LocaleKeys.stats_dashboard_detail_origin),
                      title: trip.originName ?? startTimeStr,
                    ),
                    const SizedBox(height: 8),
                    _LocationTimelineItem(
                      isOrigin: false,
                      label: tr(LocaleKeys.stats_dashboard_detail_destination),
                      title: trip.destinationName ?? endTimeStr,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailStatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DetailStatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _LocationTimelineItem extends StatelessWidget {
  final bool isOrigin;
  final String label;
  final String title;

  const _LocationTimelineItem({
    required this.isOrigin,
    required this.label,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isOrigin ? const Color(0xFF2E7D32) : AppColors.error,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
