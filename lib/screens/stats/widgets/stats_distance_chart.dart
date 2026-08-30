import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
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
    final colorScheme = context.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
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
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.insert_chart_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(LocaleKeys.stats_dashboard_chart_title),
                  style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
                    fontSize: 14,
                  ),
                ),
              ),
              if (chartData.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tr(
                      LocaleKeys.stats_dashboard_distance_value,
                      args: ['${chartData.totalDistanceKm}'],
                    ),
                    style: colorScheme.primary.textTheme.semiBoldStyle.copyWith(
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (chartData.isEmpty || chartData.bars.isEmpty)
            _buildEmptyState(colorScheme)
          else
            _buildBarChart(context, colorScheme),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 44,
            color: colorScheme.outline.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            tr(LocaleKeys.stats_dashboard_chart_empty_title),
            style: colorScheme.onSurfaceVariant.textTheme.semiBoldStyle.copyWith(
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(LocaleKeys.stats_dashboard_chart_empty_desc),
            textAlign: TextAlign.center,
            style: colorScheme.onSurfaceVariant.textTheme.regularStyle.copyWith(
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(BuildContext context, ColorScheme colorScheme) {
    final bars = chartData.bars;
    final maxDist = chartData.maxDistanceKm;
    final rawMaxY = maxDist <= 0 ? 5.0 : (maxDist * 1.25);
    final maxY = rawMaxY.ceilToDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        const double minBarWidth = 44.0;
        final double contentWidth =
            math.max(constraints.maxWidth, bars.length * minBarWidth);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: bars.length > 7
              ? const BouncingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
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
                    getTooltipColor: (group) =>
                        colorScheme.surfaceContainerHighest,
                    tooltipPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final bar = bars[group.x.toInt()];
                      return BarTooltipItem(
                        '${tr(LocaleKeys.stats_dashboard_distance_value, args: ['${bar.distanceKm}'])} \n',
                        colorScheme.onSurface.textTheme.boldStyle.copyWith(
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: tr(
                              LocaleKeys.stats_dashboard_chart_trip_count,
                              args: ['${bar.tripCount}'],
                            ),
                            style: colorScheme.primary.textTheme.mediumStyle.copyWith(
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
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: (maxY / 4).clamp(1.0, double.infinity),
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value > maxY) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          '${value.toInt()}',
                          style: colorScheme.onSurfaceVariant.textTheme.mediumStyle.copyWith(
                            fontSize: 10,
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
                            style: colorScheme.onSurfaceVariant.textTheme.semiBoldStyle.copyWith(
                              fontSize: 10,
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
                    color: colorScheme.outline.withValues(alpha: 0.12),
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
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.secondary,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: bars.length > 7 ? 14 : 18,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: colorScheme.outline.withValues(alpha: 0.1),
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
