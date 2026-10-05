import 'package:s_map/models/models.dart';

/// Cache ngắn hạn cho kết quả search.
///
/// Đây là cache tăng tốc, không phải dữ liệu người dùng: chỉ giữ một số ít
/// kết quả cuối trong RAM. Không ghi Hive để tránh tạo một kho dữ liệu POI thứ
/// hai và để cache tự sạch khi app khởi động lại.
class SearchCacheService {
  static const String cacheVersion = 'search-v1';
  static const int maxEntries = 24;

  static final SearchCacheService instance = SearchCacheService();

  final Map<String, Object> _entries = {};

  List<PoiModel>? getPois(String key, {required int limit}) {
    final value = _touch(key);
    if (value is! List<PoiModel>) return null;
    return value.take(limit).toList(growable: false);
  }

  List<String>? getSuggestions(String key, {required int limit}) {
    final value = _touch(key);
    if (value is! List<String>) return null;
    return value.take(limit).toList(growable: false);
  }

  void putPois(String key, List<PoiModel> results) {
    _put(key, List<PoiModel>.of(results, growable: false));
  }

  void putSuggestions(String key, List<String> results) {
    _put(key, List<String>.of(results, growable: false));
  }

  /// Xóa cache khi bộ dữ liệu POI được thay thế trong lúc app đang chạy.
  void clear() => _entries.clear();

  Object? _touch(String key) {
    final value = _entries.remove(key);
    if (value == null) return null;
    _entries[key] = value;
    return value;
  }

  void _put(String key, Object value) {
    _entries.remove(key);
    _entries[key] = value;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }
}
