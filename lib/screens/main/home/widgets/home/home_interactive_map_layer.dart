import 'dart:async';
import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/home/widgets/widgets.dart';
import 'package:s_map/services/services.dart';

class HomeInteractiveMapLayer extends StatefulWidget {
  final ValueChanged<PoiModel> onPoiTapped;
  final ValueChanged<bool> onSearchAreaVisibilityChanged;
  final IVisitedPoiService? visitedPoiService;

  const HomeInteractiveMapLayer({
    super.key,
    required this.onPoiTapped,
    required this.onSearchAreaVisibilityChanged,
    this.visitedPoiService,
  });

  @override
  State<HomeInteractiveMapLayer> createState() =>
      HomeInteractiveMapLayerState();
}

class HomeInteractiveMapLayerState extends State<HomeInteractiveMapLayer>
    with AppMixin, MapLayerStyleLifecycle {
  MapLibreMapController? _mapController;
  final MapSymbolManager _symbolManager = MapSymbolManager();
  final MapCameraController _cameraController = MapCameraController();
  final MapRouteManager _routeManager = MapRouteManager();
  final MapRenderedFeatureResolver _featureResolver =
      MapRenderedFeatureResolver();
  int _navListenerGeneration = 0;
  int _routeMarkerSyncGeneration = 0;
  int _memoryMarkerSyncGeneration = 0;

  @override
  MapLibreMapController? get mapController => _mapController;
  @override
  MapSymbolManager get symbolManager => _symbolManager;
  @override
  MapRouteManager get routeManager => _routeManager;
  @override
  MapDisplayCubit get displayCubit => context.read<MapDisplayCubit>();
  @override
  ViewportSearchBloc get viewportBloc => context.read<ViewportSearchBloc>();
  @override
  RoutePreviewCubit get routePreviewCubit => context.read<RoutePreviewCubit>();

  bool get _hasActiveRouteOrNavigation {
    final previewState = routePreviewCubit.state;
    final navigationState = context.read<NavigationBloc>().state;
    return previewState.isLoading ||
        previewState.isSuccess ||
        navigationState.isNavigating;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (displayCubit.state.isNightMode != isDark) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && displayCubit.state.isNightMode != isDark) {
          displayCubit.updateThemeMode(isDark);
        }
      });
    }
  }

  // ─── Public API ──────────────────────────────────────────────

  void searchByCategory(String category) {
    _cameraController.executeInVisibleRegion(_mapController, (bounds) {
      if (mounted) {
        viewportBloc.add(
          ViewportCategoryFilterChanged(category, bounds: bounds),
        );
      }
    });
  }

  void searchThisArea({String? query}) {
    _cameraController.executeInVisibleRegion(_mapController, (bounds) {
      if (mounted) {
        viewportBloc.add(SearchThisAreaPressed(bounds, query: query));
      }
    });
  }

  void handleCameraAction(MapCameraAction action) {
    _cameraController.applyCameraAction(_mapController, action);
  }

  @override
  Future<void> setSelectedPoiMarker(PoiModel poi) {
    return _symbolManager.setSelectedPoiMarker(_mapController, poi);
  }

  void clearSelectedPoiMarker({bool restoreSearchResults = true}) {
    _symbolManager.clearSelectedPoiMarker(
      _mapController,
      restoreSearchResults: restoreSearchResults,
    );
  }

  Future<void> hideSearchResultMarkers() {
    return _symbolManager.hideSearchResultMarkers(_mapController);
  }

  Future<void> clearSearchResults() {
    return _symbolManager.clearSearchResults(_mapController);
  }

  void cacheSearchResultPois(List<PoiModel> pois) {
    _symbolManager.cacheSearchResultPois(pois);
  }

  void clearAll() {
    _symbolManager.clearAll(_mapController);
  }

  @override
  Future<void> refreshMemoryMarkers() async {
    final generation = ++_memoryMarkerSyncGeneration;
    final favorites = context.read<FavoritesCubit>().state.favorites;
    final visitedService =
        widget.visitedPoiService ?? VisitedPoiServiceImpl.instance;
    List<PoiModel> visited = const [];
    try {
      visited = await visitedService.getVisitedPois();
    } catch (e, stack) {
      DLog.warning('⚠️ Không thể tải POI đã đến để render marker: $e', stack);
    }
    if (!mounted || generation != _memoryMarkerSyncGeneration) return;

    await _symbolManager.renderMemoryPoisFromSources(
      _mapController,
      favorites: favorites,
      visited: visited,
    );
  }

  void showSearchResults(List<PoiModel> pois, {bool fitBounds = true}) {
    _symbolManager.showSearchResults(
      _mapController,
      pois,
      fitBounds: fitBounds,
    );
  }

  // ─── Map Callbacks ───────────────────────────────────────────

  void _onSymbolTapped(Symbol symbol) {
    if (_hasActiveRouteOrNavigation || !mounted) return;
    final poi = _symbolManager.getPoiBySymbolId(symbol.id);
    if (poi != null) widget.onPoiTapped(poi);
  }

  void _onFeatureTapped(
    Point<double> point,
    LatLng latLng,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (annotation is Symbol || _hasActiveRouteOrNavigation || !mounted) return;
    unawaited(_handleRenderedFeatureTap(point, latLng));
  }

  void _onCameraIdle() {
    _cameraController.handleCameraIdle(
      controller: _mapController,
      onInitialSearch: (bounds) {},
      onSearchAreaVisibilityChanged: (visible) {
        if (mounted) widget.onSearchAreaVisibilityChanged(visible);
      },
    );
  }

  Future<void> _onMapClick(Point<double> point, LatLng latLng) async {
    if (_hasActiveRouteOrNavigation) return;
    final poi =
        _symbolManager.getPoiAtLocation(latLng.latitude, latLng.longitude);
    if (poi != null && mounted) {
      widget.onPoiTapped(poi);
      return;
    }
    await _handleRenderedFeatureTap(point, latLng);
  }

  Future<void> _handleRenderedFeatureTap(
    Point<double> point,
    LatLng latLng,
  ) async {
    if (_hasActiveRouteOrNavigation || !mounted) return;
    final renderedPoi = await _featureResolver.resolvePoiAtTap(
      controller: _mapController,
      point: point,
      latLng: latLng,
    );
    if (renderedPoi != null && mounted) widget.onPoiTapped(renderedPoi);
  }

  void _onMapLongClick(Point<double> point, LatLng latLng) {
    DLog.info(
        '👆 [Map] Long press detected at: (${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)})');
    hideSearchResultMarkers();
    routePreviewCubit.previewRouteToCoordinate(latLng);
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    controller.onSymbolTapped.add(_onSymbolTapped);
    controller.onFeatureTapped.add(_onFeatureTapped);
    lastAppliedMapStyle = displayCubit.state.styleString;
    displayCubit.onMapCreated();
  }

  @override
  void dispose() {
    _mapController?.onSymbolTapped.remove(_onSymbolTapped);
    _mapController?.onFeatureTapped.remove(_onFeatureTapped);
    super.dispose();
  }

  // ─── Bloc State Handlers ─────────────────────────────────────

  Future<void> _onMapDisplayStateChanged(
    BuildContext context,
    MapDisplayState state,
  ) async {
    applyMapStyle(state.styleString);
    if (state.cameraAction != null) handleCameraAction(state.cameraAction!);
    if (state.selectedPoi != null) {
      await setSelectedPoiMarker(state.selectedPoi!);
    } else if (_symbolManager.selectedPoi != null) {
      clearSelectedPoiMarker();
    }
    if (state.status == MapDisplayStatus.error &&
        state.errorMessageKey != null) {
      showError(tr(state.errorMessageKey!));
    }
  }

  void _onViewportSearchStateChanged(
    BuildContext context,
    ViewportSearchState state,
  ) {
    if (_hasActiveRouteOrNavigation) return;
    if (state.status == ViewportSearchStatus.success) {
      if (state.selectedCategory == CategoryConstants.all) {
        if (state.pois.length == 1) {
          _symbolManager.cacheSearchResultPois(state.pois);
        } else {
          _symbolManager.renderPoiList(_mapController, state.pois);
        }
      }
    } else if (state.status == ViewportSearchStatus.empty) {
      if (state.selectedCategory == CategoryConstants.all) {
        _symbolManager.renderPoiList(_mapController, const []);
      }
    } else if (state.status == ViewportSearchStatus.error &&
        state.errorMessageKey != null) {
      showError(tr(state.errorMessageKey!));
    }
  }

  Future<void> _onRoutePreviewStateChanged(RoutePreviewState state) async {
    final syncGeneration = ++_routeMarkerSyncGeneration;
    if (state.isLoading || state.isSuccess) {
      await _symbolManager.hideSearchResultMarkers(_mapController);
      if (!mounted || syncGeneration != _routeMarkerSyncGeneration) return;
    }
    if (state.isSuccess && state.currentRoute != null) {
      await _routeManager.drawRoute(
        controller: _mapController,
        routeResult: state.currentRoute!,
        origin: state.origin!,
        destination: state.destination!,
        destinationName: state.destinationName,
        alternativeRoutes: state.alternativeRoutes,
        selectedRouteIndex: state.selectedRouteIndex,
      );
      if (!mounted || syncGeneration != _routeMarkerSyncGeneration) return;
      _routeManager.fitRouteBounds(
        controller: _mapController,
        routeResult: state.currentRoute!,
        origin: state.origin,
        destination: state.destination,
      );
    } else if (state.isInitial || state.isError) {
      await _routeManager.clearRoute(_mapController);
      if (!mounted || syncGeneration != _routeMarkerSyncGeneration) return;
      if (!_hasActiveRouteOrNavigation) {
        await _symbolManager.restoreSearchResultMarkers(_mapController);
      }
      if (state.isError && state.errorMessageKey != null) {
        showError(tr(state.errorMessageKey!));
      }
    }
  }

  Future<void> _onNavigationStateChanged(NavigationState navState) async {
    final gen = ++_navListenerGeneration;
    if (navState.isNavigating) {
      if (navState.currentRoute != null &&
          navState.currentRoute != renderedNavRoute &&
          navState.origin != null &&
          navState.destination != null) {
        await _symbolManager.hideSearchResultMarkers(_mapController);
        if (!mounted || gen != _navListenerGeneration) return;
        final isSuccess = await _routeManager.drawRoute(
          controller: _mapController,
          routeResult: navState.currentRoute!,
          origin: navState.origin!,
          destination: navState.destination!,
          destinationName: navState.destinationName,
        );
        if (!mounted || gen != _navListenerGeneration) return;
        if (isSuccess) renderedNavRoute = navState.currentRoute;
      }
      if (!mounted || gen != _navListenerGeneration) return;
      if (navState.currentLat != null && navState.currentLon != null) {
        if (displayCubit.state.isFollowingUser) {
          _cameraController.updateNavigationCamera(
            controller: _mapController,
            lat: navState.displayLat ?? navState.currentLat!,
            lon: navState.displayLon ?? navState.currentLon!,
            gpsHeading: navState.currentHeading,
            compassHeading: displayCubit.state.compassHeading,
            speedKmh: navState.currentSpeedKmh,
          );
        }
        if (navState.currentRoute != null &&
            navState.currentRoute == renderedNavRoute &&
            gen == _navListenerGeneration) {
          _routeManager.updateNavigationProgress(
            controller: _mapController,
            rawPoints: navState.currentRoute!.points,
            currentSegmentIndex: navState.currentSegmentIndex,
            currentLat: navState.displayLat ?? navState.currentLat,
            currentLon: navState.displayLon ?? navState.currentLon,
          );
        }
      }
    } else if (navState.status == NavigationStatus.stopped ||
        navState.status == NavigationStatus.initial) {
      renderedNavRoute = null;
      await _routeManager.clearRoute(_mapController);
      if (!mounted || gen != _navListenerGeneration) return;
      if (!_hasActiveRouteOrNavigation) {
        await _symbolManager.restoreSearchResultMarkers(_mapController);
      }
    } else if (navState.status == NavigationStatus.arrived) {
      await refreshMemoryMarkers();
    }
  }

  // ─── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MapLayerBlocListeners(
      onMapDisplayChanged: _onMapDisplayStateChanged,
      onViewportSearchChanged: _onViewportSearchStateChanged,
      onRoutePreviewChanged: _onRoutePreviewStateChanged,
      onNavigationChanged: _onNavigationStateChanged,
      onFavoritesChanged: () => unawaited(refreshMemoryMarkers()),
      child: BlocBuilder<MapDisplayCubit, MapDisplayState>(
        buildWhen: (prev, curr) =>
            prev.status != curr.status ||
            (prev.styleString != curr.styleString && _mapController == null),
        builder: (context, state) {
          return BlocBuilder<NavigationBloc, NavigationState>(
            buildWhen: (prev, curr) => prev.isNavigating != curr.isNavigating,
            builder: (context, navState) =>
                _buildMapViewStack(state, navState),
          );
        },
      ),
    );
  }

  Widget _buildMapViewStack(
    MapDisplayState state,
    NavigationState navState,
  ) {
    final isNavigating = navState.isNavigating;

    return Stack(
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerMove: (event) {
            if (isNavigating && displayCubit.state.isFollowingUser) {
              if (event.delta.distanceSquared > 4) {
                displayCubit.unfollowUser();
              }
            }
          },
          child: MapView(
            key: const Key('map_view_main'),
            styleString: state.styleString,
            nativeCompassEnabled: false,
            myLocationTrackingMode: isNavigating
                ? MyLocationTrackingMode.none
                : MyLocationTrackingMode.tracking,
            myLocationRenderMode: isNavigating
                ? MyLocationRenderMode.compass
                : MyLocationRenderMode.normal,
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: onStyleLoaded,
            onCameraTrackingDismissed: displayCubit.onCameraTrackingDismissed,
            onCameraMove: displayCubit.onCameraMove,
            onCameraIdle: _onCameraIdle,
            onMapClick: _onMapClick,
            onMapLongClick: _onMapLongClick,
          ),
        ),
        if (state.status == MapDisplayStatus.loading)
          const Positioned.fill(
            child: Center(child: CircularProgressIndicator()),
          ),
        if (state.status == MapDisplayStatus.error)
          MapErrorOverlay(
            errorMessage: state.errorMessageKey != null
                ? tr(state.errorMessageKey!)
                : tr(LocaleKeys.map_error_load),
            onRetry: displayCubit.locateMe,
          ),
      ],
    );
  }
}
