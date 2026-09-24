import 'package:flutter/material.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/home/widgets/widgets.dart';

/// Overlay chế độ khám phá bản đồ (thanh tìm kiếm, nút tìm vùng này, bottom sheet POI / kết quả tìm kiếm)
class HomeExplorationOverlay extends StatelessWidget {
  final double topPadding;
  final HomeSearchCoordinator searchCoordinator;
  final HomeRouteActions routeActions;
  final DraggableScrollableController sheetController;
  final PoiModel? selectedMarkerPoi;
  final ValueChanged<PoiModel> onPoiSelected;
  final ValueChanged<PoiModel> onSearchResultPoiTap;
  final VoidCallback onClosePoiCard;

  const HomeExplorationOverlay({
    super.key,
    required this.topPadding,
    required this.searchCoordinator,
    required this.routeActions,
    required this.sheetController,
    required this.selectedMarkerPoi,
    required this.onPoiSelected,
    required this.onSearchResultPoiTap,
    required this.onClosePoiCard,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        HomeHeaderSearchBar(
          topPadding: topPadding,
          onPoiSelected: onPoiSelected,
          onSearchResults: (pois, query) {
            final singlePoi =
                searchCoordinator.handleSearchResults(pois, query);
            if (singlePoi != null) onPoiSelected(singlePoi);
          },
          onAreaSearch: searchCoordinator.handleAreaSearch,
          onCategorySelected: searchCoordinator.handleCategorySelected,
          onSearchOpened: searchCoordinator.handleClearSearch,
          activeSearchText: searchCoordinator.activeSearchText,
          onClearSearch: searchCoordinator.handleClearSearch,
        ),
        HomeSearchAreaButton(
          topPadding: topPadding,
          isVisible: searchCoordinator.showSearchThisArea &&
              (searchCoordinator.activeSearchText != null &&
                  searchCoordinator.activeSearchText!.trim().isNotEmpty) &&
              selectedMarkerPoi == null,
          onPressed: searchCoordinator.handleSearchThisArea,
        ),
        HomeBottomOverlay(
          sheetController: sheetController,
          selectedMarkerPoi: selectedMarkerPoi,
          searchResults: searchCoordinator.searchResults,
          searchQuery: searchCoordinator.activeSearchText,
          onPlaceTap: (place) {
            if (place.latitude != null && place.longitude != null) {
              final poi = PoiModel(
                id: place.id?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
                name: place.name ?? '',
                nameAscii: '',
                lat: place.latitude!,
                lon: place.longitude!,
                category: place.category,
              );
              onPoiSelected(poi);
            }
          },
          onSearchResultPoiTap: onSearchResultPoiTap,
          onCloseSearchResults: searchCoordinator.handleCloseSearchResults,
          onClosePoiCard: onClosePoiCard,
          onDirections: () => routeActions.handleDirections(selectedMarkerPoi),
          onCustomRoute: selectedMarkerPoi != null
              ? () => routeActions.handleOpenCustomRouteDrawing(
                    context,
                    poi: selectedMarkerPoi,
                  )
              : null,
        ),
      ],
    );
  }
}
