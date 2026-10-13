"""
Phase 3: Layer Architecture Rule Engine.
Detects forbidden import relationships defined in config/architecture.yaml.
Also detects: circular dependencies, god files.
"""
from __future__ import annotations

import re
from pathlib import Path
from dataclasses import dataclass, field, asdict
from typing import Optional

import yaml

from analyzers.symbol_graph import SymbolGraph
from utils.dart_parser import DartFileInfo


@dataclass
class ArchitectureViolation:
    file: str                    # relative path
    violating_import: str        # the forbidden import URI
    rule: str                    # description of the rule broken
    from_layer: str
    to_layer: str

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class ArchitectureReport:
    total_violations: int = 0
    violations: list[ArchitectureViolation] = field(default_factory=list)
    circular_dependencies: list[list[str]] = field(default_factory=list)
    god_files: list[dict] = field(default_factory=list)
    layer_summary: dict = field(default_factory=dict)
    files_checked: int = 0


class LayerChecker:
    """
    Checks layer boundary violations for a Dart/Flutter project.
    Rules are defined in config/architecture.yaml.
    """

    def __init__(
        self,
        project_root: str | Path,
        config_path: Optional[str | Path] = None,
        symbol_graph: Optional[SymbolGraph] = None,
    ):
        self.project_root = Path(project_root).resolve()
        self._config_path = Path(config_path) if config_path else (
            Path(__file__).parent.parent / "config" / "architecture.yaml"
        )
        self._config: dict = {}
        self._sg = symbol_graph or SymbolGraph(project_root)
        self._load_config()

    def _load_config(self):
        if self._config_path.exists():
            with open(self._config_path, encoding="utf-8") as f:
                self._config = yaml.safe_load(f) or {}

    # ------------------------------------------------------------------ #
    #  Public API                                                          #
    # ------------------------------------------------------------------ #

    def check(self, rebuild: bool = False) -> ArchitectureReport:
        """Run all checks and return a full report."""
        sg = self._sg
        if not sg._built or rebuild:
            sg.build()

        report = ArchitectureReport()
        file_infos = sg.file_infos
        report.files_checked = len(file_infos)

        layers: list[dict] = self._config.get("layers", {})
        god_threshold: int = (
            self._config.get("god_file_threshold", {}).get("max_imports", 10)
        )
        check_circular: bool = self._config.get("check_circular", True)

        # Build layer lookup: {layer_name: path_pattern}
        layer_patterns: dict[str, str] = {}
        layer_forbidden: dict[str, list[str]] = {}
        for layer_name, layer_cfg in (layers.items() if isinstance(layers, dict) else []):
            pattern = layer_cfg.get("path_pattern", "")
            layer_patterns[layer_name] = pattern
            layer_forbidden[layer_name] = layer_cfg.get("forbidden_imports", [])

        # Per-layer file counts for summary
        layer_file_counts: dict[str, int] = {k: 0 for k in layer_patterns}

        # ---- Check each file ----
        for rel_path, info in file_infos.items():
            norm_rel = rel_path.replace("\\", "/")

            # Determine which layer this file belongs to
            file_layer = _match_layer(norm_rel, layer_patterns)
            if file_layer:
                layer_file_counts[file_layer] = layer_file_counts.get(file_layer, 0) + 1

            # Check forbidden imports
            if file_layer and file_layer in layer_forbidden:
                for imp_uri in info.s_map_imports:
                    imp_path = _uri_to_lib_path(imp_uri)
                    if imp_path is None:
                        continue
                    for forbidden_prefix in layer_forbidden[file_layer]:
                        norm_forbidden = forbidden_prefix.replace("\\", "/")
                        if imp_path.startswith(norm_forbidden):
                            target_layer = _match_layer(imp_path, layer_patterns) or imp_path
                            v = ArchitectureViolation(
                                file=rel_path,
                                violating_import=imp_uri,
                                rule=(
                                    f"Layer '{file_layer}' must not import from "
                                    f"'{norm_forbidden}'"
                                ),
                                from_layer=file_layer,
                                to_layer=target_layer,
                            )
                            report.violations.append(v)
                            report.total_violations += 1
                            break  # one violation per import is enough

            # God file check
            total_imports = len(info.imports)
            if total_imports > god_threshold:
                report.god_files.append({
                    "file": rel_path,
                    "import_count": total_imports,
                    "s_map_import_count": len(info.s_map_imports),
                    "threshold": god_threshold,
                })

        # ---- Circular dependency check ----
        if check_circular and sg.graph is not None:
            try:
                import networkx as nx
                cycles = list(nx.simple_cycles(sg.graph))
                report.circular_dependencies = cycles
            except ImportError:
                pass

        # Layer summary
        report.layer_summary = {
            layer: {
                "file_count": layer_file_counts.get(layer, 0),
                "pattern": pat,
            }
            for layer, pat in layer_patterns.items()
        }

        return report

    def get_violations_for_file(self, rel_path: str) -> list[ArchitectureViolation]:
        """Return only violations for a specific file."""
        report = self.check()
        return [v for v in report.violations if v.file == rel_path]

    def format_report(self, report: Optional[ArchitectureReport] = None) -> dict:
        """Return a JSON-serialisable report dict for MCP tool consumption."""
        if report is None:
            report = self.check()

        return {
            "files_checked": report.files_checked,
            "total_violations": report.total_violations,
            "violations": [v.to_dict() for v in report.violations],
            "circular_dependencies": report.circular_dependencies,
            "god_files": report.god_files,
            "layer_summary": report.layer_summary,
        }


# ------------------------------------------------------------------ #
#  Helpers                                                             #
# ------------------------------------------------------------------ #

def _uri_to_lib_path(uri: str) -> str | None:
    """
    Convert 'package:s_map/commons/cubits/cubits.dart' →
    'lib/commons/cubits/cubits.dart'
    """
    prefix = "package:s_map/"
    if uri.startswith(prefix):
        return "lib/" + uri[len(prefix):]
    return None


def _match_layer(norm_path: str, layer_patterns: dict[str, str]) -> str | None:
    """Return the layer name whose path_pattern matches norm_path."""
    for layer_name, pattern in layer_patterns.items():
        norm_pattern = pattern.replace("\\", "/")
        if norm_path.startswith(norm_pattern):
            return layer_name
    return None
