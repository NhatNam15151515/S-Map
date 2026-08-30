import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/route_format_helper.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

class TripDetailKpiGrid extends StatelessWidget {
  final TripRecordModel trip;

  const TripDetailKpiGrid({
    super.key,
    required this.trip,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final themeColors = context.themeColors;
    final durationStr = RouteFormatHelper.formatTripDuration(trip.duration);
    final distanceStr = tr(
      LocaleKeys.stats_dashboard_distance_value,
      args: [trip.distanceKm.toStringAsFixed(1)],
    );
    final avgSpeedStr = tr(
      LocaleKeys.stats_dashboard_avg_speed_value,
      args: [trip.avgSpeedKmh.toStringAsFixed(0)],
    );
    final topSpeedStr = tr(
      LocaleKeys.stats_dashboard_top_speed_value,
      args: [trip.topSpeedKmh.toStringAsFixed(0)],
    );

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        _StatCard(
          icon: Icons.straighten_rounded,
          iconColor: colorScheme.primary,
          label: tr(LocaleKeys.stats_dashboard_kpi_total_distance),
          value: distanceStr,
        ),
        _StatCard(
          icon: Icons.schedule_rounded,
          iconColor: themeColors.statsOrange,
          label: tr(LocaleKeys.stats_dashboard_kpi_total_duration),
          value: durationStr,
        ),
        _StatCard(
          icon: Icons.speed_rounded,
          iconColor: themeColors.statsBlue,
          label: tr(LocaleKeys.stats_dashboard_kpi_avg_speed),
          value: avgSpeedStr,
        ),
        _StatCard(
          icon: Icons.flash_on_rounded,
          iconColor: themeColors.statsPink,
          label: tr(LocaleKeys.stats_dashboard_kpi_top_speed),
          value: topSpeedStr,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: colorScheme.onSurfaceVariant.textTheme.captionStyle.copyWith(
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
