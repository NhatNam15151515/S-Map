import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';
import 'package:s_map/screens/main/home/widgets/widgets.dart';

class HomeScreenContent extends StatefulWidget {
  const HomeScreenContent({super.key});

  @override
  State<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent> with AppMixin {
  final GlobalKey<HomeInteractiveMapLayerState> _mapLayerKey = GlobalKey();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  PoiModel? _selectedMarkerPoi;
  late final HomeNavigationDialogHandler _navDialogHandler;
  late final HomeSearchCoordinator _searchCoordinator;
  late final HomeRouteActions _routeActions;

  MapDisplayCubit get displayCubit => context.read<MapDisplayCubit>();
  RoutePreviewCubit get routePreviewCubit => context.read<RoutePreviewCubit>();
  NavigationBloc get navigationBloc => context.read<NavigationBloc>();

  @override
  void initState() {
    super.initState();
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
            _selectedMarkerPoi = null;
            _searchCoordinator.activeSearchText = null;
            _searchCoordinator.showSearchThisArea = false;
          });
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        navigationBloc.add(const CheckActiveSession());
        final isDark = context.read<AppCubit>().state.isDarkMode;
        displayCubit.updateMapTheme(isDarkMode: isDark);
        AppReposProvider.instance.routingRepos.isEngineReady();
      }
    });
  }

  @override
  void dispose() {
    _sheetController.dispose();
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

  // ─── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final controlsBottom = _selectedMarkerPoi != null
        ? 216.0
        : (_searchCoordinator.searchResults.isNotEmpty ||
                (_searchCoordinator.activeSearchText?.trim().isNotEmpty ??
                    false))
            ? 295.0
            : 175.0;

    return NavigationVoiceListener(
      child: Scaffold(
        body: HomeContentBlocListeners(
          searchCoordinator: _searchCoordinator,
          onSelectedPoiChanged: (poi) {
            if (!mounted) return;
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
            if (_selectedMarkerPoi != null && _selectedMarkerPoi!.isSamePoi(poi)) {
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
                  final isRouteActive = !isNavigating &&
                      (routeState.isLoading || routeState.isSuccess);
                  return Stack(
                    children: [
                      HomeInteractiveMapLayer(
                        key: _mapLayerKey,
                        onPoiTapped: (poi) {
                          if (!isNavigating) _handlePoiSelected(poi);
                        },
                        onSearchAreaVisibilityChanged: (show) {
                          if (mounted && !isRouteActive && !isNavigating) {
                            setState(() =>
                                _searchCoordinator.showSearchThisArea = show);
                          }
                        },
                      ),
                      if (!isNavigating)
                        HomeMapControls(
                          displayCubit: displayCubit,
                          bottom: controlsBottom,
                        ),
                      if (!isRouteActive && !isNavigating)
                        HomeExplorationOverlay(
                          topPadding: topPadding,
                          searchCoordinator: _searchCoordinator,
                          routeActions: _routeActions,
                          sheetController: _sheetController,
                          selectedMarkerPoi: _selectedMarkerPoi,
                          onPoiSelected: _handlePoiSelected,
                          onSearchResultPoiTap: _handleSearchResultPoiTap,
                          onClosePoiCard: _handleClosePoiCard,
                        ),
                      if (isRouteActive)
                        HomeRoutePreviewOverlay(
                          topPadding: topPadding,
                          routeState: routeState,
                          routeActions: _routeActions,
                          onStartNavigationTriggered: () {
                            _navDialogHandler.isTripSummaryShown = false;
                          },
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
          ),
        ),
      ),
    );
  }
}
