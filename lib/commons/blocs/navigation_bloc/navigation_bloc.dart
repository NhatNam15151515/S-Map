import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:s_map/commons/fallbacks/fallbacks.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/transformers/transformers.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'navigation_event.dart';
import 'navigation_state.dart';

export 'navigation_event.dart';
export 'navigation_state.dart';

class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  final IRoutingRepository _routingRepository;
  final ILocationService _locationService;
  final IOffRouteDetector _offRouteDetector;
  final ITurnByTurnEngine _turnByTurnEngine;
  final IDeviceInfoService _deviceInfoService;
  final ITripRepository _tripRepository;
  final IActiveTripService _activeTripService;

  StreamSubscription<Position>? _locationSubscription;
  Timer? _autoSaveTimer;
  int _requestGeneration = 0;
  DateTime? _lastRerouteTime;
  double? _lastValidDistanceLat;
  double? _lastValidDistanceLon;

  /// Optional global default service resolvers set by the composition root
  static ILocationService? defaultLocationService;
  static ITurnByTurnEngine? defaultTurnByTurnEngine;
  static IDeviceInfoService? defaultDeviceInfoService;
  static IActiveTripService? defaultActiveTripService;

  /// Khoảng thời gian tối thiểu giữa 2 lần kích hoạt reroute tự động (cooldown 2 giây)
  static const Duration _rerouteCooldown = Duration(seconds: 2);

  /// Chu kỳ lưu snapshot phiên điều hướng định kỳ vào Hive (mỗi 30 giây)
  static const Duration _autoSaveInterval = Duration(seconds: 30);

  NavigationBloc({
    required IRoutingRepository routingRepository,
    required ITripRepository tripRepository,
    ILocationService? locationService,
    IOffRouteDetector? offRouteDetector,
    ITurnByTurnEngine? turnByTurnEngine,
    IDeviceInfoService? deviceInfoService,
    IActiveTripService? activeTripService,
  })  : _routingRepository = routingRepository,
        _tripRepository = tripRepository,
        _locationService = locationService ??
            defaultLocationService ??
            const NoOpLocationService(),
        _offRouteDetector = offRouteDetector ?? const OffRouteDetector(),
        _turnByTurnEngine = turnByTurnEngine ??
            defaultTurnByTurnEngine ??
            const TurnByTurnEngine(),
        _deviceInfoService = deviceInfoService ??
            defaultDeviceInfoService ??
            const NoOpDeviceInfoService(),
        _activeTripService = activeTripService ??
            defaultActiveTripService ??
            const NoOpActiveTripService(),
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
    on<SaveActiveSessionSnapshot>(_onSaveActiveSessionSnapshot);
  }

  void _startAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(_autoSaveInterval, (_) {
      if (!isClosed) {
        add(const SaveActiveSessionSnapshot());
      }
    });
  }

  void _stopAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  ActiveTripSnapshot? _buildSnapshotFromState() {
    if (!state.isNavigating ||
        state.currentRoute == null ||
        state.origin == null ||
        state.destination == null) {
      return null;
    }

    return ActiveTripSnapshot(
      origin: state.origin!,
      destination: state.destination!,
      destinationName: state.destinationName,
      profile: state.profile,
      initialRoute: state.currentRoute!,
      currentSegmentIndex: state.currentSegmentIndex,
      currentInstructionIndex: state.currentInstructionIndex,
      tripStartTime: state.tripStartTime ?? DateTime.now(),
      lastSavedTime: DateTime.now(),
      totalDistanceTraveledMeters: state.totalDistanceTraveledMeters,
      maxSpeedKmh: state.maxSpeedKmh,
      speedSampleSum: state.speedSampleSum,
      speedSampleCount: state.speedSampleCount,
      lastKnownLat: state.currentLat,
      lastKnownLon: state.currentLon,
    );
  }

  Future<void> _clearActiveSessionSafely() async {
    try {
      await _activeTripService.clearActiveSession();
    } catch (e, stack) {
      DLog.error('❌ [NavigationBloc] Failed to clear active session: $e', e, stack);
    }
  }

  Future<void> _onCheckActiveSession(
    CheckActiveSession event,
    Emitter<NavigationState> emit,
  ) async {
    if (state.isNavigating) return;

    try {
      final session = await _activeTripService.getActiveSession();
      if (isClosed || emit.isDone) return;
      if (session != null && session.isValid()) {
        DLog.info(
          '🔔 [NavigationBloc] Found pending active trip session to "${session.destinationName}"',
        );
        emit(state.copyWith(pendingResumeSession: session));
      }
    } catch (e, stack) {
      if (isClosed || emit.isDone) return;
      DLog.error('❌ [NavigationBloc] Error checking active session: $e', e, stack);
    }
  }

  Future<void> _onResumeNavigation(
    ResumeNavigation event,
    Emitter<NavigationState> emit,
  ) async {
    final snapshot = event.snapshot;
    DLog.info(
      '🚀 [NavigationBloc] Resuming Navigation from snapshot to "${snapshot.destinationName}" (${snapshot.destination.lat}, ${snapshot.destination.lon})',
    );

    final generation = ++_requestGeneration;
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    _stopAutoSaveTimer();

    if (generation != _requestGeneration || isClosed) return;

    _lastRerouteTime = null;
    _lastValidDistanceLat = snapshot.lastKnownLat;
    _lastValidDistanceLon = snapshot.lastKnownLon;

    DeviceOemType? promptOem;
    try {
      final isIgnored = await _locationService.isBatteryOptimizationIgnored();
      if (!isIgnored) {
        final oemType = await _deviceInfoService.getDeviceOemType();
        if (oemType.isAggressiveOem) {
          promptOem = oemType;
        }
      }
    } catch (e) {
      DLog.error('Lỗi kiểm tra battery optimization khi resume: $e');
    }

    if (generation != _requestGeneration || isClosed) return;

    final progress = _turnByTurnEngine.updateProgress(
      currentLat: snapshot.lastKnownLat ?? snapshot.origin.lat,
      currentLon: snapshot.lastKnownLon ?? snapshot.origin.lon,
      instructions: snapshot.initialRoute.instructions,
      currentInstructionIndex: snapshot.currentInstructionIndex,
    );

    emit(state.copyWith(
      status: NavigationStatus.navigating,
      currentRoute: snapshot.initialRoute,
      origin: snapshot.origin,
      destination: snapshot.destination,
      destinationName: snapshot.destinationName,
      clearDestinationName: snapshot.destinationName == null,
      profile: snapshot.profile,
      currentLat: snapshot.lastKnownLat,
      currentLon: snapshot.lastKnownLon,
      currentSegmentIndex: snapshot.currentSegmentIndex,
      distanceToRoute: 0.0,
      isOffRoute: false,
      isRerouting: false,
      rerouteCount: 0,
      currentInstructionIndex: progress.currentInstructionIndex,
      currentInstruction: progress.currentInstruction,
      clearCurrentInstruction: progress.currentInstruction == null,
      nextInstruction: progress.nextInstruction,
      clearNextInstruction: progress.nextInstruction == null,
      distanceToNextInstruction: progress.distanceToNextInstruction,
      remainingDistance: progress.remainingDistance,
      remainingDurationMs: progress.remainingDurationMs,
      isPreAnnounced: progress.isPreAnnounced,
      tripStartTime: snapshot.tripStartTime,
      maxSpeedKmh: snapshot.maxSpeedKmh,
      totalDistanceTraveledMeters: snapshot.totalDistanceTraveledMeters,
      speedSampleSum: snapshot.speedSampleSum,
      speedSampleCount: snapshot.speedSampleCount,
      clearPendingResumeSession: true,
      clearTripSummary: true,
      clearError: true,
      clearMessage: true,
      promptBatteryOptimizationOem: promptOem,
    ));

    _startAutoSaveTimer();
    add(const SaveActiveSessionSnapshot());

    await _locationService.requestNotificationPermission();

    if (generation != _requestGeneration || isClosed) return;

    final destName =
        snapshot.destinationName ?? LocaleKeys.routing_destination_fallback.tr();
    final stream = _locationService.getPositionStream(
      enableBackground: true,
      notificationTitle:
          LocaleKeys.routing_foreground_notification_title.tr(),
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
        DLog.error('❌ [NavigationBloc] GPS Position Stream error on resume: $error');
      },
    );
  }

  Future<void> _onDiscardActiveSession(
    DiscardActiveSession event,
    Emitter<NavigationState> emit,
  ) async {
    DLog.info('🗑️ [NavigationBloc] Discarding pending active trip session');
    try {
      await _activeTripService.clearActiveSession();
    } catch (e, stack) {
      DLog.error('❌ [NavigationBloc] Error clearing discarded active session: $e', e, stack);
    }
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
      await _activeTripService.saveActiveSession(snapshot);
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
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    _stopAutoSaveTimer();

    if (generation != _requestGeneration || isClosed) return;

    _lastRerouteTime = null;
    _lastValidDistanceLat = null;
    _lastValidDistanceLon = null;

    DeviceOemType? promptOem;
    try {
      final isIgnored = await _locationService.isBatteryOptimizationIgnored();
      if (!isIgnored) {
        final oemType = await _deviceInfoService.getDeviceOemType();
        if (oemType.isAggressiveOem) {
          promptOem = oemType;
        }
      }
    } catch (e) {
      DLog.error('Lỗi kiểm tra battery optimization khi bắt đầu: $e');
    }

    if (generation != _requestGeneration || isClosed) return;

    final initialProgress = _turnByTurnEngine.initializeProgress(
      event.initialRoute.instructions,
    );

    emit(state.copyWith(
      status: NavigationStatus.navigating,
      currentRoute: event.initialRoute,
      origin: event.origin,
      destination: event.destination,
      destinationName: event.destinationName,
      clearDestinationName: event.destinationName == null,
      profile: event.profile,
      currentSegmentIndex: 0,
      distanceToRoute: 0.0,
      isOffRoute: false,
      isRerouting: false,
      rerouteCount: 0,
      currentInstructionIndex: initialProgress.currentInstructionIndex,
      currentInstruction: initialProgress.currentInstruction,
      clearCurrentInstruction: initialProgress.currentInstruction == null,
      nextInstruction: initialProgress.nextInstruction,
      clearNextInstruction: initialProgress.nextInstruction == null,
      distanceToNextInstruction: initialProgress.distanceToNextInstruction,
      remainingDistance: initialProgress.remainingDistance,
      remainingDurationMs: initialProgress.remainingDurationMs,
      isPreAnnounced: initialProgress.isPreAnnounced,
      clearCurrentPosition: true,
      tripStartTime: DateTime.now(),
      maxSpeedKmh: 0.0,
      totalDistanceTraveledMeters: 0.0,
      speedSampleSum: 0.0,
      speedSampleCount: 0,
      clearTripSummary: true,
      clearPendingResumeSession: true,
      clearError: true,
      clearMessage: true,
      promptBatteryOptimizationOem: promptOem,
    ));

    _startAutoSaveTimer();
    add(const SaveActiveSessionSnapshot());

    await _locationService.requestNotificationPermission();

    if (generation != _requestGeneration || isClosed) return;

    final destName =
        event.destinationName ?? LocaleKeys.routing_destination_fallback.tr();
    final stream = _locationService.getPositionStream(
      enableBackground: true,
      notificationTitle:
          LocaleKeys.routing_foreground_notification_title.tr(),
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

  Future<void> _onAllowBatteryOptimization(
    AllowBatteryOptimization event,
    Emitter<NavigationState> emit,
  ) async {
    try {
      await _locationService.requestIgnoreBatteryOptimization();
    } catch (e) {
      DLog.error('Lỗi khi request ignore battery optimization: $e');
    }
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

  void _onLocationUpdated(
    LocationUpdated event,
    Emitter<NavigationState> emit,
  ) {
    if (!state.isNavigating || !state.hasRoute) return;

    final currentLat = event.latitude;
    final currentLon = event.longitude;
    final speedKmh = event.speed != null
        ? event.speed! * RoutingConstants.msToKmhFactor
        : null;

    // 0. Cập nhật thống kê vận tốc và quãng đường tích lũy
    final currentMaxSpeed = speedKmh != null && speedKmh > state.maxSpeedKmh
        ? speedKmh
        : state.maxSpeedKmh;
    final newSampleSum = speedKmh != null && speedKmh > 0
        ? state.speedSampleSum + speedKmh
        : state.speedSampleSum;
    final newSampleCount = speedKmh != null && speedKmh > 0
        ? state.speedSampleCount + 1
        : state.speedSampleCount;

    final accuracy = event.accuracy;
    final isAccuracyAcceptable = accuracy == null ||
        accuracy <= RoutingConstants.maxGpsAccuracyMeters;

    // Nếu GPS fix kém chính xác (> 35m), chỉ cập nhật tọa độ hiển thị, không chạy engine/reroute
    if (!isAccuracyAcceptable) {
      emit(state.copyWith(
        currentLat: currentLat,
        currentLon: currentLon,
        currentSpeedKmh: speedKmh,
        currentHeading: event.heading,
        currentAccuracy: event.accuracy,
        maxSpeedKmh: currentMaxSpeed,
        speedSampleSum: newSampleSum,
        speedSampleCount: newSampleCount,
      ));
      return;
    }

    double addedDistance = 0.0;
    if (_lastValidDistanceLat != null && _lastValidDistanceLon != null) {
      final deltaKm = AppUtils.instance.calculateDistance(
        _lastValidDistanceLat!,
        _lastValidDistanceLon!,
        currentLat,
        currentLon,
      );
      final deltaMeters = deltaKm * RoutingConstants.metersPerKm;
      // Bỏ qua rung lắc GPS khi dừng xe (< 1m) và bước nhảy đột biến (> 200m)
      if (deltaMeters >= RoutingConstants.minGpsMovementDeltaMeters &&
          deltaMeters <= RoutingConstants.maxGpsJumpDeltaMeters) {
        addedDistance = deltaMeters;
        _lastValidDistanceLat = currentLat;
        _lastValidDistanceLon = currentLon;
      }
    } else {
      _lastValidDistanceLat = currentLat;
      _lastValidDistanceLon = currentLon;
    }

    final totalDistanceTraveled =
        state.totalDistanceTraveledMeters + addedDistance;

    // 1. Cập nhật tiến trình chỉ dẫn (Turn-by-turn Instruction Engine)
    final progress = _turnByTurnEngine.updateProgress(
      currentLat: currentLat,
      currentLon: currentLon,
      instructions: state.currentRoute!.instructions,
      currentInstructionIndex: state.currentInstructionIndex,
    );

    // 2. Kiểm tra đã đến đích chưa (thông qua engine hoặc khoảng cách đích)
    bool isArrived = progress.hasArrived;
    if (!isArrived && state.destination != null) {
      final distToDestKm = AppUtils.instance.calculateDistance(
        currentLat,
        currentLon,
        state.destination!.lat,
        state.destination!.lon,
      );
      final distToDestMeters = distToDestKm * RoutingConstants.metersPerKm;
      if (distToDestMeters <= _turnByTurnEngine.arrivalThresholdMeters) {
        isArrived = true;
      }
    }

    if (isArrived) {
      DLog.info('🏁 [NavigationBloc] User arrived at destination!');
      _requestGeneration++;
      _locationSubscription?.cancel();
      _locationSubscription = null;
      _stopAutoSaveTimer();
      unawaited(_clearActiveSessionSafely());

      final now = DateTime.now();
      final startTime = state.tripStartTime ?? now;
      final tripDuration = now.difference(startTime);
      final avgSpeed = tripDuration.inMilliseconds > 0
          ? (totalDistanceTraveled / RoutingConstants.metersPerKm) /
              (tripDuration.inMilliseconds / RoutingConstants.msPerHour)
          : 0.0;

      final summary = TripSummary(
        duration: tripDuration,
        distanceMeters: totalDistanceTraveled,
        avgSpeedKmh: avgSpeed.isFinite ? avgSpeed : 0.0,
        topSpeedKmh: currentMaxSpeed,
        destinationName: state.destinationName,
        hasArrived: true,
      );

      final tripRecord = TripRecordModel(
        id: 'trip_${now.microsecondsSinceEpoch}_${now.hashCode.abs()}',
        startTime: startTime,
        endTime: now,
        durationMs: tripDuration.inMilliseconds,
        distanceMeters: totalDistanceTraveled,
        avgSpeedKmh: avgSpeed.isFinite ? avgSpeed : 0.0,
        topSpeedKmh: currentMaxSpeed,
        destinationName: state.destinationName,
        originName: null,
        hasArrived: true,
        vehicleProfile: state.profile,
        polyline: state.currentRoute?.points,
        createdAt: now,
      );
      unawaited(_saveTripSafely(tripRecord));

      emit(state.copyWith(
        status: NavigationStatus.arrived,
        currentLat: currentLat,
        currentLon: currentLon,
        currentSpeedKmh: speedKmh,
        currentHeading: event.heading,
        currentAccuracy: event.accuracy,
        currentInstructionIndex: progress.currentInstructionIndex,
        currentInstruction: progress.currentInstruction,
        clearCurrentInstruction: progress.currentInstruction == null,
        nextInstruction: progress.nextInstruction,
        clearNextInstruction: progress.nextInstruction == null,
        distanceToNextInstruction: 0.0,
        remainingDistance: 0.0,
        remainingDurationMs: 0,
        isPreAnnounced: false,
        isOffRoute: false,
        distanceToRoute: 0.0,
        maxSpeedKmh: currentMaxSpeed,
        totalDistanceTraveledMeters: totalDistanceTraveled,
        speedSampleSum: newSampleSum,
        speedSampleCount: newSampleCount,
        tripSummary: summary,
      ));
      return;
    }

    // 3. Kiểm tra lệch tuyến (Off-route detection)
    final routePoints = state.currentRoute!.points;
    final offRouteStatus = _offRouteDetector.checkOffRoute(
      currentLat: currentLat,
      currentLon: currentLon,
      routePoints: routePoints,
      currentSegmentIndex: state.currentSegmentIndex,
      lookAheadSegments: 5,
    );

    emit(state.copyWith(
      currentLat: currentLat,
      currentLon: currentLon,
      currentSpeedKmh: speedKmh,
      currentHeading: event.heading,
      currentAccuracy: event.accuracy,
      currentSegmentIndex: offRouteStatus.segmentIndex,
      distanceToRoute: offRouteStatus.distanceToRoute,
      isOffRoute: offRouteStatus.isOffRoute,
      currentInstructionIndex: progress.currentInstructionIndex,
      currentInstruction: progress.currentInstruction,
      clearCurrentInstruction: progress.currentInstruction == null,
      nextInstruction: progress.nextInstruction,
      clearNextInstruction: progress.nextInstruction == null,
      distanceToNextInstruction: progress.distanceToNextInstruction,
      remainingDistance: progress.remainingDistance,
      remainingDurationMs: progress.remainingDurationMs,
      isPreAnnounced: progress.isPreAnnounced,
      maxSpeedKmh: currentMaxSpeed,
      totalDistanceTraveledMeters: totalDistanceTraveled,
      speedSampleSum: newSampleSum,
      speedSampleCount: newSampleCount,
    ));

    // 4. Tự động kích hoạt tính lại đường (Reroute) khi phát hiện lệch tuyến > 50m
    if (offRouteStatus.isOffRoute && !state.isRerouting) {
      final now = DateTime.now();
      final canReroute = _lastRerouteTime == null ||
          now.difference(_lastRerouteTime!) >= _rerouteCooldown;

      if (canReroute) {
        _lastRerouteTime = now;
        DLog.info(
            '🔄 [NavigationBloc] Auto-triggering reroute due to off-route (${offRouteStatus.distanceToRoute.toStringAsFixed(1)}m > 50m)');
        add(RerouteRequested(
          currentPosition: RoutePoint(lat: currentLat, lon: currentLon),
        ));
      }
    }
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
        DLog.info('⏭️ [NavigationBloc] Stale reroute response discarded (#$generation vs #$_requestGeneration)');
        return;
      }

      if (newRoute.isSuccess && newRoute.hasPoints) {
        DLog.info(
            '✅ [NavigationBloc] Reroute calculated successfully: ${(newRoute.distance / 1000).toStringAsFixed(2)}km, ${(newRoute.time / 60000).round()} mins');
        final newProgress = _turnByTurnEngine.initializeProgress(
          newRoute.instructions,
        );

        emit(state.copyWith(
          status: NavigationStatus.navigating,
          currentRoute: newRoute,
          origin: event.currentPosition,
          currentSegmentIndex: 0,
          isOffRoute: false,
          isRerouting: false,
          rerouteCount: state.rerouteCount + 1,
          requestGeneration: generation,
          currentInstructionIndex: newProgress.currentInstructionIndex,
          currentInstruction: newProgress.currentInstruction,
          clearCurrentInstruction: newProgress.currentInstruction == null,
          nextInstruction: newProgress.nextInstruction,
          clearNextInstruction: newProgress.nextInstruction == null,
          distanceToNextInstruction: newProgress.distanceToNextInstruction,
          remainingDistance: newProgress.remainingDistance,
          remainingDurationMs: newProgress.remainingDurationMs,
          isPreAnnounced: newProgress.isPreAnnounced,
          messageKey: LocaleKeys.routing_reroute_success,
          clearError: true,
        ));
        add(const SaveActiveSessionSnapshot());
      } else {
        DLog.error('❌ [NavigationBloc] Reroute calculation failed: ${newRoute.errorMessage}');
        emit(state.copyWith(
          status: NavigationStatus.navigating,
          isRerouting: false,
          requestGeneration: generation,
          errorMessageKey: newRoute.errorMessage ?? LocaleKeys.routing_error_generic,
        ));
      }
    } catch (e, stack) {
      if (isClosed || emit.isDone || generation != _requestGeneration) return;
      DLog.error('❌ [NavigationBloc] Exception in reroute calculation: $e', e, stack);
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

    _stopAutoSaveTimer();
    unawaited(_clearActiveSessionSafely());

    await _locationSubscription?.cancel();
    _locationSubscription = null;
    _lastValidDistanceLat = null;
    _lastValidDistanceLon = null;

    if (isClosed || emit.isDone || generation != _requestGeneration) return;

    if (state.status == NavigationStatus.arrived ||
        state.status == NavigationStatus.stopped) {
      if (state.status != NavigationStatus.stopped) {
        emit(state.copyWith(
          status: NavigationStatus.stopped,
        ));
      }
      return;
    }

    if (state.tripStartTime != null) {
      final now = DateTime.now();
      final startTime = state.tripStartTime!;
      final tripDuration = now.difference(startTime);
      final avgSpeed = tripDuration.inMilliseconds > 0
          ? (state.totalDistanceTraveledMeters / RoutingConstants.metersPerKm) /
              (tripDuration.inMilliseconds / RoutingConstants.msPerHour)
          : 0.0;

      final summary = TripSummary(
        duration: tripDuration,
        distanceMeters: state.totalDistanceTraveledMeters,
        avgSpeedKmh: avgSpeed.isFinite ? avgSpeed : 0.0,
        topSpeedKmh: state.maxSpeedKmh,
        destinationName: state.destinationName,
        hasArrived: false,
      );

      final tripRecord = TripRecordModel(
        id: 'trip_${now.microsecondsSinceEpoch}_${now.hashCode.abs()}',
        startTime: startTime,
        endTime: now,
        durationMs: tripDuration.inMilliseconds,
        distanceMeters: state.totalDistanceTraveledMeters,
        avgSpeedKmh: avgSpeed.isFinite ? avgSpeed : 0.0,
        topSpeedKmh: state.maxSpeedKmh,
        destinationName: state.destinationName,
        originName: null,
        hasArrived: false,
        vehicleProfile: state.profile,
        polyline: state.currentRoute?.points,
        createdAt: now,
      );

      emit(state.copyWith(
        status: NavigationStatus.stopped,
        tripSummary: summary,
      ));

      unawaited(_saveTripSafely(tripRecord));
    } else {
      emit(state.copyWith(
        status: NavigationStatus.stopped,
        clearTripSummary: true,
      ));
    }
  }

  Future<void> _saveTripSafely(TripRecordModel trip) async {
    try {
      await _tripRepository.saveTrip(trip);
    } catch (e, stack) {
      DLog.error('❌ [NavigationBloc] Failed to auto-save trip: $e', e, stack);
    }
  }

  Future<void> _onClearNavigation(
    ClearNavigation event,
    Emitter<NavigationState> emit,
  ) async {
    DLog.info('🧹 [NavigationBloc] Clearing navigation state back to initial');
    final generation = ++_requestGeneration;
    _stopAutoSaveTimer();
    unawaited(_clearActiveSessionSafely());

    await _locationSubscription?.cancel();
    _locationSubscription = null;

    if (generation != _requestGeneration || isClosed) return;

    _lastRerouteTime = null;
    _lastValidDistanceLat = null;
    _lastValidDistanceLon = null;
    emit(const NavigationState());
  }

  @override
  Future<void> close() async {
    DLog.info('🧹 [NavigationBloc] Disposing NavigationBloc and cancelling GPS listeners');
    _requestGeneration++;
    _stopAutoSaveTimer();
    _lastRerouteTime = null;
    _lastValidDistanceLat = null;
    _lastValidDistanceLon = null;
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    return super.close();
  }
}
