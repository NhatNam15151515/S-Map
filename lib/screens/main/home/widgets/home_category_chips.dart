import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
              onTap: () {
                setState(() {
                  _selectedCategory = isSelected ? "Tất cả" : item.title;
                });
                widget.onCategorySelected?.call(_selectedCategory);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.sMapLightTeal : AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.sMapTeal
                        : AppColors.outlineVariant.withAlpha(120),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(15),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
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
    );
  }
}
