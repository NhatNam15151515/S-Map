import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/models/models.dart';
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
  String? _currentSearchQuery;

  MapDisplayCubit get displayCubit => context.read<MapDisplayCubit>();
  MapExploreCubit get exploreCubit => context.read<MapExploreCubit>();
  ViewportSearchBloc get viewportBloc => context.read<ViewportSearchBloc>();
  RoutePreviewCubit get routePreviewCubit => context.read<RoutePreviewCubit>();
  NavigationBloc get navigationBloc => context.read<NavigationBloc>();

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  void _handleCategorySelected(String? cat) {
    if (cat == null) return;
    exploreCubit.selectCategory(cat);
    _mapLayerKey.currentState?.searchByCategory(cat);
  }

  void _handleSearchThisArea() {
    setState(() => _showSearchThisArea = false);
    _mapLayerKey.currentState?.searchThisArea(query: _currentSearchQuery);
  }

  void _handlePoiSelected(PoiModel poi) {
    displayCubit.selectPoi(poi);
    _mapLayerKey.currentState?.setSelectedPoiMarker(poi);
    setState(() {
      _selectedMarkerPoi = poi;
    });
  }

  void _handleSearchResults(List<PoiModel> pois, String? query) {
    _currentSearchQuery = query;
    _mapLayerKey.currentState?.showSearchResults(pois);
    if (pois.isNotEmpty) {
      setState(() {
        _selectedMarkerPoi = pois.first;
      });
    }
  }

  void _handleDirections() {
    if (_selectedMarkerPoi != null) {
      final poi = _selectedMarkerPoi!;
      DLog.info(
          '🧭 [HomeScreen] "Chỉ đường" tapped for POI: "${poi.name}" (${poi.lat}, ${poi.lon})');
      _mapLayerKey.currentState?.clearSelectedPoiMarker();
      displayCubit.clearSelectedPoi();
      setState(() => _selectedMarkerPoi = null);
      routePreviewCubit.previewRouteToPoi(poi);
    }
  }

  void _showTripSummaryModal(TripSummary summary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => TripSummaryBottomSheet(
        summary: summary,
        onDone: () {
          Navigator.of(modalContext).pop();
          navigationBloc.add(const ClearNavigation());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: BlocListener<NavigationBloc, NavigationState>(
        listenWhen: (prev, curr) =>
            prev.status != curr.status &&
            curr.tripSummary != null &&
            (curr.status == NavigationStatus.arrived ||
                curr.status == NavigationStatus.stopped),
        listener: (context, navState) {
          if (navState.tripSummary != null) {
            _showTripSummaryModal(navState.tripSummary!);
          }
        },
        child: BlocBuilder<NavigationBloc, NavigationState>(
          builder: (context, navState) {
            final isNavigating = navState.isNavigating;

            return BlocBuilder<RoutePreviewCubit, RoutePreviewState>(
              builder: (context, routeState) {
                final isRouteActive =
                    !isNavigating && (routeState.isLoading || routeState.isSuccess);

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
                      ),

                      // 4. Floating "Search This Area" Button
                      HomeSearchAreaButton(
                        topPadding: topPadding,
                        isVisible: _showSearchThisArea,
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
                          setState(() => _selectedMarkerPoi = null);
                        },
                        onDirections: _handleDirections,
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
                              DLog.info('❌ [HomeScreen] Close Route Preview tapped');
                              routePreviewCubit.clearRoute();
                            },
                            onStartNavigation: () {
                              if (routeState.currentRoute != null &&
                                  routeState.origin != null &&
                                  routeState.destination != null) {
                                DLog.info(
                                    '🚀 [HomeScreen] Starting Turn-by-Turn Navigation');
                                final route = routeState.currentRoute!;
                                final origin = routeState.origin!;
                                final destination = routeState.destination!;
                                final destName = routeState.destinationName;
                                final profile = routeState.currentProfile;

                                routePreviewCubit.clearRoute();
                                navigationBloc.add(StartNavigation(
                                  initialRoute: route,
                                  origin: origin,
                                  destination: destination,
                                  destinationName: destName,
                                  profile: profile,
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
