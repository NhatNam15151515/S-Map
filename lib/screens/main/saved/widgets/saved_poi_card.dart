import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

class SavedPoiCard extends StatelessWidget {
  final PoiModel poi;
  final VoidCallback onTap;
  final VoidCallback onDirections;
  final VoidCallback onRemove;

  const SavedPoiCard({
    super.key,
    required this.poi,
    required this.onTap,
    required this.onDirections,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final icon =
        PoiCategoryHelper.getIcon(poi.category, subCategory: poi.subCategory);
    final iconColor = PoiCategoryHelper.getIconColor(poi.category,
        subCategory: poi.subCategory);
    final bgColor = PoiCategoryHelper.getBackgroundColor(poi.category,
        subCategory: poi.subCategory);
    final address = PoiCategoryHelper.formatAddress(poi);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withAlpha(50),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Category Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),

                // POI Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        poi.name,
                        style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          address,
                          style: colorScheme.onSurfaceVariant.textTheme.textStyle.copyWith(
                            fontSize: 12,
                            fontWeight: AppFontWeight.regular.weight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Actions: Directions & Remove
                IconButton(
                  icon: Icon(
                    Icons.directions_rounded,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                  tooltip: tr(LocaleKeys.directions),
                  onPressed: onDirections,
                ),
                IconButton(
                  icon: Icon(
                    Icons.bookmark_remove_rounded,
                    color: colorScheme.error,
                    size: 20,
                  ),
                  tooltip: tr(LocaleKeys.common_cancel),
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
