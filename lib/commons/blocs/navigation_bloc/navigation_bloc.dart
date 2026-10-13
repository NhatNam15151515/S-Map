import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:s_map/commons/fallbacks/fallbacks.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/transformers/transformers.dart';
import 'package:s_map/commons/usecases/usecases.dart';
import 'package:s_map/commons/utils/map_geometry_utils.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'navigation_event.dart';
import 'navigation_state.dart';

export 'navigation_event.dart';
export 'navigation_state.dart';

/// Bộ điều khiển máy trạng thái dẫn đường (Lean Navigation Finite State Machine)
///
/// Tuân thủ nguyên tắc Clean Architecture chuẩn Google:
/// * Thao tác chuyển đổi trạng thái giao diện được tối ưu hoá qua [NavigationState].
/// * Ủy quyền số liệu và deadband cho [TripMetricsTracker].
/// * Ủy quyền lưu trữ và hoàn tất chuyến đi cho [NavigationPersistenceCoordinator].
/// * Ủy quyền chính sách thiết bị cho [NavigationDevicePolicy].
/// * Ủy quyền tính toán toạ độ và snap cho [NavigationTrackingCoordinator].
class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  final IRoutingRepository _routingRepository;
  final ILocationService _locationService;

  // Domain Subsystems
  final TripMetricsTracker _metricsTracker;
  final NavigationPersistenceCoordinator _persistenceCoordinator;
  final NavigationDevicePolicy _devicePolicy;
  final NavigationTrackingCoordinator _trackingCoordinator;

  /// Bộ lọc Kalman 2D — làm mượt tọa độ GPS thô trước khi truyền vào
  /// TrackingCoordinator và OffRouteDetector. Giảm hiện tượng marker giật
  /// khi xe máy đi qua hẻm sâu, gầm cầu, hoặc khu vực GPS multipath.
  final GpsKalmanFilter _kalmanFilter = GpsKalmanFilter();

  StreamSubscription<Position>? _locationSubscription;
  int _requestGeneration = 0;
  DateTime? _lastRerouteTime;
  DateTime? _lastGpsTimestamp;

  /// Optional global default service resolvers set by the composition root
  static ILocationService? defaultLocationService;
  static ITurnByTurnEngine? defaultTurnByTurnEngine;
  static IDeviceInfoService? defaultDeviceInfoService;
  static IActiveTripService? defaultActiveTripService;
  static IVisitedPoiService? defaultVisitedPoiService;

  /// Cần hai fix liên tiếp để bỏ qua một lần GPS nhảy đơn lẻ; với stream 500ms,
  /// xác nhận lệch tuyến thường hoàn tất trong khoảng một giây.
  static const int minConsecutiveOffRouteTicks = 2;

  /// Ngưỡng vận tốc tối thiểu (km/h) để cho phép tự động tính lại đường (tránh trôi dạt khi đứng yên)
  static const double minMovingSpeedForRerouteKmh = 5.0;

  /// Chặn lặp route do GPS rung nhưng vẫn cho phép route đổi nhanh sau khi lệch thật.
  static const Duration _rerouteCooldown = Duration(milliseconds: 1500);

  int _consecutiveOffRouteTicks = 0;

  NavigationBloc({
    required IRoutingRepository routingRepository,
    required ITripRepository tripRepository,
    ILocationService? locationService,
    IOffRouteDetector? offRouteDetector,
    ITurnByTurnEngine? turnByTurnEngine,
    IDeviceInfoService? deviceInfoService,
    IActiveTripService? activeTripService,
    IVisitedPoiService? visitedPoiService,
    TripMetricsTracker? metricsTracker,
    NavigationPersistenceCoordinator? persistenceCoordinator,
    NavigationDevicePolicy? devicePolicy,
    NavigationTrackingCoordinator? trackingCoordinator,
  }) : _routingRepository = routingRepository,
       _locationService =
           locationService ??
           defaultLocationService ??
           const NoOpLocationService(),
       _metricsTracker = metricsTracker ?? TripMetricsTracker(),
       _persistenceCoordinator =
           persistenceCoordinator ??
           NavigationPersistenceCoordinator(
             tripRepository: tripRepository,
             activeTripService:
                 activeTripService ??
                 defaultActiveTripService ??
                 const NoOpActiveTripService(),
             visitedPoiService:
                 visitedPoiService ??
                 defaultVisitedPoiService ??
                 const NoOpVisitedPoiService(),
           ),
       _devicePolicy =
           devicePolicy ??
           NavigationDevicePolicy(
             locationService:
                 locationService ??
                 defaultLocationService ??
                 const NoOpLocationService(),
             deviceInfoService:
                 deviceInfoService ??
                 defaultDeviceInfoService ??
                 const NoOpDeviceInfoService(),
           ),
       _trackingCoordinator =
           trackingCoordinator ??
           NavigationTrackingCoordinator(
             turnByTurnEngine:
                 turnByTurnEngine ??
                 defaultTurnByTurnEngine ??
                 const TurnByTurnEngine(),
             offRouteDetector: offRouteDetector ?? const OffRouteDetector(),
           ),
       super(const NavigationState()) {
    on<StartNavigation>(_onStartNavigation);
    on<LocationUpdated>(_onLocationUpdated);
    on<RerouteRequested>(_onRerouteRequested, transformer: restartable());
    on<StopNavigation>(_onStopNavigation);
    on<ClearNavigation>(_onClearNavigation);
    on<AllowBatteryOptimization>(_onAllowBatteryOptimization);
    on<SkipBatteryOptimization>(_onSkipBatteryOptimization);
    on<DismissBatteryOptimizationPrompt>(_onDismissBatteryOptimizationPrompt);
    on<CheckActiveSession>(_onCheckActiveSession);
    on<ResumeNavigation>(_onResumeNavigation);
    on<DiscardActiveSession>(_onDiscardActiveSession);
    on<SaveActiveSessionSnapshot>(
      _onSaveActiveSessionSnapshot,
      transformer: sequential(),
    );
  }

  ActiveTripSnapshot? _buildSnapshotFromState() =>
      state.toSnapshot(metrics: _metricsTracker);

  Future<void> _onCheckActiveSession(
    CheckActiveSession event,
    Emitter<NavigationState> emit,
  ) async {
    if (state.isNavigating) return;

    try {
      final session = await _persistenceCoordinator.getActiveSession();
      if (isClosed || emit.isDone) return;
      if (session != null && session.isValid()) {
        DLog.info(
          '🔔 [NavigationBloc] Found pending active trip session to "${session.destinationName}"',
        );
        emit(state.copyWith(pendingResumeSession: session));
      }
    } catch (e, stack) {
      if (isClosed || emit.isDone) return;
      DLog.error(
        '❌ [NavigationBloc] Error checking active session: $e',
        e,
        stack,
      );
    }
  }

  Future<void> _onResumeNavigation(
    ResumeNavigation event,
    Emitter<NavigationState> emit,
  ) async {
    final snapshot = event.snapshot;
    if (await _persistenceCoordinator.isSessionExpired(snapshot)) {
      emit(state.copyWith(clearPendingResumeSession: true));
      return;
    }

    DLog.info(
      '🚀 [NavigationBloc] Resuming Navigation from snapshot to "${snapshot.destinationName}" (${snapshot.destination.lat}, ${snapshot.destination.lon})',
    );

    final generation = ++_requestGeneration;
    await _cancelGpsSubscription();
    _persistenceCoordinator.stopAutoSave();

    if (generation != _requestGeneration || isClosed || emit.isDone) return;

    _lastRerouteTime = null;
    _lastGpsTimestamp = null;
    _kalmanFilter.reset();
    _metricsTracker.restoreFromSnapshot(snapshot);

    final progress = _trackingCoordinator
        .processLocationTick(
          currentLat: snapshot.lastKnownLat ?? snapshot.origin.lat,
          currentLon: snapshot.lastKnownLon ?? snapshot.origin.lon,
          route: snapshot.initialRoute,
          destination: snapshot.destination,
          currentSegmentIndex: snapshot.currentSegmentIndex,
          currentInstructionIndex: snapshot.currentInstructionIndex,
          hasMoved: false,
        )
        .progress;

    emit(
      NavigationState.resume(
        snapshot: snapshot,
        progress: progress,
        promptBatteryOptimizationOem: null,
      ),
    );

    _persistenceCoordinator.startAutoSave(() {
      if (!isClosed) add(const SaveActiveSessionSnapshot());
    });
    add(const SaveActiveSessionSnapshot());

    // Keep Screen On — giữ màn hình sáng suốt phiên chỉ đường (resume)
    unawaited(_devicePolicy.enableKeepScreenOn());

    final destName =
        snapshot.destinationName ??
        LocaleKeys.routing_destination_fallback.tr();
    _listenGpsStream(destName);
    _requestNotificationPermissionInBackground();
  }

  Future<void> _onDiscardActiveSession(
    DiscardActiveSession event,
    Emitter<NavigationState> emit,
  ) async {
    DLog.info('🗑️ [NavigationBloc] Discarding pending active trip session');
    await _persistenceCoordinator.clearActiveSessionSafely();
    if (isClosed || emit.isDone) return;
    emit(state.copyWith(clearPendingResumeSession: true));
  }

  Future<void> _onSaveActiveSessionSnapshot(
    SaveActiveSessionSnapshot event,
    Emitter<NavigationState> emit,
  ) async {
    final snapshot = _buildSnapshotFromState();
    if (snapshot == null) return;

    try {
      await _persistenceCoordinator.saveActiveSession(snapshot);
    } catch (e, stack) {
      if (isClosed || emit.isDone) return;
      DLog.warning(
        '⚠️ [NavigationBloc] Storage error while auto-saving active session: $e',
        e,
        stack,
      );
      emit(state.copyWith(errorMessageKey: LocaleKeys.routing_storage_warning));
    }
  }

  Future<void> _onStartNavigation(
    StartNavigation event,
    Emitter<NavigationState> emit,
  ) async {
    DLog.info(
      '🚀 [NavigationBloc] Starting Navigation to "${event.destinationName}" (${event.destination.lat}, ${event.destination.lon})',
    );

    final generation = ++_requestGeneration;
    await _cancelGpsSubscription();
    _persistenceCoordinator.stopAutoSave();

    if (generation != _requestGeneration || isClosed) return;

    _lastRerouteTime = null;
    _lastGpsTimestamp = null;
    _consecutiveOffRouteTicks = 0;
    _metricsTracker.reset();
    _kalmanFilter.reset();

    final initialProgress = _trackingCoordinator.initializeProgress(
      event.initialRoute.instructions,
    );

    emit(
      NavigationState.start(
        initialRoute: event.initialRoute,
        origin: event.origin,
        originName: event.originName,
        destination: event.destination,
        destinationName: event.destinationName,
        profile: event.profile,
        initialProgress: initialProgress,
        promptBatteryOptimizationOem: null,
      ),
    );

    _persistenceCoordinator.startAutoSave(() {
      if (!isClosed) add(const SaveActiveSessionSnapshot());
    });
    add(const SaveActiveSessionSnapshot());

    // Keep Screen On — giữ màn hình sáng suốt phiên chỉ đường
    unawaited(_devicePolicy.enableKeepScreenOn());

    final destName =
        event.destinationName ?? LocaleKeys.routing_destination_fallback.tr();
    _listenGpsStream(destName);
    _requestNotificationPermissionInBackground();
  }

  void _requestNotificationPermissionInBackground() {
    unawaited(
      _devicePolicy.requestNotificationPermission().catchError((Object error) {
        DLog.warning(
          '⚠️ [NavigationBloc] Notification permission request failed: $error',
        );
      }),
    );
  }

  Future<void> _onAllowBatteryOptimization(
    AllowBatteryOptimization event,
    Emitter<NavigationState> emit,
  ) async {
    await _devicePolicy.requestIgnoreBatteryOptimization();
    if (isClosed || emit.isDone) return;
    emit(state.copyWith(clearPromptBatteryOptimization: true));
  }

  void _onSkipBatteryOptimization(
    SkipBatteryOptimization event,
    Emitter<NavigationState> emit,
  ) {
    emit(state.copyWith(clearPromptBatteryOptimization: true));
  }

  void _onDismissBatteryOptimizationPrompt(
    DismissBatteryOptimizationPrompt event,
    Emitter<NavigationState> emit,
  ) {
    emit(state.copyWith(clearPromptBatteryOptimization: true));
  }

  Future<void> _onLocationUpdated(
    LocationUpdated event,
    Emitter<NavigationState> emit,
  ) async {
    if (!state.isNavigating || !state.hasRoute) return;

    // Một số thiết bị có thể phát fix cũ sau fix mới. Bỏ qua để bộ lọc và
    // tiến độ tuyến không bị lùi về vị trí trước đó.
    final timestamp = event.timestamp;
    if (timestamp != null &&
        _lastGpsTimestamp != null &&
        !timestamp.isAfter(_lastGpsTimestamp!)) {
      return;
    }
    if (timestamp != null) _lastGpsTimestamp = timestamp;

    final speedKmh = event.speed != null
        ? event.speed! * RoutingConstants.msToKmhFactor
        : null;

    final accuracy = event.accuracy;
    final isAccuracyAcceptable =
        accuracy == null || accuracy <= RoutingConstants.maxGpsAccuracyMeters;

    // Không đưa fix kém chính xác vào Kalman Filter: nếu correction bằng một
    // mẫu nhiễu thì trạng thái lọc và map matching sẽ bị kéo lệch theo.
    if (!isAccuracyAcceptable) {
      emit(
        state.copyWith(
          currentLat: state.currentLat ?? event.latitude,
          currentLon: state.currentLon ?? event.longitude,
          currentSpeedKmh: speedKmh,
          currentHeading: event.heading,
          currentAccuracy: event.accuracy,
        ),
      );
      return;
    }

    // Dùng timestamp gốc của thiết bị để dự đoán đúng khoảng cách giữa hai fix.
    final filtered = _kalmanFilter.update(
      gpsLat: event.latitude,
      gpsLon: event.longitude,
      accuracyMeters: accuracy ?? 10.0,
      speedMps: event.speed,
      headingDeg: event.heading,
      timestamp: timestamp,
    );
    final trackingLat = filtered.lat;
    final trackingLon = filtered.lon;

    // 0. Tích luỹ số liệu vận tốc và quãng đường vào MetricsTracker
    _metricsTracker.recordFix(
      lat: trackingLat,
      lon: trackingLon,
      speedKmh: speedKmh,
    );

    // 1. Phân tích chu kỳ vị trí thông qua TrackingCoordinator
    final tick = _trackingCoordinator.processLocationTick(
      currentLat: trackingLat,
      currentLon: trackingLon,
      route: state.currentRoute!,
      destination: state.destination,
      currentSegmentIndex: state.currentSegmentIndex,
      currentInstructionIndex: state.currentInstructionIndex,
      hasMoved: _metricsTracker.hasMoved,
      accuracyMeters: accuracy,
    );

    // 2. Xử lý khi đã đến đích
    if (tick.isArrived) {
      DLog.info('🏁 [NavigationBloc] User arrived at destination!');
      _requestGeneration++;
      await _cancelGpsSubscription();

      final tripRoute = _buildTripRouteForFinalization();
      final result = await _persistenceCoordinator.finalizeTrip(
        metrics: _metricsTracker,
        startTime: state.tripStartTime,
        origin: state.tripOrigin ?? state.origin,
        originName: state.tripOriginName,
        destination: state.destination,
        destinationName: state.destinationName,
        profile: state.profile,
        polyline: tripRoute.points,
        hasArrived: true,
        stopLat: trackingLat,
        stopLon: trackingLon,
      );
      if (isClosed) return;

      emit(
        state.copyWithArrival(
          currentLat: event.latitude,
          currentLon: event.longitude,
          filteredLat: filtered.lat,
          filteredLon: filtered.lon,
          currentSpeedKmh: speedKmh,
          currentHeading: event.heading,
          currentAccuracy: event.accuracy,
          currentInstructionIndex: tick.progress.currentInstructionIndex,
          currentInstruction: tick.progress.currentInstruction,
          nextInstruction: tick.progress.nextInstruction,
          metrics: _metricsTracker,
          tripSummary: result.summary,
        ),
      );
      return;
    }

    // 3. Cập nhật toạ độ và chỉ dẫn đường (có map-matched snapping)
    emit(
      state.copyWithTick(
        tick: tick,
        currentLat: event.latitude,
        currentLon: event.longitude,
        filteredLat: filtered.lat,
        filteredLon: filtered.lon,
        currentSpeedKmh: speedKmh,
        currentHeading: event.heading,
        currentAccuracy: event.accuracy,
        metrics: _metricsTracker,
      ),
    );

    // Chỉ tính route mới sau khi nhiều fix liên tiếp xác nhận lệch tuyến.
    _checkAutoReroute(
      tick,
      trackingLat,
      trackingLon,
      speedKmh,
      event.heading,
      event.headingAccuracy,
    );
  }

  Future<void> _onRerouteRequested(
    RerouteRequested event,
    Emitter<NavigationState> emit,
  ) async {
    if (state.destination == null) {
      DLog.warning('⚠️ [NavigationBloc] Cannot reroute: destination is null');
      return;
    }

    final generation = ++_requestGeneration;
    DLog.info(
      '🔄 [NavigationBloc] Rerouting [Gen #$generation] from (${event.currentPosition.lat.toStringAsFixed(5)}, ${event.currentPosition.lon.toStringAsFixed(5)}) to (${state.destination!.lat.toStringAsFixed(5)}, ${state.destination!.lon.toStringAsFixed(5)})',
    );

    emit(
      state.copyWith(
        status: NavigationStatus.rerouting,
        isRerouting: true,
        requestGeneration: generation,
        messageKey: LocaleKeys.routing_rerouting,
        clearError: true,
      ),
    );

    try {
      final newRoute = await _routingRepository.calculateRoute(
        fromLat: event.currentPosition.lat,
        fromLon: event.currentPosition.lon,
        toLat: state.destination!.lat,
        toLon: state.destination!.lon,
        vehicleProfile: state.profile,
      );

      if (isClosed || emit.isDone || generation != _requestGeneration) {
        DLog.info(
          '⏭️ [NavigationBloc] Stale reroute response discarded (#$generation vs #$_requestGeneration)',
        );
        return;
      }

      if (newRoute.isSuccess && newRoute.hasPoints) {
        DLog.info(
          '✅ [NavigationBloc] Reroute calculated successfully: ${(newRoute.distance / 1000).toStringAsFixed(2)}km, ${(newRoute.time / 60000).round()} mins',
        );
        final newProgress = _trackingCoordinator.initializeProgress(
          newRoute.instructions,
        );

        emit(
          state.copyWithRerouteSuccess(
            newRoute: newRoute,
            newOrigin: event.currentPosition,
            newProgress: newProgress,
            requestGeneration: generation,
            messageKey: LocaleKeys.routing_reroute_success,
            completedRoutePoints: _appendCompletedRoutePrefix(
              state.completedRoutePoints,
              state.currentRoute?.points ?? const [],
              event.currentPosition,
            ),
          ),
        );
        add(const SaveActiveSessionSnapshot());
      } else {
        DLog.error(
          '❌ [NavigationBloc] Reroute calculation failed: ${newRoute.errorMessage}',
        );
        emit(
          state.copyWith(
            status: NavigationStatus.navigating,
            isRerouting: false,
            requestGeneration: generation,
            errorMessageKey:
                newRoute.errorMessage ?? LocaleKeys.routing_error_generic,
          ),
        );
      }
    } catch (e, stack) {
      if (isClosed || emit.isDone || generation != _requestGeneration) return;
      DLog.error(
        '❌ [NavigationBloc] Exception in reroute calculation: $e',
        e,
        stack,
      );
      emit(
        state.copyWith(
          status: NavigationStatus.navigating,
          isRerouting: false,
          requestGeneration: generation,
          errorMessageKey: LocaleKeys.routing_error_generic,
        ),
      );
    }
  }

  Future<void> _onStopNavigation(
    StopNavigation event,
    Emitter<NavigationState> emit,
  ) async {
    final generation = ++_requestGeneration;
    DLog.info('🛑 [NavigationBloc] Stopping navigation [Gen #$generation]');

    await _cancelGpsSubscription();
    // Tắt Keep Screen On — trả lại quyền kiểm soát màn hình cho OS
    unawaited(_devicePolicy.disableKeepScreenOn());

    if (isClosed || emit.isDone || generation != _requestGeneration) return;

    if (state.status == NavigationStatus.arrived ||
        state.status == NavigationStatus.stopped) {
      if (state.status != NavigationStatus.stopped) {
        emit(state.copyWith(status: NavigationStatus.stopped));
      }
      return;
    }

    if (state.tripStartTime != null) {
      final stopLat =
          state.snappedLat ?? state.currentLat ?? _metricsTracker.lastValidLat;
      final stopLon =
          state.snappedLon ?? state.currentLon ?? _metricsTracker.lastValidLon;

      final tripRoute = _buildTripRouteForFinalization();
      final result = await _persistenceCoordinator.finalizeTrip(
        metrics: _metricsTracker,
        startTime: state.tripStartTime,
        origin: state.tripOrigin ?? state.origin,
        originName: state.tripOriginName,
        destination: state.destination,
        destinationName: state.destinationName,
        profile: state.profile,
        polyline: tripRoute.points,
        hasArrived: false,
        stopLat: stopLat,
        stopLon: stopLon,
        currentSegmentIndex: tripRoute.currentSegmentIndex,
      );

      emit(
        state.copyWith(
          status: NavigationStatus.stopped,
          tripSummary: result.summary,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: NavigationStatus.stopped,
          clearTripSummary: true,
        ),
      );
    }
  }

  Future<void> _onClearNavigation(
    ClearNavigation event,
    Emitter<NavigationState> emit,
  ) async {
    DLog.info('🧹 [NavigationBloc] Clearing navigation state back to initial');
    final generation = ++_requestGeneration;
    _persistenceCoordinator.stopAutoSave();
    unawaited(_persistenceCoordinator.clearActiveSessionSafely());

    await _cancelGpsSubscription();
    // Tắt Keep Screen On khi clear navigation
    unawaited(_devicePolicy.disableKeepScreenOn());

    if (generation != _requestGeneration || isClosed) return;

    _lastRerouteTime = null;
    _lastGpsTimestamp = null;
    _metricsTracker.reset();
    _kalmanFilter.reset();
    _consecutiveOffRouteTicks = 0;
    emit(const NavigationState());
  }

  void _checkAutoReroute(
    TrackingTickResult tick,
    double currentLat,
    double currentLon,
    double? speedKmh,
    double? headingDeg,
    double? headingAccuracyDeg,
  ) {
    final isOppositeDirection = _isMovingOppositeRoute(
      segmentIndex: tick.segmentIndex,
      headingDeg: headingDeg,
      headingAccuracyDeg: headingAccuracyDeg,
      speedKmh: speedKmh,
    );
    final isDeviationCandidate = tick.isOffRoute || isOppositeDirection;

    if (!isDeviationCandidate) {
      // Cần các fix lệch liên tiếp; fix trở lại đúng tuyến xoá xác nhận cũ.
      _consecutiveOffRouteTicks = 0;
      return;
    }

    _consecutiveOffRouteTicks++;

    if (_consecutiveOffRouteTicks < minConsecutiveOffRouteTicks) {
      DLog.info(
        '⏳ [NavigationBloc] Off-route detected ($_consecutiveOffRouteTicks/$minConsecutiveOffRouteTicks ticks, dist: ${tick.distanceToRoute.toStringAsFixed(1)}m). Awaiting confirmation window.',
      );
      return;
    }

    // Xe được coi là đứng yên nếu cảm biến vận tốc ghi nhận < 5.0 km/h (khi dừng đèn đỏ).
    // Nếu thiết bị không cung cấp vận tốc, fallback kiểm tra xem đã có dịch chuyển thực tế chưa.
    final isStationary = speedKmh != null
        ? speedKmh < minMovingSpeedForRerouteKmh
        : !_metricsTracker.hasMoved;

    if (isStationary) {
      DLog.info(
        '🛑 [NavigationBloc] Off-route suppressed: vehicle is stationary (${speedKmh?.toStringAsFixed(1)} km/h).',
      );
      return;
    }

    if (!state.isRerouting) {
      final now = DateTime.now();
      final canReroute =
          _lastRerouteTime == null ||
          now.difference(_lastRerouteTime!) >= _rerouteCooldown;

      if (canReroute) {
        _lastRerouteTime = now;
        _consecutiveOffRouteTicks = 0;
        DLog.info(
          '🔄 [NavigationBloc] Auto-triggering reroute after $minConsecutiveOffRouteTicks confirmed fixes (distance=${tick.distanceToRoute.toStringAsFixed(1)}m, oppositeDirection=$isOppositeDirection)',
        );
        add(
          RerouteRequested(
            currentPosition: RoutePoint(lat: currentLat, lon: currentLon),
          ),
        );
      }
    }
  }

  bool _isMovingOppositeRoute({
    required int segmentIndex,
    required double? headingDeg,
    required double? headingAccuracyDeg,
    required double? speedKmh,
  }) {
    if (headingDeg == null ||
        speedKmh == null ||
        speedKmh < minMovingSpeedForRerouteKmh ||
        (headingAccuracyDeg != null && headingAccuracyDeg > 45.0)) {
      return false;
    }

    final points = state.currentRoute?.points;
    if (points == null || points.length < 2) return false;
    final index = segmentIndex.clamp(0, points.length - 2).toInt();
    final start = points[index];
    final end = points[index + 1];
    if (start.length < 2 || end.length < 2) return false;
    final routeHeading = MapGeometryUtils.bearing(
      start[0],
      start[1],
      end[0],
      end[1],
    );
    final difference = ((headingDeg - routeHeading + 540.0) % 360.0) - 180.0;

    // Chỉ xem là đi ngược khi lệch gần 180°, tránh nhầm những khúc cong hoặc
    // thao tác rẽ trái/phải bình thường với việc đi sai hướng trên cùng tuyến.
    return difference.abs() >= 120.0;
  }

  List<List<double>> _appendCompletedRoutePrefix(
    List<List<double>> completed,
    List<List<double>> routePoints,
    RoutePoint currentPosition,
  ) {
    if (routePoints.isEmpty) return completed;

    final (
      segmentIndex,
      _,
      closestLat,
      closestLon,
    ) = MapGeometryUtils.findClosestPointOnPolyline(
      pLat: currentPosition.lat,
      pLon: currentPosition.lon,
      points: routePoints,
    );
    final prefix = routePoints
        .take(segmentIndex + 1)
        .map((point) => List<double>.from(point))
        .toList();
    final projectedPoint = [closestLat, closestLon];
    if (prefix.isEmpty ||
        MapGeometryUtils.haversineDistanceMeters(
              prefix.last[0],
              prefix.last[1],
              closestLat,
              closestLon,
            ) >
            1.0) {
      prefix.add(projectedPoint);
    }

    if (MapGeometryUtils.haversineDistanceMeters(
          prefix.last[0],
          prefix.last[1],
          currentPosition.lat,
          currentPosition.lon,
        ) >
        3.0) {
      prefix.add([currentPosition.lat, currentPosition.lon]);
    }

    return _joinRoutePoints(completed, prefix);
  }

  ({List<List<double>>? points, int? currentSegmentIndex})
  _buildTripRouteForFinalization() {
    final completed = state.completedRoutePoints;
    final current = state.currentRoute?.points;
    if (current == null || current.isEmpty) {
      return (
        points: completed.isEmpty ? null : completed,
        currentSegmentIndex: null,
      );
    }
    if (completed.isEmpty) {
      return (points: current, currentSegmentIndex: state.currentSegmentIndex);
    }

    final startsAtCompletedEnd =
        MapGeometryUtils.haversineDistanceMeters(
          completed.last[0],
          completed.last[1],
          current.first[0],
          current.first[1],
        ) <=
        5.0;
    final points = _joinRoutePoints(
      completed,
      startsAtCompletedEnd ? current.skip(1).toList() : current,
    );
    final segmentOffset = startsAtCompletedEnd
        ? completed.length - 1
        : completed.length;

    return (
      points: points,
      currentSegmentIndex: segmentOffset + state.currentSegmentIndex,
    );
  }

  List<List<double>> _joinRoutePoints(
    List<List<double>> first,
    List<List<double>> second,
  ) {
    if (first.isEmpty) return second.map(List<double>.from).toList();
    if (second.isEmpty) return first.map(List<double>.from).toList();

    final joined = first.map((point) => List<double>.from(point)).toList();
    final skipFirst =
        MapGeometryUtils.haversineDistanceMeters(
          joined.last[0],
          joined.last[1],
          second.first[0],
          second.first[1],
        ) <=
        5.0;
    joined.addAll(
      second.skip(skipFirst ? 1 : 0).map((point) => List<double>.from(point)),
    );
    return joined;
  }

  Future<void> _cancelGpsSubscription() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  void _listenGpsStream(String destName) {
    final stream = _locationService.getPositionStream(
      // Dẫn đường cần nhận fix thường xuyên để camera và chỉ dẫn không tụt
      // phía sau người dùng. Mức này chỉ hoạt động trong phiên navigation.
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1,
      enableBackground: true,
      notificationTitle: LocaleKeys.routing_foreground_notification_title.tr(),
      notificationText: LocaleKeys.routing_foreground_notification_text.tr(
        args: [destName],
      ),
      intervalDuration: const Duration(milliseconds: 500),
      enableWakeLock: true,
    );

    _locationSubscription = stream.listen(
      (position) {
        if (!isClosed) {
          add(LocationUpdated.fromPosition(position));
        }
      },
      onError: (error) {
        DLog.error('❌ [NavigationBloc] GPS Position Stream error: $error');
      },
    );
  }

  @override
  Future<void> close() async {
    DLog.info(
      '🧹 [NavigationBloc] Disposing NavigationBloc and cancelling GPS listeners',
    );
    _requestGeneration++;
    _persistenceCoordinator.dispose();
    _lastRerouteTime = null;
    _lastGpsTimestamp = null;
    _metricsTracker.reset();
    await _cancelGpsSubscription();
    // Safety: tắt wakelock khi bloc bị dispose
    unawaited(_devicePolicy.disableKeepScreenOn());
    return super.close();
  }
}
