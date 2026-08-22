import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/transformers/transformers.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'route_drawing_event.dart';
import 'route_drawing_state.dart';

class RouteDrawingBloc extends Bloc<RouteDrawingEvent, RouteDrawingState> {
  final IRoutingRepository _routingRepository;

  RouteDrawingBloc({required IRoutingRepository routingRepository})
      : _routingRepository = routingRepository,
        super(const RouteDrawingState()) {
    on<RouteDrawingPointTapped>(
      _onPointTapped,
      transformer: restartable(),
    );

    on<RouteDrawingUndoLastPoint>(_onUndoLastPoint);
    on<RouteDrawingRedoPoint>(_onRedoPoint);
    on<RouteDrawingClearRoute>(_onClearRoute);
    on<RouteDrawingSaveRoute>(_onSaveRoute);
  }

  /// Nối tất cả các điểm tọa độ từ các segment lại thành một chuỗi Polyline duy nhất
  static List<RoutePoint> _buildFullPolyline(List<RouteResult> segments) {
    final List<RoutePoint> fullList = [];
    for (final segment in segments) {
      for (int i = 0; i < segment.points.length; i++) {
        final pt = segment.points[i];
        if (pt.length >= 2) {
          final routePoint = RoutePoint(lat: pt[0], lon: pt[1]);
          // Tránh trùng lặp tọa độ tại điểm giao nhau giữa 2 segments liên tiếp
          if (fullList.isNotEmpty &&
              fullList.last.lat == routePoint.lat &&
              fullList.last.lon == routePoint.lon) {
            continue;
          }
          fullList.add(routePoint);
        }
      }
    }
    return List.unmodifiable(fullList);
  }

  Future<void> _onPointTapped(
    RouteDrawingPointTapped event,
    Emitter<RouteDrawingState> emit,
  ) async {
    final gen = state.requestGeneration + 1;
    DLog.info(
        '📍 [RouteDrawingBloc] Point tapped: (${event.lat}, ${event.lon}) [Gen #$gen]');

    emit(state.copyWith(
      status: RouteDrawingStatus.loading,
      requestGeneration: gen,
      clearWarning: true,
      clearError: true,
    ));

    try {
      final snapped = await _routingRepository.snapToRoad(
        lat: event.lat,
        lon: event.lon,
      );

      // Guard: kiểm tra emitter có bị hủy bởi restartable() trước khi tiếp tục
      if (emit.isDone) return;

      if (state.points.isEmpty) {
        // Điểm đầu tiên (Origin Waypoint)
        DLog.info(
            '🏁 [RouteDrawingBloc] Added origin point: (${snapped.snappedLat}, ${snapped.snappedLon})');
        emit(state.copyWith(
          status: RouteDrawingStatus.pointAdded,
          points: [snapped],
          segments: const [],
          fullPolyline: const [],
          totalDistance: 0.0,
          totalTime: 0,
          redoPoints: const [],
          redoSegments: const [],
          clearWarning: true,
          clearError: true,
        ));
        return;
      }

      // Đã có ít nhất 1 điểm trước đó -> Tự động tính toán nối đoạn đường (Auto-connect)
      final prevPoint = state.points.last;
      DLog.info(
          '🔄 [RouteDrawingBloc] Auto-connecting segment from (${prevPoint.snappedLat}, ${prevPoint.snappedLon}) to (${snapped.snappedLat}, ${snapped.snappedLon})');

      final routeResult = await _routingRepository.calculateRoute(
        fromLat: prevPoint.snappedLat,
        fromLon: prevPoint.snappedLon,
        toLat: snapped.snappedLat,
        toLon: snapped.snappedLon,
        vehicleProfile: state.profile,
      );

      if (emit.isDone) return;

      // 🛡️ Guard: Xác minh state.points không bị thay đổi (bởi Undo / Clear) trong lúc tính toán route
      if (state.points.isEmpty || state.points.last != prevPoint) {
        DLog.warning(
            '⚠️ [RouteDrawingBloc] State points changed during route calculation, ignoring stale result.');
        return;
      }

      final newPoints = [...state.points, snapped];

      if (routeResult.isSuccess) {
        final newSegments = [...state.segments, routeResult];
        final newPolyline = _buildFullPolyline(newSegments);
        final newDistance = state.totalDistance + routeResult.distance;
        final newTime = state.totalTime + routeResult.time;

        DLog.info(
            '✅ [RouteDrawingBloc] Segment connected: +${routeResult.distance}m, total=${newDistance}m, points=${newPoints.length}');

        emit(state.copyWith(
          status: RouteDrawingStatus.routeUpdated,
          points: newPoints,
          segments: newSegments,
          fullPolyline: newPolyline,
          totalDistance: newDistance,
          totalTime: newTime,
          redoPoints: const [],
          redoSegments: const [],
          clearWarning: true,
          clearError: true,
        ));
      } else {
        DLog.warning(
            '⚠️ [RouteDrawingBloc] Failed to connect segment: ${routeResult.errorMessage}');
        emit(state.copyWith(
          status: RouteDrawingStatus.warning,
          points: newPoints,
          warningMessageKey:
              routeResult.errorMessage ?? LocaleKeys.routing_error_generic,
          redoPoints: const [],
          redoSegments: const [],
        ));
      }
    } catch (e, stack) {
      if (emit.isDone) return;
      DLog.error('❌ [RouteDrawingBloc] Error handling point tap: $e', e, stack);
      emit(state.copyWith(
        status: RouteDrawingStatus.error,
        errorMessageKey: LocaleKeys.routing_error_generic,
      ));
    }
  }

  void _onUndoLastPoint(
    RouteDrawingUndoLastPoint event,
    Emitter<RouteDrawingState> emit,
  ) {
    if (state.points.isEmpty) return;

    DLog.info('↩️ [RouteDrawingBloc] Undo last point');

    if (state.points.length == 1) {
      final poppedPoint = state.points.last;
      emit(state.copyWith(
        status: RouteDrawingStatus.initial,
        points: const [],
        segments: const [],
        fullPolyline: const [],
        totalDistance: 0.0,
        totalTime: 0,
        redoPoints: [...state.redoPoints, poppedPoint],
        redoSegments: [...state.redoSegments, null],
        clearWarning: true,
        clearError: true,
      ));
      return;
    }

    final poppedPoint = state.points.last;
    // Điểm cuối có segment nối kèm nếu số lượng segments đúng bằng (số points - 1)
    final hasSegmentForLastPoint =
        state.segments.length == state.points.length - 1;
    final poppedSegment =
        hasSegmentForLastPoint && state.segments.isNotEmpty
            ? state.segments.last
            : null;

    final newPoints = state.points.sublist(0, state.points.length - 1);
    final newSegments = (hasSegmentForLastPoint && state.segments.isNotEmpty)
        ? state.segments.sublist(0, state.segments.length - 1)
        : state.segments;

    final newPolyline = _buildFullPolyline(newSegments);
    final newDistance =
        newSegments.fold<double>(0.0, (sum, seg) => sum + seg.distance);
    final newTime = newSegments.fold<int>(0, (sum, seg) => sum + seg.time);

    final newRedoPoints = [...state.redoPoints, poppedPoint];
    final newRedoSegments = [...state.redoSegments, poppedSegment];

    emit(state.copyWith(
      status: newSegments.isNotEmpty
          ? RouteDrawingStatus.routeUpdated
          : RouteDrawingStatus.pointAdded,
      points: newPoints,
      segments: newSegments,
      fullPolyline: newPolyline,
      totalDistance: newDistance,
      totalTime: newTime,
      redoPoints: newRedoPoints,
      redoSegments: newRedoSegments,
      clearWarning: true,
      clearError: true,
    ));
  }

  void _onRedoPoint(
    RouteDrawingRedoPoint event,
    Emitter<RouteDrawingState> emit,
  ) {
    if (state.redoPoints.isEmpty) return;

    DLog.info('↪️ [RouteDrawingBloc] Redo point');

    final pointToRestore = state.redoPoints.last;
    final newRedoPoints =
        state.redoPoints.sublist(0, state.redoPoints.length - 1);

    final segmentToRestore =
        state.redoSegments.isNotEmpty ? state.redoSegments.last : null;
    final newRedoSegments = state.redoSegments.isNotEmpty
        ? state.redoSegments.sublist(0, state.redoSegments.length - 1)
        : const <RouteResult?>[];

    final newPoints = [...state.points, pointToRestore];

    if (segmentToRestore != null) {
      final newSegments = [...state.segments, segmentToRestore];
      final newPolyline = _buildFullPolyline(newSegments);
      final newDistance =
          newSegments.fold<double>(0.0, (sum, seg) => sum + seg.distance);
      final newTime = newSegments.fold<int>(0, (sum, seg) => sum + seg.time);

      emit(state.copyWith(
        status: RouteDrawingStatus.routeUpdated,
        points: newPoints,
        segments: newSegments,
        fullPolyline: newPolyline,
        totalDistance: newDistance,
        totalTime: newTime,
        redoPoints: newRedoPoints,
        redoSegments: newRedoSegments,
        clearWarning: true,
        clearError: true,
      ));
    } else {
      emit(state.copyWith(
        status: state.segments.isNotEmpty
            ? RouteDrawingStatus.routeUpdated
            : RouteDrawingStatus.pointAdded,
        points: newPoints,
        redoPoints: newRedoPoints,
        redoSegments: newRedoSegments,
        clearWarning: true,
        clearError: true,
      ));
    }
  }

  void _onClearRoute(
    RouteDrawingClearRoute event,
    Emitter<RouteDrawingState> emit,
  ) {
    DLog.info('🧹 [RouteDrawingBloc] Clear route');
    emit(RouteDrawingState(profile: state.profile));
  }

  void _onSaveRoute(
    RouteDrawingSaveRoute event,
    Emitter<RouteDrawingState> emit,
  ) {
    DLog.info('💾 [RouteDrawingBloc] Save route: "${event.name}"');
    if (state.points.length < 2 || !state.hasRoute) {
      emit(state.copyWith(
        status: RouteDrawingStatus.warning,
        warningMessageKey: LocaleKeys.routing_error_generic,
      ));
      return;
    }

    emit(state.copyWith(
      status: RouteDrawingStatus.saved,
      clearWarning: true,
      clearError: true,
    ));
  }
}
