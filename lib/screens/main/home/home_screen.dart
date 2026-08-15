import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/cubits/map_display_cubit/map_display_cubit.dart';
import 'package:s_map/commons/cubits/map_display_cubit/map_display_state.dart';
import 'package:s_map/commons/mixin/app_mixin.dart';
import 'package:s_map/constants/map_constants.dart';
import 'package:s_map/models/place_model.dart';
import 'package:s_map/screens/map/widgets/map_error_overlay.dart';
import 'package:s_map/screens/map/widgets/map_view.dart';
import 'package:s_map/services/firebase_firestore_service.dart';
import 'widgets/home_category_chips.dart';
import 'widgets/home_explore_bottom_sheet.dart';
import 'widgets/home_map_controls.dart';
import 'widgets/home_search_bar.dart';

class HomeScreen extends StatefulWidget {
  static const String path = '/HomeScreen';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final MapDisplayCubit _mapCubit;

  @override
  void initState() {
    super.initState();
    _mapCubit = MapDisplayCubit();
  }

  @override
  void dispose() {
    _mapCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _mapCubit,
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
  final FireStoreService _fireStore = FireStoreService();
  String _selectedCategory = "Tất cả";
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
    final cubit = context.read<MapDisplayCubit>();
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
                cubit.clearError();
              }
            },
            builder: (context, state) {
              return Stack(
                children: [
                  MapView(
                    onMapCreated: (controller) {
                      _mapController = controller;
                      cubit.onMapCreated();
                    },
                    onStyleLoadedCallback: cubit.onStyleLoaded,
                    onCameraTrackingDismissed: cubit.onCameraTrackingDismissed,
                    onCameraMove: cubit.onCameraMove,
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
                      onRetry: cubit.locateMe,
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
                return HomeMapControls(
                  onZoomIn: cubit.zoomIn,
                  onZoomOut: cubit.zoomOut,
                  onLocateMe: cubit.locateMe,
                  onToggleOrientation: cubit.toggleOrientationMode,
                  rotation: state.rotation,
                  orientationMode: state.orientationMode,
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
                const HomeSearchBar(),
                const SizedBox(height: 10),
                HomeCategoryChips(
                  onCategorySelected: (category) {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                ),
              ],
            ),
          ),

          // 4. DYNAMIC EXPLORE BOTTOM SHEET (FIRESTORE STREAM)
          StreamBuilder<List<PlaceModel>>(
            stream: _fireStore.streamExplorePlaces(category: _selectedCategory),
            builder: (context, snapshot) {
              return HomeExploreBottomSheet(
                controller: _sheetController,
                places: snapshot.data,
                isLoading: snapshot.connectionState == ConnectionState.waiting,
                onPlaceTap: (place) {
                  if (place.latitude != null && place.longitude != null) {
                    // Navigate or move camera to place
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
