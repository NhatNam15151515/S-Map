import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_map/services/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecentSearchServiceImpl Tests (SharedPreferences Fallback)', () {
    late RecentSearchServiceImpl service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = RecentSearchServiceImpl();
    });

    test('addRecentSearch deduplicates and puts newest query first', () async {
      await service.addRecentSearch('Hà Nội');
      await service.addRecentSearch('TP. Hồ Chí Minh');
      await service.addRecentSearch('hà nội');

      final list = await service.getRecentSearches();
      expect(list.length, equals(2));
      expect(list.first, equals('hà nội'));
      expect(list[1], equals('TP. Hồ Chí Minh'));
    });

    test('removeRecentSearch removes query case-insensitively', () async {
      await service.addRecentSearch('Đà Nẵng');
      await service.addRecentSearch('Huế');

      await service.removeRecentSearch('đà nẵng');
      final list = await service.getRecentSearches();
      expect(list.length, equals(1));
      expect(list.first, equals('Huế'));
    });

    test('clearRecentSearches removes all queries', () async {
      await service.addRecentSearch('Nha Trang');
      await service.addRecentSearch('Đà Lạt');

      await service.clearRecentSearches();
      final list = await service.getRecentSearches();
      expect(list, isEmpty);
    });

    test('ignores empty or whitespace queries', () async {
      await service.addRecentSearch('   ');
      await service.addRecentSearch('');

      final list = await service.getRecentSearches();
      expect(list, isEmpty);
    });
  });
}
