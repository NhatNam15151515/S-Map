import 'radix_trie.dart';

class FuzzyMatcher {
  FuzzyMatcher._();

  static int maxEditDistance(String query) {
    final length = query.trim().length;
    if (length <= 3) return 0;
    if (length <= 5) return 1;
    return 2;
  }

  static List<int> fuzzyPrefixSearch(
    RadixTrie trie,
    String query, {
    int limit = 10,
  }) {
    final cleanQuery = RadixTrie.normalizeKey(query);
    final maxDistance = maxEditDistance(cleanQuery);
    if (cleanQuery.isEmpty || maxDistance == 0) return const [];

    final candidates = <(int id, int distance, int prominence)>{};
    for (final entry in trie.entries()) {
      if (entry.$1.isEmpty) continue;
      final candidateKey = entry.$1;
      final comparable = candidateKey.length > cleanQuery.length
          ? candidateKey.substring(0, cleanQuery.length)
          : candidateKey;
      final distance = _levenshtein(cleanQuery, comparable);
      if (distance > maxDistance) continue;
      for (final result in entry.$2) {
        final key = (result.poiId, distance, result.prominence);
        candidates.add(key);
      }
    }

    final sorted = candidates.toList()
      ..sort((a, b) {
        final distanceComparison = a.$2.compareTo(b.$2);
        return distanceComparison == 0
            ? b.$3.compareTo(a.$3)
            : distanceComparison;
      });
    return sorted.take(limit).map((result) => result.$1).toList(growable: false);
  }

  static int _levenshtein(String left, String right) {
    if (left == right) return 0;
    if (left.isEmpty) return right.length;
    if (right.isEmpty) return left.length;

    var previous = List<int>.generate(right.length + 1, (index) => index);
    for (var leftIndex = 0; leftIndex < left.length; leftIndex++) {
      final current = <int>[leftIndex + 1];
      for (var rightIndex = 0; rightIndex < right.length; rightIndex++) {
        final substitutionCost = left.codeUnitAt(leftIndex) ==
                right.codeUnitAt(rightIndex)
            ? 0
            : 1;
        current.add([
          current.last + 1,
          previous[rightIndex + 1] + 1,
          previous[rightIndex] + substitutionCost,
        ].reduce((a, b) => a < b ? a : b));
      }
      previous = current;
    }
    return previous.last;
  }
}
