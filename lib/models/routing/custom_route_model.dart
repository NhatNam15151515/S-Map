import 'package:equatable/equatable.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/routing/snapped_road_point.dart';

/// Entity biểu diễn một lộ trình tùy biến do người dùng tự vẽ và lưu trữ
class CustomRouteModel extends Equatable {
  final String id;
  final String name;
  final List<SnappedRoadPoint> waypoints;
  final List<List<double>> fullPolyline;
  final double totalDistance;
  final int totalTime;
  final String profile;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? description;

  const CustomRouteModel({
    required this.id,
    required this.name,
    required this.waypoints,
    required this.fullPolyline,
    required this.totalDistance,
    required this.totalTime,
    this.profile = RoutingConstants.profileMotorcycle,
    required this.createdAt,
    this.updatedAt,
    this.description,
  });

  CustomRouteModel copyWith({
    String? id,
    String? name,
    List<SnappedRoadPoint>? waypoints,
    List<List<double>>? fullPolyline,
    double? totalDistance,
    int? totalTime,
    String? profile,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
    bool clearDescription = false,
  }) {
    return CustomRouteModel(
      id: id ?? this.id,
      name: name ?? this.name,
      waypoints: waypoints ?? this.waypoints,
      fullPolyline: fullPolyline ?? this.fullPolyline,
      totalDistance: totalDistance ?? this.totalDistance,
      totalTime: totalTime ?? this.totalTime,
      profile: profile ?? this.profile,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description:
          clearDescription ? null : (description ?? this.description),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'waypoints': waypoints.map((w) => w.toMap()).toList(),
      'fullPolyline': fullPolyline
          .map((pt) => [pt[0], pt[1]])
          .toList(),
      'totalDistance': totalDistance,
      'totalTime': totalTime,
      'profile': profile,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'description': description,
    };
  }

  factory CustomRouteModel.fromMap(Map<String, dynamic> map) {
    final rawWaypoints = map['waypoints'];
    final List<SnappedRoadPoint> parsedWaypoints = [];
    if (rawWaypoints != null) {
      if (rawWaypoints is! List) {
        throw const FormatException('Field "waypoints" must be a List');
      }
      for (final item in rawWaypoints) {
        if (item is! Map) {
          throw FormatException('Invalid waypoint element: $item');
        }
        parsedWaypoints.add(
          SnappedRoadPoint.fromMap(Map<String, dynamic>.from(item)),
        );
      }
    }

    final rawPolyline = map['fullPolyline'];
    final List<List<double>> parsedPolyline = [];
    if (rawPolyline != null) {
      if (rawPolyline is! List) {
        throw const FormatException('Field "fullPolyline" must be a List');
      }
      for (final item in rawPolyline) {
        if (item is! List || item.length < 2) {
          throw FormatException('Invalid polyline point format: $item');
        }
        parsedPolyline.add([
          (item[0] as num).toDouble(),
          (item[1] as num).toDouble(),
        ]);
      }
    }

    return CustomRouteModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      waypoints: parsedWaypoints,
      fullPolyline: parsedPolyline,
      totalDistance: (map['totalDistance'] as num?)?.toDouble() ?? 0.0,
      totalTime: (map['totalTime'] as num?)?.toInt() ?? 0,
      profile: map['profile'] as String? ?? RoutingConstants.profileMotorcycle,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String)
          : null,
      description: map['description'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        waypoints,
        fullPolyline,
        totalDistance,
        totalTime,
        profile,
        createdAt,
        updatedAt,
        description,
      ];
}
