import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';
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
  List<PoiModel> _searchResults = [];
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
        // Pre-warm Routing engine ngầm để khi bấm Chỉ đường không bị delay/not ready
        AppReposProvider.instance.routingRepos.isEngineReady();
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
    if (_activeSearchText != null &&
        exploreCubit.state.selectedCategory == cat) {
      _handleClearSearch();
      return;
    }
    final categoryTitle = tr(PoiCategoryHelper.getCategoryLocaleKey(cat));
    exploreCubit.selectCategory(cat);
    _startAreaSearch(category: cat, label: categoryTitle);
  }

  void _handleAreaSearch(SearchResultPayload payload) {
    final category = payload.searchCategory?.trim().toLowerCase();
    final normalizedCategory = category == null || category.isEmpty
        ? CategoryConstants.all
        : category;
    final query = payload.submittedQuery?.trim();
    final label = normalizedCategory == CategoryConstants.all
        ? query
        : tr(PoiCategoryHelper.getCategoryLocaleKey(normalizedCategory));

    exploreCubit.selectCategory(normalizedCategory);
    _startAreaSearch(
      category: normalizedCategory == CategoryConstants.all
          ? null
          : normalizedCategory,
      query: normalizedCategory == CategoryConstants.all ? query : null,
      center: payload.searchCenter,
      label: label,
    );
  }

  void _startAreaSearch({
    String? category,
    String? query,
    LatLng? center,
    String? label,
  }) {
    final mapState = displayCubit.state;
    final searchCenter = center ??
        mapState.currentPosition ??
        mapState.center ??
        MapConstants.defaultLocation;

    _mapLayerKey.currentState?.clearAll();
    displayCubit.clearSelectedPoi();
    viewportBloc.add(
      ProgressiveAreaSearch(
        center: searchCenter,
        category: category,
        query: query,
      ),
    );
    setState(() {
      _activeSearchText = label;
      _searchResults = [];
      _selectedMarkerPoi = null;
      _showSearchThisArea = false;
    });
  }

  void _handleSearchThisArea() {
    // Đây là một truy vấn mới: bỏ marker và snapshot cũ ngay lập tức để
    // không trộn kết quả khu vực trước với kết quả sắp trả về.
    _mapLayerKey.currentState?.clearAll();
    displayCubit.clearSelectedPoi();
    setState(() {
      _showSearchThisArea = false;
      _searchResults = [];
      _selectedMarkerPoi = null;
    });
    final isCategorySearch =
        exploreCubit.state.selectedCategory != CategoryConstants.all;
    _mapLayerKey.currentState?.searchThisArea(
      query: isCategorySearch ? null : _activeSearchText,
    );
  }

  void _handlePoiSelected(PoiModel poi) {
    displayCubit.selectPoi(poi);
    setState(() {
      _selectedMarkerPoi = poi;
      _activeSearchText = poi.name;
      _showSearchThisArea = false;
    });
  }

  void _handleSearchResultPoiTap(PoiModel poi) {
    displayCubit.selectPoi(poi);
    setState(() {
      _selectedMarkerPoi = poi;
      _showSearchThisArea = false;
    });
  }

  void _handleSearchResults(
    List<PoiModel> pois,
    String? query,
  ) {
    if (pois.isEmpty) {
      _mapLayerKey.currentState?.clearAll();
      displayCubit.clearSelectedPoi();
      setState(() {
        _searchResults = [];
        _activeSearchText = query;
        _selectedMarkerPoi = null;
        _showSearchThisArea = false;
      });
      return;
    }
    if (pois.length == 1) {
      setState(() {
        _searchResults = pois;
      });
      _handlePoiSelected(pois.first);
      // Category search một kết quả không đi qua nhánh render list của
      // ViewportSearchBloc. Vẫn cache POI này trong MapSymbolManager để
      // phiên route có thể restore đúng snapshot nếu cần.
      _mapLayerKey.currentState?.cacheSearchResultPois(pois);
      return;
    }
    _mapLayerKey.currentState?.showSearchResults(
      pois,
      // Nếu có nhiều kết quả, camera phải mở rộng theo toàn bộ tập kết quả.
      // Đây là trường hợp text search có kết quả ngoài vùng bias zoom 13.
      // Với đúng một kết quả, _handlePoiSelected vẫn animate thẳng tới POI.
      fitBounds: true,
    );
    setState(() {
      _searchResults = pois;
      _activeSearchText = query;
      _selectedMarkerPoi = null; // Hiển thị danh sách tất cả các điểm trong bottom sheet
      _showSearchThisArea = false;
    });
  }

  void _handleOpenCustomRouteDrawing({
    PoiModel? poi,
    LatLng? destination,
    String? destinationName,
  }) {
    final mapState = displayCubit.state;
    final myPos = mapState.hasRealLocation ? mapState.currentPosition : null;
    final destLatLng =
        destination ?? (poi != null ? LatLng(poi.lat, poi.lon) : null);
    final name = destinationName ?? poi?.name;

    final payload = RouteDrawingPayload(
      initialOrigin: myPos,
      initialDestination: destLatLng,
      destinationName: name,
      destinationPoi: poi,
    );

    // Custom route là một workflow mới, không dùng lại search context cũ.
    // Clear trước khi rời Home để khi quay lại không còn snapshot marker
    // cũ chờ restore nhầm vào bản đồ.
    _mapLayerKey.currentState?.clearAll();
    displayCubit.clearSelectedPoi();
    final hasActiveRoutePreview = routePreviewCubit.state.isLoading ||
        routePreviewCubit.state.isSuccess;
    if (hasActiveRoutePreview) {
      routePreviewCubit.clearRoute();
    }
    if (mounted) {
      setState(() {
        _searchResults = [];
        _selectedMarkerPoi = null;
        _activeSearchText = null;
        _showSearchThisArea = false;
      });
    }

    context.push(AppRoutes.routeDrawing, extra: payload);
  }

  void _handleDirections() {
    if (_selectedMarkerPoi != null) {
      final poi = _selectedMarkerPoi!;
      DLog.info(
          '🧭 [HomeScreen] "Chỉ đường" tapped for POI: "${poi.name}" (${poi.lat}, ${poi.lon})');
      // Ẩn ngay các red marker còn lại trong lúc chờ GPS/route response;
      // RoutePreview listener sẽ giữ trạng thái này và restore khi đóng.
      _mapLayerKey.currentState?.hideSearchResultMarkers();
      // Route preview sẽ ẩn toàn bộ search markers nhưng giữ list cũ để
      // render lại khi đóng route. Không để clear quick card tự render list
      // trong lúc route đang được khởi tạo.
      _mapLayerKey.currentState?.clearSelectedPoiMarker(
        restoreSearchResults: false,
      );
      displayCubit.clearSelectedPoi();
      setState(() {
        _selectedMarkerPoi = null;
        _showSearchThisArea = false;
      });
      routePreviewCubit.previewRouteToPoi(poi);
    }
  }

  Future<void> _handleSelectOriginForRoute() async {
    final mapState = displayCubit.state;
    final searchCenter = mapState.currentPosition ?? mapState.center;
    final result = await context.push<dynamic>(
      AppRoutes.search,
      extra: searchCenter,
    );
    if (!mounted || result == null) return;

    final routeState = routePreviewCubit.state;
    final currentDest = routeState.destination;
    if (currentDest == null) return;

    if (result is SearchResultPayload && result.isLocation) {
      final pos = result.searchCenter ?? mapState.currentPosition;
      if (pos != null) {
        routePreviewCubit.previewRouteBetweenPoints(
          origin: RoutePoint(lat: pos.latitude, lon: pos.longitude),
          destination: currentDest,
          originName: null,
          destinationName: routeState.destinationName,
          profile: routeState.profile,
        );
      }
    } else if (result is SearchResultPayload && result.isSingle) {
      final poi = result.selectedPoi!;
      routePreviewCubit.previewRouteBetweenPoints(
        origin: RoutePoint(lat: poi.lat, lon: poi.lon),
        destination: currentDest,
        originName: poi.name,
        destinationName: routeState.destinationName,
        profile: routeState.profile,
      );
    } else if (result is PoiModel) {
      routePreviewCubit.previewRouteBetweenPoints(
        origin: RoutePoint(lat: result.lat, lon: result.lon),
        destination: currentDest,
        originName: result.name,
        destinationName: routeState.destinationName,
        profile: routeState.profile,
      );
    }
  }

  Future<void> _handleSelectDestinationForRoute() async {
    final mapState = displayCubit.state;
    final searchCenter = mapState.currentPosition ?? mapState.center;
    final result = await context.push<dynamic>(
      AppRoutes.search,
      extra: searchCenter,
    );
    if (!mounted || result == null) return;

    final routeState = routePreviewCubit.state;
    final currentOrigin = routeState.origin;
    if (currentOrigin == null) return;

    if (result is SearchResultPayload && result.isLocation) {
      final pos = result.searchCenter ?? mapState.currentPosition;
      if (pos != null) {
        routePreviewCubit.previewRouteBetweenPoints(
          origin: currentOrigin,
          destination: RoutePoint(lat: pos.latitude, lon: pos.longitude),
          originName: routeState.originName,
          destinationName: null,
          profile: routeState.profile,
        );
      }
    } else if (result is SearchResultPayload && result.isSingle) {
      final poi = result.selectedPoi!;
      routePreviewCubit.previewRouteBetweenPoints(
        origin: currentOrigin,
        destination: RoutePoint(lat: poi.lat, lon: poi.lon),
        originName: routeState.originName,
        destinationName: poi.name,
        profile: routeState.profile,
      );
    } else if (result is PoiModel) {
      routePreviewCubit.previewRouteBetweenPoints(
        origin: currentOrigin,
        destination: RoutePoint(lat: result.lat, lon: result.lon),
        originName: routeState.originName,
        destinationName: result.name,
        profile: routeState.profile,
      );
    }
  }

  void _handleClosePoiCard() {
    _mapLayerKey.currentState?.clearSelectedPoiMarker();
    displayCubit.clearSelectedPoi();
    setState(() {
      _selectedMarkerPoi = null;
      _showSearchThisArea = false;
      if (_searchResults.isEmpty) {
        _activeSearchText = null;
      }
    });
    // Nếu trước đó đang có danh sách tìm kiếm nhiều điểm, fit lại bounds bao quanh
    if (_searchResults.length > 1) {
      _mapLayerKey.currentState?.showSearchResults(
        _searchResults,
        fitBounds: false,
      );
    }
  }

  void _handleCloseSearchResults() {
    _handleClearSearch();
  }

  void _handleClearSearch() {
    _mapLayerKey.currentState?.clearAll();
    displayCubit.clearSelectedPoi();
    exploreCubit.selectCategory(CategoryConstants.all);
    viewportBloc.add(const ClearViewportSearch());
    setState(() {
      _searchResults = [];
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
    final controlsBottom = _selectedMarkerPoi != null
        ? 216.0
        : (_searchResults.isNotEmpty ||
                (_activeSearchText?.trim().isNotEmpty ?? false))
            ? 295.0
            : 175.0;

    return Scaffold(
      body: MultiBlocListener(
        listeners: [
          BlocListener<MapDisplayCubit, MapDisplayState>(
            listenWhen: (previous, current) =>
                previous.selectedPoi != current.selectedPoi,
            listener: (context, state) {
              final poi = state.selectedPoi;
              if (!mounted) return;

              if (poi == null) {
                if (_selectedMarkerPoi != null) {
                  setState(() {
                    _selectedMarkerPoi = null;
                    _showSearchThisArea = false;
                  });
                }
                return;
              }

              // Selection can originate from the Saved screen or another
              // route, not only from the current search result sheet. Show
              // the same POI detail card and discard stale search context.
              final belongsToCurrentSearch =
                  _searchResults.any((item) => _isSamePoi(item, poi));
              if (!belongsToCurrentSearch) {
                _mapLayerKey.currentState?.clearSearchResults();
              }
              if (_selectedMarkerPoi != null &&
                  _isSamePoi(_selectedMarkerPoi!, poi)) {
                return;
              }

              setState(() {
                _selectedMarkerPoi = poi;
                _activeSearchText = poi.name;
                _showSearchThisArea = false;
                if (!belongsToCurrentSearch) {
                  _searchResults = [];
                }
              });
            },
          ),
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
          BlocListener<ViewportSearchBloc, ViewportSearchState>(
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
                  _handleSearchResults(
                    viewportState.pois,
                    title,
                  );
                } else if (viewportState.status == ViewportSearchStatus.empty) {
                  _handleSearchResults(const [], title);
                }
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
                      HomeMapControls(
                        displayCubit: displayCubit,
                        bottom: controlsBottom,
                      ),

                    // 3. Normal Map Exploration Elements (Ẩn khi đang xem route hoặc dẫn đường)
                    if (!isRouteActive && !isNavigating) ...[
                      HomeHeaderSearchBar(
                        topPadding: topPadding,
                        onPoiSelected: _handlePoiSelected,
                        onSearchResults: _handleSearchResults,
                        onAreaSearch: _handleAreaSearch,
                        onCategorySelected: _handleCategorySelected,
                        onSearchOpened: _handleClearSearch,
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

                      // 5. Dynamic Bottom Overlay (Explore Sheet / Search Results Sheet / POI Quick Card)
                      HomeBottomOverlay(
                        sheetController: _sheetController,
                        selectedMarkerPoi: _selectedMarkerPoi,
                        searchResults: _searchResults,
                        searchQuery: _activeSearchText,
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
                        onSearchResultPoiTap: _handleSearchResultPoiTap,
                        onCloseSearchResults: _handleCloseSearchResults,
                        onClosePoiCard: _handleClosePoiCard,
                        onDirections: _handleDirections,
                        onCustomRoute: _selectedMarkerPoi != null
                            ? () => _handleOpenCustomRouteDrawing(
                                  poi: _selectedMarkerPoi,
                                )
                            : null,
                      ),
                    ],

                    // 6. Direction Header (Google Maps Style: Origin/Destination/Swap/Profile)
                    if (isRouteActive)
                      RouteDirectionHeader(
                        topPadding: topPadding,
                        onSelectOrigin: _handleSelectOriginForRoute,
                        onSelectDestination: _handleSelectDestinationForRoute,
                        onClose: () {
                          DLog.info(
                              '❌ [HomeScreen] Close Route Preview tapped');
                          routePreviewCubit.clearRoute();
                        },
                      ),

                    // 7. Route Preview Bottom Sheet (Hiển thị khi Route đang xem trước)
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


                    // 7. Active Navigation Panels (Top Turn-by-turn Banner & Bottom ETA Bar)
                    if (isNavigating) ...[
                      NavigationTopPanel(topPadding: topPadding),

                      // 8. Right-side Navigation Controls (Compass + Recenter + Speedometer)
                      Positioned(
                        right: 16,
                        bottom: 120 + MediaQuery.paddingOf(context).bottom,
                        child: NavigationMapControls(
                          displayCubit: displayCubit,
                          onRecenter: () {
                            displayCubit.locateMe();
                          },
                        ),
                      ),

                      NavigationBottomPanel(
                        onStopNavigation: () {
                          DLog.info('🛑 [HomeScreen] Stop Navigation tapped');
                          navigationBloc.add(const StopNavigation());
                        },
                        onRecenter: () {
                          displayCubit.locateMe();
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

  bool _isSamePoi(PoiModel left, PoiModel right) =>
      left.lat == right.lat &&
      left.lon == right.lon &&
      (left.id != null && right.id != null
          ? left.id == right.id
          : left.osmId != null && right.osmId != null
              ? left.osmId == right.osmId
              : true);
}
