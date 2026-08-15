import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/services/services.dart';

class RoutingRepositoryImpl implements IRoutingRepository {
  final IRoutingService _routingService;

  RoutingRepositoryImpl({IRoutingService? routingService})
      : _routingService = routingService ?? RoutingServiceImpl.instance;

  @override
  Future<bool> initializeEngine(String graphPath) {
    return _routingService.initGraphHopper(graphPath);
  }

  @override
  Future<RouteResult> calculateRoute({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    String? vehicleProfile,
  }) {
    return _routingService.getRoute(
      fromLat: fromLat,
      fromLon: fromLon,
      toLat: toLat,
      toLon: toLon,
      vehicleProfile: vehicleProfile,
    );
  }

  @override
  Future<bool> isEngineReady() {
    return _routingService.isInitialized();
  }

  @override
  Future<bool> dispose() {
    return _routingService.dispose();
  }
}
