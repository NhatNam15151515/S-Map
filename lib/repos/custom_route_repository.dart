import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class CustomRouteRepositoryImpl implements ICustomRouteRepository {
  final ICustomRouteService _customRouteService;

  CustomRouteRepositoryImpl({required ICustomRouteService customRouteService})
      : _customRouteService = customRouteService;

  @override
  Future<List<CustomRouteModel>> getSavedRoutes() =>
      _customRouteService.getSavedRoutes();

  @override
  Future<CustomRouteModel?> getRouteById(String id) =>
      _customRouteService.getRouteById(id);

  @override
  Future<void> saveRoute(CustomRouteModel route) =>
      _customRouteService.saveRoute(route);

  @override
  Future<void> deleteRoute(String id) =>
      _customRouteService.deleteRoute(id);

  @override
  Future<void> clearAllRoutes() =>
      _customRouteService.clearAllRoutes();

  @override
  Stream<List<CustomRouteModel>> watchSavedRoutes() =>
      _customRouteService.watchSavedRoutes();
}
