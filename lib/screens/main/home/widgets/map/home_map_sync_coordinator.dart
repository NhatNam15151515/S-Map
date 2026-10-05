import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/utils/map_camera_controller.dart';
import 'package:s_map/commons/utils/map_route_manager.dart';
import 'package:s_map/commons/utils/map_symbol_manager.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';

/// Điều phối đồng bộ các trạng thái Bloc (RoutePreview, Navigation, ViewportSearch, MapDisplay)
/// với MapController, MapSymbolManager, MapRouteManager và MapCameraController
class HomeMapSyncCoordinator {
  final MapLibreMapController? Function() getMapController;
  final MapSymbolManager symbolManager;
  final MapRouteManager routeManager;
  final MapCameraController cameraController;
  final MapDisplayCubit displayCubit;
  final void Function(String) onApplyMapStyle;
  final void Function(MapCameraAction) onCameraAction;
  final Future<void> Function(PoiModel) onSetSelectedPoiMarker;
  final void Function() onClearSelectedPoiMarker;
  final void Function(String) onError;
  final Future<void> Function() onRefreshMemoryMarkers;
  final bool Function() hasActiveRouteOrNavigation;
  final bool Function() isMounted;
  final RouteResult? Function() getRenderedNavRoute;
  final void Function(RouteResult?) setRenderedNavRoute;

  int _navListenerGeneration = 0;
  int _routeMarkerSyncGeneration = 0;

  HomeMapSyncCoordinator({
    required this.getMapController,
    required this.symbolManager,
    required this.routeManager,
    required this.cameraController,
    required this.displayCubit,
    required this.onApplyMapStyle,
    required this.onCameraAction,
    required this.onSetSelectedPoiMarker,
    required this.onClearSelectedPoiMarker,
    required this.onError,
    required this.onRefreshMemoryMarkers,
    required this.hasActiveRouteOrNavigation,
    required this.isMounted,
    required this.getRenderedNavRoute,
    required this.setRenderedNavRoute,
  });

  Future<void> onMapDisplayStateChanged(
    BuildContext context,
    MapDisplayState state,
  ) async {
    onApplyMapStyle(state.styleString);
    if (state.cameraAction != null) onCameraAction(state.cameraAction!);
    if (state.selectedPoi != null) {
      await onSetSelectedPoiMarker(state.selectedPoi!);
    } else if (symbolManager.selectedPoi != null) {
      onClearSelectedPoiMarker();
    }
    if (state.status == MapDisplayStatus.error &&
        state.errorMessageKey != null) {
      onError(tr(state.errorMessageKey!));
    }
  }

  void onViewportSearchStateChanged(
    BuildContext context,
    ViewportSearchState state,
  ) {
    if (hasActiveRouteOrNavigation()) return;
    final mapController = getMapController();
    if (state.status == ViewportSearchStatus.success) {
      if (state.selectedCategory == CategoryConstants.all) {
        if (state.pois.length == 1) {
          symbolManager.cacheSearchResultPois(state.pois);
        } else {
          symbolManager.renderPoiList(mapController, state.pois);
        }
      }
    } else if (state.status == ViewportSearchStatus.empty) {
      if (state.selectedCategory == CategoryConstants.all) {
        symbolManager.renderPoiList(mapController, const []);
      }
    } else if (state.status == ViewportSearchStatus.error &&
        state.errorMessageKey != null) {
      onError(tr(state.errorMessageKey!));
    }
  }

  Future<void> onRoutePreviewStateChanged(RoutePreviewState state) async {
    final mapController = getMapController();
    final syncGeneration = ++_routeMarkerSyncGeneration;
    if (state.isLoading || state.isSuccess) {
      await symbolManager.hideSearchResultMarkers(mapController);
      if (!isMounted() || syncGeneration != _routeMarkerSyncGeneration) return;
    }
    if (state.isSuccess && state.currentRoute != null) {
      await routeManager.drawRoute(
        controller: mapController,
        routeResult: state.currentRoute!,
        origin: state.origin!,
        destination: state.destination!,
        destinationName: state.destinationName,
        alternativeRoutes: state.alternativeRoutes,
        selectedRouteIndex: state.selectedRouteIndex,
      );
      if (!isMounted() || syncGeneration != _routeMarkerSyncGeneration) return;
      routeManager.fitRouteBounds(
        controller: mapController,
        routeResult: state.currentRoute!,
        origin: state.origin,
        destination: state.destination,
      );
    } else if (state.isInitial || state.isError) {
      await routeManager.clearRoute(mapController);
      if (!isMounted() || syncGeneration != _routeMarkerSyncGeneration) return;
      if (!hasActiveRouteOrNavigation()) {
        await symbolManager.restoreSearchResultMarkers(mapController);
      }
      if (state.isError && state.errorMessageKey != null) {
        onError(tr(state.errorMessageKey!));
      }
    }
  }

  Future<void> onNavigationStateChanged(NavigationState navState) async {
    final mapController = getMapController();
    final gen = ++_navListenerGeneration;
    if (navState.isNavigating) {
      if (navState.currentRoute != null &&
          navState.currentRoute != getRenderedNavRoute() &&
          navState.origin != null &&
          navState.destination != null) {
        await symbolManager.hideSearchResultMarkers(mapController);
        if (!isMounted() || gen != _navListenerGeneration) return;
        final isSuccess = await routeManager.drawRoute(
          controller: mapController,
          routeResult: navState.currentRoute!,
          origin: navState.origin!,
          destination: navState.destination!,
          destinationName: navState.destinationName,
        );
        if (!isMounted() || gen != _navListenerGeneration) return;
        if (isSuccess) setRenderedNavRoute(navState.currentRoute);
      }
      if (!isMounted() || gen != _navListenerGeneration) return;
      if (navState.currentLat != null && navState.currentLon != null) {
        if (displayCubit.state.isFollowingUser) {
          cameraController.updateNavigationCamera(
            controller: mapController,
            lat: navState.displayLat ?? navState.currentLat!,
            lon: navState.displayLon ?? navState.currentLon!,
            gpsHeading: navState.currentHeading,
            compassHeading: displayCubit.state.compassHeading,
            speedKmh: navState.currentSpeedKmh,
          );
        }
        if (navState.currentRoute != null &&
            navState.currentRoute == getRenderedNavRoute() &&
            gen == _navListenerGeneration) {
          routeManager.updateNavigationProgress(
            controller: mapController,
            rawPoints: navState.currentRoute!.points,
            currentSegmentIndex: navState.currentSegmentIndex,
            currentLat: navState.displayLat ?? navState.currentLat,
            currentLon: navState.displayLon ?? navState.currentLon,
          );
        }
      }
    } else if (navState.status == NavigationStatus.stopped ||
        navState.status == NavigationStatus.initial) {
      setRenderedNavRoute(null);
      await routeManager.clearRoute(mapController);
      if (!isMounted() || gen != _navListenerGeneration) return;
      if (!hasActiveRouteOrNavigation()) {
        await symbolManager.restoreSearchResultMarkers(mapController);
      }
    } else if (navState.status == NavigationStatus.arrived) {
      await onRefreshMemoryMarkers();
    }
  }
}
