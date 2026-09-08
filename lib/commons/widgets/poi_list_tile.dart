import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/models/models.dart';

class PoiListTile extends StatelessWidget {
  final PoiModel poi;
  final LatLng? userLocation;
  final VoidCallback? onTap;
  final Widget? trailing;
  final EdgeInsetsGeometry contentPadding;

  const PoiListTile({
    super.key,
    required this.poi,
    this.userLocation,
    this.onTap,
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
      subtitle: subtitleText.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitleText,
                style:
                    colorScheme.onSurfaceVariant.textTheme.textStyle.copyWith(
                  fontSize: 13,
                  fontWeight: AppFontWeight.regular.weight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          : null,
      trailing: trailing,
    );
  }
}
