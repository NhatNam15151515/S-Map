import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';

// Backward compatibility alias.
typedef RecentSearchService = IRecentSearchService;

/// Local-first search history, scoped to the active account.
///
/// Keeping each user's cache under a separate Hive key prevents history from
/// leaking between accounts on a shared device. Signed-in history is synced
/// to Firestore in the background and remains usable offline.
class RecentSearchServiceImpl implements IRecentSearchService {
  static const String boxName = 'recent_searches_box';
  static const String _legacyKey = 'recent_search_history';
  static const String _recentKeyPrefix = 'recent_search_history';
  static const String _popularKeyPrefix = 'frequent_search_cache';
  static const int _maxRecentSearches = 20;
  static const int _maxPopularSearches = 50;
  static const Duration _cloudTimeout = Duration(seconds: 2);

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

  String? get _userId {
    final id = _authService?.currentUser?.uid;
    return id == null || id.isEmpty ? null : id;
  }

  String _scopedKey(String prefix, String? userId) {
    final scope = userId ?? 'guest';
    return '$prefix:$scope';
  }

  Future<Box<dynamic>?> _getBox() async {
    if (_customBox != null) return _customBox;
    if (_customPrefs != null) return null;
    if (_box != null && _box!.isOpen) return _box!;
    try {
      // The app opens Hive during bootstrap. Detached callers use preferences
      // instead of implicitly initializing Hive.
      if (Hive.isBoxOpen(boxName)) _box = Hive.box<dynamic>(boxName);
      return _box;
    } catch (_) {
      return null;
    }
  }

  Future<SharedPreferences> _getPrefs() async =>
      _customPrefs ?? await SharedPreferences.getInstance();

  Future<dynamic> _readValue(String key) async {
    final box = await _getBox();
    if (box != null) return box.get(key);
    final prefs = await _getPrefs();
    return prefs.get(key);
  }

  Future<void> _writeValue(String key, dynamic value) async {
    final box = await _getBox();
    if (box != null) {
      await box.put(key, value);
    } else {
      final prefs = await _getPrefs();
      if (value is List<String>) {
        await prefs.setStringList(key, value);
      } else {
        await prefs.setString(key, jsonEncode(value));
      }
    }
  }

  Future<void> _deleteValue(String key) async {
    final box = await _getBox();
    if (box != null) {
      await box.delete(key);
    } else {
      final prefs = await _getPrefs();
      await prefs.remove(key);
    }
  }

  Future<List<String>> _readLocalRecentSearches(String? userId) async {
    try {
      final key = _scopedKey(_recentKeyPrefix, userId);
      final stored = await _readValue(key);
      if (stored is List) {
        return stored.map((value) => value.toString()).toList();
      }
      // Migrate only the old anonymous cache. Never expose it to a signed-in
      // account because it may have been written by another user.
      if (userId == null) {
        final legacy = await _readValue(_legacyKey);
        if (legacy is List) {
          final migrated = legacy.map((value) => value.toString()).toList();
          await _writeValue(key, migrated);
          return migrated;
        }
      }
    } catch (e) {
      DLog.error('Lỗi đọc local recent searches: $e');
    }
    return [];
  }

  Future<void> _saveLocalRecentSearches(
    List<String> searches,
    String? userId,
  ) async {
    try {
      await _writeValue(_scopedKey(_recentKeyPrefix, userId), searches);
    } catch (e) {
      DLog.error('Lỗi lưu local recent searches: $e');
    }
  }

  Future<Map<String, Map<String, dynamic>>> _readLocalPopularity(
    String? userId,
  ) async {
    try {
      final raw = await _readValue(_scopedKey(_popularKeyPrefix, userId));
      if (raw is Map) {
        return raw.map((key, value) => MapEntry(
              key.toString(),
              Map<String, dynamic>.from(value as Map),
            ));
      }
      if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(
                key.toString(),
                Map<String, dynamic>.from(value as Map),
              ));
        }
      }
    } catch (e) {
      DLog.error('Lỗi đọc local search popularity: $e');
    }
    return {};
  }

  Future<void> _saveLocalPopularity(
    Map<String, Map<String, dynamic>> popularity,
    String? userId,
  ) async {
    try {
      await _writeValue(_scopedKey(_popularKeyPrefix, userId), popularity);
    } catch (e) {
      DLog.error('Lỗi lưu local search popularity: $e');
    }
  }

  List<String> _mergeSearches(
    Iterable<String> first,
    Iterable<String> second, {
    int limit = _maxRecentSearches,
  }) {
    final seen = <String>{};
    final merged = <String>[];
    for (final value in [...first, ...second]) {
      final query = value.trim();
      if (query.isNotEmpty && seen.add(query.toLowerCase())) {
        merged.add(query);
        if (merged.length >= limit) break;
      }
    }
    return merged;
  }

  @override
  Future<List<String>> getRecentSearches() async {
    final userId = _userId;
    final local = await _readLocalRecentSearches(userId);
    if (userId == null || _fireStoreService == null) return local;
    try {
      final cloud = await _fireStoreService
          .getSearchQueries(userId, limit: _maxRecentSearches)
          .timeout(_cloudTimeout);
      final merged = _mergeSearches(local, cloud);
      if (!_sameItems(merged, local)) {
        await _saveLocalRecentSearches(merged, userId);
      }
      return merged;
    } catch (e) {
      DLog.error('Lỗi đồng bộ recent searches: $e');
      return local;
    }
  }

  @override
  Future<List<String>> getFrequentSearches({int limit = 10}) async {
    if (limit <= 0) return [];
    final userId = _userId;
    final popularity = await _readLocalPopularity(userId);
    final local = popularity.values.toList()
      ..sort((a, b) {
        final countComparison =
            (b['count'] as int? ?? 0).compareTo(a['count'] as int? ?? 0);
        if (countComparison != 0) return countComparison;
        return (b['updatedAt'] as int? ?? 0)
            .compareTo(a['updatedAt'] as int? ?? 0);
      });
    final localQueries = local
        .map((entry) => (entry['query'] ?? '').toString())
        .where((query) => query.isNotEmpty)
        .toList();
    if (userId == null || _fireStoreService == null) {
      return localQueries.take(limit).toList();
    }
    try {
      final cloud = await _fireStoreService
          .getFrequentSearchQueries(userId, limit: limit)
          .timeout(_cloudTimeout);
      return _mergeSearches(localQueries, cloud, limit: limit);
    } catch (e) {
      DLog.error('Lỗi nạp frequent searches: $e');
      return localQueries.take(limit).toList();
    }
  }

  @override
  Future<void> addRecentSearch(
    String query, {
    Map<String, dynamic>? destination,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;
    final userId = _userId;
    final recent = await _readLocalRecentSearches(userId);
    await _saveLocalRecentSearches(
      _mergeSearches([cleanQuery], recent),
      userId,
    );
    final popularity = await _readLocalPopularity(userId);
    final key = cleanQuery.toLowerCase();
    final existing = popularity[key];
    popularity[key] = {
      'query': cleanQuery,
      'count': (existing?['count'] as int? ?? 0) + 1,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    if (popularity.length > _maxPopularSearches) {
      final ranked = popularity.entries.toList()
        ..sort((a, b) =>
            (b.value['updatedAt'] as int? ?? 0)
                .compareTo(a.value['updatedAt'] as int? ?? 0));
      popularity
        ..clear()
        ..addEntries(ranked.take(_maxPopularSearches));
    }
    await _saveLocalPopularity(popularity, userId);
    if (userId != null && _fireStoreService != null) {
      unawaited(_fireStoreService
          .saveSearchQuery(
            userId,
            cleanQuery,
            destination: destination,
          )
          .timeout(_cloudTimeout)
          .catchError((Object error) {
        DLog.error('Lỗi lưu search query lên Firestore: $error');
      }));
    }
  }

  @override
  Future<void> removeRecentSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;
    final userId = _userId;
    final recent = await _readLocalRecentSearches(userId);
    recent.removeWhere(
        (item) => item.toLowerCase() == cleanQuery.toLowerCase());
    await _saveLocalRecentSearches(recent, userId);
    final popularity = await _readLocalPopularity(userId);
    popularity.remove(cleanQuery.toLowerCase());
    await _saveLocalPopularity(popularity, userId);
    if (userId != null && _fireStoreService != null) {
      await _fireStoreService
          .deleteSearchQuery(userId, cleanQuery)
          .timeout(_cloudTimeout)
          .catchError((Object error) {
        DLog.error('Lỗi xóa search query trên Firestore: $error');
      });
    }
  }

  @override
  Future<void> clearRecentSearches() async {
    final userId = _userId;
    await _saveLocalRecentSearches([], userId);
    await _saveLocalPopularity({}, userId);
    if (userId == null) {
      try {
        await _deleteValue(_legacyKey);
      } catch (e) {
        DLog.error('Lỗi xóa legacy recent searches: $e');
      }
    } else if (_fireStoreService != null) {
      await _fireStoreService
          .clearSearchQueries(userId)
          .timeout(_cloudTimeout)
          .catchError((Object error) {
        DLog.error('Lỗi xóa search queries trên Firestore: $error');
      });
    }
  }

  bool _sameItems(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}
