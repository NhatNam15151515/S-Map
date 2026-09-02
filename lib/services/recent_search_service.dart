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
  final IFireStoreService? _fireStoreService;
  final IFirebaseAuthService? _authService;
  Box<dynamic>? _box;

  static IFireStoreService? defaultFireStoreService;
  static IFirebaseAuthService? defaultAuthService;

  RecentSearchServiceImpl({
    SharedPreferences? customPrefs,
    Box<dynamic>? customBox,
    IFireStoreService? fireStoreService,
    IFirebaseAuthService? authService,
  })  : _customPrefs = customPrefs,
        _customBox = customBox,
        _fireStoreService = fireStoreService ?? defaultFireStoreService,
        _authService = authService ?? defaultAuthService;

  static final RecentSearchServiceImpl instance = RecentSearchServiceImpl();

  Future<Box<dynamic>?> _getBox() async {
    if (_customBox != null) return _customBox;
    if (_customPrefs != null) return null;

    if (_box != null && _box!.isOpen) return _box!;
    try {
      // The app opens this box during bootstrap. Do not implicitly open it
      // here: detached tests/consumers intentionally use the documented
      // SharedPreferences fallback when Hive has not been initialized.
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

  String? get _userId => _authService?.currentUser?.uid;

  Future<void> _saveLocal(List<String> values) async {
    final box = await _getBox();
    if (box != null) {
      await box.put(_storageKey, values);
      return;
    }
    final prefs = await _getPrefs();
    await prefs.setStringList(_storageKey, values);
  }

  List<String> _mergeSearches(
    Iterable<String> first,
    Iterable<String> second,
  ) {
    final result = <String>[];
    final seen = <String>{};
    for (final value in [...first, ...second]) {
      final clean = value.trim();
      final key = clean.toLowerCase();
      if (clean.isEmpty || !seen.add(key)) continue;
      result.add(clean);
      if (result.length == _maxRecentSearches) break;
    }
    return result;
  }

  @override
  Future<List<String>> getRecentSearches() async {
    List<String> local;
    final box = await _getBox();
    if (box != null) {
      final val = box.get(_storageKey);
      if (val is List) {
        local = List<String>.from(val.map((e) => e.toString()));
      } else {
        local = [];
      }
    } else {
      final prefs = await _getPrefs();
      local = List<String>.from(prefs.getStringList(_storageKey) ?? []);
    }

    final userId = _userId;
    final fireStoreService = _fireStoreService;
    if (userId == null || fireStoreService == null) return local;

    try {
      final cloud = await fireStoreService.getSearchQueries(userId);
      final merged = _mergeSearches(cloud, local);
      if (merged.length != local.length ||
          !merged.asMap().entries.every((entry) => entry.value == local[entry.key])) {
        await _saveLocal(merged);
      }
      return merged;
    } catch (_) {
      // Search must remain usable offline; the local history is authoritative
      // until Firestore becomes available again.
      return local;
    }
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

    await _saveLocal(currentList);

    final userId = _userId;
    final fireStoreService = _fireStoreService;
    if (userId != null && fireStoreService != null) {
      try {
        await fireStoreService.saveSearchQuery(userId, cleanQuery);
      } catch (_) {}
    }
  }

  @override
  Future<void> removeRecentSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    final currentList = await getRecentSearches();
    currentList
        .removeWhere((item) => item.toLowerCase() == cleanQuery.toLowerCase());

    await _saveLocal(currentList);

    final userId = _userId;
    final fireStoreService = _fireStoreService;
    if (userId != null && fireStoreService != null) {
      try {
        await fireStoreService.deleteSearchQuery(userId, cleanQuery);
      } catch (_) {}
    }
  }

  @override
  Future<void> clearRecentSearches() async {
    final box = await _getBox();
    if (box != null) {
      await box.delete(_storageKey);
    } else {
      final prefs = await _getPrefs();
      await prefs.remove(_storageKey);
    }

    final userId = _userId;
    final fireStoreService = _fireStoreService;
    if (userId != null && fireStoreService != null) {
      try {
        await fireStoreService.clearSearchQueries(userId);
      } catch (_) {}
    }
  }
}
