"""
Phase 1: Dart Analyzer Wrapper
Runs `dart analyze --format=machine` and returns structured violations.
"""
from __future__ import annotations

import subprocess
import re
from pathlib import Path
from dataclasses import dataclass, field, asdict
from typing import Optional


@dataclass
class DartViolation:
    file: str
    line: int
    col: int
    severity: str   # ERROR | WARNING | INFO
    code: str       # e.g. "unused_import"
    message: str
    relative_path: str = ""

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class AnalysisResult:
    total: int = 0
    errors: int = 0
    warnings: int = 0
    infos: int = 0
    violations: list[DartViolation] = field(default_factory=list)
    files_affected: list[str] = field(default_factory=list)
    dart_version: str = ""
    success: bool = True
    error_message: str = ""


# Machine-format line:  SEVERITY|FILE|LINE|COL|LENGTH|MESSAGE
# e.g.:  error|/path/to/file.dart|10|5|20|Undefined name 'foo'.
_MACHINE_RE = re.compile(
    r'^(error|warning|info)\|(.+?)\|(\d+)\|(\d+)\|\d+\|(.+)$',
    re.IGNORECASE
)


class DartAnalyzer:
    def __init__(self, project_root: str | Path):
        self.project_root = Path(project_root).resolve()

    def run(
        self,
        severity_filter: Optional[list[str]] = None,
        file_filter: Optional[str] = None,
    ) -> AnalysisResult:
        """
        Run dart analyze and return structured results.

        Args:
            severity_filter: e.g. ["ERROR"] to only show errors.
                             None = all severities.
            file_filter: Optional path substring to filter violations by file.
        """
        result = AnalysisResult()

        try:
            proc = subprocess.run(
                ["dart", "analyze", "--format=machine"],
                cwd=str(self.project_root),
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=120,
            )
            # dart analyze exits non-zero when violations found – that's fine
            output = proc.stdout + proc.stderr

        except FileNotFoundError:
            result.success = False
            result.error_message = (
                "`dart` command not found in PATH. "
                "Ensure Dart SDK is installed and dart is on PATH."
            )
            return result
        except subprocess.TimeoutExpired:
            result.success = False
            result.error_message = "dart analyze timed out after 120 seconds."
            return result

        files_seen: set[str] = set()

        for line in output.splitlines():
            line = line.strip()
            m = _MACHINE_RE.match(line)
            if not m:
                continue

            sev_raw, filepath, lineno, col, message = m.groups()
            severity = sev_raw.upper()

            # Count regardless of filter
            if severity == "ERROR":
                result.errors += 1
            elif severity == "WARNING":
                result.warnings += 1
            else:
                result.infos += 1
            result.total += 1

            # Apply filters
            if severity_filter and severity not in [s.upper() for s in severity_filter]:
                continue
            if file_filter and file_filter.lower() not in filepath.lower():
                continue

            # Make path relative
            try:
                rel = str(Path(filepath).relative_to(self.project_root))
            except ValueError:
                rel = filepath

            v = DartViolation(
                file=filepath,
                relative_path=rel,
                line=int(lineno),
                col=int(col),
                severity=severity,
                code="",        # machine format doesn't expose lint code separately
                message=message.strip(),
            )
            result.violations.append(v)

            if rel not in files_seen:
                files_seen.add(rel)
                result.files_affected.append(rel)

        return result

    def get_summary(self, severity_filter: Optional[list[str]] = None) -> dict:
        """
        Return a compact summary dict suitable for agent consumption.
        Token cost: ~200-500 tokens depending on violation count.
        """
        r = self.run(severity_filter=severity_filter)
        if not r.success:
            return {"success": False, "error": r.error_message}

        return {
            "success": True,
            "summary": {
                "total": r.total,
                "errors": r.errors,
                "warnings": r.warnings,
                "infos": r.infos,
                "files_affected_count": len(r.files_affected),
            },
            "violations": [v.to_dict() for v in r.violations],
            "files_affected": r.files_affected,
        }
