import 'package:easy_localization/easy_localization.dart';
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
      DLog.info('🧭 [HomeScreen] "Chỉ đường" tapped for POI: "${poi.name}" (${poi.lat}, ${poi.lon})');
      _mapLayerKey.currentState?.clearSelectedPoiMarker();
      displayCubit.clearSelectedPoi();
      setState(() => _selectedMarkerPoi = null);
      routePreviewCubit.previewRouteToPoi(poi);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: BlocBuilder<RoutePreviewCubit, RoutePreviewState>(
        builder: (context, routeState) {
          final isRouteActive = routeState.isLoading || routeState.isSuccess;

          return Stack(
            children: [
              // 1. Interactive Map Layer
              HomeInteractiveMapLayer(
                key: _mapLayerKey,
                onPoiTapped: (poi) {
                  _handlePoiSelected(poi);
                },
                onSearchAreaVisibilityChanged: (show) {
                  if (mounted && !isRouteActive) {
                    setState(() => _showSearchThisArea = show);
                  }
                },
              ),

              // 2. Right Map Controls
              HomeMapControls(displayCubit: displayCubit),

              // 3. Top Floating Search Bar & Category Chips (Ẩn khi đang xem route)
              if (!isRouteActive) ...[
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
                  onClosePoiCard: () {
                    _mapLayerKey.currentState?.clearSelectedPoiMarker();
                    displayCubit.clearSelectedPoi();
                    setState(() => _selectedMarkerPoi = null);
                  },
                  onDirections: _handleDirections,
                ),
              ],

              // 6. Route Preview Bottom Sheet (Hiển thị khi Route đang tính toán hoặc sẵn sàng)
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
                        DLog.info('🚀 [HomeScreen] "Bắt đầu" Navigation tapped');
                        showInfo(tr(LocaleKeys.routing_feature_under_development));
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
