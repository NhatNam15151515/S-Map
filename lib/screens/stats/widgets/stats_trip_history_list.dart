import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';
import 'stats_trip_item_tile.dart';

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
                  style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
                    fontSize: 14,
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
                  tr(
                    LocaleKeys.stats_dashboard_history_count,
                    args: ['${trips.length}'],
                  ),
                  style: colorScheme.onSurfaceVariant.textTheme.semiBoldStyle
                      .copyWith(
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (trips.isEmpty)
            EmptyWidget(
              key: const Key('stats_trip_history_empty'),
              icon: Icons.explore_off_rounded,
              title: tr(LocaleKeys.stats_dashboard_history_empty_title),
              subtitle: tr(LocaleKeys.stats_dashboard_history_empty_desc),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: trips.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final trip = trips[index];
                return StatsTripItemTile(
                  trip: trip,
                  onTap: () => onTapTrip(trip),
                  onDelete: () => TripFormatHelper.showDeleteConfirmDialog(
                    context,
                    onConfirm: () => onDeleteTrip(trip.id),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
