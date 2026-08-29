import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

class ExploreBottomSheet extends StatelessWidget {
  final DraggableScrollableController controller;
  final List<PlaceModel>? places;
  final bool isLoading;
  final ValueChanged<PlaceModel>? onPlaceTap;

  const ExploreBottomSheet({
    super.key,
    required this.controller,
    this.places,
    this.isLoading = false,
    this.onPlaceTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final style = AppStyle.of(context);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return DraggableScrollableSheet(
      controller: controller,
      initialChildSize: 0.20,
      minChildSize: 0.20,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.20, 0.50, 0.85],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceContainer : AppColors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: isDark
                ? Border.all(
                    color: AppColors.darkOutline.withAlpha(60), width: 0.5)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 80 : 25),
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
                          color: isDark
                              ? AppColors.darkOutline
                              : AppColors.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr(LocaleKeys.explore_title),
                                  style: style.blackTextColor.textTheme.subTitleStyle
                                      .copyWith(
                                    fontSize: 17,
                                    fontWeight: AppFontWeight.bold.weight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tr(LocaleKeys.explore_subtitle),
                                  style: AppColors
                                      .onSurfaceVariant.textTheme.captionStyle,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.sMapTeal.withAlpha(40)
                                  : AppColors.sMapLightTeal,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.explore_rounded,
                              color: AppColors.sMapTeal,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Content Body
              if (isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: DefaultListingShimmer(),
                  ),
                )
              else if (places == null || places!.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_off_rounded,
                            size: 40,
                            color: AppColors.onSurfaceVariant.withAlpha(120),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            tr(LocaleKeys.explore_empty),
                            style: AppColors
                                .onSurfaceVariant.textTheme.captionStyle
                                .copyWith(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final place = places![index];
                      return RepaintBoundary(
                        child: _buildPlaceItem(
                          context: context,
                          place: place,
                          onTap: () => onPlaceTap?.call(place),
                        ),
                      );
                    },
                    childCount: places!.length,
                  ),
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

  Widget _buildPlaceItem({
    required BuildContext context,
    required PlaceModel place,
    VoidCallback? onTap,
  }) {
    final style = AppStyle.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.sMapTeal.withAlpha(18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.sMapTeal,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.title,
                        style: style.blackTextColor.textTheme.textStyle.copyWith(
                          fontSize: 15,
                          fontWeight: AppFontWeight.semiBold.weight,
                        ),
                      ),
                      if (place.subtitle != null && place.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          place.subtitle!,
                          style: AppColors.onSurfaceVariant.textTheme.captionStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      if (place.rating != null || place.category != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (place.rating != null) ...[
                              Text(
                                "${place.rating} ★${place.reviewCount != null ? ' (${place.reviewCount})' : ''}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.googleYellow,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (place.category != null)
                              Text(
                                "• ${place.category}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.directions_rounded,
                  color: AppColors.googleBlue,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
