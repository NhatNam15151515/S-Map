import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:s_map/commons/fallbacks/fallbacks.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/transformers/transformers.dart';
import 'package:s_map/commons/usecases/usecases.dart';
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

  StreamSubscription<Position>? _locationSubscription;
  int _requestGeneration = 0;
  DateTime? _lastRerouteTime;

  /// Optional global default service resolvers set by the composition root
  static ILocationService? defaultLocationService;
  static ITurnByTurnEngine? defaultTurnByTurnEngine;
  static IDeviceInfoService? defaultDeviceInfoService;
  static IActiveTripService? defaultActiveTripService;
  static IVisitedPoiService? defaultVisitedPoiService;

  /// Số nhịp GPS liên tiếp phát hiện lệch tuyến bắt buộc trước khi kích hoạt Reroute
  static const int minConsecutiveOffRouteTicks = 3;

  /// Ngưỡng vận tốc tối thiểu (km/h) để cho phép tự động tính lại đường (tránh trôi dạt khi đứng yên)
  static const double minMovingSpeedForRerouteKmh = 5.0;

  /// Khoảng thời gian tối thiểu giữa 2 lần kích hoạt reroute tự động (cooldown 6 giây)
  static const Duration _rerouteCooldown = Duration(seconds: 6);

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
  })  : _routingRepository = routingRepository,
        _locationService = locationService ??
            defaultLocationService ??
            const NoOpLocationService(),
        _metricsTracker = metricsTracker ?? TripMetricsTracker(),
        _persistenceCoordinator = persistenceCoordinator ??
            NavigationPersistenceCoordinator(
              tripRepository: tripRepository,
              activeTripService: activeTripService ??
                  defaultActiveTripService ??
                  const NoOpActiveTripService(),
              visitedPoiService: visitedPoiService ??
                  defaultVisitedPoiService ??
                  const NoOpVisitedPoiService(),
            ),
        _devicePolicy = devicePolicy ??
            NavigationDevicePolicy(
              locationService: locationService ??
                  defaultLocationService ??
                  const NoOpLocationService(),
              deviceInfoService: deviceInfoService ??
                  defaultDeviceInfoService ??
                  const NoOpDeviceInfoService(),
            ),
        _trackingCoordinator = trackingCoordinator ??
            NavigationTrackingCoordinator(
              turnByTurnEngine: turnByTurnEngine ??
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
          '❌ [NavigationBloc] Error checking active session: $e', e, stack);
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
    _metricsTracker.restoreFromSnapshot(snapshot);

    final promptOem = await _devicePolicy.checkBatteryOptimizationPrompt();
    if (generation != _requestGeneration || isClosed || emit.isDone) return;

    final progress = _trackingCoordinator.processLocationTick(
      currentLat: snapshot.lastKnownLat ?? snapshot.origin.lat,
      currentLon: snapshot.lastKnownLon ?? snapshot.origin.lon,
      route: snapshot.initialRoute,
      destination: snapshot.destination,
      currentSegmentIndex: snapshot.currentSegmentIndex,
      currentInstructionIndex: snapshot.currentInstructionIndex,
      hasMoved: false,
    ).progress;

    emit(NavigationState.resume(
      snapshot: snapshot,
      progress: progress,
      promptBatteryOptimizationOem: promptOem,
    ));

    _persistenceCoordinator.startAutoSave(() {
      if (!isClosed) add(const SaveActiveSessionSnapshot());
    });
    add(const SaveActiveSessionSnapshot());

    await _devicePolicy.requestNotificationPermission();
    if (generation != _requestGeneration || isClosed || emit.isDone) return;

    final destName = snapshot.destinationName ??
        LocaleKeys.routing_destination_fallback.tr();
    _listenGpsStream(destName);
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
        '🚀 [NavigationBloc] Starting Navigation to "${event.destinationName}" (${event.destination.lat}, ${event.destination.lon})');

    final generation = ++_requestGeneration;
    await _cancelGpsSubscription();
    _persistenceCoordinator.stopAutoSave();

    if (generation != _requestGeneration || isClosed) return;

    _lastRerouteTime = null;
    _consecutiveOffRouteTicks = 0;
    _metricsTracker.reset();

    final promptOem = await _devicePolicy.checkBatteryOptimizationPrompt();
    if (generation != _requestGeneration || isClosed) return;

    final initialProgress = _trackingCoordinator.initializeProgress(
      event.initialRoute.instructions,
    );

    emit(NavigationState.start(
      initialRoute: event.initialRoute,
      origin: event.origin,
      destination: event.destination,
      destinationName: event.destinationName,
      profile: event.profile,
      initialProgress: initialProgress,
      promptBatteryOptimizationOem: promptOem,
    ));

    _persistenceCoordinator.startAutoSave(() {
      if (!isClosed) add(const SaveActiveSessionSnapshot());
    });
    add(const SaveActiveSessionSnapshot());

    await _devicePolicy.requestNotificationPermission();
    if (generation != _requestGeneration || isClosed) return;

    final destName =
        event.destinationName ?? LocaleKeys.routing_destination_fallback.tr();
    _listenGpsStream(destName);
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

    final currentLat = event.latitude;
    final currentLon = event.longitude;
    final speedKmh = event.speed != null
        ? event.speed! * RoutingConstants.msToKmhFactor
        : null;

    final accuracy = event.accuracy;
    final isAccuracyAcceptable =
        accuracy == null || accuracy <= RoutingConstants.maxGpsAccuracyMeters;

    // Nếu GPS fix kém chính xác (> 35m), chỉ cập nhật toạ độ hiển thị, không chạy engine/reroute
    if (!isAccuracyAcceptable) {
      emit(state.copyWith(
        currentLat: currentLat,
        currentLon: currentLon,
        currentSpeedKmh: speedKmh,
        currentHeading: event.heading,
        currentAccuracy: event.accuracy,
      ));
      return;
    }

    // 0. Tích luỹ số liệu vận tốc và quãng đường vào MetricsTracker
    _metricsTracker.recordFix(
      lat: currentLat,
      lon: currentLon,
      speedKmh: speedKmh,
    );

    // 1. Phân tích chu kỳ vị trí thông qua TrackingCoordinator
    final tick = _trackingCoordinator.processLocationTick(
      currentLat: currentLat,
      currentLon: currentLon,
      route: state.currentRoute!,
      destination: state.destination,
      currentSegmentIndex: state.currentSegmentIndex,
      currentInstructionIndex: state.currentInstructionIndex,
      hasMoved: _metricsTracker.hasMoved,
    );

    // 2. Xử lý khi đã đến đích
    if (tick.isArrived) {
      DLog.info('🏁 [NavigationBloc] User arrived at destination!');
      _requestGeneration++;
      await _cancelGpsSubscription();

      final result = await _persistenceCoordinator.finalizeTrip(
        metrics: _metricsTracker,
        startTime: state.tripStartTime,
        destination: state.destination,
        destinationName: state.destinationName,
        profile: state.profile,
        polyline: state.currentRoute?.points,
        hasArrived: true,
      );
      if (isClosed) return;

      emit(state.copyWithArrival(
        currentLat: currentLat,
        currentLon: currentLon,
        currentSpeedKmh: speedKmh,
        currentHeading: event.heading,
        currentAccuracy: event.accuracy,
        currentInstructionIndex: tick.progress.currentInstructionIndex,
        currentInstruction: tick.progress.currentInstruction,
        nextInstruction: tick.progress.nextInstruction,
        metrics: _metricsTracker,
        tripSummary: result.summary,
      ));
      return;
    }

    // 3. Cập nhật toạ độ và chỉ dẫn đường (có map-matched snapping)
    emit(state.copyWithTick(
      tick: tick,
      currentLat: currentLat,
      currentLon: currentLon,
      currentSpeedKmh: speedKmh,
      currentHeading: event.heading,
      currentAccuracy: event.accuracy,
      metrics: _metricsTracker,
    ));

    // 4. Tự động kích hoạt tính lại đường (Reroute) khi phát hiện lệch tuyến > 50m (kèm Hysteresis)
    _checkAutoReroute(tick, currentLat, currentLon, speedKmh);
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
        '🔄 [NavigationBloc] Rerouting [Gen #$generation] from (${event.currentPosition.lat.toStringAsFixed(5)}, ${event.currentPosition.lon.toStringAsFixed(5)}) to (${state.destination!.lat.toStringAsFixed(5)}, ${state.destination!.lon.toStringAsFixed(5)})');

    emit(state.copyWith(
      status: NavigationStatus.rerouting,
      isRerouting: true,
      requestGeneration: generation,
      messageKey: LocaleKeys.routing_rerouting,
      clearError: true,
    ));

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
            '⏭️ [NavigationBloc] Stale reroute response discarded (#$generation vs #$_requestGeneration)');
        return;
      }

      if (newRoute.isSuccess && newRoute.hasPoints) {
        DLog.info(
            '✅ [NavigationBloc] Reroute calculated successfully: ${(newRoute.distance / 1000).toStringAsFixed(2)}km, ${(newRoute.time / 60000).round()} mins');
        final newProgress = _trackingCoordinator.initializeProgress(
          newRoute.instructions,
        );

        emit(state.copyWithRerouteSuccess(
          newRoute: newRoute,
          newOrigin: event.currentPosition,
          newProgress: newProgress,
          requestGeneration: generation,
          messageKey: LocaleKeys.routing_reroute_success,
        ));
        add(const SaveActiveSessionSnapshot());
      } else {
        DLog.error(
            '❌ [NavigationBloc] Reroute calculation failed: ${newRoute.errorMessage}');
        emit(state.copyWith(
          status: NavigationStatus.navigating,
          isRerouting: false,
          requestGeneration: generation,
          errorMessageKey:
              newRoute.errorMessage ?? LocaleKeys.routing_error_generic,
        ));
      }
    } catch (e, stack) {
      if (isClosed || emit.isDone || generation != _requestGeneration) return;
      DLog.error(
          '❌ [NavigationBloc] Exception in reroute calculation: $e', e, stack);
      emit(state.copyWith(
        status: NavigationStatus.navigating,
        isRerouting: false,
        requestGeneration: generation,
        errorMessageKey: LocaleKeys.routing_error_generic,
      ));
    }
  }

  Future<void> _onStopNavigation(
    StopNavigation event,
    Emitter<NavigationState> emit,
  ) async {
    final generation = ++_requestGeneration;
    DLog.info('🛑 [NavigationBloc] Stopping navigation [Gen #$generation]');

    await _cancelGpsSubscription();

    if (isClosed || emit.isDone || generation != _requestGeneration) return;

    if (state.status == NavigationStatus.arrived ||
        state.status == NavigationStatus.stopped) {
      if (state.status != NavigationStatus.stopped) {
        emit(state.copyWith(status: NavigationStatus.stopped));
      }
      return;
    }

    if (state.tripStartTime != null) {
      final result = await _persistenceCoordinator.finalizeTrip(
        metrics: _metricsTracker,
        startTime: state.tripStartTime,
        destination: state.destination,
        destinationName: state.destinationName,
        profile: state.profile,
        polyline: state.currentRoute?.points,
        hasArrived: false,
      );

      emit(state.copyWith(
        status: NavigationStatus.stopped,
        tripSummary: result.summary,
      ));
    } else {
      emit(state.copyWith(
        status: NavigationStatus.stopped,
        clearTripSummary: true,
      ));
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

    if (generation != _requestGeneration || isClosed) return;

    _lastRerouteTime = null;
    _metricsTracker.reset();
    _consecutiveOffRouteTicks = 0;
    emit(const NavigationState());
  }

  void _checkAutoReroute(
    TrackingTickResult tick,
    double currentLat,
    double currentLon,
    double? speedKmh,
  ) {
    if (!tick.isOffRoute) {
      _consecutiveOffRouteTicks = 0;
      return;
    }

    _consecutiveOffRouteTicks++;

    if (_consecutiveOffRouteTicks < minConsecutiveOffRouteTicks) {
      DLog.info(
          '⏳ [NavigationBloc] Off-route detected ($_consecutiveOffRouteTicks/$minConsecutiveOffRouteTicks ticks, dist: ${tick.distanceToRoute.toStringAsFixed(1)}m). Awaiting confirmation window.');
      return;
    }

    // Xe được coi là đứng yên nếu cảm biến vận tốc ghi nhận < 5.0 km/h (khi dừng đèn đỏ).
    // Nếu thiết bị không cung cấp vận tốc, fallback kiểm tra xem đã có dịch chuyển thực tế chưa.
    final isStationary = speedKmh != null
        ? speedKmh < minMovingSpeedForRerouteKmh
        : !_metricsTracker.hasMoved;

    if (isStationary) {
      DLog.info(
          '🛑 [NavigationBloc] Off-route suppressed: vehicle is stationary (${speedKmh?.toStringAsFixed(1)} km/h).');
      return;
    }

    if (!state.isRerouting) {
      final now = DateTime.now();
      final canReroute = _lastRerouteTime == null ||
          now.difference(_lastRerouteTime!) >= _rerouteCooldown;

      if (canReroute) {
        _lastRerouteTime = now;
        _consecutiveOffRouteTicks = 0;
        DLog.info(
            '🔄 [NavigationBloc] Auto-triggering reroute after 3 confirmed off-route ticks (${tick.distanceToRoute.toStringAsFixed(1)}m > 50m)');
        add(RerouteRequested(
          currentPosition: RoutePoint(lat: currentLat, lon: currentLon),
        ));
      }
    }
  }

  Future<void> _cancelGpsSubscription() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  void _listenGpsStream(String destName) {
    final stream = _locationService.getPositionStream(
      enableBackground: true,
      notificationTitle: LocaleKeys.routing_foreground_notification_title.tr(),
      notificationText: LocaleKeys.routing_foreground_notification_text.tr(
        args: [destName],
      ),
      intervalDuration: const Duration(seconds: 1),
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
        '🧹 [NavigationBloc] Disposing NavigationBloc and cancelling GPS listeners');
    _requestGeneration++;
    _persistenceCoordinator.dispose();
    _lastRerouteTime = null;
    _metricsTracker.reset();
    await _cancelGpsSubscription();
    return super.close();
  }
}
