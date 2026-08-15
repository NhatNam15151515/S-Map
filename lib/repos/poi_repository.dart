import 'package:s_map/commons/utils/app_utils.dart';
import 'package:s_map/commons/validators/validator.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/poi_model.dart';
import 'package:s_map/services/poi_database_service.dart';
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
    int limit = 50,
  }) async {
    final db = await _getDb();

    try {
      final List<Map<String, dynamic>> results = await db.rawQuery(
        '''
        SELECT p.*
        FROM poi_rtree r
        JOIN poi p ON r.id = p.id
        WHERE r.min_lat >= ? AND r.max_lat <= ?
          AND r.min_lon >= ? AND r.max_lon <= ?
        LIMIT ?
        ''',
        [minLat, maxLat, minLon, maxLon, limit],
      );

      return results.map(PoiModel.fromMap).toList();
    } catch (_) {
      // Fallback query bảng poi thông thường nếu R*Tree không khả dụng
      final fallbackResults = await db.query(
        'poi',
        where: 'lat >= ? AND lat <= ? AND lon >= ? AND lon <= ?',
        whereArgs: [minLat, maxLat, minLon, maxLon],
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
