part of 'poi_repository.dart';

mixin _PoiSpatialSearch on _PoiRepositoryCore {
  @override
  Future<List<PoiModel>> searchInBounds({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    String? query,
    String? category,
    int limit = 50,
  }) async {
    if (!_cacheEnabled) {
      return _searchInBoundsUncached(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
        query: query,
        category: category,
        limit: limit,
      );
    }

    final key = _querySupport.boundsSearchCacheKey(
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
      query: query,
      category: category,
      limit: limit,
    );
    final cached = _searchCache.getPois(key, limit: limit);
    if (cached != null) return cached;

    final pending = _PoiRepositoryCore._inFlightBoundsSearches[key];
    if (pending != null) return List<PoiModel>.of(await pending);

    final future = _searchInBoundsUncached(
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
      query: query,
      category: category,
      limit: limit,
    );
    _PoiRepositoryCore._inFlightBoundsSearches[key] = future;
    try {
      final results = await future;
      _searchCache.putPois(key, results);
      return results;
    } finally {
      if (identical(_PoiRepositoryCore._inFlightBoundsSearches[key], future)) {
        _PoiRepositoryCore._inFlightBoundsSearches.remove(key);
      }
    }
  }

  Future<List<PoiModel>> _searchInBoundsUncached({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    String? query,
    String? category,
    int limit = 50,
  }) async {
    final db = await _getDb();
    final cleanQuery = query != null ? _querySupport.sanitizeFtsQuery(query) : '';
    final cleanAscii = cleanQuery.isNotEmpty
        ? _querySupport.sanitizeFtsQuery(AppUtils.instance.toAscii(cleanQuery))
        : '';
    final hasCategory = category != null &&
        category.trim().isNotEmpty &&
        category.trim().toLowerCase() != 'all';
    final cleanCategory = hasCategory ? category.trim().toLowerCase() : '';

    final whereClauses = <String>[
      'r.min_lat <= ? AND r.max_lat >= ?',
      'r.min_lon <= ? AND r.max_lon >= ?',
    ];
    final whereArgs = <dynamic>[maxLat, minLat, maxLon, minLon];
    // Không để SQLite trả về 50 dòng đầu theo thứ tự vật lý của DB. Dữ liệu
    // OSM thường được ghi theo từng khu vực, nên cách đó có thể làm toàn bộ
    // kết quả dồn về một phía dù trong bbox còn nhiều POI gần tâm hơn.
    // Đây là khoảng cách xấp xỉ để chọn candidate; SearchResultRanker sẽ
    // tính lại khoảng cách địa lý chính xác ở lớp orchestration.
    final centerLat = ((minLat + maxLat) / 2).toStringAsFixed(8);
    final centerLon = ((minLon + maxLon) / 2).toStringAsFixed(8);
    final orderBy =
        '((lat - $centerLat) * (lat - $centerLat) + '
        '(lon - $centerLon) * (lon - $centerLon)) ASC';

    if (cleanQuery.isNotEmpty) {
      whereClauses.add(
        '(p.name LIKE ? OR p.name_ascii LIKE ? OR p.category LIKE ? OR p.sub_category LIKE ? OR p.address LIKE ? OR p.street LIKE ? OR p.housenumber LIKE ? OR p.city LIKE ? OR p.admin_aliases LIKE ?)');
      whereArgs.addAll([
        '%$cleanQuery%',
        '%$cleanAscii%',
        '%$cleanQuery%',
        '%$cleanQuery%',
        '%$cleanQuery%',
        '%$cleanQuery%',
        '%$cleanQuery%',
        '%$cleanQuery%',
        '%$cleanQuery%',
      ]);
    }

    if (hasCategory) {
      final keywords = _querySupport.categoryKeywords(cleanCategory);
      final catOrClauses = keywords
          .map((_) => '(LOWER(p.category) LIKE ? OR LOWER(p.sub_category) LIKE ? OR LOWER(p.name) LIKE ? OR LOWER(p.name_ascii) LIKE ?)')
          .join(' OR ');
      whereClauses.add('($catOrClauses)');
      for (final kw in keywords) {
        whereArgs.addAll(['%$kw%', '%$kw%', '%$kw%', '%$kw%']);
      }
    }

    try {
      final results = await db.rawQuery(
        'SELECT p.* FROM poi_rtree r JOIN poi p ON p.id = r.id '
        'WHERE ${whereClauses.join(' AND ')} '
        'ORDER BY $orderBy LIMIT ?',
        [...whereArgs, limit],
      );
      return results.map(PoiModel.fromMap).toList();
    } catch (_) {
      // Fallback cho DB cũ chưa có R*Tree hoặc admin_aliases.
      final legacyClauses = <String>[
        'lat >= ? AND lat <= ?',
        'lon >= ? AND lon <= ?',
      ];
      final legacyArgs = <dynamic>[minLat, maxLat, minLon, maxLon];
      if (cleanQuery.isNotEmpty) {
        legacyClauses.add(
            '(name LIKE ? OR name_ascii LIKE ? OR category LIKE ? OR sub_category LIKE ? OR address LIKE ? OR street LIKE ? OR housenumber LIKE ? OR city LIKE ? OR admin_aliases LIKE ?)');
        legacyArgs.addAll(whereArgs.sublist(4, 13));
      }
      if (hasCategory) {
        final keywords = _querySupport.categoryKeywords(cleanCategory);
        final catOrClauses = keywords
            .map((_) => '(LOWER(category) LIKE ? OR LOWER(sub_category) LIKE ? OR LOWER(name) LIKE ? OR LOWER(name_ascii) LIKE ?)')
            .join(' OR ');
        legacyClauses.add('($catOrClauses)');
        for (final kw in keywords) {
          legacyArgs.addAll(['%$kw%', '%$kw%', '%$kw%', '%$kw%']);
        }
      }
      try {
        final results = await db.query(
          'poi',
          where: legacyClauses.join(' AND '),
          whereArgs: legacyArgs,
          orderBy: orderBy,
          limit: limit,
        );
        return results.map(PoiModel.fromMap).toList();
      } catch (_) {
        return [];
      }
    }
  }

}
