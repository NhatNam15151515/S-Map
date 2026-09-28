import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/utils/area_search_destination_resolver.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';
import 'route_drawing_destination_controller.dart';
import 'route_drawing_origin_controller.dart';
import 'route_drawing_payload_initializer.dart';

/// State/logic dùng chung cho workspace vẽ route trên Home và màn hình cũ.
class RouteDrawingSession {
  final RouteDrawingBloc drawingBloc;
  final SavedRoutesCubit savedRoutesCubit;
  final MapDisplayCubit mapDisplayCubit;
  final bool ownsDrawingBloc;
  final bool ownsSavedRoutesCubit;
  final bool ownsMapDisplayCubit;

  late final RouteDrawingOriginController originController;
  late final RouteDrawingDestinationController destinationController;

  RouteDrawingSession({
    RouteDrawingBloc? drawingBloc,
    SavedRoutesCubit? savedRoutesCubit,
    MapDisplayCubit? mapDisplayCubit,
    AreaSearchDestinationResolver? areaSearchResolver,
    required VoidCallback onStateChanged,
  })  : ownsDrawingBloc = drawingBloc == null,
        ownsSavedRoutesCubit = savedRoutesCubit == null,
        ownsMapDisplayCubit = mapDisplayCubit == null,
        drawingBloc = drawingBloc ??
            RouteDrawingBloc(
              routingRepository: AppReposProvider.instance.routingRepos,
              customRouteRepository:
                  AppReposProvider.instance.customRouteRepos,
            ),
        savedRoutesCubit = savedRoutesCubit ?? SavedRoutesCubit(),
        mapDisplayCubit = mapDisplayCubit ?? MapDisplayCubit() {
    originController = RouteDrawingOriginController(
      mapDisplayCubit: this.mapDisplayCubit,
      drawingBloc: this.drawingBloc,
      onStateChanged: onStateChanged,
    );
    destinationController = RouteDrawingDestinationController(
      mapDisplayCubit: this.mapDisplayCubit,
      drawingBloc: this.drawingBloc,
      areaSearchResolver: areaSearchResolver ?? AreaSearchDestinationResolver(),
      onStateChanged: onStateChanged,
    );
  }

  void initialize({
    RouteDrawingPayload? payload,
    LatLng? initialOrigin,
    LatLng? initialDestination,
    required bool Function() isMounted,
    required VoidCallback setState,
  }) {
    RouteDrawingPayloadInitializer(
      drawingBloc: drawingBloc,
      originController: originController,
      destController: destinationController,
    ).initialize(
      payload: payload,
      initialOrigin: initialOrigin,
      initialDestination: initialDestination,
      isMounted: isMounted,
      setState: setState,
    );
  }

  void reset() {
    drawingBloc.add(const RouteDrawingClearRoute());
    destinationController.markerDestination = null;
    destinationController.isMarkerDestinationActive = false;
    destinationController.isDestinationPickerActive = false;
    destinationController.isCrosshairActive = true;
    originController.isMyLocationOriginActive = false;
  }

  void handleMapTap(LatLng tappedLatLng) {
    if (destinationController.isCrosshairActive) return;

    if (destinationController.isDestinationPickerActive) {
      destinationController.setMarkerDestination(
        tappedLatLng,
        addToRoute: drawingBloc.state.points.isNotEmpty,
      );
      return;
    }

    final markerDestination = destinationController.markerDestination;
    if (drawingBloc.state.points.isEmpty && markerDestination != null) {
      drawingBloc.add(
        RouteDrawingEndpointsSelected(
          origin: RoutePoint(
            lat: tappedLatLng.latitude,
            lon: tappedLatLng.longitude,
          ),
          destination: RoutePoint(
            lat: markerDestination.latitude,
            lon: markerDestination.longitude,
          ),
        ),
      );
      return;
    }

    drawingBloc.add(
      RouteDrawingPointTapped(
        lat: tappedLatLng.latitude,
        lon: tappedLatLng.longitude,
      ),
    );
  }

  void handleAddPointAtCenter(LatLng? center) {
    if (center == null || !destinationController.isCrosshairActive) return;

    final markerDestination = destinationController.markerDestination;
    if (drawingBloc.state.points.isEmpty && markerDestination != null) {
      drawingBloc.add(
        RouteDrawingEndpointsSelected(
          origin: RoutePoint(lat: center.latitude, lon: center.longitude),
          destination: RoutePoint(
            lat: markerDestination.latitude,
            lon: markerDestination.longitude,
          ),
        ),
      );
      return;
    }

    drawingBloc.add(
      RouteDrawingPointTapped(lat: center.latitude, lon: center.longitude),
    );
  }

  void addDestination(LatLng destination) {
    destinationController.applyDestination(destination);
  }

  void dispose() {
    if (ownsDrawingBloc) drawingBloc.close();
    if (ownsSavedRoutesCubit) savedRoutesCubit.close();
    if (ownsMapDisplayCubit) mapDisplayCubit.close();
  }
}
