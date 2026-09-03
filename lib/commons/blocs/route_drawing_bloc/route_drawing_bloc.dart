import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/transformers/transformers.dart';
import 'package:s_map/commons/utils/app_utils.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';
import 'route_drawing_event.dart';
import 'route_drawing_state.dart';

class RouteDrawingBloc extends Bloc<RouteDrawingEvent, RouteDrawingState> {
  final IRoutingRepository _routingRepository;
  final ICustomRouteRepository _customRouteRepository;
  int _currentGeneration = 0;

  /// Optional global default repository resolver set during bootstrap
  static ICustomRouteRepository? defaultCustomRouteRepository;

  RouteDrawingBloc({
    required IRoutingRepository routingRepository,
    ICustomRouteRepository? customRouteRepository,
  })  : _routingRepository = routingRepository,
        _customRouteRepository = customRouteRepository ??
            defaultCustomRouteRepository ??
            (AppReposProvider.isInitialized
                ? AppReposProvider.instance.customRouteRepos
                : const NoOpCustomRouteRepository()),
        super(const RouteDrawingState()) {
    on<RouteDrawingPointTapped>(
      _onPointTapped,
      transformer: restartable(),
    );
    on<RouteDrawingEndpointsSelected>(_onEndpointsSelected);

    on<RouteDrawingUndoLastPoint>(_onUndoLastPoint);
    on<RouteDrawingRedoPoint>(_onRedoPoint);
    on<RouteDrawingClearRoute>(_onClearRoute);
    on<RouteDrawingSaveRoute>(_onSaveRoute);
    on<RouteDrawingLoadRoute>(_onLoadRoute);
    on<RouteDrawingReverseRoute>(_onReverseRoute);
    on<RouteDrawingChangeProfile>(_onChangeProfile, transformer: restartable());
    on<RouteDrawingToggleStraightLineMode>(_onToggleStraightLineMode);
  }

  void _onToggleStraightLineMode(
    RouteDrawingToggleStraightLineMode event,
    Emitter<RouteDrawingState> emit,
  ) {
    final nextMode = !state.isStraightLineMode;
    DLog.info('✈️ [RouteDrawingBloc] Straight-line mode toggled: $nextMode');
    emit(state.copyWith(isStraightLineMode: nextMode));
  }

  /// Vận tốc ước tính trung bình theo profile phương tiện (km/h) cho đường chim bay
  static double _getProfileSpeedKmh(String profile) {
    if (profile == RoutingConstants.profileFoot) return 4.5;
    if (profile == RoutingConstants.profileBike) return 12.0;
    if (profile == RoutingConstants.profileCar) return 30.0;
    return 20.0; // default moped / motorcycle
  }

  /// Nối tất cả các điểm tọa độ từ các segment lại thành một chuỗi Polyline duy nhất
  static List<RoutePoint> _buildFullPolyline(List<RouteResult> segments) {
    final List<RoutePoint> fullList = [];
    for (final segment in segments) {
      if (segment.points.isNotEmpty) {
        for (final coord in segment.points) {
          final routePoint = RoutePoint(lat: coord[0], lon: coord[1]);
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

  Future<void> _onEndpointsSelected(
    RouteDrawingEndpointsSelected event,
    Emitter<RouteDrawingState> emit,
  ) async {
    final generation = ++_currentGeneration;
    final origin = SnappedRoadPoint(
      originalLat: event.origin.lat,
      originalLon: event.origin.lon,
      snappedLat: event.origin.lat,
      snappedLon: event.origin.lon,
      isSnapped: true,
      distanceToRoad: 0,
    );

    if (event.destination == null) {
      // The GPS origin already has a trusted coordinate. Do not put the
      // drawing screen through a loading state or a snap/routing request just
      // to add its first point; that transition must be synchronous from the
      // user's perspective.
      emit(state.copyWith(
        status: RouteDrawingStatus.pointAdded,
        points: [origin],
        segments: const [],
        fullPolyline: const [],
        totalDistance: 0,
        totalTime: 0,
        redoPoints: const [],
        redoSegments: const [],
        requestGeneration: generation,
      ));
      return;
    }

    emit(state.copyWith(
      status: RouteDrawingStatus.loading,
      requestGeneration: generation,
      clearWarning: true,
      clearError: true,
    ));

    final destination = SnappedRoadPoint(
      originalLat: event.destination!.lat,
      originalLon: event.destination!.lon,
      snappedLat: event.destination!.lat,
      snappedLon: event.destination!.lon,
      isSnapped: true,
      distanceToRoad: 0,
    );
    final route = await _routingRepository.calculateRoute(
      fromLat: origin.snappedLat,
      fromLon: origin.snappedLon,
      toLat: destination.snappedLat,
      toLon: destination.snappedLon,
      vehicleProfile: state.profile,
    );

    if (isClosed || emit.isDone || generation != _currentGeneration) return;

    if (route.isSuccess) {
      emit(state.copyWith(
        status: RouteDrawingStatus.routeUpdated,
        points: [origin, destination],
        segments: [route],
        fullPolyline: _buildFullPolyline([route]),
        totalDistance: route.distance,
        totalTime: route.time,
        redoPoints: const [],
        redoSegments: const [],
        requestGeneration: generation,
        clearWarning: true,
        clearError: true,
      ));
    } else {
      emit(state.copyWith(
        status: RouteDrawingStatus.error,
        points: [origin, destination],
        requestGeneration: generation,
        errorMessageKey: route.errorMessage ?? LocaleKeys.routing_error_generic,
        clearWarning: true,
      ));
    }
  }

  Future<void> _onPointTapped(
    RouteDrawingPointTapped event,
    Emitter<RouteDrawingState> emit,
  ) async {
    final generation = ++_currentGeneration;
    DLog.info(
        '📍 [RouteDrawingBloc] Point tapped: (${event.lat}, ${event.lon}) [Gen #$generation]');

    final isStraight = event.isStraightLine ?? state.isStraightLineMode;

    if (isStraight) {
      // ✈️ CHẾ ĐỘ ĐƯỜNG CHIM BAY (Direct Line / Beeline Mode)
      // Bỏ qua Snap-to-road và GraphHopper calculateRoute
      final effectivePoint = SnappedRoadPoint(
        originalLat: event.lat,
        originalLon: event.lon,
        snappedLat: event.lat,
        snappedLon: event.lon,
        isSnapped: false,
        distanceToRoad: 0.0,
      );

      if (state.points.isEmpty) {
        DLog.info(
            '✈️ [RouteDrawingBloc] Added origin point in straight-line mode: (${event.lat}, ${event.lon})');
        emit(state.copyWith(
          status: RouteDrawingStatus.pointAdded,
          points: [effectivePoint],
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

      final prevPoint = state.points.last;
      final distanceKm = AppUtils.instance.calculateDistance(
        prevPoint.snappedLat,
        prevPoint.snappedLon,
        effectivePoint.snappedLat,
        effectivePoint.snappedLon,
      );
      final distanceMeters = distanceKm * 1000.0;
      final speedKmh = _getProfileSpeedKmh(state.profile);
      final durationMs = (distanceKm / speedKmh * 3600000).round();

      final straightLineRoute = RouteResult(
        isSuccess: true,
        distance: distanceMeters,
        time: durationMs,
        points: [
          [prevPoint.snappedLat, prevPoint.snappedLon],
          [effectivePoint.snappedLat, effectivePoint.snappedLon],
        ],
        routeTitle: 'Đường chim bay',
        isStraightLine: true,
      );

      final newPoints = [...state.points, effectivePoint];
      final newSegments = [...state.segments, straightLineRoute];
      final newPolyline = _buildFullPolyline(newSegments);
      final newDistance = state.totalDistance + straightLineRoute.distance;
      final newTime = state.totalTime + straightLineRoute.time;

      DLog.info(
          '✈️ [RouteDrawingBloc] Straight-line segment connected: +${straightLineRoute.distance.toStringAsFixed(1)}m, total=${newDistance.toStringAsFixed(1)}m, points=${newPoints.length}');

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
      return;
    }

    emit(state.copyWith(
      status: RouteDrawingStatus.loading,
      requestGeneration: generation,
      clearWarning: true,
      clearError: true,
    ));

    try {
      final snapped = await _routingRepository.snapToRoad(
        lat: event.lat,
        lon: event.lon,
      );

      // 1. Kiểm tra Snap to Road:
      // Nếu không snap được hoặc khoảng cách snap > 25m (đang chấm trong hẻm nhưng bị hút ra mặt đường lớn),
      // ưu tiên giữ nguyên vị trí chạm chính xác của người dùng trong hẻm.
      final SnappedRoadPoint effectiveSnapped;
      if (snapped.isSnapped && snapped.distanceToRoad <= 25.0) {
        effectiveSnapped = snapped;
      } else {
        effectiveSnapped = SnappedRoadPoint(
          originalLat: event.lat,
          originalLon: event.lon,
          snappedLat: event.lat,
          snappedLon: event.lon,
          isSnapped: true,
          streetName: snapped.streetName.isNotEmpty ? snapped.streetName : '',
          distanceToRoad: 0.0,
        );
      }

      // Guard: kiểm tra emitter hoặc generation có bị thay đổi (bởi tap mới, undo, clear)
      if (isClosed || emit.isDone || generation != _currentGeneration) {
        DLog.info(
            '⏭️ [RouteDrawingBloc] Stale snap response ignored (Current gen #$_currentGeneration vs #$generation)');
        return;
      }

      if (state.points.isEmpty) {
        // Điểm đầu tiên (Origin Waypoint)
        DLog.info(
            '🏁 [RouteDrawingBloc] Added origin point: (${effectiveSnapped.snappedLat}, ${effectiveSnapped.snappedLon})');
        emit(state.copyWith(
          status: RouteDrawingStatus.pointAdded,
          points: [effectiveSnapped],
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
          '🔄 [RouteDrawingBloc] Auto-connecting segment from (${prevPoint.snappedLat}, ${prevPoint.snappedLon}) to (${effectiveSnapped.snappedLat}, ${effectiveSnapped.snappedLon})');

      final routeResult = await _routingRepository.calculateRoute(
        fromLat: prevPoint.snappedLat,
        fromLon: prevPoint.snappedLon,
        toLat: effectiveSnapped.snappedLat,
        toLon: effectiveSnapped.snappedLon,
        vehicleProfile: state.profile,
      );

      if (isClosed || emit.isDone || generation != _currentGeneration) {
        DLog.info(
            '⏭️ [RouteDrawingBloc] Stale route response ignored (Current gen #$_currentGeneration vs #$generation)');
        return;
      }

      // 🛡️ Guard: Xác minh state.points không bị thay đổi (bởi Undo / Clear) trong lúc tính toán route
      if (state.points.isEmpty || state.points.last != prevPoint) {
        DLog.warning(
            '⚠️ [RouteDrawingBloc] State points changed during route calculation, ignoring stale result.');
        return;
      }

      final newPoints = [...state.points, effectiveSnapped];

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
        // Fallback: Khi đường hẻm nhỏ hoặc lối đi nội bộ không có trên đồ thị tự động của OSM,
        // tự động tạo segment nối trực tiếp (Direct Connection) để người dùng vẽ thông suốt mọi ngõ ngách!
        final distKm = AppUtils.instance.calculateDistance(
          prevPoint.snappedLat,
          prevPoint.snappedLon,
          effectiveSnapped.snappedLat,
          effectiveSnapped.snappedLon,
        );
        final distMeters = distKm * 1000.0;
        final estTimeMs = ((distMeters / (15.0 / 3.6)) * 1000).round();

        final fallbackSegment = RouteResult(
          isSuccess: true,
          distance: distMeters,
          time: estTimeMs,
          points: [
            [prevPoint.snappedLat, prevPoint.snappedLon],
            [effectiveSnapped.snappedLat, effectiveSnapped.snappedLon],
          ],
        );
        final newSegments = [...state.segments, fallbackSegment];
        final newPolyline = _buildFullPolyline(newSegments);
        final newDistance = state.totalDistance + distMeters;
        final newTime = state.totalTime + estTimeMs;

        DLog.info(
            '🔗 [RouteDrawingBloc] Direct segment connected into alley: +${distMeters.toStringAsFixed(1)}m, total=${newDistance.toStringAsFixed(1)}m');

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
      }
    } catch (e, stack) {
      if (isClosed || emit.isDone || generation != _currentGeneration) return;
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
    _currentGeneration++;
    DLog.info(
        '↩️ [RouteDrawingBloc] Undo last point [Gen #$_currentGeneration]');

    if (state.points.isEmpty) {
      if (state.isLoading) {
        emit(state.copyWith(
          status: RouteDrawingStatus.initial,
          requestGeneration: _currentGeneration,
          clearWarning: true,
          clearError: true,
        ));
      }
      return;
    }

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
        requestGeneration: _currentGeneration,
        clearWarning: true,
        clearError: true,
      ));
      return;
    }

    final poppedPoint = state.points.last;
    // Điểm cuối có segment nối kèm nếu số lượng segments đúng bằng (số points - 1)
    final hasSegmentForLastPoint =
        state.segments.length == state.points.length - 1;
    final poppedSegment = hasSegmentForLastPoint && state.segments.isNotEmpty
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
      requestGeneration: _currentGeneration,
      clearWarning: true,
      clearError: true,
    ));
  }

  void _onRedoPoint(
    RouteDrawingRedoPoint event,
    Emitter<RouteDrawingState> emit,
  ) {
    _currentGeneration++;
    if (state.redoPoints.isEmpty) {
      if (state.isLoading) {
        emit(state.copyWith(
          status: state.segments.isNotEmpty
              ? RouteDrawingStatus.routeUpdated
              : (state.points.isNotEmpty
                  ? RouteDrawingStatus.pointAdded
                  : RouteDrawingStatus.initial),
          requestGeneration: _currentGeneration,
          clearWarning: true,
          clearError: true,
        ));
      }
      return;
    }

    DLog.info('↪️ [RouteDrawingBloc] Redo point [Gen #$_currentGeneration]');

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
        requestGeneration: _currentGeneration,
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
        requestGeneration: _currentGeneration,
        clearWarning: true,
        clearError: true,
      ));
    }
  }

  void _onClearRoute(
    RouteDrawingClearRoute event,
    Emitter<RouteDrawingState> emit,
  ) {
    _currentGeneration++;
    DLog.info('🧹 [RouteDrawingBloc] Clear route [Gen #$_currentGeneration]');
    emit(RouteDrawingState(
      profile: state.profile,
      requestGeneration: _currentGeneration,
    ));
  }

  Future<void> _onSaveRoute(
    RouteDrawingSaveRoute event,
    Emitter<RouteDrawingState> emit,
  ) async {
    final saveGeneration = ++_currentGeneration;
    DLog.info(
        '💾 [RouteDrawingBloc] Save route: "${event.name}" [Gen #$saveGeneration]');
    if (state.points.length < 2 || !state.hasRoute) {
      if (isClosed || emit.isDone || saveGeneration != _currentGeneration) {
        return;
      }
      emit(state.copyWith(
        status: RouteDrawingStatus.warning,
        warningMessageKey: LocaleKeys.routing_error_generic,
      ));
      return;
    }

    try {
      final now = DateTime.now();
      final routeId = state.savedRoute?.id.isNotEmpty == true
          ? state.savedRoute!.id
          : 'route_${now.millisecondsSinceEpoch}';

      final routeName = (event.name != null && event.name!.trim().isNotEmpty)
          ? event.name!.trim()
          : (state.savedRoute?.name ?? 'Route_${now.millisecondsSinceEpoch}');

      final customRoute = CustomRouteModel(
        id: routeId,
        name: routeName,
        waypoints: state.points,
        fullPolyline: state.fullPolyline.map((p) => [p.lat, p.lon]).toList(),
        totalDistance: state.totalDistance,
        totalTime: state.totalTime,
        profile: state.profile,
        createdAt: state.savedRoute?.createdAt ?? now,
        updatedAt: now,
        description: event.description ?? state.savedRoute?.description,
      );

      await _customRouteRepository.saveRoute(customRoute);

      if (isClosed || emit.isDone || saveGeneration != _currentGeneration) {
        return;
      }

      DLog.info(
          '💾 [RouteDrawingBloc] Route saved to Hive: "${customRoute.name}" (${customRoute.id})');
      emit(state.copyWith(
        status: RouteDrawingStatus.saved,
        savedRoute: customRoute,
        clearWarning: true,
        clearError: true,
      ));
    } catch (e, stack) {
      if (isClosed || emit.isDone || saveGeneration != _currentGeneration) {
        return;
      }
      DLog.error('❌ [RouteDrawingBloc] Error saving route: $e', e, stack);
      emit(state.copyWith(
        status: RouteDrawingStatus.error,
        errorMessageKey: LocaleKeys.routing_error_generic,
      ));
    }
  }

  void _onLoadRoute(
    RouteDrawingLoadRoute event,
    Emitter<RouteDrawingState> emit,
  ) {
    _currentGeneration++;
    final route = event.route;
    DLog.info(
        '📂 [RouteDrawingBloc] Loading route "${route.name}" (${route.waypoints.length} waypoints) [Gen #$_currentGeneration]');

    final polylinePoints = route.fullPolyline
        .map((coord) => RoutePoint(lat: coord[0], lon: coord[1]))
        .toList();

    final initialSegments = route.fullPolyline.isNotEmpty
        ? [
            RouteResult(
              isSuccess: true,
              distance: route.totalDistance,
              time: route.totalTime,
              points: route.fullPolyline,
            ),
          ]
        : const <RouteResult>[];

    emit(RouteDrawingState(
      status: RouteDrawingStatus.routeUpdated,
      points: route.waypoints,
      segments: initialSegments,
      fullPolyline: polylinePoints,
      totalDistance: route.totalDistance,
      totalTime: route.totalTime,
      profile: route.profile,
      redoPoints: const [],
      redoSegments: const [],
      savedRoute: route,
      requestGeneration: _currentGeneration,
    ));
  }

  void _onReverseRoute(
    RouteDrawingReverseRoute event,
    Emitter<RouteDrawingState> emit,
  ) {
    if (state.points.length < 2) return;

    _currentGeneration++;
    DLog.info(
        '🔄 [RouteDrawingBloc] Reversing route with ${state.points.length} points [Gen #$_currentGeneration]');

    final reversedPoints = state.points.reversed.toList();
    final reversedPolyline = state.fullPolyline.reversed.toList();

    final reversedSegments = state.segments.reversed.map((seg) {
      return RouteResult(
        isSuccess: seg.isSuccess,
        distance: seg.distance,
        time: seg.time,
        points: seg.points.reversed.toList(),
        instructions: seg.instructions.reversed.toList(),
        errorMessage: seg.errorMessage,
        routeTitle: seg.routeTitle,
        isAlternative: seg.isAlternative,
        isStraightLine: seg.isStraightLine,
      );
    }).toList();

    emit(state.copyWith(
      status: RouteDrawingStatus.routeUpdated,
      points: reversedPoints,
      segments: reversedSegments,
      fullPolyline: reversedPolyline,
      redoPoints: const [],
      redoSegments: const [],
      requestGeneration: _currentGeneration,
      clearWarning: true,
      clearError: true,
    ));
  }

  Future<void> _onChangeProfile(
    RouteDrawingChangeProfile event,
    Emitter<RouteDrawingState> emit,
  ) async {
    if (state.profile == event.profile) return;

    final generation = ++_currentGeneration;
    DLog.info(
        '🚗 [RouteDrawingBloc] Changing profile to "${event.profile}" [Gen #$generation]');

    if (state.points.length < 2) {
      emit(state.copyWith(profile: event.profile));
      return;
    }

    emit(state.copyWith(
      status: RouteDrawingStatus.loading,
      profile: event.profile,
      requestGeneration: generation,
      clearWarning: true,
      clearError: true,
    ));

    final newSegments = <RouteResult>[];
    double totalDist = 0.0;
    int totalTime = 0;

    for (int i = 0; i < state.points.length - 1; i++) {
      final from = state.points[i];
      final to = state.points[i + 1];

      // Nếu segment này là đường chim bay, bảo toàn đường thẳng và chỉ ước lượng lại thời gian theo profile mới
      if (i < state.segments.length && state.segments[i].isStraightLine) {
        final origSeg = state.segments[i];
        final distKm = origSeg.distance / 1000.0;
        final speedKmh = _getProfileSpeedKmh(event.profile);
        final newTime = (distKm / speedKmh * 3600000).round();
        final updatedSeg = origSeg.copyWith(time: newTime);
        newSegments.add(updatedSeg);
        totalDist += updatedSeg.distance;
        totalTime += updatedSeg.time;
        continue;
      }

      final seg = await _routingRepository.calculateRoute(
        fromLat: from.snappedLat,
        fromLon: from.snappedLon,
        toLat: to.snappedLat,
        toLon: to.snappedLon,
        vehicleProfile: event.profile,
      );

      if (generation != _currentGeneration || isClosed || emit.isDone) return;

      if (seg.isSuccess) {
        newSegments.add(seg);
        totalDist += seg.distance;
        totalTime += seg.time;
      } else {
        final distKm = AppUtils.instance.calculateDistance(
          from.snappedLat,
          from.snappedLon,
          to.snappedLat,
          to.snappedLon,
        );
        final distMeters = distKm * 1000.0;
        final estTimeMs = ((distMeters / (15.0 / 3.6)) * 1000).round();
        final fallback = RouteResult(
          isSuccess: true,
          distance: distMeters,
          time: estTimeMs,
          points: [
            [from.snappedLat, from.snappedLon],
            [to.snappedLat, to.snappedLon],
          ],
        );
        newSegments.add(fallback);
        totalDist += distMeters;
        totalTime += estTimeMs;
      }
    }

    final newPolyline = _buildFullPolyline(newSegments);
    emit(state.copyWith(
      status: RouteDrawingStatus.routeUpdated,
      segments: newSegments,
      fullPolyline: newPolyline,
      totalDistance: totalDist,
      totalTime: totalTime,
      clearWarning: true,
      clearError: true,
    ));
  }
}
