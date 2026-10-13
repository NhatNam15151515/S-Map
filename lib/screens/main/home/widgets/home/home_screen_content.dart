import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/di/app_repos_provider.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/home/widgets/widgets.dart';

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
  late final RouteDrawingBloc _routeDrawingBloc;
  late final HomeNavigationDialogHandler _navDialogHandler;
  late final HomeSearchCoordinator _searchCoordinator;
  late final HomeRouteActions _routeActions;
  late final HomeRouteDrawingController _drawingController;
  late final HomePoiInteractionController _poiController;
  late final HomeBackNavigationHandler _backHandler;

  MapDisplayCubit get displayCubit => context.read<MapDisplayCubit>();
  RoutePreviewCubit get routePreviewCubit => context.read<RoutePreviewCubit>();
  NavigationBloc get navigationBloc => context.read<NavigationBloc>();
  SavedRoutesCubit get savedRoutesCubit => context.read<SavedRoutesCubit>();

  @override
  void initState() {
    super.initState();
    _routeDrawingBloc = RouteDrawingBloc(
      routingRepository: AppReposProvider.instance.routingRepos,
      customRouteRepository: AppReposProvider.instance.customRouteRepos,
      poiRepository: AppReposProvider.instance.poiRepos,
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
    _drawingController = HomeRouteDrawingController(
      drawingBloc: _routeDrawingBloc,
      displayCubit: displayCubit,
      routePreviewCubit: routePreviewCubit,
      mapLayerKey: _mapLayerKey,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
      onSelectedPoiChanged: (poi) => _poiController.selectedPoi = poi,
    );
    _poiController = HomePoiInteractionController(
      displayCubit: displayCubit,
      mapLayerKey: _mapLayerKey,
      searchCoordinator: _searchCoordinator,
      drawingController: _drawingController,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
    );
    _backHandler = HomeBackNavigationHandler(
      mapLayerKey: _mapLayerKey,
      routePreviewCubit: routePreviewCubit,
      searchCoordinator: _searchCoordinator,
      drawingController: _drawingController,
      exitHint: tr(LocaleKeys.back_again_to_exit),
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
            _searchCoordinator.showSearchThisArea = false;
          });
        }
      },
      onClearForRouteDrawing: () {
        if (mounted) {
          setState(() {
            _searchCoordinator.searchResults = [];
            _drawingController.searchResults = null;
            _drawingController.searchQuery = null;
            _poiController.selectedPoi = null;
            _searchCoordinator.activeSearchText = null;
            _searchCoordinator.showSearchThisArea = false;
          });
        }
      },
      onSearchResults: _drawingController.showSearchResults,
      onOpenRouteDrawing: _drawingController.enter,
      onAppendDestination: _drawingController.addDestination,
      onAppendLocation: _drawingController.addDestinationLocation,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        navigationBloc.add(const CheckActiveSession());
        final isDark = context.read<AppCubit>().state.isDarkMode;
        displayCubit.updateMapTheme(isDarkMode: isDark);
        AppReposProvider.instance.routingRepos.isEngineReady();
        final initialPayload = widget.initialRoutePayload;
        if (initialPayload != null) {
          _openDrawingPayload(initialPayload);
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant HomeScreenContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final payload = widget.initialRoutePayload;
    if (payload == null || identical(payload, oldWidget.initialRoutePayload)) {
      return;
    }

    // Home is kept alive by StatefulShellRoute.indexedStack. Selecting a
    // saved drawing updates this widget's payload without calling initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openDrawingPayload(payload);
    });
  }

  void _openDrawingPayload(RouteDrawingPayload payload) {
    _searchCoordinator.searchResults = [];
    _searchCoordinator.activeSearchText = null;
    _searchCoordinator.showSearchThisArea = false;
    _poiController.selectedPoi = null;
    _drawingController.enter(payload);
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _drawingController.dispose();
    _routeDrawingBloc.close();
    super.dispose();
  }

  Future<void> _handleSystemBack() => _backHandler.handle(
        context,
        selectedPoi: _poiController.selectedPoi,
        onCloseExplorePoi: _poiController.handleClosePoiCard,
        onCloseDrawingPoi: _poiController.closeActivePoiCard,
      );

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final routeResults = _drawingController.searchResults;
    final controlsBottom = routeResults != null && _poiController.selectedPoi == null
        ? 295.0
        : _poiController.selectedPoi != null
            ? 216.0
            : (_searchCoordinator.searchResults.isNotEmpty ||
                    (_searchCoordinator.activeSearchText?.trim().isNotEmpty ??
                        false))
                ? 295.0
                : 175.0;

    return BlocProvider<RouteDrawingBloc>.value(
      value: _routeDrawingBloc,
      child: NavigationVoiceListener(
        child: PopScope(
          canPop: context.canPop() && !_drawingController.isActive,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) unawaited(_handleSystemBack());
          },
          child: Scaffold(
            body: HomeContentBlocListeners(
              searchCoordinator: _searchCoordinator,
              onSelectedPoiChanged: _poiController.handleMapPoiChanged,
              onThemeChanged: (isDark) =>
                  displayCubit.updateMapTheme(isDarkMode: isDark),
              onNavigationChanged: _navDialogHandler.handleNavigationState,
              onSinglePoiFound: _poiController.handlePoiSelected,
              child: BlocListener<RouteDrawingBloc, RouteDrawingState>(
                listenWhen: (previous, current) =>
                    previous.status != RouteDrawingStatus.saved &&
                    current.status == RouteDrawingStatus.saved,
                listener: (context, state) {
                  _drawingController.exit();
                  showSuccess(tr(LocaleKeys.route_drawing_ui_save_success));
                },
                child: HomeScreenContentView(
                  mapLayerKey: _mapLayerKey,
                  topPadding: topPadding,
                  controlsBottom: controlsBottom,
                  displayCubit: displayCubit,
                  savedRoutesCubit: savedRoutesCubit,
                  drawingBloc: _routeDrawingBloc,
                  searchCoordinator: _searchCoordinator,
                  routeActions: _routeActions,
                  sheetController: _sheetController,
                  routeDrawing: _drawingController.isActive,
                  crosshairActive: _drawingController.isCrosshairActive,
                  drawingToolsActive: _drawingController.isToolsActive,
                  selectedPoi: _poiController.selectedPoi,
                  routeSearchResults: routeResults,
                  routeSearchQuery: _drawingController.searchQuery,
                  onDrawingMapTap: _drawingController.handleMapTap,
                  onPoiTap: _poiController.handleMapPoiTap,
                  onSearchAreaVisibilityChanged: (show) {
                    if (mounted && !_drawingController.isActive) {
                      setState(() =>
                          _searchCoordinator.showSearchThisArea = show);
                    }
                  },
                  onReverseRoute: () {
                    HapticFeedback.mediumImpact();
                    _routeDrawingBloc.add(const RouteDrawingReverseRoute());
                  },
                  onToggleCrosshair: _drawingController.toggleCrosshair,
                  onPoiSelected: _poiController.handlePoiSelected,
                  onSearchResultPoiTap:
                      _poiController.handleSearchResultPoiTap,
                  onClosePoiCard: _poiController.closeActivePoiCard,
                  onAddPointAtCenter: _drawingController.addPointAtCenter,
                  onOpenSearch: () =>
                      _routeActions.handleOpenAddDestinationSearch(
                    context,
                    onSelectedPoi: _drawingController.addDestination,
                    onSelectedLocation:
                        _drawingController.addDestinationLocation,
                  ),
                  onExitDrawing: () =>
                      _backHandler.confirmExitDrawing(context),
                  onDrawingPoiTap: _poiController.handleDrawingPoiTap,
                  onAddDestination: _drawingController.addDestination,
                  onToggleDrawingMode: _drawingController.toggleTools,
                  onCloseSearchResults:
                      _drawingController.closeSearchResults,
                  onNavigatePressed: (drawingState) {
                    HomeRouteActions.startNavigationFromDrawnRoute(
                      context: context,
                      state: drawingState,
                    );
                    _drawingController.exit();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
