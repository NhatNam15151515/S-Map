import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/utils/map_geometry_utils.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/routers/app_routes.dart';

/// Controller quản lý logic điểm đích (marker destination) trong Route Drawing.
///
/// Trách nhiệm:
/// - Toggle bật/tắt marker destination
/// - Xóa marker destination (undo điểm cuối nếu trùng)
/// - Mở destination picker mode
/// - Tìm kiếm destination qua Search screen
class RouteDrawingDestinationController {
  final MapDisplayCubit mapDisplayCubit;
  final RouteDrawingBloc drawingBloc;
  final AreaSearchDestinationResolver areaSearchResolver;
  final VoidCallback onStateChanged;

  LatLng? markerDestination;
  bool isMarkerDestinationActive = false;
  bool isDestinationPickerActive = false;
  bool isCrosshairActive = true;

  RouteDrawingDestinationController({
    required this.mapDisplayCubit,
    required this.drawingBloc,
    required this.areaSearchResolver,
    required this.onStateChanged,
  });

  /// Toggle trạng thái hiển thị marker destination.
  void handleToggle() {
    if (markerDestination == null) {
      isDestinationPickerActive = true;
      isCrosshairActive = false;
      onStateChanged();
      return;
    }

    if (isMarkerDestinationActive) {
      isMarkerDestinationActive = false;
      onStateChanged();
      return;
    }

    isMarkerDestinationActive = true;
    onStateChanged();
    mapDisplayCubit.zoomToLevel(16.0, center: markerDestination);

    if (drawingBloc.state.points.isNotEmpty) {
      final lastPoint = drawingBloc.state.points.last;
      final isAlreadyLast = MapGeometryUtils.isNearCoordinate(
        lastPoint.snappedLat,
        lastPoint.snappedLon,
        markerDestination!.latitude,
        markerDestination!.longitude,
      );
      if (!isAlreadyLast) {
        drawingBloc.add(
          RouteDrawingPointTapped(
            lat: markerDestination!.latitude,
            lon: markerDestination!.longitude,
          ),
        );
      }
    }
  }

  /// Xóa marker destination hoàn toàn (undo điểm cuối nếu trùng tọa độ).
  void handleRemove() {
    final state = drawingBloc.state;
    if (isMarkerDestinationActive && state.points.length >= 2) {
      final lastPoint = state.points.last;
      if (markerDestination != null &&
          MapGeometryUtils.isNearCoordinate(
            lastPoint.snappedLat,
            lastPoint.snappedLon,
            markerDestination!.latitude,
            markerDestination!.longitude,
          )) {
        drawingBloc.add(const RouteDrawingUndoLastPoint());
      }
    }
    markerDestination = null;
    isMarkerDestinationActive = false;
    isDestinationPickerActive = false;
    onStateChanged();
  }

  /// Hủy chế độ chọn điểm đích trên bản đồ.
  void handleCancelPicker() {
    isDestinationPickerActive = false;
    isCrosshairActive = true;
    onStateChanged();
  }

  /// Xác nhận điểm đích từ center map.
  void handleConfirmPicker(LatLng center) {
    HapticFeedback.mediumImpact();
    setMarkerDestination(
      center,
      addToRoute: drawingBloc.state.points.isNotEmpty,
    );
  }

  /// Đặt marker destination tại một tọa độ.
  void setMarkerDestination(LatLng destination, {bool addToRoute = false}) {
    markerDestination = destination;
    isDestinationPickerActive = false;
    isMarkerDestinationActive = true;
    isCrosshairActive = true;
    onStateChanged();

    if (addToRoute && drawingBloc.state.points.isNotEmpty) {
      drawingBloc.add(
        RouteDrawingPointTapped(
          lat: destination.latitude,
          lon: destination.longitude,
        ),
      );
    }
  }

  /// Mở Search screen và resolve kết quả thành destination.
  Future<void> handleSearch(BuildContext context, bool mounted) async {
    final mapState = mapDisplayCubit.state;
    final searchCenter = mapState.currentPosition ?? mapState.center;
    final result = await context.push<dynamic>(
      AppRoutes.search,
      extra: searchCenter,
    );
    if (!mounted || result == null) return;

    LatLng? destination;
    PoiModel? poi;

    if (result is SearchResultPayload) {
      if (result.isSingle) {
        poi = result.selectedPoi;
        if (poi != null) destination = LatLng(poi.lat, poi.lon);
      } else if (result.isAll &&
          result.allResults != null &&
          result.allResults!.isNotEmpty) {
        poi = result.allResults!.first;
        destination = LatLng(poi.lat, poi.lon);
      } else if (result.isLocation && result.searchCenter != null) {
        destination = result.searchCenter;
      } else if (result.isArea) {
        final center = result.searchCenter ??
            mapDisplayCubit.state.center ??
            MapConstants.defaultLocation;
        poi = await areaSearchResolver.resolve(result, center: center);
        if (poi != null) destination = LatLng(poi.lat, poi.lon);
      }
    } else if (result is PoiModel) {
      poi = result;
      destination = LatLng(poi.lat, poi.lon);
    }
    if (destination == null) return;

    if (poi != null) {
      mapDisplayCubit.selectPoi(poi);
    } else {
      mapDisplayCubit.zoomToLevel(16.0, center: destination);
    }
    setMarkerDestination(destination, addToRoute: true);
  }
}
