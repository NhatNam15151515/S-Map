import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/repos/repos.dart';
import 'package:s_map/search_engine/search_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late PoiRepositoryImpl poiRepo;
  late SearchOrchestrator orchestrator;

  setUp(() async {
    final dbFactory = databaseFactoryFfi;
    db = await dbFactory.openDatabase(inMemoryDatabasePath);

    // Tạo bảng poi theo Schema v2
    await db.execute('''
      CREATE TABLE poi (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        osm_id TEXT,
        name TEXT NOT NULL,
        name_ascii TEXT NOT NULL,
        category TEXT,
        sub_category TEXT,
        lat REAL NOT NULL,
        lon REAL NOT NULL,
        address TEXT,
        address_ascii TEXT,
        street TEXT,
        housenumber TEXT,
        city TEXT,
        admin_aliases TEXT,
        province_code TEXT,
        province_legacy_code TEXT,
        district_code TEXT,
        street_id INTEGER,
        street_core TEXT,
        house_no TEXT,
        house_no_main INTEGER,
        admin_source TEXT,
        scope TEXT
      );
    ''');

    // Tạo bảng ảo poi_fts với cột scope
    await db.execute('''
      CREATE VIRTUAL TABLE poi_fts USING fts5(
        name,
        name_ascii,
        category,
        address,
        address_ascii,
        admin_aliases,
        scope,
        content='poi',
        content_rowid='id'
      );
    ''');

    // Trigger đồng bộ FTS5
    await db.execute('''
      CREATE TRIGGER poi_ai AFTER INSERT ON poi BEGIN
        INSERT INTO poi_fts(rowid, name, name_ascii, category, address, address_ascii, admin_aliases, scope)
        VALUES (new.id, new.name, new.name_ascii, new.category, new.address, new.address_ascii, new.admin_aliases, new.scope);
      END;
    ''');

    // Bảng street
    await db.execute('''
      CREATE TABLE street (
        id INTEGER PRIMARY KEY,
        province_code TEXT NOT NULL,
        district_code TEXT,
        name TEXT NOT NULL,
        name_core TEXT NOT NULL,
        poi_count INTEGER NOT NULL,
        house_count INTEGER NOT NULL,
        center_lat REAL NOT NULL,
        center_lon REAL NOT NULL,
        min_lat REAL, max_lat REAL, min_lon REAL, max_lon REAL
      );
    ''');

    // Bảng admin_neighbor
    await db.execute('''
      CREATE TABLE admin_neighbor (
        province_code TEXT NOT NULL,
        neighbor_code TEXT NOT NULL,
        PRIMARY KEY (province_code, neighbor_code)
      );
    ''');

    // Bảng admin_unit
    await db.execute('''
      CREATE TABLE admin_unit (
        code TEXT NOT NULL,
        level INTEGER NOT NULL,
        name TEXT NOT NULL,
        name_core TEXT NOT NULL,
        accent_core TEXT NOT NULL,
        kind TEXT,
        parent_code TEXT,
        successor_code TEXT,
        successor_name TEXT,
        is_legacy INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (level, code)
      );
    ''');

    // Bảng db_meta
    await db.execute('''
      CREATE TABLE db_meta (
        key TEXT PRIMARY KEY,
        value TEXT
      );
    ''');
    await db.insert('db_meta', {'key': 'schema_version', 'value': '2'});

    // Thêm dữ liệu mẫu:
    // 1. POI ở Hà Nội (Hồ Hoàn Kiếm, cách TP.HCM ~1100 km)
    await db.insert('poi', {
      'id': 101,
      'name': 'Hồ Hoàn Kiếm',
      'name_ascii': 'Ho Hoan Kiem',
      'lat': 21.0285,
      'lon': 105.8542,
      'category': 'attraction',
      'address': 'Quận Hoàn Kiếm, Hà Nội',
      'province_code': '01',
      'province_legacy_code': '01',
      'district_code': '002',
      'scope': 'p01 d002',
    });

    // 2. Tuyến đường và số nhà ở TP.HCM (Đường Lê Lợi, Quận 1)
    await db.insert('street', {
      'id': 5001,
      'province_code': '79',
      'district_code': '760',
      'name': 'Đường Lê Lợi',
      'name_core': 'le loi',
      'poi_count': 10,
      'house_count': 5,
      'center_lat': 10.7750,
      'center_lon': 106.7000,
    });

    await db.insert('poi', {
      'id': 201,
      'name': '123 Lê Lợi',
      'name_ascii': '123 Le Loi',
      'lat': 10.7745,
      'lon': 106.6995,
      'category': 'shop',
      'address': '123 Lê Lợi, Quận 1, Hồ Chí Minh',
      'street': 'Đường Lê Lợi',
      'housenumber': '123',
      'province_code': '79',
      'province_legacy_code': '79',
      'district_code': '760',
      'street_id': 5001,
      'street_core': 'le loi',
      'house_no': '123',
      'house_no_main': 123,
      'scope': 'p79 d760 s5001',
    });

    // POI láng giềng: Bình Dương -> TP.HCM mới (mã 79, cũ 74)
    await db.insert('poi', {
      'id': 301,
      'name': 'Khu công nghiệp VSIP 1',
      'name_ascii': 'Khu cong nghiep VSIP 1',
      'lat': 10.9300,
      'lon': 106.7100,
      'category': 'industrial',
      'address': 'Thị xã Thuận An, Bình Dương',
      'province_code': '79',
      'province_legacy_code': '74',
      'scope': 'p79 lp74',
    });

    poiRepo = PoiRepositoryImpl(directDb: db);
    orchestrator = SearchOrchestrator(poiRepository: poiRepo);
  });

  tearDown(() async {
    await db.close();
  });

  group('SearchOrchestrator Scoped & Destination Search Tests', () {
    test('Cross-province search: User in TP.HCM can search for Hanoi destination (>1000km away)', () async {
      // Vị trí người dùng: TP.HCM (Quận 1)
      const userInHcm = LatLng(10.7769, 106.7009);

      // Tìm kiếm đích danh Hà Nội
      final results = await orchestrator.search(
        query: 'Hồ Hoàn Kiếm, Hà Nội',
        userLocation: userInHcm,
      );

      // Điểm đến KHÔNG bị loại bỏ bởi bán kính 50km
      expect(results, isNotEmpty);
      expect(results.first.id, 101);
      expect(results.first.name, 'Hồ Hoàn Kiếm');
    });

    test('Scoped search parses street & house number in target province', () async {
      final results = await orchestrator.search(
        query: '123 Lê Lợi, TP.HCM',
        userLocation: const LatLng(10.7769, 106.7009),
      );

      expect(results, isNotEmpty);
      expect(results.any((poi) => poi.streetId == 5001 || poi.houseNo == '123'), isTrue);
    });

    test('Cross-province search with pre-merger province name (Bình Dương -> 79)', () async {
      final results = await orchestrator.search(
        query: 'VSIP, Bình Dương',
        userLocation: const LatLng(10.7769, 106.7009),
      );

      expect(results, isNotEmpty);
      expect(results.any((poi) => poi.id == 301), isTrue);
    });

    test('Schema version is recognized as 2', () async {
      final version = await poiRepo.getSchemaVersion();
      expect(version, 2);
    });
  });
}
