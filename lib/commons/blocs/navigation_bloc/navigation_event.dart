import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';

abstract class NavigationEvent extends Equatable {
  const NavigationEvent();

  @override
  List<Object?> get props => [];
}

/// Bắt đầu chuyến đi dẫn đường với lộ trình ban đầu
class StartNavigation extends NavigationEvent {
  final RouteResult initialRoute;
  final RoutePoint origin;
  final RoutePoint destination;
  final String? destinationName;
  final String profile;

  const StartNavigation({
    required this.initialRoute,
    required this.origin,
    required this.destination,
    this.destinationName,
    this.profile = RoutingConstants.defaultProfile,
  });

  @override
  List<Object?> get props => [
        initialRoute,
        origin,
        destination,
        destinationName,
        profile,
      ];
}

/// Nhận tọa độ GPS cập nhật từ GPS Stream
class LocationUpdated extends NavigationEvent {
  final double latitude;
  final double longitude;
  final double? speed; // m/s
  final double? heading; // degrees
  final double? accuracy; // meters

  const LocationUpdated({
    required this.latitude,
    required this.longitude,
    this.speed,
    this.heading,
    this.accuracy,
  });

  factory LocationUpdated.fromPosition(Position pos) {
    return LocationUpdated(
      latitude: pos.latitude,
      longitude: pos.longitude,
      speed: pos.speed >= 0 ? pos.speed : null,
      heading: pos.heading >= 0 ? pos.heading : null,
      accuracy: pos.accuracy >= 0 ? pos.accuracy : null,
    );
  }

  @override
  List<Object?> get props => [latitude, longitude, speed, heading, accuracy];
}

/// Yêu cầu tính lại lộ trình từ vị trí GPS hiện tại
class RerouteRequested extends NavigationEvent {
  final RoutePoint currentPosition;
  final bool isForced;

  const RerouteRequested({
    required this.currentPosition,
    this.isForced = false,
  });

  @override
  List<Object?> get props => [currentPosition, isForced];
}

/// Kết thúc chuyến đi dẫn đường và hủy luồng theo dõi GPS
class StopNavigation extends NavigationEvent {
  const StopNavigation();
}
