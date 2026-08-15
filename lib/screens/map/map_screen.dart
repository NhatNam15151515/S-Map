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

class MapScreen extends StatefulWidget {
  static const String path = '/map';

  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MyMapScreenContent extends StatefulWidget {
  const _MyMapScreenContent();

  @override
  State<_MyMapScreenContent> createState() => _MyMapScreenContentState();
}

class _MyMapScreenContentState extends State<_MyMapScreenContent> with AppMixin {
  MapLibreMapController? _mapController;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

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
                    Positioned.fill(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: styles.colorScheme.primary,
                        ),
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

          // 2. RIGHT MAP CONTROLS (FAB)
          Positioned(
            right: 16,
            bottom: 140,
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
                  locateHeroTag: 'map_screen_locate_fab',
                );
              },
            ),
          ),

          // 3. TOP FLOATING SEARCH BAR & CATEGORY CHIPS
          Positioned(
            top: topPadding + 8,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MapSearchBar(showBackButton: true),
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

          // 4. DRAGGABLE EXPLORE BOTTOM SHEET
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

class _MapScreenState extends State<MapScreen> with AppMixin {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => MapDisplayCubit()),
        BlocProvider(create: (_) => MapExploreCubit()),
      ],
      child: const _MyMapScreenContent(),
    );
  }
}
