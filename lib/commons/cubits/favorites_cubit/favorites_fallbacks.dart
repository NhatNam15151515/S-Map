import 'dart:async';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

/// Fallback / No-Op implementation for IFavoritesService in decoupled/testing environments
class NoOpFavoritesService implements IFavoritesService {
  final Map<String, PoiModel> _storage = {};
  final StreamController<List<PoiModel>> _controller =
      StreamController<List<PoiModel>>.broadcast();

  String _getKey(PoiModel poi) {
    if (poi.id != null) return poi.id.toString();
    if (poi.osmId != null && poi.osmId!.isNotEmpty) return poi.osmId!;
    return poi.name;
  }

  @override
  Future<void> init() async {}

  @override
  Future<List<PoiModel>> getFavorites() async {
    return _storage.values.toList();
  }

  @override
  Future<void> addFavorite(PoiModel poi) async {
    final key = _getKey(poi);
    _storage[key] = poi;
    _controller.add(_storage.values.toList());
  }

  @override
  Future<void> removeFavorite(String poiId) async {
    _storage.remove(poiId);
    _controller.add(_storage.values.toList());
  }

  @override
  Future<bool> isFavorite(String poiId) async {
    return _storage.containsKey(poiId);
  }

  @override
  Future<void> clearFavorites() async {
    _storage.clear();
    _controller.add([]);
  }

  @override
  Stream<List<PoiModel>> watchFavorites() => _controller.stream;
}
