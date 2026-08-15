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
    final style = AppStyle.of(context);
    final icon =
        PoiCategoryHelper.getIcon(poi.category, subCategory: poi.subCategory);
    final iconColor = PoiCategoryHelper.getIconColor(poi.category,
        subCategory: poi.subCategory);
    final bgColor = PoiCategoryHelper.getBackgroundColor(poi.category,
        subCategory: poi.subCategory);
    final address = PoiCategoryHelper.formatAddress(poi);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withAlpha(100),
          width: 0.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 10,
            offset: Offset(0, 3),
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
                        style:
                            style.blackTextColor.textTheme.boldStyle.copyWith(
                          fontSize: 15,
                          color: AppColors.googleDarkText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          address,
                          style: AppColors
                              .onSurfaceVariant.textTheme.textStyle
                              .copyWith(
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
                  icon: const Icon(
                    Icons.directions_rounded,
                    color: AppColors.googleBlue,
                    size: 22,
                  ),
                  tooltip: tr(LocaleKeys.directions),
                  onPressed: onDirections,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.bookmark_remove_rounded,
                    color: AppColors.googleRed,
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
