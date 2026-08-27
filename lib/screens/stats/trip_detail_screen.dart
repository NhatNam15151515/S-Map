import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/commons/utils/map_drawing_route_manager.dart';
import 'package:s_map/commons/utils/route_format_helper.dart';
import 'package:s_map/constants/map_constants.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/routers/app_routes.dart';

class TripDetailScreen extends StatefulWidget {
  static const String path = AppRoutes.tripDetail;
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
  static const double _panelRadius = 28.0;
  static const double _badgeRadius = 8.0;
  static const double _cardRadius = 14.0;
  static const double _panelMaxHeightFactor = 0.58;

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
      case 'moped_vn':
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
      case 'moped_vn':
      default:
        return tr(LocaleKeys.stats_dashboard_filter_motorcycle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final startLatLng = trip.polyline?.isNotEmpty == true
        ? LatLng(trip.polyline!.first[0], trip.polyline!.first[1])
        : MapConstants.defaultLocation;

    final durationStr = RouteFormatHelper.formatTripDuration(trip.duration);
    final distanceStr = '${trip.distanceKm.toStringAsFixed(1)} km';
    final startTimeStr = DateFormat('HH:mm, dd/MM/yyyy').format(trip.startTime);
    final endTimeStr = DateFormat('HH:mm, dd/MM/yyyy').format(trip.endTime);
    final avgSpeedStr = tr(LocaleKeys.stats_dashboard_speed_unit, args: ['${trip.avgSpeedKmh.round()}']);
    final topSpeedStr = tr(LocaleKeys.stats_dashboard_speed_unit, args: ['${trip.topSpeedKmh.round()}']);

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
                color: AppStyle.of(context).colorScheme.surface,
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
                icon: Icon(Icons.arrow_back_rounded,
                    color: AppStyle.of(context).blackTextColor),
                onPressed: () => context.pop(),
              ),
            ),
          ),

          // 3. Card chi tiết thông số chuyến đi ở nửa dưới màn hình
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * _panelMaxHeightFactor,
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: BoxDecoration(
                color: AppStyle.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(_panelRadius)),
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
                child: SingleChildScrollView(
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
                                  style: AppColors.onSurface.textTheme.textTitleStyle.copyWith(
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  _getVehicleName(trip.vehicleProfile),
                                  style: AppColors.onSurfaceVariant.textTheme.mediumStyle.copyWith(
                                    fontSize: 12,
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
                                borderRadius: BorderRadius.circular(_badgeRadius),
                              ),
                              child: Text(
                                tr(LocaleKeys.stats_dashboard_status_completed),
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.googleGreen,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(_badgeRadius),
                              ),
                              child: Text(
                                tr(LocaleKeys.stats_dashboard_status_stopped),
                                style: AppColors.onSurfaceVariant.textTheme.semiBoldStyle.copyWith(
                                  fontSize: 11,
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
                              cardRadius: _cardRadius,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DetailStatBox(
                              icon: Icons.schedule_rounded,
                              label: tr(LocaleKeys.stats_dashboard_detail_duration),
                              value: durationStr,
                              color: AppColors.sunOrange,
                              cardRadius: _cardRadius,
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
                              value: avgSpeedStr,
                              color: AppColors.googleBlue,
                              cardRadius: _cardRadius,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DetailStatBox(
                              icon: Icons.flash_on_rounded,
                              label: tr(LocaleKeys.stats_dashboard_detail_top_speed),
                              value: topSpeedStr,
                              color: AppColors.brightIndigo,
                              cardRadius: _cardRadius,
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
  final double cardRadius;

  const _DetailStatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.cardRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(cardRadius),
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
                  style: AppColors.onSurfaceVariant.textTheme.regularStyle.copyWith(
                    fontSize: 10,
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
            style: AppColors.onSurface.textTheme.textTitleStyle.copyWith(
              fontSize: 13,
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
            color: isOrigin ? AppColors.googleGreen : AppColors.error,
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
                style: AppColors.onSurfaceVariant.textTheme.semiBoldStyle.copyWith(
                  fontSize: 10,
                ),
              ),
              Text(
                title,
                style: AppColors.onSurface.textTheme.semiBoldStyle.copyWith(
                  fontSize: 12,
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
