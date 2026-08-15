import 'package:s_map/interfaces/interfaces.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Backward compatibility alias
typedef RecentSearchService = IRecentSearchService;

class RecentSearchServiceImpl implements IRecentSearchService {
  static const String _storageKey = 'recent_search_history';
  static const int _maxRecentSearches = 20;

  final SharedPreferences? _customPrefs;

  RecentSearchServiceImpl({SharedPreferences? customPrefs})
      : _customPrefs = customPrefs;

  static final RecentSearchServiceImpl instance = RecentSearchServiceImpl();

  Future<SharedPreferences> _getPrefs() async {
    if (_customPrefs != null) return _customPrefs;
    return await SharedPreferences.getInstance();
  }

  @override
  Future<List<String>> getRecentSearches() async {
    final prefs = await _getPrefs();
    return List<String>.from(prefs.getStringList(_storageKey) ?? []);
  }

  @override
  Future<void> addRecentSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    final prefs = await _getPrefs();
    final List<String> currentList =
        List<String>.from(prefs.getStringList(_storageKey) ?? []);

    // Xóa từ khóa nếu đã tồn tại để đưa lên đầu danh sách
    currentList.removeWhere(
        (item) => item.toLowerCase() == cleanQuery.toLowerCase());
    currentList.insert(0, cleanQuery);

    // Giới hạn số lượng tối đa
    if (currentList.length > _maxRecentSearches) {
      currentList.removeRange(_maxRecentSearches, currentList.length);
    }

    await prefs.setStringList(_storageKey, currentList);
  }

  @override
  Future<void> removeRecentSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    final prefs = await _getPrefs();
    final List<String> currentList =
        List<String>.from(prefs.getStringList(_storageKey) ?? []);

    currentList.removeWhere(
        (item) => item.toLowerCase() == cleanQuery.toLowerCase());
    await prefs.setStringList(_storageKey, currentList);
  }

  @override
  Future<void> clearRecentSearches() async {
    final prefs = await _getPrefs();
    await prefs.remove(_storageKey);
  }
}
