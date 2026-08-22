import 'package:equatable/equatable.dart';
import 'trip_record_model.dart';

/// Model thống kê tổng hợp số liệu các chuyến đi
class TripStatsModel extends Equatable {
  final int totalTrips;
  final int completedTrips;
  final double totalDistanceMeters;
  final int totalDurationMs;
  final double avgSpeedKmh;
  final double topSpeedKmh;
  final Map<String, int> tripsByProfile;

  const TripStatsModel({
    required this.totalTrips,
    required this.completedTrips,
    required this.totalDistanceMeters,
    required this.totalDurationMs,
    required this.avgSpeedKmh,
    required this.topSpeedKmh,
    this.tripsByProfile = const {},
  });

  const TripStatsModel.empty()
      : totalTrips = 0,
        completedTrips = 0,
        totalDistanceMeters = 0.0,
        totalDurationMs = 0,
        avgSpeedKmh = 0.0,
        topSpeedKmh = 0.0,
        tripsByProfile = const {};

  /// Tổng quãng đường tính bằng Kilomet
  double get totalDistanceKm => totalDistanceMeters / 1000.0;

  /// Tổng thời gian tính bằng Phút
  double get totalDurationMinutes => totalDurationMs / 60000.0;

  /// Tổng thời gian tính bằng Giờ
  double get totalDurationHours => totalDurationMs / 3600000.0;

  /// Tỷ lệ hoàn thành chuyến đi (0.0 đến 1.0)
  double get completionRate =>
      totalTrips > 0 ? (completedTrips / totalTrips) : 0.0;

  /// Tạo đối tượng thống kê tổng hợp từ danh sách chuyến đi
  factory TripStatsModel.fromTrips(List<TripRecordModel> trips) {
    if (trips.isEmpty) {
      return const TripStatsModel.empty();
    }

    final totalTrips = trips.length;
    var completedTrips = 0;
    var totalDistanceMeters = 0.0;
    var totalDurationMs = 0;
    var topSpeedKmh = 0.0;
    final tripsByProfile = <String, int>{};

    for (final trip in trips) {
      if (trip.hasArrived) {
        completedTrips++;
      }
      totalDistanceMeters += trip.distanceMeters;
      totalDurationMs += trip.durationMs;
      if (trip.topSpeedKmh > topSpeedKmh) {
        topSpeedKmh = trip.topSpeedKmh;
      }
      tripsByProfile[trip.vehicleProfile] =
          (tripsByProfile[trip.vehicleProfile] ?? 0) + 1;
    }

    final double avgSpeedKmh;
    if (totalDurationMs > 0 && totalDistanceMeters > 0) {
      final hours = totalDurationMs / 3600000.0;
      avgSpeedKmh = (totalDistanceMeters / 1000.0) / hours;
    } else {
      avgSpeedKmh = 0.0;
    }

    return TripStatsModel(
      totalTrips: totalTrips,
      completedTrips: completedTrips,
      totalDistanceMeters: totalDistanceMeters,
      totalDurationMs: totalDurationMs,
      avgSpeedKmh: avgSpeedKmh.isFinite ? avgSpeedKmh : 0.0,
      topSpeedKmh: topSpeedKmh,
      tripsByProfile: Map.unmodifiable(tripsByProfile),
    );
  }

  TripStatsModel copyWith({
    int? totalTrips,
    int? completedTrips,
    double? totalDistanceMeters,
    int? totalDurationMs,
    double? avgSpeedKmh,
    double? topSpeedKmh,
    Map<String, int>? tripsByProfile,
  }) {
    return TripStatsModel(
      totalTrips: totalTrips ?? this.totalTrips,
      completedTrips: completedTrips ?? this.completedTrips,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      totalDurationMs: totalDurationMs ?? this.totalDurationMs,
      avgSpeedKmh: avgSpeedKmh ?? this.avgSpeedKmh,
      topSpeedKmh: topSpeedKmh ?? this.topSpeedKmh,
      tripsByProfile: tripsByProfile ?? this.tripsByProfile,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalTrips': totalTrips,
      'completedTrips': completedTrips,
      'totalDistanceMeters': totalDistanceMeters,
      'totalDurationMs': totalDurationMs,
      'avgSpeedKmh': avgSpeedKmh,
      'topSpeedKmh': topSpeedKmh,
      'tripsByProfile': tripsByProfile,
    };
  }

  factory TripStatsModel.fromMap(Map<dynamic, dynamic> map) {
    final rawProfiles = map['tripsByProfile'];
    final Map<String, int> parsedProfiles = {};
    if (rawProfiles != null && rawProfiles is Map) {
      for (final entry in rawProfiles.entries) {
        if (entry.key is String && entry.value is num) {
          parsedProfiles[entry.key as String] = (entry.value as num).toInt();
        }
      }
    }

    return TripStatsModel(
      totalTrips: (map['totalTrips'] as num?)?.toInt() ?? 0,
      completedTrips: (map['completedTrips'] as num?)?.toInt() ?? 0,
      totalDistanceMeters: (map['totalDistanceMeters'] as num?)?.toDouble() ?? 0.0,
      totalDurationMs: (map['totalDurationMs'] as num?)?.toInt() ?? 0,
      avgSpeedKmh: (map['avgSpeedKmh'] as num?)?.toDouble() ?? 0.0,
      topSpeedKmh: (map['topSpeedKmh'] as num?)?.toDouble() ?? 0.0,
      tripsByProfile: Map.unmodifiable(parsedProfiles),
    );
  }

  @override
  List<Object?> get props => [
        totalTrips,
        completedTrips,
        totalDistanceMeters,
        totalDurationMs,
        avgSpeedKmh,
        topSpeedKmh,
        tripsByProfile,
      ];
}
