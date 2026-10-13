part of 'poi_repository.dart';

mixin _PoiNearSearch on _PoiRepositoryCore {
  @override
  Future<List<PoiModel>> searchByNameNear({
    required String query,
    required double latitude,
    required double longitude,
    String? provinceCode,
    int limit = 160,
  }) async {
    if (!Validator.instance.isValidSearchQuery(query) || limit <= 0) {
      return const [];
    }

    final matchedSovereign = _querySupport.matchSovereignPois(query);
    final hasDiacritics = Validator.instance.hasDiacritics(query);
    final normalizedQuery = hasDiacritics
        ? query
        : AppUtils.instance.toAscii(query);
    final cleanQuery = _querySupport.sanitizeFtsQuery(normalizedQuery);
    if (cleanQuery.isEmpty) return matchedSovereign;

    final words = cleanQuery
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    final column = hasDiacritics ? 'name' : 'name_ascii';
    final tokenPattern = words.map((word) => '"$word"*').join(' AND ');
    final ftsPattern = words.length > 1
        ? '($column: "$cleanQuery"* OR $column: ($tokenPattern))'
        : '$column: "$cleanQuery"*';
    final scopedFtsPattern = provinceCode == null || provinceCode.isEmpty
        ? ftsPattern
        : '(scope: p$provinceCode) AND ($ftsPattern)';

    const radiusKm = 25.0;
    const latitudeDelta = radiusKm / 111.0;
    final longitudeScale = math.cos(latitude * math.pi / 180.0).abs();
    final longitudeDelta =
        radiusKm / (111.0 * math.max(longitudeScale, 0.01));
    final db = await _getDb();

    if (!await _querySupport.supportsFts5(db)) {
      return _searchNameNearWithoutFts(
        db,
        query: query,
        latitude: latitude,
        longitude: longitude,
        provinceCode: provinceCode,
        limit: limit,
        matchedSovereign: matchedSovereign,
      );
    }

    try {
      final queryTimer = Stopwatch()..start();
      final rows = await db.rawQuery(
        '''
        SELECT p.*
        FROM poi_fts f
        JOIN poi p ON p.id = f.rowid
        JOIN poi_rtree r ON r.id = p.id
        WHERE poi_fts MATCH ?
          AND r.min_lat BETWEEN ? AND ?
          AND r.min_lon BETWEEN ? AND ?
        LIMIT ?
        ''',
        [
          scopedFtsPattern,
          latitude - latitudeDelta,
          latitude + latitudeDelta,
          longitude - longitudeDelta,
          longitude + longitudeDelta,
          limit,
        ],
      );
      DLog.searchTrace(
        '[PoiSearch] local-fts-rtree elapsed='
        '${queryTimer.elapsedMilliseconds}ms rows=${rows.length} '
        'radius=${radiusKm.toInt()}km',
      );
      final dbPois = rows.map(PoiModel.fromMap).toList(growable: false);
      return [...matchedSovereign, ...dbPois].take(limit).toList();
    } catch (error) {
      DLog.warning('[PoiSearch] local FTS/R*Tree query failed', error);
      return _searchNameNearWithoutFts(
        db,
        query: query,
        latitude: latitude,
        longitude: longitude,
        provinceCode: provinceCode,
        limit: limit,
        matchedSovereign: matchedSovereign,
      );
    }
  }

  Future<List<PoiModel>> _searchNameNearWithoutFts(
    Database db, {
    required String query,
    required double latitude,
    required double longitude,
    String? provinceCode,
    required int limit,
    required List<PoiModel> matchedSovereign,
  }) async {
    const radiusKm = 25.0;
    const latitudeDelta = radiusKm / 111.0;
    final longitudeDelta = radiusKm /
        (111.0 * math.max(math.cos(latitude * math.pi / 180.0).abs(), 0.01));
    final lat = latitude.toStringAsFixed(8);
    final lon = longitude.toStringAsFixed(8);
    final timer = Stopwatch()..start();
    final scopeClause = provinceCode == null || provinceCode.isEmpty
        ? ''
        : ' AND p.province_code = ?';
    final arguments = <Object?>[
      latitude - latitudeDelta,
      latitude + latitudeDelta,
      longitude - longitudeDelta,
      longitude + longitudeDelta,
    ];
    if (scopeClause.isNotEmpty) arguments.add(provinceCode);
    arguments.add(3000);
    final rows = await db.rawQuery(
      '''
      SELECT p.*
      FROM poi p
      WHERE p.lat BETWEEN ? AND ?
        AND p.lon BETWEEN ? AND ?
        $scopeClause
      ORDER BY ((p.lat - $lat) * (p.lat - $lat) +
                (p.lon - $lon) * (p.lon - $lon)) ASC
      LIMIT ?
      ''',
      arguments,
    );
    final tokenSplitter = RegExp(r'[^a-z0-9À-ỹ]+', caseSensitive: false);
    final tokens = query
        .toLowerCase()
        .split(tokenSplitter)
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    final normalizedAsciiQuery =
        AppUtils.instance.toAscii(query).toLowerCase().trim();
    final matched = <(PoiModel poi, int textScore, double distanceScore)>[];
    for (final row in rows) {
      final poi = PoiModel.fromMap(row);
      final accentNameTokens = poi.name.toLowerCase().split(tokenSplitter);
      final asciiName = poi.nameAscii.toLowerCase();
      final asciiNameTokens = asciiName.split(tokenSplitter);
      final matches = tokens.every((token) {
        final nameTokens = Validator.instance.hasDiacritics(token)
            ? accentNameTokens
            : asciiNameTokens;
        return nameTokens.any((nameToken) => nameToken.startsWith(token));
      });
      if (!matches) continue;
      final textScore = asciiName == normalizedAsciiQuery
          ? 3
          : asciiName.startsWith(normalizedAsciiQuery)
              ? 2
              : 1;
      final distanceLat = poi.lat - latitude;
      final distanceLon = poi.lon - longitude;
      matched.add((
        poi,
        textScore,
        distanceLat * distanceLat + distanceLon * distanceLon,
      ));
    }
    matched.sort((a, b) {
      final textComparison = b.$2.compareTo(a.$2);
      if (textComparison != 0) return textComparison;
      final prominenceComparison = b.$1.prominence.compareTo(a.$1.prominence);
      if (prominenceComparison != 0) return prominenceComparison;
      return a.$3.compareTo(b.$3);
    });
    DLog.searchTrace(
      '[PoiSearch] local-bbox-text elapsed=${timer.elapsedMilliseconds}ms '
      'scanned=${rows.length} matched=${matched.length}',
    );
    return [
      ...matchedSovereign,
      ...matched.take(limit).map((candidate) => candidate.$1),
    ].take(limit).toList();
  }
}
