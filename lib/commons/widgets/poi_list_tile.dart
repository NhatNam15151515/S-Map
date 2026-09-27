import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

class PoiListTile extends StatelessWidget {
  final PoiModel poi;
  final LatLng? userLocation;
  final VoidCallback? onTap;
  final VoidCallback? onAddDestination;
  final bool hasExistingDestinations;
  final Widget? trailing;
  final EdgeInsetsGeometry contentPadding;

  const PoiListTile({
    super.key,
    required this.poi,
    this.userLocation,
    this.onTap,
    this.onAddDestination,
    this.hasExistingDestinations = false,
    this.trailing,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 6,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final icon = PoiCategoryHelper.getIcon(
      poi.category,
      subCategory: poi.subCategory,
    );
    final iconColor = PoiCategoryHelper.getIconColor(
      poi.category,
      subCategory: poi.subCategory,
    );
    final bgColor = PoiCategoryHelper.getBackgroundColor(
      poi.category,
      subCategory: poi.subCategory,
    );
    final address = PoiCategoryHelper.formatAddress(poi);
    final addDestinationCallback = hasExistingDestinations
        ? (onAddDestination ?? onTap)
        : null;
    final resolvedTrailing = trailing ??
        (hasExistingDestinations
            ? null
            : Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: colorScheme.outline,
              ));

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

    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: contentPadding,
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 22,
          ),
        ),
        title: Text(
          poi.name,
          style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: (subtitleText.isNotEmpty || addDestinationCallback != null)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (subtitleText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitleText,
                        style: colorScheme.onSurfaceVariant.textTheme.textStyle
                            .copyWith(
                          fontSize: 13,
                          fontWeight: AppFontWeight.regular.weight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (addDestinationCallback != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: InkWell(
                        key: const Key('poi_list_tile_add_destination_button'),
                        onTap: addDestinationCallback,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  colorScheme.primary.withValues(alpha: 0.25),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_location_alt_rounded,
                                size: 14,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                tr(LocaleKeys.route_drawing_ui_add_destination),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              )
            : null,
        trailing: resolvedTrailing,
      ),
    );
  }
}

