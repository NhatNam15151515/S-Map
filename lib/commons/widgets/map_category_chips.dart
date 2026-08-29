import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/constants/category_constants.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class MapCategoryChips extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String>? onCategorySelected;

  const MapCategoryChips({
    super.key,
    this.selectedCategory = CategoryConstants.all,
    this.onCategorySelected,
  });

  static const List<({String id, String titleKey, IconData icon, Color color})>
      _categories = [
    (
      id: CategoryConstants.food,
      titleKey: LocaleKeys.category_food,
      icon: Icons.restaurant_rounded,
      color: AppColors.googleRed
    ),
    (
      id: CategoryConstants.coffee,
      titleKey: LocaleKeys.category_coffee,
      icon: Icons.local_cafe_rounded,
      color: AppColors.constructionZone
    ),
    (
      id: CategoryConstants.hotel,
      titleKey: LocaleKeys.category_hotel,
      icon: Icons.hotel_rounded,
      color: AppColors.googleBlue
    ),
    (
      id: CategoryConstants.gas,
      titleKey: LocaleKeys.category_gas,
      icon: Icons.local_gas_station_rounded,
      color: AppColors.googleYellow
    ),
    (
      id: CategoryConstants.atm,
      titleKey: LocaleKeys.category_atm,
      icon: Icons.atm_rounded,
      color: AppColors.googleGreen
    ),
    (
      id: CategoryConstants.hospital,
      titleKey: LocaleKeys.category_hospital,
      icon: Icons.local_hospital_rounded,
      color: AppColors.sMapTeal
    ),
  ];

  void _onChipTap(String categoryId, bool isSelected) {
    HapticFeedback.lightImpact();
    onCategorySelected?.call(categoryId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return RepaintBoundary(
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final item = _categories[index];
            final isSelected = selectedCategory == item.id;
            final labelText = tr(item.titleKey);

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _onChipTap(item.id, isSelected),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary.withAlpha(35)
                        : colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outline.withAlpha(50),
                      width: isSelected ? 1.2 : 0.8,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.08),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        size: 16,
                        color: isSelected ? colorScheme.primary : item.color,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        labelText,
                        style: isSelected
                            ? colorScheme.primary
                                .textTheme
                                .textStyle
                                .copyWith(
                                  fontSize: 13,
                                  fontWeight: AppFontWeight.semiBold.weight,
                                )
                            : colorScheme.onSurface.textTheme.textStyle.copyWith(
                                fontSize: 13,
                                fontWeight: AppFontWeight.medium.weight,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }


}
