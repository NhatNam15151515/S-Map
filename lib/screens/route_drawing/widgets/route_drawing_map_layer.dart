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

  RouteDrawingBloc get drawingBloc => context.read<RouteDrawingBloc>();
  MapDisplayCubit get displayCubit => context.read<MapDisplayCubit>();

  void fitRouteBounds() {
    final state = drawingBloc.state;
    _routeManager.fitRouteBounds(
      controller: _mapController,
      points: state.points,
      fullPolyline: state.fullPolyline,
    );
  }

  void _onMapClick(dynamic point, LatLng latLng) {
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
      child: BlocBuilder<MapDisplayCubit, MapDisplayState>(
        buildWhen: (prev, curr) =>
            prev.status != curr.status || prev.styleString != curr.styleString,
        builder: (context, mapState) {
          return MapView(
            styleString: mapState.styleString,
            onMapCreated: (controller) {
              _mapController = controller;
              displayCubit.onMapCreated();
            },
            onStyleLoadedCallback: () {
              _routeManager.loadMarkerAssets(_mapController);
              displayCubit.onStyleLoaded();
            },
            onCameraTrackingDismissed: displayCubit.onCameraTrackingDismissed,
            onCameraMove: displayCubit.onCameraMove,
            onMapClick: _onMapClick,
          );
        },
      ),
    );
  }
}
