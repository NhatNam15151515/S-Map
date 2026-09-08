import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/route_format_helper.dart';
import 'package:s_map/commons/widgets/widgets.dart';
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
        AppMetricCard(
          layout: AppMetricCardLayout.horizontal,
          icon: Icons.straighten_rounded,
          iconColor: colorScheme.primary,
          label: tr(LocaleKeys.stats_dashboard_kpi_total_distance),
          value: distanceStr,
        ),
        AppMetricCard(
          layout: AppMetricCardLayout.horizontal,
          icon: Icons.schedule_rounded,
          iconColor: themeColors.statsOrange,
          label: tr(LocaleKeys.stats_dashboard_kpi_total_duration),
          value: durationStr,
        ),
        AppMetricCard(
          layout: AppMetricCardLayout.horizontal,
          icon: Icons.speed_rounded,
          iconColor: themeColors.statsBlue,
          label: tr(LocaleKeys.stats_dashboard_kpi_avg_speed),
          value: avgSpeedStr,
        ),
        AppMetricCard(
          layout: AppMetricCardLayout.horizontal,
          icon: Icons.flash_on_rounded,
          iconColor: themeColors.statsPink,
          label: tr(LocaleKeys.stats_dashboard_kpi_top_speed),
          value: topSpeedStr,
        ),
      ],
    );
  }
}
