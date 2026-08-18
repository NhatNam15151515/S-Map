import 'dart:math' as math;
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

/// Bộ máy phân tích và điều phối chỉ dẫn rẽ từng chặng (Turn-by-turn Instruction Engine)
/// Xử lý tự động chuyển chặng (Advance logic), cảnh báo trước (Pre-announce) và tính ETA/khoảng cách còn lại.
class TurnByTurnEngine implements ITurnByTurnEngine {
  static const double _earthRadiusMeters = 6371000.0;
  static const double _degToRad = math.pi / 180.0;

  @override
  final double advanceThresholdMeters;

  @override
  final double preAnnounceThresholdMeters;

  @override
  final double arrivalThresholdMeters;

  const TurnByTurnEngine({
    this.advanceThresholdMeters = RoutingConstants.defaultAdvanceThresholdMeters,
    this.preAnnounceThresholdMeters = RoutingConstants.defaultPreAnnounceThresholdMeters,
    this.arrivalThresholdMeters = RoutingConstants.defaultArrivalThresholdMeters,
  });

  @override
  InstructionProgress initializeProgress(List<RouteInstruction> instructions) {
    if (instructions.isEmpty) {
      return const InstructionProgress();
    }

    final totalDistance = instructions.fold<double>(
      0.0,
      (sum, item) => sum + item.distance,
    );
    final totalDurationMs = instructions.fold<int>(
      0,
      (sum, item) => sum + item.time,
    );

    final firstInstruction = instructions.first;
    final nextInstruction = instructions.length > 1 ? instructions[1] : null;

    final initialDistanceToNext = firstInstruction.distance;
    final isPreAnnounced = initialDistanceToNext <= preAnnounceThresholdMeters;

    return InstructionProgress(
      currentInstructionIndex: 0,
      currentInstruction: firstInstruction,
      nextInstruction: nextInstruction,
      distanceToNextInstruction: initialDistanceToNext,
      remainingDistance: totalDistance,
      remainingDurationMs: totalDurationMs,
      isPreAnnounced: isPreAnnounced,
      hasArrived: false,
    );
  }

  @override
  InstructionProgress updateProgress({
    required double currentLat,
    required double currentLon,
    required List<RouteInstruction> instructions,
    required int currentInstructionIndex,
    List<List<double>> routePoints = const [],
    int currentSegmentIndex = 0,
  }) {
    if (instructions.isEmpty) {
      return const InstructionProgress();
    }

    int activeIndex = currentInstructionIndex.clamp(0, instructions.length - 1);
    double distToNextMeters = 0.0;

    // 1. Advance Logic: Kiểm tra xem đã vượt qua / đến gần (< 30m) điểm rẽ kế tiếp chưa
    while (activeIndex < instructions.length - 1) {
      final nextInstruction = instructions[activeIndex + 1];
      final currentInstruction = instructions[activeIndex];

      // Mốc chuyển hướng là điểm bắt đầu của chặng tiếp theo hoặc điểm kết thúc chặng hiện tại
      final maneuverPoint = nextInstruction.points.isNotEmpty
          ? nextInstruction.points.first
          : (currentInstruction.points.isNotEmpty
              ? currentInstruction.points.last
              : null);

      if (maneuverPoint == null) {
        distToNextMeters = currentInstruction.distance;
        break;
      }

      final d = _calculateHaversineDistanceMeters(
        currentLat,
        currentLon,
        maneuverPoint[0],
        maneuverPoint[1],
      );

      if (d < advanceThresholdMeters) {
        activeIndex++;
        distToNextMeters = d;
        DLog.info(
          '⏭️ [TurnByTurnEngine] Advance to instruction #$activeIndex: "${instructions[activeIndex].text}" (dist=${d.toStringAsFixed(1)}m < ${advanceThresholdMeters.toStringAsFixed(0)}m)',
        );
      } else {
        distToNextMeters = d;
        break;
      }
    }

    // 2. Nếu đang ở chỉ dẫn cuối cùng (đích đến)
    if (activeIndex == instructions.length - 1) {
      final lastInstruction = instructions[activeIndex];
      final destinationPoint = lastInstruction.points.isNotEmpty
          ? lastInstruction.points.last
          : null;

      if (destinationPoint != null) {
        distToNextMeters = _calculateHaversineDistanceMeters(
          currentLat,
          currentLon,
          destinationPoint[0],
          destinationPoint[1],
        );
      } else {
        distToNextMeters = lastInstruction.distance;
      }
    }

    final currentInstruction = instructions[activeIndex];
    final nextInstruction = (activeIndex + 1 < instructions.length)
        ? instructions[activeIndex + 1]
        : null;

    // 3. Kiểm tra trạng thái đến đích (Arrival)
    final bool hasArrived = (activeIndex == instructions.length - 1) &&
        (distToNextMeters <= arrivalThresholdMeters ||
            (currentInstruction.type == InstructionType.arrive &&
                distToNextMeters <= advanceThresholdMeters));

    // 4. Kiểm tra cảnh báo trước (Pre-announce: <= 200m)
    final bool isPreAnnounced =
        distToNextMeters <= preAnnounceThresholdMeters && !hasArrived;

    // 5. Tính toán tổng khoảng cách còn lại (Remaining Distance)
    double remainingDist = hasArrived ? 0.0 : distToNextMeters;
    if (!hasArrived) {
      for (int i = activeIndex + 1; i < instructions.length; i++) {
        remainingDist += instructions[i].distance;
      }
    }

    // 6. Tính toán thời gian di chuyển còn lại (Remaining Duration - ms)
    int remainingDuration = 0;
    if (!hasArrived) {
      final currentTotalDist = currentInstruction.distance;
      final currentFraction = currentTotalDist > 0.0
          ? (distToNextMeters / currentTotalDist).clamp(0.0, 1.0)
          : 0.0;
      int currentDurationPart = (currentInstruction.time * currentFraction).round();

      int subsequentDuration = 0;
      for (int i = activeIndex + 1; i < instructions.length; i++) {
        subsequentDuration += instructions[i].time;
      }
      remainingDuration = currentDurationPart + subsequentDuration;
    }

    return InstructionProgress(
      currentInstructionIndex: activeIndex,
      currentInstruction: currentInstruction,
      nextInstruction: nextInstruction,
      distanceToNextInstruction: distToNextMeters,
      remainingDistance: remainingDist,
      remainingDurationMs: remainingDuration,
      isPreAnnounced: isPreAnnounced,
      hasArrived: hasArrived,
    );
  }

  /// Tính khoảng cách Haversine chính xác giữa 2 điểm tọa độ (đơn vị: mét)
  static double _calculateHaversineDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = (lat2 - lat1) * _degToRad;
    final dLon = (lon2 - lon1) * _degToRad;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * _degToRad) *
            math.cos(lat2 * _degToRad) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
    return _earthRadiusMeters * c;
  }
}
