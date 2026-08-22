import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
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
  Future<void> close() async {
    await _eventController.close();
  }

  @override
  Stream<BoxEvent> watch({dynamic key}) => _eventController.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHiveBox fakeBox;
  late TripServiceImpl service;

  final sampleTrip1 = TripRecordModel(
    id: 'trip_1',
    startTime: DateTime(2026, 8, 22, 8, 0),
    endTime: DateTime(2026, 8, 22, 8, 20),
    durationMs: 1200000,
    distanceMeters: 8500.0,
    avgSpeedKmh: 25.5,
    topSpeedKmh: 48.0,
    destinationName: 'Bệnh viện Chợ Rẫy',
    originName: 'Quận 1',
    hasArrived: true,
    vehicleProfile: 'motorcycle',
    createdAt: DateTime(2026, 8, 22, 8, 20),
  );

  final sampleTrip2 = TripRecordModel(
    id: 'trip_2',
    startTime: DateTime(2026, 8, 22, 14, 0),
    endTime: DateTime(2026, 8, 22, 14, 45),
    durationMs: 2700000,
    distanceMeters: 22000.0,
    avgSpeedKmh: 29.3,
    topSpeedKmh: 60.0,
    destinationName: 'Sân bay Tân Sơn Nhất',
    originName: 'Quận 7',
    hasArrived: true,
    vehicleProfile: 'car',
    createdAt: DateTime(2026, 8, 22, 14, 45),
  );

  setUp(() {
    fakeBox = FakeHiveBox();
    service = TripServiceImpl(customBox: fakeBox);
  });

  tearDown(() async {
    await fakeBox.close();
  });

  group('TripServiceImpl Tests with FakeHiveBox', () {
    test('init, saveTrip and getTrips stores and retrieves data correctly', () async {
      await service.init();
      await service.saveTrip(sampleTrip1);
      await service.saveTrip(sampleTrip2);

      final retrieved = await service.getTrips();
      expect(retrieved.length, equals(2));
      // Sắp xếp chuyến đi mới nhất (sampleTrip2) lên trước
      expect(retrieved[0].id, equals('trip_2'));
      expect(retrieved[1].id, equals('trip_1'));
    });

    test('getTripById returns matching trip or null if not found', () async {
      await service.saveTrip(sampleTrip1);

      final trip = await service.getTripById('trip_1');
      expect(trip, isNotNull);
      expect(trip!.id, equals('trip_1'));
      expect(trip.destinationName, equals('Bệnh viện Chợ Rẫy'));

      final nonExistent = await service.getTripById('non_existent');
      expect(nonExistent, isNull);
    });

    test('deleteTrip removes single record', () async {
      await service.saveTrip(sampleTrip1);
      await service.saveTrip(sampleTrip2);

      await service.deleteTrip('trip_1');
      final list = await service.getTrips();
      expect(list.length, equals(1));
      expect(list.first.id, equals('trip_2'));
    });

    test('clearAllTrips wipes all stored trips', () async {
      await service.saveTrip(sampleTrip1);
      await service.saveTrip(sampleTrip2);

      await service.clearAllTrips();
      final list = await service.getTrips();
      expect(list, isEmpty);
    });

    test('getTrips gracefully skips corrupted Hive records without failing', () async {
      await service.saveTrip(sampleTrip1);
      // Giả lập bản ghi bị hỏng trong Hive Box (thiếu id hoặc sai schema)
      fakeBox._storage['corrupted_trip'] = {'bad_key': 12345};

      final list = await service.getTrips();
      expect(list.length, equals(1));
      expect(list.first.id, equals('trip_1'));
    });

    test('rethrows Hive exceptions when underlying storage fails', () async {
      fakeBox.shouldThrow = true;
      expect(() => service.getTrips(), throwsException);
      expect(() => service.getTripById('trip_1'), throwsException);
      expect(() => service.saveTrip(sampleTrip1), throwsException);
      expect(() => service.deleteTrip('trip_1'), throwsException);
      expect(() => service.clearAllTrips(), throwsException);
    });

    test('watchTrips stream emits updated list when storage changes', () async {
      final stream = service.watchTrips();

      expectLater(
        stream,
        emitsInOrder([
          isEmpty,
          hasLength(1),
          hasLength(2),
        ]),
      );

      await Future.delayed(const Duration(milliseconds: 10));
      await service.saveTrip(sampleTrip1);
      await Future.delayed(const Duration(milliseconds: 10));
      await service.saveTrip(sampleTrip2);
    });
  });
}
