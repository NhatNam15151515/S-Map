import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/cubits/map_display_cubit/map_display_cubit.dart';
import 'package:s_map/commons/cubits/map_display_cubit/map_display_state.dart';
import 'package:s_map/commons/mixin/app_mixin.dart';
import 'package:s_map/constants/map_constants.dart';
import 'package:s_map/screens/map/widgets/map_error_overlay.dart';
import 'package:s_map/screens/map/widgets/map_fab_buttons.dart';
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

    return Scaffold(
      body: BlocConsumer<MapDisplayCubit, MapDisplayState>(
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
              if (state.status == MapDisplayStatus.ready ||
                  state.status == MapDisplayStatus.loading)
                MapFabButtons(
                  onZoomIn: cubit.zoomIn,
                  onZoomOut: cubit.zoomOut,
                  onLocateMe: cubit.locateMe,
                  onToggleOrientation: cubit.toggleOrientationMode,
                  rotation: state.rotation,
                  orientationMode: state.orientationMode,
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
                  onRetry: cubit.locateMe,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MapScreenState extends State<MapScreen> with AppMixin {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MapDisplayCubit(),
      child: const _MyMapScreenContent(),
    );
  }
}
