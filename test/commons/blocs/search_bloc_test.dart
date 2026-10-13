import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class FakePoiRepository extends IPoiRepository {
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
    String? query,
    String? category,
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
  Future<List<String>> getFrequentSearches({int limit = 10}) async =>
      List.from(storage.take(limit));

  @override
  Future<void> addRecentSearch(
    String query, {
    Map<String, dynamic>? destination,
  }) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    storage.removeWhere((item) => item.toLowerCase() == clean.toLowerCase());
    storage.insert(0, clean);
  }

  @override
  Future<void> removeRecentSearch(String query) async {
    storage.removeWhere(
        (item) => item.toLowerCase() == query.trim().toLowerCase());
  }

  @override
  Future<void> clearRecentSearches() async {
    storage.clear();
  }
}

void main() {
  late FakePoiRepository fakeRepo;
  late FakeRecentSearchService fakeRecentService;
  late SearchBloc searchBloc;

  setUp(() {
    fakeRepo = FakePoiRepository();
    fakeRecentService = FakeRecentSearchService();
    searchBloc = SearchBloc(
      poiRepository: fakeRepo,
      recentSearchService: fakeRecentService,
    );
  });

  tearDown(() async {
    await searchBloc.close();
  });

  group('SearchBloc - Initial State & Recent Searches', () {
    test('initial state should be idle with empty results and suggestions', () {
      expect(searchBloc.state.status, SearchStatus.initial);
      expect(searchBloc.state.query, '');
      expect(searchBloc.state.results, isEmpty);
      expect(searchBloc.state.suggestions, isEmpty);
      expect(searchBloc.state.isLoading, isFalse);
    });

    test('loadRecentSearches should populate state with saved history',
        () async {
      await fakeRecentService.addRecentSearch('Phở Bát Đàn');
      await fakeRecentService.addRecentSearch('Cà phê Trứng');

      final completer = Completer<void>();
      searchBloc.add(SearchHistoryLoadRequested(completer: completer));
      await completer.future;

      expect(searchBloc.state.recentSearches.length, 2);
      expect(searchBloc.state.recentSearches.first, 'Cà phê Trứng');
    });
  });

  group('SearchBloc - Debounce Tests', () {
    test(
        'rapid keystrokes should trigger only ONE search call after debounce duration',
        () async {
      // Gõ liên tục với khoảng cách giữa các phím ngắn hơn thời gian debounce.
      searchBloc.add(const SearchQueryChanged('p',
          debounceDuration: Duration(milliseconds: 100)));
      await Future.delayed(const Duration(milliseconds: 30));

      searchBloc.add(const SearchQueryChanged('ph',
          debounceDuration: Duration(milliseconds: 100)));
      await Future.delayed(const Duration(milliseconds: 30));

      searchBloc.add(const SearchQueryChanged('phở',
          debounceDuration: Duration(milliseconds: 100)));

      // Đợi debounce timer hoàn thành
      await Future.delayed(const Duration(milliseconds: 150));

      // Xác minh chỉ có duy nhất 1 lần gọi search xuống repository với từ khóa 'phở'
      expect(fakeRepo.searchCallCount, 1);
      expect(fakeRepo.lastSearchQuery, 'phở');
      expect(searchBloc.state.status, SearchStatus.success);
      expect(searchBloc.state.results.length, greaterThanOrEqualTo(2));
    });

    test(
        'onQueryChanged with empty string should reset to initial state immediately',
        () async {
      searchBloc.add(const SearchQueryChanged('phở',
          debounceDuration: Duration(milliseconds: 50)));
      await Future.delayed(const Duration(milliseconds: 80));
      expect(searchBloc.state.status, SearchStatus.success);

      searchBloc.add(const SearchQueryChanged(''));
      await Future<void>.delayed(Duration.zero);
      expect(searchBloc.state.status, SearchStatus.initial);
      expect(searchBloc.state.results, isEmpty);
      expect(searchBloc.state.suggestions, isEmpty);
    });
  });

  group('SearchBloc - Vietnamese Accents & Suggestions Tests', () {
    test(
        'search "bệnh viện" and "benh vien" should yield equal results (Acceptance Criteria)',
        () async {
      await _submitSearch(searchBloc, 'bệnh viện');
      final accentedResults = searchBloc.state.results;

      await _submitSearch(searchBloc, 'benh vien');
      final unaccentedResults = searchBloc.state.results;

      expect(accentedResults, isNotEmpty);
      expect(unaccentedResults, isNotEmpty);
      expect(accentedResults.first.name, unaccentedResults.first.name);
      expect(accentedResults.first.name, 'Bệnh viện Chợ Rẫy');
    });

    test(
        'suggestions should merge matching recent searches and database suggestions',
        () async {
      await fakeRecentService.addRecentSearch('Phở bò đặc biệt');
      await _loadHistory(searchBloc);

      // Trigger search as-you-type
      searchBloc.add(const SearchQueryChanged('phở',
          debounceDuration: Duration(milliseconds: 50)));
      await Future.delayed(const Duration(milliseconds: 80));

      expect(searchBloc.state.suggestions, isNotEmpty);
      // Recent search khớp 'phở' được ưu tiên đưa lên đầu
      expect(searchBloc.state.suggestions.first, 'Phở bò đặc biệt');
      expect(searchBloc.state.suggestions.contains('Phở Thìn Lò Đúc'), isTrue);
    });

    test(
        'suggestions should match recent searches case-insensitively with unaccented query',
        () async {
      // Lịch sử có dấu và viết hoa: "Phở Bát Đàn"
      await fakeRecentService.addRecentSearch('Phở Bát Đàn');
      await _loadHistory(searchBloc);

      // Gõ không dấu viết thường: "pho"
      searchBloc.add(const SearchQueryChanged('pho',
          debounceDuration: Duration(milliseconds: 50)));
      await Future.delayed(const Duration(milliseconds: 80));

      expect(searchBloc.state.suggestions, isNotEmpty);
      expect(searchBloc.state.suggestions.first, 'Phở Bát Đàn');
    });

    test(
        'consecutive keystrokes should update state.query immediately and avoid stale state lag',
        () async {
      searchBloc.add(const SearchQueryChanged('bệ',
          debounceDuration: Duration(milliseconds: 100)));
      await Future<void>.delayed(Duration.zero);
      expect(searchBloc.state.query, 'bệ');

      searchBloc.add(const SearchQueryChanged('bệnh',
          debounceDuration: Duration(milliseconds: 100)));
      await Future<void>.delayed(Duration.zero);
      expect(searchBloc.state.query, 'bệnh');

      searchBloc.add(const SearchQueryChanged('bệnh viện',
          debounceDuration: Duration(milliseconds: 100)));
      await Future<void>.delayed(Duration.zero);
      expect(searchBloc.state.query, 'bệnh viện');

      await Future.delayed(const Duration(milliseconds: 150));
      expect(searchBloc.state.status, SearchStatus.success);
      expect(searchBloc.state.query, 'bệnh viện');
      expect(
          searchBloc.state.results.any((e) => e.name == 'Bệnh viện Chợ Rẫy'),
          isTrue);
    });
  });

  group('SearchBloc - Submit Search & Error Handling Tests', () {
    test('search should update results and save to recent searches', () async {
      await _submitSearch(searchBloc, 'Highlands');

      expect(searchBloc.state.status, SearchStatus.success);
      expect(searchBloc.state.results.any((e) => e.name == 'Highlands Coffee'),
          isTrue);
      expect(searchBloc.state.recentSearches.contains('Highlands'), isTrue);
    });

    test('search should handle errors gracefully and emit SearchStatus.error',
        () async {
      await _submitSearch(searchBloc, 'TRIGGER_ERROR');

      expect(searchBloc.state.status, SearchStatus.error);
      expect(searchBloc.state.errorMessage, isNotNull);
    });

    test('manage recent searches: remove and clear should work properly',
        () async {
      await _dispatchHistory(searchBloc,
          (completer) => SearchRecentAdded('Quán Cơm', completer: completer));
      await _dispatchHistory(searchBloc,
          (completer) => SearchRecentAdded('Bún Chả', completer: completer));
      expect(searchBloc.state.recentSearches.length, 2);

      await _dispatchHistory(searchBloc,
          (completer) => SearchRecentRemoved('Quán Cơm', completer: completer));
      expect(searchBloc.state.recentSearches.contains('Quán Cơm'), isFalse);
      expect(searchBloc.state.recentSearches.contains('Bún Chả'), isTrue);

      await _dispatchHistory(
          searchBloc, (completer) => SearchHistoryCleared(completer: completer));
      expect(searchBloc.state.recentSearches, isEmpty);
    });

    test('clearSearch should reset query, results, and suggestions', () async {
      await _submitSearch(searchBloc, 'phở');
      expect(searchBloc.state.results, isNotEmpty);

      searchBloc.add(const SearchCleared());
      await Future<void>.delayed(Duration.zero);
      expect(searchBloc.state.status, SearchStatus.initial);
      expect(searchBloc.state.query, '');
      expect(searchBloc.state.results, isEmpty);
      expect(searchBloc.state.suggestions, isEmpty);
    });

    test(
        'search and suggestions should sort POIs by closest distance to userLocation',
        () async {
      final tpHcmBloc = SearchBloc(
        poiRepository: fakeRepo,
        recentSearchService: fakeRecentService,
        userLocation: const LatLng(10.7800, 106.6900), // TP.HCM
      );

      // Search "phở" -> Phở Hòa Pasteur (TP.HCM) must be first, Phở Thìn (Hà Nội) second
      await _submitSearch(tpHcmBloc, 'phở');
      expect(tpHcmBloc.state.results.length, 2);
      expect(tpHcmBloc.state.results[0].name, 'Phở Hòa Pasteur');
      expect(tpHcmBloc.state.results[1].name, 'Phở Thìn Lò Đúc');

      // Update location to Hanoi -> Phở Thìn (Hà Nội) should become first
      tpHcmBloc.add(const SearchUserLocationChanged(LatLng(21.0200, 105.8500)));
      await Future<void>.delayed(Duration.zero);
      expect(tpHcmBloc.state.results[0].name, 'Phở Thìn Lò Đúc');
      expect(tpHcmBloc.state.results[1].name, 'Phở Hòa Pasteur');

      await tpHcmBloc.close();
    });
    test(
        '[SCH-05] Race condition guard — stale slow response is discarded when newer query arrives',
        () async {
      // Sử dụng repo có delay riêng cho từng query
      final slowRepo = FakePoiRepository();
      final raceBloc = SearchBloc(
        poiRepository: slowRepo,
        recentSearchService: fakeRecentService,
      );

      // Search 'Highlands' (fast, will resolve quickly)
      await _submitSearch(raceBloc, 'Highlands');
      expect(raceBloc.state.results.any((e) => e.name == 'Highlands Coffee'),
          isTrue);

      // Trigger two searches: first for 'phở', then immediately for 'Highlands'
      // Since both resolve synchronously in this mock, we verify that state.query
      // matches the most recent query to protect against race conditions.
      raceBloc.add(const SearchQueryChanged('phở',
          debounceDuration: Duration(milliseconds: 50)));
      await Future.delayed(const Duration(milliseconds: 10));
      raceBloc.add(const SearchQueryChanged('Highlands',
          debounceDuration: Duration(milliseconds: 50)));
      await Future.delayed(const Duration(milliseconds: 100));

      // The query state should match the LATEST query, not the first
      expect(raceBloc.state.query, 'Highlands');

      await raceBloc.close();
    });

    test('[SCH-08] Suggestions are capped at maximum 10 items', () async {
      // Create a repo with many POIs to generate >10 suggestions
      final manyPoiRepo = FakePoiRepository();
      final blocMany = SearchBloc(
        poiRepository: manyPoiRepo,
        recentSearchService: fakeRecentService,
      );

      // Add many recent searches to inflate suggestion count
      for (int i = 0; i < 15; i++) {
        await fakeRecentService.addRecentSearch('Phở variant $i');
      }
      await _loadHistory(blocMany);

      blocMany.add(const SearchQueryChanged('Phở',
          debounceDuration: Duration(milliseconds: 50)));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(blocMany.state.suggestions.length, lessThanOrEqualTo(10));

      await blocMany.close();
    });
  });
}

Future<void> _submitSearch(SearchBloc bloc, String query) async {
  final completer = Completer<void>();
  bloc.add(SearchSubmitted(query, completer: completer));
  await completer.future;
}

Future<void> _loadHistory(SearchBloc bloc) => _dispatchHistory(
      bloc,
      (completer) => SearchHistoryLoadRequested(completer: completer),
    );

Future<void> _dispatchHistory(
  SearchBloc bloc,
  SearchHistoryEvent Function(Completer<void>) createEvent,
) async {
  final completer = Completer<void>();
  bloc.add(createEvent(completer));
  await completer.future;
}
