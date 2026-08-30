import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';
import 'trip_detail_kpi_grid.dart';
import 'trip_detail_route_info.dart';

class TripDetailPanel extends StatelessWidget {
  static const double panelRadius = 28.0;
  static const double badgeRadius = 8.0;

  final TripRecordModel trip;

  const TripDetailPanel({
    super.key,
    required this.trip,
  });

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
    final colorScheme = context.colorScheme;
    final themeColors = context.themeColors;
    final dateFormatted =
        DateFormat('HH:mm - dd/MM/yyyy').format(trip.startTime);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.58,
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(panelRadius)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
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
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getVehicleIcon(trip.vehicleProfile),
                      size: 22,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(LocaleKeys.stats_dashboard_detail_title),
                          style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _getVehicleName(trip.vehicleProfile),
                          style: colorScheme.onSurfaceVariant.textTheme.mediumStyle.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trip.hasArrived)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: themeColors.statsSuccess.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(badgeRadius),
                      ),
                      child: Text(
                        tr(LocaleKeys.stats_dashboard_status_completed),
                        style: themeColors.statsSuccess.textTheme.semiBoldStyle.copyWith(
                          fontSize: 11,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(badgeRadius),
                      ),
                      child: Text(
                        tr(LocaleKeys.stats_dashboard_status_stopped),
                        style: colorScheme.onSurfaceVariant.textTheme.semiBoldStyle.copyWith(
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // KPI Summary Grid
              TripDetailKpiGrid(trip: trip),

              const SizedBox(height: 14),

              // Origin & Destination Info
              TripDetailRouteInfo(trip: trip),

              const SizedBox(height: 12),

              // Metadata Row (Start time, sync status)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateFormatted,
                        style: colorScheme.onSurfaceVariant.textTheme.captionStyle.copyWith(
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  if (trip.isSynced)
                    Icon(
                      Icons.cloud_done_rounded,
                      size: 16,
                      color: themeColors.statsSuccess,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


}

