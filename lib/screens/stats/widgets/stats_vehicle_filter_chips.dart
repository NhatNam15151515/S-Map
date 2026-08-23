import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/generated/locale_keys.g.dart';

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

  int _getCountForProfile(String? profile) {
    if (profile == null) {
      final motorcycle = (profileCounts['motorcycle'] ?? 0) +
          (profileCounts['moped_vn'] ?? 0) +
          (profileCounts['moped'] ?? 0);
      final car = profileCounts['car'] ?? 0;
      final walking = (profileCounts['walking'] ?? 0) + (profileCounts['foot'] ?? 0);
      return motorcycle + car + walking;
    }
    if (profile == 'motorcycle') {
      return (profileCounts['motorcycle'] ?? 0) +
          (profileCounts['moped_vn'] ?? 0) +
          (profileCounts['moped'] ?? 0);
    }
    if (profile == 'walking') {
      return (profileCounts['walking'] ?? 0) + (profileCounts['foot'] ?? 0);
    }
    return profileCounts[profile] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final filters = [
      (null, tr(LocaleKeys.stats_dashboard_filter_all), Icons.all_inclusive_rounded),
      ('motorcycle', tr(LocaleKeys.stats_dashboard_filter_motorcycle), Icons.two_wheeler_rounded),
      ('car', tr(LocaleKeys.stats_dashboard_filter_car), Icons.directions_car_rounded),
      ('walking', tr(LocaleKeys.stats_dashboard_filter_walking), Icons.directions_walk_rounded),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: filters.map((item) {
          final profile = item.$1;
          final label = item.$2;
          final icon = item.$3;
          final isSelected = profile == selectedProfile;
          final count = _getCountForProfile(profile);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              key: Key('stats_profile_${profile ?? 'all'}'),
              avatar: Icon(
                icon,
                size: 16,
                color: isSelected ? AppColors.white : AppColors.sMapDarkTeal,
              ),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? AppColors.white : AppColors.onSurface,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.white.withValues(alpha: 0.25)
                            : AppColors.sMapDarkTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppColors.white : AppColors.sMapDarkTeal,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              selected: isSelected,
              selectedColor: AppColors.sMapTeal,
              backgroundColor: AppColors.surface,
              showCheckmark: false,
              side: BorderSide(
                color: isSelected ? AppColors.sMapTeal : AppColors.outline.withValues(alpha: 0.15),
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
