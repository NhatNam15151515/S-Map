import 'package:equatable/equatable.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';

enum RoutePreviewStatus { initial, loading, success, error }

class RoutePreviewState extends Equatable {
  final RoutePreviewStatus status;
  final RouteResult? routeResult;
  final List<RouteResult> alternativeRoutes;
  final int selectedRouteIndex;
  final RoutePoint? origin;
  final RoutePoint? destination;
  final String? originName;
  final String? destinationName;
  final String profile;
  final String? errorMessageKey;
  final int requestGeneration;

  const RoutePreviewState({
    this.status = RoutePreviewStatus.initial,
    this.routeResult,
    this.alternativeRoutes = const [],
    this.selectedRouteIndex = 0,
    this.origin,
    this.destination,
    this.originName,
    this.destinationName,
    this.profile = RoutingConstants.profileMopedVn,
    this.errorMessageKey,
    this.requestGeneration = 0,
  });

  bool get isInitial => status == RoutePreviewStatus.initial;
  bool get isLoading => status == RoutePreviewStatus.loading;
  bool get isSuccess =>
      status == RoutePreviewStatus.success &&
      currentRoute != null &&
      currentRoute!.isSuccess;
  bool get isError => status == RoutePreviewStatus.error;
  bool get hasRoute => currentRoute != null && currentRoute!.isSuccess;
  bool get hasAlternativeRoutes => alternativeRoutes.length > 1;

  RouteResult? get currentRoute {
    if (alternativeRoutes.isNotEmpty &&
        selectedRouteIndex >= 0 &&
        selectedRouteIndex < alternativeRoutes.length) {
      return alternativeRoutes[selectedRouteIndex];
    }
    return routeResult;
  }

  String get currentProfile => profile;
  bool get isOriginCurrentLocation => originName == null;

  RoutePreviewState copyWith({
    RoutePreviewStatus? status,
    RouteResult? routeResult,
    List<RouteResult>? alternativeRoutes,
    int? selectedRouteIndex,
    RoutePoint? origin,
    RoutePoint? destination,
    String? originName,
    String? destinationName,
    String? profile,
    String? errorMessageKey,
    int? requestGeneration,
    bool clearRoute = false,
    bool clearError = false,
    bool clearOriginName = false,
    bool clearDestinationName = false,
  }) {
    return RoutePreviewState(
      status: status ?? this.status,
      routeResult: clearRoute ? null : (routeResult ?? this.routeResult),
      alternativeRoutes:
          clearRoute ? const [] : (alternativeRoutes ?? this.alternativeRoutes),
      selectedRouteIndex: selectedRouteIndex ?? this.selectedRouteIndex,
      origin: clearRoute ? null : (origin ?? this.origin),
      destination: clearRoute ? null : (destination ?? this.destination),
      originName: clearRoute || clearOriginName
          ? null
          : (originName ?? this.originName),
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
        alternativeRoutes,
        selectedRouteIndex,
        origin,
        destination,
        originName,
        destinationName,
        profile,
        errorMessageKey,
        requestGeneration,
      ];
}
