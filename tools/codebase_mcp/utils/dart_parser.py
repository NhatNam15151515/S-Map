"""
Phase 2a: Tree-sitter Dart utilities.
Parses .dart files and extracts symbols (classes, functions, imports).
"""
from __future__ import annotations

import re
from pathlib import Path
from dataclasses import dataclass, field
from typing import Optional

# Tree-sitter setup (v0.22+ API)
try:
    import tree_sitter_dart as tsdart
    from tree_sitter import Language, Parser, Node

    DART_LANGUAGE = Language(tsdart.language())
    _PARSER = Parser(DART_LANGUAGE)
    TREE_SITTER_AVAILABLE = True
except Exception:
    TREE_SITTER_AVAILABLE = False
    _PARSER = None
    Node = object  # type: ignore


@dataclass
class DartSymbol:
    name: str
    kind: str           # "class" | "mixin" | "extension" | "function" | "method" | "enum" | "typedef"
    file: str
    line: int
    signature: str      # One-line elided representation


@dataclass
class DartFileInfo:
    path: str
    relative_path: str
    imports: list[str] = field(default_factory=list)          # raw import paths
    s_map_imports: list[str] = field(default_factory=list)    # only package:s_map/...
    symbols: list[DartSymbol] = field(default_factory=list)
    line_count: int = 0
    parse_error: bool = False


# --- Fallback regex-based parser (used if tree-sitter unavailable) ---

_IMPORT_RE = re.compile(r"""import\s+['"]([^'"]+)['"]\s*;""")
_CLASS_RE   = re.compile(
    r'^\s*(abstract\s+)?(class|mixin|extension|enum)\s+(\w+)', re.MULTILINE
)
_FUNC_RE    = re.compile(
    r'^\s+(?:(?:Future|Stream|void|String|int|double|bool|List|Map|dynamic|[\w<>,?\s]+)\s+)?'
    r'(\w+)\s*\(', re.MULTILINE
)


def _parse_with_regex(path: Path, rel: str) -> DartFileInfo:
    """Fallback parser using regex — less precise but zero-dependency."""
    info = DartFileInfo(path=str(path), relative_path=rel)
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
        info.line_count = text.count("\n") + 1

        for m in _IMPORT_RE.finditer(text):
            uri = m.group(1)
            info.imports.append(uri)
            if uri.startswith("package:s_map/"):
                info.s_map_imports.append(uri)

        for m in _CLASS_RE.finditer(text):
            kind = m.group(2)
            name = m.group(3)
            line = text[: m.start()].count("\n") + 1
            info.symbols.append(DartSymbol(
                name=name, kind=kind, file=str(path), line=line,
                signature=f"{kind} {name} {{...}}"
            ))

    except Exception:
        info.parse_error = True

    return info


# --- Tree-sitter-based parser ---

def _node_text(node: "Node", src: bytes) -> str:
    return src[node.start_byte:node.end_byte].decode("utf-8", errors="replace")


def _parse_with_tree_sitter(path: Path, rel: str) -> DartFileInfo:
    info = DartFileInfo(path=str(path), relative_path=rel)
    try:
        src = path.read_bytes()
        info.line_count = src.count(b"\n") + 1
        tree = _PARSER.parse(src)
        root = tree.root_node

        if root.has_error:
            info.parse_error = True

        def walk(node: "Node"):
            t = node.type

            if t == "import_or_export":
                # Dart grammar: import_or_export → library_import → import_specification
                #               → configurable_uri → uri → string_literal
                # Walk recursively to find 'uri' nodes inside this import
                def _extract_uri(n):
                    if n.type == "uri":
                        # uri's text is the string_literal e.g. 'package:s_map/...'
                        raw = _node_text(n, src).strip("'\"")
                        info.imports.append(raw)
                        if raw.startswith("package:s_map/"):
                            info.s_map_imports.append(raw)
                        return
                    for ch in n.children:
                        _extract_uri(ch)
                _extract_uri(node)
                return  # no need to recurse import nodes further

            if t in ("class_definition", "mixin_declaration", "extension_declaration",
                      "enum_declaration"):
                kind_map = {
                    "class_definition": "class",
                    "mixin_declaration": "mixin",
                    "extension_declaration": "extension",
                    "enum_declaration": "enum",
                }
                kind = kind_map.get(t, t)
                # tree-sitter-dart uses 'identifier' as child type for class name
                name_node = node.child_by_field_name("name")
                if name_node is None:
                    # Fallback: find first 'identifier' child
                    for ch in node.children:
                        if ch.type == "identifier":
                            name_node = ch
                            break
                if name_node:
                    name = _node_text(name_node, src)
                    line = node.start_point[0] + 1
                    first_line = _node_text(node, src).split("\n")[0].rstrip(" {")
                    sig = f"{first_line} {{...}}"
                    info.symbols.append(DartSymbol(
                        name=name, kind=kind, file=str(path),
                        line=line, signature=sig
                    ))
                # Still recurse into class body for methods
                for child in node.children:
                    walk(child)
                return

            if t in ("function_signature", "method_signature",
                      "function_declaration", "getter_signature"):
                name_node = node.child_by_field_name("name")
                if name_node is None:
                    for ch in node.children:
                        if ch.type == "identifier":
                            name_node = ch
                            break
                if name_node:
                    name = _node_text(name_node, src)
                    # Skip private/anonymous/override-only methods at top file level
                    line = node.start_point[0] + 1
                    first_line = _node_text(node, src).split("\n")[0].strip()
                    info.symbols.append(DartSymbol(
                        name=name, kind="function", file=str(path),
                        line=line, signature=first_line
                    ))

            for child in node.children:
                walk(child)

        walk(root)

    except Exception:
        info.parse_error = True

    return info


# --- Public API ---

def parse_dart_file(path: str | Path, project_root: str | Path) -> DartFileInfo:
    """Parse a single .dart file and return its info."""
    p = Path(path).resolve()
    root = Path(project_root).resolve()
    try:
        rel = str(p.relative_to(root))
    except ValueError:
        rel = str(p)

    if TREE_SITTER_AVAILABLE:
        return _parse_with_tree_sitter(p, rel)
    return _parse_with_regex(p, rel)


def parse_all_dart_files(
    project_root: str | Path,
    exclude_generated: bool = True,
) -> dict[str, DartFileInfo]:
    """
    Parse all .dart files under project_root/lib.
    Returns {relative_path: DartFileInfo}.
    """
    root = Path(project_root).resolve()
    lib_dir = root / "lib"
    results: dict[str, DartFileInfo] = {}

    for dart_file in sorted(lib_dir.rglob("*.dart")):
        rel = str(dart_file.relative_to(root))

        # Skip generated files
        if exclude_generated and (
            rel.startswith("lib\\generated\\") or
            rel.startswith("lib/generated/") or
            dart_file.name.endswith(".g.dart") or
            dart_file.name.endswith(".freezed.dart")
        ):
            continue

        info = parse_dart_file(dart_file, root)
        results[rel] = info

    return results
