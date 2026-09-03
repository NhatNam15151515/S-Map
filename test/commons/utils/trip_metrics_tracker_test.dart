import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/utils/trip_metrics_tracker.dart';

void main() {
  group('TripMetricsTracker Unit Tests', () {
    late TripMetricsTracker tracker;

    setUp(() {
      tracker = TripMetricsTracker();
    });

    test('initial state has zero values', () {
      expect(tracker.totalDistanceTraveledMeters, equals(0.0));
      expect(tracker.maxSpeedKmh, equals(0.0));
      expect(tracker.speedSampleCount, equals(0));
      expect(tracker.hasMoved, isFalse);
    });

    test('first GPS fix sets last known coordinates without accumulating distance', () {
      tracker.recordFix(lat: 10.7769, lon: 106.7009, speedKmh: 25.0);

      expect(tracker.lastValidLat, equals(10.7769));
      expect(tracker.lastValidLon, equals(106.7009));
      expect(tracker.totalDistanceTraveledMeters, equals(0.0));
      expect(tracker.maxSpeedKmh, equals(25.0));
      expect(tracker.speedSampleCount, equals(1));
      expect(tracker.hasMoved, isFalse);
    });

    test('ignores microscopic jitter movements (< 1 meter)', () {
      tracker.recordFix(lat: 10.7769000, lon: 106.7009000, speedKmh: 0.0);
      // Extremely small offset ~ 0.05m
      tracker.recordFix(lat: 10.7769004, lon: 106.7009004, speedKmh: 0.0);

      expect(tracker.totalDistanceTraveledMeters, equals(0.0));
      expect(tracker.hasMoved, isFalse);
    });

    test('ignores unrealistic teleportation jumps (> 200 meters per second)', () {
      tracker.recordFix(lat: 10.7769, lon: 106.7009, speedKmh: 20.0);
      // Jump 5km away suddenly
      tracker.recordFix(lat: 10.8200, lon: 106.7500, speedKmh: 20.0);

      expect(tracker.totalDistanceTraveledMeters, equals(0.0));
      expect(tracker.hasMoved, isFalse);
    });

    test('accumulates valid movement distance and updates hasMoved', () {
      tracker.recordFix(lat: 10.7769, lon: 106.7009, speedKmh: 30.0);
      // ~10-15m movement
      tracker.recordFix(lat: 10.7770, lon: 106.7009, speedKmh: 35.0);

      expect(tracker.totalDistanceTraveledMeters, greaterThan(5.0));
      expect(tracker.totalDistanceTraveledMeters, lessThan(20.0));
      expect(tracker.maxSpeedKmh, equals(35.0));
      expect(tracker.hasMoved, isTrue);
    });

    test('buildSummary computes duration and average speed accurately', () {
      final startTime = DateTime(2026, 1, 1, 10, 0, 0);
      final endTime = DateTime(2026, 1, 1, 10, 30, 0); // 30 minutes = 0.5 hours

      tracker.totalDistanceTraveledMeters = 15000; // 15 km
      tracker.maxSpeedKmh = 45.0;

      final summary = tracker.buildSummary(
        startTime: startTime,
        endTime: endTime,
        destinationName: 'Chợ Bến Thành',
        hasArrived: true,
      );

      expect(summary.duration, equals(const Duration(minutes: 30)));
      expect(summary.distanceMeters, equals(15000));
      expect(summary.topSpeedKmh, equals(45.0));
      // 15km in 0.5h = 30 km/h
      expect(summary.avgSpeedKmh, closeTo(30.0, 0.1));
      expect(summary.destinationName, equals('Chợ Bến Thành'));
      expect(summary.hasArrived, isTrue);
    });
  });
}
