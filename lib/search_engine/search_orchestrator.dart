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

    final triePois = await _poiRepository.getPoisByIds(trieIds);
    final rankedTrie = SearchResultRanker.rank(
      [...localCandidates, ...triePois],
      center: userLocation,
      query: query,
      limit: limit,
      maxDistanceKm: userLocation == null
          ? null
          : SearchResultRanker.defaultNearbySearchRadiusKm,
    );
    if (rankedTrie.length >= limit ||
        (normalizedQuery.length <= 2 && rankedTrie.isNotEmpty)) {
      return rankedTrie;
    }

    final deepResults = await _poiRepository.search(query, limit: limit * 2);
    final merged = <PoiModel>[];
    final seen = <String>{};
    for (final poi in [...localCandidates, ...triePois, ...deepResults]) {
      final key = poi.id != null
          ? 'id:${poi.id}'
          : '${poi.name}|${poi.lat}|${poi.lon}';
      if (seen.add(key)) merged.add(poi);
    }
    return SearchResultRanker.rank(
      merged,
      center: userLocation,
      query: query,
      limit: limit,
      maxDistanceKm: userLocation == null
          ? null
          : SearchResultRanker.defaultNearbySearchRadiusKm,
    );
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
