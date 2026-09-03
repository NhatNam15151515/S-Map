import 'dart:async';

import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/validators/validator.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/services/services.dart';
import 'package:sqflite/sqflite.dart';

// Backward compatibility alias
typedef PoiRepository = IPoiRepository;

class PoiRepositoryImpl implements IPoiRepository {
  final IPoiDatabaseService _dbService;
  final Database? _directDb;
  final SearchCacheService _searchCache;
  final bool _cacheEnabled;

  static final Map<String, Future<List<PoiModel>>> _inFlightSearches = {};
  static final Map<String, Future<List<PoiModel>>> _inFlightBoundsSearches = {};
  static final Map<String, Future<List<String>>> _inFlightSuggestions = {};

  PoiRepositoryImpl({
    IPoiDatabaseService? dbService,
    Database? directDb,
    SearchCacheService? searchCache,
  })  : _dbService = dbService ?? PoiDatabaseServiceImpl.instance,
        _directDb = directDb,
        _searchCache = searchCache ?? SearchCacheService.instance,
        // Direct/custom databases are primarily used by tests or isolated
        // consumers. Do not let their data leak into the shared app cache.
        _cacheEnabled = directDb == null && dbService == null;

  Future<Database> _getDb() async {
    final direct = _directDb;
    if (direct != null && direct.isOpen) {
      return direct;
    }
    final dbInstance = _dbService.database;
    if (_dbService.isOpen && dbInstance != null) {
      return dbInstance;
    }
    return await _dbService.openDatabaseInstance();
  }

  /// Làm sạch các ký tự đặc biệt có thể phá hỏng cú pháp FTS5 query
  String _sanitizeFtsQuery(String query) {
    return query.replaceAll(RegExp(r'''[*"'-\:()^~{}\[\]\\]'''), ' ').trim();
  }

  static final RegExp _searchTokenRegExp = RegExp(r'[^a-z0-9]+');
  static final RegExp _containsNumberRegExp = RegExp(r'\d');
  static const Set<String> _addressNoiseTokens = {
    'so',
    'number',
    'no',
    'duong',
    'pho',
    'street',
    'road',
  };

  /// Chuẩn hóa query/địa chỉ thành các token ASCII để tìm được cả dữ liệu
  /// tiếng Việt có dấu, không dấu và dấu tổ hợp từ OSM.
  List<String> _tokenizeSearchText(String? text) {
    final normalized = AppUtils.instance
        .toAscii(text)
        .replaceAll(_searchTokenRegExp, ' ')
        .trim();
    if (normalized.isEmpty) return [];

    return normalized
        .split(RegExp(r'\s+'))
        .where((token) =>
            token.isNotEmpty && !_addressNoiseTokens.contains(token))
        .toList();
  }

  bool _matchesSearchTokens(
    List<String> queryTokens,
    List<String> candidateTokens,
  ) {
    return queryTokens.every((queryToken) {
      return candidateTokens.any((candidateToken) {
        if (candidateToken == queryToken) return true;
        // Allow a house number prefix such as "141" to match "141a".
        return queryToken.length >= 2 && candidateToken.startsWith(queryToken);
      });
    });
  }

  bool _matchesAddressCoreTokens(
    List<String> queryTokens,
    Map<String, dynamic> row,
  ) {
    // Chỉ số đầu tiên trong query được xem là số nhà. Các số phía sau
    // thường là thành phần hành chính (ví dụ "Quận 1"), không được dùng để
    // loại bỏ một địa chỉ hợp lệ khi OSM thiếu hoặc khác tên admin.
    final houseNumberIndex =
        queryTokens.indexWhere(_containsNumberRegExp.hasMatch);
    final numberTokens = houseNumberIndex >= 0
        ? [queryTokens[houseNumberIndex]]
        : const <String>[];
    final candidateNumberTokens = _tokenizeSearchText(
      [row['housenumber'], row['address']].whereType<String>().join(' '),
    );
    if (!_matchesSearchTokens(numberTokens, candidateNumberTokens)) return false;

    final streetQueryTokens = queryTokens
        .asMap()
        .entries
        .where((entry) => entry.key != houseNumberIndex)
        .map((entry) => entry.value)
        .where((token) => !token.contains(RegExp(r'^\d+$')))
        .toList();
    final candidateStreetTokens = _tokenizeSearchText(
      [row['street'], row['address']].whereType<String>().join(' '),
    );

    // Phần tên đường là khóa định vị chính; các token hành chính có thể
    // khác nhau giữa địa chỉ trước và sau sáp nhập hoặc bị thiếu trong OSM.
    return streetQueryTokens.any((queryToken) {
      return candidateStreetTokens.any((candidateToken) {
        if (candidateToken == queryToken) return true;
        return queryToken.length >= 2 && candidateToken.startsWith(queryToken);
      });
    });
  }

  /// Tìm theo các trường địa chỉ trong DB bằng FTS5 push-down predicate,
  /// kết hợp cả số nhà lẫn tên đường thay vì chỉ quét số nhà trên toàn bảng.
  Future<List<PoiModel>> _searchAddressFields(
    String query, {
    int limit = 20,
  }) async {
    final queryTokens = _tokenizeSearchText(query);
    if (queryTokens.isEmpty ||
        !queryTokens.any(_containsNumberRegExp.hasMatch)) {
      return [];
    }

    final db = await _getDb();
    final numberTokens = queryTokens
        .where(_containsNumberRegExp.hasMatch)
        .toSet()
        .toList();
    final nonNumberTokens = queryTokens
        .where((token) => !_containsNumberRegExp.hasMatch(token))
        .toList();

    // 1. Thử truy vấn qua FTS5 với push-down predicate (cả số nhà lẫn tên đường)
    if (numberTokens.isNotEmpty && nonNumberTokens.isNotEmpty) {
      try {
        final numPattern = numberTokens.map((n) => '"$n"*').join(' OR ');
        final streetPattern = nonNumberTokens.map((s) => '"$s"*').join(' AND ');
        final ftsPattern = '($numPattern) AND ($streetPattern)';

        final ftsRows = await db.rawQuery(
          '''
          SELECT p.*
          FROM poi_fts f
          JOIN poi p ON f.rowid = p.id
          WHERE poi_fts MATCH ?
          LIMIT ?
          ''',
          [ftsPattern, limit * 3],
        );

        if (ftsRows.isNotEmpty) {
          final exactMatches = <PoiModel>[];
          final relaxedMatches = <PoiModel>[];
          for (final row in ftsRows) {
            final addressText = [
              row['address'],
              row['street'],
              row['housenumber'],
              row['city'],
              row['admin_aliases'],
            ].whereType<String>().join(' ');
            final addressTokens = _tokenizeSearchText(addressText);
            if (_matchesSearchTokens(queryTokens, addressTokens)) {
              exactMatches.add(PoiModel.fromMap(row));
            } else if (_matchesAddressCoreTokens(queryTokens, row)) {
              relaxedMatches.add(PoiModel.fromMap(row));
            }
          }
          if (exactMatches.isNotEmpty || relaxedMatches.isNotEmpty) {
            return [...exactMatches, ...relaxedMatches].take(limit).toList();
          }
        }
      } catch (_) {
        // Fallback xuống câu query LIKE nếu bảng FTS5 không khả dụng
      }
    }

    // 2. Fallback tìm kiếm SQL trực tiếp với LIMIT an toàn (tránh Full Table Scan vô tận)
    final candidateClauses = <String>[];
    final candidateArgs = <String>[];
    for (final numberToken in numberTokens) {
      for (final column in ['housenumber', 'address', 'street']) {
        candidateClauses.add('$column LIKE ?');
        candidateArgs.add('%$numberToken%');
      }
    }

    try {
      final rows = await db.query(
        'poi',
        where: candidateClauses.join(' OR '),
        whereArgs: candidateArgs,
        limit: 200,
      );

      final exactMatches = <PoiModel>[];
      final relaxedMatches = <PoiModel>[];
      for (final row in rows) {
        final addressText = [
          row['address'],
          row['street'],
          row['housenumber'],
          row['city'],
          row['admin_aliases'],
        ].whereType<String>().join(' ');
        final addressTokens = _tokenizeSearchText(addressText);
        if (_matchesSearchTokens(queryTokens, addressTokens)) {
          exactMatches.add(PoiModel.fromMap(row));
        } else if (_matchesAddressCoreTokens(queryTokens, row)) {
          relaxedMatches.add(PoiModel.fromMap(row));
        }
      }
      return [...exactMatches, ...relaxedMatches].take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  /// Nếu người dùng nhập cả số nhà nhưng OSM chưa có bản ghi số nhà đó,
  /// trả về chỉ mục đường tương ứng để vẫn tìm được vị trí gần đúng offline.
  Future<List<PoiModel>> _searchStreetFallback(
    String query, {
    int limit = 20,
  }) async {
    final streetTokens = _tokenizeSearchText(query)
        .where((token) => !_containsNumberRegExp.hasMatch(token))
        .toList();
    if (streetTokens.isEmpty) return [];

    final db = await _getDb();
    final ftsPattern = streetTokens
        .map((token) => 'name_ascii: "$token"*')
        .join(' AND ');
    try {
      final rows = await db.rawQuery(
        '''
        SELECT p.*
        FROM poi_fts f
        JOIN poi p ON f.rowid = p.id
        WHERE poi_fts MATCH ? AND p.category = 'street'
        LIMIT ?
        ''',
        [ftsPattern, limit],
      );
      return rows.map(PoiModel.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  List<PoiModel> _mergeUniqueResults(
    Iterable<PoiModel> primary,
    Iterable<PoiModel> additional, {
    int limit = 20,
  }) {
    final result = <PoiModel>[];
    final seen = <String>{};

    for (final poi in [...primary, ...additional]) {
      final key = poi.id != null
          ? 'id:${poi.id}'
          : 'loc:${poi.lat}:${poi.lon}:${poi.name}';
      if (seen.add(key)) {
        result.add(poi);
        if (result.length >= limit) break;
      }
    }
    return result;
  }

  static const List<PoiModel> _sovereignPois = [
    PoiModel(
      id: 999901,
      name: 'Quần đảo Hoàng Sa (Việt Nam)',
      nameAscii: 'Quan dao Hoang Sa (Viet Nam)',
      lat: 16.5367,
      lon: 112.3394,
      category: 'island',
      address: 'Thành phố Đà Nẵng, Việt Nam',
    ),
    PoiModel(
      id: 999902,
      name: 'Quần đảo Trường Sa (Việt Nam)',
      nameAscii: 'Quan dao Truong Sa (Viet Nam)',
      lat: 8.6433,
      lon: 111.9197,
      category: 'island',
      address: 'Tỉnh Khánh Hòa, Việt Nam',
    ),
    PoiModel(
      id: 999903,
      name: 'Biển Đông',
      nameAscii: 'Bien Dong',
      lat: 13.5000,
      lon: 113.5000,
      category: 'sea',
      address: 'Việt Nam',
    ),
  ];

  List<PoiModel> _matchSovereignPois(String query) {
    final lower = query.toLowerCase().trim();
    if (lower.isEmpty) return [];
    return _sovereignPois.where((p) {
      final nameLower = p.name.toLowerCase();
      if (nameLower.contains(lower)) return true;
      if ((lower.contains('hoang sa') || lower.contains('hoàng sa')) && p.id == 999901) return true;
      if ((lower.contains('truong sa') || lower.contains('trường sa')) && p.id == 999902) return true;
      if ((lower.contains('bien dong') || lower.contains('biển đông')) && p.id == 999903) return true;
      return false;
    }).toList();
  }

  @override
  Future<List<PoiModel>> searchByName(String query, {int limit = 20}) async {
    if (!Validator.instance.isValidSearchQuery(query)) {
      return [];
    }

    final matchedSovereign = _matchSovereignPois(query);
    final cleanQuery = _sanitizeFtsQuery(query);
    if (cleanQuery.isEmpty) return matchedSovereign;

    final db = await _getDb();
    final words = cleanQuery
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final ftsPattern = words.length > 1
        ? '("$cleanQuery"*) OR (${words.map((w) => '"$w"*').join(' AND ')})'
        : '"$cleanQuery"*';

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
    } catch (_) {
      // Fallback tìm kiếm LIKE nếu FTS5 có vấn đề về cú pháp token
      final fallbackResults = await db.query(
        'poi',
        where: 'name LIKE ? OR address LIKE ? OR street LIKE ? OR housenumber LIKE ?',
        whereArgs: [
          '%$cleanQuery%',
          '%$cleanQuery%',
          '%$cleanQuery%',
          '%$cleanQuery%',
        ],
        limit: limit,
      );
      final dbPois = fallbackResults.map(PoiModel.fromMap).toList();
      return [...matchedSovereign, ...dbPois].take(limit).toList();
    }
  }

  @override
  Future<List<PoiModel>> searchByNameAscii(String query,
      {int limit = 20}) async {
    if (!Validator.instance.isValidSearchQuery(query)) {
      return [];
    }

    final matchedSovereign = _matchSovereignPois(query);
    final asciiQuery = AppUtils.instance.toAscii(query);
    final cleanQuery = _sanitizeFtsQuery(asciiQuery);
    if (cleanQuery.isEmpty) return matchedSovereign;

    final db = await _getDb();
    final words = cleanQuery
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final tokenPattern = words.length > 1
        ? ' OR (name_ascii: ${words.map((w) => '"$w"*').join(' AND ')})'
        : '';
    final ftsPattern =
        '(name_ascii: "$cleanQuery"* OR address: "$cleanQuery"* OR admin_aliases: "$cleanQuery"*$tokenPattern)';

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
    } catch (_) {
      // Fallback vẫn hỗ trợ DB cũ chưa có cột admin_aliases.
      List<Map<String, dynamic>> fallbackResults;
      try {
        fallbackResults = await db.query(
          'poi',
          where: 'name_ascii LIKE ? OR address LIKE ? OR street LIKE ? OR housenumber LIKE ? OR admin_aliases LIKE ?',
          whereArgs: [
            '%$cleanQuery%',
            '%$cleanQuery%',
            '%$cleanQuery%',
            '%$cleanQuery%',
            '%$cleanQuery%',
          ],
          limit: limit,
        );
      } catch (_) {
        fallbackResults = await db.query(
          'poi',
          where: 'name_ascii LIKE ? OR address LIKE ? OR street LIKE ? OR housenumber LIKE ?',
          whereArgs: [
            '%$cleanQuery%',
            '%$cleanQuery%',
            '%$cleanQuery%',
            '%$cleanQuery%',
          ],
          limit: limit,
        );
      }
      final dbPois = fallbackResults.map(PoiModel.fromMap).toList();
      return [...matchedSovereign, ...dbPois].take(limit).toList();
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

    final key = _searchCacheKey(cleanQuery, limit: limit);
    final cached = _searchCache.getPois(key, limit: limit);
    if (cached != null) {
      return cached;
    }

    final pending = _inFlightSearches[key];
    if (pending != null) return List<PoiModel>.of(await pending);

    final future = _searchUncached(cleanQuery, limit: limit);
    _inFlightSearches[key] = future;
    try {
      final results = await future;
      _searchCache.putPois(key, results);
      return results;
    } finally {
      if (identical(_inFlightSearches[key], future)) {
        _inFlightSearches.remove(key);
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

    final hasDiacritics = Validator.instance.hasDiacritics(query);

    if (hasDiacritics) {
      // Người dùng gõ có dấu: Ưu tiên FTS có dấu trước
      // Hai nhánh độc lập nên chạy song song để giảm thời gian phản hồi lần
      // đầu; các lần sau sẽ được phục vụ từ SearchCacheService.
      final initialResults = await Future.wait([
        searchByName(query, limit: limit),
        _searchAddressFields(query, limit: limit),
      ]);
      final exactResults = initialResults[0];
      final addressResults = initialResults[1];
      if (exactResults.length >= limit && addressResults.isEmpty) {
        return exactResults;
      }

      // Nếu ít kết quả, tìm kiếm mở rộng bằng name_ascii để không bỏ sót
      final asciiResults = await searchByNameAscii(query, limit: limit);
      final streetResults = addressResults.isEmpty
          ? await _searchStreetFallback(query, limit: limit)
          : const <PoiModel>[];

      return _mergeUniqueResults(
        addressResults,
        [...exactResults, ...streetResults, ...asciiResults],
        limit: limit,
      );
    } else {
      // Người dùng gõ không dấu: Tìm kiếm trực tiếp qua FTS5 name_ascii
      final nameResults = await searchByNameAscii(query, limit: limit);
      final addressResults = await _searchAddressFields(query, limit: limit);
      final streetResults = addressResults.isEmpty
          ? await _searchStreetFallback(query, limit: limit)
          : const <PoiModel>[];
      return _mergeUniqueResults(
        addressResults,
        [...nameResults, ...streetResults],
        limit: limit,
      );
    }
  }

  List<String> _getCategoryKeywords(String category) {
    final lower = category.toLowerCase().trim();
    switch (lower) {
      case 'coffee':
      case 'cafe':
      case 'cà phê':
      case 'ca phe':
        return ['coffee', 'cafe', 'cà phê', 'ca phe'];
      case 'food':
      case 'nhà hàng':
      case 'quán ăn':
        return ['food', 'restaurant', 'fast_food', 'nhà hàng', 'nha hang', 'quán ăn', 'quan an'];
      case 'gas':
      case 'fuel':
      case 'xăng':
      case 'cây xăng':
        return ['gas', 'fuel', 'xăng', 'xang', 'petrol'];
      case 'hotel':
      case 'khách sạn':
      case 'nhà nghỉ':
        return ['hotel', 'motel', 'guest_house', 'khách sạn', 'khach san', 'nhà nghỉ', 'nha nghi'];
      case 'atm':
      case 'ngân hàng':
      case 'bank':
        return ['atm', 'bank', 'ngân hàng', 'ngan hang'];
      case 'hospital':
      case 'bệnh viện':
      case 'y tế':
        return ['hospital', 'clinic', 'pharmacy', 'bệnh viện', 'benh vien', 'phòng khám', 'phong kham', 'nhà thuốc', 'nha thuoc'];
      default:
        return [lower];
    }
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

    final key = _boundsSearchCacheKey(
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

    final pending = _inFlightBoundsSearches[key];
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
    _inFlightBoundsSearches[key] = future;
    try {
      final results = await future;
      _searchCache.putPois(key, results);
      return results;
    } finally {
      if (identical(_inFlightBoundsSearches[key], future)) {
        _inFlightBoundsSearches.remove(key);
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
    final cleanQuery = query != null ? _sanitizeFtsQuery(query) : '';
    final cleanAscii = cleanQuery.isNotEmpty
        ? _sanitizeFtsQuery(AppUtils.instance.toAscii(cleanQuery))
        : '';
    final hasCategory = category != null &&
        category.trim().isNotEmpty &&
        category.trim().toLowerCase() != 'all';
    final cleanCategory = hasCategory ? category.trim().toLowerCase() : '';

    final whereClauses = <String>[
      'lat >= ? AND lat <= ?',
      'lon >= ? AND lon <= ?',
    ];
    final whereArgs = <dynamic>[minLat, maxLat, minLon, maxLon];
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
          '(name LIKE ? OR name_ascii LIKE ? OR category LIKE ? OR sub_category LIKE ? OR address LIKE ? OR street LIKE ? OR housenumber LIKE ? OR city LIKE ? OR admin_aliases LIKE ?)');
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
      final keywords = _getCategoryKeywords(cleanCategory);
      final catOrClauses = keywords
          .map((_) => '(LOWER(category) LIKE ? OR LOWER(sub_category) LIKE ? OR LOWER(name) LIKE ? OR LOWER(name_ascii) LIKE ?)')
          .join(' OR ');
      whereClauses.add('($catOrClauses)');
      for (final kw in keywords) {
        whereArgs.addAll(['%$kw%', '%$kw%', '%$kw%', '%$kw%']);
      }
    }

    try {
      final results = await db.query(
        'poi',
        where: whereClauses.join(' AND '),
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
      );
      return results.map(PoiModel.fromMap).toList();
    } catch (_) {
      // DB tải từ phiên bản cũ chưa có admin_aliases vẫn phải xem được.
      if (cleanQuery.isEmpty) return [];
      final legacyClauses = whereClauses
          .map((clause) => clause.replaceAll(' OR admin_aliases LIKE ?', ''))
          .toList();
      final legacyArgs = [...whereArgs];
      // 4 tọa độ bbox + 8 trường cũ trước admin_aliases.
      legacyArgs.removeAt(12);
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

  @override
  Future<List<String>> getSuggestions(String query, {int limit = 10}) async {
    if (query.trim().isEmpty) return [];

    if (!_cacheEnabled) {
      return _getSuggestionsUncached(query, limit: limit);
    }

    final key = _suggestionsCacheKey(query, limit: limit);
    final cached = _searchCache.getSuggestions(key, limit: limit);
    if (cached != null) return cached;

    final pending = _inFlightSuggestions[key];
    if (pending != null) return List<String>.of(await pending);

    final future = _getSuggestionsUncached(query, limit: limit);
    _inFlightSuggestions[key] = future;
    try {
      final results = await future;
      _searchCache.putSuggestions(key, results);
      return results;
    } finally {
      if (identical(_inFlightSuggestions[key], future)) {
        _inFlightSuggestions.remove(key);
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
    final cleanQuery = _sanitizeFtsQuery(trimmed);
    if (cleanQuery.isEmpty) return [];

    final db = await _getDb();
    final cleanAscii = _sanitizeFtsQuery(AppUtils.instance.toAscii(trimmed));
    final ftsPattern = hasDiacritics
        ? '(name: "$cleanQuery"* OR address: "$cleanQuery"*)'
        : '(name_ascii: "$cleanAscii"* OR admin_aliases: "$cleanAscii"*)';

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
    } catch (_) {
      final fallbackResults = await db.rawQuery(
        '''
        SELECT DISTINCT name
        FROM poi
        WHERE ${hasDiacritics ? 'name LIKE ?' : 'name_ascii LIKE ?'}
        LIMIT ?
        ''',
        [hasDiacritics ? '%$cleanQuery%' : '%$cleanAscii%', limit],
      );

      return fallbackResults
          .map((row) => row['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
    }
  }

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

  String _searchCacheKey(String query, {required int limit}) {
    // Có dấu/không dấu đi qua các nhánh FTS khác nhau; không gộp hai loại này
    // vào một cache key để tránh dùng nhầm result set trong các edge case OSM.
    final mode = Validator.instance.hasDiacritics(query) ? 'accent' : 'ascii';
    return '${SearchCacheService.cacheVersion}|search|$mode|'
        '${_normalizeCacheText(query)}|limit:$limit';
  }

  String _suggestionsCacheKey(String query, {required int limit}) =>
      '${SearchCacheService.cacheVersion}|suggestions|${_normalizeCacheText(query)}|limit:$limit';

  String _boundsSearchCacheKey({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    String? query,
    String? category,
    required int limit,
  }) {
    String coordinate(double value) => value.toStringAsFixed(5);

    return '${SearchCacheService.cacheVersion}|bounds|'
        '${coordinate(minLat)}:${coordinate(maxLat)}:'
        '${coordinate(minLon)}:${coordinate(maxLon)}|'
        'query:${_normalizeCacheText(query)}|'
        'category:${_normalizeCacheText(category)}|limit:$limit';
  }

  String _normalizeCacheText(String? value) {
    if (value == null || value.isEmpty) return '';
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
