"""
S-Map Codebase Intelligence MCP Server
========================================
Provides Antigravity agents with tools to understand and enforce the
S-Map Flutter codebase without reading raw files.

Tools exposed:
  Phase 1 – Dart Analyzer:
    - run_dart_analyze        : Full violation list from `dart analyze`
    - get_violations_summary  : Compact summary (recommended first call)

  Phase 2 – Repo Map & Symbol Graph:
    - get_repo_map            : Aider-style PageRank repo map (~1500 tokens)
    - query_symbol            : Find definition + usages of a class/function
    - get_file_dependencies   : What a file imports and what imports it
    - get_graph_stats         : Circular deps, total symbols, parse errors

  Phase 3 – Architecture Rules:
    - check_architecture_rules : Detect layer violations, circular deps, god files
    - get_architecture_report  : Alias for check_architecture_rules (full report)

Usage (local stdio MCP):
  python server.py

Usage (SSE MCP):
  python server.py --transport sse --port 8765
"""
from __future__ import annotations

import sys
import os
from pathlib import Path
from typing import Optional

# ── Add project root to sys.path so imports work ──────────────────────────────
_SERVER_DIR = Path(__file__).parent.resolve()
sys.path.insert(0, str(_SERVER_DIR))

# ── Project root: the S-Map Flutter project (has pubspec.yaml) ───────────────
_PROJECT_ROOT = (_SERVER_DIR.parent.parent / "S-Map").resolve()
if not (_PROJECT_ROOT / "pubspec.yaml").exists():
    # Fallback: one level up from server dir
    _PROJECT_ROOT = _SERVER_DIR.parent.parent.resolve()

# ── Lazy-init singletons (built on first use to keep startup fast) ────────────
_sg = None   # SymbolGraph
_rm = None   # RepoMap
_lc = None   # LayerChecker
_da = None   # DartAnalyzer


def _get_sg():
    global _sg
    if _sg is None:
        from analyzers.symbol_graph import SymbolGraph
        _sg = SymbolGraph(_PROJECT_ROOT)
        _sg.build()
    return _sg


def _get_rm(token_budget: int = 1500):
    global _rm
    if _rm is None:
        from analyzers.repo_map import RepoMap
        _rm = RepoMap(_PROJECT_ROOT, token_budget=token_budget, symbol_graph=_get_sg())
    return _rm


def _get_lc():
    global _lc
    if _lc is None:
        from analyzers.layer_checker import LayerChecker
        _lc = LayerChecker(_PROJECT_ROOT, symbol_graph=_get_sg())
    return _lc


def _get_da():
    global _da
    if _da is None:
        from analyzers.dart_analyzer import DartAnalyzer
        _da = DartAnalyzer(_PROJECT_ROOT)
    return _da


# ── MCP Server ────────────────────────────────────────────────────────────────
# ── MCP Server ────────────────────────────────────────────────────────────────
from mcp.server.mcpserver import MCPServer

mcp = MCPServer(
    name="smap-codebase-intel",
    instructions=(
        "Codebase Intelligence tools for the S-Map Flutter project. "
        "RECOMMENDED WORKFLOW: "
        "1. Call get_violations_summary to see current dart analyze issues. "
        "2. Call get_repo_map to understand the codebase structure. "
        "3. Call check_architecture_rules for layer violations. "
        "4. Call query_symbol to inspect a specific class or function. "
        "Each tool is token-optimized and returns structured data."
    ),
)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE 1 – Dart Analyzer
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@mcp.tool()
def get_violations_summary(
    severity: str = "ALL",
    file_filter: str = "",
) -> dict:
    """
    Run `dart analyze` and return a compact summary of violations.
    This is the recommended FIRST call to assess code health.

    Args:
        severity: "ERROR", "WARNING", "INFO", or "ALL" (default).
        file_filter: Optional substring to filter violations by file path
                     (e.g. "screens/main" to focus on main screens).

    Returns:
        {
          summary: {total, errors, warnings, infos, files_affected_count},
          violations: [{file, relative_path, line, col, severity, message}],
          files_affected: [list of relative paths]
        }
    Token cost: ~200–600 tokens depending on project health.
    """
    sev_filter = None if severity.upper() == "ALL" else [severity.upper()]
    result = _get_da().get_summary(severity_filter=sev_filter)

    # Apply file_filter after aggregation if specified
    if file_filter and result.get("violations"):
        result["violations"] = [
            v for v in result["violations"]
            if file_filter.lower() in v.get("relative_path", "").lower()
        ]
        result["files_affected"] = list({
            v["relative_path"] for v in result["violations"]
        })

    return result


@mcp.tool()
def run_dart_analyze(
    severity: str = "ERROR",
    file_filter: str = "",
) -> dict:
    """
    Run `dart analyze` and return full structured violation list.
    Use get_violations_summary first for a quick overview.

    Args:
        severity: Filter by "ERROR", "WARNING", "INFO", or "ALL".
                  Defaults to "ERROR" to keep output focused.
        file_filter: Optional file path substring filter.

    Returns: Same schema as get_violations_summary.
    Token cost: ~200–2000 tokens.
    """
    return get_violations_summary(severity=severity, file_filter=file_filter)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE 2 – Repo Map & Symbol Graph
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@mcp.tool()
def get_repo_map(
    focus_files: Optional[list[str]] = None,
    include_layers: Optional[list[str]] = None,
    token_budget: int = 1500,
) -> str:
    """
    Generate an Aider-style PageRank repo map of the S-Map codebase.
    Returns elided file signatures ranked by import centrality.
    This is the MOST TOKEN-EFFICIENT way to understand the full codebase.

    Args:
        focus_files: Relative paths of files currently being edited
                     (e.g. ["lib/screens/main/home/home_screen.dart"]).
                     These files and their neighbors will be ranked higher.
        include_layers: Optionally restrict to specific layers
                        (e.g. ["lib/commons/", "lib/repos/"]).
        token_budget: Max tokens for the map (default 1500, max recommended 3000).

    Returns: Multi-line string with file headers and symbol signatures.
    Token cost: Controlled by token_budget parameter.
    """
    rm = _get_rm(token_budget)
    return rm.generate(focus_files=focus_files, include_layers=include_layers)


@mcp.tool()
def query_symbol(symbol_name: str) -> dict:
    """
    Find the definition and all usages of a Dart class, mixin, or function.

    Args:
        symbol_name: The exact class/function/enum name to look up
                     (e.g. "MapExploreCubit", "PoiModel", "searchInBounds").

    Returns:
        {
          symbol_name: str,
          found: bool,
          definitions: [{file, relative_path, line, kind, signature}],
          usages: [{file, relative_path, imports_via}]
        }
    Token cost: ~100–300 tokens.
    """
    sg = _get_sg()
    result = sg.query_symbol(symbol_name)
    return {
        "symbol_name": result.symbol_name,
        "found": result.found,
        "definitions": result.definitions,
        "usages": result.usages,
    }


@mcp.tool()
def get_file_dependencies(relative_path: str) -> dict:
    """
    Get import relationships for a specific file.

    Args:
        relative_path: File path relative to project root
                       (e.g. "lib/commons/cubits/map_explore_cubit/map_explore_cubit.dart").

    Returns:
        {
          file: str,
          imports: [package:s_map/... URIs this file imports],
          imported_by: [files that import this file]
        }
    Token cost: ~100–200 tokens.
    """
    # Normalize slashes
    norm = relative_path.replace("/", "\\")
    sg = _get_sg()
    result = sg.get_file_dependencies(norm)
    if "error" in result:
        # Try forward slash variant
        result = sg.get_file_dependencies(relative_path)
    return result


@mcp.tool()
def get_graph_stats() -> dict:
    """
    Get high-level statistics about the codebase dependency graph.
    Includes: file count, symbol count, circular dependency detection.

    Returns:
        {
          total_files: int,
          total_symbols: int,
          total_edges: int,
          circular_dependencies: [[file1, file2, ...]],
          circular_count: int,
          parse_errors: [files with parse errors]
        }
    Token cost: ~100–400 tokens.
    """
    return _get_sg().get_graph_stats()


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE 3 – Architecture Rule Engine
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@mcp.tool()
def check_architecture_rules(rebuild: bool = False) -> dict:
    """
    Check all S-Map architecture rules and return violations.
    Rules are defined in config/architecture.yaml.

    Checks:
      - Layer boundary violations (e.g. commons importing services directly)
      - Circular import dependencies
      - God files (too many imports, default threshold: 10)

    Args:
        rebuild: Force rebuild of the symbol graph (use if files changed).

    Returns:
        {
          files_checked: int,
          total_violations: int,
          violations: [{file, violating_import, rule, from_layer, to_layer}],
          circular_dependencies: [[file paths in cycle]],
          god_files: [{file, import_count, threshold}],
          layer_summary: {layer_name: {file_count, pattern}}
        }
    Token cost: ~300–1500 tokens depending on violation count.
    """
    lc = _get_lc()
    report = lc.check(rebuild=rebuild)
    return lc.format_report(report)


@mcp.tool()
def get_architecture_report(
    layer: Optional[str] = None,
    rebuild: bool = False,
) -> dict:
    """
    Get architecture compliance report, optionally filtered by layer.

    Args:
        layer: Optional layer name to filter violations
               (e.g. "commons_logic", "screens", "repos", "services",
                "models", "interfaces", "constants").
               Pass None for full report.
        rebuild: Force rebuild of symbol graph.

    Returns: Same schema as check_architecture_rules, filtered by layer.
    Token cost: ~200–800 tokens.
    """
    lc = _get_lc()
    report = lc.check(rebuild=rebuild)
    formatted = lc.format_report(report)

    if layer:
        formatted["violations"] = [
            v for v in formatted["violations"]
            if v.get("from_layer") == layer or v.get("to_layer") == layer
        ]
        formatted["total_violations"] = len(formatted["violations"])
        formatted["filtered_by_layer"] = layer

    return formatted


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Entry Point
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def _check_treesitter() -> str:
    try:
        from utils.dart_parser import TREE_SITTER_AVAILABLE
        return "available ✓" if TREE_SITTER_AVAILABLE else "unavailable (regex fallback active)"
    except Exception as e:
        return f"error: {e}"


if __name__ == "__main__":
    import argparse
    import asyncio

    parser = argparse.ArgumentParser(description="S-Map Codebase Intelligence MCP Server")
    parser.add_argument(
        "--transport", choices=["stdio", "sse", "streamable-http"], default="stdio",
        help="Transport type (default: stdio for Antigravity integration)"
    )
    parser.add_argument("--port", type=int, default=8765, help="Port for SSE/HTTP transport")
    parser.add_argument("--host", type=str, default="127.0.0.1", help="Host for SSE/HTTP transport")
    parser.add_argument("--project-root", type=str, default="",
                        help="Override project root path")
    args = parser.parse_args()

    if args.project_root:
        _PROJECT_ROOT = Path(args.project_root).resolve()

    print(f"[smap-mcp] Starting | project: {_PROJECT_ROOT}", file=sys.stderr)
    print(f"[smap-mcp] Tree-sitter: {_check_treesitter()}", file=sys.stderr)
    print(f"[smap-mcp] Transport: {args.transport}", file=sys.stderr)

    if args.transport == "stdio":
        asyncio.run(mcp.run_stdio_async())
    elif args.transport == "sse":
        asyncio.run(mcp.run_sse_async(host=args.host, port=args.port))
    else:
        asyncio.run(mcp.run_streamable_http_async(host=args.host, port=args.port))
