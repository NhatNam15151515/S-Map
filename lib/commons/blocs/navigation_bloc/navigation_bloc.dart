import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/transformers/transformers.dart';
import 'package:s_map/commons/utils/app_utils.dart';
import 'package:s_map/commons/utils/off_route_detector.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/services/services.dart';
import 'navigation_event.dart';
import 'navigation_state.dart';

export 'navigation_event.dart';
export 'navigation_state.dart';

class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  final IRoutingRepository _routingRepository;
  final ILocationService _locationService;
  final IOffRouteDetector _offRouteDetector;

  StreamSubscription<Position>? _locationSubscription;
  int _requestGeneration = 0;
  DateTime? _lastRerouteTime;

  /// Khoảng thời gian tối thiểu giữa 2 lần kích hoạt reroute tự động (cooldown 2 giây)
  static const Duration _rerouteCooldown = Duration(seconds: 2);

  /// Bán kính xem như đã đến đích (20 mét)
  static const double _arrivalThresholdMeters = 20.0;

  NavigationBloc({
    required IRoutingRepository routingRepository,
    ILocationService? locationService,
    IOffRouteDetector? offRouteDetector,
  })  : _routingRepository = routingRepository,
        _locationService = locationService ?? LocationService.instance,
        _offRouteDetector = offRouteDetector ?? const OffRouteDetector(),
        super(const NavigationState()) {
    on<StartNavigation>(_onStartNavigation);
    on<LocationUpdated>(_onLocationUpdated);
    on<RerouteRequested>(_onRerouteRequested, transformer: restartable());
    on<StopNavigation>(_onStopNavigation);
  }

  Future<void> _onStartNavigation(
    StartNavigation event,
    Emitter<NavigationState> emit,
  ) async {
    DLog.info(
        '🚀 [NavigationBloc] Starting Navigation to "${event.destinationName}" (${event.destination.lat}, ${event.destination.lon})');

    await _locationSubscription?.cancel();
    _locationSubscription = null;

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
      clearError: true,
      clearMessage: true,
    ));

    _locationSubscription = _locationService.positionStream.listen(
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

  void _onLocationUpdated(
    LocationUpdated event,
    Emitter<NavigationState> emit,
  ) {
    if (!state.isNavigating || !state.hasRoute) return;

    final currentLat = event.latitude;
    final currentLon = event.longitude;
    final speedKmh = event.speed != null ? event.speed! * 3.6 : null;

    // 1. Kiểm tra đã đến đích chưa
    if (state.destination != null) {
      final distToDestKm = AppUtils.instance.calculateDistance(
        currentLat,
        currentLon,
        state.destination!.lat,
        state.destination!.lon,
      );
      final distToDestMeters = distToDestKm * 1000.0;

      if (distToDestMeters <= _arrivalThresholdMeters) {
        DLog.info('🏁 [NavigationBloc] User arrived at destination! (dist=${distToDestMeters.toStringAsFixed(1)}m)');
        emit(state.copyWith(
          status: NavigationStatus.arrived,
          currentLat: currentLat,
          currentLon: currentLon,
          currentSpeedKmh: speedKmh,
          currentHeading: event.heading,
          currentAccuracy: event.accuracy,
          isOffRoute: false,
          distanceToRoute: 0.0,
        ));
        return;
      }
    }

    // 2. Kiểm tra lệch tuyến (Off-route detection)
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
    ));

    // 3. Tự động kích hoạt tính lại đường (Reroute) khi phát hiện lệch tuyến > 50m
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

      if (emit.isDone || generation != _requestGeneration) {
        DLog.info('⏭️ [NavigationBloc] Stale reroute response discarded (#$generation vs #$_requestGeneration)');
        return;
      }

      if (newRoute.isSuccess && newRoute.hasPoints) {
        DLog.info(
            '✅ [NavigationBloc] Reroute calculated successfully: ${(newRoute.distance / 1000).toStringAsFixed(2)}km, ${(newRoute.time / 60000).round()} mins');
        emit(state.copyWith(
          status: NavigationStatus.navigating,
          currentRoute: newRoute,
          origin: event.currentPosition,
          currentSegmentIndex: 0,
          isOffRoute: false,
          isRerouting: false,
          rerouteCount: state.rerouteCount + 1,
          requestGeneration: generation,
          messageKey: LocaleKeys.routing_reroute_success,
          clearError: true,
        ));
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
      if (emit.isDone || generation != _requestGeneration) return;
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
    DLog.info('🛑 [NavigationBloc] Stopping navigation session');
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    _requestGeneration++;
    emit(const NavigationState(status: NavigationStatus.stopped));
  }

  @override
  Future<void> close() async {
    DLog.info('🧹 [NavigationBloc] Disposing NavigationBloc and cancelling GPS listeners');
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    return super.close();
  }
}
