import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class SearchRecentList extends StatelessWidget {
  final List<String> recentSearches;
  final ValueChanged<String> onItemTap;
  final ValueChanged<String> onItemRemove;
  final VoidCallback onClearAll;

  const SearchRecentList({
    super.key,
    required this.recentSearches,
    required this.onItemTap,
    required this.onItemRemove,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    if (recentSearches.isEmpty) {
      return Center(
        child: EmptyWidget(
          title: tr(LocaleKeys.noRecentSearches),
          icon: Icons.history_rounded,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Text(
                tr(LocaleKeys.recentSearches),
                style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onClearAll,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  tr(LocaleKeys.clearAll),
                  style: colorScheme.primary.textTheme.boldStyle.copyWith(
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: recentSearches.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 52,
              endIndent: 16,
              color: colorScheme.outline.withValues(alpha: 0.3),
            ),
            itemBuilder: (context, index) {
              final query = recentSearches[index];

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                title: Text(
                  query,
                  style:
                      colorScheme.onSurface.textTheme.textStyle.copyWith(
                    fontSize: 15,
                    fontWeight: AppFontWeight.regular.weight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => onItemRemove(query),
                  tooltip: tr(LocaleKeys.cancel),
                ),
                onTap: () => onItemTap(query),
              );
            },
          ),
        ),
      ],
    );
  }
}
