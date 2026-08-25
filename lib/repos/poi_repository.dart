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

  @override
  Future<List<PoiModel>> searchByName(String query, {int limit = 20}) async {
    if (!Validator.instance.isValidSearchQuery(query)) {
      return [];
    }

    final cleanQuery = _sanitizeFtsQuery(query);
    if (cleanQuery.isEmpty) return [];

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

      return results.map(PoiModel.fromMap).toList();
    } catch (_) {
      // Fallback tìm kiếm LIKE nếu FTS5 có vấn đề về cú pháp token
      final fallbackResults = await db.query(
        'poi',
        where: 'name LIKE ?',
        whereArgs: ['%$cleanQuery%'],
        limit: limit,
      );
      return fallbackResults.map(PoiModel.fromMap).toList();
    }
  }

  @override
  Future<List<PoiModel>> searchByNameAscii(String query,
      {int limit = 20}) async {
    if (!Validator.instance.isValidSearchQuery(query)) {
      return [];
    }

    final asciiQuery = AppUtils.instance.toAscii(query);
    final cleanQuery = _sanitizeFtsQuery(asciiQuery);
    if (cleanQuery.isEmpty) return [];

    final db = await _getDb();
    final ftsPattern = 'name_ascii: "$cleanQuery"*';

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

      return results.map(PoiModel.fromMap).toList();
    } catch (_) {
      // Fallback tìm kiếm LIKE trên cột name_ascii
      final fallbackResults = await db.query(
        'poi',
        where: 'name_ascii LIKE ?',
        whereArgs: ['%$cleanQuery%'],
        limit: limit,
      );
      return fallbackResults.map(PoiModel.fromMap).toList();
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
      if (exactResults.length >= limit) {
        return exactResults;
      }

      // Nếu ít kết quả, tìm kiếm mở rộng bằng name_ascii để không bỏ sót
      final asciiResults = await searchByNameAscii(query, limit: limit);
      final existingIds = exactResults.map((e) => e.id).toSet();

      final combined = [...exactResults];
      for (final item in asciiResults) {
        if (!existingIds.contains(item.id)) {
          combined.add(item);
          if (combined.length >= limit) break;
        }
      }
      return combined;
    } else {
      // Người dùng gõ không dấu: Tìm kiếm trực tiếp qua FTS5 name_ascii
      return await searchByNameAscii(query, limit: limit);
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

    try {
      final whereClauses = <String>[
        'r.min_lat >= ? AND r.max_lat <= ?',
        'r.min_lon >= ? AND r.max_lon <= ?',
      ];
      final whereArgs = <dynamic>[minLat, maxLat, minLon, maxLon];

      if (cleanQuery.isNotEmpty) {
        whereClauses.add(
            '(p.name LIKE ? OR p.name_ascii LIKE ? OR p.category LIKE ? OR p.sub_category LIKE ?)');
        whereArgs.addAll([
          '%$cleanQuery%',
          '%$cleanAscii%',
          '%$cleanQuery%',
          '%$cleanQuery%',
        ]);
      }

      if (hasCategory) {
        whereClauses.add('(LOWER(p.category) LIKE ? OR LOWER(p.sub_category) LIKE ?)');
        whereArgs.addAll(['%$cleanCategory%', '%$cleanCategory%']);
      }

      whereArgs.add(limit);

      final List<Map<String, dynamic>> results = await db.rawQuery(
        '''
        SELECT p.*
        FROM poi_rtree r
        JOIN poi p ON r.id = p.id
        WHERE ${whereClauses.join(' AND ')}
        LIMIT ?
        ''',
        whereArgs,
      );

      return results.map(PoiModel.fromMap).toList();
    } catch (_) {
      // Fallback query bảng poi thông thường nếu R*Tree không khả dụng
      final whereClauses = <String>[
        'lat >= ? AND lat <= ?',
        'lon >= ? AND lon <= ?',
      ];
      final whereArgs = <dynamic>[minLat, maxLat, minLon, maxLon];

      if (cleanQuery.isNotEmpty) {
        whereClauses.add(
            '(name LIKE ? OR name_ascii LIKE ? OR category LIKE ? OR sub_category LIKE ?)');
        whereArgs.addAll([
          '%$cleanQuery%',
          '%$cleanAscii%',
          '%$cleanQuery%',
          '%$cleanQuery%',
        ]);
      }

      if (hasCategory) {
        whereClauses.add('(LOWER(category) LIKE ? OR LOWER(sub_category) LIKE ?)');
        whereArgs.addAll(['%$cleanCategory%', '%$cleanCategory%']);
      }

      final fallbackResults = await db.query(
        'poi',
        where: whereClauses.join(' AND '),
        whereArgs: whereArgs,
        limit: limit,
      );
      return fallbackResults.map(PoiModel.fromMap).toList();
    }
  }

  @override
  Future<List<String>> getSuggestions(String query, {int limit = 10}) async {
    if (query.trim().isEmpty) return [];

    final cleanQuery = _sanitizeFtsQuery(AppUtils.instance.toAscii(query));
    if (cleanQuery.isEmpty) return [];

    final db = await _getDb();
    final ftsPattern = 'name_ascii: "$cleanQuery"*';

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
