import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/screens/main/home/widgets/map/map_view.dart';

class RouteDrawingMapLayer extends StatefulWidget {
  final bool isCrosshairActive;
  final LatLng? markerDestination;
  final void Function(LatLng latLng)? onMapTap;

  const RouteDrawingMapLayer({
    super.key,
    this.isCrosshairActive = false,
    this.markerDestination,
    this.onMapTap,
  });

  @override
  State<RouteDrawingMapLayer> createState() => RouteDrawingMapLayerState();
}

class RouteDrawingMapLayerState extends State<RouteDrawingMapLayer> with AppMixin {
  MapLibreMapController? _mapController;
  final MapDrawingRouteManager _routeManager = MapDrawingRouteManager();
  final MapCameraController _cameraController = MapCameraController();
  String? _lastShownMapError;
  String? _lastAppliedMapStyle;

  LatLng? get currentCenter =>
      _mapController?.cameraPosition?.target ?? displayCubit.state.center;

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

  @override
  void didUpdateWidget(covariant RouteDrawingMapLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.markerDestination != oldWidget.markerDestination) {
      _renderCurrentRoute();
    }
  }

  Future<void> _renderCurrentRoute() async {
    final state = drawingBloc.state;
    if (state.points.isEmpty &&
        state.fullPolyline.isEmpty &&
        widget.markerDestination == null) {
      await _routeManager.clear(_mapController);
    } else {
      await _routeManager.drawCustomRoute(
        controller: _mapController,
        points: state.points,
        fullPolyline: state.fullPolyline,
        destinationPreview: widget.markerDestination,
      );
    }
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
    // Khi đang bật tâm ngắm (crosshair), điểm chỉ được thêm qua nút "Thêm điểm tại tâm"
    // Tránh click nhầm hoặc gesture xuyên qua tự động sinh điểm tại tâm.
    if (widget.isCrosshairActive) return;

    HapticFeedback.lightImpact();

    if (widget.onMapTap != null) {
      widget.onMapTap!(latLng);
    } else {
      drawingBloc.add(
        RouteDrawingPointTapped(
          lat: latLng.latitude,
          lon: latLng.longitude,
        ),
      );
    }
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
        await _renderCurrentRoute();

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
                await _renderCurrentRoute();
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
