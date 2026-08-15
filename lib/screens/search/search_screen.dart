import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/commons/widgets/app_bar.dart';
import 'package:s_map/commons/mixin/app_mixin.dart';

class SearchScreen extends StatefulWidget {
  static const String path = '/search';

  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with AppMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBackAppBar(title: tr(LocaleKeys.search)),
      body: Column(
        children: [
          // Search input
          Container(
            margin: const EdgeInsets.all(16),
            decoration: styles.searchContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.search_rounded,
                    color: AppColors.onSurfaceVariant, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: tr(LocaleKeys.search_input_hint),
                      hintStyle: AppColors.onSurfaceVariant.textTheme.textStyle
                          .copyWith(fontSize: 15),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Category chips
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _categoryChip(tr(LocaleKeys.category_food), Icons.restaurant_rounded),
                _categoryChip(tr(LocaleKeys.category_coffee), Icons.coffee_rounded),
                _categoryChip(tr(LocaleKeys.category_hotel), Icons.hotel_rounded),
                _categoryChip(tr(LocaleKeys.category_atm), Icons.atm_rounded),
                _categoryChip(tr(LocaleKeys.category_hospital), Icons.local_hospital_rounded),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Recent searches
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  tr(LocaleKeys.recentSearches),
                  style: styles.blackTextColor.textTheme.subTitleStyle
                      .copyWith(fontSize: 15),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    tr(LocaleKeys.clearAll),
                    style: AppColors.sMapTeal.textTheme.boldStyle
                        .copyWith(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Empty state
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_rounded,
                      size: 48, color: AppColors.outlineVariant),
                  const SizedBox(height: 12),
                  Text(
                    tr(LocaleKeys.noRecentSearches),
                    style: AppColors.onSurfaceVariant.textTheme.textStyle
                        .copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: AppColors.sMapTeal),
        label: Text(label,
            style: styles.blackTextColor.textTheme.textStyle
                .copyWith(fontSize: 13)),
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.outlineVariant, width: 0.5),
        ),
        onPressed: () {},
      ),
    );
  }
}
