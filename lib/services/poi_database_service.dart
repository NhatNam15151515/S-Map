import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:sqflite/sqflite.dart';

// Backward compatibility alias
typedef PoiDatabaseService = IPoiDatabaseService;

class PoiDatabaseServiceImpl implements IPoiDatabaseService {
  Database? _db;
  Future<Database>? _openFuture;
  Future<void>? _closeFuture;
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
    while (_closeFuture != null) {
      await _closeFuture;
    }

    if (_db != null && _db!.isOpen) {
      return _db!;
    }

    if (_openFuture != null) {
      return await _openFuture!;
    }

    final future = _performOpenDatabase(customPath: customPath);
    _openFuture = future;
    try {
      final db = await future;
      return db;
    } finally {
      if (identical(_openFuture, future)) {
        _openFuture = null;
      }
    }
  }

  Future<Database> _performOpenDatabase({String? customPath}) async {
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
      ByteData byteData;
      try {
        byteData = await rootBundle.load('assets/database/poi.db');
      } catch (e) {
        throw FileSystemException(
          'Failed to load POI database asset from bundle: assets/database/poi.db ($e)',
          dbPath,
        );
      }

      final buffer = byteData.buffer;
      final tmpPath = '$dbPath.tmp_${DateTime.now().microsecondsSinceEpoch}';
      final tmpFile = File(tmpPath);
      await tmpFile.parent.create(recursive: true);
      await tmpFile.writeAsBytes(
        buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        flush: true,
      );

      try {
        await tmpFile.rename(dbPath);
      } catch (e) {
        if (!await file.exists()) {
          rethrow;
        }
        // If another process completed the rename first, delete the tmp file
        try {
          if (await tmpFile.exists()) {
            await tmpFile.delete();
          }
        } catch (_) {}
      }
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
    if (_closeFuture != null) {
      await _closeFuture;
      return;
    }

    final closeOp = _performClose();
    _closeFuture = closeOp;
    try {
      await closeOp;
    } finally {
      _closeFuture = null;
    }
  }

  Future<void> _performClose() async {
    if (_openFuture != null) {
      try {
        await _openFuture;
      } catch (_) {}
    }
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
    _openFuture = null;
  }
}
