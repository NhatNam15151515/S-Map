"""
Phase 2b: Symbol Graph Builder.
Builds a directed import graph from DartFileInfo data.
Provides symbol lookup: find all usages of a class/function across the repo.
"""
from __future__ import annotations

from pathlib import Path
from dataclasses import dataclass, field
from typing import Optional

try:
    import networkx as nx
    NX_AVAILABLE = True
except ImportError:
    NX_AVAILABLE = False

from utils.dart_parser import DartFileInfo, DartSymbol, parse_all_dart_files


@dataclass
class SymbolQueryResult:
    symbol_name: str
    found: bool
    definitions: list[dict] = field(default_factory=list)
    usages: list[dict] = field(default_factory=list)


class SymbolGraph:
    """
    Builds and queries the dependency graph of a Dart project.
    Nodes = file relative paths.
    Edges = A → B means A imports B.
    """

    def __init__(self, project_root: str | Path):
        self.project_root = Path(project_root).resolve()
        self._file_infos: dict[str, DartFileInfo] = {}
        self._graph: Optional["nx.DiGraph"] = None
        self._symbol_index: dict[str, list[DartSymbol]] = {}
        self._built = False

    # ------------------------------------------------------------------ #
    #  Build                                                               #
    # ------------------------------------------------------------------ #

    def build(self, force: bool = False) -> "SymbolGraph":
        if self._built and not force:
            return self

        self._file_infos = parse_all_dart_files(self.project_root)
        self._build_graph()
        self._build_symbol_index()
        self._built = True
        return self

    def _s_map_import_to_rel(self, uri: str) -> str | None:
        """
        Convert 'package:s_map/commons/cubits/cubits.dart' →
        'lib\\commons\\cubits\\cubits.dart'  (Windows sep)
        """
        prefix = "package:s_map/"
        if not uri.startswith(prefix):
            return None
        rest = uri[len(prefix):]
        return str(Path("lib") / Path(rest))

    def _build_graph(self):
        if not NX_AVAILABLE:
            return
        self._graph = nx.DiGraph()
        for rel_path, info in self._file_infos.items():
            self._graph.add_node(rel_path)
            for imp_uri in info.s_map_imports:
                target_rel = self._s_map_import_to_rel(imp_uri)
                if target_rel and target_rel in self._file_infos:
                    self._graph.add_edge(rel_path, target_rel)

    def _build_symbol_index(self):
        self._symbol_index = {}
        for info in self._file_infos.values():
            for sym in info.symbols:
                self._symbol_index.setdefault(sym.name, []).append(sym)

    # ------------------------------------------------------------------ #
    #  Queries                                                             #
    # ------------------------------------------------------------------ #

    def query_symbol(self, symbol_name: str) -> SymbolQueryResult:
        """Find all definitions and file-level usages of a symbol."""
        if not self._built:
            self.build()

        result = SymbolQueryResult(symbol_name=symbol_name, found=False)

        # Definitions
        defs = self._symbol_index.get(symbol_name, [])
        for sym in defs:
            result.definitions.append({
                "file": sym.file,
                "relative_path": _norm(sym.file, self.project_root),
                "line": sym.line,
                "kind": sym.kind,
                "signature": sym.signature,
            })
        result.found = bool(defs)

        # Usages: files that contain the symbol name as a literal token in imports or body
        # (simple heuristic: scan raw text for symbol name)
        for rel_path, info in self._file_infos.items():
            # Check if this file imports a file where the symbol is defined
            defined_in = {_norm(s.file, self.project_root) for s in defs}
            imports_it = any(
                self._s_map_import_to_rel(imp) in defined_in
                for imp in info.s_map_imports
            )
            if imports_it and rel_path not in defined_in:
                result.usages.append({
                    "file": info.path,
                    "relative_path": rel_path,
                    "imports_via": [
                        imp for imp in info.s_map_imports
                        if self._s_map_import_to_rel(imp) in defined_in
                    ],
                })

        return result

    def get_file_dependencies(self, rel_path: str) -> dict:
        """Return what a file imports and what imports it (reverse edges)."""
        if not self._built:
            self.build()

        info = self._file_infos.get(rel_path)
        if not info:
            return {"error": f"File not found: {rel_path}"}

        result: dict = {
            "file": rel_path,
            "imports": info.s_map_imports,
            "imported_by": [],
        }

        if NX_AVAILABLE and self._graph and rel_path in self._graph:
            result["imported_by"] = list(self._graph.predecessors(rel_path))

        return result

    def get_graph_stats(self) -> dict:
        if not self._built:
            self.build()

        stats: dict = {
            "total_files": len(self._file_infos),
            "total_symbols": sum(len(i.symbols) for i in self._file_infos.values()),
            "parse_errors": [r for r, i in self._file_infos.items() if i.parse_error],
        }

        if NX_AVAILABLE and self._graph:
            stats["total_edges"] = self._graph.number_of_edges()
            # Circular dependencies
            cycles = list(nx.simple_cycles(self._graph))
            stats["circular_dependencies"] = cycles
            stats["circular_count"] = len(cycles)

        return stats

    # ------------------------------------------------------------------ #
    #  Internal access                                                     #
    # ------------------------------------------------------------------ #

    @property
    def file_infos(self) -> dict[str, DartFileInfo]:
        if not self._built:
            self.build()
        return self._file_infos

    @property
    def graph(self):
        if not self._built:
            self.build()
        return self._graph


def _norm(filepath: str, root: Path) -> str:
    try:
        return str(Path(filepath).relative_to(root))
    except ValueError:
        return filepath
