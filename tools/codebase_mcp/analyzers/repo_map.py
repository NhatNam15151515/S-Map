"""
Phase 2c: Aider-style Repo Map.
Generates a token-efficient structural overview of the entire codebase
using PageRank to prioritize the most important files/symbols.

Algorithm (mirrors Aider's repo-map):
  1. Build import graph (SymbolGraph)
  2. Compute Personalized PageRank, personalizing toward `focus_files`
  3. Select top-K files within token budget
  4. Render each selected file as elided view (signatures only, no body)
"""
from __future__ import annotations

import math
from pathlib import Path
from typing import Optional

try:
    import networkx as nx
    NX_AVAILABLE = True
except ImportError:
    NX_AVAILABLE = False

from analyzers.symbol_graph import SymbolGraph
from utils.dart_parser import DartFileInfo, DartSymbol


# Average chars per token (conservative estimate for code)
_CHARS_PER_TOKEN = 3.5


def _estimate_tokens(text: str) -> int:
    return max(1, int(len(text) / _CHARS_PER_TOKEN))


class RepoMap:
    """
    Generates a compact, ranked structural view of the codebase.
    Default token budget: 1500 tokens.
    """

    def __init__(
        self,
        project_root: str | Path,
        token_budget: int = 1500,
        symbol_graph: Optional[SymbolGraph] = None,
    ):
        self.project_root = Path(project_root).resolve()
        self.token_budget = token_budget
        self._sg = symbol_graph or SymbolGraph(project_root)

    def generate(
        self,
        focus_files: Optional[list[str]] = None,
        include_layers: Optional[list[str]] = None,
    ) -> str:
        """
        Generate the repo map.

        Args:
            focus_files: File relative paths the agent is currently working on.
                         These are used as personalization seeds for PageRank.
            include_layers: Optional list of layer prefixes to restrict output
                            (e.g. ["lib/commons/", "lib/repos/"]).

        Returns:
            Multi-line string ≤ token_budget tokens.
        """
        sg = self._sg
        if not sg._built:
            sg.build()

        file_infos = sg.file_infos
        graph = sg.graph

        # ---- Rank files ----
        ranked = self._rank_files(graph, file_infos, focus_files or [])

        # ---- Filter by layer if requested ----
        if include_layers:
            ranked = [
                (rel, score) for rel, score in ranked
                if any(rel.startswith(lyr.replace("/", "\\")) or
                       rel.startswith(lyr) for lyr in include_layers)
            ]

        # ---- Build elided view within token budget ----
        lines: list[str] = []
        used_tokens = 0
        header = (
            f"# S-Map Repo Map  ({len(file_infos)} files total)\n"
            f"# Showing top files ranked by import centrality\n\n"
        )
        used_tokens += _estimate_tokens(header)
        lines.append(header)

        for rel_path, score in ranked:
            if rel_path not in file_infos:
                continue
            info = file_infos[rel_path]

            block = self._render_file_block(rel_path, info, score)
            block_tokens = _estimate_tokens(block)

            if used_tokens + block_tokens > self.token_budget:
                # Add truncation notice and stop
                lines.append(
                    f"\n... (budget reached – {len(ranked) - ranked.index((rel_path, score))} "
                    f"more files not shown. Increase token_budget or use include_layers to focus.)\n"
                )
                break

            lines.append(block)
            used_tokens += block_tokens

        result = "".join(lines)
        return result

    # ------------------------------------------------------------------ #
    #  Ranking                                                             #
    # ------------------------------------------------------------------ #

    def _rank_files(
        self,
        graph,
        file_infos: dict[str, DartFileInfo],
        focus_files: list[str],
    ) -> list[tuple[str, float]]:
        """
        Rank files by importance using Personalized PageRank when networkx
        is available, otherwise fall back to in-degree count.
        """
        all_files = list(file_infos.keys())

        if NX_AVAILABLE and graph and graph.number_of_nodes() > 0:
            # Build personalization dict seeded toward focus_files
            pers: dict[str, float] = {}
            if focus_files:
                # Normalize focus file paths
                norm_focus = {
                    f.replace("/", "\\") for f in focus_files
                } | set(focus_files)
                focus_nodes = [n for n in graph.nodes if n in norm_focus]
                if focus_nodes:
                    weight = 1.0 / len(focus_nodes)
                    for fn in focus_nodes:
                        pers[fn] = weight
                else:
                    pers = None  # type: ignore
            else:
                pers = None  # type: ignore

            try:
                pr = nx.pagerank(
                    graph,
                    alpha=0.85,
                    personalization=pers if pers else None,
                    max_iter=200,
                    tol=1e-6,
                )
            except nx.PowerIterationFailedConvergence:
                pr = {n: 1.0 / max(1, graph.number_of_nodes()) for n in graph.nodes}

            # Merge graph nodes with all file_infos (some may not be in graph)
            scores: dict[str, float] = {f: 0.0 for f in all_files}
            scores.update(pr)

        else:
            # Fallback: rank by number of s_map imports (how "central" a file is)
            scores = {
                rel: len(info.s_map_imports)
                for rel, info in file_infos.items()
            }

        # Boost focus files to the top
        if focus_files:
            norm_focus = {f.replace("/", "\\") for f in focus_files} | set(focus_files)
            for f in norm_focus:
                if f in scores:
                    scores[f] *= 10.0

        ranked = sorted(scores.items(), key=lambda x: x[1], reverse=True)
        return ranked

    # ------------------------------------------------------------------ #
    #  Rendering                                                           #
    # ------------------------------------------------------------------ #

    def _render_file_block(
        self,
        rel_path: str,
        info: DartFileInfo,
        score: float,
    ) -> str:
        """Render one file as an elided block (path + symbols, no body)."""
        lines: list[str] = []

        # Header line
        display_path = rel_path.replace("\\", "/")
        lines.append(f"### {display_path}\n")

        # Symbols
        if info.symbols:
            for sym in info.symbols:
                lines.append(f"  {sym.signature}\n")
        else:
            lines.append(f"  (no top-level symbols)\n")

        # Internal imports summary (compact)
        if info.s_map_imports:
            short_imports = [
                i.replace("package:s_map/", "")
                  .replace(".dart", "")
                for i in info.s_map_imports[:5]
            ]
            suffix = f" +{len(info.s_map_imports) - 5} more" if len(info.s_map_imports) > 5 else ""
            lines.append(f"  imports: {', '.join(short_imports)}{suffix}\n")

        lines.append("\n")
        return "".join(lines)
