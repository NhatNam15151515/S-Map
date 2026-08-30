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

  PoiRepositoryImpl({
    IPoiDatabaseService? dbService,
    Database? directDb,
  })  : _dbService = dbService ?? PoiDatabaseServiceImpl.instance,
        _directDb = directDb;

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
    final numberTokens = queryTokens
        .where(_containsNumberRegExp.hasMatch)
        .toList();
    final candidateNumberTokens = _tokenizeSearchText(
      [row['housenumber'], row['address']].whereType<String>().join(' '),
    );
    if (!_matchesSearchTokens(numberTokens, candidateNumberTokens)) return false;

    final streetQueryTokens = queryTokens
        .where((token) => !_containsNumberRegExp.hasMatch(token))
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

  /// Tìm theo các trường địa chỉ đã có trong DB, kể cả khi DB cũ chưa có
  /// cột address_ascii trong FTS index.
  Future<List<PoiModel>> _searchAddressFields(
    String query, {
    int limit = 20,
  }) async {
    final queryTokens = _tokenizeSearchText(query);
    if (queryTokens.isEmpty ||
        !queryTokens.any(_containsNumberRegExp.hasMatch)) {
      return [];
    }

    final numberTokens = queryTokens
        .where(_containsNumberRegExp.hasMatch)
        .toSet()
        .toList();
    final candidateClauses = <String>[];
    final candidateArgs = <String>[];
    for (final numberToken in numberTokens) {
      for (final column in ['housenumber', 'address', 'street']) {
        candidateClauses.add('$column LIKE ?');
        candidateArgs.add('%$numberToken%');
      }
    }

    final db = await _getDb();
    try {
      final rows = await db.query(
        'poi',
        where: candidateClauses.join(' OR '),
        whereArgs: candidateArgs,
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
    final ftsPattern = '"$cleanQuery"*';

    try {
      final List<Map<String, dynamic>> results = await db.rawQuery(
        '''
        SELECT p.*
        FROM poi_fts f
        JOIN poi p ON f.rowid = p.id
        WHERE poi_fts MATCH ?
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
    final ftsPattern =
        '(name_ascii: "$cleanQuery"* OR address: "$cleanQuery"* OR admin_aliases: "$cleanQuery"*)';

    try {
      final List<Map<String, dynamic>> results = await db.rawQuery(
        '''
        SELECT p.*
        FROM poi_fts f
        JOIN poi p ON f.rowid = p.id
        WHERE poi_fts MATCH ?
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

    final hasDiacritics = Validator.instance.hasDiacritics(query);

    if (hasDiacritics) {
      // Người dùng gõ có dấu: Ưu tiên FTS có dấu trước
      final exactResults = await searchByName(query, limit: limit);
      final addressResults = await _searchAddressFields(query, limit: limit);
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
        [...exactResults, ...asciiResults, ...streetResults],
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

    final cleanQuery = _sanitizeFtsQuery(AppUtils.instance.toAscii(query));
    if (cleanQuery.isEmpty) return [];

    final db = await _getDb();
    final ftsPattern =
        '(name_ascii: "$cleanQuery"* OR admin_aliases: "$cleanQuery"*)';

    try {
      final List<Map<String, dynamic>> results = await db.rawQuery(
        '''
        SELECT DISTINCT p.name
        FROM poi_fts f
        JOIN poi p ON f.rowid = p.id
        WHERE poi_fts MATCH ?
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
        WHERE name_ascii LIKE ?
        LIMIT ?
        ''',
        ['%$cleanQuery%', limit],
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
}
