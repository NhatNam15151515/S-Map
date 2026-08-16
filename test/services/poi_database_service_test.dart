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
  String? lastPath;
  OpenDatabaseOptions? lastOptions;

  @override
  Future<Database> openDatabase(String path, {OpenDatabaseOptions? options}) async {
    openCount++;
    lastPath = path;
    lastOptions = options;
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
    test('openDatabaseInstance returns open database instance and asserts open contract', () async {
      final fakeFactory = FakeDatabaseFactory();
      final service = PoiDatabaseServiceImpl(customFactory: fakeFactory);

      final db1 = await service.openDatabaseInstance(customPath: testDbPath);
      expect(db1.isOpen, isTrue);
      expect(service.isOpen, isTrue);
      expect(fakeFactory.openCount, equals(1));
      expect(fakeFactory.lastPath, equals(testDbPath));
      expect(fakeFactory.lastOptions?.readOnly, isTrue);
      expect(fakeFactory.lastOptions?.singleInstance, isTrue);

      final db2 = await service.openDatabaseInstance(customPath: testDbPath);
      expect(identical(db1, db2), isTrue);
      expect(fakeFactory.openCount, equals(1));

      await service.close();
      expect(service.isOpen, isFalse);
    });

    test('openDatabaseInstance synchronizes concurrent calls with shared Future across benchmark iterations', () async {
      // Warm up: ensure test database file exists so file copy is not timed during benchmark
      final warmupFactory = FakeDatabaseFactory();
      final warmupService = PoiDatabaseServiceImpl(customFactory: warmupFactory);
      await warmupService.openDatabaseInstance(customPath: testDbPath);
      await warmupService.close();

      const iterations = 20;

      for (int i = 0; i < iterations; i++) {
        final fakeFactory = FakeDatabaseFactory()..delay = const Duration(milliseconds: 5);
        final service = PoiDatabaseServiceImpl(customFactory: fakeFactory);

        final stopwatch = Stopwatch()..start();
        final results = await Future.wait([
          service.openDatabaseInstance(customPath: testDbPath),
          service.openDatabaseInstance(customPath: testDbPath),
          service.openDatabaseInstance(customPath: testDbPath),
          service.openDatabaseInstance(customPath: testDbPath),
        ]);
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(300));
        expect(fakeFactory.openCount, equals(1));
        expect(identical(results[0], results[1]), isTrue);
        expect(identical(results[1], results[2]), isTrue);
        expect(identical(results[2], results[3]), isTrue);

        await service.close();
      }
    });

    test('open -> close -> open sequence correctly queues when first open is pending', () async {
      final fakeFactory = FakeDatabaseFactory()..delay = const Duration(milliseconds: 30);
      final service = PoiDatabaseServiceImpl(customFactory: fakeFactory);

      // Start initial open
      final openFuture1 = service.openDatabaseInstance(customPath: testDbPath);

      // Call close while open is in-flight
      final closeFuture = service.close();

      // Immediately queue reopen while open1 and close are in-flight
      final reopenFuture = service.openDatabaseInstance(customPath: testDbPath);

      final db1 = await openFuture1;
      await closeFuture;
      final db2 = await reopenFuture;

      expect(db1.isOpen, isFalse);
      expect(db2.isOpen, isTrue);
      expect(service.isOpen, isTrue);
      expect(identical(db1, db2), isFalse);
      expect(fakeFactory.openCount, equals(2));

      await service.close();
    });
  });
}
