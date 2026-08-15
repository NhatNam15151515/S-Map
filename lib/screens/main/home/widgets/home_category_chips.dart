import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:s_map/commons/utils/app_colors.dart';

class HomeCategoryChips extends StatefulWidget {
  final ValueChanged<String>? onCategorySelected;

  const HomeCategoryChips({super.key, this.onCategorySelected});

  @override
  State<HomeCategoryChips> createState() => _HomeCategoryChipsState();
}

class _HomeCategoryChipsState extends State<HomeCategoryChips> {
  String _selectedCategory = "Tất cả";

  final List<({String title, IconData icon, Color color})> _categories = const [
    (title: "Ăn uống", icon: Icons.restaurant_rounded, color: AppColors.googleRed),
    (title: "Cà phê", icon: Icons.local_cafe_rounded, color: AppColors.constructionZone),
    (title: "Khách sạn", icon: Icons.hotel_rounded, color: AppColors.googleBlue),
    (title: "Cây xăng", icon: Icons.local_gas_station_rounded, color: AppColors.googleYellow),
    (title: "ATM", icon: Icons.atm_rounded, color: AppColors.googleGreen),
    (title: "Bệnh viện", icon: Icons.local_hospital_rounded, color: AppColors.sMapTeal),
  ];

  void _onChipTap(String title, bool isSelected) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedCategory = isSelected ? "Tất cả" : title;
    });
    widget.onCategorySelected?.call(_selectedCategory);
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
                        item.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.sMapDarkTeal
                              : AppColors.googleDarkText,
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
