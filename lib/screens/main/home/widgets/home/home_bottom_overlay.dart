import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/models/models.dart';

class HomeBottomOverlay extends StatelessWidget {
  final DraggableScrollableController sheetController;
  final PoiModel? selectedMarkerPoi;
  final List<PoiModel>? searchResults;
  final String? searchQuery;
  final ValueChanged<dynamic> onPlaceTap;
  final ValueChanged<PoiModel>? onSearchResultPoiTap;
  final VoidCallback? onCloseSearchResults;
  final VoidCallback onClosePoiCard;
  final VoidCallback onDirections;
  final VoidCallback? onCustomRoute;

  const HomeBottomOverlay({
    super.key,
    required this.sheetController,
    required this.selectedMarkerPoi,
    this.searchResults,
    this.searchQuery,
    required this.onPlaceTap,
    this.onSearchResultPoiTap,
    this.onCloseSearchResults,
    required this.onClosePoiCard,
    required this.onDirections,
    this.onCustomRoute,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Khi đang chọn một địa điểm cụ thể (từ sheet hoặc bấm vào marker): hiển thị Quick Card
    if (selectedMarkerPoi != null) {
      final bottomPadding = MediaQuery.paddingOf(context).bottom;
      return Positioned(
        left: 0,
        right: 0,
        bottom: kBottomNavigationBarHeight + bottomPadding + 4,
        child: BlocBuilder<MapDisplayCubit, MapDisplayState>(
          buildWhen: (prev, curr) =>
              prev.currentPosition != curr.currentPosition,
          builder: (context, mapDisplayState) {
            return PoiQuickCard(
              poi: selectedMarkerPoi!,
              userLocation: mapDisplayState.currentPosition,
              onClose: onClosePoiCard,
              onDirections: onDirections,
              onCustomRoute: onCustomRoute,
            );
          },
        ),
      );
    }

    // 2. Khi có danh sách kết quả tìm kiếm (hoặc đang active search/category): hiển thị Sheet danh sách kết quả
    if ((searchResults != null && searchResults!.isNotEmpty) ||
        (searchQuery != null && searchQuery!.trim().isNotEmpty)) {
      return SearchResultsBottomSheet(
        key: const ValueKey('search_results_bottom_sheet'),
        pois: searchResults ?? const [],
        query: searchQuery,
        onPoiTap: onSearchResultPoiTap,
        onClose: onCloseSearchResults,
      );
    }

    // 3. Mặc định: hiển thị Explore Bottom Sheet khám phá địa điểm
    return BlocBuilder<MapExploreCubit, MapExploreState>(
      builder: (context, exploreState) {
        return ExploreBottomSheet(
          key: const ValueKey('explore_bottom_sheet'),
          controller: sheetController,
          places: exploreState.places,
          isLoading: exploreState.isLoading,
          onPlaceTap: onPlaceTap,
        );
      },
    );
  }
}
