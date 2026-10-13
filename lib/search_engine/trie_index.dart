import 'dart:typed_data';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart';

import 'radix_trie.dart';

class TrieIndex {
  final RadixTrie _trie;
  final RadixTrie? _phoneticTrie;

  const TrieIndex._(this._trie, this._phoneticTrie);

  factory TrieIndex.fromBytes(Uint8List bytes) {
    final reader = _BinaryReader(bytes);
    if (reader.readAscii(4) != 'SMTR') {
      throw const FormatException('Unsupported S-Map trie index');
    }

    final version = reader.readUint8();
    if (version != 1 && version != 2) {
      throw const FormatException('Unsupported S-Map trie index version');
    }
    final trie = _readTrie(reader);
    final phoneticTrie = version == 2 ? _readTrie(reader) : null;
    return TrieIndex._(trie, phoneticTrie);
  }

  static RadixTrie _readTrie(_BinaryReader reader) {
    final nodeCount = reader.readUint32();
    final nodes = <TrieNode>[];
    final childReferences = <List<(int key, int index)>>[];
    for (var index = 0; index < nodeCount; index++) {
      final edge = reader.readUtf8(reader.readUint16());
      final childCount = reader.readUint16();
      final references = <(int key, int index)>[];
      for (var child = 0; child < childCount; child++) {
        references.add((reader.readUint32(), reader.readUint32()));
      }
      final resultCount = reader.readUint8();
      final results = <TrieResult>[];
      for (var result = 0; result < resultCount; result++) {
        results.add(TrieResult(reader.readUint32(), reader.readUint8()));
      }
      final maxProminence = reader.readUint8();
      nodes.add(TrieNode(
        edge: edge,
        topResults: results,
        maxDescendantProminence: maxProminence,
      ));
      childReferences.add(references);
    }

    for (var index = 0; index < nodes.length; index++) {
      for (final reference in childReferences[index]) {
        nodes[index].children[reference.$1] = nodes[reference.$2];
      }
    }
    if (nodes.isEmpty) throw const FormatException('Empty S-Map trie index');
    return RadixTrie(root: nodes.first);
  }

  static Future<TrieIndex> loadAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    // The index contains many small nodes. Decoding it on the UI isolate can
    // block the first search for seconds on mid-range devices.
    return Isolate.run(() => TrieIndex.fromBytes(bytes));
  }

  static Future<TrieIndex?> tryLoadAsset(String assetPath) async {
    try {
      return await loadAsset(assetPath);
    } catch (_) {
      return null;
    }
  }

  List<int> prefixSearch(String prefix, {int limit = 10}) => _trie
      .prefixSearch(prefix, limit: limit)
      .map((result) => result.poiId)
      .toList(growable: false);

  List<TrieResult> prefixSearchWithScores(String prefix, {int limit = 10}) =>
      _trie.prefixSearch(prefix, limit: limit);

  RadixTrie get trie => _trie;

  RadixTrie? get phoneticTrie => _phoneticTrie;
}

class _BinaryReader {
  final ByteData _data;
  int _offset = 0;

  _BinaryReader(Uint8List bytes)
      : _data = ByteData.sublistView(bytes);

  int readUint8() {
    final value = _data.getUint8(_offset);
    _offset++;
    return value;
  }

  int readUint16() {
    final value = _data.getUint16(_offset, Endian.little);
    _offset += 2;
    return value;
  }

  int readUint32() {
    final value = _data.getUint32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  String readAscii(int length) => String.fromCharCodes(
        _readBytes(length),
      );

  String readUtf8(int length) {
    return utf8.decode(_readBytes(length));
  }

  Uint8List _readBytes(int length) {
    final bytes = _data.buffer.asUint8List(
      _data.offsetInBytes + _offset,
      length,
    );
    _offset += length;
    return bytes;
  }
}
