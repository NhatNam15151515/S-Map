part of 'poi_repository.dart';

mixin _PoiSuggestionSearch on _PoiRepositoryCore {
  @override
  Future<List<String>> getSuggestions(String query, {int limit = 10}) async {
    if (query.trim().isEmpty) return [];

    if (!_cacheEnabled) {
      return _getSuggestionsUncached(query, limit: limit);
    }

    final key = _querySupport.suggestionsCacheKey(query, limit: limit);
    final cached = _searchCache.getSuggestions(key, limit: limit);
    if (cached != null) return cached;

    final pending = _PoiRepositoryCore._inFlightSuggestions[key];
    if (pending != null) return List<String>.of(await pending);

    final future = _getSuggestionsUncached(query, limit: limit);
    _PoiRepositoryCore._inFlightSuggestions[key] = future;
    try {
      final results = await future;
      _searchCache.putSuggestions(key, results);
      return results;
    } finally {
      if (identical(_PoiRepositoryCore._inFlightSuggestions[key], future)) {
        _PoiRepositoryCore._inFlightSuggestions.remove(key);
      }
    }
  }

  Future<List<String>> _getSuggestionsUncached(
    String query, {
    required int limit,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final hasDiacritics = Validator.instance.hasDiacritics(trimmed);
    final cleanQuery = _querySupport.sanitizeFtsQuery(trimmed);
    if (cleanQuery.isEmpty) return [];

    final db = await _getDb();
    final cleanAscii = _querySupport.sanitizeFtsQuery(AppUtils.instance.toAscii(trimmed));
    final ftsPattern = hasDiacritics
        ? '(name: "$cleanQuery"* OR address: "$cleanQuery"*)'
        : '(name_ascii: "$cleanAscii"* OR admin_aliases: "$cleanAscii"*)';

    if (!await _querySupport.supportsFts5(db)) {
      final prefixRows = await _querySupport.searchNamePrefix(db, trimmed, limit: limit);
      return prefixRows
          .map((poi) => poi.name)
          .where((name) => name.isNotEmpty)
          .toSet()
          .take(limit)
          .toList(growable: false);
    }

    try {
      final List<Map<String, dynamic>> results = await db.rawQuery(
        '''
        SELECT DISTINCT p.name
        FROM poi_fts f
        JOIN poi p ON f.rowid = p.id
        WHERE poi_fts MATCH ?
        ORDER BY bm25(poi_fts) ASC
        LIMIT ?
        ''',
        [ftsPattern, limit],
      );

      return results
          .map((row) => row['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (error) {
      DLog.warning('[PoiSearch] FTS suggestion query failed', error);
      final prefixRows = await _querySupport.searchNamePrefix(db, trimmed, limit: limit);
      return prefixRows
          .map((poi) => poi.name)
          .where((name) => name.isNotEmpty)
          .toSet()
          .take(limit)
          .toList(growable: false);
    }
  }
}
