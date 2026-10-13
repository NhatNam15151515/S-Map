import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

/// Widget chuyên biệt phụ trách render biểu đồ cột khoảng cách (FL Chart).
///
/// Tách rời hoàn toàn logic cấu hình biểu đồ, tính toán trục tung (Y-axis),
/// trục hoành (X-axis) và tooltip ra khỏi card container.
class StatsDistanceBarChart extends StatelessWidget {
  static const double chartHeight = 200.0;
  static const double minBarWidth = 44.0;

  final TripChartData chartData;

  const StatsDistanceBarChart({
    super.key,
    required this.chartData,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final bars = chartData.bars;
    final maxY = chartData.maxY;
    final interval = chartData.yAxisInterval;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double contentWidth =
            math.max(constraints.maxWidth, bars.length * minBarWidth);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: bars.length > 7
              ? const BouncingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          child: SizedBox(
            width: contentWidth,
            height: chartHeight,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: _buildBarTouchData(colorScheme, bars),
                titlesData: _buildTitlesData(colorScheme, maxY, bars, interval),
                gridData: _buildGridData(colorScheme, interval),
                borderData: FlBorderData(show: false),
                barGroups: _buildBarGroups(colorScheme, maxY, bars),
              ),
            ),
          ),
        );
      },
    );
  }

  BarTouchData _buildBarTouchData(
    ColorScheme colorScheme,
    List<TripChartBarData> bars,
  ) {
    return BarTouchData(
      enabled: true,
      touchTooltipData: BarTouchTooltipData(
        getTooltipColor: (_) => colorScheme.surfaceContainerHighest,
        tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    );
  }

  FlTitlesData _buildTitlesData(
    ColorScheme colorScheme,
    double maxY,
    List<TripChartBarData> bars,
    double interval,
  ) {
    return FlTitlesData(
      show: true,
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        axisNameWidget: Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            'km',
            style:
                colorScheme.onSurfaceVariant.textTheme.semiBoldStyle.copyWith(
              fontSize: 10,
            ),
          ),
        ),
        axisNameSize: 16,
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 34,
          interval: interval,
          getTitlesWidget: (value, meta) {
            if (value < 0 || value > maxY + 0.001) {
              return const SizedBox.shrink();
            }
            final isInt = (value - value.round()).abs() < 0.05;
            final text = isInt ? '${value.round()}' : value.toStringAsFixed(1);
            return SideTitleWidget(
              meta: meta,
              child: Text(
                text,
                style:
                    colorScheme.onSurfaceVariant.textTheme.mediumStyle.copyWith(
                  fontSize: 10,
                ),
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
                style:
                    colorScheme.onSurfaceVariant.textTheme.semiBoldStyle.copyWith(
                  fontSize: 10,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  FlGridData _buildGridData(ColorScheme colorScheme, double interval) {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: interval,
      getDrawingHorizontalLine: (value) => FlLine(
        color: colorScheme.outline.withValues(alpha: 0.12),
        strokeWidth: 1,
        dashArray: [4, 4],
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(
    ColorScheme colorScheme,
    double maxY,
    List<TripChartBarData> bars,
  ) {
    return bars.map((bar) {
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxY,
              color: colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
        ],
      );
    }).toList();
  }
}
