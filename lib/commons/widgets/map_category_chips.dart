import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/app_colors.dart';

class MapCategoryChips extends StatefulWidget {
  final String selectedCategory;
  final ValueChanged<String>? onCategorySelected;

  const MapCategoryChips({
    super.key,
    this.selectedCategory = "Tất cả",
    this.onCategorySelected,
  });

  @override
  State<MapCategoryChips> createState() => _MapCategoryChipsState();
}

class _MapCategoryChipsState extends State<MapCategoryChips> {
  late String _selectedCategory;

  final List<({String titleKey, String title, IconData icon, Color color})>
      _categories = const [
    (
      titleKey: 'category.food',
      title: "Ăn uống",
      icon: Icons.restaurant_rounded,
      color: AppColors.googleRed
    ),
    (
      titleKey: 'category.coffee',
      title: "Cà phê",
      icon: Icons.local_cafe_rounded,
      color: AppColors.constructionZone
    ),
    (
      titleKey: 'category.hotel',
      title: "Khách sạn",
      icon: Icons.hotel_rounded,
      color: AppColors.googleBlue
    ),
    (
      titleKey: 'category.gas',
      title: "Cây xăng",
      icon: Icons.local_gas_station_rounded,
      color: AppColors.googleYellow
    ),
    (
      titleKey: 'category.atm',
      title: "ATM",
      icon: Icons.atm_rounded,
      color: AppColors.googleGreen
    ),
    (
      titleKey: 'category.hospital',
      title: "Bệnh viện",
      icon: Icons.local_hospital_rounded,
      color: AppColors.sMapTeal
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.selectedCategory;
  }

  @override
  void didUpdateWidget(covariant MapCategoryChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategory != widget.selectedCategory) {
      _selectedCategory = widget.selectedCategory;
    }
  }

  void _onChipTap(String title, bool isSelected) {
    HapticFeedback.lightImpact();
    final nextCategory = isSelected ? "Tất cả" : title;
    setState(() {
      _selectedCategory = nextCategory;
    });
    widget.onCategorySelected?.call(nextCategory);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final item = _categories[index];
            final isSelected = _selectedCategory == item.title;
            final translated = tr(item.titleKey);
            final labelText = translated == item.titleKey ? item.title : translated;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _onChipTap(item.title, isSelected),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.sMapLightTeal : AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.sMapTeal
                          : AppColors.outlineVariant.withAlpha(120),
                      width: isSelected ? 1.2 : 0.8,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.05),
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
                        color: isSelected ? AppColors.sMapTeal : item.color,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        labelText,
                        style: isSelected
                            ? AppColors.sMapDarkTeal.textTheme.textStyle.copyWith(
                                fontSize: 13,
                                fontWeight: AppFontWeight.semiBold.weight,
                              )
                            : AppColors.googleDarkText.textTheme.textStyle.copyWith(
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
