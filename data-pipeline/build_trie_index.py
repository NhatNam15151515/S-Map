#!/usr/bin/env python3
"""Build the compact prefix index consumed by S-Map's offline search engine."""

import argparse
import re
import sqlite3
import struct
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path


TOP_K = 10


@dataclass
class TrieNode:
    edge: str = ""
    children: dict[str, "TrieNode"] = field(default_factory=dict)
    results: dict[int, int] = field(default_factory=dict)

    def record(self, poi_id: int, prominence: int) -> None:
        current = self.results.get(poi_id)
        if current is None or prominence > current:
            self.results[poi_id] = prominence
        self.results = dict(
            sorted(
                self.results.items(),
                key=lambda item: (-item[1], item[0]),
            )[:TOP_K]
        )


class RadixTrieBuilder:
    def __init__(self) -> None:
        self.root = TrieNode()
        self.phonetic_root = TrieNode()

    @staticmethod
    def normalize_key(value: str) -> str:
        decomposed = unicodedata.normalize("NFD", value.strip().lower())
        without_tones = "".join(
            char for char in decomposed if unicodedata.category(char) != "Mn"
        ).replace("đ", "d")
        return re.sub(r"\s+", " ", without_tones)

    @staticmethod
    def phonetic_key(value: str) -> str:
        decomposed = unicodedata.normalize("NFD", value.lower())
        without_tones = "".join(
            char for char in decomposed if unicodedata.category(char) != "Mn"
        ).replace("đ", "d")
        return (
            without_tones.replace("ch", "c")
            .replace("tr", "c")
            .replace("x", "s")
        )

    def insert(
        self,
        raw_key: str,
        poi_id: int,
        prominence: int,
        root: TrieNode | None = None,
    ) -> None:
        key = self.normalize_key(raw_key)
        if not key:
            return
        self._insert(root or self.root, key, 0, poi_id, prominence)

    def _insert(
        self,
        parent: TrieNode,
        key: str,
        offset: int,
        poi_id: int,
        prominence: int,
    ) -> None:
        parent.record(poi_id, prominence)
        if offset == len(key):
            return

        first = key[offset]
        remaining = key[offset:]
        child = parent.children.get(first)
        if child is None:
            child = TrieNode(edge=remaining)
            child.record(poi_id, prominence)
            parent.children[first] = child
            return

        common = 0
        while common < len(child.edge) and common < len(remaining):
            if child.edge[common] != remaining[common]:
                break
            common += 1

        if common == len(child.edge):
            self._insert(child, key, offset + common, poi_id, prominence)
            return

        split = TrieNode(edge=child.edge[:common], results=dict(child.results))
        old_suffix = TrieNode(
            edge=child.edge[common:],
            children=child.children,
            results=dict(child.results),
        )
        split.children[old_suffix.edge[0]] = old_suffix
        parent.children[first] = split

        new_offset = offset + common
        if new_offset == len(key):
            split.record(poi_id, prominence)
            return

        new_child = TrieNode(edge=key[new_offset:])
        new_child.record(poi_id, prominence)
        split.children[key[new_offset]] = new_child
        split.record(poi_id, prominence)

    def add_poi(self, poi_id: int, name_ascii: str, prominence: int) -> None:
        name = self.normalize_key(name_ascii)
        keys = {name, *name.split()}
        for key in keys:
            self.insert(key, poi_id, prominence)
        self.insert(
            self.phonetic_key(name),
            poi_id,
            prominence,
            root=self.phonetic_root,
        )

    def serialize(self, output_path: Path) -> None:
        def serialize_trie(root: TrieNode) -> bytearray:
            nodes: list[TrieNode] = []

            def flatten(node: TrieNode) -> int:
                index = len(nodes)
                nodes.append(node)
                for child in sorted(node.children.values(), key=lambda item: item.edge):
                    flatten(child)
                return index

            flatten(root)
            indexes = {id(node): index for index, node in enumerate(nodes)}
            payload = bytearray(struct.pack("<I", len(nodes)))
            for node in nodes:
                edge_bytes = node.edge.encode("utf-8")
                if len(edge_bytes) > 65535:
                    raise ValueError("Trie edge is too long")
                payload.extend(struct.pack("<H", len(edge_bytes)))
                payload.extend(edge_bytes)
                children = sorted(node.children.values(), key=lambda item: item.edge)
                payload.extend(struct.pack("<H", len(children)))
                for child in children:
                    payload.extend(struct.pack("<I I", ord(child.edge[0]), indexes[id(child)]))
                results = sorted(node.results.items(), key=lambda item: (-item[1], item[0]))[:TOP_K]
                payload.extend(struct.pack("<B", len(results)))
                for poi_id, prominence in results:
                    payload.extend(struct.pack("<I B", poi_id, max(0, min(255, prominence))))
                max_prominence = max((value for _, value in results), default=0)
                payload.extend(struct.pack("<B", max(0, min(255, max_prominence))))
            return payload

        payload = bytearray(b"SMTR")
        payload.extend(struct.pack("<B", 2))
        payload.extend(serialize_trie(self.root))
        payload.extend(serialize_trie(self.phonetic_root))
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_bytes(payload)


def build_from_database(db_path: Path, output_path: Path) -> int:
    builder = RadixTrieBuilder()
    with sqlite3.connect(db_path) as connection:
        columns = {
            row[1] for row in connection.execute("PRAGMA table_info(poi)")
        }
        prominence = "prominence" if "prominence" in columns else "0"
        rows = connection.execute(
            f"SELECT id, name_ascii, {prominence} FROM poi WHERE name_ascii IS NOT NULL"
        )
        count = 0
        for poi_id, name_ascii, score in rows:
            builder.add_poi(int(poi_id), str(name_ascii), int(score or 0))
            count += 1
    builder.serialize(output_path)
    return count


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("db_path", type=Path)
    parser.add_argument("output_path", type=Path)
    args = parser.parse_args()
    count = build_from_database(args.db_path, args.output_path)
    print(f"Built trie index for {count:,} POIs: {args.output_path}")


if __name__ == "__main__":
    main()
