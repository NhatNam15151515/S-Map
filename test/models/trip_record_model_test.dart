import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/models/models.dart';

void main() {
  group('TripRecordModel Unit Tests', () {
    final startTime = DateTime(2026, 8, 22, 8, 0, 0);
    final endTime = DateTime(2026, 8, 22, 8, 30, 0);
    final createdAt = DateTime(2026, 8, 22, 8, 30, 5);

    final sampleTrip = TripRecordModel(
      id: 'trip_1001',
      startTime: startTime,
      endTime: endTime,
      durationMs: 1800000,
      distanceMeters: 15400.0,
      avgSpeedKmh: 30.8,
      topSpeedKmh: 55.2,
      destinationName: 'Landmark 81',
      originName: 'Chợ Bến Thành',
      hasArrived: true,
      vehicleProfile: 'motorcycle',
      polyline: const [
        [10.7725, 106.6980],
        [10.7950, 106.7215],
      ],
      createdAt: createdAt,
    );

    test('props equality and value semantics work correctly', () {
      final tripDuplicate = TripRecordModel(
        id: 'trip_1001',
        startTime: startTime,
        endTime: endTime,
        durationMs: 1800000,
        distanceMeters: 15400.0,
        avgSpeedKmh: 30.8,
        topSpeedKmh: 55.2,
        destinationName: 'Landmark 81',
        originName: 'Chợ Bến Thành',
        hasArrived: true,
        vehicleProfile: 'motorcycle',
        polyline: const [
          [10.7725, 106.6980],
          [10.7950, 106.7215],
        ],
        createdAt: createdAt,
      );

      expect(sampleTrip, equals(tripDuplicate));
      expect(sampleTrip.hashCode, equals(tripDuplicate.hashCode));
      expect(sampleTrip.distanceKm, closeTo(15.4, 0.01));
      expect(sampleTrip.duration, equals(const Duration(minutes: 30)));
    });

    test('toMap and fromMap serialization round-trip retains all fields', () {
      final map = sampleTrip.toMap();
      final reconstructed = TripRecordModel.fromMap(map);

      expect(reconstructed.id, equals(sampleTrip.id));
      expect(reconstructed.startTime, equals(sampleTrip.startTime));
      expect(reconstructed.endTime, equals(sampleTrip.endTime));
      expect(reconstructed.durationMs, equals(sampleTrip.durationMs));
      expect(reconstructed.distanceMeters, equals(sampleTrip.distanceMeters));
      expect(reconstructed.avgSpeedKmh, equals(sampleTrip.avgSpeedKmh));
      expect(reconstructed.topSpeedKmh, equals(sampleTrip.topSpeedKmh));
      expect(reconstructed.destinationName, equals('Landmark 81'));
      expect(reconstructed.originName, equals('Chợ Bến Thành'));
      expect(reconstructed.hasArrived, isTrue);
      expect(reconstructed.vehicleProfile, equals('motorcycle'));
      expect(reconstructed.polyline?.length, equals(2));
      expect(reconstructed.polyline?.first, equals([10.7725, 106.6980]));
      expect(reconstructed.createdAt, equals(sampleTrip.createdAt));
      expect(reconstructed, equals(sampleTrip));
    });

    test('copyWith modifies specified fields and retains others', () {
      final modified = sampleTrip.copyWith(
        distanceMeters: 20000.0,
        hasArrived: false,
        clearDestination: true,
      );

      expect(modified.id, equals('trip_1001'));
      expect(modified.distanceMeters, equals(20000.0));
      expect(modified.hasArrived, isFalse);
      expect(modified.destinationName, isNull);
      expect(modified.originName, equals('Chợ Bến Thành'));
    });

    test('fromMap handles missing optional values gracefully', () {
      final minimalMap = {
        'id': 'trip_min',
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
      };

      final parsed = TripRecordModel.fromMap(minimalMap);
      expect(parsed.id, equals('trip_min'));
      expect(parsed.durationMs, equals(0));
      expect(parsed.distanceMeters, equals(0.0));
      expect(parsed.avgSpeedKmh, equals(0.0));
      expect(parsed.topSpeedKmh, equals(0.0));
      expect(parsed.destinationName, isNull);
      expect(parsed.hasArrived, isFalse);
      expect(parsed.vehicleProfile, equals('motorcycle'));
      expect(parsed.polyline, isNull);
    });

    test('fromMap throws FormatException when schema is invalid', () {
      expect(
        () => TripRecordModel.fromMap(const {'id': ''}),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => TripRecordModel.fromMap(const {
          'id': 'trip_bad_start',
          'startTime': 12345, // Not a string
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => TripRecordModel.fromMap({
          'id': 'trip_bad_end',
          'startTime': startTime.toIso8601String(),
          'endTime': 'invalid_date_format',
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => TripRecordModel.fromMap({
          'id': 'trip_bad_polyline',
          'startTime': startTime.toIso8601String(),
          'endTime': endTime.toIso8601String(),
          'polyline': 'not_a_list',
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => TripRecordModel.fromMap({
          'id': 'trip_bad_point',
          'startTime': startTime.toIso8601String(),
          'endTime': endTime.toIso8601String(),
          'polyline': const [
            [10.77], // Invalid coordinate length (< 2)
          ],
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
