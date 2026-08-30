import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

class PoiQuickCard extends StatelessWidget {
  final PoiModel poi;
  final LatLng? userLocation;
  final VoidCallback onClose;
  final VoidCallback? onDirections;

  const PoiQuickCard({
    super.key,
    required this.poi,
    this.userLocation,
    required this.onClose,
    this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    LatLng? effectiveLocation = userLocation;
    if (effectiveLocation == null) {
      try {
        final mapDisplayState = context.watch<MapDisplayCubit>().state;
        effectiveLocation = mapDisplayState.currentPosition;
      } catch (_) {
        // If MapDisplayCubit is not in context, keep null
      }
    }

    final colorScheme = context.colorScheme;
    final icon = PoiCategoryHelper.getIcon(poi.category, subCategory: poi.subCategory);
    final iconColor = PoiCategoryHelper.getIconColor(poi.category, subCategory: poi.subCategory);
    final bgColor = PoiCategoryHelper.getBackgroundColor(poi.category, subCategory: poi.subCategory);
    final categoryLabel = tr(PoiCategoryHelper.getCategoryLocaleKey(poi.category));
    final address = PoiCategoryHelper.formatAddress(poi);

    String subtitleText = address;
    if (effectiveLocation != null) {
      final distKm = AppUtils.instance.calculateDistance(
        effectiveLocation.latitude,
        effectiveLocation.longitude,
        poi.lat,
        poi.lon,
      );
      final distStr = PoiCategoryHelper.formatDistance(distKm);
      subtitleText = address.isNotEmpty ? '$distStr • $address' : distStr;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withAlpha(80),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      poi.name,
                      style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (categoryLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        categoryLabel,
                        style: colorScheme.onSurfaceVariant.textTheme.textStyle.copyWith(
                          fontSize: 12,
                          fontWeight: AppFontWeight.regular.weight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (subtitleText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitleText,
                        style: colorScheme.onSurfaceVariant.textTheme.textStyle.copyWith(
                          fontSize: 13,
                          fontWeight: AppFontWeight.regular.weight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              BlocBuilder<FavoritesCubit, FavoritesState>(
                builder: (context, favState) {
                  final cubit = context.read<FavoritesCubit>();
                  final key = cubit.getPoiKey(poi);
                  final isFav = favState.isFavorite(key);

                  return IconButton(
                    icon: Icon(
                      isFav
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_outline_rounded,
                      size: 22,
                      color: isFav
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => cubit.toggleFavorite(poi),
                    tooltip: tr(LocaleKeys.savedPlaces),
                  );
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                onPressed: onClose,
                tooltip: tr(LocaleKeys.cancel),
              ),
            ],
          ),
          if (onDirections != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onDirections,
                    icon: Icon(
                      Icons.directions_rounded,
                      size: 18,
                      color: colorScheme.onPrimary,
                    ),
                    label: Text(
                      tr(LocaleKeys.directions),
                      style: colorScheme.onPrimary.textTheme.semiBoldStyle.copyWith(
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
