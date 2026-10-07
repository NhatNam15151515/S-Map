import 'dart:math' as math;

import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/app_utils.dart';
import 'package:s_map/commons/utils/map_geometry_utils.dart';
import 'package:s_map/models/models.dart';

typedef RouteCalculator = Future<RouteResult> Function({
  required double fromLat,
  required double fromLon,
  required double toLat,
  required double toLon,
  String? vehicleProfile,
});

typedef RoadSnapper = Future<SnappedRoadPoint> Function({
  required double lat,
  required double lon,
});

/// Builds and validates an alternative route using a snapped via point.
class RoutingAlternativeBuilder {
  final RouteCalculator _calculateRoute;
  final RoadSnapper _snapToRoad;

  const RoutingAlternativeBuilder({
    required RouteCalculator calculateRoute,
    required RoadSnapper snapToRoad,
  })  : _calculateRoute = calculateRoute,
        _snapToRoad = snapToRoad;

  /// Tìm lộ trình thay thế bằng chiến lược Waypoint Perturbation.
  /// Lấy điểm dọc lộ trình chính, chiếu pháp tuyến vuông góc sang 2 bên để tìm
  /// đường song song/đường tránh qua `snapToRoad`, sau đó tính lộ trình 2 chặng:
  /// Start -> ViaPoint và ViaPoint -> Destination rồi ghép lại.
  Future<RouteResult?> buildAlternativeRoute({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    required RouteResult primaryRoute,
    required String profile,
  }) async {
    final points = primaryRoute.points;
    if (points.length < 8 || primaryRoute.distance < 400.0) return null;

    final sampleRatios = [0.5, 0.4, 0.6];
    final offsets = [250.0, -250.0, 450.0, -450.0, 650.0, -650.0];

    for (final ratio in sampleRatios) {
      final midIndex = (points.length * ratio).round().clamp(1, points.length - 2);
      final midPoint = points[midIndex];
      final step = math.max(1, (points.length * 0.05).round());
      final prevPoint = points[math.max(0, midIndex - step)];
      final nextPoint = points[math.min(points.length - 1, midIndex + step)];

      final dLat = nextPoint[0] - prevPoint[0];
      final dLon = nextPoint[1] - prevPoint[1];
      final latRad = midPoint[0] * MapGeometryUtils.degToRad;
      final cosLat = math.cos(latRad);
      final dY = dLat * MapGeometryUtils.metersPerDegreeLat;
      final dX = dLon * MapGeometryUtils.metersPerDegreeLat * cosLat;
      final len = math.sqrt(dX * dX + dY * dY);
      if (len < 10.0) continue;

      final normX = -dY / len;
      final normY = dX / len;

      for (final offset in offsets) {
        final candLat =
            midPoint[0] + (normY * offset) / MapGeometryUtils.metersPerDegreeLat;
        final candLon = midPoint[1] +
            (normX * offset) / (MapGeometryUtils.metersPerDegreeLat * cosLat);

        try {
          final snapped = await _snapToRoad(lat: candLat, lon: candLon);
          if (!snapped.isSnapped) continue;

          final distKm = AppUtils.instance.calculateDistance(
            midPoint[0],
            midPoint[1],
            snapped.snappedLat,
            snapped.snappedLon,
          );
          if (distKm * 1000.0 < 70.0) continue;

          final leg1 = await _calculateRoute(
            fromLat: fromLat,
            fromLon: fromLon,
            toLat: snapped.snappedLat,
            toLon: snapped.snappedLon,
            vehicleProfile: profile,
          );
          if (!leg1.isSuccess || !leg1.hasPoints) continue;

          final leg2 = await _calculateRoute(
            fromLat: snapped.snappedLat,
            fromLon: snapped.snappedLon,
            toLat: toLat,
            toLon: toLon,
            vehicleProfile: profile,
          );
          if (!leg2.isSuccess || !leg2.hasPoints) continue;
          if (_hasBacktrackingSpur(leg1.points, leg2.points)) continue;

          final totalDist = leg1.distance + leg2.distance;
          final totalTime = leg1.time + leg2.time;
          final distanceDiff = (totalDist - primaryRoute.distance).abs();
          final isDistinct = distanceDiff > (primaryRoute.distance * 0.03) ||
              ((leg1.points.length + leg2.points.length) !=
                  primaryRoute.points.length);
          if (!isDistinct || totalDist > primaryRoute.distance * 1.45) continue;

          final combinedPoints = <List<double>>[
            ...leg1.points,
            if (leg2.points.length > 1) ...leg2.points.sublist(1),
          ];
          final cleanedLeg1Instructions = leg1.instructions.isNotEmpty &&
                  (leg1.instructions.last.sign == 4 ||
                      leg1.instructions.last.text.toLowerCase().contains('đến'))
              ? leg1.instructions.sublist(0, leg1.instructions.length - 1)
              : leg1.instructions;
          final cleanedLeg2Instructions = leg2.instructions.isNotEmpty &&
                  leg2.instructions.first.sign == 0 &&
                  cleanedLeg1Instructions.isNotEmpty
              ? leg2.instructions.sublist(1)
              : leg2.instructions;
          final combinedInstructions = <RouteInstruction>[
            ...cleanedLeg1Instructions,
            ...cleanedLeg2Instructions,
          ];

          final title = _buildTitle(snapped.streetName, combinedInstructions);
          return RouteResult(
            isSuccess: true,
            distance: totalDist,
            time: totalTime,
            points: combinedPoints,
            instructions: combinedInstructions,
            routeTitle: title,
            isAlternative: true,
          );
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  bool _hasBacktrackingSpur(
    List<List<double>> leg1Points,
    List<List<double>> leg2Points,
  ) {
    if (leg1Points.length < 2 || leg2Points.length < 2) return false;
    final checkCount1 = math.min(12, leg1Points.length - 1);
    final checkCount2 = math.min(12, leg2Points.length - 1);

    for (var i = 1; i <= checkCount1; i++) {
      final p = leg1Points[leg1Points.length - 1 - i];
      for (var j = 1; j <= checkCount2; j++) {
        final q = leg2Points[j];
        if (MapGeometryUtils.haversineDistanceMeters(p[0], p[1], q[0], q[1]) <
            18.0) {
          DLog.info('↩️ [RoutingAlternativeBuilder] Detected retraced route point');
          return true;
        }
      }
    }

    final endPoint = leg1Points.last;
    List<double>? inPoint;
    for (var i = leg1Points.length - 2; i >= 0; i--) {
      final point = leg1Points[i];
      final distance = MapGeometryUtils.haversineDistanceMeters(
        point[0],
        point[1],
        endPoint[0],
        endPoint[1],
      );
      if (distance >= 15.0 || i == 0) {
        inPoint = point;
        break;
      }
    }

    final startPoint = leg2Points.first;
    List<double>? outPoint;
    for (var i = 1; i < leg2Points.length; i++) {
      final point = leg2Points[i];
      final distance = MapGeometryUtils.haversineDistanceMeters(
        point[0],
        point[1],
        startPoint[0],
        startPoint[1],
      );
      if (distance >= 15.0 || i == leg2Points.length - 1) {
        outPoint = point;
        break;
      }
    }

    if (inPoint == null || outPoint == null) return false;
    final latRad = endPoint[0] * MapGeometryUtils.degToRad;
    final cosLat = math.cos(latRad);
    final inDy = (endPoint[0] - inPoint[0]) * MapGeometryUtils.metersPerDegreeLat;
    final inDx = (endPoint[1] - inPoint[1]) *
        MapGeometryUtils.metersPerDegreeLat *
        cosLat;
    final outDy = (outPoint[0] - startPoint[0]) *
        MapGeometryUtils.metersPerDegreeLat;
    final outDx = (outPoint[1] - startPoint[1]) *
        MapGeometryUtils.metersPerDegreeLat *
        cosLat;
    final inLen = math.sqrt(inDx * inDx + inDy * inDy);
    final outLen = math.sqrt(outDx * outDx + outDy * outDy);
    if (inLen <= 1.0 || outLen <= 1.0) return false;

    final cosAngle = (inDx * outDx + inDy * outDy) / (inLen * outLen);
    if (cosAngle < -0.25) {
      DLog.info(
        '↩️ [RoutingAlternativeBuilder] Rejected sharp U-turn (cos=$cosAngle)',
      );
      return true;
    }
    return false;
  }

  String _buildTitle(
    String streetName,
    List<RouteInstruction> instructions,
  ) {
    final rawStreet = streetName.trim();
    if (rawStreet.isNotEmpty && !_isAlleyName(rawStreet)) {
      return 'Qua $rawStreet';
    }

    String? prominentStreet;
    var maxDistance = 0.0;
    for (final instruction in instructions) {
      final name = instruction.streetName.trim();
      if (name.isNotEmpty &&
          !_isAlleyName(name) &&
          instruction.distance > maxDistance) {
        maxDistance = instruction.distance;
        prominentStreet = name;
      }
    }
    return prominentStreet == null ? 'Đường tránh' : 'Qua $prominentStreet';
  }

  bool _isAlleyName(String value) {
    final normalized = value.toLowerCase();
    return normalized.startsWith('hẻm') ||
        normalized.startsWith('ngõ') ||
        normalized.startsWith('đường nội bộ');
  }
}
