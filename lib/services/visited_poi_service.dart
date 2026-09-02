import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

/// Local-first history of places the user actually reached.
class VisitedPoiServiceImpl implements IVisitedPoiService {
  static const String boxName = 'visited_pois_box';

  final Box<dynamic>? _customBox;
  final IFireStoreService? _fireStoreService;
  final IFirebaseAuthService? _authService;
  Box<dynamic>? _box;
  String? _cloudSyncUserId;
  final Set<String> _cloudSyncedKeys = {};

  static IFireStoreService? defaultFireStoreService;
  static IFirebaseAuthService? defaultAuthService;

  VisitedPoiServiceImpl({
    Box<dynamic>? customBox,
    IFireStoreService? fireStoreService,
    IFirebaseAuthService? authService,
  })  : _customBox = customBox,
        _fireStoreService = fireStoreService ?? defaultFireStoreService,
        _authService = authService ?? defaultAuthService;

  static final VisitedPoiServiceImpl instance = VisitedPoiServiceImpl();

  Future<Box<dynamic>> _getBox() async {
    final customBox = _customBox;
    if (customBox != null) return customBox;
    if (_box != null && _box!.isOpen) return _box!;
    try {
      _box = Hive.isBoxOpen(boxName)
          ? Hive.box<dynamic>(boxName)
          : await Hive.openBox<dynamic>(boxName);
    return _box!;
    } catch (e) {
      DLog.error('Lỗi mở Hive box $boxName: $e');
      rethrow;
    }
  }

  String? get _userId => _authService?.currentUser?.uid;

  String _key(PoiModel poi) => PoiCategoryHelper.getPoiKey(poi);

  void _prepareCloudSyncUser(String? userId) {
    if (_cloudSyncUserId == userId) return;
    _cloudSyncUserId = userId;
    _cloudSyncedKeys.clear();
  }

  Future<bool> _syncVisitedToCloud(PoiModel poi) async {
    final userId = _userId;
    final fireStoreService = _fireStoreService;
    if (userId == null || fireStoreService == null) return false;
    try {
      await fireStoreService.saveVisitedPlace(userId, {
        ...poi.toMap(),
        'poiKey': _key(poi),
      });
      return true;
    } catch (e) {
      DLog.warning('⚠️ Không thể đồng bộ visited POI lên Firestore: $e');
      return false;
    }
  }

  PoiModel? _parse(dynamic value) {
    if (value is! Map) return null;
    final poi = PoiModel.fromMap(Map<String, dynamic>.from(value));
    if (poi.name.isEmpty || (poi.lat == 0 && poi.lon == 0)) return null;
    return poi;
  }

  @override
  Future<void> init() async {
    await _getBox();
  }

  @override
  Future<List<PoiModel>> getVisitedPois() async {
    final box = await _getBox();
    final local = <String, PoiModel>{};
    for (final key in box.keys) {
      final poi = _parse(box.get(key));
      if (poi != null) local[_key(poi)] = poi;
    }

    final userId = _userId;
    final fireStoreService = _fireStoreService;
    if (userId == null || fireStoreService == null) {
      return local.values.toList();
    }
    _prepareCloudSyncUser(userId);
    // Migrate local visit records created before the user signed in. The
    // session set prevents repeated writes from the Hive watcher.
    await Future.wait(local.values.map((poi) async {
      final key = _key(poi);
      if (_cloudSyncedKeys.contains(key)) return;
      if (await _syncVisitedToCloud(poi)) {
        _cloudSyncedKeys.add(key);
      }
    }));
    try {
      final cloudRows = await fireStoreService.getVisitedPlaces(userId);
      for (final row in cloudRows) {
        final poi = _parse(row);
        if (poi == null) continue;
        final key = _key(poi);
        local[key] = poi;
        _cloudSyncedKeys.add(key);
        await box.put(key, poi.toMap());
      }
    } catch (e) {
      DLog.warning('⚠️ Không thể tải visited POI từ Firestore: $e');
    }
    return local.values.toList();
  }

  @override
  Future<void> recordVisited(PoiModel poi) async {
    final box = await _getBox();
    await box.put(_key(poi), poi.toMap());

    final userId = _userId;
    final fireStoreService = _fireStoreService;
    if (userId != null && fireStoreService != null) {
      // Local Hive is the success path; cloud sync must never delay arrival.
      _prepareCloudSyncUser(userId);
      unawaited(() async {
        if (_cloudSyncedKeys.contains(_key(poi))) return;
        if (await _syncVisitedToCloud(poi)) {
          _cloudSyncedKeys.add(_key(poi));
        }
      }());
    }
  }

  @override
  Future<void> clearVisitedPois() async {
    final box = await _getBox();
    await box.clear();
    _cloudSyncedKeys.clear();
    final userId = _userId;
    final fireStoreService = _fireStoreService;
    if (userId != null && fireStoreService != null) {
      await fireStoreService.clearVisitedPlaces(userId);
    }
  }

  @override
  Stream<List<PoiModel>> watchVisitedPois() async* {
    final box = await _getBox();
    yield await getVisitedPois();
    await for (final _ in box.watch()) {
      yield await getVisitedPois();
    }
  }
}
