import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

// Backward compatibility alias
typedef FavoritesService = IFavoritesService;

class FavoritesServiceImpl implements IFavoritesService {
  static const String boxName = 'favorites_box';

  final Box<dynamic>? _customBox;
  final IFireStoreService? _fireStoreService;
  final IFirebaseAuthService? _authService;
  Box<dynamic>? _box;
  String? _cloudSyncUserId;
  final Set<String> _cloudSyncedKeys = {};

  static IFireStoreService? defaultFireStoreService;
  static IFirebaseAuthService? defaultAuthService;

  FavoritesServiceImpl({
    Box<dynamic>? customBox,
    IFireStoreService? fireStoreService,
    IFirebaseAuthService? authService,
  })  : _customBox = customBox,
        _fireStoreService = fireStoreService ?? defaultFireStoreService,
        _authService = authService ?? defaultAuthService;

  static final FavoritesServiceImpl instance = FavoritesServiceImpl();

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

  String _getPoiKey(PoiModel poi) {
    if (poi.id != null) return poi.id.toString();
    if (poi.osmId != null && poi.osmId!.isNotEmpty) return poi.osmId!;
    return poi.name;
  }

  String _getCloudPoiKey(PoiModel poi) => PoiCategoryHelper.getPoiKey(poi);

  String? get _userId => _authService?.currentUser?.uid;

  void _prepareCloudSyncUser(String? userId) {
    if (_cloudSyncUserId == userId) return;
    _cloudSyncUserId = userId;
    _cloudSyncedKeys.clear();
  }

  Future<bool> _syncFavoriteToCloud(PoiModel poi) async {
    final userId = _userId;
    final fireStoreService = _fireStoreService;
    if (userId == null || fireStoreService == null) return false;
    try {
      await fireStoreService.savePlace(userId, {
        ...poi.toMap(),
        'poiKey': _getCloudPoiKey(poi),
      });
      return true;
    } catch (e) {
      DLog.warning('⚠️ Không thể đồng bộ favorite lên Firestore: $e');
      return false;
    }
  }

  @override
  Future<void> init() async {
    await _getBox();
  }

  @override
  Future<List<PoiModel>> getFavorites() async {
    try {
      final box = await _getBox();
      final List<PoiModel> list = [];

      for (final key in box.keys) {
        final val = box.get(key);
        if (val is Map) {
          final map = Map<String, dynamic>.from(val);
          list.add(PoiModel.fromMap(map));
        }
      }
      final userId = _userId;
      final fireStoreService = _fireStoreService;
      if (userId == null || fireStoreService == null) return list;
      _prepareCloudSyncUser(userId);

      // Migrate local favorites created before Google sign-in. Keep a small
      // in-memory set so Hive watcher reloads do not write the same rows over
      // and over again during one app session.
      await Future.wait(list.map((poi) async {
        final key = _getCloudPoiKey(poi);
        if (_cloudSyncedKeys.contains(key)) return;
        if (await _syncFavoriteToCloud(poi)) {
          _cloudSyncedKeys.add(key);
        }
      }));

      try {
        final cloudRows = await fireStoreService.getSavedPlaces(userId);
        final merged = <String, PoiModel>{
          for (final poi in list) _getCloudPoiKey(poi): poi,
        };
        for (final row in cloudRows) {
          final poi = PoiModel.fromMap(row);
          if (poi.name.isEmpty || (poi.lat == 0 && poi.lon == 0)) continue;
          final cloudKey = _getCloudPoiKey(poi);
          merged[cloudKey] = poi;
          _cloudSyncedKeys.add(cloudKey);
          await box.put(_getPoiKey(poi), poi.toMap());
        }
        return merged.values.toList();
      } catch (e) {
        DLog.warning('⚠️ Không thể tải favorite từ Firestore: $e');
        return list;
      }
    } catch (e) {
      DLog.error('Lỗi lấy danh sách favorites từ Hive: $e');
      return [];
    }
  }

  @override
  Future<void> addFavorite(PoiModel poi) async {
    try {
      final box = await _getBox();
      final key = _getPoiKey(poi);
      await box.put(key, poi.toMap());
      _prepareCloudSyncUser(_userId);
      if (await _syncFavoriteToCloud(poi)) {
        _cloudSyncedKeys.add(_getCloudPoiKey(poi));
      }
    } catch (e) {
      DLog.error('Lỗi thêm favorite vào Hive: $e');
    }
  }

  @override
  Future<void> removeFavorite(String poiId) async {
    try {
      final box = await _getBox();
      await box.delete(poiId);
      // FavoritesCubit uses the canonical `id:...` / `osm:...` key, while
      // older Hive entries used the raw id. Remove both forms safely.
      if (poiId.startsWith('id:')) {
        await box.delete(poiId.substring(3));
      } else if (poiId.startsWith('osm:')) {
        await box.delete(poiId.substring(4));
      }
      final userId = _userId;
      final fireStoreService = _fireStoreService;
      _cloudSyncedKeys.remove(poiId);
      if (userId != null && fireStoreService != null) {
        await fireStoreService.deleteSavedPlace(userId, poiId);
      }
    } catch (e) {
      DLog.error('Lỗi xóa favorite khỏi Hive: $e');
    }
  }

  @override
  Future<bool> isFavorite(String poiId) async {
    try {
      final box = await _getBox();
      if (box.containsKey(poiId)) return true;
      if (poiId.startsWith('id:') && box.containsKey(poiId.substring(3))) {
        return true;
      }
      if (poiId.startsWith('osm:') && box.containsKey(poiId.substring(4))) {
        return true;
      }
      return false;
    } catch (e) {
      DLog.error('Lỗi kiểm tra favorite trong Hive: $e');
      return false;
    }
  }

  @override
  Future<void> clearFavorites() async {
    try {
      final box = await _getBox();
      await box.clear();
      _cloudSyncedKeys.clear();
      final userId = _userId;
      final fireStoreService = _fireStoreService;
      if (userId != null && fireStoreService != null) {
        await fireStoreService.clearSavedPlaces(userId);
      }
    } catch (e) {
      DLog.error('Lỗi xóa toàn bộ favorites trong Hive: $e');
    }
  }

  @override
  Stream<List<PoiModel>> watchFavorites() async* {
    final box = await _getBox();
    yield await getFavorites();
    await for (final _ in box.watch()) {
      yield await getFavorites();
    }
  }
}
