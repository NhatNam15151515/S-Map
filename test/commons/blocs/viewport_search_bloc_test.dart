import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class FakePoiRepository implements IPoiRepository {
  List<PoiModel> mockPois = [];
  Duration delay = Duration.zero;
  bool shouldThrow = false;

  @override
  Future<List<PoiModel>> searchInBounds({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    String? query,
    int limit = 50,
  }) async {
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (shouldThrow) {
      throw Exception('Database query error');
    }
    var filtered = mockPois.where((p) =>
        p.lat >= minLat &&
        p.lat <= maxLat &&
        p.lon >= minLon &&
        p.lon <= maxLon);

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      filtered = filtered.where((p) =>
          p.name.toLowerCase().contains(q) ||
          p.nameAscii.toLowerCase().contains(q) ||
          (p.category != null && p.category!.toLowerCase().contains(q)) ||
          (p.subCategory != null && p.subCategory!.toLowerCase().contains(q)));
    }

    return filtered.take(limit).toList();
  }

  @override
  Future<List<PoiModel>> search(String query, {int limit = 20}) async => [];

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
  final sampleBounds = LatLngBounds(
    southwest: const LatLng(10.70, 106.60),
    northeast: const LatLng(10.85, 106.75),
  );

  const samplePois = [
    PoiModel(
      id: 1,
      name: 'Phở Hòa Pasteur',
      nameAscii: 'Pho Hoa Pasteur',
      category: 'food',
      lat: 10.78,
      lon: 106.69,
      address: '260C Pasteur, Q.3',
    ),
    PoiModel(
      id: 2,
      name: 'Highlands Coffee',
      nameAscii: 'Highlands Coffee',
      category: 'coffee',
      lat: 10.77,
      lon: 106.70,
      address: '75 Nguyễn Du, Q.1',
    ),
    PoiModel(
      id: 3,
      name: 'Khách sạn Rex',
      nameAscii: 'Khach san Rex',
      category: 'hotel',
      lat: 10.776,
      lon: 106.701,
      address: '141 Nguyễn Huệ, Q.1',
    ),
  ];

  late FakePoiRepository fakeRepo;
  late ViewportSearchBloc bloc;

  setUp(() {
    fakeRepo = FakePoiRepository();
    bloc = ViewportSearchBloc(poiRepository: fakeRepo);
  });

  tearDown(() {
    bloc.close();
  });

  group('ViewportSearchBloc Tests', () {
    test('initial state should be ViewportSearchStatus.initial', () {
      expect(bloc.state.status, equals(ViewportSearchStatus.initial));
      expect(bloc.state.isInitial, isTrue);
      expect(bloc.currentCategory, equals(CategoryConstants.all));
    });

    test('SearchInViewportRequested emits [loading, success] when POIs found', () async {
      fakeRepo.mockPois = samplePois;

      final expectedStates = [
        ViewportSearchState(
          status: ViewportSearchStatus.loading,
          bounds: sampleBounds,
          selectedCategory: CategoryConstants.all,
        ),
        ViewportSearchState(
          status: ViewportSearchStatus.success,
          pois: samplePois,
          bounds: sampleBounds,
          selectedCategory: CategoryConstants.all,
        ),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(SearchInViewportRequested(sampleBounds));
    });

    test('SearchInViewportRequested emits [loading, empty] when no POIs found', () async {
      fakeRepo.mockPois = [];

      final expectedStates = [
        ViewportSearchState(
          status: ViewportSearchStatus.loading,
          bounds: sampleBounds,
          selectedCategory: CategoryConstants.all,
        ),
        ViewportSearchState(
          status: ViewportSearchStatus.empty,
          pois: const [],
          bounds: sampleBounds,
          selectedCategory: CategoryConstants.all,
        ),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(SearchInViewportRequested(sampleBounds));
    });

    test('SearchInViewportRequested with category filter only returns matching POIs', () async {
      fakeRepo.mockPois = samplePois;

      final expectedStates = [
        ViewportSearchState(
          status: ViewportSearchStatus.loading,
          bounds: sampleBounds,
          selectedCategory: 'coffee',
        ),
        ViewportSearchState(
          status: ViewportSearchStatus.success,
          pois: [samplePois[1]],
          bounds: sampleBounds,
          selectedCategory: 'coffee',
        ),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(SearchInViewportRequested(sampleBounds, category: 'coffee'));
    });

    test('restartable() transformer cancels prior in-flight query on rapid events', () async {
      fakeRepo.mockPois = samplePois;
      fakeRepo.delay = const Duration(milliseconds: 100);

      final bounds1 = LatLngBounds(
        southwest: const LatLng(10.70, 106.60),
        northeast: const LatLng(10.75, 106.65),
      );
      final bounds2 = LatLngBounds(
        southwest: const LatLng(10.76, 106.66),
        northeast: const LatLng(10.85, 106.75),
      );

      // Phát event 1, sau 20ms phát event 2 đè lên event 1
      bloc.add(SearchInViewportRequested(bounds1));
      await Future.delayed(const Duration(milliseconds: 20));
      bloc.add(SearchInViewportRequested(bounds2));

      // Event 1 bị cancel -> state cuối cùng nhận được là của bounds2
      await expectLater(
        bloc.stream,
        emitsThrough(
          ViewportSearchState(
            status: ViewportSearchStatus.success,
            pois: samplePois,
            bounds: bounds2,
            selectedCategory: CategoryConstants.all,
          ),
        ),
      );
    });

    test('ViewportCategoryFilterChanged updates currentCategory and queries with bounds', () async {
      fakeRepo.mockPois = samplePois;

      bloc.add(ViewportCategoryFilterChanged('food', bounds: sampleBounds));

      await expectLater(
        bloc.stream,
        emitsThrough(
          ViewportSearchState(
            status: ViewportSearchStatus.success,
            pois: [samplePois[0]],
            bounds: sampleBounds,
            selectedCategory: 'food',
          ),
        ),
      );

      expect(bloc.currentCategory, equals('food'));
    });

    test('ClearViewportSearch resets state to initial', () async {
      fakeRepo.mockPois = samplePois;

      bloc.add(SearchInViewportRequested(sampleBounds));
      await expectLater(bloc.stream, emitsThrough(predicate<ViewportSearchState>((s) => s.isSuccess)));

      bloc.add(const ClearViewportSearch());
      await expectLater(bloc.stream, emits(const ViewportSearchState()));
      expect(bloc.currentCategory, equals(CategoryConstants.all));
    });

    test('Error during query emits status error', () async {
      fakeRepo.shouldThrow = true;

      final expectedStates = [
        ViewportSearchState(
          status: ViewportSearchStatus.loading,
          bounds: sampleBounds,
          selectedCategory: CategoryConstants.all,
        ),
        ViewportSearchState(
          status: ViewportSearchStatus.error,
          errorMessageKey: LocaleKeys.no_pois_in_viewport,
          bounds: sampleBounds,
        ),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(SearchInViewportRequested(sampleBounds));
    });
  });
}
