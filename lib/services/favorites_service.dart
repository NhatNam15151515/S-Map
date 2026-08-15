import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

// Backward compatibility alias
typedef FavoritesService = IFavoritesService;

class FavoritesServiceImpl implements IFavoritesService {
  static const String boxName = 'favorites_box';

  final Box<dynamic>? _customBox;
  Box<dynamic>? _box;

  FavoritesServiceImpl({Box<dynamic>? customBox}) : _customBox = customBox;

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
      return list;
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
    } catch (e) {
      DLog.error('Lỗi thêm favorite vào Hive: $e');
    }
  }

  @override
  Future<void> removeFavorite(String poiId) async {
    try {
      final box = await _getBox();
      await box.delete(poiId);
    } catch (e) {
      DLog.error('Lỗi xóa favorite khỏi Hive: $e');
    }
  }

  @override
  Future<bool> isFavorite(String poiId) async {
    try {
      final box = await _getBox();
      return box.containsKey(poiId);
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
