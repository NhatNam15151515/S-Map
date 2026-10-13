import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:s_map/commons/utils/map_geometry_utils.dart';
import 'package:s_map/commons/utils/trip_format_helper.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

/// Dữ liệu một chặng đường / con đường di chuyển trong chuyến đi
class TripLegItem {
  final int index;
  final String title;
  final double distanceMeters;
  final int durationMs;
  final double avgSpeedKmh;
  final double topSpeedKmh;

  const TripLegItem({
    required this.index,
    required this.title,
    required this.distanceMeters,
    required this.durationMs,
    required this.avgSpeedKmh,
    required this.topSpeedKmh,
  });

  /// Quãng đường dạng km
  double get distanceKm => distanceMeters / 1000.0;

  /// Thời gian di chuyển
  Duration get duration => Duration(milliseconds: durationMs);
}

/// Trích xuất và phân tích các chặng / con đường đã đi từ một [TripRecordModel]
class TripLegExtractor {
  /// Phân tích dữ liệu lộ trình thành danh sách các con đường/chặng đường đã đi
  static List<TripLegItem> extractLegs(
    TripRecordModel trip, {
    String? customOrigin,
    String? customDestination,
    String? customStopped,
  }) {
    final polyline = trip.polyline;
    final rawOrigin = (customOrigin != null && customOrigin.trim().isNotEmpty)
        ? customOrigin.trim()
        : TripFormatHelper.getOriginAddress(trip);
    final rawDestination =
        (customDestination != null && customDestination.trim().isNotEmpty)
            ? customDestination.trim()
            : TripFormatHelper.getDestinationAddress(trip);
    final rawStopped =
        (customStopped != null && customStopped.trim().isNotEmpty)
            ? customStopped.trim()
            : TripFormatHelper.getStoppedAddress(trip);

    // Chuẩn hoá: Tránh in toạ độ thô "10.xxxx, 106.yyyy" ra UI nếu không có tên
    final origin = _cleanDisplayTitle(
        rawOrigin, tr(LocaleKeys.stats_dashboard_detail_origin));
    final destination = _cleanDisplayTitle(
        rawDestination, tr(LocaleKeys.stats_dashboard_detail_destination));
    final stopped = _cleanDisplayTitle(
        rawStopped, tr(LocaleKeys.stats_dashboard_detail_stopped_point));
    final actualEndPoint = trip.hasArrived ? destination : stopped;

    // Nếu không có polyline hoặc lộ trình quá ngắn, tạo chặng kết nối duy nhất
    if (polyline == null || polyline.length < 3 || trip.distanceMeters <= 50) {
      final legTitle = origin == actualEndPoint
          ? actualEndPoint
          : '$origin → $actualEndPoint';

      return [
        TripLegItem(
          index: 1,
          title: legTitle,
          distanceMeters: trip.distanceMeters,
          durationMs: trip.durationMs,
          avgSpeedKmh: trip.avgSpeedKmh,
          topSpeedKmh: trip.topSpeedKmh,
        ),
      ];
    }

    // Phát hiện các điểm chuyển hướng chính (ngã rẽ)
    final splitIndices = _detectTurnIndices(polyline);

    // Nếu không phát hiện đủ đoạn rẽ rõ ràng, chia lộ trình thành 2 - 3 chặng cân đối
    final segments = _buildSegments(polyline, splitIndices);

    final totalPolylineDist = _calculatePolylineDistance(polyline);
    final totalDurationMs = math.max(trip.durationMs, 1000);
    final legs = <TripLegItem>[];

    for (int i = 0; i < segments.length; i++) {
      final segPoints = segments[i];
      final segDist = _calculatePolylineDistance(segPoints);

      // Phân bổ thời gian theo tỷ lệ quãng đường
      final ratio = totalPolylineDist > 0
          ? (segDist / totalPolylineDist)
          : (1.0 / segments.length);
      final segDurationMs = math.max((totalDurationMs * ratio).round(), 1000);

      // Tính vận tốc trung bình và tối đa của từng chặng
      final hours = segDurationMs / 3600000.0;
      double segAvgSpeed =
          hours > 0 ? (segDist / 1000.0) / hours : trip.avgSpeedKmh;
      if (!segAvgSpeed.isFinite || segAvgSpeed <= 0) {
        segAvgSpeed = trip.avgSpeedKmh;
      }

      // Vận tốc tối đa ước tính trong chặng (không vượt quá topSpeed của chuyến đi)
      final segTopSpeed = math.min(
        trip.topSpeedKmh > 0 ? trip.topSpeedKmh : segAvgSpeed * 1.25,
        math.max(segAvgSpeed * 1.25, segAvgSpeed),
      );

      // Đặt tên chặng rõ ràng, mô tả điểm bắt đầu, trung gian và điểm đến
      final String segTitle;
      if (segments.length == 1) {
        segTitle = '$origin → $actualEndPoint';
      } else if (i == 0) {
        segTitle = '${tr(LocaleKeys.stats_dashboard_detail_origin)}: $origin';
      } else if (i == segments.length - 1) {
        final destLabel = trip.hasArrived
            ? tr(LocaleKeys.stats_dashboard_detail_destination)
            : tr(LocaleKeys.stats_dashboard_detail_stopped_point);
        segTitle = '$destLabel: $actualEndPoint';
      } else {
        segTitle = tr(LocaleKeys.stats_dashboard_detail_leg_street,
            args: ['${i + 1}']);
      }

      legs.add(
        TripLegItem(
          index: i + 1,
          title: segTitle,
          distanceMeters: segDist,
          durationMs: segDurationMs,
          avgSpeedKmh: double.parse(segAvgSpeed.toStringAsFixed(1)),
          topSpeedKmh: double.parse(segTopSpeed.toStringAsFixed(1)),
        ),
      );
    }

    return legs;
  }

  /// Phát hiện các index có góc rẽ đáng kể trong polyline
  static List<int> _detectTurnIndices(List<List<double>> points) {
    final turns = <int>[0];
    double accumulatedDist = 0.0;

    for (int i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final next = points[i + 1];

      final dist = MapGeometryUtils.haversineDistanceMeters(
        prev[0],
        prev[1],
        curr[0],
        curr[1],
      );
      accumulatedDist += dist;

      // Chỉ xét điểm rẽ khi đã đi được ít nhất 200m kể từ chặng trước
      if (accumulatedDist >= 200.0) {
        final b1 = _bearing(prev[0], prev[1], curr[0], curr[1]);
        final b2 = _bearing(curr[0], curr[1], next[0], next[1]);
        final angleDiff = (b2 - b1).abs();
        final normalizedAngle = angleDiff > 180 ? 360 - angleDiff : angleDiff;

        if (normalizedAngle >= 35.0) {
          turns.add(i);
          accumulatedDist = 0.0;
          if (turns.length >= 5) {
            break; // Giới hạn tối đa 5 chặng để hiển thị tối ưu
          }
        }
      }
    }

    if (turns.last != points.length - 1) {
      turns.add(points.length - 1);
    }

    return turns;
  }

  /// Tách danh sách points thành các sub-list tương ứng
  static List<List<List<double>>> _buildSegments(
    List<List<double>> points,
    List<int> splitIndices,
  ) {
    if (splitIndices.length <= 2) {
      // Nếu ít hơn 2 điểm rẽ, chia đều 2 hoặc 3 phần nếu tuyến đường dài
      if (points.length >= 20) {
        final mid = points.length ~/ 2;
        return [
          points.sublist(0, mid + 1),
          points.sublist(mid),
        ];
      }
      return [points];
    }

    final segments = <List<List<double>>>[];
    for (int i = 0; i < splitIndices.length - 1; i++) {
      final start = splitIndices[i];
      final end = splitIndices[i + 1];
      if (end > start) {
        segments.add(points.sublist(start, end + 1));
      }
    }
    return segments.isNotEmpty ? segments : [points];
  }

  /// Tính tổng chiều dài một mảng toạ độ (mét). Delegate sang [MapGeometryUtils.polylineLengthMeters].
  static double _calculatePolylineDistance(List<List<double>> points) {
    return MapGeometryUtils.polylineLengthMeters(points);
  }

  /// Tính bearing (góc hướng di chuyển) giữa 2 tọa độ. Delegate sang [MapGeometryUtils.bearing].
  static double _bearing(double lat1, double lon1, double lat2, double lon2) {
    return MapGeometryUtils.bearing(lat1, lon1, lat2, lon2);
  }

  static String _cleanDisplayTitle(String raw, String fallback) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return fallback;
    // Kiểm tra nếu là toạ độ thô dạng "10.7878, 106.7045"
    if (RegExp(r'^\d+\.\d+\s*,\s*\d+\.\d+$').hasMatch(trimmed)) {
      return fallback;
    }
    return trimmed;
  }
}
