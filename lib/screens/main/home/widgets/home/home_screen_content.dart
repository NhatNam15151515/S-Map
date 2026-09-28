import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';
import 'package:s_map/screens/main/home/widgets/widgets.dart';
import 'package:s_map/screens/route_drawing/widgets/widgets.dart';

class HomeScreenContent extends StatefulWidget {
  final RouteDrawingPayload? initialRoutePayload;

  const HomeScreenContent({super.key, this.initialRoutePayload});

  @override
  State<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent> with AppMixin {
  final GlobalKey<HomeInteractiveMapLayerState> _mapLayerKey = GlobalKey();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  PoiModel? _selectedMarkerPoi;
  List<PoiModel>? _routeSearchResults;
  String? _routeSearchQuery;
  bool _isRouteDrawingMode = false;
  late final RouteDrawingSession _routeDrawingSession;
  late final HomeNavigationDialogHandler _navDialogHandler;
  late final HomeSearchCoordinator _searchCoordinator;
  late final HomeRouteActions _routeActions;

  MapDisplayCubit get displayCubit => context.read<MapDisplayCubit>();
  RoutePreviewCubit get routePreviewCubit => context.read<RoutePreviewCubit>();
  NavigationBloc get navigationBloc => context.read<NavigationBloc>();
  SavedRoutesCubit get savedRoutesCubit => context.read<SavedRoutesCubit>();
  RouteDrawingBloc get routeDrawingBloc => _routeDrawingSession.drawingBloc;
  RouteDrawingBloc get _routeDrawingBloc => routeDrawingBloc;
  RouteDrawingDestinationController get routeDrawingDestinationController =>
      _routeDrawingSession.destinationController;
  RouteDrawingDestinationController get _routeDrawingDestinationController =>
      routeDrawingDestinationController;

  @override
  void initState() {
    super.initState();
    _routeDrawingSession = RouteDrawingSession(
      mapDisplayCubit: displayCubit,
      savedRoutesCubit: savedRoutesCubit,
      onStateChanged: _onRouteDrawingControllerChanged,
    );
    _navDialogHandler = HomeNavigationDialogHandler(
      context: context,
      routePreviewCubit: routePreviewCubit,
      navigationBloc: navigationBloc,
      onError: showError,
    );
    _searchCoordinator = HomeSearchCoordinator(
      mapLayerKey: _mapLayerKey,
      displayCubit: displayCubit,
      exploreCubit: context.read<MapExploreCubit>(),
      viewportBloc: context.read<ViewportSearchBloc>(),
      onStateChanged: () {
        if (mounted) setState(() {});
      },
    );
    _routeActions = HomeRouteActions(
      mapLayerKey: _mapLayerKey,
      displayCubit: displayCubit,
      routePreviewCubit: routePreviewCubit,
      onStateChanged: () {
        if (mounted) {
          setState(() {
            _selectedMarkerPoi = null;
            _searchCoordinator.showSearchThisArea = false;
          });
        }
      },
      onClearForRouteDrawing: () {
        if (mounted) {
          setState(() {
            _searchCoordinator.searchResults = [];
            _routeSearchResults = null;
            _routeSearchQuery = null;
            _selectedMarkerPoi = null;
            _searchCoordinator.activeSearchText = null;
            _searchCoordinator.showSearchThisArea = false;
          });
        }
      },
      onSearchResults: _showRouteSearchResults,
      onOpenRouteDrawing: _enterRouteDrawing,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        navigationBloc.add(const CheckActiveSession());
        final isDark = context.read<AppCubit>().state.isDarkMode;
        displayCubit.updateMapTheme(isDarkMode: isDark);
        AppReposProvider.instance.routingRepos.isEngineReady();
        final initialPayload = widget.initialRoutePayload;
        if (initialPayload != null) {
          _enterRouteDrawing(initialPayload);
        }
      }
    });
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _routeDrawingSession.dispose();
    super.dispose();
  }

  // ─── POI Selection ───────────────────────────────────────────

  void _handlePoiSelected(PoiModel poi) {
    displayCubit.selectPoi(poi);
    setState(() {
      _selectedMarkerPoi = poi;
      _searchCoordinator.activeSearchText = poi.name;
      _searchCoordinator.showSearchThisArea = false;
    });
  }

  void _handleSearchResultPoiTap(PoiModel poi) {
    displayCubit.selectPoi(poi);
    setState(() {
      _selectedMarkerPoi = poi;
      _searchCoordinator.showSearchThisArea = false;
    });
  }

  void _handleClosePoiCard() {
    _mapLayerKey.currentState?.clearSelectedPoiMarker();
    displayCubit.clearSelectedPoi();
    setState(() {
      _selectedMarkerPoi = null;
      _searchCoordinator.showSearchThisArea = false;
      if (_searchCoordinator.searchResults.isEmpty) {
        _searchCoordinator.activeSearchText = null;
      }
    });
    if (_searchCoordinator.searchResults.length > 1) {
      _mapLayerKey.currentState?.showSearchResults(
        _searchCoordinator.searchResults,
        fitBounds: false,
      );
    }
  }

  void _showRouteSearchResults(List<PoiModel> pois, String? query) {
    _mapLayerKey.currentState?.clearSelectedPoiMarker(
      restoreSearchResults: false,
    );
    _mapLayerKey.currentState?.showSearchResults(pois, fitBounds: true);
    displayCubit.clearSelectedPoi();
    if (!mounted) return;
    setState(() {
      _routeSearchResults = pois;
      _routeSearchQuery = query;
      _selectedMarkerPoi = null;
    });
  }

  void _closeRouteSearchResults() {
    _mapLayerKey.currentState?.clearSearchResults();
    _mapLayerKey.currentState?.clearSelectedPoiMarker(
      restoreSearchResults: false,
    );
    displayCubit.clearSelectedPoi();
    if (!mounted) return;
    setState(() {
      _routeSearchResults = null;
      _routeSearchQuery = null;
      _selectedMarkerPoi = null;
    });
  }

  void _handleRouteSearchPoiTap(PoiModel poi) {
    displayCubit.selectPoi(poi);
    if (!mounted) return;
    setState(() => _selectedMarkerPoi = poi);
  }

  void _closeRouteSearchPoi() {
    _mapLayerKey.currentState?.clearSelectedPoiMarker(
      restoreSearchResults: true,
    );
    displayCubit.clearSelectedPoi();
    if (!mounted) return;
    setState(() => _selectedMarkerPoi = null);
  }

  void _onRouteDrawingControllerChanged() {
    if (mounted) setState(() {});
  }

  void _enterRouteDrawing(RouteDrawingPayload payload) {
    _mapLayerKey.currentState?.clearAll();
    _mapLayerKey.currentState?.clearDrawingRoute();
    displayCubit.clearSelectedPoi();
    routePreviewCubit.clearRoute();

    if (mounted) {
      setState(() {
        _isRouteDrawingMode = true;
        _routeSearchResults = null;
        _routeSearchQuery = null;
        _selectedMarkerPoi = null;
        _searchCoordinator.searchResults = [];
        _searchCoordinator.activeSearchText = null;
        _searchCoordinator.showSearchThisArea = false;
      });
    }

    _routeDrawingSession.reset();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isRouteDrawingMode) return;
      _routeDrawingSession.initialize(
        payload: payload,
        isMounted: () => mounted && _isRouteDrawingMode,
        setState: _onRouteDrawingControllerChanged,
      );
    });
  }

  void _exitRouteDrawing() {
    _mapLayerKey.currentState?.clearDrawingRoute();
    _mapLayerKey.currentState?.clearSearchResults();
    displayCubit.clearSelectedPoi();
    routePreviewCubit.clearRoute();
    _routeDrawingSession.reset();
    if (!mounted) return;
    setState(() {
      _isRouteDrawingMode = false;
      _routeSearchResults = null;
      _routeSearchQuery = null;
      _selectedMarkerPoi = null;
    });
  }

  void _addDrawingDestination(PoiModel poi) {
    if (!_isRouteDrawingMode) return;
    _routeDrawingSession.addDestination(LatLng(poi.lat, poi.lon));
    _mapLayerKey.currentState?.clearSelectedPoiMarker(
      restoreSearchResults: false,
    );
    _mapLayerKey.currentState?.clearSearchResults();
    displayCubit.clearSelectedPoi();
    if (!mounted) return;
    setState(() {
      _routeSearchResults = null;
      _routeSearchQuery = null;
      _selectedMarkerPoi = null;
    });
  }

  Future<void> _openDrawingDestinationSearch() {
    return _routeActions.handleOpenAddDestinationSearch(
      context,
      onSelectedPoi: _addDrawingDestination,
    );
  }

  void _handleDrawingPoiTap(PoiModel poi) {
    displayCubit.selectPoi(poi);
    if (!mounted) return;
    setState(() => _selectedMarkerPoi = poi);
  }

  void _handleDrawingMapTap(LatLng tappedLatLng) {
    _routeDrawingSession.handleMapTap(tappedLatLng);
  }

  void _handleDrawingAddPointAtCenter() {
    final center = _mapLayerKey.currentState?.currentCenter ??
        displayCubit.state.center;
    _routeDrawingSession.handleAddPointAtCenter(center);
  }

  // ─── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final controlsBottom = _routeSearchResults != null &&
            _selectedMarkerPoi == null
        ? 295.0
        : _selectedMarkerPoi != null
        ? 216.0
        : (_searchCoordinator.searchResults.isNotEmpty ||
                (_searchCoordinator.activeSearchText?.trim().isNotEmpty ??
                    false))
            ? 295.0
            : 175.0;

    return BlocProvider<RouteDrawingBloc>.value(
      value: _routeDrawingBloc,
      child: NavigationVoiceListener(
        child: Scaffold(
          body: HomeContentBlocListeners(
            searchCoordinator: _searchCoordinator,
            onSelectedPoiChanged: (poi) {
              if (!mounted) return;
              if (_isRouteDrawingMode) {
                if (poi == null) {
                  if (_selectedMarkerPoi != null) {
                    setState(() => _selectedMarkerPoi = null);
                  }
                } else if (_selectedMarkerPoi?.isSamePoi(poi) != true) {
                  setState(() => _selectedMarkerPoi = poi);
                }
                return;
              }
              if (_routeSearchResults != null) {
                if (poi == null) {
                  if (_selectedMarkerPoi != null) {
                    setState(() => _selectedMarkerPoi = null);
                  }
                  return;
                }
                final belongsToRouteSearch = _routeSearchResults!
                    .any((item) => item.isSamePoi(poi));
                if (belongsToRouteSearch) {
                  if (_selectedMarkerPoi?.isSamePoi(poi) != true) {
                    setState(() => _selectedMarkerPoi = poi);
                  }
                  return;
                }
              }
              if (poi == null) {
                if (_selectedMarkerPoi != null) {
                  setState(() {
                    _selectedMarkerPoi = null;
                    _searchCoordinator.showSearchThisArea = false;
                  });
                }
                return;
              }
              final belongsToCurrentSearch = _searchCoordinator.searchResults
                  .any((item) => item.isSamePoi(poi));
              if (!belongsToCurrentSearch) {
                _mapLayerKey.currentState?.clearSearchResults();
              }
              if (_selectedMarkerPoi != null &&
                  _selectedMarkerPoi!.isSamePoi(poi)) {
                return;
              }
              setState(() {
                _selectedMarkerPoi = poi;
                _searchCoordinator.activeSearchText = poi.name;
                _searchCoordinator.showSearchThisArea = false;
                if (!belongsToCurrentSearch) {
                  _searchCoordinator.searchResults = [];
                }
              });
            },
            onThemeChanged: (isDark) =>
                displayCubit.updateMapTheme(isDarkMode: isDark),
            onNavigationChanged: _navDialogHandler.handleNavigationState,
            onSinglePoiFound: _handlePoiSelected,
            child: BlocBuilder<NavigationBloc, NavigationState>(
              buildWhen: (prev, curr) =>
                  prev.status != curr.status ||
                  prev.isNavigating != curr.isNavigating,
              builder: (context, navState) {
                final isNavigating = navState.isNavigating;
                return BlocBuilder<RoutePreviewCubit, RoutePreviewState>(
                  buildWhen: (prev, curr) {
                    final prevActive = prev.isLoading || prev.isSuccess;
                    final currActive = curr.isLoading || curr.isSuccess;
                    if (prevActive != currActive) return true;
                    if (currActive) {
                      return prev.status != curr.status ||
                          prev.currentRoute != curr.currentRoute ||
                          prev.origin != curr.origin ||
                          prev.destination != curr.destination ||
                          prev.destinationName != curr.destinationName ||
                          prev.currentProfile != curr.currentProfile;
                    }
                    return false;
                  },
                  builder: (context, routeState) {
                    return BlocBuilder<RouteDrawingBloc, RouteDrawingState>(
                      buildWhen: (prev, curr) =>
                          prev.status != curr.status ||
                          prev.points != curr.points ||
                          prev.segments != curr.segments ||
                          prev.fullPolyline != curr.fullPolyline ||
                          prev.totalDistance != curr.totalDistance ||
                          prev.totalTime != curr.totalTime ||
                          prev.canUndo != curr.canUndo ||
                          prev.canRedo != curr.canRedo ||
                          prev.isStraightLineMode != curr.isStraightLineMode,
                      builder: (context, drawingState) {
                        final isRouteDrawing = _isRouteDrawingMode;
                        final isRouteActive = !isNavigating &&
                            !isRouteDrawing &&
                            (routeState.isLoading || routeState.isSuccess);
                        return Stack(
                          children: [
                            HomeInteractiveMapLayer(
                              key: _mapLayerKey,
                              allowPoiInteractionWhenRouteActive:
                                  _routeSearchResults != null,
                              isRouteDrawingActive: isRouteDrawing,
                              routeDrawingBloc: _routeDrawingBloc,
                              drawingMarkerDestination:
                                  _routeDrawingDestinationController
                                      .markerDestination,
                              onDrawingMapTap: _handleDrawingMapTap,
                              onPoiTapped: (poi) {
                                if (isNavigating) return;
                                if (isRouteDrawing) {
                                  _handleDrawingPoiTap(poi);
                                } else if (_routeSearchResults != null) {
                                  _handleRouteSearchPoiTap(poi);
                                } else {
                                  _handlePoiSelected(poi);
                                }
                              },
                              onSearchAreaVisibilityChanged: (show) {
                                if (mounted &&
                                    !isRouteActive &&
                                    !isRouteDrawing &&
                                    !isNavigating) {
                                  setState(() => _searchCoordinator
                                      .showSearchThisArea = show);
                                }
                              },
                            ),
                            if (!isNavigating && !isRouteDrawing)
                              HomeMapControls(
                                displayCubit: displayCubit,
                                bottom: controlsBottom,
                              ),
                            if (!isRouteActive &&
                                !isRouteDrawing &&
                                !isNavigating)
                              HomeExplorationOverlay(
                                topPadding: topPadding,
                                searchCoordinator: _searchCoordinator,
                                routeActions: _routeActions,
                                sheetController: _sheetController,
                                selectedMarkerPoi: _selectedMarkerPoi,
                                onPoiSelected: _handlePoiSelected,
                                onSearchResultPoiTap:
                                    _handleSearchResultPoiTap,
                                onClosePoiCard: _handleClosePoiCard,
                              ),
                            if (isRouteActive)
                              HomeRoutePreviewOverlay(
                                topPadding: topPadding,
                                routeState: routeState,
                                routeActions: _routeActions,
                                searchResults: _routeSearchResults,
                                searchQuery: _routeSearchQuery,
                                selectedSearchPoi: _routeSearchResults != null
                                    ? _selectedMarkerPoi
                                    : null,
                                onSearchResultPoiTap:
                                    _handleRouteSearchPoiTap,
                                onAddDestination: (poi) => _routeActions
                                    .handleAddDestination(context, poi),
                                onCloseSearchResults: _closeRouteSearchResults,
                                onCloseSearchPoi: _closeRouteSearchPoi,
                                onStartNavigationTriggered: () {
                                  _navDialogHandler.isTripSummaryShown = false;
                                },
                              ),
                            if (isRouteDrawing)
                              RouteDrawingWorkspaceOverlay(
                                topPadding: topPadding,
                                drawingState: drawingState,
                                destinationController:
                                    _routeDrawingDestinationController,
                                drawingBloc: _routeDrawingBloc,
                                mapDisplayCubit: displayCubit,
                                searchResults: _routeSearchResults,
                                searchQuery: _routeSearchQuery,
                                selectedPoi: _selectedMarkerPoi,
                                onOpenSearch: _openDrawingDestinationSearch,
                                currentCenter: () =>
                                    _mapLayerKey.currentState?.currentCenter,
                                onExit: _exitRouteDrawing,
                                onSave: () =>
                                    RouteDrawingActionCoordinator.showSaveRouteDialog(
                                  context: context,
                                  drawingBloc: _routeDrawingBloc,
                                ),
                                onNavigate: () {
                                  RouteDrawingActionCoordinator
                                      .startNavigationFromDrawnRoute(
                                    context: context,
                                    state: drawingState,
                                  );
                                  _exitRouteDrawing();
                                },
                                onShowSavedRoutes: () =>
                                    RouteDrawingActionCoordinator
                                        .showSavedRoutesSheet(
                                  context: context,
                                  drawingBloc: _routeDrawingBloc,
                                  savedRoutesCubit: savedRoutesCubit,
                                ),
                                onPoiTap: _handleDrawingPoiTap,
                                onAddDestination: _addDrawingDestination,
                                onCloseSearch: _closeRouteSearchResults,
                                onClosePoi: _closeRouteSearchPoi,
                                onAddPointAtCenter:
                                    _handleDrawingAddPointAtCenter,
                                onControllerChanged:
                                    _onRouteDrawingControllerChanged,
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
              },
            ),
          ),
        ),
      ),
    );
  }
}
