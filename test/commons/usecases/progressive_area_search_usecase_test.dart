import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/usecases/progressive_area_search_usecase.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class MockPoiRepository implements IPoiRepository {
  List<PoiModel> inBoundsPois = [];
  List<PoiModel> textSearchPois = [];

  @override
  Future<List<PoiModel>> searchInBounds({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    String? query,
    String? category,
    int limit = 50,
  }) async {
    return inBoundsPois;
  }

  @override
  Future<List<PoiModel>> search(String query, {int limit = 20}) async {
    return textSearchPois;
  }

  @override
  Future<List<PoiModel>> searchByName(String query, {int limit = 20}) async => [];

  @override
  Future<List<PoiModel>> searchByNameAscii(String query, {int limit = 20}) async => [];

  @override
  Future<List<String>> getSuggestions(String query, {int limit = 10}) async => [];

  @override
  Future<PoiModel?> getPoiById(int id) async => null;
}

void main() {
  group('ProgressiveAreaSearchUseCase Unit Tests', () {
    late MockPoiRepository mockRepo;
    late ProgressiveAreaSearchUseCase useCase;

    setUp(() {
      mockRepo = MockPoiRepository();
      useCase = ProgressiveAreaSearchUseCase(poiRepository: mockRepo);
    });

    test('returns empty result when no candidates exist across all zoom levels', () async {
      mockRepo.inBoundsPois = [];
      mockRepo.textSearchPois = [];

      final result = await useCase.execute(
        center: const LatLng(10.7769, 106.7009),
        initialZoom: 16.0,
        query: null,
        category: 'all',
        limit: 20,
        isCancelled: () => false,
      );

      expect(result.isSuccess, isFalse);
      expect(result.pois, isEmpty);
    });

    test('finds nearby POI and returns matching bounds and resolved zoom', () async {
      mockRepo.inBoundsPois = [
        const PoiModel(
          id: 1,
          name: 'Nhà thờ Đức Bà',
          nameAscii: 'Nha tho Duc Ba',
          category: 'tourism',
          lat: 10.7798,
          lon: 106.6990,
        ),
      ];

      final result = await useCase.execute(
        center: const LatLng(10.7798, 106.6990),
        initialZoom: 16.0,
        query: null,
        category: 'all',
        limit: 20,
        isCancelled: () => false,
      );

      expect(result.isSuccess, isTrue);
      expect(result.pois.length, equals(1));
      expect(result.pois.first.name, equals('Nhà thờ Đức Bà'));
      expect(result.bounds, isNotNull);
    });

    test('respects cancellation callback and terminates early', () async {
      mockRepo.inBoundsPois = [
        const PoiModel(
          id: 1,
          name: 'Bến Thành',
          nameAscii: 'Ben Thanh',
          lat: 10.7725,
          lon: 106.6980,
        ),
      ];

      final result = await useCase.execute(
        center: const LatLng(10.7725, 106.6980),
        initialZoom: 16.0,
        query: null,
        category: 'all',
        limit: 20,
        isCancelled: () => true, // Cancelled immediately
      );

      expect(result.isSuccess, isFalse);
      expect(result.pois, isEmpty);
    });
  });
}
