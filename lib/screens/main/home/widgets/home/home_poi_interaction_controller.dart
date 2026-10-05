import 'package:flutter/material.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/home/widgets/map/home_interactive_map_layer.dart';
import 'package:s_map/screens/main/home/widgets/drawing/home_route_drawing_controller.dart';
import 'package:s_map/screens/main/home/widgets/home/home_search_coordinator.dart';

/// Coordinates selected POIs between map markers and the Home search sheets.
class HomePoiInteractionController {
  HomePoiInteractionController({
    required MapDisplayCubit displayCubit,
    required GlobalKey<HomeInteractiveMapLayerState> mapLayerKey,
    required HomeSearchCoordinator searchCoordinator,
    required HomeRouteDrawingController drawingController,
    required VoidCallback onStateChanged,
  })  : _displayCubit = displayCubit,
        _mapLayerKey = mapLayerKey,
        _searchCoordinator = searchCoordinator,
        _drawingController = drawingController,
        _onStateChanged = onStateChanged;

  final MapDisplayCubit _displayCubit;
  final GlobalKey<HomeInteractiveMapLayerState> _mapLayerKey;
  final HomeSearchCoordinator _searchCoordinator;
  final HomeRouteDrawingController _drawingController;
  final VoidCallback _onStateChanged;

  PoiModel? selectedPoi;

  void handlePoiSelected(PoiModel poi) {
    _displayCubit.selectPoi(poi);
    selectedPoi = poi;
    _searchCoordinator.activeSearchText = poi.name;
    _searchCoordinator.showSearchThisArea = false;
    _onStateChanged();
  }

  void handleSearchResultPoiTap(PoiModel poi) {
    _displayCubit.selectPoi(poi);
    selectedPoi = poi;
    _searchCoordinator.showSearchThisArea = false;
    _onStateChanged();
  }

  void handleRouteSearchPoiTap(PoiModel poi) {
    _displayCubit.selectPoi(poi);
    selectedPoi = poi;
    _onStateChanged();
  }

  void handleDrawingPoiTap(PoiModel poi) {
    _displayCubit.selectPoi(poi);
    selectedPoi = poi;
    _onStateChanged();
  }

  void handleClosePoiCard() {
    _mapLayerKey.currentState?.clearSelectedPoiMarker();
    _displayCubit.clearSelectedPoi();
    selectedPoi = null;
    _searchCoordinator.showSearchThisArea = false;
    if (_searchCoordinator.searchResults.isEmpty) {
      _searchCoordinator.activeSearchText = null;
    }
    _onStateChanged();
    if (_searchCoordinator.searchResults.length > 1) {
      _mapLayerKey.currentState?.showSearchResults(
        _searchCoordinator.searchResults,
        fitBounds: false,
      );
    }
  }

  void closeActivePoiCard() {
    if (!_drawingController.isActive) {
      handleClosePoiCard();
      return;
    }
    _mapLayerKey.currentState?.clearSelectedPoiMarker(
      restoreSearchResults: _drawingController.searchResults != null,
    );
    _displayCubit.clearSelectedPoi();
    selectedPoi = null;
    _onStateChanged();
  }

  void handleMapPoiChanged(PoiModel? poi) {
    if (_drawingController.isActive ||
        _drawingController.searchResults != null) {
      if (poi == null) {
        if (selectedPoi != null) {
          selectedPoi = null;
          _onStateChanged();
        }
        return;
      }
      final routeResults = _drawingController.searchResults;
      if (_drawingController.isActive ||
          routeResults!.any((item) => item.isSamePoi(poi))) {
        if (selectedPoi?.isSamePoi(poi) != true) {
          selectedPoi = poi;
          _onStateChanged();
        }
        return;
      }
    }

    if (poi == null) {
      if (selectedPoi != null) {
        selectedPoi = null;
        _searchCoordinator.showSearchThisArea = false;
        _onStateChanged();
      }
      return;
    }
    final belongsToSearch =
        _searchCoordinator.searchResults.any((item) => item.isSamePoi(poi));
    if (!belongsToSearch) _mapLayerKey.currentState?.clearSearchResults();
    if (selectedPoi?.isSamePoi(poi) == true) return;
    selectedPoi = poi;
    _searchCoordinator.activeSearchText = poi.name;
    _searchCoordinator.showSearchThisArea = false;
    if (!belongsToSearch) _searchCoordinator.searchResults = [];
    _onStateChanged();
  }

  void handleMapPoiTap(PoiModel poi) {
    if (_drawingController.isActive) {
      handleDrawingPoiTap(poi);
    } else if (_drawingController.searchResults != null) {
      handleRouteSearchPoiTap(poi);
    } else {
      handlePoiSelected(poi);
    }
  }
}
