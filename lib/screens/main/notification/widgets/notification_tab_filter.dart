import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
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
    final colorScheme = context.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: NotificationTab.values.map((e) {
          final picked = selectedTab == e;
          final labelColor = picked ? colorScheme.primary : colorScheme.onSurfaceVariant;
          final textStyle = picked
              ? labelColor.textTheme.semiBoldStyle.copyWith(fontSize: 13)
              : labelColor.textTheme.regularStyle.copyWith(fontSize: 13);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: picked,
              onSelected: (selected) {
                if (selected) onTabChanged(e);
              },
              label: Text(
                e.title,
                style: textStyle,
              ),
              selectedColor: colorScheme.primary.withAlpha(35),
              backgroundColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: picked
                      ? colorScheme.primary
                      : colorScheme.outline.withAlpha(50),
                  width: 0.5,
                ),
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
