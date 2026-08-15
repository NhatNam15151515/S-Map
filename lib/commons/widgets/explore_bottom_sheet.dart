import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/commons/widgets/shimmers.dart';
import 'package:s_map/models/place_model.dart';

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
    return DraggableScrollableSheet(
      controller: controller,
      initialChildSize: 0.14,
      minChildSize: 0.14,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.14, 0.40, 0.85],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.12),
                blurRadius: 16,
                offset: Offset(0, -3),
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
                          color: AppColors.outlineVariant,
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
                                  tr('explore.title') == 'explore.title'
                                      ? 'Khám phá khu vực lân cận'
                                      : tr('explore.title'),
                                  style: AppColors.googleDarkText.textTheme.subTitleStyle.copyWith(
                                    fontSize: 17,
                                    fontWeight: AppFontWeight.bold.weight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tr('explore.subtitle') == 'explore.subtitle'
                                      ? 'Các địa điểm thịnh hành xung quanh bạn'
                                      : tr('explore.subtitle'),
                                  style: AppColors.onSurfaceVariant.textTheme.captionStyle,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.sMapLightTeal,
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
                            tr('explore.empty') == 'explore.empty'
                                ? 'Không tìm thấy địa điểm nào'
                                : tr('explore.empty'),
                            style: AppColors.onSurfaceVariant.textTheme.captionStyle.copyWith(fontSize: 14),
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
                          place: place,
                          onTap: () => onPlaceTap?.call(place),
                        ),
                      );
                    },
                    childCount: places!.length,
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 40),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceItem({
    required PlaceModel place,
    VoidCallback? onTap,
  }) {
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
                        style: AppColors.googleDarkText.textTheme.textStyle.copyWith(
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
