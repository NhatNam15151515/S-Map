import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';

class TripSyncServiceImpl implements ITripSyncService {
  static const String boxName = 'trip_sync_queue_box';

  final Box<dynamic>? _customBox;
  Box<dynamic>? _box;

  TripSyncServiceImpl({Box<dynamic>? customBox}) : _customBox = customBox;

  static final TripSyncServiceImpl instance = TripSyncServiceImpl();

  Future<Box<dynamic>> _getBox() async {
    if (_customBox != null) return _customBox;
    if (_box != null && _box!.isOpen) return _box!;

    try {
      if (!Hive.isBoxOpen(boxName)) {
        _box = await Hive.openBox<dynamic>(boxName);
      } else {
        _box = Hive.box<dynamic>(boxName);
      }
    } catch (e) {
      DLog.error('Lỗi mở Hive box $boxName: $e');
      _box = await Hive.openBox<dynamic>(boxName);
    }
    return _box!;
  }

  @override
  Future<void> init() async {
    await _getBox();
  }

  @override
  Future<void> enqueueTrip(String tripId) async {
    try {
      final box = await _getBox();
      await box.put(tripId, DateTime.now().toIso8601String());
    } catch (e) {
      DLog.error('❌ [TripSyncService] Error enqueueing trip $tripId: $e');
      rethrow;
    }
  }

  @override
  Future<List<String>> getQueuedTripIds() async {
    try {
      final box = await _getBox();
      return box.keys.map((k) => k.toString()).toList();
    } catch (e) {
      DLog.error('❌ [TripSyncService] Error getting queued trip IDs: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeQueuedTrip(String tripId) async {
    try {
      final box = await _getBox();
      await box.delete(tripId);
    } catch (e) {
      DLog.error('❌ [TripSyncService] Error removing queued trip $tripId: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearQueue() async {
    try {
      final box = await _getBox();
      await box.clear();
    } catch (e) {
      DLog.error('❌ [TripSyncService] Error clearing sync queue: $e');
      rethrow;
    }
  }

  @override
  Future<int> getQueueCount() async {
    try {
      final box = await _getBox();
      return box.length;
    } catch (e) {
      DLog.error('❌ [TripSyncService] Error getting queue count: $e');
      return 0;
    }
  }

  @override
  Stream<int> watchQueueCount() async* {
    final box = await _getBox();
    yield box.length;
    await for (final _ in box.watch()) {
      yield box.length;
    }
  }
}
