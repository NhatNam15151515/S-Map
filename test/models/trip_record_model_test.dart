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

    test('polyline is deeply unmodifiable and mutating source list does not affect model', () {
      final mutablePoints = [
        [10.7725, 106.6980],
        [10.7950, 106.7215],
      ];
      final trip = TripRecordModel(
        id: 'trip_unmodifiable',
        startTime: startTime,
        endTime: endTime,
        durationMs: 1800000,
        distanceMeters: 15400.0,
        avgSpeedKmh: 30.8,
        topSpeedKmh: 55.2,
        polyline: mutablePoints,
        createdAt: createdAt,
      );

      final initialHashCode = trip.hashCode;
      final initialToMap = trip.toMap();

      // Sửa đổi list nguồn ban đầu
      mutablePoints[0][0] = 99.9999;
      mutablePoints.add([11.0, 107.0]);

      // Kiểm tra dữ liệu trong model, hashCode và toMap() không bị ảnh hưởng
      expect(trip.polyline?.first, equals([10.7725, 106.6980]));
      expect(trip.polyline?.length, equals(2));
      expect(trip.hashCode, equals(initialHashCode));
      expect(trip.toMap(), equals(initialToMap));

      // Kiểm tra thao tác can thiệp trực tiếp vào polyline của model sẽ ném UnsupportedError
      expect(() => trip.polyline?.add([12.0, 108.0]), throwsUnsupportedError);
      expect(() => trip.polyline?[0][0] = 50.0, throwsUnsupportedError);
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
        clearOrigin: true,
        clearPolyline: true,
      );

      expect(modified.id, equals('trip_1001'));
      expect(modified.distanceMeters, equals(20000.0));
      expect(modified.hasArrived, isFalse);
      expect(modified.destinationName, isNull);
      expect(modified.originName, isNull);
      expect(modified.polyline, isNull);
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

      expect(
        () => TripRecordModel.fromMap({
          'id': 'trip_bad_point_type',
          'startTime': startTime.toIso8601String(),
          'endTime': endTime.toIso8601String(),
          'polyline': const [
            ['10.77', '106.69'], // Invalid coordinate element type (String instead of num)
          ],
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => TripRecordModel.fromMap({
          'id': 'trip_bad_coords_range',
          'startTime': startTime.toIso8601String(),
          'endTime': endTime.toIso8601String(),
          'polyline': const [
            [95.0, 106.69], // Lat > 90
          ],
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => TripRecordModel.fromMap({
          'id': 'trip_bad_duration',
          'startTime': startTime.toIso8601String(),
          'endTime': endTime.toIso8601String(),
          'durationMs': -100, // Negative duration
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => TripRecordModel.fromMap({
          'id': 'trip_fractional_duration',
          'startTime': startTime.toIso8601String(),
          'endTime': endTime.toIso8601String(),
          'durationMs': 123.45, // Fractional duration (double instead of int)
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => TripRecordModel.fromMap({
          'id': 'trip_bad_distance',
          'startTime': startTime.toIso8601String(),
          'endTime': endTime.toIso8601String(),
          'distanceMeters': -5.0, // Negative distance
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => TripRecordModel.fromMap({
          'id': 'trip_bad_speed',
          'startTime': startTime.toIso8601String(),
          'endTime': endTime.toIso8601String(),
          'avgSpeedKmh': double.nan, // NaN speed
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => TripRecordModel.fromMap({
          'id': 'trip_bad_destination',
          'startTime': startTime.toIso8601String(),
          'endTime': endTime.toIso8601String(),
          'destinationName': 12345, // Non-string destination
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => TripRecordModel.fromMap({
          'id': 'trip_bad_origin',
          'startTime': startTime.toIso8601String(),
          'endTime': endTime.toIso8601String(),
          'originName': 12345, // Non-string origin
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => TripRecordModel.fromMap({
          'id': 'trip_bad_profile',
          'startTime': startTime.toIso8601String(),
          'endTime': endTime.toIso8601String(),
          'vehicleProfile': 999, // Non-string profile
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => TripRecordModel.fromMap({
          'id': 'trip_bad_has_arrived',
          'startTime': startTime.toIso8601String(),
          'endTime': endTime.toIso8601String(),
          'hasArrived': 'true', // String instead of bool
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => TripRecordModel.fromMap({
          'id': 'trip_bad_created_at',
          'startTime': startTime.toIso8601String(),
          'endTime': endTime.toIso8601String(),
          'createdAt': 'not_a_valid_date',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
