import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

class PoiQuickCard extends StatelessWidget {
  final PoiModel poi;
  final VoidCallback onClose;
  final VoidCallback? onDirections;

  const PoiQuickCard({
    super.key,
    required this.poi,
    required this.onClose,
    this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    final icon = PoiCategoryHelper.getIcon(poi.category, subCategory: poi.subCategory);
    final iconColor = PoiCategoryHelper.getIconColor(poi.category, subCategory: poi.subCategory);
    final bgColor = PoiCategoryHelper.getBackgroundColor(poi.category, subCategory: poi.subCategory);
    final address = PoiCategoryHelper.formatAddress(poi);
    String subtitleText = address;
    try {
      final userLocation =
          context.read<MapDisplayCubit>().state.currentPosition;
      if (userLocation != null) {
        final distKm = AppUtils.instance.calculateDistance(
          userLocation.latitude,
          userLocation.longitude,
          poi.lat,
          poi.lon,
        );
        final distStr = PoiCategoryHelper.formatDistance(distKm);
        subtitleText = address.isNotEmpty ? '$distStr • $address' : distStr;
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withAlpha(100),
          width: 0.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.12),
            blurRadius: 16,
            offset: Offset(0, 6),
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
                      style: style.blackTextColor.textTheme.boldStyle.copyWith(
                        fontSize: 16,
                        color: AppColors.googleDarkText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitleText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitleText,
                        style: AppColors.onSurfaceVariant.textTheme.textStyle.copyWith(
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
              Builder(
                builder: (context) {
                  FavoritesCubit? cubit;
                  try {
                    cubit = context.watch<FavoritesCubit>();
                  } catch (_) {}

                  if (cubit == null) {
                    return const SizedBox.shrink();
                  }

                  final key = cubit.getPoiKey(poi);
                  final isFav = cubit.state.isFavorite(key);

                  return IconButton(
                    icon: Icon(
                      isFav
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_outline_rounded,
                      size: 22,
                      color: isFav
                          ? AppColors.sMapTeal
                          : AppColors.onSurfaceVariant,
                    ),
                    onPressed: () => cubit?.toggleFavorite(poi),
                    tooltip: tr(LocaleKeys.savedPlaces),
                  );
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: AppColors.onSurfaceVariant,
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
                    icon: const Icon(
                      Icons.directions_rounded,
                      size: 18,
                      color: AppColors.white,
                    ),
                    label: Text(
                      tr(LocaleKeys.directions),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sMapTeal,
                      foregroundColor: AppColors.white,
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
