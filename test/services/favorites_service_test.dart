import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testPoi = PoiModel(
    id: 99,
    name: 'Hồ Hoàn Kiếm',
    nameAscii: 'Ho Hoan Kiem',
    category: 'park',
    lat: 21.0285,
    lon: 105.8542,
    address: 'Hàng Trống, Hoàn Kiếm',
  );

  group('FavoritesService / Fallback Tests', () {
    late NoOpFavoritesService service;

    setUp(() {
      service = NoOpFavoritesService();
    });

    test('addFavorite, getFavorites, isFavorite, removeFavorite lifecycle',
        () async {
      expect(await service.getFavorites(), isEmpty);
      expect(await service.isFavorite('99'), isFalse);

      await service.addFavorite(testPoi);

      final list = await service.getFavorites();
      expect(list.length, equals(1));
      expect(list.first.name, equals('Hồ Hoàn Kiếm'));
      expect(await service.isFavorite('99'), isTrue);

      await service.removeFavorite('99');
      expect(await service.getFavorites(), isEmpty);
      expect(await service.isFavorite('99'), isFalse);
    });

    test('clearFavorites clears all records', () async {
      await service.addFavorite(testPoi);
      expect(await service.getFavorites(), isNotEmpty);

      await service.clearFavorites();
      expect(await service.getFavorites(), isEmpty);
    });

    test('watchFavorites stream emits updates', () async {
      final stream = service.watchFavorites();

      expectLater(
        stream,
        emitsInOrder([
          [testPoi],
          <PoiModel>[],
        ]),
      );

      await service.addFavorite(testPoi);
      await service.removeFavorite('99');
    });
  });
}
