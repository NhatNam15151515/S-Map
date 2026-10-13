import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';

/// Danh sách chip lọc chuyến đi theo phương tiện (Tất cả, Xe máy, Ô tô, Đi bộ).
class StatsVehicleFilterChips extends StatelessWidget {
  final String? selectedProfile;
  final ValueChanged<String?> onProfileSelected;
  final Map<String, int> profileCounts;

  const StatsVehicleFilterChips({
    super.key,
    required this.selectedProfile,
    required this.onProfileSelected,
    this.profileCounts = const {},
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final filters = TripFormatHelper.getVehicleFilterOptions();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: filters.map((item) {
          final profile = item.$1;
          final label = item.$2;
          final icon = item.$3;
          final isSelected = profile == selectedProfile;
          final count =
              TripFormatHelper.getProfileTripCount(profileCounts, profile);

          final textColor =
              isSelected ? colorScheme.onPrimary : colorScheme.onSurface;
          final iconColor =
              isSelected ? colorScheme.onPrimary : colorScheme.primary;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              key: Key('stats_profile_${profile ?? 'all'}'),
              avatar: Icon(
                icon,
                size: 16,
                color: iconColor,
              ),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: isSelected
                        ? textColor.textTheme.semiBoldStyle.copyWith(fontSize: 12)
                        : textColor.textTheme.mediumStyle.copyWith(fontSize: 12),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.onPrimary.withValues(alpha: 0.25)
                            : colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: isSelected
                            ? colorScheme.onPrimary.textTheme.semiBoldStyle
                                .copyWith(fontSize: 10)
                            : colorScheme.primary.textTheme.semiBoldStyle
                                .copyWith(fontSize: 10),
                      ),
                    ),
                  ],
                ],
              ),
              selected: isSelected,
              selectedColor: colorScheme.primary,
              backgroundColor: colorScheme.surface,
              showCheckmark: false,
              side: BorderSide(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (_) => onProfileSelected(profile),
            ),
          );
        }).toList(),
      ),
    );
  }
}
