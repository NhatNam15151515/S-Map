import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/home/widgets/widgets.dart';

/// Presentational composition of the Home map and its contextual overlays.
class HomeScreenContentView extends StatelessWidget {
  const HomeScreenContentView({
    super.key,
    required this.mapLayerKey,
    required this.topPadding,
    required this.controlsBottom,
    required this.displayCubit,
    required this.savedRoutesCubit,
    required this.drawingBloc,
    required this.searchCoordinator,
    required this.routeActions,
    required this.sheetController,
    required this.routeDrawing,
    required this.crosshairActive,
    required this.drawingToolsActive,
    required this.selectedPoi,
    required this.routeSearchResults,
    required this.routeSearchQuery,
    required this.onDrawingMapTap,
    required this.onPoiTap,
    required this.onSearchAreaVisibilityChanged,
    required this.onReverseRoute,
    required this.onToggleCrosshair,
    required this.onPoiSelected,
    required this.onSearchResultPoiTap,
    required this.onClosePoiCard,
    required this.onAddPointAtCenter,
    required this.onOpenSearch,
    required this.onExitDrawing,
    required this.onDrawingPoiTap,
    required this.onAddDestination,
    required this.onToggleDrawingMode,
    required this.onCloseSearchResults,
    required this.onNavigatePressed,
  });

  final GlobalKey<HomeInteractiveMapLayerState> mapLayerKey;
  final double topPadding;
  final double controlsBottom;
  final MapDisplayCubit displayCubit;
  final SavedRoutesCubit savedRoutesCubit;
  final RouteDrawingBloc drawingBloc;
  final HomeSearchCoordinator searchCoordinator;
  final HomeRouteActions routeActions;
  final DraggableScrollableController sheetController;
  final bool routeDrawing;
  final bool crosshairActive;
  final bool drawingToolsActive;
  final PoiModel? selectedPoi;
  final List<PoiModel>? routeSearchResults;
  final String? routeSearchQuery;
  final ValueChanged<LatLng> onDrawingMapTap;
  final ValueChanged<PoiModel> onPoiTap;
  final ValueChanged<bool> onSearchAreaVisibilityChanged;
  final VoidCallback onReverseRoute;
  final VoidCallback onToggleCrosshair;
  final ValueChanged<PoiModel> onPoiSelected;
  final ValueChanged<PoiModel> onSearchResultPoiTap;
  final VoidCallback onClosePoiCard;
  final VoidCallback onAddPointAtCenter;
  final VoidCallback onOpenSearch;
  final VoidCallback onExitDrawing;
  final ValueChanged<PoiModel> onDrawingPoiTap;
  final ValueChanged<PoiModel> onAddDestination;
  final VoidCallback onToggleDrawingMode;
  final VoidCallback onCloseSearchResults;
  final ValueChanged<RouteDrawingState> onNavigatePressed;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NavigationBloc, NavigationState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status || prev.isNavigating != curr.isNavigating,
      builder: (context, navState) {
        return BlocBuilder<RouteDrawingBloc, RouteDrawingState>(
          buildWhen: (prev, curr) =>
              prev.status != curr.status ||
              prev.points != curr.points ||
              prev.segments != curr.segments ||
              prev.fullPolyline != curr.fullPolyline ||
              prev.totalDistance != curr.totalDistance ||
              prev.totalTime != curr.totalTime ||
              prev.isStraightLineMode != curr.isStraightLineMode,
          builder: (context, drawingState) {
            final isNavigating = navState.isNavigating;
            return Stack(
              children: [
                HomeInteractiveMapLayer(
                  key: mapLayerKey,
                  allowPoiInteractionWhenRouteActive:
                      routeSearchResults != null,
                  isRouteSearchSheetOpen: routeDrawing &&
                      routeSearchResults != null &&
                      selectedPoi == null,
                  isRouteDrawingActive: routeDrawing,
                  isCrosshairActive: crosshairActive,
                  routeDrawingBloc: drawingBloc,
                  onDrawingMapTap: onDrawingMapTap,
                  onPoiTapped: (poi) {
                    if (!isNavigating) onPoiTap(poi);
                  },
                  onSearchAreaVisibilityChanged: onSearchAreaVisibilityChanged,
                ),
                if (!isNavigating)
                  HomeMapControls(
                    displayCubit: displayCubit,
                    bottom: controlsBottom,
                    isDrawingMode: routeDrawing && drawingToolsActive,
                    canReverse: routeDrawing &&
                        drawingState.points.length >= 2,
                    isCrosshairActive: crosshairActive,
                    onReverseRoute: onReverseRoute,
                    onToggleCrosshair: onToggleCrosshair,
                  ),
                if (!routeDrawing && !isNavigating)
                  HomeExplorationOverlay(
                    topPadding: topPadding,
                    searchCoordinator: searchCoordinator,
                    routeActions: routeActions,
                    sheetController: sheetController,
                    selectedMarkerPoi: selectedPoi,
                    onPoiSelected: onPoiSelected,
                    onSearchResultPoiTap: onSearchResultPoiTap,
                    onClosePoiCard: onClosePoiCard,
                  ),
                if (routeDrawing)
                  HomeDrawingOverlay(
                    topPadding: topPadding,
                    drawingState: drawingState,
                    drawingBloc: drawingBloc,
                    savedRoutesCubit: savedRoutesCubit,
                    isCrosshairActive: crosshairActive,
                    isDrawingMode: drawingToolsActive,
                    selectedMarkerPoi: selectedPoi,
                    searchResults: routeSearchResults,
                    searchQuery: routeSearchQuery,
                    onAddPointAtCenter: onAddPointAtCenter,
                    onOpenSearch: onOpenSearch,
                    onExit: onExitDrawing,
                    onDrawingPoiTap: onDrawingPoiTap,
                    onAddDestination: onAddDestination,
                    onToggleDrawingMode: onToggleDrawingMode,
                    onCloseSearchResults: onCloseSearchResults,
                    onClosePoiCard: onClosePoiCard,
                    onNavigatePressed: () => onNavigatePressed(drawingState),
                  ),
                if (isNavigating)
                  HomeNavigationOverlay(
                    topPadding: topPadding,
                    displayCubit: displayCubit,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
