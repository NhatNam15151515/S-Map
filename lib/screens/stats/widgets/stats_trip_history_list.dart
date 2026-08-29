import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/route_format_helper.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

class StatsTripHistoryList extends StatelessWidget {
  final List<TripRecordModel> trips;
  final ValueChanged<TripRecordModel> onTapTrip;
  final ValueChanged<String> onDeleteTrip;

  const StatsTripHistoryList({
    super.key,
    required this.trips,
    required this.onTapTrip,
    required this.onDeleteTrip,
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

  Color _getVehicleColor(BuildContext context, String profile) {
    final themeColors = context.themeColors;
    switch (profile.toLowerCase()) {
      case 'car':
        return themeColors.statsBlue;
      case 'walking':
      case 'foot':
        return themeColors.statsOrange;
      case 'motorcycle':
      case 'moped':
      case 'moped_vn':
      default:
        return context.colorScheme.primary;
    }
  }

  void _showDeleteConfirmDialog(BuildContext context, TripRecordModel trip) {
    final colorScheme = context.colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          tr(LocaleKeys.stats_dashboard_delete_trip_title),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: colorScheme.onSurface,
          ),
        ),
        content: Text(
          tr(LocaleKeys.stats_dashboard_delete_trip_desc),
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              tr(LocaleKeys.cancel),
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            key: const Key('confirm_delete_trip_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
              onDeleteTrip(trip.id);
            },
            child: Text(
              tr(LocaleKeys.stats_dashboard_delete_trip_btn),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.history_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(LocaleKeys.stats_dashboard_history_title),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tr(LocaleKeys.stats_dashboard_history_count, args: ['${trips.length}']),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (trips.isEmpty)
            _buildEmptyState(colorScheme)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: trips.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final trip = trips[index];
                return _TripItemTile(
                  trip: trip,
                  vehicleIcon: _getVehicleIcon(trip.vehicleProfile),
                  vehicleColor: _getVehicleColor(context, trip.vehicleProfile),
                  onTap: () => onTapTrip(trip),
                  onDelete: () => _showDeleteConfirmDialog(context, trip),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Container(
      key: const Key('stats_trip_history_empty'),
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.explore_off_rounded,
            size: 40,
            color: colorScheme.outline.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            tr(LocaleKeys.stats_dashboard_history_empty_title),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(LocaleKeys.stats_dashboard_history_empty_desc),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripItemTile extends StatelessWidget {
  final TripRecordModel trip;
  final IconData vehicleIcon;
  final Color vehicleColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TripItemTile({
    required this.trip,
    required this.vehicleIcon,
    required this.vehicleColor,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final themeColors = context.themeColors;
    final title = trip.destinationName?.trim().isNotEmpty == true
        ? trip.destinationName!
        : (trip.originName?.trim().isNotEmpty == true
            ? trip.originName!
            : DateFormat('HH:mm - dd/MM/yyyy').format(trip.startTime));

    final durationStr = RouteFormatHelper.formatTripDuration(trip.duration);
    final distanceStr = '${trip.distanceKm.toStringAsFixed(1)} km';
    final dateStr = DateFormat('HH:mm, dd/MM').format(trip.startTime);

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
                color: vehicleColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                vehicleIcon,
                size: 20,
                color: vehicleColor,
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
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onSurfaceVariant,
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
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (trip.hasArrived)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: themeColors.statsSuccess.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tr(LocaleKeys.stats_dashboard_status_completed),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: themeColors.statsSuccess,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tr(LocaleKeys.stats_dashboard_status_stopped),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
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
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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
