import 'package:flutter/material.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/models/models.dart';

class NotificationTabFilter extends StatelessWidget {
  final NotificationTab selectedTab;
  final ValueChanged<NotificationTab> onTabChanged;

  const NotificationTabFilter({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: NotificationTab.values.map((e) {
          final picked = selectedTab == e;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: picked,
              onSelected: (selected) {
                if (selected) onTabChanged(e);
              },
              label: Text(
                e.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: picked ? FontWeight.w600 : FontWeight.w400,
                  color: picked
                      ? (isDark ? AppColors.sMapTeal : AppColors.sMapDarkTeal)
                      : (isDark
                          ? const Color(0xFF9AA0A6)
                          : AppColors.onSurfaceVariant),
                ),
              ),
              selectedColor: isDark
                  ? AppColors.sMapTeal.withAlpha(50)
                  : AppColors.sMapLightTeal,
              backgroundColor: isDark
                  ? AppColors.darkSurfaceContainer
                  : AppColors.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: isDark
                    ? BorderSide(
                        color: AppColors.darkOutline.withAlpha(60), width: 0.5)
                    : BorderSide.none,
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          );
        }).toList(),
      ),
    );
  }

}
