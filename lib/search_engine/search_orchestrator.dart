import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/utils/search_result_ranker.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

import 'address/address.dart';
import 'fuzzy_matcher.dart';
import 'trie_index.dart';
import 'vn_phonetic_encoder.dart';

class SearchOrchestrator {
  final IPoiRepository _poiRepository;
  final TrieIndex? _trieIndex;
  final Future<TrieIndex?>? _trieIndexFuture;
  final AddressParser _addressParser;
  TrieIndex? _loadedTrieIndex;

  SearchOrchestrator({
    required IPoiRepository poiRepository,
    TrieIndex? trieIndex,
    Future<TrieIndex?>? trieIndexFuture,
    AddressParser? addressParser,
  })  : _poiRepository = poiRepository,
        _trieIndex = trieIndex,
        _trieIndexFuture = trieIndexFuture,
        _addressParser = addressParser ?? AddressParser.instance;

  Future<List<PoiModel>> search({
    required String query,
    LatLng? userLocation,
    int limit = 20,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return const [];

    final parsed = _addressParser.parse(cleanQuery);
    final usefulResultCount = limit < 20 ? limit : 20;

    // === NHÁNH 1: CÓ Ý ĐỊNH ĐIỂM ĐẾN / PHẠM VI HÀNH CHÍNH CỤ THỂ ===
    if (parsed.isDestinationIntent && parsed.hasProvince) {
      return _searchDestinationScoped(
        parsed: parsed,
        userLocation: userLocation,
        limit: limit,
        usefulResultCount: usefulResultCount,
      );
    }

    // === NHÁNH 2: TÌM KIẾM TỰ DO / CỤC BỘ (LOCAL-FIRST) ===
    final trie = await _resolveTrie();
    final normalizedQuery = VnPhoneticEncoder.normalize(cleanQuery);
    final addressFallbackQuery = _withoutAddressNumber(cleanQuery);
    final phoneticQuery = VnPhoneticEncoder.encodePhonetic(cleanQuery);

    final localCandidates = userLocation == null
        ? const <PoiModel>[]
        : await _searchNearbyCandidates(
            query: cleanQuery,
            center: userLocation,
            limit: limit < 100 ? 100 : limit * 4,
          );

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
    final triePois = await _poiRepository.getPoisByIds(allTrieIds);

    // Ưu tiên xếp hạng trong bán kính cục bộ trước
    final rankedLocal = SearchResultRanker.rank(
      [...localCandidates, ...triePois],
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
      return rankedLocal;
    }

    // Nếu kết quả cục bộ chưa đủ, tìm kiếm sâu trong CSDL POI
    final searches = await Future.wait([
      _poiRepository.search(cleanQuery, limit: limit * 2),
      if (addressFallbackQuery != null)
        _poiRepository.search(addressFallbackQuery, limit: limit * 2),
    ]);
    final deepResults = searches.first;
    final addressFallbackResults =
        addressFallbackQuery == null ? const <PoiModel>[] : searches.last;

    final merged = <PoiModel>[];
    final seen = <String>{};
    for (final poi in [
      ...localCandidates,
      ...triePois,
      ...deepResults,
      ...addressFallbackResults,
    ]) {
      final key = poi.id != null
          ? 'id:${poi.id}'
          : '${poi.name}|${poi.lat}|${poi.lon}';
      if (seen.add(key)) merged.add(poi);
    }

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
      return SearchResultRanker.rank(
        merged,
        center: userLocation,
        query: cleanQuery,
        limit: limit,
        maxDistanceKm: null,
      );
    }

    return localRanked;
  }

  /// Xử lý tìm kiếm điểm đến theo cấp độ hành chính (Hierarchical Scoped Cascading)
  Future<List<PoiModel>> _searchDestinationScoped({
    required ParsedAddress parsed,
    required LatLng? userLocation,
    required int limit,
    required int usefulResultCount,
  }) async {
    final merged = <PoiModel>[];
    final seen = <String>{};

    void addPois(Iterable<PoiModel> pois) {
      for (final poi in pois) {
        final key = poi.id != null
            ? 'id:${poi.id}'
            : '${poi.name}|${poi.lat}|${poi.lon}';
        if (seen.add(key)) merged.add(poi);
      }
    }

    // --- TIER 1: TÌM TRONG PHẠM VI TỈNH ĐÍCH (TARGET PROVINCE) ---
    // A. Tra cứu số nhà & tuyến đường trực tiếp nếu có
    if (parsed.hasStreet) {
      final streets = await _poiRepository.findStreets(
        nameQuery: parsed.street!,
        provinceCode: parsed.provinceCode,
        districtCode: parsed.districtCode,
        limit: 3,
      );

      if (streets.isNotEmpty) {
        final primaryStreet = streets.first;
        final houseMatches = await _poiRepository.findHouseNumbers(
          streetId: primaryStreet.id,
          targetHouseNo: parsed.houseNoMain,
          limit: 10,
        );
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
    final targetFtsQuery = parsed.freeText.isNotEmpty ? parsed.freeText : parsed.rawQuery;
    final scopedResults = await _poiRepository.searchScoped(
      query: targetFtsQuery,
      provinceCode: parsed.provinceCode,
      districtCode: parsed.districtCode,
      limit: limit * 2,
    );
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

    // --- TIER 2: MỞ RỘNG RA CÁC TỈNH LÁNG GIỀNG KHI TỈNH ĐÍCH CHƯA CÓ KẾT QUẢ ---
    final neighbors = await _poiRepository.getNeighborProvinces(parsed.provinceCode!);
    for (final neighborCode in neighbors.take(4)) {
      final neighborResults = await _poiRepository.searchScoped(
        query: targetFtsQuery,
        provinceCode: neighborCode,
        limit: limit,
      );
      addPois(neighborResults);
      if (merged.isNotEmpty) break;
    }

    // --- TIER 3: DỰ PHÒNG TOÀN QUỐC (NATIONAL FALLBACK) ---
    if (merged.isEmpty) {
      final globalFallback = await _poiRepository.search(targetFtsQuery, limit: limit);
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
