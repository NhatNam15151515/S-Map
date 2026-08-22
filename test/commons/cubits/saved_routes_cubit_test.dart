import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class MockCustomRouteRepository implements ICustomRouteRepository {
  final List<CustomRouteModel> storage = [];
  final StreamController<List<CustomRouteModel>> _controller =
      StreamController<List<CustomRouteModel>>.broadcast();
  bool shouldThrow = false;

  @override
  Future<List<CustomRouteModel>> getSavedRoutes() async {
    if (shouldThrow) throw Exception('Database read error');
    return List.unmodifiable(storage);
  }

  @override
  Future<CustomRouteModel?> getRouteById(String id) async {
    if (shouldThrow) throw Exception('Database read error');
    try {
      return storage.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveRoute(CustomRouteModel route) async {
    if (shouldThrow) throw Exception('Database write error');
    final index = storage.indexWhere((r) => r.id == route.id);
    if (index >= 0) {
      storage[index] = route;
    } else {
      storage.add(route);
    }
    _controller.add(List.unmodifiable(storage));
  }

  @override
  Future<void> deleteRoute(String id) async {
    if (shouldThrow) throw Exception('Database delete error');
    storage.removeWhere((r) => r.id == id);
    _controller.add(List.unmodifiable(storage));
  }

  @override
  Future<void> clearAllRoutes() async {
    if (shouldThrow) throw Exception('Database clear error');
    storage.clear();
    _controller.add(List.unmodifiable(storage));
  }

  @override
  Stream<List<CustomRouteModel>> watchSavedRoutes() => _controller.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleRoute1 = CustomRouteModel(
    id: 'saved_1',
    name: 'Tuyến số 1',
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
    totalDistance: 600.0,
    totalTime: 80000,
    profile: RoutingConstants.profileMotorcycle,
    createdAt: DateTime(2026, 8, 22, 12, 0),
  );

  final sampleRoute2 = CustomRouteModel(
    id: 'saved_2',
    name: 'Tuyến số 2',
    waypoints: const [
      SnappedRoadPoint(
        isSnapped: true,
        originalLat: 10.778,
        originalLon: 106.702,
        snappedLat: 10.77805,
        snappedLon: 106.70205,
      ),
    ],
    fullPolyline: const [
      [10.77805, 106.70205],
    ],
    totalDistance: 1500.0,
    totalTime: 200000,
    profile: RoutingConstants.profileMotorcycle,
    createdAt: DateTime(2026, 8, 22, 13, 0),
  );

  group('SavedRoutesCubit State Transitions & Operations', () {
    late MockCustomRouteRepository mockRepo;
    late SavedRoutesCubit cubit;

    setUp(() {
      mockRepo = MockCustomRouteRepository();
      cubit = SavedRoutesCubit(customRouteRepository: mockRepo);
    });

    tearDown(() {
      cubit.close();
    });

    test('initial state loads routes automatically and emits success', () async {
      await Future.delayed(const Duration(milliseconds: 10));
      expect(cubit.state.status, equals(SavedRoutesStatus.success));
      expect(cubit.state.routes, isEmpty);
      expect(cubit.state.isEmpty, isTrue);
    });

    test('loadSavedRoutes with items emits loaded routes', () async {
      mockRepo.storage.addAll([sampleRoute1, sampleRoute2]);

      await cubit.loadSavedRoutes();

      expect(cubit.state.status, equals(SavedRoutesStatus.success));
      expect(cubit.state.routes.length, equals(2));
      expect(cubit.state.count, equals(2));
      expect(cubit.state.routes[0].id, equals('saved_1'));
    });

    test('deleteRoute removes route and updates state', () async {
      mockRepo.storage.addAll([sampleRoute1, sampleRoute2]);
      await cubit.loadSavedRoutes();
      expect(cubit.state.routes.length, equals(2));

      await cubit.deleteRoute('saved_1');
      expect(cubit.state.routes.length, equals(1));
      expect(cubit.state.routes.first.id, equals('saved_2'));
    });

    test('clearAllRoutes empties list and updates state', () async {
      mockRepo.storage.addAll([sampleRoute1, sampleRoute2]);
      await cubit.loadSavedRoutes();

      await cubit.clearAllRoutes();
      expect(cubit.state.routes, isEmpty);
      expect(cubit.state.isEmpty, isTrue);
    });

    test('repository exception emits error status with message', () async {
      mockRepo.shouldThrow = true;

      await cubit.loadSavedRoutes();
      expect(cubit.state.status, equals(SavedRoutesStatus.error));
      expect(cubit.state.errorMessage, contains('Database read error'));
    });
  });

  group('NoOpCustomRouteRepository Fallback Tests', () {
    const noOpRepo = NoOpCustomRouteRepository();

    test('returns safe defaults without error', () async {
      expect(await noOpRepo.getSavedRoutes(), isEmpty);
      expect(await noOpRepo.getRouteById('any_id'), isNull);
      await noOpRepo.saveRoute(sampleRoute1);
      await noOpRepo.deleteRoute('any_id');
      await noOpRepo.clearAllRoutes();

      final stream = noOpRepo.watchSavedRoutes();
      expectLater(stream, emits(isEmpty));
    });
  });
}
