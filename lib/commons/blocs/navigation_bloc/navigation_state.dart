import 'package:equatable/equatable.dart';
import 'package:s_map/commons/usecases/usecases.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';

enum NavigationStatus {
  initial,
  navigating,
  rerouting,
  arrived,
  stopped,
  error,
}

class NavigationState extends Equatable {
  final NavigationStatus status;
  final RouteResult? currentRoute;
  final RoutePoint? origin;
  final RoutePoint? destination;
  final String? destinationName;
  final String profile;

  // GPS real-time properties
  final double? currentLat;
  final double? currentLon;
  final double? currentSpeedKmh;
  final double? currentHeading;
  final double? currentAccuracy;

  // Map-matched road snapped coordinates (Google Maps style)
  final double? snappedLat;
  final double? snappedLon;
  final bool isSnappedToRoute;

  // Navigation tracking properties
  final int currentSegmentIndex;
  final double distanceToRoute;
  final bool isOffRoute;
  final bool isRerouting;
  final int rerouteCount;
  final int requestGeneration;

  // Turn-by-turn instruction progress properties
  final int currentInstructionIndex;
  final RouteInstruction? currentInstruction;
  final RouteInstruction? nextInstruction;
  final double distanceToNextInstruction;
  final double remainingDistance;
  final int remainingDurationMs;
  final bool isPreAnnounced;

  // Trip statistics properties
  final TripSummary? tripSummary;
  final DateTime? tripStartTime;
  final double maxSpeedKmh;
  final double totalDistanceTraveledMeters;
  final double speedSampleSum;
  final int speedSampleCount;

  // Notifications & errors
  final String? messageKey;
  final String? errorMessageKey;

  // Battery optimization prompt
  final DeviceOemType? promptBatteryOptimizationOem;

  // Active trip resume prompt
  final ActiveTripSnapshot? pendingResumeSession;

  const NavigationState({
    this.status = NavigationStatus.initial,
    this.currentRoute,
    this.origin,
    this.destination,
    this.destinationName,
    this.profile = RoutingConstants.defaultProfile,
    this.currentLat,
    this.currentLon,
    this.currentSpeedKmh,
    this.currentHeading,
    this.currentAccuracy,
    this.snappedLat,
    this.snappedLon,
    this.isSnappedToRoute = false,
    this.currentSegmentIndex = 0,
    this.distanceToRoute = 0.0,
    this.isOffRoute = false,
    this.isRerouting = false,
    this.rerouteCount = 0,
    this.requestGeneration = 0,
    this.currentInstructionIndex = 0,
    this.currentInstruction,
    this.nextInstruction,
    this.distanceToNextInstruction = 0.0,
    this.remainingDistance = 0.0,
    this.remainingDurationMs = 0,
    this.isPreAnnounced = false,
    this.tripSummary,
    this.tripStartTime,
    this.maxSpeedKmh = 0.0,
    this.totalDistanceTraveledMeters = 0.0,
    this.speedSampleSum = 0.0,
    this.speedSampleCount = 0,
    this.messageKey,
    this.errorMessageKey,
    this.promptBatteryOptimizationOem,
    this.pendingResumeSession,
  });

  /// Toạ độ hiển thị tối ưu: Ưu tiên toạ độ đã được snap vào tim đường nếu đang on-route
  double? get displayLat =>
      isSnappedToRoute ? (snappedLat ?? currentLat) : currentLat;
  double? get displayLon =>
      isSnappedToRoute ? (snappedLon ?? currentLon) : currentLon;

  bool get isNavigating =>
      status == NavigationStatus.navigating ||
      status == NavigationStatus.rerouting;

  bool get hasRoute =>
      currentRoute != null &&
      currentRoute!.isSuccess &&
      currentRoute!.hasPoints;

  bool get hasInstructions =>
      currentRoute != null && currentRoute!.hasInstructions;

  InstructionType get instructionType =>
      currentInstruction?.type ?? InstructionType.unknown;

  NavigationState copyWith({
    NavigationStatus? status,
    RouteResult? currentRoute,
    RoutePoint? origin,
    RoutePoint? destination,
    String? destinationName,
    bool clearDestinationName = false,
    String? profile,
    double? currentLat,
    double? currentLon,
    double? currentSpeedKmh,
    double? currentHeading,
    double? currentAccuracy,
    bool clearCurrentPosition = false,
    double? snappedLat,
    double? snappedLon,
    bool? isSnappedToRoute,
    bool clearSnappedCoordinates = false,
    int? currentSegmentIndex,
    double? distanceToRoute,
    bool? isOffRoute,
    bool? isRerouting,
    int? rerouteCount,
    int? requestGeneration,
    int? currentInstructionIndex,
    RouteInstruction? currentInstruction,
    bool clearCurrentInstruction = false,
    RouteInstruction? nextInstruction,
    bool clearNextInstruction = false,
    double? distanceToNextInstruction,
    double? remainingDistance,
    int? remainingDurationMs,
    bool? isPreAnnounced,
    TripSummary? tripSummary,
    bool clearTripSummary = false,
    DateTime? tripStartTime,
    bool clearTripStartTime = false,
    double? maxSpeedKmh,
    double? totalDistanceTraveledMeters,
    double? speedSampleSum,
    int? speedSampleCount,
    String? messageKey,
    bool clearMessage = false,
    String? errorMessageKey,
    bool clearError = false,
    DeviceOemType? promptBatteryOptimizationOem,
    bool clearPromptBatteryOptimization = false,
    ActiveTripSnapshot? pendingResumeSession,
    bool clearPendingResumeSession = false,
  }) {
    return NavigationState(
      status: status ?? this.status,
      currentRoute: currentRoute ?? this.currentRoute,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      destinationName: clearDestinationName
          ? null
          : (destinationName ?? this.destinationName),
      profile: profile ?? this.profile,
      currentLat: clearCurrentPosition ? null : (currentLat ?? this.currentLat),
      currentLon: clearCurrentPosition ? null : (currentLon ?? this.currentLon),
      currentSpeedKmh: clearCurrentPosition
          ? null
          : (currentSpeedKmh ?? this.currentSpeedKmh),
      currentHeading:
          clearCurrentPosition ? null : (currentHeading ?? this.currentHeading),
      currentAccuracy: clearCurrentPosition
          ? null
          : (currentAccuracy ?? this.currentAccuracy),
      snappedLat:
          clearSnappedCoordinates ? null : (snappedLat ?? this.snappedLat),
      snappedLon:
          clearSnappedCoordinates ? null : (snappedLon ?? this.snappedLon),
      isSnappedToRoute: isSnappedToRoute ?? this.isSnappedToRoute,
      currentSegmentIndex: currentSegmentIndex ?? this.currentSegmentIndex,
      distanceToRoute: distanceToRoute ?? this.distanceToRoute,
      isOffRoute: isOffRoute ?? this.isOffRoute,
      isRerouting: isRerouting ?? this.isRerouting,
      rerouteCount: rerouteCount ?? this.rerouteCount,
      requestGeneration: requestGeneration ?? this.requestGeneration,
      currentInstructionIndex:
          currentInstructionIndex ?? this.currentInstructionIndex,
      currentInstruction: clearCurrentInstruction
          ? null
          : (currentInstruction ?? this.currentInstruction),
      nextInstruction: clearNextInstruction
          ? null
          : (nextInstruction ?? this.nextInstruction),
      distanceToNextInstruction:
          distanceToNextInstruction ?? this.distanceToNextInstruction,
      remainingDistance: remainingDistance ?? this.remainingDistance,
      remainingDurationMs: remainingDurationMs ?? this.remainingDurationMs,
      isPreAnnounced: isPreAnnounced ?? this.isPreAnnounced,
      tripSummary: clearTripSummary ? null : (tripSummary ?? this.tripSummary),
      tripStartTime:
          clearTripStartTime ? null : (tripStartTime ?? this.tripStartTime),
      maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      totalDistanceTraveledMeters:
          totalDistanceTraveledMeters ?? this.totalDistanceTraveledMeters,
      speedSampleSum: speedSampleSum ?? this.speedSampleSum,
      speedSampleCount: speedSampleCount ?? this.speedSampleCount,
      messageKey: clearMessage ? null : (messageKey ?? this.messageKey),
      errorMessageKey:
          clearError ? null : (errorMessageKey ?? this.errorMessageKey),
      promptBatteryOptimizationOem: clearPromptBatteryOptimization
          ? null
          : (promptBatteryOptimizationOem ?? this.promptBatteryOptimizationOem),
      pendingResumeSession: clearPendingResumeSession
          ? null
          : (pendingResumeSession ?? this.pendingResumeSession),
    );
  }

  @override
  List<Object?> get props => [
        status,
        currentRoute,
        origin,
        destination,
        destinationName,
        profile,
        currentLat,
        currentLon,
        currentSpeedKmh,
        currentHeading,
        currentAccuracy,
        snappedLat,
        snappedLon,
        isSnappedToRoute,
        currentSegmentIndex,
        distanceToRoute,
        isOffRoute,
        isRerouting,
        rerouteCount,
        requestGeneration,
        currentInstructionIndex,
        currentInstruction,
        nextInstruction,
        distanceToNextInstruction,
        remainingDistance,
        remainingDurationMs,
        isPreAnnounced,
        tripSummary,
        tripStartTime,
        maxSpeedKmh,
        totalDistanceTraveledMeters,
        speedSampleSum,
        speedSampleCount,
        messageKey,
        errorMessageKey,
        promptBatteryOptimizationOem,
        pendingResumeSession,
      ];

  /// Chuyển đổi trạng thái sang ActiveTripSnapshot để lưu vào bộ nhớ tạm
  ActiveTripSnapshot? toSnapshot({required TripMetricsTracker metrics}) {
    if (!isNavigating ||
        currentRoute == null ||
        origin == null ||
        destination == null) {
      return null;
    }

    return ActiveTripSnapshot(
      origin: origin!,
      destination: destination!,
      destinationName: destinationName,
      profile: profile,
      initialRoute: currentRoute!,
      currentSegmentIndex: currentSegmentIndex,
      currentInstructionIndex: currentInstructionIndex,
      tripStartTime: tripStartTime ?? DateTime.now(),
      lastSavedTime: DateTime.now(),
      totalDistanceTraveledMeters: metrics.totalDistanceTraveledMeters,
      maxSpeedKmh: metrics.maxSpeedKmh,
      speedSampleSum: metrics.speedSampleSum,
      speedSampleCount: metrics.speedSampleCount,
      lastKnownLat: currentLat,
      lastKnownLon: currentLon,
    );
  }

  /// Khởi tạo trạng thái bắt đầu phiên dẫn đường mới
  static NavigationState start({
    required RouteResult initialRoute,
    required RoutePoint origin,
    required RoutePoint destination,
    required String? destinationName,
    required String profile,
    required InstructionProgress initialProgress,
    required DeviceOemType? promptBatteryOptimizationOem,
  }) {
    return NavigationState(
      status: NavigationStatus.navigating,
      currentRoute: initialRoute,
      origin: origin,
      destination: destination,
      destinationName: destinationName,
      profile: profile,
      currentSegmentIndex: 0,
      distanceToRoute: 0.0,
      isOffRoute: false,
      isRerouting: false,
      rerouteCount: 0,
      currentInstructionIndex: initialProgress.currentInstructionIndex,
      currentInstruction: initialProgress.currentInstruction,
      nextInstruction: initialProgress.nextInstruction,
      distanceToNextInstruction: initialProgress.distanceToNextInstruction,
      remainingDistance: initialProgress.remainingDistance,
      remainingDurationMs: initialProgress.remainingDurationMs,
      isPreAnnounced: initialProgress.isPreAnnounced,
      tripStartTime: DateTime.now(),
      promptBatteryOptimizationOem: promptBatteryOptimizationOem,
    );
  }

  /// Khởi tạo trạng thái khôi phục từ snapshot lưu trữ
  static NavigationState resume({
    required ActiveTripSnapshot snapshot,
    required InstructionProgress progress,
    required DeviceOemType? promptBatteryOptimizationOem,
  }) {
    return NavigationState(
      status: NavigationStatus.navigating,
      currentRoute: snapshot.initialRoute,
      origin: snapshot.origin,
      destination: snapshot.destination,
      destinationName: snapshot.destinationName,
      profile: snapshot.profile,
      currentLat: snapshot.lastKnownLat,
      currentLon: snapshot.lastKnownLon,
      currentSegmentIndex: snapshot.currentSegmentIndex,
      distanceToRoute: 0.0,
      isOffRoute: false,
      isRerouting: false,
      rerouteCount: 0,
      currentInstructionIndex: progress.currentInstructionIndex,
      currentInstruction: progress.currentInstruction,
      nextInstruction: progress.nextInstruction,
      distanceToNextInstruction: progress.distanceToNextInstruction,
      remainingDistance: progress.remainingDistance,
      remainingDurationMs: progress.remainingDurationMs,
      isPreAnnounced: progress.isPreAnnounced,
      tripStartTime: snapshot.tripStartTime,
      maxSpeedKmh: snapshot.maxSpeedKmh,
      totalDistanceTraveledMeters: snapshot.totalDistanceTraveledMeters,
      speedSampleSum: snapshot.speedSampleSum,
      speedSampleCount: snapshot.speedSampleCount,
      promptBatteryOptimizationOem: promptBatteryOptimizationOem,
    );
  }

  /// Cập nhật trạng thái sau một chu kỳ GPS tracking hợp lệ
  NavigationState copyWithTick({
    required TrackingTickResult tick,
    required double currentLat,
    required double currentLon,
    required double? currentSpeedKmh,
    required double? currentHeading,
    required double? currentAccuracy,
    required TripMetricsTracker metrics,
  }) {
    final progress = tick.progress;
    return copyWith(
      currentLat: currentLat,
      currentLon: currentLon,
      snappedLat: tick.snappedLat,
      snappedLon: tick.snappedLon,
      isSnappedToRoute: tick.isSnapped,
      currentSpeedKmh: currentSpeedKmh,
      currentHeading: currentHeading,
      currentAccuracy: currentAccuracy,
      currentSegmentIndex: tick.offRouteStatus.segmentIndex,
      distanceToRoute: tick.offRouteStatus.distanceToRoute,
      isOffRoute: tick.offRouteStatus.isOffRoute,
      currentInstructionIndex: progress.currentInstructionIndex,
      currentInstruction: progress.currentInstruction,
      clearCurrentInstruction: progress.currentInstruction == null,
      nextInstruction: progress.nextInstruction,
      clearNextInstruction: progress.nextInstruction == null,
      distanceToNextInstruction: progress.distanceToNextInstruction,
      remainingDistance: progress.remainingDistance,
      remainingDurationMs: progress.remainingDurationMs,
      isPreAnnounced: progress.isPreAnnounced,
      maxSpeedKmh: metrics.maxSpeedKmh,
      totalDistanceTraveledMeters: metrics.totalDistanceTraveledMeters,
      speedSampleSum: metrics.speedSampleSum,
      speedSampleCount: metrics.speedSampleCount,
    );
  }

  /// Cập nhật trạng thái khi người dùng đã đến đích
  NavigationState copyWithArrival({
    required double currentLat,
    required double currentLon,
    required double? currentSpeedKmh,
    required double? currentHeading,
    required double? currentAccuracy,
    required int currentInstructionIndex,
    required RouteInstruction? currentInstruction,
    required RouteInstruction? nextInstruction,
    required TripMetricsTracker metrics,
    required TripSummary tripSummary,
  }) {
    return copyWith(
      status: NavigationStatus.arrived,
      currentLat: currentLat,
      currentLon: currentLon,
      currentSpeedKmh: currentSpeedKmh,
      currentHeading: currentHeading,
      currentAccuracy: currentAccuracy,
      currentInstructionIndex: currentInstructionIndex,
      currentInstruction: currentInstruction,
      clearCurrentInstruction: currentInstruction == null,
      nextInstruction: nextInstruction,
      clearNextInstruction: nextInstruction == null,
      distanceToNextInstruction: 0.0,
      remainingDistance: 0.0,
      remainingDurationMs: 0,
      isPreAnnounced: false,
      isOffRoute: false,
      distanceToRoute: 0.0,
      maxSpeedKmh: metrics.maxSpeedKmh,
      totalDistanceTraveledMeters: metrics.totalDistanceTraveledMeters,
      speedSampleSum: metrics.speedSampleSum,
      speedSampleCount: metrics.speedSampleCount,
      tripSummary: tripSummary,
    );
  }

  /// Cập nhật trạng thái khi tính lại đường (Reroute) thành công
  NavigationState copyWithRerouteSuccess({
    required RouteResult newRoute,
    required RoutePoint newOrigin,
    required InstructionProgress newProgress,
    required int requestGeneration,
    required String messageKey,
  }) {
    return copyWith(
      status: NavigationStatus.navigating,
      currentRoute: newRoute,
      origin: newOrigin,
      currentSegmentIndex: 0,
      isOffRoute: false,
      isRerouting: false,
      rerouteCount: rerouteCount + 1,
      requestGeneration: requestGeneration,
      currentInstructionIndex: newProgress.currentInstructionIndex,
      currentInstruction: newProgress.currentInstruction,
      clearCurrentInstruction: newProgress.currentInstruction == null,
      nextInstruction: newProgress.nextInstruction,
      clearNextInstruction: newProgress.nextInstruction == null,
      distanceToNextInstruction: newProgress.distanceToNextInstruction,
      remainingDistance: newProgress.remainingDistance,
      remainingDurationMs: newProgress.remainingDurationMs,
      isPreAnnounced: newProgress.isPreAnnounced,
      messageKey: messageKey,
      clearError: true,
    );
  }
}
