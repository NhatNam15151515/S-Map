import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/utils/app_colors.dart';
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
      default:
        return Icons.two_wheeler_rounded;
    }
  }

  Color _getVehicleColor(String profile) {
    switch (profile.toLowerCase()) {
      case 'car':
        return const Color(0xFF1565C0);
      case 'walking':
      case 'foot':
        return const Color(0xFFE65100);
      case 'motorcycle':
      case 'moped':
      default:
        return AppColors.sMapDarkTeal;
    }
  }

  Future<void> _showDeleteConfirmDialog(BuildContext context, TripRecordModel trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          tr(LocaleKeys.stats_dashboard_delete_trip_title),
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        content: Text(
          tr(LocaleKeys.stats_dashboard_delete_trip_desc),
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 13,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              tr(LocaleKeys.cancel),
              style: const TextStyle(fontFamily: 'Montserrat', color: AppColors.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            key: const Key('confirm_delete_trip_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              tr(LocaleKeys.clearAll),
              style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onDeleteTrip(trip.id);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  color: AppColors.sMapDarkTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  size: 16,
                  color: AppColors.sMapDarkTeal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(LocaleKeys.stats_dashboard_history_title),
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tr(LocaleKeys.stats_dashboard_history_count, args: ['${trips.length}']),
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
          const SizedBox(height: 12),
          if (trips.isEmpty)
            _buildEmptyState()
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
                  vehicleColor: _getVehicleColor(trip.vehicleProfile),
                  onTap: () => onTapTrip(trip),
                  onDelete: () => _showDeleteConfirmDialog(context, trip),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.explore_off_rounded,
            size: 40,
            color: AppColors.outline.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 8),
          Text(
            tr(LocaleKeys.stats_dashboard_history_empty_title),
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(LocaleKeys.stats_dashboard_history_empty_desc),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 11,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.outline.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
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
                color: vehicleColor.withValues(alpha: 0.1),
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
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 10,
                          color: AppColors.onSurfaceVariant,
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
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onSurfaceVariant,
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
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tr(LocaleKeys.stats_dashboard_status_completed),
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tr(LocaleKeys.stats_dashboard_status_stopped),
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurfaceVariant,
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
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
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
