import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:s_map/search_engine/search_engine.dart';

void main() {
  test('radix trie returns prefix matches ordered by prominence', () {
    final trie = RadixTrie();
    trie.insert('benh vien cho ray', 1, 200);
    trie.insert('benh vien nhan dan', 2, 100);
    trie.insert('benh vien tu nhan', 3, 50);

    expect(trie.prefixSearch('benh vien', limit: 2).map((item) => item.poiId), [1, 2]);
    expect(trie.prefixSearch('benh vien cho', limit: 2).single.poiId, 1);
  });

  test('strict normalization preserves Vietnamese consonant distinctions', () {
    expect(VnPhoneticEncoder.normalize('Trường Chinh'), 'truong chinh');
    expect(VnPhoneticEncoder.normalize('Xã Sơn'), 'xa son');
    expect(
      VnPhoneticEncoder.encodePhonetic('Trường Chinh'),
      'cuong cinh',
    );
  });

  test('phonetic fallback and fuzzy matcher tolerate input errors', () {
    final trie = RadixTrie();
    trie.insert(VnPhoneticEncoder.encodePhonetic('Bệnh viện'), 10, 100);

    expect(VnPhoneticEncoder.normalize('Bệnh viện'), 'benh vien');
    expect(
      FuzzyMatcher.fuzzyPrefixSearch(trie, 'benh vien', limit: 1),
      [10],
    );
  });

  test('search debouncer emits immediate and delayed passes', () {
    final debouncer = SearchDebouncer();
    final calls = <String>[];

    fakeAsync((async) {
      debouncer.onQueryChanged('pho', calls.add);
      expect(calls, ['pho']);
      async.elapse(const Duration(milliseconds: 149));
      expect(calls, ['pho']);
      async.elapse(const Duration(milliseconds: 1));
      expect(calls, ['pho', 'pho']);
    });

    debouncer.dispose();
  });
}
