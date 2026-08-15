import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/home/widgets/widgets.dart';
import 'package:s_map/services/services.dart';

class HomeScreen extends StatefulWidget {
  static const String path = '/HomeScreen';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final MapDisplayCubit _mapCubit;
  late final MapExploreCubit _exploreCubit;
  late final ViewportSearchBloc _viewportBloc;

  @override
  void initState() {
    super.initState();
    _mapCubit = MapDisplayCubit(
      locationService: LocationService.instance,
      compassService: CompassService.instance,
      mapStyleService: MapStyleService.instance,
    );
    _exploreCubit = MapExploreCubit(
      fireStoreService: FireStoreService.instance,
    )..watchExplorePlaces();
    _viewportBloc = ViewportSearchBloc();
  }

  @override
  void dispose() {
    _mapCubit.close();
    _exploreCubit.close();
    _viewportBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _mapCubit),
        BlocProvider.value(value: _exploreCubit),
        BlocProvider.value(value: _viewportBloc),
      ],
      child: const _HomeScreenContent(),
    );
  }
}

class _HomeScreenContent extends StatefulWidget {
  const _HomeScreenContent();

  @override
  State<_HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<_HomeScreenContent> with AppMixin {
  final GlobalKey<HomeInteractiveMapLayerState> _mapLayerKey = GlobalKey();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  bool _showSearchThisArea = false;
  PoiModel? _selectedMarkerPoi;

  MapDisplayCubit get displayCubit => context.read<MapDisplayCubit>();
  MapExploreCubit get exploreCubit => context.read<MapExploreCubit>();
  ViewportSearchBloc get viewportBloc => context.read<ViewportSearchBloc>();

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  void _handleCategorySelected(String? cat) async {
    if (cat == null) return;
    exploreCubit.selectCategory(cat);
    final bounds = await _mapLayerKey.currentState?.getVisibleRegion();
    if (bounds != null && mounted) {
      viewportBloc.add(ViewportCategoryFilterChanged(cat, bounds: bounds));
    }
  }

  void _handleSearchThisArea() async {
    final bounds = await _mapLayerKey.currentState?.getVisibleRegion();
    if (bounds != null && mounted) {
      setState(() => _showSearchThisArea = false);
      viewportBloc.add(SearchThisAreaPressed(bounds));
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Interactive Map Layer
          HomeInteractiveMapLayer(
            key: _mapLayerKey,
            onPoiTapped: (poi) => setState(() => _selectedMarkerPoi = poi),
            onSearchAreaVisibilityChanged: (show) {
              if (mounted) setState(() => _showSearchThisArea = show);
            },
          ),

          // 2. Right Map Controls
          HomeMapControls(displayCubit: displayCubit),

          // 3. Top Floating Search Bar & Category Chips
          HomeHeaderSearchBar(
            topPadding: topPadding,
            onPoiSelected: (poi) => displayCubit.selectPoi(poi),
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
                _mapLayerKey.currentState?.handleCameraAction(
                  MapCameraAction(
                    type: MapCameraActionType.animateToPosition,
                    target: LatLng(place.latitude!, place.longitude!),
                    zoom: 16.0,
                    timestamp: DateTime.now().microsecondsSinceEpoch,
                  ),
                );
              }
            },
            onClosePoiCard: () => setState(() => _selectedMarkerPoi = null),
            onDirections: () {
              if (_selectedMarkerPoi != null) {
                AppUtils.instance.openLocation(
                  _selectedMarkerPoi!.lat,
                  _selectedMarkerPoi!.lon,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
