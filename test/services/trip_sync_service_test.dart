import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
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
  int get length => _storage.length;

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
  late FakeHiveBox fakeBox;
  late TripSyncServiceImpl syncService;

  setUp(() {
    fakeBox = FakeHiveBox();
    syncService = TripSyncServiceImpl(customBox: fakeBox);
  });

  group('TripSyncServiceImpl Offline Queue Tests', () {
    test('enqueueTrip successfully puts tripId in Hive box', () async {
      await syncService.enqueueTrip('trip_001');

      expect(await syncService.getQueueCount(), 1);
      final ids = await syncService.getQueuedTripIds();
      expect(ids, contains('trip_001'));
    });

    test('removeQueuedTrip removes item from Hive box', () async {
      await syncService.enqueueTrip('trip_001');
      await syncService.enqueueTrip('trip_002');
      expect(await syncService.getQueueCount(), 2);

      await syncService.removeQueuedTrip('trip_001');
      final ids = await syncService.getQueuedTripIds();
      expect(ids.length, 1);
      expect(ids, contains('trip_002'));
    });

    test('clearQueue empties the queue', () async {
      await syncService.enqueueTrip('trip_001');
      await syncService.enqueueTrip('trip_002');
      await syncService.enqueueTrip('trip_003');

      await syncService.clearQueue();
      expect(await syncService.getQueueCount(), 0);
      expect(await syncService.getQueuedTripIds(), isEmpty);
    });

    test('watchQueueCount emits updated count when items are enqueued or removed', () async {
      final stream = syncService.watchQueueCount();

      expectLater(
        stream,
        emitsInOrder([
          0,
          1,
          2,
          1,
        ]),
      );

      await Future.delayed(const Duration(milliseconds: 10));
      await syncService.enqueueTrip('trip_001');
      await Future.delayed(const Duration(milliseconds: 10));
      await syncService.enqueueTrip('trip_002');
      await Future.delayed(const Duration(milliseconds: 10));
      await syncService.removeQueuedTrip('trip_001');
    });

    test('error handling when Hive operations throw', () async {
      fakeBox.shouldThrow = true;
      expect(() => syncService.enqueueTrip('trip_err'), throwsA(isA<Exception>()));
      expect(() => syncService.getQueuedTripIds(), throwsA(isA<Exception>()));
      expect(() => syncService.removeQueuedTrip('trip_err'), throwsA(isA<Exception>()));
      expect(() => syncService.clearQueue(), throwsA(isA<Exception>()));
      expect(await syncService.getQueueCount(), 0);
    });
  });
}
