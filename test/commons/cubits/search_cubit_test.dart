import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/cubits/search_cubit/search_cubit.dart';
import 'package:s_map/commons/cubits/search_cubit/search_state.dart';
import 'package:s_map/interfaces/i_poi_repository.dart';
import 'package:s_map/interfaces/i_recent_search_service.dart';
import 'package:s_map/models/poi_model.dart';

class FakePoiRepository implements IPoiRepository {
  int searchCallCount = 0;
  String? lastSearchQuery;

  final List<PoiModel> mockPois = const [
    PoiModel(
      id: 1,
      name: 'Bệnh viện Chợ Rẫy',
      nameAscii: 'benh vien cho ray',
      category: 'hospital',
      lat: 10.7554,
      lon: 106.6596,
      address: '201B Nguyễn Chí Thanh, Quận 5, TP.HCM',
    ),
    PoiModel(
      id: 2,
      name: 'Phở Thìn Lò Đúc',
      nameAscii: 'pho thin lo duc',
      category: 'food',
      lat: 21.0175,
      lon: 105.8562,
      address: '13 Lò Đúc, Hà Nội',
    ),
    PoiModel(
      id: 3,
      name: 'Phở Hòa Pasteur',
      nameAscii: 'pho hoa pasteur',
      category: 'food',
      lat: 10.7892,
      lon: 106.6897,
      address: '260C Pasteur, Quận 3, TP.HCM',
    ),
    PoiModel(
      id: 4,
      name: 'Highlands Coffee',
      nameAscii: 'highlands coffee',
      category: 'coffee',
      lat: 10.7761,
      lon: 106.7012,
      address: 'Quận 1, TP.HCM',
    ),
  ];

  @override
  Future<List<PoiModel>> search(String query, {int limit = 20}) async {
    searchCallCount++;
    lastSearchQuery = query;

    if (query == 'TRIGGER_ERROR') {
      throw Exception('Database query failure');
    }

    final lower = query.toLowerCase();
    return mockPois.where((poi) {
      return poi.name.toLowerCase().contains(lower) ||
          poi.nameAscii.toLowerCase().contains(lower);
    }).toList();
  }

  @override
  Future<List<PoiModel>> searchByName(String query, {int limit = 20}) =>
      search(query, limit: limit);

  @override
  Future<List<PoiModel>> searchByNameAscii(String query, {int limit = 20}) =>
      search(query, limit: limit);

  @override
  Future<List<String>> getSuggestions(String query, {int limit = 10}) async {
    final lower = query.toLowerCase();
    return mockPois
        .where((poi) =>
            poi.name.toLowerCase().contains(lower) ||
            poi.nameAscii.toLowerCase().contains(lower))
        .map((e) => e.name)
        .toList();
  }

  @override
  Future<List<PoiModel>> searchInBounds({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    int limit = 50,
  }) async =>
      mockPois;

  @override
  Future<PoiModel?> getPoiById(int id) async {
    try {
      return mockPois.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}

class FakeRecentSearchService implements IRecentSearchService {
  final List<String> storage = [];

  @override
  Future<List<String>> getRecentSearches() async => List.from(storage);

  @override
  Future<void> addRecentSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    storage.removeWhere((item) => item.toLowerCase() == clean.toLowerCase());
    storage.insert(0, clean);
  }

  @override
  Future<void> removeRecentSearch(String query) async {
    storage.removeWhere((item) => item.toLowerCase() == query.trim().toLowerCase());
  }

  @override
  Future<void> clearRecentSearches() async {
    storage.clear();
  }
}

void main() {
  late FakePoiRepository fakeRepo;
  late FakeRecentSearchService fakeRecentService;
  late SearchCubit searchCubit;

  setUp(() {
    fakeRepo = FakePoiRepository();
    fakeRecentService = FakeRecentSearchService();
    searchCubit = SearchCubit(
      poiRepository: fakeRepo,
      recentSearchService: fakeRecentService,
    );
  });

  tearDown(() async {
    await searchCubit.close();
  });

  group('SearchCubit - Initial State & Recent Searches', () {
    test('initial state should be idle with empty results and suggestions', () {
      expect(searchCubit.state.status, SearchStatus.initial);
      expect(searchCubit.state.query, '');
      expect(searchCubit.state.results, isEmpty);
      expect(searchCubit.state.suggestions, isEmpty);
      expect(searchCubit.state.isLoading, isFalse);
    });

    test('loadRecentSearches should populate state with saved history', () async {
      await fakeRecentService.addRecentSearch('Phở Bát Đàn');
      await fakeRecentService.addRecentSearch('Cà phê Trứng');

      await searchCubit.loadRecentSearches();

      expect(searchCubit.state.recentSearches.length, 2);
      expect(searchCubit.state.recentSearches.first, 'Cà phê Trứng');
    });
  });

  group('SearchCubit - Debounce 300ms Tests', () {
    test('rapid keystrokes should trigger only ONE search call after debounce duration', () async {
      // Giả lập người dùng gõ liên tục: 'p' -> 'ph' -> 'phở' với khoảng cách 50ms < 300ms
      searchCubit.onQueryChanged('p', debounceDuration: const Duration(milliseconds: 100));
      await Future.delayed(const Duration(milliseconds: 30));

      searchCubit.onQueryChanged('ph', debounceDuration: const Duration(milliseconds: 100));
      await Future.delayed(const Duration(milliseconds: 30));

      searchCubit.onQueryChanged('phở', debounceDuration: const Duration(milliseconds: 100));

      // Đợi debounce timer hoàn thành
      await Future.delayed(const Duration(milliseconds: 150));

      // Xác minh chỉ có duy nhất 1 lần gọi search xuống repository với từ khóa 'phở'
      expect(fakeRepo.searchCallCount, 1);
      expect(fakeRepo.lastSearchQuery, 'phở');
      expect(searchCubit.state.status, SearchStatus.success);
      expect(searchCubit.state.results.length, greaterThanOrEqualTo(2));
    });

    test('onQueryChanged with empty string should reset to initial state immediately', () async {
      searchCubit.onQueryChanged('phở', debounceDuration: const Duration(milliseconds: 50));
      await Future.delayed(const Duration(milliseconds: 80));
      expect(searchCubit.state.status, SearchStatus.success);

      searchCubit.onQueryChanged('');
      expect(searchCubit.state.status, SearchStatus.initial);
      expect(searchCubit.state.results, isEmpty);
      expect(searchCubit.state.suggestions, isEmpty);
    });
  });

  group('SearchCubit - Vietnamese Accents & Suggestions Tests', () {
    test('search "bệnh viện" and "benh vien" should yield equal results (Acceptance Criteria)', () async {
      await searchCubit.search('bệnh viện');
      final accentedResults = searchCubit.state.results;

      await searchCubit.search('benh vien');
      final unaccentedResults = searchCubit.state.results;

      expect(accentedResults, isNotEmpty);
      expect(unaccentedResults, isNotEmpty);
      expect(accentedResults.first.name, unaccentedResults.first.name);
      expect(accentedResults.first.name, 'Bệnh viện Chợ Rẫy');
    });

    test('suggestions should merge matching recent searches and database suggestions', () async {
      await fakeRecentService.addRecentSearch('Phở bò đặc biệt');
      await searchCubit.loadRecentSearches();

      // Trigger search as-you-type
      searchCubit.onQueryChanged('phở', debounceDuration: const Duration(milliseconds: 50));
      await Future.delayed(const Duration(milliseconds: 80));

      expect(searchCubit.state.suggestions, isNotEmpty);
      // Recent search khớp 'phở' được ưu tiên đưa lên đầu
      expect(searchCubit.state.suggestions.first, 'Phở bò đặc biệt');
      expect(searchCubit.state.suggestions.contains('Phở Thìn Lò Đúc'), isTrue);
    });

    test('suggestions should match recent searches case-insensitively with unaccented query', () async {
      // Lịch sử có dấu và viết hoa: "Phở Bát Đàn"
      await fakeRecentService.addRecentSearch('Phở Bát Đàn');
      await searchCubit.loadRecentSearches();

      // Gõ không dấu viết thường: "pho"
      searchCubit.onQueryChanged('pho', debounceDuration: const Duration(milliseconds: 50));
      await Future.delayed(const Duration(milliseconds: 80));

      expect(searchCubit.state.suggestions, isNotEmpty);
      expect(searchCubit.state.suggestions.first, 'Phở Bát Đàn');
    });

    test('consecutive keystrokes should update state.query immediately and avoid stale state lag', () async {
      searchCubit.onQueryChanged('bệ', debounceDuration: const Duration(milliseconds: 100));
      expect(searchCubit.state.query, 'bệ');

      searchCubit.onQueryChanged('bệnh', debounceDuration: const Duration(milliseconds: 100));
      expect(searchCubit.state.query, 'bệnh');

      searchCubit.onQueryChanged('bệnh viện', debounceDuration: const Duration(milliseconds: 100));
      expect(searchCubit.state.query, 'bệnh viện');

      await Future.delayed(const Duration(milliseconds: 150));
      expect(searchCubit.state.status, SearchStatus.success);
      expect(searchCubit.state.query, 'bệnh viện');
      expect(searchCubit.state.results.any((e) => e.name == 'Bệnh viện Chợ Rẫy'), isTrue);
    });
  });

  group('SearchCubit - Submit Search & Error Handling Tests', () {
    test('search should update results and save to recent searches', () async {
      await searchCubit.search('Highlands');

      expect(searchCubit.state.status, SearchStatus.success);
      expect(searchCubit.state.results.any((e) => e.name == 'Highlands Coffee'), isTrue);
      expect(searchCubit.state.recentSearches.contains('Highlands'), isTrue);
    });

    test('search should handle errors gracefully and emit SearchStatus.error', () async {
      await searchCubit.search('TRIGGER_ERROR');

      expect(searchCubit.state.status, SearchStatus.error);
      expect(searchCubit.state.errorMessage, isNotNull);
    });

    test('manage recent searches: remove and clear should work properly', () async {
      await searchCubit.addRecentSearch('Quán Cơm');
      await searchCubit.addRecentSearch('Bún Chả');
      expect(searchCubit.state.recentSearches.length, 2);

      await searchCubit.removeRecentSearch('Quán Cơm');
      expect(searchCubit.state.recentSearches.contains('Quán Cơm'), isFalse);
      expect(searchCubit.state.recentSearches.contains('Bún Chả'), isTrue);

      await searchCubit.clearRecentSearches();
      expect(searchCubit.state.recentSearches, isEmpty);
    });

    test('clearSearch should reset query, results, and suggestions', () async {
      await searchCubit.search('phở');
      expect(searchCubit.state.results, isNotEmpty);

      searchCubit.clearSearch();
      expect(searchCubit.state.status, SearchStatus.initial);
      expect(searchCubit.state.query, '');
      expect(searchCubit.state.results, isEmpty);
      expect(searchCubit.state.suggestions, isEmpty);
    });
  });
}
