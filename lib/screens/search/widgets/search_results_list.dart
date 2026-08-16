import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

class SearchResultsList extends StatelessWidget {
  final List<PoiModel> results;
  final List<String> suggestions;
  final bool isLoading;
  final LatLng? userLocation;
  final ValueChanged<PoiModel> onPoiTap;
  final ValueChanged<String> onSuggestionTap;

  const SearchResultsList({
    super.key,
    required this.results,
    required this.suggestions,
    required this.isLoading,
    this.userLocation,
    required this.onPoiTap,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);

    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppColors.sMapTeal),
        ),
      );
    }

    if (results.isEmpty && suggestions.isEmpty) {
      return Center(
        child: EmptyWidget(
          title: tr(LocaleKeys.no_search_results),
          subtitle: tr(LocaleKeys.no_search_results_desc),
          icon: Icons.search_off_rounded,
        ),
      );
    }

    // Kết hợp danh sách: Ưu tiên POI results nếu có, nếu không thì hiển thị keyword suggestions
    final hasResults = results.isNotEmpty;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: hasResults ? results.length : suggestions.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        indent: 64,
        endIndent: 16,
        color: AppColors.outlineVariant,
      ),
      itemBuilder: (context, index) {
        if (hasResults) {
          final poi = results[index];
          final icon = PoiCategoryHelper.getIcon(poi.category, subCategory: poi.subCategory);
          final iconColor = PoiCategoryHelper.getIconColor(poi.category, subCategory: poi.subCategory);
          final bgColor = PoiCategoryHelper.getBackgroundColor(poi.category, subCategory: poi.subCategory);
          final address = PoiCategoryHelper.formatAddress(poi);

          String subtitleText = address;
          if (userLocation != null) {
            final distKm = AppUtils.instance.calculateDistance(
              userLocation!.latitude,
              userLocation!.longitude,
              poi.lat,
              poi.lon,
            );
            final distStr = PoiCategoryHelper.formatDistance(distKm);
            subtitleText = address.isNotEmpty ? '$distStr • $address' : distStr;
          }

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            title: Text(
              poi.name,
              style: style.blackTextColor.textTheme.boldStyle.copyWith(
                fontSize: 15,
                color: AppColors.googleDarkText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: subtitleText.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitleText,
                      style: AppColors.onSurfaceVariant.textTheme.textStyle.copyWith(
                        fontSize: 13,
                        fontWeight: AppFontWeight.regular.weight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : null,
            trailing: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.outlineVariant,
            ),
            onTap: () => onPoiTap(poi),
          );
        } else {
          final suggestion = suggestions[index];

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            leading: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_rounded,
                color: AppColors.onSurfaceVariant,
                size: 20,
              ),
            ),
            title: Text(
              suggestion,
              style: style.blackTextColor.textTheme.textStyle.copyWith(
                fontSize: 15,
                fontWeight: AppFontWeight.regular.weight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(
              Icons.north_west_rounded,
              size: 18,
              color: AppColors.onSurfaceVariant,
            ),
            onTap: () => onSuggestionTap(suggestion),
          );
        }
      },
    );
  }
}
