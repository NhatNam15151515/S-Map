import 'package:s_map/models/models.dart';

abstract class IRoutingRepository {
  Future<bool> initializeEngine(String graphPath);

  Future<RouteResult> calculateRoute({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    String? vehicleProfile,
  });

  Future<bool> isEngineReady();

  Future<bool> dispose();
}
