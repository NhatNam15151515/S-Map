import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

/// Bottom Sheet hiển thị danh sách tất cả các địa điểm trong kết quả tìm kiếm
class SearchResultsBottomSheet extends StatelessWidget {
  final DraggableScrollableController? controller;
  final List<PoiModel> pois;
  final String? query;
  final ValueChanged<PoiModel>? onPoiTap;
  final VoidCallback? onClose;

  const SearchResultsBottomSheet({
    super.key,
    this.controller,
    required this.pois,
    this.query,
    this.onPoiTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return DraggableScrollableSheet(
      controller: controller,
      initialChildSize: 0.35,
      minChildSize: 0.18,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.18, 0.35, 0.85],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border.all(
              color: colorScheme.outline.withAlpha(50),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 8),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.outline.withAlpha(120),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Header: Query title, count and Close button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  query != null && query!.trim().isNotEmpty
                                      ? query!
                                      : tr(LocaleKeys.search_results),
                                  style: colorScheme.onSurface.textTheme.subTitleStyle
                                      .copyWith(
                                    fontSize: 17,
                                    fontWeight: AppFontWeight.bold.weight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tr(LocaleKeys.poi_found_count,
                                      args: [pois.length.toString()]),
                                  style: colorScheme.onSurfaceVariant.textTheme.captionStyle
                                      .copyWith(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          if (onClose != null)
                            IconButton(
                              onPressed: onClose,
                              icon: Icon(
                                Icons.close_rounded,
                                color: colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest.withAlpha(120),
                                padding: const EdgeInsets.all(6),
                                minimumSize: const Size(32, 32),
                              ),
                              tooltip: tr(LocaleKeys.cancel),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      color: colorScheme.outline.withAlpha(40),
                    ),
                  ],
                ),
              ),

              // POI List with distance calculation or Empty State
              if (pois.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_off_rounded,
                          size: 40,
                          color: colorScheme.outline.withAlpha(120),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tr(LocaleKeys.no_search_results),
                          style: colorScheme.onSurfaceVariant.textTheme.textStyle.copyWith(
                            fontSize: 14,
                            fontWeight: AppFontWeight.medium.weight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                BlocBuilder<MapDisplayCubit, MapDisplayState>(
                  buildWhen: (prev, curr) =>
                      prev.currentPosition != curr.currentPosition,
                  builder: (context, mapState) {
                    final userLocation = mapState.currentPosition;

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final poi = pois[index];
                          return RepaintBoundary(
                            child: _buildPoiItem(
                              context: context,
                              poi: poi,
                              userLocation: userLocation,
                              onTap: () => onPoiTap?.call(poi),
                            ),
                          );
                        },
                        childCount: pois.length,
                      ),
                    );
                  },
                ),
              SliverToBoxAdapter(
                child: SizedBox(height: bottomPadding + 100),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPoiItem({
    required BuildContext context,
    required PoiModel poi,
    required LatLng? userLocation,
    VoidCallback? onTap,
  }) {
    final colorScheme = context.colorScheme;
    final icon = PoiCategoryHelper.getIcon(poi.category, subCategory: poi.subCategory);
    final iconColor = PoiCategoryHelper.getIconColor(poi.category, subCategory: poi.subCategory);
    final bgColor = PoiCategoryHelper.getBackgroundColor(poi.category, subCategory: poi.subCategory);
    final address = PoiCategoryHelper.formatAddress(poi);

    String subtitleText = address;
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Container(
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        poi.name,
                        style: colorScheme.onSurface.textTheme.textStyle.copyWith(
                          fontSize: 15,
                          fontWeight: AppFontWeight.semiBold.weight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitleText.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitleText,
                          style: colorScheme.onSurfaceVariant.textTheme.captionStyle
                              .copyWith(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: colorScheme.outline.withAlpha(150),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
