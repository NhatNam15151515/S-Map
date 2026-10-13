import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/models/models.dart';

void main() {
  group('TripStatsModel Unit Tests', () {
    final t1 = TripRecordModel(
      id: 't1',
      startTime: DateTime(2026, 8, 22, 7, 0),
      endTime: DateTime(2026, 8, 22, 7, 30),
      durationMs: 1800000, // 0.5 hour
      distanceMeters: 15000.0, // 15 km
      avgSpeedKmh: 30.0,
      topSpeedKmh: 50.0,
      hasArrived: true,
      vehicleProfile: 'motorcycle',
      createdAt: DateTime(2026, 8, 22, 7, 30),
    );

    final t2 = TripRecordModel(
      id: 't2',
      startTime: DateTime(2026, 8, 22, 12, 0),
      endTime: DateTime(2026, 8, 22, 12, 30),
      durationMs: 1800000, // 0.5 hour
      distanceMeters: 25000.0, // 25 km
      avgSpeedKmh: 50.0,
      topSpeedKmh: 80.0,
      hasArrived: true,
      vehicleProfile: 'car',
      createdAt: DateTime(2026, 8, 22, 12, 30),
    );

    final t3 = TripRecordModel(
      id: 't3',
      startTime: DateTime(2026, 8, 22, 18, 0),
      endTime: DateTime(2026, 8, 22, 18, 15),
      durationMs: 900000, // 0.25 hour
      distanceMeters: 5000.0, // 5 km
      avgSpeedKmh: 20.0,
      topSpeedKmh: 35.0,
      hasArrived: false, // Canceled/stopped early
      vehicleProfile: 'motorcycle',
      createdAt: DateTime(2026, 8, 22, 18, 15),
    );

    test('TripStatsModel.empty creates zeroed stats model', () {
      const emptyStats = TripStatsModel.empty();
      expect(emptyStats.totalTrips, equals(0));
      expect(emptyStats.completedTrips, equals(0));
      expect(emptyStats.totalDistanceMeters, equals(0.0));
      expect(emptyStats.totalDistanceKm, equals(0.0));
      expect(emptyStats.totalDurationMs, equals(0));
      expect(emptyStats.totalDurationMinutes, equals(0.0));
      expect(emptyStats.totalDurationHours, equals(0.0));
      expect(emptyStats.avgSpeedKmh, equals(0.0));
      expect(emptyStats.topSpeedKmh, equals(0.0));
      expect(emptyStats.completionRate, equals(0.0));
      expect(emptyStats.tripsByProfile, isEmpty);
    });

    test('TripStatsModel.fromTrips correctly aggregates data across trips', () {
      final stats = TripStatsModel.fromTrips([t1, t2, t3]);

      expect(stats.totalTrips, equals(3));
      expect(stats.completedTrips, equals(2));
      expect(stats.completionRate, closeTo(2 / 3, 0.001));

      // Total distance: 15km + 25km + 5km = 45km (45,000m)
      expect(stats.totalDistanceMeters, equals(45000.0));
      expect(stats.totalDistanceKm, equals(45.0));

      // Total duration: 30m + 30m + 15m = 75m (4,500,000ms = 1.25 hours)
      expect(stats.totalDurationMs, equals(4500000));
      expect(stats.totalDurationMinutes, equals(75.0));
      expect(stats.totalDurationHours, equals(1.25));

      // Top speed: max(50, 80, 35) = 80
      expect(stats.topSpeedKmh, equals(80.0));

      // Average speed: 45 km / 1.25 hours = 36.0 km/h
      expect(stats.avgSpeedKmh, closeTo(36.0, 0.01));

      // Profile breakdown: 2 motorcycle, 1 car
      expect(stats.tripsByProfile['motorcycle'], equals(2));
      expect(stats.tripsByProfile['car'], equals(1));
    });

    test('toMap and fromMap serialization round-trip retains all stats fields', () {
      final stats = TripStatsModel.fromTrips([t1, t2]);
      final map = stats.toMap();
      final reconstructed = TripStatsModel.fromMap(map);

      expect(reconstructed.totalTrips, equals(stats.totalTrips));
      expect(reconstructed.completedTrips, equals(stats.completedTrips));
      expect(reconstructed.totalDistanceMeters, equals(stats.totalDistanceMeters));
      expect(reconstructed.totalDurationMs, equals(stats.totalDurationMs));
      expect(reconstructed.avgSpeedKmh, closeTo(stats.avgSpeedKmh, 0.01));
      expect(reconstructed.topSpeedKmh, equals(stats.topSpeedKmh));
      expect(reconstructed.tripsByProfile, equals(stats.tripsByProfile));
      expect(reconstructed, equals(stats));
    });

    test('copyWith modifies specified fields while retaining others', () {
      final stats = TripStatsModel.fromTrips([t1]);
      final modified = stats.copyWith(
        topSpeedKmh: 99.9,
        completedTrips: 10,
      );

      expect(modified.topSpeedKmh, equals(99.9));
      expect(modified.completedTrips, equals(10));
      expect(modified.totalTrips, equals(stats.totalTrips));
    });
  });
}
