import 'package:s_map/models/models.dart';

abstract class IRoutingService {
  Future<bool> initGraphHopper(String graphPath);

  Future<RouteResult> getRoute({
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

  Future<bool> isInitialized();

  Future<bool> dispose();
}
