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
                      ? AppColors.sMapDarkTeal
                      : AppColors.onSurfaceVariant,
                ),
              ),
              selectedColor: AppColors.sMapLightTeal,
              backgroundColor: AppColors.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide.none,
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
