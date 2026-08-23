import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'trip_sync_service.dart';

// Backward compatibility alias
typedef TripService = ITripService;

class TripServiceImpl implements ITripService {
  static const String boxName = 'trip_history_box';

  final Box<dynamic>? _customBox;
  final ITripSyncService? _syncService;
  Box<dynamic>? _box;

  TripServiceImpl({
    Box<dynamic>? customBox,
    ITripSyncService? syncService,
  })  : _customBox = customBox,
        _syncService = syncService;

  static final TripServiceImpl instance = TripServiceImpl();

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
  Future<List<TripRecordModel>> getTrips() async {
    try {
      final box = await _getBox();
      final List<TripRecordModel> list = [];

      for (final key in box.keys) {
        try {
          final val = box.get(key);
          if (val is Map) {
            final map = Map<String, dynamic>.from(val);
            list.add(TripRecordModel.fromMap(map));
          }
        } catch (recordError) {
          DLog.warning(
              '⚠️ [TripService] Skipping corrupted trip record at key "$key": $recordError');
        }
      }
      // Sắp xếp chuyến đi mới nhất lên trước
      list.sort((a, b) => b.startTime.compareTo(a.startTime));
      return list;
    } catch (e) {
      DLog.error('❌ [TripService] Failed to access Hive box for trips: $e');
      rethrow;
    }
  }

  @override
  Future<TripRecordModel?> getTripById(String id) async {
    try {
      final box = await _getBox();
      final val = box.get(id);
      if (val is Map) {
        final map = Map<String, dynamic>.from(val);
        return TripRecordModel.fromMap(map);
      }
      return null;
    } catch (e) {
      DLog.error('❌ [TripService] Error getting trip $id: $e');
      rethrow;
    }
  }

  ITripSyncService get _effectiveSyncService =>
      _syncService ?? TripSyncServiceImpl.instance;

  @override
  Future<void> saveTrip(TripRecordModel trip) async {
    try {
      final box = await _getBox();
      await box.put(trip.id, trip.toMap());
      if (!trip.isSynced) {
        await _effectiveSyncService.enqueueTrip(trip.id);
      }
    } catch (e) {
      DLog.error('❌ [TripService] Error saving trip: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteTrip(String id) async {
    try {
      final box = await _getBox();
      await box.delete(id);
      await _effectiveSyncService.removeQueuedTrip(id);
    } catch (e) {
      DLog.error('❌ [TripService] Error deleting trip: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearAllTrips() async {
    try {
      final box = await _getBox();
      await box.clear();
      await _effectiveSyncService.clearQueue();
    } catch (e) {
      DLog.error('❌ [TripService] Error clearing trips: $e');
      rethrow;
    }
  }

  @override
  Future<void> markTripAsSynced(String id) async {
    try {
      final trip = await getTripById(id);
      if (trip != null) {
        final updated = trip.copyWith(isSynced: true);
        await saveTrip(updated);
      }
    } catch (e) {
      DLog.error('❌ [TripService] Error marking trip $id as synced: $e');
      rethrow;
    }
  }

  @override
  Stream<List<TripRecordModel>> watchTrips() async* {
    final box = await _getBox();
    yield await getTrips();
    await for (final _ in box.watch()) {
      yield await getTrips();
    }
  }
}
