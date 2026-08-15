import 'package:hive_flutter/hive_flutter.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Backward compatibility alias
typedef RecentSearchService = IRecentSearchService;

class RecentSearchServiceImpl implements IRecentSearchService {
  static const String boxName = 'recent_searches_box';
  static const String _storageKey = 'recent_search_history';
  static const int _maxRecentSearches = 20;

  final SharedPreferences? _customPrefs;
  final Box<dynamic>? _customBox;
  Box<dynamic>? _box;

  RecentSearchServiceImpl({
    SharedPreferences? customPrefs,
    Box<dynamic>? customBox,
  })  : _customPrefs = customPrefs,
        _customBox = customBox;

  static final RecentSearchServiceImpl instance = RecentSearchServiceImpl();

  Future<Box<dynamic>?> _getBox() async {
    if (_customBox != null) return _customBox;
    if (_customPrefs != null) return null;

    if (_box != null && _box!.isOpen) return _box!;
    try {
      if (Hive.isBoxOpen(boxName)) {
        _box = Hive.box<dynamic>(boxName);
        return _box;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<SharedPreferences> _getPrefs() async {
    if (_customPrefs != null) return _customPrefs;
    return await SharedPreferences.getInstance();
  }

  @override
  Future<List<String>> getRecentSearches() async {
    final box = await _getBox();
    if (box != null) {
      final val = box.get(_storageKey);
      if (val is List) {
        return List<String>.from(val.map((e) => e.toString()));
      }
      return [];
    }

    final prefs = await _getPrefs();
    return List<String>.from(prefs.getStringList(_storageKey) ?? []);
  }

  @override
  Future<void> addRecentSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    final currentList = await getRecentSearches();

    // Xóa từ khóa nếu đã tồn tại để đưa lên đầu danh sách
    currentList
        .removeWhere((item) => item.toLowerCase() == cleanQuery.toLowerCase());
    currentList.insert(0, cleanQuery);

    // Giới hạn số lượng tối đa
    if (currentList.length > _maxRecentSearches) {
      currentList.removeRange(_maxRecentSearches, currentList.length);
    }

    final box = await _getBox();
    if (box != null) {
      await box.put(_storageKey, currentList);
      return;
    }

    final prefs = await _getPrefs();
    await prefs.setStringList(_storageKey, currentList);
  }

  @override
  Future<void> removeRecentSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    final currentList = await getRecentSearches();
    currentList
        .removeWhere((item) => item.toLowerCase() == cleanQuery.toLowerCase());

    final box = await _getBox();
    if (box != null) {
      await box.put(_storageKey, currentList);
      return;
    }

    final prefs = await _getPrefs();
    await prefs.setStringList(_storageKey, currentList);
  }

  @override
  Future<void> clearRecentSearches() async {
    final box = await _getBox();
    if (box != null) {
      await box.delete(_storageKey);
      return;
    }

    final prefs = await _getPrefs();
    await prefs.remove(_storageKey);
  }
}
