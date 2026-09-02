import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/screens/main/home/widgets/map/map_view.dart';

class RouteDrawingMapLayer extends StatefulWidget {
  const RouteDrawingMapLayer({super.key});

  @override
  State<RouteDrawingMapLayer> createState() => RouteDrawingMapLayerState();
}

class RouteDrawingMapLayerState extends State<RouteDrawingMapLayer> with AppMixin {
  MapLibreMapController? _mapController;
  final MapDrawingRouteManager _routeManager = MapDrawingRouteManager();
  final MapCameraController _cameraController = MapCameraController();
  String? _lastShownMapError;
  String? _lastAppliedMapStyle;

  RouteDrawingBloc get drawingBloc => context.read<RouteDrawingBloc>();
  MapDisplayCubit get displayCubit => context.read<MapDisplayCubit>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && displayCubit.state.isNightMode != isDark) {
        displayCubit.updateThemeMode(isDark);
      }
    });
  }

  void fitRouteBounds() {
    final state = drawingBloc.state;
    _routeManager.fitRouteBounds(
      controller: _mapController,
      points: state.points,
      fullPolyline: state.fullPolyline,
    );
  }

  Future<void> _applyMapStyle(String styleString) async {
    if (styleString.isEmpty || styleString == _lastAppliedMapStyle) return;

    final controller = _mapController;
    if (controller == null) return;

    _lastAppliedMapStyle = styleString;
    try {
      await controller.setStyle(styleString);
    } catch (error, stack) {
      _lastAppliedMapStyle = null;
      if (mounted) {
        showWarning('Không thể áp dụng giao diện bản đồ: $error');
      }
      debugPrintStack(label: 'Map style update failed', stackTrace: stack);
    }
  }

  void _onMapClick(Point<double> point, LatLng latLng) {
    if (drawingBloc.state.isLoading) return;
    drawingBloc.add(
      RouteDrawingPointTapped(
        lat: latLng.latitude,
        lon: latLng.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RouteDrawingBloc, RouteDrawingState>(
      listenWhen: (prev, curr) =>
          prev.points != curr.points ||
          prev.fullPolyline != curr.fullPolyline ||
          prev.status != curr.status ||
          prev.warningMessageKey != curr.warningMessageKey ||
          prev.errorMessageKey != curr.errorMessageKey,
      listener: (context, state) async {
        if (state.points.isEmpty && state.fullPolyline.isEmpty) {
          await _routeManager.clear(_mapController);
        } else {
          await _routeManager.drawCustomRoute(
            controller: _mapController,
            points: state.points,
            fullPolyline: state.fullPolyline,
          );
        }

        if (!context.mounted) return;

        if (state.status == RouteDrawingStatus.saved) {
          showSuccess(tr(LocaleKeys.route_drawing_ui_save_success));
        }

        if (state.warningMessageKey != null) {
          showWarning(tr(state.warningMessageKey!));
        }

        if (state.errorMessageKey != null) {
          showError(tr(state.errorMessageKey!));
        }
      },
      child: BlocListener<MapDisplayCubit, MapDisplayState>(
        listenWhen: (prev, curr) =>
            prev.cameraAction != curr.cameraAction ||
            prev.errorMessageKey != curr.errorMessageKey ||
            prev.styleString != curr.styleString,
        listener: (context, mapState) {
          _applyMapStyle(mapState.styleString);
          final action = mapState.cameraAction;
          if (action != null) {
            _cameraController.applyCameraAction(_mapController, action);
          }
          final errorKey = mapState.errorMessageKey;
          if (errorKey == null) {
            _lastShownMapError = null;
          } else if (errorKey != _lastShownMapError) {
            _lastShownMapError = errorKey;
            showError(tr(errorKey));
          }
        },
        child: BlocBuilder<MapDisplayCubit, MapDisplayState>(
          buildWhen: (prev, curr) =>
              prev.status != curr.status ||
              (prev.styleString != curr.styleString && _mapController == null),
          builder: (context, mapState) {
            return MapView(
              styleString: mapState.styleString,
              onMapCreated: (controller) {
                _mapController = controller;
                _lastAppliedMapStyle = mapState.styleString;
                displayCubit.onMapCreated();
              },
              onStyleLoadedCallback: () async {
                _routeManager.resetAssetLoaded();
                await _routeManager.loadMarkerAssets(_mapController);
                final drawState = drawingBloc.state;
                if (drawState.points.isNotEmpty ||
                    drawState.fullPolyline.isNotEmpty) {
                  await _routeManager.drawCustomRoute(
                    controller: _mapController,
                    points: drawState.points,
                    fullPolyline: drawState.fullPolyline,
                  );
                }
                _lastAppliedMapStyle = displayCubit.state.styleString;
                displayCubit.onStyleLoaded();
              },
              onCameraTrackingDismissed:
                  displayCubit.onCameraTrackingDismissed,
              onCameraMove: displayCubit.onCameraMove,
              onMapClick: _onMapClick,
            );
          },
        ),
      ),
    );
  }
}
