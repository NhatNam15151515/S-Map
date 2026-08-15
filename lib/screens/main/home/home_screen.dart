import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/cubits/map_display_cubit/map_display_cubit.dart';
import 'package:s_map/commons/cubits/map_display_cubit/map_display_state.dart';
import 'package:s_map/commons/cubits/map_explore_cubit/map_explore_cubit.dart';
import 'package:s_map/commons/cubits/map_explore_cubit/map_explore_state.dart';
import 'package:s_map/commons/mixin/app_mixin.dart';
import 'package:s_map/commons/widgets/explore_bottom_sheet.dart';
import 'package:s_map/commons/widgets/map_category_chips.dart';
import 'package:s_map/commons/widgets/map_controls.dart';
import 'package:s_map/commons/widgets/map_search_bar.dart';
import 'package:s_map/constants/map_constants.dart';
import 'package:s_map/screens/map/widgets/map_error_overlay.dart';
import 'package:s_map/screens/map/widgets/map_view.dart';

class HomeScreen extends StatefulWidget {
  static const String path = '/HomeScreen';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final MapDisplayCubit _mapCubit;
  late final MapExploreCubit _exploreCubit;

  @override
  void initState() {
    super.initState();
    _mapCubit = MapDisplayCubit();
    _exploreCubit = MapExploreCubit()..watchExplorePlaces();
  }

  @override
  void dispose() {
    _mapCubit.close();
    _exploreCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _mapCubit),
        BlocProvider.value(value: _exploreCubit),
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
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  MapLibreMapController? _mapController;

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  void _handleCameraAction(MapCameraAction action) {
    if (_mapController == null) return;
    switch (action.type) {
      case MapCameraActionType.animateToPosition:
        if (action.target != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              action.target!,
              action.zoom ?? MapConstants.locateMeZoom,
            ),
          );
        }
        break;
      case MapCameraActionType.zoomIn:
        _mapController!.animateCamera(CameraUpdate.zoomIn());
        break;
      case MapCameraActionType.zoomOut:
        _mapController!.animateCamera(CameraUpdate.zoomOut());
        break;
      case MapCameraActionType.bearingTo:
        if (action.bearing != null) {
          _mapController!.moveCamera(CameraUpdate.bearingTo(action.bearing!));
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayCubit = context.read<MapDisplayCubit>();
    final exploreCubit = context.read<MapExploreCubit>();
    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: Stack(
        children: [
          // 1. BASE MAP VIEW
          BlocConsumer<MapDisplayCubit, MapDisplayState>(
            listenWhen: (prev, curr) =>
                prev.cameraAction != curr.cameraAction ||
                (curr.errorMessageKey != null &&
                    prev.errorMessageKey != curr.errorMessageKey),
            listener: (context, state) {
              if (state.cameraAction != null) {
                _handleCameraAction(state.cameraAction!);
              }
              if (state.errorMessageKey != null &&
                  state.status != MapDisplayStatus.error) {
                showWarning(tr(state.errorMessageKey!));
                displayCubit.clearError();
              }
            },
            builder: (context, state) {
              return Stack(
                children: [
                  MapView(
                    onMapCreated: (controller) {
                      _mapController = controller;
                      displayCubit.onMapCreated();
                    },
                    onStyleLoadedCallback: displayCubit.onStyleLoaded,
                    onCameraTrackingDismissed: displayCubit.onCameraTrackingDismissed,
                    onCameraMove: displayCubit.onCameraMove,
                  ),
                  if (state.status == MapDisplayStatus.loading)
                    const Positioned.fill(
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  if (state.status == MapDisplayStatus.error)
                    MapErrorOverlay(
                      errorMessage: state.errorMessageKey != null
                          ? tr(state.errorMessageKey!)
                          : tr('map.error_load'),
                      onRetry: displayCubit.locateMe,
                    ),
                ],
              );
            },
          ),

          // 2. RIGHT MAP CONTROLS
          Positioned(
            right: 16,
            bottom: 220,
            child: BlocBuilder<MapDisplayCubit, MapDisplayState>(
              buildWhen: (previous, current) =>
                  previous.rotation != current.rotation ||
                  previous.orientationMode != current.orientationMode,
              builder: (context, state) {
                return MapControls(
                  onZoomIn: displayCubit.zoomIn,
                  onZoomOut: displayCubit.zoomOut,
                  onLocateMe: displayCubit.locateMe,
                  onToggleOrientation: displayCubit.toggleOrientationMode,
                  rotation: state.rotation,
                  orientationMode: state.orientationMode,
                  locateHeroTag: 'home_screen_locate_fab',
                );
              },
            ),
          ),

          // 3. TOP FLOATING SEARCH BAR & CATEGORIES
          Positioned(
            top: topPadding + 8,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MapSearchBar(),
                const SizedBox(height: 10),
                BlocBuilder<MapExploreCubit, MapExploreState>(
                  buildWhen: (prev, curr) =>
                      prev.selectedCategory != curr.selectedCategory,
                  builder: (context, exploreState) {
                    return MapCategoryChips(
                      selectedCategory: exploreState.selectedCategory,
                      onCategorySelected: exploreCubit.selectCategory,
                    );
                  },
                ),
              ],
            ),
          ),

          // 4. DYNAMIC EXPLORE BOTTOM SHEET
          BlocBuilder<MapExploreCubit, MapExploreState>(
            builder: (context, exploreState) {
              return ExploreBottomSheet(
                controller: _sheetController,
                places: exploreState.places,
                isLoading: exploreState.isLoading,
                onPlaceTap: (place) {
                  if (place.latitude != null && place.longitude != null) {
                    _handleCameraAction(MapCameraAction(
                      type: MapCameraActionType.animateToPosition,
                      target: LatLng(place.latitude!, place.longitude!),
                      zoom: 16.0,
                      timestamp: DateTime.now().microsecondsSinceEpoch,
                    ));
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
