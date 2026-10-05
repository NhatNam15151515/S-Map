import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/route_format_helper.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

class StatsSummaryCards extends StatelessWidget {
  final TripStatsModel stats;

  const StatsSummaryCards({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final themeColors = context.themeColors;
    final durationStr = stats.totalDurationMs > 0
        ? RouteFormatHelper.formatTripDuration(
            Duration(milliseconds: stats.totalDurationMs))
        : '0 ${tr(LocaleKeys.routing_unit_minute)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AppMetricCard(
                  key: const Key('kpi_card_distance'),
                  icon: Icons.route_rounded,
                  iconColor: colorScheme.primary,
                  iconBackgroundColor:
                      colorScheme.primary.withValues(alpha: 0.12),
                  label: tr(LocaleKeys.stats_dashboard_kpi_total_distance),
                  value: stats.totalDistanceKm.toStringAsFixed(1),
                  unit: 'km',
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppMetricCard(
                  key: const Key('kpi_card_duration'),
                  icon: Icons.schedule_rounded,
                  iconColor: themeColors.statsOrange,
                  iconBackgroundColor:
                      themeColors.statsOrange.withValues(alpha: 0.12),
                  label: tr(LocaleKeys.stats_dashboard_kpi_total_duration),
                  value: durationStr,
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.all(14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppMetricCard(
                  key: const Key('kpi_card_trips'),
                  icon: Icons.flag_rounded,
                  iconColor: themeColors.statsSuccess,
                  iconBackgroundColor:
                      themeColors.statsSuccess.withValues(alpha: 0.12),
                  label: tr(LocaleKeys.stats_dashboard_kpi_total_trips),
                  value: '${stats.totalTrips}',
                  subtitle: tr(
                    LocaleKeys.stats_dashboard_kpi_completion_rate,
                    args: ['${(stats.completionRate * 100).round()}%'],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppMetricCard(
                  key: const Key('kpi_card_speed'),
                  icon: Icons.speed_rounded,
                  iconColor: themeColors.statsBlue,
                  iconBackgroundColor:
                      themeColors.statsBlue.withValues(alpha: 0.12),
                  label: tr(LocaleKeys.stats_dashboard_kpi_avg_speed),
                  value: '${stats.avgSpeedKmh.round()}',
                  unit: 'km/h',
                  subtitle:
                      '${tr(LocaleKeys.stats_dashboard_kpi_top_speed)}: ${tr(LocaleKeys.stats_dashboard_speed_unit, args: ['${stats.topSpeedKmh.round()}'])}',
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.all(14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
