import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/home/widgets/widgets.dart';

class HomeInteractiveMapLayer extends StatefulWidget {
  final ValueChanged<PoiModel> onPoiTapped;
  final ValueChanged<bool> onSearchAreaVisibilityChanged;

  const HomeInteractiveMapLayer({
    super.key,
    required this.onPoiTapped,
    required this.onSearchAreaVisibilityChanged,
  });

  @override
  State<HomeInteractiveMapLayer> createState() =>
      HomeInteractiveMapLayerState();
}

class HomeInteractiveMapLayerState extends State<HomeInteractiveMapLayer>
    with AppMixin {
  MapLibreMapController? _mapController;
  LatLngBounds? _lastSearchedBounds;
  final Map<String, PoiModel> _renderedSymbols = {};

  MapDisplayCubit get displayCubit => context.read<MapDisplayCubit>();
  ViewportSearchBloc get viewportBloc => context.read<ViewportSearchBloc>();

  Future<LatLngBounds?> getVisibleRegion() async {
    return await _mapController?.getVisibleRegion();
  }

  void handleCameraAction(MapCameraAction action) {
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
        viewportBloc.add(SearchInViewportRequested(bounds));
        widget.onSearchAreaVisibilityChanged(false);
      } else {
        final currentCenter = LatLng(
          (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
          (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
        );
        final lastCenter = LatLng(
          (_lastSearchedBounds!.northeast.latitude +
                  _lastSearchedBounds!.southwest.latitude) /
              2,
          (_lastSearchedBounds!.northeast.longitude +
                  _lastSearchedBounds!.southwest.longitude) /
              2,
        );
        final distKm = AppUtils.instance.calculateDistance(
          currentCenter.latitude,
          currentCenter.longitude,
          lastCenter.latitude,
          lastCenter.longitude,
        );
        if (distKm > MapConstants.viewportSearchDistanceThresholdKm) {
          widget.onSearchAreaVisibilityChanged(true);
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
            iconSize: MapConstants.symbolIconSize,
            textField: poi.name,
            textSize: MapConstants.symbolTextSize,
            textColor: AppColors.mapSymbolText.toHex,
            textHaloColor: AppColors.mapSymbolHalo.toHex,
            textHaloWidth: MapConstants.symbolTextHaloWidth,
            textOffset: const Offset(0, 1.2),
          ),
        );
        _renderedSymbols[symbol.id] = poi;
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<MapDisplayCubit, MapDisplayState>(
          listenWhen: (prev, curr) =>
              prev.cameraAction != curr.cameraAction ||
              prev.status != curr.status,
          listener: (context, state) {
            if (state.cameraAction != null) {
              handleCameraAction(state.cameraAction!);
            }
            if (state.status == MapDisplayStatus.error &&
                state.errorMessageKey != null) {
              showError(tr(state.errorMessageKey!));
            }
          },
        ),
        BlocListener<ViewportSearchBloc, ViewportSearchState>(
          listenWhen: (prev, curr) =>
              prev.pois != curr.pois || prev.status != curr.status,
          listener: (context, state) {
            if (state.status == ViewportSearchStatus.success) {
              _updatePoiSymbols(state.pois);
            } else if (state.status == ViewportSearchStatus.error &&
                state.errorMessageKey != null) {
              showError(tr(state.errorMessageKey!));
            }
          },
        ),
      ],
      child: BlocBuilder<MapDisplayCubit, MapDisplayState>(
        buildWhen: (prev, curr) =>
            prev.status != curr.status || prev.styleString != curr.styleString,
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
                      widget.onPoiTapped(poi);
                    }
                  });
                  displayCubit.onMapCreated();
                },
                onStyleLoadedCallback: displayCubit.onStyleLoaded,
                onCameraTrackingDismissed:
                    displayCubit.onCameraTrackingDismissed,
                onCameraMove: displayCubit.onCameraMove,
                onCameraIdle: _onCameraIdle,
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
    );
  }
}
