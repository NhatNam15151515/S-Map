import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/utils/search_result_ranker.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

import 'fuzzy_matcher.dart';
import 'trie_index.dart';
import 'vn_phonetic_encoder.dart';

class SearchOrchestrator {
  final IPoiRepository _poiRepository;
  final TrieIndex? _trieIndex;
  final Future<TrieIndex?>? _trieIndexFuture;
  TrieIndex? _loadedTrieIndex;

  SearchOrchestrator({
    required IPoiRepository poiRepository,
    TrieIndex? trieIndex,
    Future<TrieIndex?>? trieIndexFuture,
  })  : _poiRepository = poiRepository,
        _trieIndex = trieIndex,
        _trieIndexFuture = trieIndexFuture;

  Future<List<PoiModel>> search({
    required String query,
    LatLng? userLocation,
    int limit = 20,
  }) async {
    final trie = await _resolveTrie();
    final normalizedQuery = VnPhoneticEncoder.normalize(query);
    final addressFallbackQuery = _withoutAddressNumber(query);
    final phoneticQuery = VnPhoneticEncoder.encodePhonetic(query);
    final localCandidates = userLocation == null
        ? const <PoiModel>[]
        : await _searchNearbyCandidates(
            query: query,
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
    final rankedTrie = SearchResultRanker.rank(
      [...localCandidates, ...triePois],
      center: userLocation,
      query: query,
      limit: limit,
      maxDistanceKm: userLocation == null
          ? null
          : SearchResultRanker.defaultNearbySearchRadiusKm,
    );
    // 50 results are not needed to make autocomplete useful. Avoid a second,
    // much slower database search once the local index has enough candidates.
    final usefulResultCount = limit < 20 ? limit : 20;
    if (rankedTrie.length >= usefulResultCount ||
        (normalizedQuery.length <= 2 && rankedTrie.isNotEmpty) ||
        (relaxedTrieIds.isNotEmpty && rankedTrie.isNotEmpty)) {
      return rankedTrie;
    }

    // OSM address coverage is incomplete: a leading house number often has no
    // corresponding housenumber field. Retry by street/place name so the
    // number does not hide an otherwise useful result (e.g. "76 Tam Đảo").
    final searches = await Future.wait([
      _poiRepository.search(query, limit: limit * 2),
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
    return SearchResultRanker.rank(
      merged,
      center: userLocation,
      // Keep the original query for ranking: a real number + street match
      // should outrank the relaxed street/place fallback.
      query: query,
      limit: limit,
      maxDistanceKm: userLocation == null
          ? null
          : SearchResultRanker.defaultNearbySearchRadiusKm,
    );
  }

  String? _withoutAddressNumber(String query) {
    final tokens = query.trim().split(RegExp(r'\s+'));
    if (!tokens.any((token) => RegExp(r'\d').hasMatch(token))) return null;

    // Search the remaining words as either a street or place name. This also
    // handles "Tam Đảo 76" and common address prefixes such as "số 76 đường…".
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
