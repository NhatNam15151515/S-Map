import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class MockFailingFavoritesService implements IFavoritesService {
  @override
  Future<void> init() async {}

  @override
  Future<List<PoiModel>> getFavorites() async {
    throw Exception('Failed to load favorites');
  }

  @override
  Future<void> addFavorite(PoiModel poi) async {
    throw Exception('Failed to add favorite');
  }

  @override
  Future<void> removeFavorite(String poiId) async {
    throw Exception('Failed to remove favorite');
  }

  @override
  Future<bool> isFavorite(String poiId) async {
    throw Exception('Failed to check favorite');
  }

  @override
  Future<void> clearFavorites() async {
    throw Exception('Failed to clear favorites');
  }

  @override
  Stream<List<PoiModel>> watchFavorites() {
    throw Exception('Failed to watch favorites');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const poi1 = PoiModel(
    id: 101,
    name: 'Cà phê Giảng',
    nameAscii: 'Ca phe Giang',
    category: 'coffee',
    lat: 21.03,
    lon: 105.85,
    address: '39 Nguyễn Hữu Huân',
  );

  const poi2 = PoiModel(
    id: 102,
    osmId: 'node/12345',
    name: 'Bệnh viện Bạch Mai',
    nameAscii: 'Benh vien Bach Mai',
    category: 'hospital',
    lat: 20.99,
    lon: 105.84,
    address: '78 Giải Phóng',
  );

  group('FavoritesCubit Tests', () {
    late NoOpFavoritesService mockService;
    late FavoritesCubit cubit;

    setUp(() {
      mockService = NoOpFavoritesService();
      cubit = FavoritesCubit(favoritesService: mockService);
    });

    tearDown(() {
      cubit.close();
    });

    test('Initial state loads empty favorites successfully and helper getters work',
        () async {
      await Future.delayed(const Duration(milliseconds: 10));
      expect(cubit.state.status, equals(FavoritesStatus.success));
      expect(cubit.state.isSuccess, isTrue);
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.isError, isFalse);
      expect(cubit.state.favorites, isEmpty);
      expect(cubit.state.favoriteIds, isEmpty);
    });

    test('toggleFavorite adds POI when not in favorites', () async {
      await cubit.toggleFavorite(poi1);

      expect(cubit.state.favorites.length, equals(1));
      expect(cubit.state.favorites.first.name, equals('Cà phê Giảng'));
      expect(cubit.state.isFavorite('id:101'), isTrue);
      expect(cubit.state.favoriteIds.contains('id:101'), isTrue);
    });

    test('toggleFavorite removes POI when already in favorites', () async {
      await cubit.toggleFavorite(poi1);
      expect(cubit.state.isFavorite('id:101'), isTrue);

      await cubit.toggleFavorite(poi1);
      expect(cubit.state.isFavorite('id:101'), isFalse);
      expect(cubit.state.favorites, isEmpty);
      expect(cubit.state.favoriteIds, isEmpty);
    });

    test('removeFavorite removes correct POI by key', () async {
      await cubit.toggleFavorite(poi1);
      await cubit.toggleFavorite(poi2);
      expect(cubit.state.favorites.length, equals(2));

      await cubit.removeFavorite('id:101');
      expect(cubit.state.favorites.length, equals(1));
      expect(cubit.state.isFavorite('id:101'), isFalse);
      expect(cubit.state.isFavorite('id:102'), isTrue);
    });

    test('clearFavorites removes all favorites', () async {
      await cubit.toggleFavorite(poi1);
      await cubit.toggleFavorite(poi2);
      expect(cubit.state.favorites.length, equals(2));

      await cubit.clearFavorites();
      expect(cubit.state.favorites, isEmpty);
      expect(cubit.state.favoriteIds, isEmpty);
    });

    test('Handles service exceptions gracefully', () async {
      final failingCubit =
          FavoritesCubit(favoritesService: MockFailingFavoritesService());

      await Future.delayed(const Duration(milliseconds: 10));
      expect(failingCubit.state.status, equals(FavoritesStatus.error));
      expect(failingCubit.state.errorMessage, isNotNull);

      await failingCubit.toggleFavorite(poi1);
      expect(failingCubit.state.status, equals(FavoritesStatus.error));

      await failingCubit.close();
    });
  });
}
