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

  // Notifications & errors
  final String? messageKey;
  final String? errorMessageKey;

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
    this.messageKey,
    this.errorMessageKey,
  });

  bool get isNavigating =>
      status == NavigationStatus.navigating ||
      status == NavigationStatus.rerouting;

  bool get hasRoute =>
      currentRoute != null && currentRoute!.isSuccess && currentRoute!.hasPoints;

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
    int? currentSegmentIndex,
    double? distanceToRoute,
    bool? isOffRoute,
    bool? isRerouting,
    int? rerouteCount,
    int? requestGeneration,
    String? messageKey,
    bool clearMessage = false,
    String? errorMessageKey,
    bool clearError = false,
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
      currentLat: currentLat ?? this.currentLat,
      currentLon: currentLon ?? this.currentLon,
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      currentHeading: currentHeading ?? this.currentHeading,
      currentAccuracy: currentAccuracy ?? this.currentAccuracy,
      currentSegmentIndex: currentSegmentIndex ?? this.currentSegmentIndex,
      distanceToRoute: distanceToRoute ?? this.distanceToRoute,
      isOffRoute: isOffRoute ?? this.isOffRoute,
      isRerouting: isRerouting ?? this.isRerouting,
      rerouteCount: rerouteCount ?? this.rerouteCount,
      requestGeneration: requestGeneration ?? this.requestGeneration,
      messageKey: clearMessage ? null : (messageKey ?? this.messageKey),
      errorMessageKey:
          clearError ? null : (errorMessageKey ?? this.errorMessageKey),
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
        messageKey,
        errorMessageKey,
      ];
}
