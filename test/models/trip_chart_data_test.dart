import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/models/models.dart';

void main() {
  group('TripChartData Unit Tests', () {
    final baseDate = DateTime(2026, 8, 23, 10, 30); // Sunday, Aug 23, 2026

    TripRecordModel createTrip({
      required String id,
      required DateTime time,
      required double distanceMeters,
      String vehicle = 'motorcycle',
      bool arrived = true,
    }) {
      return TripRecordModel(
        id: id,
        startTime: time,
        endTime: time.add(const Duration(minutes: 20)),
        durationMs: 20 * 60 * 1000,
        distanceMeters: distanceMeters,
        avgSpeedKmh: 30.0,
        topSpeedKmh: 45.0,
        hasArrived: arrived,
        vehicleProfile: vehicle,
        createdAt: time,
      );
    }

    test('filterTripsByTimeRange filters today correctly', () {
      final trips = [
        createTrip(id: '1', time: DateTime(2026, 8, 23, 8, 0), distanceMeters: 5000),
        createTrip(id: '2', time: DateTime(2026, 8, 23, 14, 0), distanceMeters: 3000),
        createTrip(id: '3', time: DateTime(2026, 8, 22, 23, 59), distanceMeters: 4000), // Yesterday
      ];

      final filtered = TripChartData.filterTripsByTimeRange(
        trips,
        StatsTimeRange.today,
        now: baseDate,
      );

      expect(filtered.length, 2);
      expect(filtered.map((t) => t.id), containsAll(['1', '2']));
    });

    test('filterTripsByTimeRange filters thisWeek correctly', () {
      // Base date is Sunday Aug 23, 2026 -> Week is Mon Aug 17 to Sun Aug 23
      final trips = [
        createTrip(id: '1', time: DateTime(2026, 8, 17, 8, 0), distanceMeters: 5000), // Mon
        createTrip(id: '2', time: DateTime(2026, 8, 23, 12, 0), distanceMeters: 2000), // Sun
        createTrip(id: '3', time: DateTime(2026, 8, 16, 23, 59), distanceMeters: 4000), // Prev week Sun
        createTrip(id: '4', time: DateTime(2026, 8, 24, 0, 1), distanceMeters: 1000), // Next week Mon
      ];

      final filtered = TripChartData.filterTripsByTimeRange(
        trips,
        StatsTimeRange.thisWeek,
        now: baseDate,
      );

      expect(filtered.length, 2);
      expect(filtered.map((t) => t.id), containsAll(['1', '2']));
    });

    test('filterTripsByTimeRange filters thisMonth correctly', () {
      final trips = [
        createTrip(id: '1', time: DateTime(2026, 8, 1, 1, 0), distanceMeters: 1000),
        createTrip(id: '2', time: DateTime(2026, 8, 31, 23, 0), distanceMeters: 2000),
        createTrip(id: '3', time: DateTime(2026, 7, 31, 23, 59), distanceMeters: 3000),
        createTrip(id: '4', time: DateTime(2026, 9, 1, 0, 1), distanceMeters: 4000),
      ];

      final filtered = TripChartData.filterTripsByTimeRange(
        trips,
        StatsTimeRange.thisMonth,
        now: baseDate,
      );

      expect(filtered.length, 2);
      expect(filtered.map((t) => t.id), containsAll(['1', '2']));
    });

    test('filterTripsByTimeRange filters thisYear correctly', () {
      final trips = [
        createTrip(id: '1', time: DateTime(2026, 1, 1, 1, 0), distanceMeters: 1000),
        createTrip(id: '2', time: DateTime(2026, 12, 31, 23, 0), distanceMeters: 2000),
        createTrip(id: '3', time: DateTime(2025, 12, 31, 23, 59), distanceMeters: 3000),
      ];

      final filtered = TripChartData.filterTripsByTimeRange(
        trips,
        StatsTimeRange.thisYear,
        now: baseDate,
      );

      expect(filtered.length, 2);
      expect(filtered.map((t) => t.id), containsAll(['1', '2']));
    });

    test('filterTripsByTimeRange allTime returns all trips', () {
      final trips = [
        createTrip(id: '1', time: DateTime(2024, 1, 1), distanceMeters: 1000),
        createTrip(id: '2', time: DateTime(2026, 8, 23), distanceMeters: 2000),
      ];

      final filtered = TripChartData.filterTripsByTimeRange(
        trips,
        StatsTimeRange.allTime,
        now: baseDate,
      );

      expect(filtered.length, 2);
    });

    test('fromTrips today generates 6 hourly buckets with accurate distances', () {
      final trips = [
        createTrip(id: '1', time: DateTime(2026, 8, 23, 1, 0), distanceMeters: 2000), // bucket 0 (0-4h)
        createTrip(id: '2', time: DateTime(2026, 8, 23, 9, 30), distanceMeters: 3500), // bucket 2 (8-12h)
        createTrip(id: '3', time: DateTime(2026, 8, 23, 10, 0), distanceMeters: 1500), // bucket 2 (8-12h)
      ];

      final chart = TripChartData.fromTrips(trips, StatsTimeRange.today, now: baseDate);

      expect(chart.bars.length, 6);
      expect(chart.bars[0].distanceKm, 2.0);
      expect(chart.bars[0].tripCount, 1);
      expect(chart.bars[1].distanceKm, 0.0);
      expect(chart.bars[2].distanceKm, 5.0);
      expect(chart.bars[2].tripCount, 2);
      expect(chart.totalDistanceKm, 7.0);
      expect(chart.maxDistanceKm, 5.0);
      expect(chart.isNotEmpty, isTrue);
    });

    test('fromTrips thisWeek generates 7 day buckets', () {
      final trips = [
        createTrip(id: '1', time: DateTime(2026, 8, 17, 10, 0), distanceMeters: 4000), // Monday (x=0)
        createTrip(id: '2', time: DateTime(2026, 8, 23, 15, 0), distanceMeters: 6000), // Sunday (x=6)
      ];

      final chart = TripChartData.fromTrips(trips, StatsTimeRange.thisWeek, now: baseDate);

      expect(chart.bars.length, 7);
      expect(chart.bars[0].label, 'T2');
      expect(chart.bars[0].distanceKm, 4.0);
      expect(chart.bars[6].label, 'CN');
      expect(chart.bars[6].distanceKm, 6.0);
      expect(chart.totalDistanceKm, 10.0);
      expect(chart.maxDistanceKm, 6.0);
    });

    test('fromTrips thisMonth generates 6 date intervals', () {
      final trips = [
        createTrip(id: '1', time: DateTime(2026, 8, 3, 10, 0), distanceMeters: 10000), // 1-5 (x=0)
        createTrip(id: '2', time: DateTime(2026, 8, 28, 10, 0), distanceMeters: 5000), // 26-31 (x=5)
      ];

      final chart = TripChartData.fromTrips(trips, StatsTimeRange.thisMonth, now: baseDate);

      expect(chart.bars.length, 6);
      expect(chart.bars[0].distanceKm, 10.0);
      expect(chart.bars[5].distanceKm, 5.0);
      expect(chart.totalDistanceKm, 15.0);
    });

    test('fromTrips thisYear generates 12 month buckets', () {
      final trips = [
        createTrip(id: '1', time: DateTime(2026, 1, 15), distanceMeters: 12000), // Jan (T1)
        createTrip(id: '2', time: DateTime(2026, 8, 23), distanceMeters: 8000), // Aug (T8)
      ];

      final chart = TripChartData.fromTrips(trips, StatsTimeRange.thisYear, now: baseDate);

      expect(chart.bars.length, 12);
      expect(chart.bars[0].label, 'T1');
      expect(chart.bars[0].distanceKm, 12.0);
      expect(chart.bars[7].label, 'T8');
      expect(chart.bars[7].distanceKm, 8.0);
    });

    test('fromTrips allTime generates 6 recent month buckets', () {
      final trips = [
        createTrip(id: '1', time: DateTime(2026, 8, 23), distanceMeters: 10000),
      ];

      final chart = TripChartData.fromTrips(trips, StatsTimeRange.allTime, now: baseDate);

      expect(chart.bars.length, 6);
      expect(chart.bars.last.distanceKm, 10.0);
    });

    test('empty TripChartData has isNotEmpty == false', () {
      const empty = TripChartData.empty();
      expect(empty.isEmpty, isTrue);
      expect(empty.isNotEmpty, isFalse);
    });
  });
}
