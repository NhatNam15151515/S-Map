import 'package:equatable/equatable.dart';
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

  bool get isNavigating =>
      status == NavigationStatus.navigating ||
      status == NavigationStatus.rerouting;

  bool get hasRoute =>
      currentRoute != null && currentRoute!.isSuccess && currentRoute!.hasPoints;

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
      currentSpeedKmh: clearCurrentPosition ? null : (currentSpeedKmh ?? this.currentSpeedKmh),
      currentHeading: clearCurrentPosition ? null : (currentHeading ?? this.currentHeading),
      currentAccuracy: clearCurrentPosition ? null : (currentAccuracy ?? this.currentAccuracy),
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
      tripSummary:
          clearTripSummary ? null : (tripSummary ?? this.tripSummary),
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
}
