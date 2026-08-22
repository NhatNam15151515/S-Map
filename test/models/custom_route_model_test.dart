import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';

void main() {
  group('CustomRouteModel Unit Tests', () {
    const sampleSnappedPoint1 = SnappedRoadPoint(
      isSnapped: true,
      originalLat: 10.773,
      originalLon: 106.699,
      snappedLat: 10.77305,
      snappedLon: 106.69905,
      streetName: 'Nguyễn Du',
      distanceToRoad: 4.2,
    );

    const sampleSnappedPoint2 = SnappedRoadPoint(
      isSnapped: true,
      originalLat: 10.778,
      originalLon: 106.702,
      snappedLat: 10.77805,
      snappedLon: 106.70205,
      streetName: 'Lê Thánh Tôn',
      distanceToRoad: 3.1,
    );

    final sampleCreatedAt = DateTime(2026, 8, 22, 10, 30);
    final sampleUpdatedAt = DateTime(2026, 8, 22, 10, 45);

    final sampleModel = CustomRouteModel(
      id: 'route_123',
      name: 'Lộ trình đi làm',
      waypoints: const [sampleSnappedPoint1, sampleSnappedPoint2],
      fullPolyline: const [
        [10.77305, 106.69905],
        [10.77500, 106.70000],
        [10.77805, 106.70205],
      ],
      totalDistance: 1250.5,
      totalTime: 180000,
      profile: RoutingConstants.profileMotorcycle,
      createdAt: sampleCreatedAt,
      updatedAt: sampleUpdatedAt,
      description: 'Lộ trình tránh kẹt xe giờ cao điểm',
    );

    test('props equality and value semantics work correctly', () {
      final duplicateModel = CustomRouteModel(
        id: 'route_123',
        name: 'Lộ trình đi làm',
        waypoints: const [sampleSnappedPoint1, sampleSnappedPoint2],
        fullPolyline: const [
          [10.77305, 106.69905],
          [10.77500, 106.70000],
          [10.77805, 106.70205],
        ],
        totalDistance: 1250.5,
        totalTime: 180000,
        profile: RoutingConstants.profileMotorcycle,
        createdAt: sampleCreatedAt,
        updatedAt: sampleUpdatedAt,
        description: 'Lộ trình tránh kẹt xe giờ cao điểm',
      );

      expect(sampleModel, equals(duplicateModel));
      expect(sampleModel.hashCode, equals(duplicateModel.hashCode));
    });

    test('toMap and fromMap serialization round-trip retains all fields', () {
      final map = sampleModel.toMap();
      expect(map['id'], equals('route_123'));
      expect(map['name'], equals('Lộ trình đi làm'));
      expect(map['totalDistance'], equals(1250.5));
      expect(map['totalTime'], equals(180000));
      expect(map['profile'], equals(RoutingConstants.profileMotorcycle));
      expect(map['description'], equals('Lộ trình tránh kẹt xe giờ cao điểm'));
      expect((map['waypoints'] as List).length, equals(2));
      expect((map['fullPolyline'] as List).length, equals(3));

      final restoredModel = CustomRouteModel.fromMap(map);
      expect(restoredModel.id, equals(sampleModel.id));
      expect(restoredModel.name, equals(sampleModel.name));
      expect(restoredModel.waypoints.length, equals(2));
      expect(restoredModel.waypoints[0].snappedLat, equals(sampleSnappedPoint1.snappedLat));
      expect(restoredModel.fullPolyline.length, equals(3));
      expect(restoredModel.totalDistance, equals(sampleModel.totalDistance));
      expect(restoredModel.totalTime, equals(sampleModel.totalTime));
      expect(restoredModel.createdAt, equals(sampleModel.createdAt));
      expect(restoredModel.updatedAt, equals(sampleModel.updatedAt));
      expect(restoredModel.description, equals(sampleModel.description));
    });

    test('copyWith modifies specified fields and retains others', () {
      final updated = sampleModel.copyWith(
        name: 'Lộ trình cập nhật',
        totalDistance: 1500.0,
        clearDescription: true,
      );

      expect(updated.id, equals(sampleModel.id));
      expect(updated.name, equals('Lộ trình cập nhật'));
      expect(updated.totalDistance, equals(1500.0));
      expect(updated.description, isNull);
      expect(updated.waypoints, equals(sampleModel.waypoints));
    });

    test('fromMap handles missing or default values gracefully', () {
      final minimalMap = <String, dynamic>{
        'id': 'route_empty',
        'name': 'Default Route',
      };

      final model = CustomRouteModel.fromMap(minimalMap);
      expect(model.id, equals('route_empty'));
      expect(model.name, equals('Default Route'));
      expect(model.waypoints, isEmpty);
      expect(model.fullPolyline, isEmpty);
      expect(model.totalDistance, equals(0.0));
      expect(model.totalTime, equals(0));
      expect(model.profile, equals(RoutingConstants.profileMotorcycle));
      expect(model.description, isNull);
    });
  });
}
