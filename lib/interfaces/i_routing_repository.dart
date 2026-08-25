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

  Future<SnappedRoadPoint> snapToRoad({
    required double lat,
    required double lon,
  });

  Future<bool> isEngineReady();

  Future<bool> dispose();
}
