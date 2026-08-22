import 'package:equatable/equatable.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';

enum RouteDrawingStatus {
  initial,
  loading,
  pointAdded,
  routeUpdated,
  warning,
  error,
  saved,
}

class RouteDrawingState extends Equatable {
  final RouteDrawingStatus status;
  final List<SnappedRoadPoint> points;
  final List<RouteResult> segments;
  final List<RoutePoint> fullPolyline;
  final double totalDistance;
  final int totalTime;
  final List<SnappedRoadPoint> redoPoints;
  final List<RouteResult?> redoSegments;
  final String? warningMessageKey;
  final String? errorMessageKey;
  final String profile;
  final int requestGeneration;

  const RouteDrawingState({
    this.status = RouteDrawingStatus.initial,
    this.points = const [],
    this.segments = const [],
    this.fullPolyline = const [],
    this.totalDistance = 0.0,
    this.totalTime = 0,
    this.redoPoints = const [],
    this.redoSegments = const [],
    this.warningMessageKey,
    this.errorMessageKey,
    this.profile = RoutingConstants.defaultProfile,
    this.requestGeneration = 0,
  });

  bool get canUndo => points.isNotEmpty;
  bool get canRedo => redoPoints.isNotEmpty;
  bool get hasRoute => segments.isNotEmpty && fullPolyline.isNotEmpty;
  bool get isLoading => status == RouteDrawingStatus.loading;
  int get pointCount => points.length;

  RouteDrawingState copyWith({
    RouteDrawingStatus? status,
    List<SnappedRoadPoint>? points,
    List<RouteResult>? segments,
    List<RoutePoint>? fullPolyline,
    double? totalDistance,
    int? totalTime,
    List<SnappedRoadPoint>? redoPoints,
    List<RouteResult?>? redoSegments,
    String? warningMessageKey,
    String? errorMessageKey,
    String? profile,
    int? requestGeneration,
    bool clearWarning = false,
    bool clearError = false,
  }) {
    return RouteDrawingState(
      status: status ?? this.status,
      points: points ?? this.points,
      segments: segments ?? this.segments,
      fullPolyline: fullPolyline ?? this.fullPolyline,
      totalDistance: totalDistance ?? this.totalDistance,
      totalTime: totalTime ?? this.totalTime,
      redoPoints: redoPoints ?? this.redoPoints,
      redoSegments: redoSegments ?? this.redoSegments,
      warningMessageKey:
          clearWarning ? null : (warningMessageKey ?? this.warningMessageKey),
      errorMessageKey:
          clearError ? null : (errorMessageKey ?? this.errorMessageKey),
      profile: profile ?? this.profile,
      requestGeneration: requestGeneration ?? this.requestGeneration,
    );
  }

  @override
  List<Object?> get props => [
        status,
        points,
        segments,
        fullPolyline,
        totalDistance,
        totalTime,
        redoPoints,
        redoSegments,
        warningMessageKey,
        errorMessageKey,
        profile,
        requestGeneration,
      ];
}
