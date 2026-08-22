import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

// Backward compatibility alias
typedef CustomRouteService = ICustomRouteService;

class CustomRouteServiceImpl implements ICustomRouteService {
  static const String boxName = 'custom_routes_box';

  final Box<dynamic>? _customBox;
  Box<dynamic>? _box;

  CustomRouteServiceImpl({Box<dynamic>? customBox}) : _customBox = customBox;

  static final CustomRouteServiceImpl instance = CustomRouteServiceImpl();

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
  Future<List<CustomRouteModel>> getSavedRoutes() async {
    try {
      final box = await _getBox();
      final List<CustomRouteModel> list = [];

      for (final key in box.keys) {
        try {
          final val = box.get(key);
          if (val is Map) {
            final map = Map<String, dynamic>.from(val);
            list.add(CustomRouteModel.fromMap(map));
          }
        } catch (recordError) {
          DLog.warning(
              '⚠️ [CustomRouteService] Skipping corrupted route record at key "$key": $recordError');
        }
      }
      // Sắp xếp lộ trình mới nhất lên trước
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      DLog.error('❌ [CustomRouteService] Failed to access Hive box for custom routes: $e');
      rethrow;
    }
  }

  @override
  Future<CustomRouteModel?> getRouteById(String id) async {
    try {
      final box = await _getBox();
      final val = box.get(id);
      if (val is Map) {
        final map = Map<String, dynamic>.from(val);
        return CustomRouteModel.fromMap(map);
      }
      return null;
    } catch (e) {
      DLog.error('❌ [CustomRouteService] Error getting custom route $id: $e');
      rethrow;
    }
  }

  @override
  Future<void> saveRoute(CustomRouteModel route) async {
    try {
      final box = await _getBox();
      await box.put(route.id, route.toMap());
    } catch (e) {
      DLog.error('❌ [CustomRouteService] Error saving custom route: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteRoute(String id) async {
    try {
      final box = await _getBox();
      await box.delete(id);
    } catch (e) {
      DLog.error('❌ [CustomRouteService] Error deleting custom route: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearAllRoutes() async {
    try {
      final box = await _getBox();
      await box.clear();
    } catch (e) {
      DLog.error('❌ [CustomRouteService] Error clearing custom routes: $e');
      rethrow;
    }
  }

  @override
  Stream<List<CustomRouteModel>> watchSavedRoutes() async* {
    final box = await _getBox();
    yield await getSavedRoutes();
    await for (final _ in box.watch()) {
      yield await getSavedRoutes();
    }
  }
}
