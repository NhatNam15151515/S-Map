import 'package:equatable/equatable.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/routing/route_point.dart';
import 'package:s_map/models/routing/route_result.dart';

/// Model lưu trạng thái snapshot của chuyến đi đang diễn ra (Active Navigation Session)
/// dùng để khôi phục (Resume) khi ứng dụng bị tắt hoặc kill giữa chừng.
class ActiveTripSnapshot extends Equatable {
  final RoutePoint origin;
  final RoutePoint destination;
  final String? destinationName;
  final String profile;
  final RouteResult initialRoute;
  final int currentSegmentIndex;
  final int currentInstructionIndex;
  final DateTime tripStartTime;
  final DateTime lastSavedTime;
  final double totalDistanceTraveledMeters;
  final double maxSpeedKmh;
  final double speedSampleSum;
  final int speedSampleCount;
  final double? lastKnownLat;
  final double? lastKnownLon;

  const ActiveTripSnapshot({
    required this.origin,
    required this.destination,
    this.destinationName,
    this.profile = RoutingConstants.defaultProfile,
    required this.initialRoute,
    this.currentSegmentIndex = 0,
    this.currentInstructionIndex = 0,
    required this.tripStartTime,
    required this.lastSavedTime,
    this.totalDistanceTraveledMeters = 0.0,
    this.maxSpeedKmh = 0.0,
    this.speedSampleSum = 0.0,
    this.speedSampleCount = 0,
    this.lastKnownLat,
    this.lastKnownLon,
  });

  /// Kiểm tra xem snapshot có còn hợp lệ theo thời gian tối đa cho phép (mặc định 24h)
  bool isValid({Duration maxAge = const Duration(hours: 24)}) {
    final now = DateTime.now();
    return now.difference(lastSavedTime) <= maxAge;
  }

  ActiveTripSnapshot copyWith({
    RoutePoint? origin,
    RoutePoint? destination,
    String? destinationName,
    bool clearDestinationName = false,
    String? profile,
    RouteResult? initialRoute,
    int? currentSegmentIndex,
    int? currentInstructionIndex,
    DateTime? tripStartTime,
    DateTime? lastSavedTime,
    double? totalDistanceTraveledMeters,
    double? maxSpeedKmh,
    double? speedSampleSum,
    int? speedSampleCount,
    double? lastKnownLat,
    double? lastKnownLon,
    bool clearLastKnownPosition = false,
  }) {
    return ActiveTripSnapshot(
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      destinationName: clearDestinationName
          ? null
          : (destinationName ?? this.destinationName),
      profile: profile ?? this.profile,
      initialRoute: initialRoute ?? this.initialRoute,
      currentSegmentIndex: currentSegmentIndex ?? this.currentSegmentIndex,
      currentInstructionIndex:
          currentInstructionIndex ?? this.currentInstructionIndex,
      tripStartTime: tripStartTime ?? this.tripStartTime,
      lastSavedTime: lastSavedTime ?? this.lastSavedTime,
      totalDistanceTraveledMeters:
          totalDistanceTraveledMeters ?? this.totalDistanceTraveledMeters,
      maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      speedSampleSum: speedSampleSum ?? this.speedSampleSum,
      speedSampleCount: speedSampleCount ?? this.speedSampleCount,
      lastKnownLat: clearLastKnownPosition
          ? null
          : (lastKnownLat ?? this.lastKnownLat),
      lastKnownLon: clearLastKnownPosition
          ? null
          : (lastKnownLon ?? this.lastKnownLon),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'origin': origin.toMap(),
      'destination': destination.toMap(),
      'destinationName': destinationName,
      'profile': profile,
      'initialRoute': initialRoute.toMap(),
      'currentSegmentIndex': currentSegmentIndex,
      'currentInstructionIndex': currentInstructionIndex,
      'tripStartTime': tripStartTime.toIso8601String(),
      'lastSavedTime': lastSavedTime.toIso8601String(),
      'totalDistanceTraveledMeters': totalDistanceTraveledMeters,
      'maxSpeedKmh': maxSpeedKmh,
      'speedSampleSum': speedSampleSum,
      'speedSampleCount': speedSampleCount,
      'lastKnownLat': lastKnownLat,
      'lastKnownLon': lastKnownLon,
    };
  }

  factory ActiveTripSnapshot.fromMap(Map<dynamic, dynamic> map) {
    final rawOrigin = map['origin'];
    if (rawOrigin == null || rawOrigin is! Map) {
      throw const FormatException('Field "origin" must be a valid Map');
    }
    final origin = RoutePoint.fromMap(Map<String, dynamic>.from(rawOrigin));

    final rawDest = map['destination'];
    if (rawDest == null || rawDest is! Map) {
      throw const FormatException('Field "destination" must be a valid Map');
    }
    final destination =
        RoutePoint.fromMap(Map<String, dynamic>.from(rawDest));

    final rawInitialRoute = map['initialRoute'];
    if (rawInitialRoute == null || rawInitialRoute is! Map) {
      throw const FormatException('Field "initialRoute" must be a valid Map');
    }
    final initialRoute =
        RouteResult.fromMap(Map<String, dynamic>.from(rawInitialRoute));

    final rawStartTime = map['tripStartTime'];
    if (rawStartTime == null || rawStartTime is! String) {
      throw const FormatException(
          'Field "tripStartTime" must be a valid ISO8601 String');
    }
    final tripStartTime = DateTime.tryParse(rawStartTime);
    if (tripStartTime == null) {
      throw const FormatException(
          'Field "tripStartTime" could not be parsed to DateTime');
    }

    final rawLastSaved = map['lastSavedTime'];
    if (rawLastSaved == null || rawLastSaved is! String) {
      throw const FormatException(
          'Field "lastSavedTime" must be a valid ISO8601 String');
    }
    final lastSavedTime = DateTime.tryParse(rawLastSaved);
    if (lastSavedTime == null) {
      throw const FormatException(
          'Field "lastSavedTime" could not be parsed to DateTime');
    }

    return ActiveTripSnapshot(
      origin: origin,
      destination: destination,
      destinationName: map['destinationName'] as String?,
      profile: (map['profile'] as String?) ?? RoutingConstants.defaultProfile,
      initialRoute: initialRoute,
      currentSegmentIndex: (map['currentSegmentIndex'] as num?)?.toInt() ?? 0,
      currentInstructionIndex:
          (map['currentInstructionIndex'] as num?)?.toInt() ?? 0,
      tripStartTime: tripStartTime,
      lastSavedTime: lastSavedTime,
      totalDistanceTraveledMeters:
          (map['totalDistanceTraveledMeters'] as num?)?.toDouble() ?? 0.0,
      maxSpeedKmh: (map['maxSpeedKmh'] as num?)?.toDouble() ?? 0.0,
      speedSampleSum: (map['speedSampleSum'] as num?)?.toDouble() ?? 0.0,
      speedSampleCount: (map['speedSampleCount'] as num?)?.toInt() ?? 0,
      lastKnownLat: (map['lastKnownLat'] as num?)?.toDouble(),
      lastKnownLon: (map['lastKnownLon'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [
        origin,
        destination,
        destinationName,
        profile,
        initialRoute,
        currentSegmentIndex,
        currentInstructionIndex,
        tripStartTime,
        lastSavedTime,
        totalDistanceTraveledMeters,
        maxSpeedKmh,
        speedSampleSum,
        speedSampleCount,
        lastKnownLat,
        lastKnownLon,
      ];
}
