import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/poi_list_tile.dart';
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

    return DraggableScrollableSheet(
      controller: controller,
      initialChildSize: 0.45,
      minChildSize: 0.16,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.16, 0.45, 0.95],
      builder: (context, scrollController) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outline.withAlpha(50),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              // 1. Sticky Header dính trên đầu (luôn cố định khi cuộn)
              SliverPersistentHeader(
                pinned: true,
                delegate: _SearchResultsHeaderDelegate(
                  query: query,
                  count: pois.length,
                  onClose: onClose,
                  colorScheme: colorScheme,
                ),
              ),

              // 2. POI List with distance calculation or Empty State
              if (pois.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 36, horizontal: 20),
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
                          style: colorScheme.onSurfaceVariant.textTheme.textStyle
                              .copyWith(
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
                            child: PoiListTile(
                              poi: poi,
                              userLocation: userLocation,
                              onTap: () => onPoiTap?.call(poi),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 2,
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: colorScheme.outline.withAlpha(150),
                              ),
                            ),
                          );
                        },
                        childCount: pois.length,
                      ),
                    );
                  },
                ),

              // Đệm đáy nhẹ nhàng để không sát mép bo tròn
              const SliverToBoxAdapter(
                child: SizedBox(height: 16),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Header Delegate ghim cứng trên đỉnh của SearchResultsBottomSheet
class _SearchResultsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String? query;
  final int count;
  final VoidCallback? onClose;
  final ColorScheme colorScheme;

  _SearchResultsHeaderDelegate({
    this.query,
    required this.count,
    this.onClose,
    required this.colorScheme,
  });

  @override
  double get minExtent => 76.0;

  @override
  double get maxExtent => 76.0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: 76.0,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withAlpha(35),
            width: 0.8,
          ),
        ),
      ),
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
          const SizedBox(height: 8),

          // Header: Query title, count and Close button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
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
                            args: [count.toString()]),
                        style: colorScheme
                            .onSurfaceVariant.textTheme.captionStyle
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
                      backgroundColor: colorScheme
                          .surfaceContainerHighest
                          .withAlpha(120),
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(32, 32),
                    ),
                    tooltip: tr(LocaleKeys.cancel),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SearchResultsHeaderDelegate oldDelegate) {
    return oldDelegate.query != query ||
        oldDelegate.count != count ||
        oldDelegate.onClose != onClose ||
        oldDelegate.colorScheme != colorScheme;
  }
}
