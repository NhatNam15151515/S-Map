import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/app_utils.dart';
import 'package:s_map/commons/utils/map_geometry_utils.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/poi_repository.dart';
import 'package:s_map/services/services.dart';

/// Helper chuyên biệt tra cứu thông tin địa chỉ (số nhà, tên đường, địa điểm)
/// tại một tọa độ địa lý cụ thể (ví dụ vị trí dừng của chuyến đi) trong bán kính hẹp (3-15m).
class TripAddressResolver {
  TripAddressResolver._();

  /// Tra cứu thông tin địa chỉ ngay tại vị trí dừng:
  /// - Ưu tiên 1: Số nhà + tên đường từ POI Database offline trong bán kính cực gần (3-15m)
  /// - Ưu tiên 2: Tên con đường gần nhất từ engine snapToRoad (GraphHopper)
  /// - Trả về null nếu không phát hiện địa chỉ/con đường nào trong phạm vi
  static Future<String?> resolveAddressAtCoordinate(
    double lat,
    double lon, {
    double targetRadiusMeters = 5.0,
    double maxRadiusMeters = 30.0,
    IPoiRepository? poiRepository,
    IRoutingService? routingService,
  }) async {
    // 1. Thử tìm kiếm trong cơ sở dữ liệu POI / Địa chỉ offline với cơ chế ưu tiên thông minh
    try {
      final (deltaLat, deltaLon) =
          MapGeometryUtils.boundingBoxDelta(lat, maxRadiusMeters);

      final poiRepo = poiRepository ?? PoiRepositoryImpl();
      final candidates = await poiRepo.searchInBounds(
        minLat: lat - deltaLat,
        maxLat: lat + deltaLat,
        minLon: lon - deltaLon,
        maxLon: lon + deltaLon,
        limit: 30,
      );

      if (candidates.isNotEmpty) {
        PoiModel? bestHouseAndStreet;
        double minHouseDist = double.infinity;

        PoiModel? bestAddress;
        double minAddressDist = double.infinity;

        PoiModel? bestStreet;
        double minStreetDist = double.infinity;

        PoiModel? bestNamedPoi;
        double minNamedDist = double.infinity;

        for (final poi in candidates) {
          final distMeters = AppUtils.instance
                  .calculateDistance(lat, lon, poi.lat, poi.lon) *
              1000.0;

          if (distMeters > maxRadiusMeters) continue;

          final house = poi.housenumber?.trim();
          final street = poi.street?.trim();
          final address = poi.address?.trim();
          final name = poi.name.trim();

          // Nhóm 1: Có cả số nhà và tên đường
          if (house != null &&
              house.isNotEmpty &&
              street != null &&
              street.isNotEmpty) {
            if (distMeters < minHouseDist) {
              minHouseDist = distMeters;
              bestHouseAndStreet = poi;
            }
          }

          // Nhóm 2: Có trường địa chỉ
          if (address != null && address.isNotEmpty) {
            if (distMeters < minAddressDist) {
              minAddressDist = distMeters;
              bestAddress = poi;
            }
          }

          // Nhóm 3: Có tên đường
          if (street != null && street.isNotEmpty) {
            if (distMeters < minStreetDist) {
              minStreetDist = distMeters;
              bestStreet = poi;
            }
          }

          // Nhóm 4: Có tên địa điểm
          if (name.isNotEmpty) {
            if (distMeters < minNamedDist) {
              minNamedDist = distMeters;
              bestNamedPoi = poi;
            }
          }
        }

        // Ưu tiên 1 cao nhất: Số nhà + Tên đường
        if (bestHouseAndStreet != null) {
          final formatted =
              '${bestHouseAndStreet.housenumber!.trim()} ${bestHouseAndStreet.street!.trim()}';
          DLog.info(
              '📍 [TripAddressResolver] Found exact house & street: $formatted (${minHouseDist.toStringAsFixed(1)}m)');
          return formatted;
        }

        // Ưu tiên 2: Địa chỉ chi tiết
        if (bestAddress != null) {
          DLog.info(
              '📍 [TripAddressResolver] Found address: ${bestAddress.address} (${minAddressDist.toStringAsFixed(1)}m)');
          return bestAddress.address!.trim();
        }

        // Ưu tiên 3: Tên con đường
        if (bestStreet != null) {
          DLog.info(
              '📍 [TripAddressResolver] Found street: ${bestStreet.street} (${minStreetDist.toStringAsFixed(1)}m)');
          return bestStreet.street!.trim();
        }

        // Ưu tiên 4: Tên địa điểm cụ thể (quán cà phê, cửa hàng...)
        if (bestNamedPoi != null) {
          DLog.info(
              '📍 [TripAddressResolver] Found POI name: ${bestNamedPoi.name} (${minNamedDist.toStringAsFixed(1)}m)');
          return bestNamedPoi.name.trim();
        }
      }
    } catch (e) {
      DLog.warning('⚠️ [TripAddressResolver] POI lookup failed: $e');
    }

    // 2. Thử nắn vào tim đường gần nhất qua GraphHopper RoutingService
    try {
      final router = routingService ?? RoutingServiceImpl.instance;
      final snapped = await router.snapToRoad(lat: lat, lon: lon);

      if (snapped.isSnapped &&
          snapped.streetName.trim().isNotEmpty &&
          snapped.distanceToRoad <= maxRadiusMeters * 2) {
        final roadName = snapped.streetName.trim();
        DLog.info(
            '🛣️ [TripAddressResolver] Found snapped road: $roadName (${snapped.distanceToRoad.toStringAsFixed(1)}m)');
        return roadName;
      }
    } catch (e) {
      DLog.warning('⚠️ [TripAddressResolver] snapToRoad lookup failed: $e');
    }

    return null;
  }
}
