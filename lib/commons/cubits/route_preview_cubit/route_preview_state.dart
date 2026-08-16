import 'package:equatable/equatable.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';

enum RoutePreviewStatus { initial, loading, success, error }

class RoutePreviewState extends Equatable {
  final RoutePreviewStatus status;
  final RouteResult? routeResult;
  final RoutePoint? origin;
  final RoutePoint? destination;
  final String? destinationName;
  final String profile;
  final String? errorMessageKey;
  final int requestGeneration;

  const RoutePreviewState({
    this.status = RoutePreviewStatus.initial,
    this.routeResult,
    this.origin,
    this.destination,
    this.destinationName,
    this.profile = RoutingConstants.profileMopedVn,
    this.errorMessageKey,
    this.requestGeneration = 0,
  });

  bool get isInitial => status == RoutePreviewStatus.initial;
  bool get isLoading => status == RoutePreviewStatus.loading;
  bool get isSuccess =>
      status == RoutePreviewStatus.success &&
      routeResult != null &&
      routeResult!.isSuccess;
  bool get isError => status == RoutePreviewStatus.error;
  bool get hasRoute => routeResult != null && routeResult!.isSuccess;

  RoutePreviewState copyWith({
    RoutePreviewStatus? status,
    RouteResult? routeResult,
    RoutePoint? origin,
    RoutePoint? destination,
    String? destinationName,
    String? profile,
    String? errorMessageKey,
    int? requestGeneration,
    bool clearRoute = false,
    bool clearError = false,
    bool clearDestinationName = false,
  }) {
    return RoutePreviewState(
      status: status ?? this.status,
      routeResult: clearRoute ? null : (routeResult ?? this.routeResult),
      origin: clearRoute ? null : (origin ?? this.origin),
      destination: clearRoute ? null : (destination ?? this.destination),
      destinationName: clearRoute || clearDestinationName
          ? null
          : (destinationName ?? this.destinationName),
      profile: profile ?? this.profile,
      errorMessageKey:
          clearError ? null : (errorMessageKey ?? this.errorMessageKey),
      requestGeneration: requestGeneration ?? this.requestGeneration,
    );
  }

  @override
  List<Object?> get props => [
        status,
        routeResult,
        origin,
        destination,
        destinationName,
        profile,
        errorMessageKey,
        requestGeneration,
      ];
}
