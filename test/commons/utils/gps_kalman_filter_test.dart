import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/utils/gps_kalman_filter.dart';

void main() {
  late GpsKalmanFilter filter;

  setUp(() {
    filter = GpsKalmanFilter();
  });

  group('GpsKalmanFilter - Initialization', () {
    test('should not be initialized before first update', () {
      expect(filter.isInitialized, isFalse);
    });

    test('should be initialized after first update', () {
      filter.update(
        gpsLat: 10.7769,
        gpsLon: 106.7009,
        accuracyMeters: 10.0,
        timestamp: DateTime(2026, 1, 1, 0, 0, 0),
      );
      expect(filter.isInitialized, isTrue);
    });

    test('first update should return same coordinates as input', () {
      final result = filter.update(
        gpsLat: 10.7769,
        gpsLon: 106.7009,
        accuracyMeters: 10.0,
        timestamp: DateTime(2026, 1, 1, 0, 0, 0),
      );
      expect(result.lat, closeTo(10.7769, 1e-6));
      expect(result.lon, closeTo(106.7009, 1e-6));
    });

    test('reset should clear initialization state', () {
      filter.update(
        gpsLat: 10.7769,
        gpsLon: 106.7009,
        accuracyMeters: 10.0,
        timestamp: DateTime(2026, 1, 1, 0, 0, 0),
      );
      expect(filter.isInitialized, isTrue);

      filter.reset();
      expect(filter.isInitialized, isFalse);
    });
  });

  group('GpsKalmanFilter - Noise Reduction', () {
    test('should smooth noisy GPS readings along a straight path', () {
      // Mô phỏng xe máy đi thẳng trên đường Nguyễn Trãi (hướng Bắc)
      // GPS fix mỗi giây, tốc độ ~30 km/h (~8.3 m/s)
      // Thêm nhiễu ±15m (±0.000135 deg) vào lat
      const baseLat = 10.7700;
      const baseLon = 106.6900;
      const speedMps = 8.3; // ~30 km/h
      const stepPerSec = speedMps / 111320.0; // deg lat per second

      final noisePattern = [
        0.000135, -0.000160, 0.000180, -0.000100, 0.000070,
        -0.000170, 0.000140, -0.000090, 0.000120, -0.000150,
        0.000110, -0.000130, 0.000160, -0.000080, 0.000095,
        -0.000145, 0.000105, -0.000125, 0.000155, -0.000075,
      ];

      final baseTime = DateTime(2026, 1, 1, 12, 0, 0);
      double totalRawError = 0;
      double totalFilteredError = 0;

      for (int i = 0; i < noisePattern.length; i++) {
        final trueLat = baseLat + stepPerSec * i;
        final noisyLat = trueLat + noisePattern[i];
        final t = baseTime.add(Duration(seconds: i));

        final result = filter.update(
          gpsLat: noisyLat,
          gpsLon: baseLon,
          accuracyMeters: 15.0,
          speedMps: speedMps,
          headingDeg: 0.0,
          timestamp: t,
        );

        // Skip first 3 readings (filter warm-up / convergence)
        if (i >= 3) {
          totalRawError += (noisyLat - trueLat).abs();
          totalFilteredError += (result.lat - trueLat).abs();
        }
      }

      // Filtered error phải nhỏ hơn raw error (sau warm-up)
      expect(
        totalFilteredError,
        lessThan(totalRawError),
        reason:
            'Kalman filter should reduce total positioning error after warm-up. '
            'Raw error: $totalRawError, Filtered: $totalFilteredError',
      );
    });

    test('should trust GPS more when accuracy is good', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);

      // Khởi tạo
      filter.update(
        gpsLat: 10.7700,
        gpsLon: 106.6900,
        accuracyMeters: 5.0,
        timestamp: t0,
      );

      // GPS fix cách 1 giây, accuracy rất tốt (3m)
      final goodAccuracy = filter.update(
        gpsLat: 10.7705,
        gpsLon: 106.6900,
        accuracyMeters: 3.0,
        timestamp: t0.add(const Duration(seconds: 1)),
      );

      // Reset và thử với accuracy kém
      filter.reset();
      filter.update(
        gpsLat: 10.7700,
        gpsLon: 106.6900,
        accuracyMeters: 5.0,
        timestamp: t0,
      );

      final badAccuracy = filter.update(
        gpsLat: 10.7705,
        gpsLon: 106.6900,
        accuracyMeters: 50.0,
        timestamp: t0.add(const Duration(seconds: 1)),
      );

      // Khi accuracy tốt, filtered position nên gần GPS measurement hơn
      final goodDelta = (goodAccuracy.lat - 10.7705).abs();
      final badDelta = (badAccuracy.lat - 10.7705).abs();

      expect(
        goodDelta,
        lessThanOrEqualTo(badDelta),
        reason:
            'Filter should trust GPS more when accuracy is good. '
            'Good accuracy delta: $goodDelta, Bad accuracy delta: $badDelta',
      );
    });
  });

  group('GpsKalmanFilter - GPS Teleport Handling', () {
    test('should hard-reset on GPS teleport (> 200m jump)', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);

      // Khởi tạo tại Q1
      filter.update(
        gpsLat: 10.7700,
        gpsLon: 106.6900,
        accuracyMeters: 10.0,
        timestamp: t0,
      );

      // GPS nhảy sang Thủ Đức (~5km away) — teleport, 1 giây sau
      final result = filter.update(
        gpsLat: 10.8200,
        gpsLon: 106.7400,
        accuracyMeters: 10.0,
        timestamp: t0.add(const Duration(seconds: 1)),
      );

      // Sau teleport, filter nên reset về vị trí GPS mới
      expect(result.lat, closeTo(10.8200, 0.001));
      expect(result.lon, closeTo(106.7400, 0.001));
    });
  });

  group('GpsKalmanFilter - Reset Behavior', () {
    test('should produce same result after reset + same input', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);

      final first = filter.update(
        gpsLat: 10.7769,
        gpsLon: 106.7009,
        accuracyMeters: 10.0,
        timestamp: t0,
      );

      filter.reset();

      final second = filter.update(
        gpsLat: 10.7769,
        gpsLon: 106.7009,
        accuracyMeters: 10.0,
        timestamp: t0,
      );

      expect(second.lat, closeTo(first.lat, 1e-10));
      expect(second.lon, closeTo(first.lon, 1e-10));
    });

    test('filteredLat/filteredLon should match last update result', () {
      final result = filter.update(
        gpsLat: 10.7769,
        gpsLon: 106.7009,
        accuracyMeters: 10.0,
        timestamp: DateTime(2026, 1, 1, 12, 0, 0),
      );

      expect(filter.filteredLat, equals(result.lat));
      expect(filter.filteredLon, equals(result.lon));
    });
  });

  group('GpsKalmanFilter - Edge Cases', () {
    test('should handle zero accuracy gracefully (use min noise)', () {
      expect(
        () => filter.update(
          gpsLat: 10.7769,
          gpsLon: 106.7009,
          accuracyMeters: 0.0,
          timestamp: DateTime(2026, 1, 1, 12, 0, 0),
        ),
        returnsNormally,
      );
    });

    test('should handle very large accuracy gracefully', () {
      expect(
        () => filter.update(
          gpsLat: 10.7769,
          gpsLon: 106.7009,
          accuracyMeters: 1000.0,
          timestamp: DateTime(2026, 1, 1, 12, 0, 0),
        ),
        returnsNormally,
      );
    });

    test('should handle negative speed gracefully', () {
      expect(
        () => filter.update(
          gpsLat: 10.7769,
          gpsLon: 106.7009,
          accuracyMeters: 10.0,
          speedMps: -5.0,
          timestamp: DateTime(2026, 1, 1, 12, 0, 0),
        ),
        returnsNormally,
      );
    });

    test('should handle rapid consecutive updates with proper timestamps', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      for (int i = 0; i < 10; i++) {
        final result = filter.update(
          gpsLat: 10.7769 + i * 0.00001,
          gpsLon: 106.7009,
          accuracyMeters: 10.0,
          timestamp: t0.add(Duration(seconds: i)),
        );
        expect(result.lat.isFinite, isTrue);
        expect(result.lon.isFinite, isTrue);
      }
    });

    test('should maintain finite values after many iterations', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      // 1000 iterations — check for NaN/Infinity accumulation
      for (int i = 0; i < 1000; i++) {
        final result = filter.update(
          gpsLat: 10.7700 + i * 0.000001,
          gpsLon: 106.6900 + i * 0.000001,
          accuracyMeters: 10.0 + (i % 30), // varying accuracy
          speedMps: 8.0,
          timestamp: t0.add(Duration(seconds: i)),
        );
        expect(result.lat.isFinite, isTrue,
            reason: 'lat should be finite at iteration $i');
        expect(result.lon.isFinite, isTrue,
            reason: 'lon should be finite at iteration $i');
      }
    });
  });
}
