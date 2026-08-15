import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/models/place_model.dart';

class HomeExploreBottomSheet extends StatelessWidget {
  final DraggableScrollableController controller;
  final List<PlaceModel>? places;
  final bool isLoading;
  final ValueChanged<PlaceModel>? onPlaceTap;

  const HomeExploreBottomSheet({
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
                color: Color.fromRGBO(0, 0, 0, 0.15),
                blurRadius: 15,
                offset: Offset(0, -2),
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
                                  "Khám phá khu vực lân cận",
                                  style: AppColors.googleDarkText.textTheme.subTitleStyle.copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Các địa điểm thịnh hành xung quanh bạn",
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

                    // Shortcuts
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _buildShortcut(Icons.directions_rounded, "Chỉ đường", AppColors.googleBlue, () {}),
                          _buildShortcut(Icons.bookmark_border_rounded, "Đã lưu", AppColors.sMapTeal, () {}),
                          _buildShortcut(Icons.share_location_rounded, "Chia sẻ", AppColors.googleGreen, () {}),
                          _buildShortcut(Icons.add_location_alt_rounded, "Thêm vị trí", AppColors.constructionZone, () {}),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Popular Places Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        "Địa điểm nổi bật",
                        style: AppColors.googleDarkText.textTheme.subTitleStyle.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),

              // Slivers for Dynamic Places
              if (isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.sMapTeal,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                )
              else if (places == null || places!.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_off_rounded,
                            size: 40,
                            color: AppColors.outlineVariant,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Chưa có địa điểm nào trong khu vực này",
                            style: AppColors.onSurfaceVariant.textTheme.captionStyle.copyWith(
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
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
                      return _buildPlaceItem(
                        place: place,
                        onTap: () => onPlaceTap?.call(place),
                      );
                    },
                    childCount: places!.length,
                  ),
                ),

              // Bottom spacing for floating navigation bar
              const SliverToBoxAdapter(
                child: SizedBox(height: 110),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShortcut(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.googleDarkText,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
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
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.googleDarkText,
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
