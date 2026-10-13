import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'firebase_auth_service.dart';
import 'firebase_firestore_service.dart';
import 'trip_sync_service.dart';

// Backward compatibility alias
typedef TripService = ITripService;

class TripServiceImpl implements ITripService {
  static const String boxName = 'trip_history_box';

  final Box<dynamic>? _customBox;
  final ITripSyncService _syncService;
  final IFireStoreService? _fireStoreService;
  final IFirebaseAuthService? _authService;
  Box<dynamic>? _box;

  static IFireStoreService? defaultFireStoreService;
  static IFirebaseAuthService? defaultAuthService;

  TripServiceImpl({
    Box<dynamic>? customBox,
    ITripSyncService? syncService,
    IFireStoreService? fireStoreService,
    IFirebaseAuthService? authService,
  })  : _customBox = customBox,
        _syncService = syncService ?? TripSyncServiceImpl.instance,
        _fireStoreService = fireStoreService,
        _authService = authService;

  static final TripServiceImpl instance = TripServiceImpl();

  IFireStoreService? get _effectiveFireStoreService =>
      _fireStoreService ?? defaultFireStoreService ?? FireStoreService.instance;

  IFirebaseAuthService? get _effectiveAuthService =>
      _authService ?? defaultAuthService ?? FirebaseAuthService.instance;

  String? get _userId => _effectiveAuthService?.currentUser?.uid;

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
      final localTrips = <String, TripRecordModel>{};
      for (final key in box.keys) {
        final val = box.get(key);
        if (val is Map) {
          try {
            final map = Map<String, dynamic>.from(val);
            final trip = TripRecordModel.fromMap(map);
            if (trip.id.isNotEmpty) localTrips[trip.id] = trip;
          } catch (corruptedRecordError) {
            DLog.warning(
              '⚠️ [TripService] Skipping corrupted trip record at key "$key": $corruptedRecordError',
            );
          }
        }
      }

      final userId = _userId;
      final fireStoreService = _effectiveFireStoreService;
      if (userId != null && fireStoreService != null) {
        try {
          final cloudTrips = await fireStoreService.getSyncedTrips(userId);
          for (final trip in cloudTrips) {
            if (trip.id.isEmpty) continue;
            final previous = localTrips[trip.id];
            localTrips[trip.id] = trip;
            if (previous != trip) {
              await box.put(trip.id, trip.toMap());
            }
          }
        } catch (e) {
          DLog.warning(
              '⚠️ [TripService] Không thể tải lịch sử chuyến đi từ Firestore: $e');
        }
      }

      final trips = localTrips.values.toList();
      trips.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return trips;
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

  @override
  Future<void> saveTrip(TripRecordModel trip) async {
    try {
      final box = await _getBox();
      await box.put(trip.id, trip.toMap());
      if (!trip.isSynced) {
        await _syncService.enqueueTrip(trip.id);
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
      await _syncService.removeQueuedTrip(id);
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
      await _syncService.clearQueue();
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
        final syncedTrip = trip.copyWith(isSynced: true);
        final box = await _getBox();
        await box.put(id, syncedTrip.toMap());
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
