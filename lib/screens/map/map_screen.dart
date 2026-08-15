import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';
import 'widgets/widgets.dart';

class MapScreen extends StatefulWidget {
  static const String path = '/map';

  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with AppMixin {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => MapDisplayCubit()),
        BlocProvider(create: (_) => MapExploreCubit()..watchExplorePlaces()),
        BlocProvider(create: (_) => ViewportSearchBloc()),
      ],
      child: const _MyMapScreenContent(),
    );
  }
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

  bool _showSearchThisArea = false;
  LatLngBounds? _lastSearchedBounds;
  PoiModel? _selectedMarkerPoi;
  final Map<String, PoiModel> _renderedSymbols = {};

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

  Future<void> _onCameraIdle() async {
    if (_mapController == null) return;
    try {
      final bounds = await _mapController!.getVisibleRegion();
      if (!mounted) return;

      if (_lastSearchedBounds == null) {
        _lastSearchedBounds = bounds;
        context.read<ViewportSearchBloc>().add(SearchInViewportRequested(bounds));
        setState(() => _showSearchThisArea = false);
      } else {
        final currentCenter = LatLng(
          (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
          (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
        );
        final lastCenter = LatLng(
          (_lastSearchedBounds!.northeast.latitude + _lastSearchedBounds!.southwest.latitude) / 2,
          (_lastSearchedBounds!.northeast.longitude + _lastSearchedBounds!.southwest.longitude) / 2,
        );
        final distKm = AppUtils.instance.calculateDistance(
          currentCenter.latitude,
          currentCenter.longitude,
          lastCenter.latitude,
          lastCenter.longitude,
        );
        if (distKm > 0.4) {
          setState(() => _showSearchThisArea = true);
        }
      }
    } catch (_) {}
  }

  Future<void> _updatePoiSymbols(List<PoiModel> pois) async {
    if (_mapController == null) return;
    try {
      await _mapController!.clearSymbols();
      _renderedSymbols.clear();
      for (final poi in pois) {
        final symbol = await _mapController!.addSymbol(
          SymbolOptions(
            geometry: LatLng(poi.lat, poi.lon),
            iconSize: 1.1,
            textField: poi.name,
            textSize: 11.0,
            textOffset: const Offset(0, 1.2),
            textColor: '#0F172A',
            textHaloColor: '#FFFFFF',
            textHaloWidth: 1.5,
          ),
        );
        _renderedSymbols[symbol.id] = poi;
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final displayCubit = context.read<MapDisplayCubit>();
    final exploreCubit = context.read<MapExploreCubit>();
    final viewportBloc = context.read<ViewportSearchBloc>();
    final topPadding = MediaQuery.paddingOf(context).top;

    return MultiBlocListener(
      listeners: [
        BlocListener<MapDisplayCubit, MapDisplayState>(
          listenWhen: (prev, curr) =>
              prev.cameraAction != curr.cameraAction ||
              prev.selectedPoi != curr.selectedPoi ||
              (curr.errorMessageKey != null &&
                  prev.errorMessageKey != curr.errorMessageKey),
          listener: (context, state) {
            if (state.cameraAction != null) {
              _handleCameraAction(state.cameraAction!);
            }
            if (state.selectedPoi != null && _mapController != null) {
              try {
                _mapController!.clearSymbols();
                _renderedSymbols.clear();
                _mapController!.addSymbol(
                  SymbolOptions(
                    geometry: LatLng(
                      state.selectedPoi!.lat,
                      state.selectedPoi!.lon,
                    ),
                    iconSize: 1.2,
                    textField: state.selectedPoi!.name,
                    textSize: 12.0,
                    textOffset: const Offset(0, 1.2),
                    textColor: '#0F172A',
                    textHaloColor: '#FFFFFF',
                    textHaloWidth: 2.0,
                  ),
                );
                setState(() => _selectedMarkerPoi = state.selectedPoi);
              } catch (_) {}
            }
            if (state.errorMessageKey != null &&
                state.status != MapDisplayStatus.error) {
              showWarning(tr(state.errorMessageKey!));
              displayCubit.clearError();
            }
          },
        ),
        BlocListener<ViewportSearchBloc, ViewportSearchState>(
          listenWhen: (prev, curr) => prev.status != curr.status || prev.pois != curr.pois,
          listener: (context, state) {
            if (state.isSuccess) {
              _updatePoiSymbols(state.pois);
            } else if (state.isEmpty) {
              _mapController?.clearSymbols();
              _renderedSymbols.clear();
            }
          },
        ),
      ],
      child: Scaffold(
        body: Stack(
          children: [
            // 1. BASE MAP VIEW
            BlocBuilder<MapDisplayCubit, MapDisplayState>(
              builder: (context, state) {
                return Stack(
                  children: [
                    MapView(
                      styleString: state.styleString,
                      onMapCreated: (controller) {
                        _mapController = controller;
                        _mapController!.onSymbolTapped.add((symbol) {
                          final poi = _renderedSymbols[symbol.id];
                          if (poi != null && mounted) {
                            setState(() => _selectedMarkerPoi = poi);
                          }
                        });
                        displayCubit.onMapCreated();
                      },
                      onStyleLoadedCallback: displayCubit.onStyleLoaded,
                      onCameraTrackingDismissed: displayCubit.onCameraTrackingDismissed,
                      onCameraMove: displayCubit.onCameraMove,
                      onCameraIdle: _onCameraIdle,
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
                  MapSearchBar(
                    showBackButton: true,
                    onPoiSelected: (poi) => displayCubit.selectPoi(poi),
                  ),
                  const SizedBox(height: 10),
                  BlocBuilder<MapExploreCubit, MapExploreState>(
                    buildWhen: (prev, curr) =>
                        prev.selectedCategory != curr.selectedCategory,
                    builder: (context, exploreState) {
                      return MapCategoryChips(
                        selectedCategory: exploreState.selectedCategory,
                        onCategorySelected: (cat) async {
                          exploreCubit.selectCategory(cat);
                          final bounds = await _mapController?.getVisibleRegion();
                          if (bounds != null && mounted) {
                            viewportBloc.add(
                              ViewportCategoryFilterChanged(
                                cat,
                                bounds: bounds,
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            // 4. FLOATING "SEARCH THIS AREA" BUTTON
            Positioned(
              top: topPadding + 108,
              left: 0,
              right: 0,
              child: Center(
                child: BlocBuilder<ViewportSearchBloc, ViewportSearchState>(
                  buildWhen: (prev, curr) => prev.status != curr.status,
                  builder: (context, viewportState) {
                    final isLoading = viewportState.isLoading;
                    return SearchThisAreaButton(
                      isVisible: _showSearchThisArea || isLoading,
                      isLoading: isLoading,
                      onPressed: () async {
                        final bounds = await _mapController?.getVisibleRegion();
                        if (bounds != null && mounted) {
                          _lastSearchedBounds = bounds;
                          setState(() => _showSearchThisArea = false);
                          viewportBloc.add(SearchThisAreaPressed(bounds));
                        }
                      },
                    );
                  },
                ),
              ),
            ),

            // 5. DRAGGABLE EXPLORE BOTTOM SHEET (khi chưa chọn marker cụ thể)
            if (_selectedMarkerPoi == null)
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

            // 6. POI QUICK PREVIEW CARD (khi chạm vào 1 marker POI)
            if (_selectedMarkerPoi != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: PoiQuickCard(
                  poi: _selectedMarkerPoi!,
                  onClose: () => setState(() => _selectedMarkerPoi = null),
                  onDirections: () {
                    AppUtils.instance.openLocation(
                      _selectedMarkerPoi!.lat,
                      _selectedMarkerPoi!.lon,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
