import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class ActiveTripServiceImpl implements IActiveTripService {
  static const String boxName = 'active_trip_session_box';
  static const String activeSessionKey = 'current_active_session';

  final Box<dynamic>? _customBox;
  Box<dynamic>? _box;
  Future<void> _mutationQueue = Future.value();

  ActiveTripServiceImpl({
    Box<dynamic>? customBox,
  }) : _customBox = customBox;

  static final ActiveTripServiceImpl instance = ActiveTripServiceImpl();

  Future<T> _enqueueMutation<T>(Future<T> Function() action) {
    final next = _mutationQueue.then((_) => action());
    _mutationQueue = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  Future<Box<dynamic>> _getBox() async {
    if (_customBox != null) return _customBox;
    if (_box != null && _box!.isOpen) return _box!;

    try {
      if (!Hive.isBoxOpen(boxName)) {
        _box = await Hive.openBox<dynamic>(boxName);
      } else {
        _box = Hive.box<dynamic>(boxName);
      }
    } catch (e, stack) {
      DLog.error('❌ [ActiveTripService] Lỗi mở Hive box $boxName: $e', e, stack);
      rethrow;
    }
    return _box!;
  }

  @override
  Future<void> init() async {
    try {
      await _getBox();
    } catch (e, stack) {
      DLog.error('❌ [ActiveTripService] Initialization failed for $boxName: $e', e, stack);
    }
  }

  @override
  Future<void> saveActiveSession(ActiveTripSnapshot snapshot) {
    return _enqueueMutation(() async {
      try {
        final box = await _getBox();
        await box.put(activeSessionKey, snapshot.toMap());
        DLog.info(
          '💾 [ActiveTripService] Saved active trip session snapshot (Dest: "${snapshot.destinationName}", Dist: ${snapshot.totalDistanceTraveledMeters.toStringAsFixed(1)}m)',
        );
      } catch (e, stack) {
        DLog.error(
          '❌ [ActiveTripService] Failed to persist active trip snapshot to Hive: $e',
          e,
          stack,
        );
        rethrow;
      }
    });
  }

  @override
  Future<ActiveTripSnapshot?> getActiveSession() async {
    try {
      final box = await _getBox();
      final val = box.get(activeSessionKey);
      if (val == null) return null;

      if (val is Map) {
        try {
          final map = Map<String, dynamic>.from(val);
          final snapshot = ActiveTripSnapshot.fromMap(map);

          // Kiểm tra hạn sử dụng (không quá 24h)
          if (!snapshot.isValid()) {
            DLog.warning(
              '⚠️ [ActiveTripService] Active trip session expired (> 24h). Clearing session...',
            );
            await clearActiveSession();
            return null;
          }

          return snapshot;
        } catch (corruptedError) {
          DLog.warning(
            '⚠️ [ActiveTripService] Corrupted active session record in Hive: $corruptedError. Auto-clearing...',
          );
          await clearActiveSession();
          return null;
        }
      }

      // Bản ghi không đúng cấu trúc Map
      await clearActiveSession();
      return null;
    } catch (e, stack) {
      DLog.error('❌ [ActiveTripService] Error retrieving active session: $e', e, stack);
      return null;
    }
  }

  @override
  Future<void> clearActiveSession() {
    return _enqueueMutation(() async {
      try {
        final box = await _getBox();
        await box.delete(activeSessionKey);
        DLog.info('🧹 [ActiveTripService] Cleared active trip session');
      } catch (e, stack) {
        DLog.error('❌ [ActiveTripService] Error clearing active session: $e', e, stack);
        rethrow;
      }
    });
  }

  @override
  Future<bool> hasActiveSession() async {
    try {
      final session = await getActiveSession();
      return session != null;
    } catch (_) {
      return false;
    }
  }
}
