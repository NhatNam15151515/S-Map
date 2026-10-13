part of 'poi_repository.dart';

mixin _PoiTextSearch on _PoiRepositoryCore {
  @override
  Future<List<PoiModel>> searchByNamePrefix(
    String query, {
    int limit = 80,
    String? provinceCode,
  }) async {
    if (!Validator.instance.isValidSearchQuery(query) || limit <= 0) {
      return const [];
    }
    final db = await _getDb();
    return _querySupport.searchNamePrefix(
      db,
      query,
      limit: limit,
      provinceCode: provinceCode,
    );
  }

  @override
  Future<List<PoiModel>> searchByName(String query, {int limit = 20}) async {
    if (!Validator.instance.isValidSearchQuery(query)) {
      return [];
    }

    final matchedSovereign = _querySupport.matchSovereignPois(query);
    final cleanQuery = _querySupport.sanitizeFtsQuery(query);
    if (cleanQuery.isEmpty) return matchedSovereign;

    final db = await _getDb();
    final words = cleanQuery
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final nameTerms = words.map((w) => '"$w"*').join(' AND ');
    final ftsPattern = words.length > 1
        ? '(name: "$cleanQuery"* OR name: ($nameTerms))'
        : 'name: "$cleanQuery"*';

    if (!await _querySupport.supportsFts5(db)) {
      final fallback = await _querySupport.searchNamePrefix(db, query, limit: limit);
      return [...matchedSovereign, ...fallback].take(limit).toList();
    }

    try {
      final List<Map<String, dynamic>> results = await db.rawQuery(
        '''
        SELECT p.*
        FROM poi_fts f
        JOIN poi p ON f.rowid = p.id
        WHERE poi_fts MATCH ?
        ORDER BY bm25(poi_fts) ASC
        LIMIT ?
        ''',
        [ftsPattern, limit],
      );

      final dbPois = results.map(PoiModel.fromMap).toList();
      return [...matchedSovereign, ...dbPois].take(limit).toList();
    } catch (error) {
      DLog.warning('[PoiSearch] FTS name query failed', error);
      final fallback = await _querySupport.searchNamePrefix(db, query, limit: limit);
      return [...matchedSovereign, ...fallback].take(limit).toList();
    }
  }

  @override
  Future<List<PoiModel>> searchByNameAscii(String query,
      {int limit = 20}) async {
    if (!Validator.instance.isValidSearchQuery(query)) {
      return [];
    }

    final matchedSovereign = _querySupport.matchSovereignPois(query);
    final asciiQuery = AppUtils.instance.toAscii(query);
    final cleanQuery = _querySupport.sanitizeFtsQuery(asciiQuery);
    if (cleanQuery.isEmpty) return matchedSovereign;

    final db = await _getDb();
    final words = cleanQuery
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final tokenPattern = words.map((w) => '"$w"*').join(' AND ');
    final ftsPattern = words.length > 1
        ? '(name_ascii: "$cleanQuery"* OR name_ascii: ($tokenPattern))'
        : 'name_ascii: "$cleanQuery"*';

    if (!await _querySupport.supportsFts5(db)) {
      final fallback = await _querySupport.searchNamePrefix(db, query, limit: limit);
      return [...matchedSovereign, ...fallback].take(limit).toList();
    }

    try {
      final List<Map<String, dynamic>> results = await db.rawQuery(
        '''
        SELECT p.*
        FROM poi_fts f
        JOIN poi p ON f.rowid = p.id
        WHERE poi_fts MATCH ?
        ORDER BY bm25(poi_fts) ASC
        LIMIT ?
        ''',
        [ftsPattern, limit],
      );

      final dbPois = results.map(PoiModel.fromMap).toList();
      return [...matchedSovereign, ...dbPois].take(limit).toList();
    } catch (error) {
      DLog.warning('[PoiSearch] FTS ASCII query failed', error);
      final fallback = await _querySupport.searchNamePrefix(db, query, limit: limit);
      return [...matchedSovereign, ...fallback].take(limit).toList();
    }
  }

  @override
  Future<List<PoiModel>> search(String query, {int limit = 20}) async {
    if (!Validator.instance.isValidSearchQuery(query)) {
      return [];
    }

    final cleanQuery = query.trim();
    if (!_cacheEnabled) {
      return _searchUncached(cleanQuery, limit: limit);
    }

    final key = _querySupport.searchCacheKey(cleanQuery, limit: limit);
    final cached = _searchCache.getPois(key, limit: limit);
    if (cached != null) {
      return cached;
    }

    final pending = _PoiRepositoryCore._inFlightSearches[key];
    if (pending != null) return List<PoiModel>.of(await pending);

    final future = _searchUncached(cleanQuery, limit: limit);
    _PoiRepositoryCore._inFlightSearches[key] = future;
    try {
      final results = await future;
      _searchCache.putPois(key, results);
      return results;
    } finally {
      if (identical(_PoiRepositoryCore._inFlightSearches[key], future)) {
        _PoiRepositoryCore._inFlightSearches.remove(key);
      }
    }
  }

  Future<List<PoiModel>> _searchUncached(
    String query, {
    required int limit,
  }) async {
    if (!Validator.instance.isValidSearchQuery(query)) {
      return [];
    }

    // Unified repository search is name-oriented. Address parsing and scoped
    // lookup live in SearchOrchestrator so autocomplete and submit share the
    // same interpretation of an unordered query.
    return Validator.instance.hasDiacritics(query)
        ? searchByName(query, limit: limit)
        : searchByNameAscii(query, limit: limit);
  }

}
