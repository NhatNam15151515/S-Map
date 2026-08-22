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

  TripRecordModel({
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
    List<List<double>>? polyline,
    required this.createdAt,
  }) : polyline = polyline == null
            ? null
            : List<List<double>>.unmodifiable(
                polyline.map((point) => List<double>.unmodifiable(point)),
              );

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
        final lat = (item[0] as num).toDouble();
        final lon = (item[1] as num).toDouble();
        if (!lat.isFinite ||
            !lon.isFinite ||
            lat < -90.0 ||
            lat > 90.0 ||
            lon < -180.0 ||
            lon > 180.0) {
          throw FormatException(
              'Coordinate out of valid geographic range: [$lat, $lon]');
        }
        parsedPolyline.add([lat, lon]);
      }
    }

    final rawDuration = map['durationMs'];
    final int durationMs;
    if (rawDuration != null) {
      if (rawDuration is! int || rawDuration < 0) {
        throw const FormatException(
            'Field "durationMs" must be a non-negative int');
      }
      durationMs = rawDuration;
    } else {
      durationMs = 0;
    }

    final rawDist = map['distanceMeters'];
    final double distanceMeters;
    if (rawDist != null) {
      if (rawDist is! num || !rawDist.isFinite || rawDist < 0) {
        throw const FormatException(
            'Field "distanceMeters" must be a non-negative finite num');
      }
      distanceMeters = rawDist.toDouble();
    } else {
      distanceMeters = 0.0;
    }

    final rawAvgSpeed = map['avgSpeedKmh'];
    final double avgSpeedKmh;
    if (rawAvgSpeed != null) {
      if (rawAvgSpeed is! num || !rawAvgSpeed.isFinite || rawAvgSpeed < 0) {
        throw const FormatException(
            'Field "avgSpeedKmh" must be a non-negative finite num');
      }
      avgSpeedKmh = rawAvgSpeed.toDouble();
    } else {
      avgSpeedKmh = 0.0;
    }

    final rawTopSpeed = map['topSpeedKmh'];
    final double topSpeedKmh;
    if (rawTopSpeed != null) {
      if (rawTopSpeed is! num || !rawTopSpeed.isFinite || rawTopSpeed < 0) {
        throw const FormatException(
            'Field "topSpeedKmh" must be a non-negative finite num');
      }
      topSpeedKmh = rawTopSpeed.toDouble();
    } else {
      topSpeedKmh = 0.0;
    }

    final rawDest = map['destinationName'];
    if (rawDest != null && rawDest is! String) {
      throw const FormatException('Field "destinationName" must be a String');
    }

    final rawOrigin = map['originName'];
    if (rawOrigin != null && rawOrigin is! String) {
      throw const FormatException('Field "originName" must be a String');
    }

    final rawProfile = map['vehicleProfile'];
    if (rawProfile != null && rawProfile is! String) {
      throw const FormatException('Field "vehicleProfile" must be a String');
    }

    final rawHasArrived = map['hasArrived'];
    if (rawHasArrived != null && rawHasArrived is! bool) {
      throw const FormatException('Field "hasArrived" must be a bool');
    }

    final rawCreatedAt = map['createdAt'];
    DateTime createdAt = DateTime.now();
    if (rawCreatedAt != null) {
      if (rawCreatedAt is! String) {
        throw const FormatException(
            'Field "createdAt" must be a valid ISO8601 String');
      }
      final parsed = DateTime.tryParse(rawCreatedAt);
      if (parsed == null) {
        throw const FormatException(
            'Field "createdAt" could not be parsed to DateTime');
      }
      createdAt = parsed;
    }

    return TripRecordModel(
      id: rawId,
      startTime: startTime,
      endTime: endTime,
      durationMs: durationMs,
      distanceMeters: distanceMeters,
      avgSpeedKmh: avgSpeedKmh,
      topSpeedKmh: topSpeedKmh,
      destinationName: rawDest as String?,
      originName: rawOrigin as String?,
      hasArrived: rawHasArrived as bool? ?? false,
      vehicleProfile: (rawProfile as String?) ?? 'motorcycle',
      polyline: parsedPolyline,
      createdAt: createdAt,
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
