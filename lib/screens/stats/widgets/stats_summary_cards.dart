import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/commons/utils/route_format_helper.dart';
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
    final durationStr = stats.totalDurationMs > 0
        ? RouteFormatHelper.formatTripDuration(Duration(milliseconds: stats.totalDurationMs))
        : '0 ${tr(LocaleKeys.routing_unit_minute)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  key: const Key('kpi_card_distance'),
                  icon: Icons.route_rounded,
                  iconColor: AppColors.sMapDarkTeal,
                  backgroundColor: AppColors.sMapTeal.withValues(alpha: 0.08),
                  title: tr(LocaleKeys.stats_dashboard_kpi_total_distance),
                  value: stats.totalDistanceKm.toStringAsFixed(1),
                  unit: 'km',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  key: const Key('kpi_card_duration'),
                  icon: Icons.schedule_rounded,
                  iconColor: const Color(0xFFE65100), // Amber-orange
                  backgroundColor: const Color(0xFFFFF3E0),
                  title: tr(LocaleKeys.stats_dashboard_kpi_total_duration),
                  value: durationStr,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  key: const Key('kpi_card_trips'),
                  icon: Icons.flag_rounded,
                  iconColor: const Color(0xFF2E7D32), // Green
                  backgroundColor: const Color(0xFFE8F5E9),
                  title: tr(LocaleKeys.stats_dashboard_kpi_total_trips),
                  value: '${stats.totalTrips}',
                  subtitle: tr(
                    LocaleKeys.stats_dashboard_kpi_completion_rate,
                    args: ['${(stats.completionRate * 100).round()}%'],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  key: const Key('kpi_card_speed'),
                  icon: Icons.speed_rounded,
                  iconColor: const Color(0xFF1565C0), // Blue
                  backgroundColor: const Color(0xFFE3F2FD),
                  title: tr(LocaleKeys.stats_dashboard_kpi_avg_speed),
                  value: '${stats.avgSpeedKmh.round()}',
                  unit: 'km/h',
                  subtitle: '${tr(LocaleKeys.stats_dashboard_kpi_top_speed)}: ${stats.topSpeedKmh.round()} km/h',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String title;
  final String value;
  final String? unit;
  final String? subtitle;

  const _KpiCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.title,
    required this.value,
    this.unit,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: iconColor,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(
                  unit!,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: iconColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
