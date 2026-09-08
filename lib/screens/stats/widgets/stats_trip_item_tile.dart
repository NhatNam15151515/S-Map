import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

class StatsTripItemTile extends StatelessWidget {
  final TripRecordModel trip;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final IconData? vehicleIcon;
  final Color? vehicleColor;

  const StatsTripItemTile({
    super.key,
    required this.trip,
    required this.onTap,
    required this.onDelete,
    this.vehicleIcon,
    this.vehicleColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final themeColors = context.themeColors;

    final effectiveIcon =
        vehicleIcon ?? TripFormatHelper.getVehicleIcon(trip.vehicleProfile);
    final effectiveColor = vehicleColor ??
        TripFormatHelper.getVehicleColor(context, trip.vehicleProfile);

    final title = TripFormatHelper.getTripTitle(trip);
    final dateStr = TripFormatHelper.formatTripDate(trip.startTime);
    final durationStr = RouteFormatHelper.formatTripDuration(trip.duration);
    final distanceStr = tr(
      LocaleKeys.stats_dashboard_distance_value,
      args: [trip.distanceKm.toStringAsFixed(1)],
    );

    return InkWell(
      key: Key('trip_item_${trip.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                effectiveIcon,
                size: 20,
                color: effectiveColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: colorScheme.onSurface.textTheme.semiBoldStyle
                              .copyWith(
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: colorScheme
                            .onSurfaceVariant.textTheme.captionStyle
                            .copyWith(
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$distanceStr • $durationStr',
                          style: colorScheme
                              .onSurfaceVariant.textTheme.captionStyle
                              .copyWith(
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (trip.hasArrived)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: themeColors.statsSuccess
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tr(LocaleKeys.stats_dashboard_status_completed),
                            style: themeColors
                                .statsSuccess.textTheme.semiBoldStyle
                                .copyWith(
                              fontSize: 9,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tr(LocaleKeys.stats_dashboard_status_stopped),
                            style: colorScheme.error.textTheme.semiBoldStyle
                                .copyWith(
                              fontSize: 9,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              key: Key('delete_trip_btn_${trip.id}'),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              color: colorScheme.error,
              onPressed: onDelete,
              tooltip: tr(LocaleKeys.route_drawing_ui_delete_route),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
