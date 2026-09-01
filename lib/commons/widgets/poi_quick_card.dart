import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final VoidCallback? onCustomRoute;

  const PoiQuickCard({
    super.key,
    required this.poi,
    this.userLocation,
    required this.onClose,
    this.onDirections,
    this.onCustomRoute,
  });

  @override
  Widget build(BuildContext context) {
    if (userLocation != null) {
      return _buildCard(context, userLocation);
    }

    return BlocBuilder<MapDisplayCubit, MapDisplayState>(
      buildWhen: (prev, curr) => prev.currentPosition != curr.currentPosition,
      builder: (context, state) {
        return _buildCard(context, state.currentPosition);
      },
    );
  }

  Widget _buildCard(BuildContext context, LatLng? effectiveLocation) {
    final colorScheme = context.colorScheme;
    final icon = PoiCategoryHelper.getIcon(poi.category, subCategory: poi.subCategory);
    final iconColor = PoiCategoryHelper.getIconColor(poi.category, subCategory: poi.subCategory);
    final bgColor = PoiCategoryHelper.getBackgroundColor(poi.category, subCategory: poi.subCategory);
    final categoryLabel = tr(PoiCategoryHelper.getCategoryLocaleKey(poi.category));
    final address = PoiCategoryHelper.formatAddress(poi);

    String? distStr;
    String? etaStr;
    if (effectiveLocation != null) {
      final distKm = AppUtils.instance.calculateDistance(
        effectiveLocation.latitude,
        effectiveLocation.longitude,
        poi.lat,
        poi.lon,
      );
      distStr = PoiCategoryHelper.formatDistance(distKm);
      final estMinutes = (distKm / 30 * 60).round();
      if (estMinutes < 1) {
        etaStr = '< 1 ${tr(LocaleKeys.minuteS)}';
      } else if (estMinutes >= 60) {
        final hours = estMinutes ~/ 60;
        final mins = estMinutes % 60;
        etaStr = mins > 0 ? '$hours ${tr(LocaleKeys.hourS)} $mins ${tr(LocaleKeys.minuteS)}' : '$hours ${tr(LocaleKeys.hourS)}';
      } else {
        etaStr = '~$estMinutes ${tr(LocaleKeys.minuteS)}';
      }
    }

    final latLonStr = '${poi.lat.toStringAsFixed(5)}, ${poi.lon.toStringAsFixed(5)}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      poi.name,
                      style: colorScheme.onSurface.textTheme.semiBoldStyle.copyWith(
                        fontSize: 16,
                        height: 1.25,
                      ),
                    ),
                    if (categoryLabel.isNotEmpty || (poi.subCategory != null && poi.subCategory!.isNotEmpty)) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (categoryLabel.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                categoryLabel,
                                style: colorScheme.primary.textTheme.mediumStyle.copyWith(
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          if (poi.subCategory != null &&
                              poi.subCategory!.trim().isNotEmpty &&
                              poi.subCategory!.toLowerCase() != poi.category?.toLowerCase())
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest.withAlpha(120),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                poi.subCategory!.trim(),
                                style: colorScheme.onSurfaceVariant.textTheme.mediumStyle.copyWith(
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              BlocBuilder<FavoritesCubit, FavoritesState>(
                builder: (context, favState) {
                  final cubit = context.read<FavoritesCubit>();
                  final key = cubit.getPoiKey(poi);
                  final isFav = favState.isFavorite(key);

                  return IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
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
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
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
          if (address.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address,
                    style: colorScheme.onSurfaceVariant.textTheme.textStyle.copyWith(
                      fontSize: 13,
                      fontWeight: AppFontWeight.regular.weight,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (distStr != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.two_wheeler_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  etaStr != null ? '$distStr • $etaStr' : distStr,
                  style: colorScheme.primary.textTheme.semiBoldStyle.copyWith(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              Clipboard.setData(ClipboardData(text: latLonStr));
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  content: Text('Đã sao chép tọa độ: $latLonStr'),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.my_location_rounded,
                    size: 14,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    latLonStr,
                    style: colorScheme.outline.textTheme.textStyle.copyWith(
                      fontSize: 12,
                      fontWeight: AppFontWeight.regular.weight,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.copy_rounded,
                    size: 12,
                    color: colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
          if (onDirections != null || onCustomRoute != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onDirections != null)
                  Expanded(
                    flex: 5,
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
                if (onDirections != null && onCustomRoute != null)
                  const SizedBox(width: 8),
                if (onCustomRoute != null)
                  Expanded(
                    flex: 4,
                    child: OutlinedButton.icon(
                      onPressed: onCustomRoute,
                      icon: Icon(
                        Icons.gesture_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      label: Text(
                        tr(LocaleKeys.route_drawing_ui_custom_route_drawing),
                        style: colorScheme.primary.textTheme.semiBoldStyle.copyWith(
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                        side: BorderSide(
                          color: colorScheme.primary.withAlpha(120),
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
