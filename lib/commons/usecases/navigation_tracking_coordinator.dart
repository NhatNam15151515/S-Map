import 'package:s_map/commons/utils/app_utils.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

/// Kết quả đầu ra của một chu kỳ xử lý vị trí GPS (Navigation Tracking Tick)
class TrackingTickResult {
  final InstructionProgress progress;
  final OffRouteStatus offRouteStatus;
  final bool isArrived;
  final bool isSnapped;
  final double? snappedLat;
  final double? snappedLon;

  const TrackingTickResult({
    required this.progress,
    required this.offRouteStatus,
    required this.isArrived,
    required this.isSnapped,
    this.snappedLat,
    this.snappedLon,
  });

  bool get isOffRoute => offRouteStatus.isOffRoute;
  double get distanceToRoute => offRouteStatus.distanceToRoute;
  int get segmentIndex => offRouteStatus.segmentIndex;
}

/// Domain Coordinator: Hợp nhất bộ máy chỉ dẫn Turn-by-Turn, kiểm tra lệch tuyến và Map-Matching Snapping
class NavigationTrackingCoordinator {
  final ITurnByTurnEngine _turnByTurnEngine;
  final IOffRouteDetector _offRouteDetector;

  const NavigationTrackingCoordinator({
    required ITurnByTurnEngine turnByTurnEngine,
    required IOffRouteDetector offRouteDetector,
  })  : _turnByTurnEngine = turnByTurnEngine,
        _offRouteDetector = offRouteDetector;

  InstructionProgress initializeProgress(List<RouteInstruction> instructions) {
    return _turnByTurnEngine.initializeProgress(instructions);
  }

  /// Xử lý một chu kỳ toạ độ GPS gửi về:
  /// 1. Cập nhật tiến trình chỉ dẫn (instruction, next, remaining dist/time).
  /// 2. Kiểm tra điều kiện hoàn thành hành trình (đến đích).
  /// 3. Kiểm tra lệch tuyến và tính toạ độ bám tim đường (road snapping).
  TrackingTickResult processLocationTick({
    required double currentLat,
    required double currentLon,
    required RouteResult route,
    required RoutePoint? destination,
    required int currentSegmentIndex,
    required int currentInstructionIndex,
    required bool hasMoved,
    int lookAheadSegments = 5,
  }) {
    // 1. Cập nhật tiến trình chỉ dẫn
    final progress = _turnByTurnEngine.updateProgress(
      currentLat: currentLat,
      currentLon: currentLon,
      instructions: route.instructions,
      currentInstructionIndex: currentInstructionIndex,
    );

    // 2. Kiểm tra đến đích
    bool isArrived = progress.hasArrived && hasMoved;
    if (!isArrived && destination != null) {
      final distToDestKm = AppUtils.instance.calculateDistance(
        currentLat,
        currentLon,
        destination.lat,
        destination.lon,
      );
      final distToDestMeters = distToDestKm * RoutingConstants.metersPerKm;
      if (hasMoved &&
          distToDestMeters <= _turnByTurnEngine.arrivalThresholdMeters) {
        isArrived = true;
      }
    }

    // 3. Kiểm tra lệch tuyến và Map-matching tim đường
    final offRouteStatus = _offRouteDetector.checkOffRoute(
      currentLat: currentLat,
      currentLon: currentLon,
      routePoints: route.points,
      currentSegmentIndex: currentSegmentIndex,
      lookAheadSegments: lookAheadSegments,
    );

    final isSnapped =
        !offRouteStatus.isOffRoute && offRouteStatus.closestPoint != null;
    final snappedLat = isSnapped ? offRouteStatus.closestPoint![0] : null;
    final snappedLon = isSnapped ? offRouteStatus.closestPoint![1] : null;

    return TrackingTickResult(
      progress: progress,
      offRouteStatus: offRouteStatus,
      isArrived: isArrived,
      isSnapped: isSnapped,
      snappedLat: snappedLat,
      snappedLon: snappedLon,
    );
  }
}
