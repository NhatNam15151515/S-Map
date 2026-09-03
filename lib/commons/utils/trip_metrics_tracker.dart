import 'package:s_map/commons/utils/app_utils.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';

/// Bộ tính toán và tích luỹ số liệu hành trình (Trip Metrics & Statistics Tracker)
///
/// Xử lý lọc nhiễu GPS (deadband), cộng dồn quãng đường, thống kê vận tốc
/// và sinh đối tượng TripSummary / TripRecordModel.
class TripMetricsTracker {
  double totalDistanceTraveledMeters = 0.0;
  double maxSpeedKmh = 0.0;
  double speedSampleSum = 0.0;
  int speedSampleCount = 0;
  bool hasMoved = false;

  double? lastValidLat;
  double? lastValidLon;

  TripMetricsTracker({
    this.totalDistanceTraveledMeters = 0.0,
    this.maxSpeedKmh = 0.0,
    this.speedSampleSum = 0.0,
    this.speedSampleCount = 0,
    this.hasMoved = false,
    this.lastValidLat,
    this.lastValidLon,
  });

  void reset() {
    totalDistanceTraveledMeters = 0.0;
    maxSpeedKmh = 0.0;
    speedSampleSum = 0.0;
    speedSampleCount = 0;
    hasMoved = false;
    lastValidLat = null;
    lastValidLon = null;
  }

  /// Khôi phục số liệu tích lũy từ snapshot
  void restoreFromSnapshot(ActiveTripSnapshot snapshot) {
    totalDistanceTraveledMeters = snapshot.totalDistanceTraveledMeters;
    maxSpeedKmh = snapshot.maxSpeedKmh;
    speedSampleSum = snapshot.speedSampleSum;
    speedSampleCount = snapshot.speedSampleCount;
    lastValidLat = snapshot.lastKnownLat;
    lastValidLon = snapshot.lastKnownLon;
    hasMoved = false;
  }

  /// Ghi nhận toạ độ mới từ GPS fix hợp lệ và cập nhật số liệu
  void recordFix({
    required double lat,
    required double lon,
    required double? speedKmh,
  }) {
    // 1. Cập nhật thống kê vận tốc
    if (speedKmh != null && speedKmh > maxSpeedKmh) {
      maxSpeedKmh = speedKmh;
    }
    if (speedKmh != null && speedKmh > 0) {
      speedSampleSum += speedKmh;
      speedSampleCount++;
    }

    // 2. Tích luỹ quãng đường có lọc nhiễu deadband
    if (lastValidLat != null && lastValidLon != null) {
      final deltaKm = AppUtils.instance.calculateDistance(
        lastValidLat!,
        lastValidLon!,
        lat,
        lon,
      );
      final deltaMeters = deltaKm * RoutingConstants.metersPerKm;

      // Bỏ qua rung lắc GPS khi dừng xe (< 1m) và bước nhảy đột biến (> 200m)
      if (deltaMeters >= RoutingConstants.minGpsMovementDeltaMeters &&
          deltaMeters <= RoutingConstants.maxGpsJumpDeltaMeters) {
        totalDistanceTraveledMeters += deltaMeters;
        hasMoved = true;
        lastValidLat = lat;
        lastValidLon = lon;
      }
    } else {
      lastValidLat = lat;
      lastValidLon = lon;
    }
  }

  /// Tạo báo cáo tổng kết chuyến đi (TripSummary)
  TripSummary buildSummary({
    required DateTime startTime,
    required DateTime endTime,
    required String? destinationName,
    required bool hasArrived,
  }) {
    final tripDuration = endTime.difference(startTime);
    final avgSpeed = tripDuration.inMilliseconds > 0
        ? (totalDistanceTraveledMeters / RoutingConstants.metersPerKm) /
            (tripDuration.inMilliseconds / RoutingConstants.msPerHour)
        : 0.0;

    return TripSummary(
      duration: tripDuration,
      distanceMeters: totalDistanceTraveledMeters,
      avgSpeedKmh: avgSpeed.isFinite ? avgSpeed : 0.0,
      topSpeedKmh: maxSpeedKmh,
      destinationName: destinationName,
      hasArrived: hasArrived,
    );
  }

  /// Tạo bản ghi lưu trữ chuyến đi (TripRecordModel)
  TripRecordModel buildRecord({
    required String id,
    required DateTime startTime,
    required DateTime endTime,
    required String? destinationName,
    required String profile,
    required List<List<double>>? polyline,
    required bool hasArrived,
  }) {
    final tripDuration = endTime.difference(startTime);
    final avgSpeed = tripDuration.inMilliseconds > 0
        ? (totalDistanceTraveledMeters / RoutingConstants.metersPerKm) /
            (tripDuration.inMilliseconds / RoutingConstants.msPerHour)
        : 0.0;

    return TripRecordModel(
      id: id,
      startTime: startTime,
      endTime: endTime,
      durationMs: tripDuration.inMilliseconds,
      distanceMeters: totalDistanceTraveledMeters,
      avgSpeedKmh: avgSpeed.isFinite ? avgSpeed : 0.0,
      topSpeedKmh: maxSpeedKmh,
      destinationName: destinationName,
      originName: null,
      hasArrived: hasArrived,
      vehicleProfile: profile,
      polyline: polyline,
      createdAt: endTime,
    );
  }
}
