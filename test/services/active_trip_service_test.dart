import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/services/services.dart';

class FakeHiveBox implements Box<dynamic> {
  final Map<dynamic, dynamic> _storage = {};
  final StreamController<BoxEvent> _eventController =
      StreamController<BoxEvent>.broadcast();
  bool shouldThrow = false;

  @override
  bool get isOpen => true;

  @override
  Iterable<dynamic> get keys {
    if (shouldThrow) throw Exception('Hive keys read failed');
    return _storage.keys;
  }

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) {
    if (shouldThrow) throw Exception('Hive get failed');
    return _storage.containsKey(key) ? _storage[key] : defaultValue;
  }

  @override
  Future<void> put(dynamic key, dynamic value) async {
    if (shouldThrow) throw Exception('Hive put failed');
    _storage[key] = value;
    _eventController.add(BoxEvent(key, value, false));
  }

  @override
  Future<void> delete(dynamic key) async {
    if (shouldThrow) throw Exception('Hive delete failed');
    final prev = _storage.remove(key);
    _eventController.add(BoxEvent(key, prev, true));
  }

  @override
  Future<int> clear() async {
    if (shouldThrow) throw Exception('Hive clear failed');
    final count = _storage.length;
    _storage.clear();
    _eventController.add(BoxEvent(null, null, false));
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHiveBox fakeBox;
  late ActiveTripServiceImpl service;

  const sampleRoute = RouteResult(
    isSuccess: true,
    distance: 3500.0,
    time: 420000,
    points: [
      [10.7769, 106.7009], // Chợ Bến Thành
      [10.7780, 106.7020],
      [10.7795, 106.7035],
      [10.7820, 106.7050], // Landmark 81 direction
    ],
    instructions: [
      RouteInstruction(
        text: 'Đi thẳng trên đường Lê Lợi',
        streetName: 'Lê Lợi',
        distance: 1200.0,
        time: 150000,
        sign: 0,
        points: [
          [10.7769, 106.7009],
          [10.7780, 106.7020],
        ],
      ),
      RouteInstruction(
        text: 'Rẽ phải vào đường Nguyễn Huệ',
        streetName: 'Nguyễn Huệ',
        distance: 2300.0,
        time: 270000,
        sign: 2,
        points: [
          [10.7780, 106.7020],
          [10.7820, 106.7050],
        ],
      ),
    ],
  );

  final sampleSnapshot = ActiveTripSnapshot(
    origin: const RoutePoint(lat: 10.7769, lon: 106.7009),
    destination: const RoutePoint(lat: 10.7820, lon: 106.7050),
    destinationName: 'Landmark 81',
    profile: RoutingConstants.profileMopedVn,
    initialRoute: sampleRoute,
    currentSegmentIndex: 1,
    currentInstructionIndex: 1,
    tripStartTime: DateTime.now().subtract(const Duration(minutes: 15)),
    lastSavedTime: DateTime.now(),
    totalDistanceTraveledMeters: 1450.0,
    maxSpeedKmh: 42.5,
    speedSampleSum: 1250.0,
    speedSampleCount: 35,
    lastKnownLat: 10.7782,
    lastKnownLon: 106.7022,
  );

  setUp(() {
    fakeBox = FakeHiveBox();
    service = ActiveTripServiceImpl(customBox: fakeBox);
  });

  group('ActiveTripServiceImpl Authentic Tests', () {
    test('saveActiveSession persists snapshot map into Hive box', () async {
      await service.saveActiveSession(sampleSnapshot);

      final stored = fakeBox.get(ActiveTripServiceImpl.activeSessionKey);
      expect(stored, isNotNull);
      expect(stored is Map, isTrue);

      final map = Map<String, dynamic>.from(stored as Map);
      expect(map['destinationName'], equals('Landmark 81'));
      expect(map['profile'], equals(RoutingConstants.profileMopedVn));
      expect(map['totalDistanceTraveledMeters'], equals(1450.0));
      expect(map['maxSpeedKmh'], equals(42.5));
      expect(map['lastKnownLat'], equals(10.7782));
      expect(map['lastKnownLon'], equals(106.7022));
    });

    test('getActiveSession successfully deserializes valid stored snapshot', () async {
      await service.saveActiveSession(sampleSnapshot);

      final retrieved = await service.getActiveSession();
      expect(retrieved, isNotNull);
      expect(retrieved!.destinationName, equals('Landmark 81'));
      expect(retrieved.origin.lat, equals(10.7769));
      expect(retrieved.origin.lon, equals(106.7009));
      expect(retrieved.destination.lat, equals(10.7820));
      expect(retrieved.destination.lon, equals(106.7050));
      expect(retrieved.totalDistanceTraveledMeters, equals(1450.0));
      expect(retrieved.maxSpeedKmh, equals(42.5));
      expect(retrieved.speedSampleCount, equals(35));
      expect(retrieved.initialRoute.instructions.length, equals(2));
      expect(retrieved.initialRoute.instructions[0].streetName, equals('Lê Lợi'));
      expect(retrieved.initialRoute.instructions[1].streetName, equals('Nguyễn Huệ'));
    });

    test('getActiveSession returns null and clears box when session is older than 24h', () async {
      final expiredSnapshot = sampleSnapshot.copyWith(
        lastSavedTime: DateTime.now().subtract(const Duration(hours: 25)),
      );
      await service.saveActiveSession(expiredSnapshot);

      final retrieved = await service.getActiveSession();
      expect(retrieved, isNull);
      expect(fakeBox.get(ActiveTripServiceImpl.activeSessionKey), isNull);
    });

    test('getActiveSession gracefully handles and auto-clears corrupted record in Hive', () async {
      // Giả lập record bị hỏng trong Hive
      await fakeBox.put(ActiveTripServiceImpl.activeSessionKey, {
        'corrupted_field': 'invalid_data',
        // thiếu origin, destination, initialRoute, tripStartTime
      });

      final retrieved = await service.getActiveSession();
      expect(retrieved, isNull);
      expect(fakeBox.get(ActiveTripServiceImpl.activeSessionKey), isNull);
    });

    test('getActiveSession gracefully handles non-map primitive data in Hive', () async {
      await fakeBox.put(ActiveTripServiceImpl.activeSessionKey, 'corrupted_string');

      final retrieved = await service.getActiveSession();
      expect(retrieved, isNull);
      expect(fakeBox.get(ActiveTripServiceImpl.activeSessionKey), isNull);
    });

    test('clearActiveSession deletes active session key from box', () async {
      await service.saveActiveSession(sampleSnapshot);
      expect(await service.hasActiveSession(), isTrue);

      await service.clearActiveSession();
      expect(await service.hasActiveSession(), isFalse);
      expect(await service.getActiveSession(), isNull);
    });

    test('saveActiveSession rethrows exception when Hive storage fails (e.g. disk full)', () async {
      fakeBox.shouldThrow = true;

      expect(
        () => service.saveActiveSession(sampleSnapshot),
        throwsA(isA<Exception>()),
      );
    });
  });
}
