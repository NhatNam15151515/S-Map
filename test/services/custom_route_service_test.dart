import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/services/services.dart';

class FakeHiveBox implements Box<dynamic> {
  final Map<dynamic, dynamic> _storage = {};
  final StreamController<BoxEvent> _eventController =
      StreamController<BoxEvent>.broadcast();
  bool shouldThrow = false;

  @override
  bool get isOpen => true;

  @override
  Iterable<dynamic> get keys {
    if (shouldThrow) throw Exception('Hive keys read failed');
    return _storage.keys;
  }

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) {
    if (shouldThrow) throw Exception('Hive get failed');
    return _storage.containsKey(key) ? _storage[key] : defaultValue;
  }

  @override
  Future<void> put(dynamic key, dynamic value) async {
    if (shouldThrow) throw Exception('Hive put failed');
    _storage[key] = value;
    _eventController.add(BoxEvent(key, value, false));
  }

  @override
  Future<void> delete(dynamic key) async {
    if (shouldThrow) throw Exception('Hive delete failed');
    final prev = _storage.remove(key);
    _eventController.add(BoxEvent(key, prev, true));
  }

  @override
  Future<int> clear() async {
    if (shouldThrow) throw Exception('Hive clear failed');
    final count = _storage.length;
    _storage.clear();
    _eventController.add(BoxEvent(null, null, false));
    return count;
  }

  @override
  Future<void> close() async {
    await _eventController.close();
  }

  @override
  Stream<BoxEvent> watch({dynamic key}) => _eventController.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleSnappedPoint = SnappedRoadPoint(
    isSnapped: true,
    originalLat: 10.773,
    originalLon: 106.699,
    snappedLat: 10.77305,
    snappedLon: 106.69905,
    streetName: 'Nguyễn Du',
    distanceToRoad: 4.2,
  );

  final sampleRoute1 = CustomRouteModel(
    id: 'route_1',
    name: 'Tuyến đường 1',
    waypoints: const [sampleSnappedPoint],
    fullPolyline: const [
      [10.77305, 106.69905],
    ],
    totalDistance: 500.0,
    totalTime: 60000,
    profile: RoutingConstants.profileMotorcycle,
    createdAt: DateTime(2026, 8, 22, 9, 0),
    description: 'Mô tả tuyến 1',
  );

  final sampleRoute2 = CustomRouteModel(
    id: 'route_2',
    name: 'Tuyến đường 2',
    waypoints: const [sampleSnappedPoint],
    fullPolyline: const [
      [10.77305, 106.69905],
    ],
    totalDistance: 1200.0,
    totalTime: 120000,
    profile: RoutingConstants.profileMotorcycle,
    createdAt: DateTime(2026, 8, 22, 10, 0), // Newest
    description: 'Mô tả tuyến 2',
  );

  group('CustomRouteServiceImpl Tests with FakeHiveBox', () {
    late FakeHiveBox fakeBox;
    late CustomRouteServiceImpl service;

    setUp(() {
      fakeBox = FakeHiveBox();
      service = CustomRouteServiceImpl(customBox: fakeBox);
    });

    tearDown(() async {
      await fakeBox.close();
    });

    test('getSavedRoutes returns empty list initially', () async {
      final routes = await service.getSavedRoutes();
      expect(routes, isEmpty);
    });

    test('saveRoute stores route and getSavedRoutes sorts newest first', () async {
      await service.saveRoute(sampleRoute1);
      await service.saveRoute(sampleRoute2);

      final routes = await service.getSavedRoutes();
      expect(routes.length, equals(2));
      expect(routes.first.id, equals('route_2')); // Newest first
      expect(routes.last.id, equals('route_1'));
    });

    test('getSavedRoutes skips corrupted route records and retains valid ones', () async {
      await service.saveRoute(sampleRoute1);
      fakeBox._storage['corrupted_route'] = {'waypoints': 'invalid_format'};

      final routes = await service.getSavedRoutes();
      expect(routes.length, equals(1));
      expect(routes.first.id, equals('route_1'));
    });

    test('getRouteById returns correct route or null if not found', () async {
      await service.saveRoute(sampleRoute1);

      final found = await service.getRouteById('route_1');
      expect(found, isNotNull);
      expect(found?.name, equals('Tuyến đường 1'));
      expect(found?.totalDistance, equals(500.0));

      final notFound = await service.getRouteById('non_existent_id');
      expect(notFound, isNull);
    });

    test('deleteRoute removes specified route from storage', () async {
      await service.saveRoute(sampleRoute1);
      await service.saveRoute(sampleRoute2);

      await service.deleteRoute('route_1');

      final routes = await service.getSavedRoutes();
      expect(routes.length, equals(1));
      expect(routes.first.id, equals('route_2'));
      expect(await service.getRouteById('route_1'), isNull);
    });

    test('clearAllRoutes wipes all saved routes', () async {
      await service.saveRoute(sampleRoute1);
      await service.saveRoute(sampleRoute2);

      await service.clearAllRoutes();

      final routes = await service.getSavedRoutes();
      expect(routes, isEmpty);
    });

    test('operations propagate Hive exceptions', () async {
      fakeBox.shouldThrow = true;

      expect(() => service.getSavedRoutes(), throwsA(isA<Exception>()));
      expect(() => service.getRouteById('route_1'), throwsA(isA<Exception>()));
      expect(() => service.saveRoute(sampleRoute1), throwsA(isA<Exception>()));
      expect(() => service.deleteRoute('route_1'), throwsA(isA<Exception>()));
      expect(() => service.clearAllRoutes(), throwsA(isA<Exception>()));
    });

    test('watchSavedRoutes stream emits updated list when storage changes', () async {
      final stream = service.watchSavedRoutes();

      expectLater(
        stream,
        emitsInOrder([
          isEmpty,
          hasLength(1),
          isEmpty,
        ]),
      );

      // Trigger writes
      await Future.delayed(const Duration(milliseconds: 10));
      await service.saveRoute(sampleRoute1);
      await Future.delayed(const Duration(milliseconds: 10));
      await service.deleteRoute('route_1');
    });
  });
}
