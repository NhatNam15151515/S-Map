import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

class StatsDistanceChart extends StatelessWidget {
  final TripChartData chartData;

  const StatsDistanceChart({
    super.key,
    required this.chartData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
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
                  color: AppColors.sMapDarkTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.insert_chart_rounded,
                  size: 16,
                  color: AppColors.sMapDarkTeal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(LocaleKeys.stats_dashboard_chart_title),
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              if (chartData.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.sMapTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${chartData.totalDistanceKm} km',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.sMapDarkTeal,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (chartData.isEmpty || chartData.bars.isEmpty)
            _buildEmptyState()
          else
            _buildBarChart(context),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 180,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 44,
            color: AppColors.outline.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 8),
          Text(
            tr(LocaleKeys.stats_dashboard_chart_empty_title),
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(LocaleKeys.stats_dashboard_chart_empty_desc),
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

  Widget _buildBarChart(BuildContext context) {
    final bars = chartData.bars;
    final maxDist = chartData.maxDistanceKm;
    final rawMaxY = maxDist <= 0 ? 5.0 : (maxDist * 1.25);
    final maxY = rawMaxY.ceilToDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        const double minBarWidth = 44.0;
        final double contentWidth = math.max(constraints.maxWidth, bars.length * minBarWidth);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: bars.length > 7 ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
          child: SizedBox(
            width: contentWidth,
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => AppColors.surfaceDim,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final bar = bars[group.x.toInt()];
                      return BarTooltipItem(
                        '${bar.distanceKm} km\n',
                        const TextStyle(
                          fontFamily: 'Montserrat',
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: tr(
                              LocaleKeys.stats_dashboard_chart_trip_count,
                              args: ['${bar.tripCount}'],
                            ),
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              color: AppColors.sMapDarkTeal,
                              fontWeight: FontWeight.w500,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: (maxY / 4).clamp(1.0, double.infinity),
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value > maxY) return const SizedBox.shrink();
                        return Text(
                          '${value.toInt()}',
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            color: AppColors.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= bars.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            bars[index].label,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              color: AppColors.onSurfaceVariant,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY / 4).clamp(1.0, double.infinity),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.outline.withValues(alpha: 0.08),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: bars.map((bar) {
                  return BarChartGroupData(
                    x: bar.x,
                    barRods: [
                      BarChartRodData(
                        toY: bar.distanceKm,
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.sMapDarkTeal,
                            AppColors.sMapTeal,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: bars.length > 7 ? 14 : 18,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
