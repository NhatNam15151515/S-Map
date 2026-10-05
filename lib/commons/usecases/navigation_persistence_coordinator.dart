import 'dart:async';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/app_utils.dart';
import 'package:s_map/commons/utils/map_geometry_utils.dart';
import 'package:s_map/commons/utils/trip_address_resolver.dart';
import 'package:s_map/commons/utils/trip_metrics_tracker.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/services/routing_service.dart';

/// Kết quả tổng kết và bản ghi hành trình khi kết thúc phiên dẫn đường
class TripFinalizationResult {
  final TripSummary summary;
  final TripRecordModel record;

  const TripFinalizationResult({
    required this.summary,
    required this.record,
  });
}

/// Coordinator quản lý lưu trữ và vòng đời dữ liệu chuyến đi
///
/// Tách biệt hoàn toàn việc lưu Hive, SQLite và Visited POI khỏi NavigationBloc.
class NavigationPersistenceCoordinator {
  final ITripRepository _tripRepository;
  final IActiveTripService _activeTripService;
  final IVisitedPoiService _visitedPoiService;
  final Duration autoSaveInterval;

  Timer? _autoSaveTimer;

  NavigationPersistenceCoordinator({
    required ITripRepository tripRepository,
    required IActiveTripService activeTripService,
    required IVisitedPoiService visitedPoiService,
    this.autoSaveInterval = const Duration(seconds: 30),
  })  : _tripRepository = tripRepository,
        _activeTripService = activeTripService,
        _visitedPoiService = visitedPoiService;

  void startAutoSave(void Function() onAutoSave) {
    stopAutoSave();
    _autoSaveTimer = Timer.periodic(autoSaveInterval, (_) => onAutoSave());
  }

  void stopAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  Future<void> saveActiveSession(ActiveTripSnapshot snapshot) async {
    await _activeTripService.saveActiveSession(snapshot);
  }

  Future<ActiveTripSnapshot?> getActiveSession() async {
    return _activeTripService.getActiveSession();
  }

  Future<bool> isSessionExpired(ActiveTripSnapshot snapshot) async {
    if (!snapshot.isValid()) {
      DLog.warning(
          '⚠️ [NavigationPersistenceCoordinator] Cannot resume: active session expired (> 24h)');
      unawaited(clearActiveSessionSafely());
      return true;
    }
    return false;
  }

  Future<void> clearActiveSessionSafely() async {
    try {
      await _activeTripService.clearActiveSession();
    } catch (e, stack) {
      DLog.error(
          '❌ [NavigationPersistenceCoordinator] Failed to clear active session: $e',
          e,
          stack);
    }
  }

  Future<void> saveTripSafely(TripRecordModel trip) async {
    try {
      await _tripRepository.saveTrip(trip);
    } catch (e, stack) {
      DLog.error(
          '❌ [NavigationPersistenceCoordinator] Failed to auto-save trip: $e',
          e,
          stack);
    }
  }

  Future<void> recordVisitedDestinationSafely(
    RoutePoint? destination,
    String? destinationName,
  ) async {
    if (destination == null) return;

    final name = destinationName?.trim();
    final displayName = name == null || name.isEmpty ? 'Điểm đã đến' : name;
    final poi = PoiModel(
      osmId:
          'visited:${destination.lat.toStringAsFixed(6)}:${destination.lon.toStringAsFixed(6)}',
      name: displayName,
      nameAscii: AppUtils.instance.toAscii(displayName),
      category: 'place',
      lat: destination.lat,
      lon: destination.lon,
    );

    try {
      await _visitedPoiService.recordVisited(poi);
    } catch (e, stack) {
      DLog.warning(
          '⚠️ [NavigationPersistenceCoordinator] Không thể lưu POI đã đến: $e',
          stack);
    }
  }

  /// Tổng kết và hoàn tất lưu trữ chuyến đi (dùng chung cho cả Arrive và Stop)
  Future<TripFinalizationResult> finalizeTrip({
    required TripMetricsTracker metrics,
    required DateTime? startTime,
    required RoutePoint? destination,
    required String? destinationName,
    required String profile,
    required List<List<double>>? polyline,
    required bool hasArrived,
    double? stopLat,
    double? stopLon,
    int? currentSegmentIndex,
    String? originName,
  }) async {
    stopAutoSave();
    unawaited(clearActiveSessionSafely());

    final now = DateTime.now();
    final effectiveStartTime = startTime ?? now;

    final summary = metrics.buildSummary(
      startTime: effectiveStartTime,
      endTime: now,
      destinationName: destinationName,
      hasArrived: hasArrived,
    );

    // 1. Xác định toạ độ dừng thực tế
    final actualStopLat = stopLat ?? metrics.lastValidLat;
    final actualStopLon = stopLon ?? metrics.lastValidLon;

    // 2. Tra cứu tên địa chỉ dừng chân (stoppedName) khi dừng giữa đường
    String? stoppedName;
    if (!hasArrived) {
      if (actualStopLat != null && actualStopLon != null) {
        stoppedName = await TripAddressResolver.resolveAddressAtCoordinate(
          actualStopLat,
          actualStopLon,
        );
      } else if (polyline != null && polyline.isNotEmpty) {
        final lastPoint = polyline.last;
        stoppedName = await TripAddressResolver.resolveAddressAtCoordinate(
          lastPoint[0],
          lastPoint[1],
        );
      }
    }

    // 2.1. Tự động tra cứu số nhà/tên đường cho Điểm xuất phát (originName)
    // Ưu tiên snapToRoad (GraphHopper) để lấy tên đường chính xác tại toạ độ GPS,
    // tránh lấy nhầm tên đường từ POI gần nhưng thuộc đường khác (ví dụ: ngã ba)
    String? effectiveOriginName = originName;
    if ((effectiveOriginName == null || effectiveOriginName.trim().isEmpty) &&
        polyline != null &&
        polyline.isNotEmpty) {
      final startPoint = polyline.first;

      // Thử 1: snapToRoad cho tên đường chính xác nhất
      try {
        final routingService =
            await _getRoutingService();
        if (routingService != null) {
          final snapped = await routingService.snapToRoad(
            lat: startPoint[0],
            lon: startPoint[1],
          );
          if (snapped.isSnapped &&
              snapped.streetName.trim().isNotEmpty &&
              snapped.distanceToRoad <= 30.0) {
            effectiveOriginName = snapped.streetName.trim();
          }
        }
      } catch (e) {
        DLog.warning(
            '⚠️ [NavigationPersistenceCoordinator] snapToRoad for origin failed: $e');
      }

      // Thử 2: Fallback về TripAddressResolver (POI database)
      if (effectiveOriginName == null || effectiveOriginName.trim().isEmpty) {
        effectiveOriginName =
            await TripAddressResolver.resolveAddressAtCoordinate(
          startPoint[0],
          startPoint[1],
        );
      }
    }

    // 3. Xử lý polyline thực tế đã đi:
    // - Khi đến đích (hasArrived = true): Lưu toàn bộ polyline theo tuyến đường
    // - Khi dừng giữa đường (hasArrived = false): Cắt ngắn polyline đến điểm dừng thực tế
    List<List<double>>? effectivePolyline;
    if (hasArrived) {
      effectivePolyline = polyline;
    } else if (polyline != null && polyline.isNotEmpty) {
      if (actualStopLat != null && actualStopLon != null) {
        if (!metrics.hasMoved && metrics.totalDistanceTraveledMeters < 30.0) {
          effectivePolyline = [
            polyline.first,
            [actualStopLat, actualStopLon],
          ];
        } else {
          final cutIndex = _findCutIndex(
            polyline,
            currentSegmentIndex,
            actualStopLat,
            actualStopLon,
          );
          final sliced = polyline.sublist(0, cutIndex).toList();
          sliced.add([actualStopLat, actualStopLon]);
          effectivePolyline = sliced;
        }
      } else {
        effectivePolyline = polyline;
      }
    }

    final record = metrics.buildRecord(
      id: 'trip_${now.microsecondsSinceEpoch}_${now.hashCode.abs()}',
      startTime: effectiveStartTime,
      endTime: now,
      destinationName: destinationName,
      originName: effectiveOriginName,
      stoppedName: stoppedName,
      profile: profile,
      polyline: effectivePolyline,
      hasArrived: hasArrived,
    );

    unawaited(saveTripSafely(record));
    if (hasArrived && destination != null) {
      await recordVisitedDestinationSafely(destination, destinationName);
    }

    return TripFinalizationResult(summary: summary, record: record);
  }

  int _findCutIndex(
    List<List<double>> points,
    int? currentSegmentIndex,
    double stopLat,
    double stopLon,
  ) {
    if (currentSegmentIndex != null &&
        currentSegmentIndex >= 0 &&
        currentSegmentIndex < points.length) {
      return (currentSegmentIndex + 1).clamp(1, points.length);
    }

    // Fallback: tìm điểm gần nhất trên polyline bằng chiếu hình cos(lat)-corrected
    final (closestIdx, _, _, _) = MapGeometryUtils.findClosestPointOnPolyline(
      pLat: stopLat,
      pLon: stopLon,
      points: points,
    );
    return (closestIdx + 1).clamp(1, points.length);
  }

  /// Lấy RoutingService instance (có thể mở rộng thành DI sau)
  Future<IRoutingService?> _getRoutingService() async {
    try {
      return RoutingServiceImpl.instance;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    stopAutoSave();
  }
}
