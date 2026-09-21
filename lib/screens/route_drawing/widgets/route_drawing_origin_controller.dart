import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/models/models.dart';

/// Controller quản lý logic "Vị trí của tôi" làm điểm xuất phát trong Route Drawing.
///
/// Trách nhiệm:
/// - Xử lý toggle bật/tắt My Location Origin
/// - Resolve GPS position khi chưa có cache
/// - Dispatch event tới RouteDrawingBloc
class RouteDrawingOriginController {
  final MapDisplayCubit mapDisplayCubit;
  final RouteDrawingBloc drawingBloc;
  final VoidCallback onStateChanged;

  bool isMyLocationOriginActive = false;
  bool isResolvingMyLocationOrigin = false;

  RouteDrawingOriginController({
    required this.mapDisplayCubit,
    required this.drawingBloc,
    required this.onStateChanged,
  });

  /// Toggle trạng thái "Vị trí của tôi" làm origin.
  ///
  /// Nếu đang active → tắt.
  /// Nếu có cached position → dùng ngay.
  /// Nếu chưa có → request GPS rồi thêm.
  Future<void> handleToggle({
    LatLng? markerDestination,
    required bool mounted,
  }) async {
    if (isResolvingMyLocationOrigin) return;

    if (isMyLocationOriginActive) {
      isMyLocationOriginActive = false;
      onStateChanged();
      return;
    }

    final mapState = mapDisplayCubit.state;
    final cachedPosition =
        mapState.hasRealLocation ? mapState.currentPosition : null;
    if (cachedPosition != null) {
      _addOrigin(cachedPosition, markerDestination, mounted);
      return;
    }

    isResolvingMyLocationOrigin = true;
    onStateChanged();
    try {
      final currentPos = await mapDisplayCubit.acquireCurrentPosition();
      if (currentPos != null && mounted) {
        _addOrigin(currentPos, markerDestination, mounted);
      }
    } finally {
      if (mounted) {
        isResolvingMyLocationOrigin = false;
        onStateChanged();
      }
    }
  }

  void _addOrigin(LatLng pos, LatLng? markerDestination, bool mounted) {
    if (!mounted || drawingBloc.state.points.isNotEmpty) return;

    isMyLocationOriginActive = true;
    onStateChanged();

    drawingBloc.add(
      RouteDrawingEndpointsSelected(
        origin: RoutePoint(lat: pos.latitude, lon: pos.longitude),
        destination: markerDestination == null
            ? null
            : RoutePoint(
                lat: markerDestination.latitude,
                lon: markerDestination.longitude,
              ),
      ),
    );
  }
}
