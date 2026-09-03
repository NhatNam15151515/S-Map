import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/utils/app_utils.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Khởi tạo sqflite FFI cho môi trường test trên Desktop/CI
  sqfliteFfiInit();

  late Database db;
  late PoiRepositoryImpl poiRepo;

  setUp(() async {
    final dbFactory = databaseFactoryFfi;
    db = await dbFactory.openDatabase(inMemoryDatabasePath);

    // 1. Tạo bảng chính poi
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
        admin_aliases TEXT
      );
    ''');

    // 2. Tạo bảng ảo FTS5 poi_fts
    await db.execute('''
      CREATE VIRTUAL TABLE poi_fts USING fts5(
        name,
        name_ascii,
        category,
        address,
        address_ascii,
        admin_aliases,
        content='poi',
        content_rowid='id'
      );
    ''');

    // Trigger tự động đồng bộ sang FTS5
    await db.execute('''
      CREATE TRIGGER poi_ai AFTER INSERT ON poi BEGIN
        INSERT INTO poi_fts(rowid, name, name_ascii, category, address, address_ascii, admin_aliases)
        VALUES (new.id, new.name, new.name_ascii, new.category, new.address, new.address_ascii, new.admin_aliases);
      END;
    ''');

    // 3. Tạo bảng ảo R*Tree poi_rtree
    await db.execute('''
      CREATE VIRTUAL TABLE poi_rtree USING rtree(
        id,
        min_lat, max_lat,
        min_lon, max_lon
      );
    ''');

    // Trigger tự động đồng bộ sang R*Tree
    await db.execute('''
      CREATE TRIGGER poi_rtree_ai AFTER INSERT ON poi BEGIN
        INSERT INTO poi_rtree(id, min_lat, max_lat, min_lon, max_lon)
        VALUES (new.id, new.lat, new.lat, new.lon, new.lon);
      END;
    ''');

    // 4. Nạp dữ liệu mẫu POI thực tế
    final mockPois = [
      {
        'osm_id': 'n1001',
        'name': 'Phở Thìn Lò Đúc',
        'name_ascii': AppUtils.instance.toAscii('Phở Thìn Lò Đúc'),
        'category': 'food',
        'sub_category': 'restaurant',
        'lat': 21.0175,
        'lon': 105.8562,
        'address': '13 Lò Đúc, Hai Bà Trưng, Hà Nội',
        'street': 'Lò Đúc',
        'housenumber': '13',
        'city': 'Hà Nội',
      },
      {
        'osm_id': 'n1002',
        'name': 'Phở Hòa Pasteur',
        'name_ascii': AppUtils.instance.toAscii('Phở Hòa Pasteur'),
        'category': 'food',
        'sub_category': 'restaurant',
        'lat': 10.7892,
        'lon': 106.6897,
        'address': '260C Pasteur, Phường 8, Quận 3, TP.HCM',
        'street': 'Pasteur',
        'housenumber': '260C',
        'city': 'TP.HCM',
      },
      {
        'osm_id': 'n1003',
        'name': 'Bệnh viện Chợ Rẫy',
        'name_ascii': AppUtils.instance.toAscii('Bệnh viện Chợ Rẫy'),
        'category': 'hospital',
        'sub_category': 'general',
        'lat': 10.7554,
        'lon': 106.6596,
        'address': '201B Nguyễn Chí Thanh, Phường 12, Quận 5, TP.HCM',
        'street': 'Nguyễn Chí Thanh',
        'housenumber': '201B',
        'city': 'TP.HCM',
      },
      {
        'osm_id': 'n1004',
        'name': 'Khách sạn Rex Sài Gòn',
        'name_ascii': AppUtils.instance.toAscii('Khách sạn Rex Sài Gòn'),
        'category': 'hotel',
        'sub_category': 'luxury',
        'lat': 10.7761,
        'lon': 106.7012,
        'address': '141 Nguyễn Huệ, Bến Nghé, Quận 1, TP.HCM',
        'street': 'Nguyễn Huệ',
        'housenumber': '141',
        'city': 'TP.HCM',
      },
      {
        'osm_id': 'n1005',
        'name': 'Highlands Coffee Nhà Thờ',
        'name_ascii': AppUtils.instance.toAscii('Highlands Coffee Nhà Thờ'),
        'category': 'coffee',
        'sub_category': 'cafe',
        'lat': 21.0289,
        'lon': 105.8492,
        'address': '1 Nhà Thờ, Hoàn Kiếm, Hà Nội',
        'street': 'Nhà Thờ',
        'housenumber': '1',
        'city': 'Hà Nội',
      },
      {
        'osm_id': 'n1006',
        'name': 'ATM Vietcombank Bến Thành',
        'name_ascii': AppUtils.instance.toAscii('ATM Vietcombank Bến Thành'),
        'category': 'atm',
        'sub_category': 'bank_atm',
        'lat': 10.7725,
        'lon': 106.6980,
        'address': 'Chợ Bến Thành, Quận 1, TP.HCM',
        'street': 'Lê Lợi',
        'housenumber': '',
        'city': 'TP.HCM',
        'admin_aliases': 'Thành phố Hồ Chí Minh | Ho Chi Minh City | Bình Dương | Tỉnh Bình Dương | Bà Rịa - Vũng Tàu',
      },
      {
        'osm_id': 'w2001',
        'name': '142 Nguyễn Huệ',
        'name_ascii': AppUtils.instance.toAscii('142 Nguyễn Huệ'),
        'category': 'address',
        'sub_category': 'house_number',
        'lat': 10.7759,
        'lon': 106.7015,
        'address': '142, Nguyễn Huệ, TP.HCM',
        'street': 'Nguyễn Huệ',
        'housenumber': '142',
        'city': 'TP.HCM',
        'admin_aliases': 'Thành phố Hồ Chí Minh | Ho Chi Minh City | Bình Dương | Tỉnh Bình Dương | Bà Rịa - Vũng Tàu',
      },
      {
        'osm_id': 'street:nguyen suy:',
        'name': 'Nguyễn Súy',
        'name_ascii': AppUtils.instance.toAscii('Nguyễn Súy'),
        'category': 'street',
        'sub_category': 'residential',
        'lat': 10.7950,
        'lon': 106.6300,
        'address': 'Nguyễn Súy',
        'street': 'Nguyễn Súy',
        'housenumber': '',
        'city': 'TP.HCM',
      },
    ];

    for (final poi in mockPois) {
      await db.insert('poi', poi);
    }

    poiRepo = PoiRepositoryImpl(directDb: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('PoiRepository - FTS5 & Search Tests', () {
    test('searchByName should find Vietnamese queries with accents correctly',
        () async {
      final results = await poiRepo.searchByName('Phở');
      expect(results, isNotEmpty);
      expect(results.any((e) => e.name.contains('Phở')), isTrue);
    });

    test(
        'searchByNameAscii should find matching records from unaccented queries',
        () async {
      final results = await poiRepo.searchByNameAscii('pho');
      expect(results, isNotEmpty);
      expect(results.length, greaterThanOrEqualTo(2));
      expect(results.any((e) => e.name == 'Phở Thìn Lò Đúc'), isTrue);
      expect(results.any((e) => e.name == 'Phở Hòa Pasteur'), isTrue);
    });

    test(
        'search (Auto-detect) should return identical results for "phở" and "pho"',
        () async {
      final resultsWithAccents = await poiRepo.search('phở');
      final resultsWithoutAccents = await poiRepo.search('pho');

      expect(resultsWithAccents, isNotEmpty);
      expect(resultsWithoutAccents, isNotEmpty);

      final namesWithAccents = resultsWithAccents.map((e) => e.name).toSet();
      final namesWithoutAccents =
          resultsWithoutAccents.map((e) => e.name).toSet();

      // Cả hai query đều tìm thấy các quán Phở
      expect(namesWithAccents.contains('Phở Thìn Lò Đúc'), isTrue);
      expect(namesWithoutAccents.contains('Phở Thìn Lò Đúc'), isTrue);
      expect(namesWithoutAccents.contains('Phở Hòa Pasteur'), isTrue);
    });

    test('search should find a POI by house number and street with or without accents',
        () async {
      final accented = await poiRepo.search('141 Nguyễn Huệ');
      final ascii = await poiRepo.search('141 Nguyen Hue');
      final withAddressPrefix =
          await poiRepo.search('số 201B đường Nguyen Chi Thanh');

      expect(accented.any((e) => e.name == 'Khách sạn Rex Sài Gòn'), isTrue);
      expect(ascii.any((e) => e.name == 'Khách sạn Rex Sài Gòn'), isTrue);
      expect(withAddressPrefix.any((e) => e.name == 'Bệnh viện Chợ Rẫy'), isTrue);
    });

    test('search should find an address-only dataset record', () async {
      final results = await poiRepo.search('142 Nguyen Hue');

      expect(results.any((e) => e.category == 'address'), isTrue);
      expect(results.any((e) => e.housenumber == '142'), isTrue);
    });

    test('search should resolve both pre- and post-merger province names',
        () async {
      final oldAddress = await poiRepo.search('142 Nguyen Hue Binh Duong');
      final newAddress = await poiRepo.search('142 Nguyen Hue Ho Chi Minh');

      expect(oldAddress.any((e) => e.housenumber == '142'), isTrue);
      expect(newAddress.any((e) => e.housenumber == '142'), isTrue);
      expect(oldAddress.first.lat, newAddress.first.lat);
      expect(oldAddress.first.lon, newAddress.first.lon);
    });

    test('search should keep the address core when admin tokens are missing',
        () async {
      final results = await poiRepo.search('142 Nguyen Hue Quan 1');

      expect(results.any((e) => e.name == '142 Nguyễn Huệ'), isTrue);
    });

    test('search should fall back to a street when the house number is missing',
        () async {
      final results = await poiRepo.search('142 Nguyen Suy');

      expect(results.any((e) => e.category == 'street'), isTrue);
      expect(results.any((e) => e.name == 'Nguyễn Súy'), isTrue);
    });

    test('search should return empty list for invalid or short query',
        () async {
      expect(await poiRepo.search(''), isEmpty);
      expect(await poiRepo.search('a'), isEmpty);
    });

    test('search should sanitize special FTS5 wildcard characters safely without crashing',
        () async {
      // Các ký tự đặc biệt FTS5 như *, ", ', (, ), -, :, ^, ~
      final specialQueries = [
        'phở*',
        '"Phở"',
        "phở'",
        '(phở)',
        'phở-bò',
        'category:food',
        'pho^2',
        'pho~',
        '***',
        '""',
      ];

      for (final query in specialQueries) {
        // Đảm bảo không ném Exception / crash SQLite
        final results = await poiRepo.search(query);
        expect(results, isA<List<PoiModel>>());
      }
    });
  });

  group('PoiRepository - Spatial R*Tree Tests', () {
    test('searchInBounds should return POIs within TP.HCM bounding box',
        () async {
      // Bounding box bao trọn TP.HCM (lat: 10.70..10.85, lon: 106.60..106.75)
      final results = await poiRepo.searchInBounds(
        minLat: 10.70,
        maxLat: 10.85,
        minLon: 106.60,
        maxLon: 106.75,
      );

      expect(results, isNotEmpty);
      expect(results.every((e) => e.city == 'TP.HCM'), isTrue);
      expect(results.any((e) => e.name == 'Phở Hòa Pasteur'), isTrue);
      expect(results.any((e) => e.name == 'Bệnh viện Chợ Rẫy'), isTrue);
      expect(results.any((e) => e.name == 'Khách sạn Rex Sài Gòn'), isTrue);
      expect(results.any((e) => e.name == 'ATM Vietcombank Bến Thành'), isTrue);

      // Địa điểm ở Hà Nội không được xuất hiện trong Bounding Box này
      expect(results.any((e) => e.name == 'Phở Thìn Lò Đúc'), isFalse);
    });

    test('searchInBounds should return POIs within Hanoi bounding box',
        () async {
      // Bounding box bao trọn Hà Nội (lat: 21.00..21.05, lon: 105.80..105.90)
      final results = await poiRepo.searchInBounds(
        minLat: 21.00,
        maxLat: 21.05,
        minLon: 105.80,
        maxLon: 105.90,
      );

      expect(results, isNotEmpty);
      expect(results.every((e) => e.city == 'Hà Nội'), isTrue);
      expect(results.any((e) => e.name == 'Phở Thìn Lò Đúc'), isTrue);
      expect(results.any((e) => e.name == 'Highlands Coffee Nhà Thờ'), isTrue);
    });

    test('searchInBounds with query filter should return matching POIs inside bounding box only',
        () async {
      // Query "phở" in TP.HCM bbox -> returns only 'Phở Hòa Pasteur'
      final hcmPho = await poiRepo.searchInBounds(
        minLat: 10.70,
        maxLat: 10.85,
        minLon: 106.60,
        maxLon: 106.75,
        query: 'phở',
      );

      expect(hcmPho.length, 1);
      expect(hcmPho.first.name, 'Phở Hòa Pasteur');

      // Query "coffee" / "cafe" in Hanoi bbox -> returns 'Highlands Coffee Nhà Thờ'
      final hnCafe = await poiRepo.searchInBounds(
        minLat: 21.00,
        maxLat: 21.05,
        minLon: 105.80,
        maxLon: 105.90,
        query: 'coffee',
      );

      expect(hnCafe.length, 1);
      expect(hnCafe.first.name, 'Highlands Coffee Nhà Thờ');
    });

    test('searchInBounds with category filter should return matching category POIs only',
        () async {
      // Category "hotel" in TP.HCM bbox -> returns only 'Khách sạn Rex Sài Gòn'
      final hcmHotel = await poiRepo.searchInBounds(
        minLat: 10.70,
        maxLat: 10.85,
        minLon: 106.60,
        maxLon: 106.75,
        category: 'hotel',
      );

      expect(hcmHotel.length, 1);
      expect(hcmHotel.first.name, 'Khách sạn Rex Sài Gòn');
      expect(hcmHotel.first.category, 'hotel');

      // Category "food" in TP.HCM bbox -> returns 'Phở Hòa Pasteur'
      final hcmFood = await poiRepo.searchInBounds(
        minLat: 10.70,
        maxLat: 10.85,
        minLon: 106.60,
        maxLon: 106.75,
        category: 'food',
      );

      expect(hcmFood.any((e) => e.name == 'Phở Hòa Pasteur'), isTrue);
      expect(hcmFood.every((e) => e.category == 'food'), isTrue);
    });

    test('searchInBounds returns nearest candidates before applying the limit',
        () async {
      final candidates = [
        {
          'name': 'Coffee Center',
          'name_ascii': 'Coffee Center',
          'category': 'coffee',
          'sub_category': 'cafe',
          'lat': 10.775,
          'lon': 106.675,
          'city': 'TP.HCM',
        },
        {
          'name': 'Coffee East',
          'name_ascii': 'Coffee East',
          'category': 'coffee',
          'sub_category': 'cafe',
          'lat': 10.775,
          'lon': 106.676,
          'city': 'TP.HCM',
        },
        {
          'name': 'Coffee West',
          'name_ascii': 'Coffee West',
          'category': 'coffee',
          'sub_category': 'cafe',
          'lat': 10.775,
          'lon': 106.61,
          'city': 'TP.HCM',
        },
      ];
      for (final candidate in candidates) {
        await db.insert('poi', candidate);
      }

      final results = await poiRepo.searchInBounds(
        minLat: 10.70,
        maxLat: 10.85,
        minLon: 106.60,
        maxLon: 106.75,
        category: 'coffee',
        limit: 2,
      );

      expect(results.map((poi) => poi.name).toList(),
          ['Coffee Center', 'Coffee East']);
    });
  });

  group('PoiRepository - ID & Benchmark Tests', () {
    test('getPoiById should return correct PoiModel or null', () async {
      final poi = await poiRepo.getPoiById(1);
      expect(poi, isNotNull);
      expect(poi!.id, 1);
      expect(poi.name, 'Phở Thìn Lò Đúc');

      final notFound = await poiRepo.getPoiById(9999);
      expect(notFound, isNull);
    });

    test('Query performance benchmark should be under 50ms', () async {
      final stopwatch = Stopwatch()..start();
      final results = await poiRepo.search('bệnh viện');
      stopwatch.stop();

      expect(results, isNotEmpty);
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });

    test('getSuggestions should return distinct place names matching query prefix', () async {
      final suggestions = await poiRepo.getSuggestions('ph');
      expect(suggestions, isNotEmpty);
      expect(suggestions.contains('Phở Thìn Lò Đúc'), isTrue);
      expect(suggestions.contains('Phở Hòa Pasteur'), isTrue);

      final empty = await poiRepo.getSuggestions('');
      expect(empty, isEmpty);

      final accentedSuggestions = await poiRepo.getSuggestions('Phở');
      expect(accentedSuggestions, isNotEmpty);
      expect(accentedSuggestions.every((s) => s.contains('Phở')), isTrue);
    });
  });
}
