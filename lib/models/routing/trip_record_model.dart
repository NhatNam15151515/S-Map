import 'package:equatable/equatable.dart';

/// Model biểu diễn một chuyến đi hoàn thành hoặc kết thúc trong ứng dụng
class TripRecordModel extends Equatable {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMs;
  final double distanceMeters;
  final double avgSpeedKmh;
  final double topSpeedKmh;
  final String? destinationName;
  final String? originName;
  final bool hasArrived;
  final String vehicleProfile;
  final List<List<double>>? polyline;
  final DateTime createdAt;

  const TripRecordModel({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.durationMs,
    required this.distanceMeters,
    required this.avgSpeedKmh,
    required this.topSpeedKmh,
    this.destinationName,
    this.originName,
    this.hasArrived = false,
    this.vehicleProfile = 'motorcycle',
    this.polyline,
    required this.createdAt,
  });

  /// Thời gian di chuyển dạng Duration
  Duration get duration => Duration(milliseconds: durationMs);

  /// Quãng đường tính bằng Kilomet
  double get distanceKm => distanceMeters / 1000.0;

  TripRecordModel copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    int? durationMs,
    double? distanceMeters,
    double? avgSpeedKmh,
    double? topSpeedKmh,
    String? destinationName,
    String? originName,
    bool? hasArrived,
    String? vehicleProfile,
    List<List<double>>? polyline,
    DateTime? createdAt,
    bool clearDestination = false,
    bool clearOrigin = false,
    bool clearPolyline = false,
  }) {
    return TripRecordModel(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMs: durationMs ?? this.durationMs,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      avgSpeedKmh: avgSpeedKmh ?? this.avgSpeedKmh,
      topSpeedKmh: topSpeedKmh ?? this.topSpeedKmh,
      destinationName:
          clearDestination ? null : (destinationName ?? this.destinationName),
      originName: clearOrigin ? null : (originName ?? this.originName),
      hasArrived: hasArrived ?? this.hasArrived,
      vehicleProfile: vehicleProfile ?? this.vehicleProfile,
      polyline: clearPolyline ? null : (polyline ?? this.polyline),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'durationMs': durationMs,
      'distanceMeters': distanceMeters,
      'avgSpeedKmh': avgSpeedKmh,
      'topSpeedKmh': topSpeedKmh,
      'destinationName': destinationName,
      'originName': originName,
      'hasArrived': hasArrived,
      'vehicleProfile': vehicleProfile,
      'polyline': polyline,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TripRecordModel.fromMap(Map<dynamic, dynamic> map) {
    final rawId = map['id'];
    if (rawId == null || rawId is! String || rawId.trim().isEmpty) {
      throw const FormatException('Field "id" must be a non-empty String');
    }

    final rawStartTime = map['startTime'];
    if (rawStartTime == null || rawStartTime is! String) {
      throw const FormatException('Field "startTime" must be a valid ISO8601 String');
    }
    final startTime = DateTime.tryParse(rawStartTime);
    if (startTime == null) {
      throw const FormatException('Field "startTime" could not be parsed to DateTime');
    }

    final rawEndTime = map['endTime'];
    if (rawEndTime == null || rawEndTime is! String) {
      throw const FormatException('Field "endTime" must be a valid ISO8601 String');
    }
    final endTime = DateTime.tryParse(rawEndTime);
    if (endTime == null) {
      throw const FormatException('Field "endTime" could not be parsed to DateTime');
    }

    final rawPolyline = map['polyline'];
    List<List<double>>? parsedPolyline;
    if (rawPolyline != null) {
      if (rawPolyline is! List) {
        throw const FormatException('Field "polyline" must be a List');
      }
      parsedPolyline = [];
      for (final item in rawPolyline) {
        if (item is! List ||
            item.length < 2 ||
            item[0] is! num ||
            item[1] is! num) {
          throw FormatException('Invalid coordinate in polyline: $item');
        }
        parsedPolyline.add([
          (item[0] as num).toDouble(),
          (item[1] as num).toDouble(),
        ]);
      }
    }

    return TripRecordModel(
      id: rawId,
      startTime: startTime,
      endTime: endTime,
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      avgSpeedKmh: (map['avgSpeedKmh'] as num?)?.toDouble() ?? 0.0,
      topSpeedKmh: (map['topSpeedKmh'] as num?)?.toDouble() ?? 0.0,
      destinationName: map['destinationName'] as String?,
      originName: map['originName'] as String?,
      hasArrived: map['hasArrived'] as bool? ?? false,
      vehicleProfile: map['vehicleProfile'] as String? ?? 'motorcycle',
      polyline: parsedPolyline,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        startTime,
        endTime,
        durationMs,
        distanceMeters,
        avgSpeedKmh,
        topSpeedKmh,
        destinationName,
        originName,
        hasArrived,
        vehicleProfile,
        polyline,
        createdAt,
      ];
}
