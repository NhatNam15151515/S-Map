import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class NoOpPoiRepository implements IPoiRepository {
  const NoOpPoiRepository();

  @override
  Future<List<PoiModel>> searchByName(String query, {int limit = 20}) async => [];

  @override
  Future<List<PoiModel>> searchByNameAscii(String query, {int limit = 20}) async => [];

  @override
  Future<List<PoiModel>> searchByNamePrefix(
    String query, {
    int limit = 80,
    String? provinceCode,
  }) async => [];

  @override
  Future<List<PoiModel>> searchByNameNear({
    required String query,
    required double latitude,
    required double longitude,
    String? provinceCode,
    int limit = 160,
  }) async => [];

  @override
  Future<List<PoiModel>> search(String query, {int limit = 20}) async => [];

  @override
  Future<List<PoiModel>> searchInBounds({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    String? query,
    String? category,
    int limit = 50,
  }) async => [];

  @override
  Future<List<String>> getSuggestions(String query, {int limit = 10}) async => [];

  @override
  Future<PoiModel?> getPoiById(int id) async => null;

  @override
  Future<int> getSchemaVersion() async => 1;

  @override
  Future<List<String>> getNeighborProvinces(String provinceCode) async => [];

  @override
  Future<List<StreetModel>> findStreets({
    required String nameQuery,
    String? provinceCode,
    String? districtCode,
    int limit = 10,
  }) async => [];

  @override
  Future<List<PoiModel>> findHouseNumbers({
    required int streetId,
    int? targetHouseNo,
    int limit = 10,
  }) async => [];

  @override
  Future<List<PoiModel>> searchScoped({
    required String query,
    String? provinceCode,
    String? districtCode,
    int? streetId,
    int limit = 20,
  }) async => [];

  @override
  Future<List<AdminUnitModel>> getAdminUnits({int? level}) async => [];

  Future<List<PoiModel>> getPoisByIds(List<int> ids) async => [];
}
