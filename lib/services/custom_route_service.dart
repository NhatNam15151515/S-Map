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
  final IFireStoreService? _fireStoreService;
  final IFirebaseAuthService? _authService;
  Box<dynamic>? _box;

  static IFireStoreService? defaultFireStoreService;
  static IFirebaseAuthService? defaultAuthService;

  CustomRouteServiceImpl({
    Box<dynamic>? customBox,
    IFireStoreService? fireStoreService,
    IFirebaseAuthService? authService,
  })  : _customBox = customBox,
        _fireStoreService = fireStoreService ?? defaultFireStoreService,
        _authService = authService ?? defaultAuthService;

  static final CustomRouteServiceImpl instance = CustomRouteServiceImpl();

  String? get _userId => _authService?.currentUser?.uid;

  Future<void> _syncRouteToCloud(CustomRouteModel route) async {
    final userId = _userId;
    final fireStoreService = _fireStoreService;
    if (userId == null || fireStoreService == null) return;
    try {
      await fireStoreService.saveCustomRoute(userId, route.toMap());
    } catch (e) {
      DLog.warning('⚠️ Không thể đồng bộ lộ trình vẽ lên Firestore: $e');
    }
  }

  Future<void> _deleteRouteFromCloud(String routeId) async {
    final userId = _userId;
    final fireStoreService = _fireStoreService;
    if (userId == null || fireStoreService == null) return;
    try {
      await fireStoreService.deleteCustomRoute(userId, routeId);
    } catch (e) {
      DLog.warning('⚠️ Không thể xóa lộ trình vẽ trên Firestore: $e');
    }
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
      final localRoutes = <String, CustomRouteModel>{};

      for (final key in box.keys) {
        try {
          final val = box.get(key);
          if (val is Map) {
            final map = Map<String, dynamic>.from(val);
            final route = CustomRouteModel.fromMap(map);
            if (route.id.isNotEmpty) localRoutes[route.id] = route;
          }
        } catch (recordError) {
          DLog.warning(
              '⚠️ [CustomRouteService] Skipping corrupted route record at key "$key": $recordError');
        }
      }

      final userId = _userId;
      final fireStoreService = _fireStoreService;
      if (userId != null && fireStoreService != null) {
        try {
          final cloudRows = await fireStoreService.getCustomRoutes(userId);
          final cloudRouteIds = <String>{};
          for (final row in cloudRows) {
            try {
              final route = CustomRouteModel.fromMap(row);
              if (route.id.isEmpty) continue;
              cloudRouteIds.add(route.id);
              final previous = localRoutes[route.id];
              localRoutes[route.id] = route;
              // Do not write unchanged cloud rows back into Hive: the Hive
              // watcher would otherwise trigger an endless reload loop.
              if (previous != route) {
                await box.put(route.id, route.toMap());
              }
            } catch (cloudRecordError) {
              DLog.warning(
                  '⚠️ [CustomRouteService] Skipping corrupted cloud route: $cloudRecordError');
            }
          }
          // Migrate routes that were created locally before the user signed
          // in. If the same id already exists in cloud, the cloud copy wins.
          for (final route in localRoutes.values) {
            if (!cloudRouteIds.contains(route.id)) {
              await _syncRouteToCloud(route);
            }
          }
        } catch (e) {
          DLog.warning('⚠️ Không thể tải lộ trình vẽ từ Firestore: $e');
        }
      }

      final list = localRoutes.values.toList();
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
      await _syncRouteToCloud(route);
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
      await _deleteRouteFromCloud(id);
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
      final userId = _userId;
      final fireStoreService = _fireStoreService;
      if (userId != null && fireStoreService != null) {
        try {
          await fireStoreService.clearCustomRoutes(userId);
        } catch (e) {
          DLog.warning('⚠️ Không thể xóa lộ trình vẽ trên Firestore: $e');
        }
      }
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
