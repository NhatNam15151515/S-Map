import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

/// Fallback No-Op Repository khi chưa khởi tạo storage
class NoOpCustomRouteRepository implements ICustomRouteRepository {
  const NoOpCustomRouteRepository();

  @override
  Future<List<CustomRouteModel>> getSavedRoutes() async => const [];

  @override
  Future<CustomRouteModel?> getRouteById(String id) async => null;

  @override
  Future<void> saveRoute(CustomRouteModel route) async {}

  @override
  Future<void> deleteRoute(String id) async {}

  @override
  Future<void> clearAllRoutes() async {}

  @override
  Stream<List<CustomRouteModel>> watchSavedRoutes() =>
      Stream.value(const <CustomRouteModel>[]);
}
