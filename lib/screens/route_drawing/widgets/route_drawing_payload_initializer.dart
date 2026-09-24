import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/models/models.dart';
import 'route_drawing_destination_controller.dart';
import 'route_drawing_origin_controller.dart';

/// Helper class xử lý khởi tạo trạng thái ban đầu từ [RouteDrawingPayload].
///
/// Trách nhiệm duy nhất:
/// - Parse payload + initial params → dispatch events tới bloc
/// - Set trạng thái ban đầu cho origin/destination controllers
class RouteDrawingPayloadInitializer {
  final RouteDrawingBloc drawingBloc;
  final RouteDrawingOriginController originController;
  final RouteDrawingDestinationController destController;

  RouteDrawingPayloadInitializer({
    required this.drawingBloc,
    required this.originController,
    required this.destController,
  });

  /// Khởi tạo trạng thái từ payload và initial params.
  ///
  /// Phải gọi trong `initState` hoặc `addPostFrameCallback`.
  void initialize({
    RouteDrawingPayload? payload,
    LatLng? initialOrigin,
    LatLng? initialDestination,
    required bool Function() isMounted,
    required VoidCallback setState,
  }) {
    final initialRoute = payload?.initialRoute;
    final effectiveOrigin = initialOrigin ?? payload?.initialOrigin;

    destController.markerDestination = initialDestination ??
        payload?.initialDestination ??
        (payload?.destinationPoi != null
            ? LatLng(payload!.destinationPoi!.lat, payload.destinationPoi!.lon)
            : null);
    destController.isDestinationPickerActive = false;
    destController.isMarkerDestinationActive =
        destController.markerDestination != null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMounted()) return;
      if (initialRoute != null) {
        drawingBloc.add(RouteDrawingLoadRoute(initialRoute));
        return;
      }
      if (effectiveOrigin != null) {
        _dispatchEndpoints(effectiveOrigin, setState);
      }
    });
  }

  void _dispatchEndpoints(LatLng origin, VoidCallback setState) {
    drawingBloc.add(
      RouteDrawingEndpointsSelected(
        origin: RoutePoint(
          lat: origin.latitude,
          lon: origin.longitude,
        ),
        destination: destController.markerDestination == null
            ? null
            : RoutePoint(
                lat: destController.markerDestination!.latitude,
                lon: destController.markerDestination!.longitude,
              ),
      ),
    );
    originController.isMyLocationOriginActive = true;
    destController.isMarkerDestinationActive =
        destController.markerDestination != null;
    setState();
  }
}
