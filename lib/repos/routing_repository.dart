import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/usecases/routing_alternative_builder.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/services/routing_graph_data_loader.dart';

class RoutingRepositoryImpl implements IRoutingRepository {
  final IRoutingService _routingService;
  final RoutingGraphDataLoader _graphDataLoader =
      const RoutingGraphDataLoader();
  Future<void>? _autoInitFuture;
  int _lifecycleSession = 0;
  int _activeInitSession = 0;
  late final RoutingAlternativeBuilder _alternativeRouteBuilder =
      RoutingAlternativeBuilder(
    calculateRoute: calculateRoute,
    snapToRoad: snapToRoad,
  );

  RoutingRepositoryImpl({required IRoutingService routingService})
      : _routingService = routingService;

  @override
  Future<bool> initializeEngine(String graphPath) async {
    DLog.info(
        '🏛️ [RoutingRepository] Explicit initializeEngine called with: "$graphPath"');
    final targetSession = ++_lifecycleSession;
    _autoInitFuture = null;
    final success = await _routingService.initGraphHopper(graphPath);
    if (targetSession != _lifecycleSession) {
      if (_activeInitSession == 0) {
        await _routingService.dispose();
      }
      return false;
    }
    if (success) {
      _activeInitSession = targetSession;
    }
    return success;
  }

  /// Tự động tìm và nạp file đồ thị đường đi (.ghz hoặc thư mục giải nén) nếu có trên thiết bị
  Future<void> _ensureAutoInitialized() async {
    final isReady = await _routingService.isInitialized();
    if (isReady) return;

    _autoInitFuture ??= _ensureAutoInitializedImpl();
    await _autoInitFuture;

    final readyAfter = await _routingService.isInitialized();
    if (!readyAfter) {
      _autoInitFuture = null;
    }
  }

  Future<void> _ensureAutoInitializedImpl() async {
    DLog.info('🔍 [RoutingRepository] Executing _ensureAutoInitializedImpl');
    final currentSession = _lifecycleSession;
    try {
      final isReady = await _routingService.isInitialized();
      if (currentSession != _lifecycleSession || isReady) return;

      Future<bool> tryInit(String path) async {
        if (currentSession != _lifecycleSession) return false;
        final success = await _routingService.initGraphHopper(path);
        if (currentSession != _lifecycleSession) {
          if (_activeInitSession == 0) await _routingService.dispose();
          return false;
        }
        if (success) _activeInitSession = currentSession;
        return success;
      }

      await _graphDataLoader.initializeFromAvailableData(
        initializeGraph: tryInit,
      );
    } catch (error, stack) {
      DLog.error(
        '❌ [RoutingRepository] Auto-init check exception: $error',
        error,
        stack,
      );
    }
  }

  @override
  Future<RouteResult> calculateRoute({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    String? vehicleProfile,
  }) async {
    // S-Map chuyên dụng cho xe máy (moped_vn), mọi yêu cầu điều hướng đều dùng profile này
    const effectiveProfile = RoutingConstants.profileMopedVn;
    DLog.info(
        '🏍️ [RoutingRepository] calculateRoute requested: ($fromLat, $fromLon) -> ($toLat, $toLon) | profile: $effectiveProfile (requested: $vehicleProfile)');
    await _ensureAutoInitialized();

    final isReady = await _routingService.isInitialized();
    DLog.info(
        '🏍️ [RoutingRepository] isEngineReady after auto-init check: $isReady');
    if (isReady) {
      final nativeResult = await _routingService.getRoute(
        fromLat: fromLat,
        fromLon: fromLon,
        toLat: toLat,
        toLon: toLon,
        vehicleProfile: effectiveProfile,
      );
      DLog.info(
          '🏍️ [RoutingRepository] Native route result status: isSuccess=${nativeResult.isSuccess}, distance=${nativeResult.distance}m, points=${nativeResult.points.length}, error="${nativeResult.errorMessage}"');
      return nativeResult;
    }

    DLog.warning(
        '⚠️ [RoutingRepository] Native GraphHopper not ready -> returning failure result');
    return RouteResult.failure(
      RoutingConstants.errServiceNotInitialized,
    );
  }

  @override
  Future<List<RouteResult>> calculateAlternativeRoutes({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    String? vehicleProfile,
  }) async {
    final primaryProfile = vehicleProfile ?? RoutingConstants.profileMopedVn;
    DLog.info(
        '🔀 [RoutingRepository] calculateAlternativeRoutes requested: ($fromLat, $fromLon) -> ($toLat, $toLon) | profile: $primaryProfile');

    // 1. Tính toán lộ trình chính (Primary Route)
    final primaryRoute = await calculateRoute(
      fromLat: fromLat,
      fromLon: fromLon,
      toLat: toLat,
      toLon: toLon,
      vehicleProfile: primaryProfile,
    );

    if (!primaryRoute.isSuccess || !primaryRoute.hasPoints) {
      return [primaryRoute];
    }

    // 2. Tìm lộ trình thay thế (Alternative Route):
    // Hệ thống chỉ hỗ trợ chuyên dụng xe máy (moped_vn), sử dụng chiến lược
    // Waypoint Perturbation (Tìm đường song song/đường tránh qua snapToRoad)
    final altRoute = await _alternativeRouteBuilder.buildAlternativeRoute(
      fromLat: fromLat,
      fromLon: fromLon,
      toLat: toLat,
      toLon: toLon,
      primaryRoute: primaryRoute,
      profile: primaryProfile,
    );

    if (altRoute != null) {
      final namedPrimary = primaryRoute.copyWith(
        routeTitle: 'Nhanh nhất',
      );
      DLog.info(
          '✅ [RoutingRepository] Found distinct alternative route: Primary=${primaryRoute.distance}m vs Alt=${altRoute.distance}m (${altRoute.routeTitle})');
      return [namedPrimary, altRoute];
    }

    return [primaryRoute.copyWith(routeTitle: 'Lộ trình tối ưu')];
  }

  @override
  Future<SnappedRoadPoint> snapToRoad({
    required double lat,
    required double lon,
  }) async {
    DLog.info('📍 [RoutingRepository] snapToRoad requested: ($lat, $lon)');
    await _ensureAutoInitialized();

    final isReady = await _routingService.isInitialized();
    if (isReady) {
      final snapResult = await _routingService.snapToRoad(
        lat: lat,
        lon: lon,
      );
      DLog.info(
          '📍 [RoutingRepository] Native snap result: isSnapped=${snapResult.isSnapped}, snapped=(${snapResult.snappedLat}, ${snapResult.snappedLon}), street="${snapResult.streetName}", dist=${snapResult.distanceToRoad}m');
      return snapResult;
    }

    DLog.warning(
        '💡 [RoutingRepository] Native GraphHopper not ready -> returning notSnapped fallback');
    return SnappedRoadPoint.notSnapped(
      originalLat: lat,
      originalLon: lon,
      errorMessage: RoutingConstants.errServiceNotInitialized,
    );
  }

  @override
  Future<bool> isEngineReady() async {
    final ready = await _routingService.isInitialized();
    if (ready) return true;
    await _ensureAutoInitialized();
    return _routingService.isInitialized();
  }

  @override
  Future<bool> dispose() {
    DLog.info('🧹 [RoutingRepository] dispose called');
    _lifecycleSession++;
    _activeInitSession = 0;
    _autoInitFuture = null;
    return _routingService.dispose();
  }

}
