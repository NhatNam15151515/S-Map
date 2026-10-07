import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/home/widgets/home/home_poi_quick_card.dart';
import 'package:s_map/screens/main/home/widgets/home/home_search_results_sheet.dart';

class HomeBottomOverlay extends StatelessWidget {
  final DraggableScrollableController sheetController;
  final PoiModel? selectedMarkerPoi;
  final List<PoiModel>? searchResults;
  final String? searchQuery;
  final ValueChanged<dynamic> onPlaceTap;
  final ValueChanged<PoiModel>? onSearchResultPoiTap;
  final ValueChanged<PoiModel>? onAddDestination;
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
    this.onAddDestination,
    this.onCloseSearchResults,
    required this.onClosePoiCard,
    required this.onDirections,
    this.onCustomRoute,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Khi đang chọn một địa điểm cụ thể (từ sheet hoặc bấm vào marker): hiển thị Quick Card
    if (selectedMarkerPoi != null) {
      // final bottomPadding = MediaQuery.paddingOf(context).bottom;
      return Positioned(
        left: 0,
        right: 0,
        bottom: kBottomNavigationBarHeight + 12 /*+ bottomPadding*/,
        child: HomePoiQuickCard(
          poi: selectedMarkerPoi!,
          onClose: onClosePoiCard,
          onDirections: onDirections,
          onCustomRoute: onCustomRoute,
        ),
      );
    }

    // 2. Khi có danh sách kết quả tìm kiếm (hoặc đang active search/category): hiển thị Sheet danh sách kết quả
    if ((searchResults != null && searchResults!.isNotEmpty) ||
        (searchQuery != null && searchQuery!.trim().isNotEmpty)) {
      final hasDestinations =
          context.read<RoutePreviewCubit>().state.destination != null;

      return Padding(
        // Keep normal search results above MainScreen's persistent navigator,
        // matching the add-destination sheet in HomeDrawingOverlay.
        padding: EdgeInsets.only(
          bottom: kBottomNavigationBarHeight +
              MediaQuery.paddingOf(context).bottom +
              8,
        ),
        child: HomeSearchResultsSheet(
          key: const ValueKey('search_results_bottom_sheet'),
          pois: searchResults ?? const [],
          query: searchQuery,
          onPoiTap: onSearchResultPoiTap,
          onAddDestination: onAddDestination,
          hasExistingDestinations: hasDestinations,
          onClose: onCloseSearchResults,
        ),
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
