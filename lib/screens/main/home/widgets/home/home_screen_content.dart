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
  bool _isTripSummaryShown = false;

  late final HomeSearchCoordinator _searchCoordinator;
  late final HomeRouteActions _routeActions;

  MapDisplayCubit get displayCubit => context.read<MapDisplayCubit>();
  RoutePreviewCubit get routePreviewCubit => context.read<RoutePreviewCubit>();
  NavigationBloc get navigationBloc => context.read<NavigationBloc>();

  @override
  void initState() {
    super.initState();
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

  // ─── Navigation State ────────────────────────────────────────

  NavigationState _prevNavState = const NavigationState();

  void _handleNavigationState(
    BuildContext context,
    NavigationState prev,
    NavigationState curr,
  ) {
    if (!_isTripSummaryShown &&
        prev.status != curr.status &&
        curr.tripSummary != null &&
        (curr.status == NavigationStatus.arrived ||
            curr.status == NavigationStatus.stopped)) {
      _isTripSummaryShown = true;
      HomeDialogCoordinator.showTripSummaryModal(
        context: context,
        summary: curr.tripSummary!,
        onDone: () {
          routePreviewCubit.clearRoute();
          navigationBloc.add(const ClearNavigation());
        },
        onDismissed: () => _isTripSummaryShown = false,
      );
    }
    if (prev.promptBatteryOptimizationOem !=
            curr.promptBatteryOptimizationOem &&
        curr.promptBatteryOptimizationOem != null) {
      HomeDialogCoordinator.showBatteryOptimizationPrompt(
        context: context,
        oemType: curr.promptBatteryOptimizationOem,
        navigationBloc: navigationBloc,
      );
    }
    if (prev.pendingResumeSession != curr.pendingResumeSession &&
        curr.pendingResumeSession != null) {
      HomeDialogCoordinator.showResumeSessionPrompt(
        context: context,
        session: curr.pendingResumeSession,
        navigationBloc: navigationBloc,
      );
    }
    if (prev.errorMessageKey != curr.errorMessageKey &&
        curr.errorMessageKey != null) {
      showError(tr(curr.errorMessageKey!));
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
        body: MultiBlocListener(
          listeners: [
            _buildMapDisplayListener(),
            _buildAppThemeListener(),
            _buildNavigationListener(),
            _buildViewportSearchListener(),
          ],
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
                        ..._buildExplorationOverlays(topPadding),
                      if (isRouteActive)
                        ..._buildRoutePreviewOverlays(
                            topPadding, routeState),
                      if (isNavigating)
                        ..._buildNavigationOverlays(topPadding),
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

  // ─── Bloc Listeners ──────────────────────────────────────────

  BlocListener _buildMapDisplayListener() {
    return BlocListener<MapDisplayCubit, MapDisplayState>(
      listenWhen: (previous, current) =>
          previous.selectedPoi != current.selectedPoi,
      listener: (context, state) {
        final poi = state.selectedPoi;
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
    );
  }

  BlocListener _buildAppThemeListener() {
    return BlocListener<AppCubit, AppState>(
      listenWhen: (prev, curr) =>
          prev.themeMode != curr.themeMode || prev.appStyle != curr.appStyle,
      listener: (context, appState) {
        displayCubit.updateMapTheme(isDarkMode: appState.isDarkMode);
      },
    );
  }

  BlocListener _buildNavigationListener() {
    return BlocListener<NavigationBloc, NavigationState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.tripSummary != curr.tripSummary ||
          prev.promptBatteryOptimizationOem !=
              curr.promptBatteryOptimizationOem ||
          prev.pendingResumeSession != curr.pendingResumeSession ||
          prev.errorMessageKey != curr.errorMessageKey,
      listener: (context, navState) {
        final prev = _prevNavState;
        _handleNavigationState(context, prev, navState);
        _prevNavState = navState;
      },
    );
  }

  BlocListener _buildViewportSearchListener() {
    return BlocListener<ViewportSearchBloc, ViewportSearchState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.pois != curr.pois ||
          prev.selectedCategory != curr.selectedCategory,
      listener: (context, viewportState) {
        final isAreaSearch = viewportState.isAreaSearch;
        final isCategorySearch =
            viewportState.selectedCategory != CategoryConstants.all;
        if (isAreaSearch || isCategorySearch) {
          final title = isCategorySearch
              ? tr(PoiCategoryHelper.getCategoryLocaleKey(
                  viewportState.selectedCategory))
              : viewportState.searchQuery;
          if (viewportState.status == ViewportSearchStatus.success) {
            final singlePoi = _searchCoordinator.handleSearchResults(
              viewportState.pois,
              title,
            );
            if (singlePoi != null) _handlePoiSelected(singlePoi);
          } else if (viewportState.status == ViewportSearchStatus.empty) {
            _searchCoordinator.handleSearchResults(const [], title);
          }
        }
      },
    );
  }

  // ─── Overlay Builders ────────────────────────────────────────

  List<Widget> _buildExplorationOverlays(double topPadding) {
    return [
      HomeHeaderSearchBar(
        topPadding: topPadding,
        onPoiSelected: _handlePoiSelected,
        onSearchResults: (pois, query) {
          final singlePoi =
              _searchCoordinator.handleSearchResults(pois, query);
          if (singlePoi != null) _handlePoiSelected(singlePoi);
        },
        onAreaSearch: _searchCoordinator.handleAreaSearch,
        onCategorySelected: _searchCoordinator.handleCategorySelected,
        onSearchOpened: _searchCoordinator.handleClearSearch,
        activeSearchText: _searchCoordinator.activeSearchText,
        onClearSearch: _searchCoordinator.handleClearSearch,
      ),
      HomeSearchAreaButton(
        topPadding: topPadding,
        isVisible: _searchCoordinator.showSearchThisArea &&
            (_searchCoordinator.activeSearchText != null &&
                _searchCoordinator.activeSearchText!.trim().isNotEmpty) &&
            _selectedMarkerPoi == null,
        onPressed: _searchCoordinator.handleSearchThisArea,
      ),
      HomeBottomOverlay(
        sheetController: _sheetController,
        selectedMarkerPoi: _selectedMarkerPoi,
        searchResults: _searchCoordinator.searchResults,
        searchQuery: _searchCoordinator.activeSearchText,
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
            _handlePoiSelected(poi);
          }
        },
        onSearchResultPoiTap: _handleSearchResultPoiTap,
        onCloseSearchResults: _searchCoordinator.handleCloseSearchResults,
        onClosePoiCard: _handleClosePoiCard,
        onDirections: () => _routeActions.handleDirections(_selectedMarkerPoi),
        onCustomRoute: _selectedMarkerPoi != null
            ? () => _routeActions.handleOpenCustomRouteDrawing(
                  context,
                  poi: _selectedMarkerPoi,
                )
            : null,
      ),
    ];
  }

  List<Widget> _buildRoutePreviewOverlays(
    double topPadding,
    RoutePreviewState routeState,
  ) {
    return [
      RouteDirectionHeader(
        topPadding: topPadding,
        onSelectOrigin: () => _routeActions.handleSelectEndpointForRoute(
          context,
          isOrigin: true,
          mounted: mounted,
        ),
        onSelectDestination: () => _routeActions.handleSelectEndpointForRoute(
          context,
          isOrigin: false,
          mounted: mounted,
        ),
        onClose: () {
          DLog.info('❌ [HomeScreen] Close Route Preview tapped');
          routePreviewCubit.clearRoute();
        },
      ),
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          top: false,
          child: RoutePreviewBottomSheet(
            onClose: () {
              DLog.info('❌ [HomeScreen] Close Route Preview tapped');
              routePreviewCubit.clearRoute();
            },
            onCustomRoute: routeState.destination != null
                ? () => _routeActions.handleOpenCustomRouteDrawing(
                      context,
                      destination: LatLng(
                        routeState.destination!.lat,
                        routeState.destination!.lon,
                      ),
                      destinationName: routeState.destinationName,
                    )
                : null,
            onStartNavigation: () {
              if (routeState.currentRoute != null &&
                  routeState.origin != null &&
                  routeState.destination != null) {
                DLog.info('🚀 [HomeScreen] Starting Turn-by-Turn Navigation');
                _isTripSummaryShown = false;
                navigationBloc.add(StartNavigation(
                  initialRoute: routeState.currentRoute!,
                  origin: routeState.origin!,
                  destination: routeState.destination!,
                  destinationName: routeState.destinationName,
                  profile: routeState.currentProfile,
                ));
              }
            },
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildNavigationOverlays(double topPadding) {
    return [
      NavigationTopPanel(topPadding: topPadding),
      Positioned(
        right: 16,
        bottom: 120 + MediaQuery.paddingOf(context).bottom,
        child: NavigationMapControls(
          displayCubit: displayCubit,
          onRecenter: () => displayCubit.locateMe(),
        ),
      ),
      NavigationBottomPanel(
        onStopNavigation: () {
          DLog.info('🛑 [HomeScreen] Stop Navigation tapped');
          navigationBloc.add(const StopNavigation());
        },
        onRecenter: () => displayCubit.locateMe(),
      ),
    ];
  }
}
