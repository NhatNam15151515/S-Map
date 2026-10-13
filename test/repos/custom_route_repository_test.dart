import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';

class MockCustomRouteService implements ICustomRouteService {
  final List<CustomRouteModel> storage = [];

  @override
  Future<void> init() async {}

  @override
  Future<List<CustomRouteModel>> getSavedRoutes() async => List.unmodifiable(storage);

  @override
  Future<CustomRouteModel?> getRouteById(String id) async {
    try {
      return storage.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveRoute(CustomRouteModel route) async {
    final index = storage.indexWhere((r) => r.id == route.id);
    if (index >= 0) {
      storage[index] = route;
    } else {
      storage.add(route);
    }
  }

  @override
  Future<void> deleteRoute(String id) async {
    storage.removeWhere((r) => r.id == id);
  }

  @override
  Future<void> clearAllRoutes() async {
    storage.clear();
  }

  @override
  Stream<List<CustomRouteModel>> watchSavedRoutes() =>
      Stream.value(List.unmodifiable(storage));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleRoute = CustomRouteModel(
    id: 'repo_route_1',
    name: 'Tuyến thử nghiệm repo',
    waypoints: const [
      SnappedRoadPoint(
        isSnapped: true,
        originalLat: 10.773,
        originalLon: 106.699,
        snappedLat: 10.77305,
        snappedLon: 106.69905,
      ),
    ],
    fullPolyline: const [
      [10.77305, 106.69905],
    ],
    totalDistance: 750.0,
    totalTime: 90000,
    profile: RoutingConstants.profileMotorcycle,
    createdAt: DateTime(2026, 8, 22, 11, 0),
  );

  group('CustomRouteRepositoryImpl Tests', () {
    late MockCustomRouteService mockService;
    late CustomRouteRepositoryImpl repository;

    setUp(() {
      mockService = MockCustomRouteService();
      repository = CustomRouteRepositoryImpl(customRouteService: mockService);
    });

    test('getSavedRoutes, saveRoute, getRouteById, deleteRoute, clearAllRoutes delegation', () async {
      expect(await repository.getSavedRoutes(), isEmpty);

      await repository.saveRoute(sampleRoute);
      final list = await repository.getSavedRoutes();
      expect(list.length, equals(1));
      expect(list.first.id, equals('repo_route_1'));

      final retrieved = await repository.getRouteById('repo_route_1');
      expect(retrieved, equals(sampleRoute));

      await repository.deleteRoute('repo_route_1');
      expect(await repository.getSavedRoutes(), isEmpty);

      await repository.saveRoute(sampleRoute);
      await repository.clearAllRoutes();
      expect(await repository.getSavedRoutes(), isEmpty);
    });

    test('watchSavedRoutes emits stream from service', () async {
      mockService.storage.add(sampleRoute);

      final stream = repository.watchSavedRoutes();
      expectLater(
        stream,
        emits([sampleRoute]),
      );
    });
  });
}
