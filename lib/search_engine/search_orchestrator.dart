import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/search_result_ranker.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

import 'address/address.dart';
import 'fuzzy_matcher.dart';
import 'trie_index.dart';
import 'vn_phonetic_encoder.dart';

typedef SearchStageObserver = void Function(
  String stage,
  Duration elapsed,
  int resultCount,
);

class SearchOrchestrator {
  final IPoiRepository _poiRepository;
  final TrieIndex? _trieIndex;
  final Future<TrieIndex?>? _trieIndexFuture;
  final AddressParser _addressParser;
  TrieIndex? _loadedTrieIndex;
  Future<List<AdminUnitModel>>? _adminUnitsFuture;
  String? _provinceCacheKey;
  Future<String?>? _provinceCodeFuture;
  final SearchStageObserver? _onSearchStage;

  SearchOrchestrator({
    required IPoiRepository poiRepository,
    TrieIndex? trieIndex,
    Future<TrieIndex?>? trieIndexFuture,
    AddressParser? addressParser,
    SearchStageObserver? onSearchStage,
  })  : _poiRepository = poiRepository,
        _trieIndex = trieIndex,
        _trieIndexFuture = trieIndexFuture,
        _addressParser = addressParser ?? AddressParser.instance,
        _onSearchStage = onSearchStage;

  Future<List<PoiModel>> search({
    required String query,
    LatLng? userLocation,
    int limit = 20,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return const [];

    final adminUnits = await _resolveAdminUnits();
    final parsed = _addressParser.parse(
      cleanQuery,
      adminUnits: adminUnits,
    );
    final normalizedQuery = VnPhoneticEncoder.normalize(cleanQuery);
    final usefulResultCount = limit < 20 ? limit : 20;

    // === NHÁNH 1: CÓ Ý ĐỊNH ĐIỂM ĐẾN / PHẠM VI HÀNH CHÍNH CỤ THỂ ===
    if (parsed.isDestinationIntent) {
      final timer = Stopwatch()..start();
      final results = await _searchDestinationScoped(
        parsed: parsed,
        userLocation: userLocation,
        limit: limit,
      );
      _reportStage('address-scope', timer, results.length);
      return results;
    }

    // Stage 1: Search inside the user's province.
    final userProvinceCode = userLocation == null
        ? null
        : await _resolveProvinceNear(userLocation);
    final localProvinceResults = <PoiModel>[];
    if (userProvinceCode != null) {
      final timer = Stopwatch()..start();
      localProvinceResults.addAll(await _poiRepository.searchScoped(
        query: cleanQuery,
        provinceCode: userProvinceCode,
        limit: limit * 4,
      ));
      _reportStage('province', timer, localProvinceResults.length);
      final rankedProvince = SearchResultRanker.rank(
        localProvinceResults,
        center: userLocation,
        query: cleanQuery,
        limit: limit,
        maxDistanceKm: null,
      );
      if (rankedProvince.length >= usefulResultCount ||
          (normalizedQuery.length <= 2 && rankedProvince.isNotEmpty)) {
        return rankedProvince;
      }
    }

    // Stage 2: Search nearby and in the local trie before widening geography.
    final localTimer = Stopwatch()..start();
    final localCandidatesFuture = userLocation == null
        ? Future.value(const <PoiModel>[])
        : _searchNearbyCandidates(
            query: cleanQuery,
            center: userLocation,
            limit: limit < 100 ? 100 : limit * 4,
          );
    final trie = await _resolveTrie();
    final addressFallbackQuery = _withoutAddressNumber(cleanQuery);
    final phoneticQuery = VnPhoneticEncoder.encodePhonetic(cleanQuery);

    final trieIds = <int>[];
    if (trie != null && normalizedQuery.isNotEmpty) {
      trieIds.addAll(trie.prefixSearch(normalizedQuery, limit: limit * 2));
      if (trieIds.isEmpty) {
        final usePhoneticFallback = phoneticQuery != normalizedQuery;
        final fallbackTrie = usePhoneticFallback
            ? trie.phoneticTrie
            : trie.trie;
        final fallbackQuery = usePhoneticFallback
            ? phoneticQuery
            : normalizedQuery;
        if (fallbackTrie != null) {
          trieIds.addAll(FuzzyMatcher.fuzzyPrefixSearch(
            fallbackTrie,
            fallbackQuery,
            limit: limit * 2,
          ));
        }
      }
    }

    final relaxedTrieIds = <int>[];
    if (trie != null && addressFallbackQuery != null) {
      final normalizedFallbackQuery =
          VnPhoneticEncoder.normalize(addressFallbackQuery);
      if (normalizedFallbackQuery.isNotEmpty) {
        relaxedTrieIds.addAll(
          trie.prefixSearch(normalizedFallbackQuery, limit: limit * 2),
        );
      }
    }

    final allTrieIds = <int>{...trieIds, ...relaxedTrieIds}.toList();
    final triePoisFuture = _poiRepository.getPoisByIds(allTrieIds);
    final localCandidates = await localCandidatesFuture;
    final triePois = await triePoisFuture;

    final localResults = _uniquePois([
      ...localProvinceResults,
      ...localCandidates,
      ...triePois,
    ]);
    _reportStage('nearby-and-trie', localTimer, localResults.length);
    final rankedLocal = SearchResultRanker.rank(
      localResults,
      center: userLocation,
      query: cleanQuery,
      limit: limit,
      maxDistanceKm: userLocation == null
          ? null
          : SearchResultRanker.defaultNearbySearchRadiusKm,
    );

    if (rankedLocal.length >= usefulResultCount ||
        (normalizedQuery.length <= 2 && rankedLocal.isNotEmpty) ||
        (relaxedTrieIds.isNotEmpty && rankedLocal.isNotEmpty)) {
      return _prioritizeLocalResults(
        localResults: localProvinceResults,
        allResults: rankedLocal,
        center: userLocation,
        query: cleanQuery,
        limit: limit,
      );
    }

    // Stage 3: Expand to neighboring provinces only when local results are thin.
    final expandedProvinceResults = <PoiModel>[];
    if (userProvinceCode != null) {
      final neighborTimer = Stopwatch()..start();
      final neighborCodes = await _poiRepository.getNeighborProvinces(
        userProvinceCode,
      );
      for (final neighborCode in neighborCodes.take(4)) {
        expandedProvinceResults.addAll(await _poiRepository.searchScoped(
          query: cleanQuery,
          provinceCode: neighborCode,
          limit: limit * 2,
        ));
        final expandedResults = _uniquePois([
          ...localResults,
          ...expandedProvinceResults,
        ]);
        final rankedExpanded = SearchResultRanker.rank(
          expandedResults,
          center: userLocation,
          query: cleanQuery,
          limit: limit,
          maxDistanceKm: null,
        );
        if (rankedExpanded.length >= usefulResultCount) {
          _reportStage(
            'neighbor-provinces',
            neighborTimer,
            expandedProvinceResults.length,
          );
          return _prioritizeLocalResults(
            localResults: localProvinceResults,
            allResults: rankedExpanded,
            center: userLocation,
            query: cleanQuery,
            limit: limit,
          );
        }
      }
      _reportStage(
        'neighbor-provinces',
        neighborTimer,
        expandedProvinceResults.length,
      );
    }

    // Stage 4: Use the global index only if scoped and nearby results are thin.
    final globalTimer = Stopwatch()..start();
    final searches = await Future.wait([
      _poiRepository.search(cleanQuery, limit: limit * 2),
      if (addressFallbackQuery != null)
        _poiRepository.search(addressFallbackQuery, limit: limit * 2),
    ]);
    final deepResults = searches.first;
    final addressFallbackResults =
        addressFallbackQuery == null ? const <PoiModel>[] : searches.last;

    final merged = _uniquePois([
      ...localResults,
      ...expandedProvinceResults,
      ...deepResults,
      ...addressFallbackResults,
    ]);
    _reportStage(
      'global-index',
      globalTimer,
      deepResults.length + addressFallbackResults.length,
    );

    // Thử lọc bán kính local trước
    final localRanked = SearchResultRanker.rank(
      merged,
      center: userLocation,
      query: cleanQuery,
      limit: limit,
      maxDistanceKm: userLocation == null
          ? null
          : SearchResultRanker.defaultNearbySearchRadiusKm,
    );

    // Nếu không có kết quả trong bán kính 50km, mở rộng toàn quốc với Soft Decay
    if (localRanked.isEmpty && merged.isNotEmpty) {
      final rankedAll = SearchResultRanker.rank(
        merged,
        center: userLocation,
        query: cleanQuery,
        limit: limit,
        maxDistanceKm: null,
      );
      return _prioritizeLocalResults(
        localResults: localProvinceResults,
        allResults: rankedAll,
        center: userLocation,
        query: cleanQuery,
        limit: limit,
      );
    }

    return _prioritizeLocalResults(
      localResults: localProvinceResults,
      allResults: localRanked,
      center: userLocation,
      query: cleanQuery,
      limit: limit,
    );
  }

  /// Lightweight search-as-you-type path using local R*Tree and trie prefixes,
  /// without the full nearby-province expansion used by submit.
  Future<List<PoiModel>> searchAutocomplete({
    required String query,
    LatLng? userLocation,
    int limit = 20,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return const [];

    final totalTimer = Stopwatch()..start();
    DLog.searchTrace(
      '[SearchAutocomplete] orchestrator start '
      'query="$cleanQuery" hasLocation=${userLocation != null}',
    );
    final parseTimer = Stopwatch()..start();
    final adminUnits = await _resolveAdminUnits();
    final parsed = _addressParser.parse(cleanQuery, adminUnits: adminUnits);
    _reportStage('autocomplete-parse', parseTimer, adminUnits.length);
    DLog.searchTrace(
      '[SearchAutocomplete] parsed destination=${parsed.isDestinationIntent} '
      'hasProvince=${parsed.hasProvince} hasStreet=${parsed.hasStreet}',
    );
    if (!parsed.isDestinationIntent) {
      final results = await _searchAutocompleteName(
        cleanQuery,
        userLocation: userLocation,
        limit: limit,
      );
      DLog.searchTrace(
        '[SearchAutocomplete] orchestrator done '
        'results=${results.length} total=${totalTimer.elapsedMilliseconds}ms',
      );
      return results;
    }

    // Keep raw-name matches alongside scoped results: an admin alias can also
    // be part of a POI's proper name (for example, "Đại học Sài Gòn").
    final branches = await Future.wait([
      _searchDestinationScoped(
        parsed: parsed,
        userLocation: userLocation,
        limit: limit,
      ),
      _searchAutocompleteName(
        cleanQuery,
        userLocation: userLocation,
        limit: limit,
      ),
    ]);
    final addressResults = branches[0];
    final nameResults = branches[1];
    final results = SearchResultRanker.rank(
      _uniquePois([...addressResults, ...nameResults]),
      center: userLocation,
      query: cleanQuery,
      limit: limit,
      isDestinationQuery: parsed.isDestinationIntent,
    );
    DLog.searchTrace(
      '[SearchAutocomplete] destination branches '
      'scoped=${addressResults.length} name=${nameResults.length} '
      'merged=${results.length} total=${totalTimer.elapsedMilliseconds}ms',
    );
    return results;
  }

  Future<List<PoiModel>> _searchAutocompleteName(
    String query, {
    required LatLng? userLocation,
    required int limit,
  }) async {
    final localTimer = Stopwatch()..start();
    final provinceTimer = Stopwatch()..start();
    final provinceCode = userLocation == null
        ? null
        : await _resolveProvinceNear(userLocation);
    _reportStage('autocomplete-province-resolve', provinceTimer, provinceCode == null ? 0 : 1);
    DLog.searchTrace(
      '[SearchAutocomplete] local scope province=${provinceCode ?? "none"}',
    );
    final nearby = userLocation == null
        ? const <PoiModel>[]
        : await _poiRepository.searchByNameNear(
            query: query,
            latitude: userLocation.latitude,
            longitude: userLocation.longitude,
            provinceCode: provinceCode,
            limit: limit < 100 ? 100 : limit * 8,
          );
    _reportStage('autocomplete-r-tree', localTimer, nearby.length);

    // Keep local matches ahead of national trie matches. Ranking them together
    // can make a distant exact-name POI outrank a relevant nearby result.
    final rankedNearby = SearchResultRanker.rank(
      nearby,
      center: userLocation,
      query: query,
      limit: limit,
    );
    // A sufficient local result set is already more relevant than national
    // trie results. Return it now instead of blocking the keystroke on first
    // trie deserialization (which can take several seconds on-device).
    if (rankedNearby.length >= limit) {
      DLog.searchTrace(
        '[SearchAutocomplete] local results sufficient; skip trie '
        'count=${rankedNearby.length}',
      );
      return rankedNearby;
    }

    // A cheap B-tree prefix lookup gives exact full-name matches immediately
    // when the Android SQLite runtime has no FTS5 module. Scope it to the
    // user's province first, then expand nationally only when that is empty.
    final prefixTimer = Stopwatch()..start();
    final inProvincePrefix = provinceCode == null
        ? const <PoiModel>[]
        : await _poiRepository.searchByNamePrefix(
            query,
            limit: limit * 8,
            provinceCode: provinceCode,
          );
    final prefixCandidates = inProvincePrefix.isNotEmpty
        ? inProvincePrefix
        : await _poiRepository.searchByNamePrefix(query, limit: limit * 8);
    final rankedPrefix = SearchResultRanker.rank(
      _uniquePois([...nearby, ...prefixCandidates]),
      center: userLocation,
      query: query,
      limit: limit,
    );
    _reportStage('autocomplete-name-prefix', prefixTimer, prefixCandidates.length);
    if (rankedPrefix.isNotEmpty) {
      DLog.searchTrace(
        '[SearchAutocomplete] prefix matches available; skip trie '
        'count=${rankedPrefix.length} inProvince=${inProvincePrefix.length}',
      );
      return rankedPrefix;
    }

    final trieTimer = Stopwatch()..start();
    final trieResults = await _searchTrieAutocomplete(query, limit: limit);
    _reportStage('autocomplete-trie', trieTimer, trieResults.length);
    final provinceTrieResults = provinceCode == null
        ? trieResults
        : trieResults
            .where((poi) => poi.provinceCode == provinceCode)
            .toList(growable: false);

    final remainingLimit = limit - rankedPrefix.length;
    final rankedTrie = remainingLimit <= 0
        ? const <PoiModel>[]
        : SearchResultRanker.rank(
            provinceTrieResults,
            center: userLocation,
            query: query,
            limit: remainingLimit,
          );
    final prioritized = _uniquePois([...rankedPrefix, ...rankedTrie])
        .take(limit)
        .toList(growable: false);
    DLog.searchTrace(
      '[SearchAutocomplete] candidates local=${nearby.length} '
      'trie=${trieResults.length} provinceTrie=${provinceTrieResults.length} '
      'localRanked=${rankedNearby.length} prefixRanked=${rankedPrefix.length} '
      'trieRanked=${rankedTrie.length} emitted=${prioritized.length}',
    );
    if (prioritized.isNotEmpty) return prioritized;

    // Retain full-text global lookup for inputs the local and prefix indexes
    // cannot resolve, such as a distant or non-prefix place name.
    final globalTimer = Stopwatch()..start();
    final global = await _poiRepository.search(query, limit: limit);
    _reportStage('autocomplete-global-bm25', globalTimer, global.length);
    return SearchResultRanker.rank(
      global,
      center: userLocation,
      query: query,
      limit: limit,
    );
  }

  Future<List<PoiModel>> _searchTrieAutocomplete(
    String query, {
    required int limit,
  }) async {
    final trie = await _resolveTrie();
    if (trie == null) return const [];

    final normalizedQuery = VnPhoneticEncoder.normalize(query);
    if (normalizedQuery.isEmpty) return const [];

    var ids = trie.prefixSearch(normalizedQuery, limit: limit);
    if (ids.isEmpty && trie.phoneticTrie != null) {
      ids = trie.phoneticTrie!
          .prefixSearch(
            VnPhoneticEncoder.encodePhonetic(normalizedQuery),
            limit: limit,
          )
          .map((result) => result.poiId)
          .toList(growable: false);
    }
    return _poiRepository.getPoisByIds(ids);
  }

  Future<List<AdminUnitModel>> _resolveAdminUnits() {
    return _adminUnitsFuture ??= _poiRepository.getAdminUnits();
  }

  void _reportStage(String stage, Stopwatch timer, int resultCount) {
    timer.stop();
    try {
      DLog.searchTrace(
        '[SearchStage] $stage elapsed=${timer.elapsedMilliseconds}ms '
        'candidates=$resultCount',
      );
      _onSearchStage?.call(stage, timer.elapsed, resultCount);
    } catch (_) {
      // Profiling must never affect search results.
    }
  }

  Future<String?> _resolveProvinceNear(LatLng center) {
    final key =
        '${center.latitude.toStringAsFixed(3)}:${center.longitude.toStringAsFixed(3)}';
    if (_provinceCacheKey == key && _provinceCodeFuture != null) {
      return _provinceCodeFuture!;
    }
    _provinceCacheKey = key;
    return _provinceCodeFuture = _resolveProvinceNearUncached(center);
  }

  Future<String?> _resolveProvinceNearUncached(LatLng center) async {
    final bounds = MapConstants.boundsFromCenter(center, 8.0);
    final nearby = await _poiRepository.searchInBounds(
      minLat: bounds.southwest.latitude,
      maxLat: bounds.northeast.latitude,
      minLon: bounds.southwest.longitude,
      maxLon: bounds.northeast.longitude,
      limit: 40,
    );
    for (final poi in nearby) {
      final code = poi.provinceCode;
      if (code != null && code.isNotEmpty) return code;
    }
    return null;
  }

  List<PoiModel> _prioritizeLocalResults({
    required List<PoiModel> localResults,
    required List<PoiModel> allResults,
    required LatLng? center,
    required String query,
    required int limit,
  }) {
    final rankedLocal = SearchResultRanker.rank(
      localResults,
      center: center,
      query: query,
      limit: limit,
      maxDistanceKm: null,
    );
    if (rankedLocal.isEmpty) return allResults.take(limit).toList();

    final localIds = rankedLocal.map(_poiKey).toSet();
    final expanded = allResults.where((poi) => !localIds.contains(_poiKey(poi)));
    return [...rankedLocal, ...expanded].take(limit).toList();
  }

  List<PoiModel> _uniquePois(Iterable<PoiModel> pois) {
    final seen = <String>{};
    return pois.where((poi) => seen.add(_poiKey(poi))).toList();
  }

  String _poiKey(PoiModel poi) => poi.id != null
      ? 'id:${poi.id}'
      : '${poi.name}|${poi.lat}|${poi.lon}';

  /// Xử lý tìm kiếm điểm đến theo cấp độ hành chính (Hierarchical Scoped Cascading)
  Future<List<PoiModel>> _searchDestinationScoped({
    required ParsedAddress parsed,
    required LatLng? userLocation,
    required int limit,
  }) async {
    final merged = <PoiModel>[];
    final seen = <String>{};

    void addPois(Iterable<PoiModel> pois) {
      for (final poi in pois) {
        if (seen.add(_poiKey(poi))) merged.add(poi);
      }
    }

    // --- TIER 1: TÌM TRONG PHẠM VI TỈNH ĐÍCH (TARGET PROVINCE) ---
    // A. Tra cứu số nhà & tuyến đường trực tiếp nếu có
    if (parsed.hasStreet) {
      final streetTimer = Stopwatch()..start();
      final streets = await _poiRepository.findStreets(
        nameQuery: parsed.street!,
        provinceCode: parsed.provinceCode,
        districtCode: parsed.districtCode,
        limit: 3,
      );
      _reportStage('address-find-streets', streetTimer, streets.length);

      if (streets.isNotEmpty) {
        final primaryStreet = streets.first;
        final houseTimer = Stopwatch()..start();
        final houseMatches = await _poiRepository.findHouseNumbers(
          streetId: primaryStreet.id,
          targetHouseNo: parsed.houseNoMain,
          limit: 10,
        );
        _reportStage('address-find-houses', houseTimer, houseMatches.length);
        addPois(houseMatches);

        if (houseMatches.isEmpty) {
          addPois([
            PoiModel(
              id: -(1000000 + primaryStreet.id),
              name: primaryStreet.name,
              nameAscii: primaryStreet.nameCore,
              lat: primaryStreet.centerLat,
              lon: primaryStreet.centerLon,
              category: 'street',
              street: primaryStreet.name,
              city: parsed.provinceName,
            )
          ]);
        }
      }
    }

    // B. Scoped FTS trong tỉnh đích
    final targetFtsQuery = parsed.freeText.isNotEmpty
        ? parsed.freeText
        : parsed.rawQuery;
    final scopedTimer = Stopwatch()..start();
    final scopedResults = await _poiRepository.searchScoped(
      query: targetFtsQuery,
      provinceCode: parsed.provinceCode,
      districtCode: parsed.districtCode,
      limit: limit * 2,
    );
    _reportStage('address-scoped-fts', scopedTimer, scopedResults.length);
    addPois(scopedResults);

    // Nếu đã tìm thấy kết quả tại tỉnh đích, xếp hạng và trả về ngay
    if (merged.isNotEmpty) {
      return SearchResultRanker.rank(
        merged,
        center: userLocation,
        query: parsed.rawQuery,
        limit: limit,
        maxDistanceKm: null,
        isDestinationQuery: true,
      );
    }

    // An explicit province is a hard address constraint. Keep the last
    // fallback global so a parsing/index mismatch can still recover a result.
    if (merged.isEmpty) {
      final fallbackTimer = Stopwatch()..start();
      final globalFallback = await _poiRepository.search(
        parsed.rawQuery,
        limit: limit,
      );
      _reportStage('address-global-fallback', fallbackTimer, globalFallback.length);
      addPois(globalFallback);
    }

    return SearchResultRanker.rank(
      merged,
      center: userLocation,
      query: parsed.rawQuery,
      limit: limit,
      maxDistanceKm: null,
      isDestinationQuery: true,
    );
  }

  String? _withoutAddressNumber(String query) {
    final tokens = query.trim().split(RegExp(r'\s+'));
    if (!tokens.any((token) => RegExp(r'\d').hasMatch(token))) return null;

    final textTokens = tokens.where((token) {
      if (RegExp(r'\d').hasMatch(token)) return false;
      final normalized = VnPhoneticEncoder.normalize(token);
      return !const {'so', 'duong', 'pho', 'street', 'road', 'no', 'number'}
          .contains(normalized);
    }).toList(growable: false);
    return textTokens.isEmpty ? null : textTokens.join(' ');
  }

  Future<List<PoiModel>> _searchNearbyCandidates({
    required String query,
    required LatLng center,
    required int limit,
  }) {
    final bounds = MapConstants.boundsFromCenter(
      center,
      SearchResultRanker.defaultNearbySearchRadiusKm,
    );
    return _poiRepository.searchInBounds(
      minLat: bounds.southwest.latitude,
      maxLat: bounds.northeast.latitude,
      minLon: bounds.southwest.longitude,
      maxLon: bounds.northeast.longitude,
      query: query,
      limit: limit,
    );
  }

  Future<TrieIndex?> _resolveTrie() async {
    if (_trieIndex != null) return _trieIndex;
    if (_loadedTrieIndex != null) return _loadedTrieIndex;
    final future = _trieIndexFuture;
    if (future == null) return null;
    _loadedTrieIndex = await future;
    return _loadedTrieIndex;
  }
}
