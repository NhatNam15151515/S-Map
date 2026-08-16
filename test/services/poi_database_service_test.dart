import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/services/poi_database_service.dart';
import 'package:sqflite/sqflite.dart';

class FakeDatabase implements Database {
  bool _isOpen = true;

  @override
  bool get isOpen => _isOpen;

  @override
  Future<void> close() async {
    _isOpen = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDatabaseFactory implements DatabaseFactory {
  int openCount = 0;
  Duration delay = Duration.zero;

  @override
  Future<Database> openDatabase(String path, {OpenDatabaseOptions? options}) async {
    openCount++;
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    return FakeDatabase();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String testDbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('smap_poi_test_');
    testDbPath = '${tempDir.path}/test_poi.db';
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('PoiDatabaseServiceImpl Tests', () {
    test('openDatabaseInstance returns open database instance and reuses it', () async {
      final fakeFactory = FakeDatabaseFactory();
      final service = PoiDatabaseServiceImpl(customFactory: fakeFactory);

      final db1 = await service.openDatabaseInstance(customPath: testDbPath);
      expect(db1.isOpen, isTrue);
      expect(service.isOpen, isTrue);
      expect(fakeFactory.openCount, equals(1));

      final db2 = await service.openDatabaseInstance(customPath: testDbPath);
      expect(identical(db1, db2), isTrue);
      expect(fakeFactory.openCount, equals(1));

      await service.close();
      expect(service.isOpen, isFalse);
    });

    test('openDatabaseInstance synchronizes concurrent calls with a shared Future', () async {
      final fakeFactory = FakeDatabaseFactory()..delay = const Duration(milliseconds: 50);
      final service = PoiDatabaseServiceImpl(customFactory: fakeFactory);

      final results = await Future.wait([
        service.openDatabaseInstance(customPath: testDbPath),
        service.openDatabaseInstance(customPath: testDbPath),
        service.openDatabaseInstance(customPath: testDbPath),
      ]);

      expect(fakeFactory.openCount, equals(1));
      expect(identical(results[0], results[1]), isTrue);
      expect(identical(results[1], results[2]), isTrue);

      await service.close();
    });

    test('open -> close -> open sequence correctly serializes when first open is pending', () async {
      final fakeFactory = FakeDatabaseFactory()..delay = const Duration(milliseconds: 30);
      final service = PoiDatabaseServiceImpl(customFactory: fakeFactory);

      // Start initial open
      final openFuture1 = service.openDatabaseInstance(customPath: testDbPath);

      // Call close while open is in-flight
      final closeFuture = service.close();

      await Future.wait([openFuture1, closeFuture]);
      expect(service.isOpen, isFalse);

      // Subsequent open should succeed and open a fresh database
      final db2 = await service.openDatabaseInstance(customPath: testDbPath);
      expect(db2.isOpen, isTrue);
      expect(service.isOpen, isTrue);
      expect(fakeFactory.openCount, equals(2));

      await service.close();
    });
  });
}
