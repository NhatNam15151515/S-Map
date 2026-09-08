import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';
import 'stats_distance_bar_chart.dart';

/// Card container hiển thị thống kê khoảng cách di chuyển theo biểu đồ.
///
/// Quản lý header card (tiêu đề, icon, tổng khoảng cách), trạng thái rỗng
/// ([EmptyWidget]) và nhúng [StatsDistanceBarChart] cho phần render đồ thị.
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
            SizedBox(
              height: 180,
              child: EmptyWidget(
                icon: Icons.bar_chart_rounded,
                title: tr(LocaleKeys.stats_dashboard_chart_empty_title),
                subtitle: tr(LocaleKeys.stats_dashboard_chart_empty_desc),
              ),
            )
          else
            StatsDistanceBarChart(chartData: chartData),
        ],
      ),
    );
  }
}
