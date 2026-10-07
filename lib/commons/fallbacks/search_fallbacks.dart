import 'package:s_map/interfaces/interfaces.dart';

/// Fallback / No-Op implementation for IRecentSearchService in decoupled/testing environments
class NoOpRecentSearchService implements IRecentSearchService {
  final List<String> _searches = [];

  @override
  Future<void> addRecentSearch(
    String query, {
    Map<String, dynamic>? destination,
  }) async {
    _searches.remove(query);
    _searches.insert(0, query);
  }

  @override
  Future<void> clearRecentSearches() async {
    _searches.clear();
  }

  @override
  Future<List<String>> getRecentSearches() async {
    return List.unmodifiable(_searches);
  }

  @override
  Future<List<String>> getFrequentSearches({int limit = 10}) async =>
      List.unmodifiable(_searches.take(limit));

  @override
  Future<void> removeRecentSearch(String query) async {
    _searches.remove(query);
  }
}
