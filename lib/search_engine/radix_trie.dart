class TrieResult {
  final int poiId;
  final int prominence;

  const TrieResult(this.poiId, this.prominence);
}

class TrieNode {
  String edge;
  final Map<int, TrieNode> children;
  final List<TrieResult> topResults;
  int maxDescendantProminence;

  TrieNode({
    required this.edge,
    Map<int, TrieNode>? children,
    List<TrieResult>? topResults,
    this.maxDescendantProminence = 0,
  })  : children = children ?? <int, TrieNode>{},
        topResults = topResults ?? <TrieResult>[];

  void record(int poiId, int prominence, {int topK = 10}) {
    final existingIndex = topResults.indexWhere((item) => item.poiId == poiId);
    if (existingIndex >= 0) {
      if (topResults[existingIndex].prominence >= prominence) return;
      topResults.removeAt(existingIndex);
    }
    topResults.add(TrieResult(poiId, prominence));
    topResults.sort((a, b) {
      final prominenceComparison = b.prominence.compareTo(a.prominence);
      return prominenceComparison == 0
          ? a.poiId.compareTo(b.poiId)
          : prominenceComparison;
    });
    if (topResults.length > topK) {
      topResults.removeRange(topK, topResults.length);
    }
    if (prominence > maxDescendantProminence) {
      maxDescendantProminence = prominence;
    }
  }
}

class RadixTrie {
  static const int defaultTopK = 10;

  final TrieNode root;
  final int topK;

  RadixTrie({TrieNode? root, this.topK = defaultTopK})
      : root = root ?? TrieNode(edge: '');

  void insert(String rawKey, int poiId, int prominence) {
    final key = normalizeKey(rawKey);
    if (key.isEmpty) return;
    _insert(root, key, 0, poiId, prominence);
  }

  void _insert(
    TrieNode parent,
    String key,
    int offset,
    int poiId,
    int prominence,
  ) {
    parent.record(poiId, prominence, topK: topK);
    if (offset == key.length) return;

    final firstCodeUnit = key.codeUnitAt(offset);
    final remaining = key.substring(offset);
    final child = parent.children[firstCodeUnit];
    if (child == null) {
      final newChild = TrieNode(edge: remaining);
      parent.children[firstCodeUnit] = newChild;
      newChild.record(poiId, prominence, topK: topK);
      return;
    }

    final commonLength = _commonPrefixLength(child.edge, remaining);
    if (commonLength == child.edge.length) {
      _insert(child, key, offset + commonLength, poiId, prominence);
      return;
    }

    final split = TrieNode(edge: child.edge.substring(0, commonLength));
    split.topResults.addAll(child.topResults);
    split.maxDescendantProminence = child.maxDescendantProminence;
    split.children[child.edge.codeUnitAt(commonLength)] = TrieNode(
      edge: child.edge.substring(commonLength),
      children: child.children,
      topResults: child.topResults,
      maxDescendantProminence: child.maxDescendantProminence,
    );
    parent.children[firstCodeUnit] = split;

    final newOffset = offset + commonLength;
    if (newOffset == key.length) {
      split.record(poiId, prominence, topK: topK);
      return;
    }

    final newChild = TrieNode(edge: key.substring(newOffset));
    newChild.record(poiId, prominence, topK: topK);
    split.children[key.codeUnitAt(newOffset)] = newChild;
    split.record(poiId, prominence, topK: topK);
  }

  List<TrieResult> prefixSearch(String rawPrefix, {int limit = 10}) {
    final prefix = normalizeKey(rawPrefix);
    if (prefix.isEmpty) return const [];

    var node = root;
    var offset = 0;
    while (offset < prefix.length) {
      final child = node.children[prefix.codeUnitAt(offset)];
      if (child == null) return const [];
      final remaining = prefix.substring(offset);
      if (remaining.length <= child.edge.length) {
        return child.edge.startsWith(remaining)
            ? child.topResults.take(limit).toList(growable: false)
            : const [];
      }
      if (!remaining.startsWith(child.edge)) return const [];
      offset += child.edge.length;
      node = child;
    }
    return node.topResults.take(limit).toList(growable: false);
  }

  Iterable<(String key, List<TrieResult> results)> entries() sync* {
    yield* _entries(root, '');
  }

  Iterable<(String key, List<TrieResult> results)> _entries(
    TrieNode node,
    String prefix,
  ) sync* {
    final key = '$prefix${node.edge}';
    if (node.topResults.isNotEmpty) {
      yield (key, node.topResults);
    }
    for (final child in node.children.values) {
      yield* _entries(child, key);
    }
  }

  static int _commonPrefixLength(String left, String right) {
    final length = left.length < right.length ? left.length : right.length;
    var index = 0;
    while (index < length && left.codeUnitAt(index) == right.codeUnitAt(index)) {
      index++;
    }
    return index;
  }

  static String normalizeKey(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');
}
