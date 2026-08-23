import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

class StatsTimeRangeSelector extends StatelessWidget {
  final StatsTimeRange selectedRange;
  final ValueChanged<StatsTimeRange> onRangeSelected;

  const StatsTimeRangeSelector({
    super.key,
    required this.selectedRange,
    required this.onRangeSelected,
  });

  String _getRangeLabel(StatsTimeRange range) {
    switch (range) {
      case StatsTimeRange.today:
        return tr(LocaleKeys.stats_dashboard_range_today);
      case StatsTimeRange.thisWeek:
        return tr(LocaleKeys.stats_dashboard_range_this_week);
      case StatsTimeRange.thisMonth:
        return tr(LocaleKeys.stats_dashboard_range_this_month);
      case StatsTimeRange.thisYear:
        return tr(LocaleKeys.stats_dashboard_range_this_year);
      case StatsTimeRange.allTime:
        return tr(LocaleKeys.stats_dashboard_range_all_time);
    }
  }

  @override
  Widget build(BuildContext context) {
    const ranges = StatsTimeRange.values;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: ranges.map((range) {
          final isSelected = range == selectedRange;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              key: Key('stats_range_${range.name}'),
              label: Text(
                _getRangeLabel(range),
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.sMapDarkTeal,
              backgroundColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
              showCheckmark: false,
              side: BorderSide(
                color: isSelected ? AppColors.sMapDarkTeal : AppColors.outline.withValues(alpha: 0.2),
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onSelected: (_) => onRangeSelected(range),
            ),
          );
        }).toList(),
      ),
    );
  }
}
