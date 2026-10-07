part of 'poi_repository.dart';

mixin _PoiAddressLookup on _PoiRepositoryCore {
  @override
  Future<PoiModel?> getPoiById(int id) async {
    final db = await _getDb();
    final results = await db.query(
      'poi',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return PoiModel.fromMap(results.first);
  }

  Future<List<PoiModel>> getPoisByIds(List<int> ids) async {
    final uniqueIds = ids.toSet().toList(growable: false);
    if (uniqueIds.isEmpty) return const [];

    final db = await _getDb();
    final placeholders = List.filled(uniqueIds.length, '?').join(', ');
    final rows = await db.query(
      'poi',
      where: 'id IN ($placeholders)',
      whereArgs: uniqueIds,
    );
    final byId = <int, PoiModel>{
      for (final row in rows)
        if (row['id'] is num)
          (row['id'] as num).toInt(): PoiModel.fromMap(row),
    };
    return ids
        .map((id) => byId[id])
        .whereType<PoiModel>()
        .toList(growable: false);
  }

  @override
  Future<int> getSchemaVersion() async {
    if (_cachedSchemaVersion != null) return _cachedSchemaVersion!;
    try {
      final db = await _getDb();
      final rows = await db.query(
        'db_meta',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['schema_version'],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        _cachedSchemaVersion = int.tryParse(rows.first['value']?.toString() ?? '') ?? 1;
        return _cachedSchemaVersion!;
      }
    } catch (_) {
      // Bảng db_meta chưa tồn tại -> DB v1
    }
    _cachedSchemaVersion = 1;
    return 1;
  }

  @override
  Future<List<String>> getNeighborProvinces(String provinceCode) async {
    try {
      final db = await _getDb();
      final rows = await db.query(
        'admin_neighbor',
        columns: ['neighbor_code'],
        where: 'province_code = ?',
        whereArgs: [provinceCode],
      );
      return rows
          .map((r) => r['neighbor_code']?.toString() ?? '')
          .where((c) => c.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<StreetModel>> findStreets({
    required String nameQuery,
    String? provinceCode,
    String? districtCode,
    int limit = 10,
  }) async {
    final core = AddressParser.normalizeCore(nameQuery);
    if (core.isEmpty) return const [];

    try {
      final db = await _getDb();
      final clauses = <String>['name_core LIKE ?'];
      final args = <dynamic>['%$core%'];

      if (provinceCode != null && provinceCode.isNotEmpty) {
        clauses.add('province_code = ?');
        args.add(provinceCode);
      }
      if (districtCode != null && districtCode.isNotEmpty) {
        clauses.add('district_code = ?');
        args.add(districtCode);
      }

      final rows = await db.query(
        'street',
        where: clauses.join(' AND '),
        whereArgs: args,
        orderBy: 'poi_count DESC',
        limit: limit,
      );
      return rows.map(StreetModel.fromMap).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<PoiModel>> findHouseNumbers({
    required int streetId,
    int? targetHouseNo,
    int limit = 10,
  }) async {
    try {
      final db = await _getDb();
      String orderBy = 'house_no_main ASC';
      if (targetHouseNo != null) {
        orderBy = 'ABS(house_no_main - $targetHouseNo) ASC';
      }

      final rows = await db.query(
        'poi',
        where: 'street_id = ? AND house_no IS NOT NULL',
        whereArgs: [streetId],
        orderBy: orderBy,
        limit: limit,
      );
      return rows.map(PoiModel.fromMap).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<PoiModel>> searchScoped({
    required String query,
    String? provinceCode,
    String? districtCode,
    int? streetId,
    int limit = 20,
  }) async {
    if (!Validator.instance.isValidSearchQuery(query)) {
      return [];
    }

    final cleanQuery = _querySupport.sanitizeFtsQuery(query);
    if (cleanQuery.isEmpty) return [];

    final scopeTokens = <String>[];
    if (provinceCode != null && provinceCode.isNotEmpty) {
      scopeTokens.add('p$provinceCode');
    }
    if (districtCode != null && districtCode.isNotEmpty) {
      scopeTokens.add('d$districtCode');
    }
    if (streetId != null) {
      scopeTokens.add('s$streetId');
    }

    // Nếu không có bất kỳ phạm vi nào, fallback về unified search thông thường
    if (scopeTokens.isEmpty) {
      return search(query, limit: limit);
    }

    final db = await _getDb();
    final hasDiacritics = Validator.instance.hasDiacritics(query);
    final asciiQuery = _querySupport.sanitizeFtsQuery(AppUtils.instance.toAscii(query));
    final words = (hasDiacritics ? cleanQuery : asciiQuery)
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    final ftsTokens = words.map((w) => '"$w"*').join(' AND ');
    final scopePattern = scopeTokens.map((s) => 'scope: $s').join(' AND ');
    final ftsPattern = '($scopePattern) AND ($ftsTokens)';

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
      return results.map(PoiModel.fromMap).toList();
    } catch (_) {
      // Fallback nếu FTS5 chưa có cột scope hoặc query FTS5 không khả dụng
      return search(query, limit: limit);
    }
  }

  @override
  Future<List<AdminUnitModel>> getAdminUnits({int? level}) async {
    try {
      final db = await _getDb();
      final whereClause = level != null ? 'level = ?' : null;
      final whereArgs = level != null ? [level] : null;
      final rows = await db.query(
        'admin_unit',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'name_core ASC',
      );
      return rows.map(AdminUnitModel.fromMap).toList();
    } catch (_) {
      return const [];
    }
  }
}
