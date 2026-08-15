import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:sqflite/sqflite.dart';

// Backward compatibility alias
typedef PoiDatabaseService = IPoiDatabaseService;

class PoiDatabaseServiceImpl implements IPoiDatabaseService {
  Database? _db;
  final DatabaseFactory? _customFactory;

  PoiDatabaseServiceImpl({DatabaseFactory? customFactory, Database? initialDb})
      : _customFactory = customFactory,
        _db = initialDb;

  static final PoiDatabaseServiceImpl instance = PoiDatabaseServiceImpl();

  @override
  Database? get database => _db;

  @override
  bool get isOpen => _db != null && _db!.isOpen;

  @override
  Future<Database> openDatabaseInstance({String? customPath}) async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }

    String dbPath = customPath ?? '';
    if (dbPath.isEmpty) {
      final appDir = await getApplicationDocumentsDirectory();
      dbPath = p.join(appDir.path, 'poi.db');
    }

    final file = File(dbPath);
    if (!await file.exists()) {
      throw FileSystemException("POI database file not found at: $dbPath");
    }

    if (_customFactory != null) {
      _db = await _customFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          readOnly: true,
          singleInstance: true,
        ),
      );
    } else {
      _db = await openDatabase(
        dbPath,
        readOnly: true,
        singleInstance: true,
      );
    }

    return _db!;
  }

  @override
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
