import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/routers/app_routes.dart';
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

  bool _showSearchThisArea = false;
  PoiModel? _selectedMarkerPoi;
  bool _isTripSummaryShown = false;
  String? _activeSearchText;

  MapDisplayCubit get displayCubit => context.read<MapDisplayCubit>();
  MapExploreCubit get exploreCubit => context.read<MapExploreCubit>();
  ViewportSearchBloc get viewportBloc => context.read<ViewportSearchBloc>();
  RoutePreviewCubit get routePreviewCubit => context.read<RoutePreviewCubit>();
  NavigationBloc get navigationBloc => context.read<NavigationBloc>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        navigationBloc.add(const CheckActiveSession());
        final isDark = context.read<AppCubit>().state.isDarkMode;
        displayCubit.updateMapTheme(isDarkMode: isDark);
      }
    });
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  void _handleCategorySelected(String? cat) {
    if (cat == null) return;
    exploreCubit.selectCategory(cat);
    _mapLayerKey.currentState?.searchByCategory(cat);
    setState(() {
      _activeSearchText = cat;
    });
  }

  void _handleSearchThisArea() {
    setState(() => _showSearchThisArea = false);
    _mapLayerKey.currentState?.searchThisArea(query: _activeSearchText);
  }

  void _handlePoiSelected(PoiModel poi) {
    displayCubit.selectPoi(poi);
    _mapLayerKey.currentState?.setSelectedPoiMarker(poi);
    setState(() {
      _selectedMarkerPoi = poi;
      _activeSearchText = poi.name;
      _showSearchThisArea = false;
    });
  }

  void _handleSearchResults(List<PoiModel> pois, String? query) {
    _mapLayerKey.currentState?.showSearchResults(pois);
    setState(() {
      _activeSearchText = query;
      if (pois.isNotEmpty) {
        _selectedMarkerPoi = pois.first;
      }
    });
  }

  void _handleOpenCustomRouteDrawing({
    PoiModel? poi,
    LatLng? destination,
    String? destinationName,
  }) {
    final myPos = displayCubit.state.currentPosition;
    final destLatLng =
        destination ?? (poi != null ? LatLng(poi.lat, poi.lon) : null);
    final name = destinationName ?? poi?.name;

    final payload = RouteDrawingPayload(
      initialOrigin: myPos,
      initialDestination: destLatLng,
      destinationName: name,
      destinationPoi: poi,
    );

    context.push(AppRoutes.routeDrawing, extra: payload);
  }

  void _handleDirections() {
    if (_selectedMarkerPoi != null) {
      final poi = _selectedMarkerPoi!;
      DLog.info(
          '🧭 [HomeScreen] "Chỉ đường" tapped for POI: "${poi.name}" (${poi.lat}, ${poi.lon})');
      _mapLayerKey.currentState?.clearSelectedPoiMarker();
      displayCubit.clearSelectedPoi();
      setState(() {
        _selectedMarkerPoi = null;
        _activeSearchText = null;
        _showSearchThisArea = false;
      });
      routePreviewCubit.previewRouteToPoi(poi);
    }
  }

  void _handleClearSearch() {
    _mapLayerKey.currentState?.clearAll();
    displayCubit.clearSelectedPoi();
    setState(() {
      _selectedMarkerPoi = null;
      _activeSearchText = null;
      _showSearchThisArea = false;
    });
  }

  void _showTripSummaryModal(TripSummary summary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => TripSummaryBottomSheet(
        summary: summary,
        onDone: () {
          modalContext.pop();
          routePreviewCubit.clearRoute();
          navigationBloc.add(const ClearNavigation());
        },
      ),
    ).whenComplete(() {
      _isTripSummaryShown = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: MultiBlocListener(
        listeners: [
          BlocListener<AppCubit, AppState>(
            listenWhen: (prev, curr) =>
                prev.themeMode != curr.themeMode ||
                prev.appStyle != curr.appStyle,
            listener: (context, appState) {
              displayCubit.updateMapTheme(isDarkMode: appState.isDarkMode);
            },
          ),
          BlocListener<NavigationBloc, NavigationState>(
            listenWhen: (prev, curr) =>
                !_isTripSummaryShown &&
                prev.status != curr.status &&
                curr.tripSummary != null &&
                (curr.status == NavigationStatus.arrived ||
                    curr.status == NavigationStatus.stopped),
            listener: (context, navState) {
              if (navState.tripSummary != null && !_isTripSummaryShown) {
                _isTripSummaryShown = true;
                _showTripSummaryModal(navState.tripSummary!);
              }
            },
          ),
          BlocListener<NavigationBloc, NavigationState>(
            listenWhen: (prev, curr) =>
                prev.promptBatteryOptimizationOem !=
                    curr.promptBatteryOptimizationOem &&
                curr.promptBatteryOptimizationOem != null,
            listener: (context, navState) async {
              final oemType = navState.promptBatteryOptimizationOem;
              if (oemType != null) {
                final result = await BatteryOptimizationDialog.show(
                  context,
                  oemType: oemType,
                  onAllow: () {
                    navigationBloc.add(const AllowBatteryOptimization());
                  },
                  onSkip: () {
                    navigationBloc.add(const SkipBatteryOptimization());
                  },
                );
                if (result == null && context.mounted) {
                  navigationBloc.add(const DismissBatteryOptimizationPrompt());
                }
              }
            },
          ),
          BlocListener<NavigationBloc, NavigationState>(
            listenWhen: (prev, curr) =>
                prev.pendingResumeSession != curr.pendingResumeSession &&
                curr.pendingResumeSession != null,
            listener: (context, navState) async {
              final session = navState.pendingResumeSession;
              if (session != null) {
                final result = await ResumeTripDialog.show(
                  context,
                  snapshot: session,
                  onResume: () {
                    navigationBloc.add(ResumeNavigation(session));
                  },
                  onDiscard: () {
                    navigationBloc.add(const DiscardActiveSession());
                  },
                );
                if (result == null && context.mounted) {
                  navigationBloc.add(const DiscardActiveSession());
                }
              }
            },
          ),
          BlocListener<NavigationBloc, NavigationState>(
            listenWhen: (prev, curr) =>
                prev.errorMessageKey != curr.errorMessageKey &&
                curr.errorMessageKey != null,
            listener: (context, navState) {
              final errKey = navState.errorMessageKey;
              if (errKey != null) {
                showError(tr(errKey));
              }
            },
          ),
        ],
        child: BlocBuilder<NavigationBloc, NavigationState>(
          buildWhen: (prev, curr) =>
              prev.status != curr.status ||
              prev.isNavigating != curr.isNavigating,
          builder: (context, navState) {
            final isNavigating = navState.isNavigating;

            return BlocBuilder<RoutePreviewCubit, RoutePreviewState>(
              builder: (context, routeState) {
                final isRouteActive = !isNavigating &&
                    (routeState.isLoading || routeState.isSuccess);

                return Stack(
                  children: [
                    // 1. Interactive Map Layer
                    HomeInteractiveMapLayer(
                      key: _mapLayerKey,
                      onPoiTapped: (poi) {
                        if (!isNavigating) {
                          _handlePoiSelected(poi);
                        }
                      },
                      onSearchAreaVisibilityChanged: (show) {
                        if (mounted && !isRouteActive && !isNavigating) {
                          setState(() => _showSearchThisArea = show);
                        }
                      },
                    ),

                    // 2. Right Map Controls (ẩn khi đang điều hướng)
                    if (!isNavigating)
                      HomeMapControls(displayCubit: displayCubit),

                    // 3. Normal Map Exploration Elements (Ẩn khi đang xem route hoặc dẫn đường)
                    if (!isRouteActive && !isNavigating) ...[
                      HomeHeaderSearchBar(
                        topPadding: topPadding,
                        onPoiSelected: _handlePoiSelected,
                        onSearchResults: _handleSearchResults,
                        onCategorySelected: _handleCategorySelected,
                        activeSearchText: _activeSearchText,
                        onClearSearch: _handleClearSearch,
                      ),

                      // 4. Floating "Search This Area" Button
                      HomeSearchAreaButton(
                        topPadding: topPadding,
                        isVisible: _showSearchThisArea &&
                            (_activeSearchText != null &&
                                _activeSearchText!.trim().isNotEmpty) &&
                            _selectedMarkerPoi == null,
                        onPressed: _handleSearchThisArea,
                      ),

                      // 5. Dynamic Bottom Overlay (Explore Sheet / POI Quick Card)
                      HomeBottomOverlay(
                        sheetController: _sheetController,
                        selectedMarkerPoi: _selectedMarkerPoi,
                        onPlaceTap: (place) {
                          if (place.latitude != null &&
                              place.longitude != null) {
                            final poi = PoiModel(
                              id: place.id?.hashCode ??
                                  DateTime.now().millisecondsSinceEpoch,
                              name: place.name ?? '',
                              nameAscii: '',
                              lat: place.latitude!,
                              lon: place.longitude!,
                              category: place.category,
                            );
                            _handlePoiSelected(poi);
                          }
                        },
                        onClosePoiCard: () {
                          _mapLayerKey.currentState?.clearSelectedPoiMarker();
                          displayCubit.clearSelectedPoi();
                          setState(() {
                            _selectedMarkerPoi = null;
                            _showSearchThisArea = false;
                          });
                        },
                        onDirections: _handleDirections,
                        onCustomRoute: _selectedMarkerPoi != null
                            ? () => _handleOpenCustomRouteDrawing(
                                  poi: _selectedMarkerPoi,
                                )
                            : null,
                      ),
                    ],

                    // 6. Route Preview Bottom Sheet (Hiển thị khi Route đang xem trước)
                    if (isRouteActive)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          top: false,
                          child: RoutePreviewBottomSheet(
                            onClose: () {
                              DLog.info(
                                  '❌ [HomeScreen] Close Route Preview tapped');
                              routePreviewCubit.clearRoute();
                            },
                            onCustomRoute: routeState.destination != null
                                ? () => _handleOpenCustomRouteDrawing(
                                      destination: LatLng(
                                        routeState.destination!.lat,
                                        routeState.destination!.lon,
                                      ),
                                      destinationName:
                                          routeState.destinationName,
                                    )
                                : null,
                            onStartNavigation: () {
                              if (routeState.currentRoute != null &&
                                  routeState.origin != null &&
                                  routeState.destination != null) {
                                DLog.info(
                                    '🚀 [HomeScreen] Starting Turn-by-Turn Navigation');
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

                    // 7. Active Navigation Panels (Top Turn-by-turn Banner & Bottom Speedometer/ETA Bar)
                    if (isNavigating) ...[
                      NavigationTopPanel(topPadding: topPadding),
                      NavigationBottomPanel(
                        onStopNavigation: () {
                          DLog.info('🛑 [HomeScreen] Stop Navigation tapped');
                          navigationBloc.add(const StopNavigation());
                        },
                      ),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
