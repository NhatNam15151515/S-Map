import 'package:equatable/equatable.dart';

class RoutePoint extends Equatable {
  final double lat;
  final double lon;

  const RoutePoint({
    required this.lat,
    required this.lon,
  });

  factory RoutePoint.fromList(List<dynamic> list) {
    if (list.length < 2) {
      return const RoutePoint(lat: 0.0, lon: 0.0);
    }
    return RoutePoint(
      lat: (list[0] as num).toDouble(),
      lon: (list[1] as num).toDouble(),
    );
  }

  factory RoutePoint.fromMap(Map<String, dynamic> map) {
    return RoutePoint(
      lat: (map['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (map['lon'] as num?)?.toDouble() ?? 0.0,
    );
  }

  List<double> toList() => [lat, lon];

  Map<String, dynamic> toMap() => {
        'lat': lat,
        'lon': lon,
      };

  @override
  List<Object?> get props => [lat, lon];
}
