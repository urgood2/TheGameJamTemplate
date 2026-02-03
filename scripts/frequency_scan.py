#!/usr/bin/env python3
"""Frequency scanning for Lua-facing bindings/components.

Default mode is token-aware: strings and comments are ignored when scanning.
Falls back to regex if token-aware scanning fails.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from bisect import bisect_right
from collections.abc import Callable, Iterable
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover - optional dependency
    yaml = None

try:
    import jsonschema
except ImportError:  # pragma: no cover - optional dependency
    jsonschema = None


LOG_PREFIX = "[FREQ]"
DEFAULT_OCCURRENCE_THRESHOLD = 10
DEFAULT_ROOTS = ["assets/scripts"]
DEFAULT_ALIAS_FILE = "planning/frequency_aliases.yaml"
DEFAULT_OUTPUT_DIR = "planning/inventory"


FREQUENCY_SCHEMA = {
    "type": "object",
    "required": [
        "schema_version",
        "generated_at",
        "system",
        "scan_config",
        "scan_stats",
        "summary",
        "items",
    ],
    "properties": {
        "schema_version": {"type": "string"},
        "generated_at": {"type": "string"},
        "system": {"type": "string"},
        "scan_config": {
            "type": "object",
            "required": [
                "mode",
                "roots",
                "patterns_count",
                "patterns",
                "aliases_file",
                "occurrence_threshold",
                "input_source",
                "cli",
            ],
        },
        "scan_stats": {
            "type": "object",
            "required": ["files_scanned", "fallback_used", "total_matches"],
        },
        "summary": {
            "type": "object",
            "required": ["total_items", "high_frequency", "low_frequency", "not_found"],
        },
        "items": {"type": "array"},
    },
}


def log(message: str, logger: Callable[[str], None] | None = None) -> None:
    if logger is None:
        print(message)
    else:
        logger(message)


def rel_path(path: Path, project_root: Path) -> str:
    try:
        return str(path.relative_to(project_root))
    except ValueError:
        return str(path)


def match_long_bracket(src: str, idx: int) -> int | None:
    """If src[idx:] starts with [=*[ return count of '=' chars, else None."""
    if idx >= len(src) or src[idx] != "[":
        return None
    j = idx + 1
    while j < len(src) and src[j] == "=":
        j += 1
    if j < len(src) and src[j] == "[":
        return j - idx - 1
    return None


def sanitize_lua_source(src: str) -> str | None:
    """Return src with strings/comments replaced by spaces, preserving newlines."""
    out: list[str] = []
    i = 0
    n = len(src)
    state = "normal"  # normal | string | long_string | line_comment | long_comment
    quote = ""
    long_eqs = 0

    while i < n:
        ch = src[i]

        if state == "normal":
            if ch == "-" and i + 1 < n and src[i + 1] == "-":
                out.append(" ")
                out.append(" ")
                i += 2
                lb = match_long_bracket(src, i)
                if lb is not None:
                    state = "long_comment"
                    long_eqs = lb
                    out.extend(" " * (lb + 2))
                    i += lb + 2
                else:
                    state = "line_comment"
                continue

            if ch in ("'", '"'):
                state = "string"
                quote = ch
                out.append(" ")
                i += 1
                continue

            lb = match_long_bracket(src, i) if ch == "[" else None
            if lb is not None:
                state = "long_string"
                long_eqs = lb
                out.extend(" " * (lb + 2))
                i += lb + 2
                continue

            out.append(ch)
            i += 1
            continue

        if state == "string":
            if ch == "\n":
                out.append("\n")
            else:
                out.append(" ")
            if ch == "\\" and i + 1 < n:
                i += 1
                out.append("\n" if src[i] == "\n" else " ")
                i += 1
                continue
            if ch == quote:
                state = "normal"
            i += 1
            continue

        if state == "line_comment":
            if ch == "\n":
                out.append("\n")
                state = "normal"
            else:
                out.append(" ")
            i += 1
            continue

        if state == "long_comment":
            close = "]" + ("=" * long_eqs) + "]"
            if src.startswith(close, i):
                out.extend(" " * len(close))
                i += len(close)
                state = "normal"
                continue
            out.append("\n" if ch == "\n" else " ")
            i += 1
            continue

        if state == "long_string":
            close = "]" + ("=" * long_eqs) + "]"
            if src.startswith(close, i):
                out.extend(" " * len(close))
                i += len(close)
                state = "normal"
                continue
            out.append("\n" if ch == "\n" else " ")
            i += 1
            continue

    if state != "normal":
        return None
    return "".join(out)


def build_line_index(text: str) -> list[int]:
    line_starts = [0]
    for idx, ch in enumerate(text):
        if ch == "\n":
            line_starts.append(idx + 1)
    return line_starts


def line_number(line_starts: list[int], index: int) -> int:
    return bisect_right(line_starts, index)


def alias_to_regex(alias: str) -> str:
    escaped = re.escape(alias)
    return rf"(?<![A-Za-z0-9_]){escaped}(?![A-Za-z0-9_])"


def load_aliases(path: Path) -> dict[str, list[str]]:
    if not path.exists():
        return {}
    if yaml is None:
        raise RuntimeError("PyYAML is required to load alias config.")
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if data is None:
        return {}
    if isinstance(data, dict) and "aliases" in data and isinstance(data["aliases"], dict):
        data = data["aliases"]
    aliases: dict[str, list[str]] = {}
    if isinstance(data, dict):
        for canonical, value in data.items():
            if isinstance(value, dict) and "aliases" in value:
                value = value["aliases"]
            if isinstance(value, list):
                aliases[canonical] = [str(v) for v in value]
            elif isinstance(value, str):
                aliases[canonical] = [value]
            else:
                aliases[canonical] = []
    return aliases


def normalize_aliases(
    names: Iterable[str], alias_config: dict[str, list[str]]
) -> dict[str, list[str]]:
    alias_map: dict[str, list[str]] = {}
    for name in names:
        aliases = alias_config.get(name, [])
        merged = [name] + [a for a in aliases if a != name]
        alias_map[name] = list(dict.fromkeys(merged))
    return alias_map


def extract_names_from_json(data: object) -> list[str]:
    names: list[str] = []
    if isinstance(data, dict):
        if "lua_name" in data and isinstance(data["lua_name"], str):
            names.append(data["lua_name"])
        for value in data.values():
            names.extend(extract_names_from_json(value))
    elif isinstance(data, list):
        for item in data:
            names.extend(extract_names_from_json(item))
    return names


def load_names_from_file(path: Path) -> list[str]:
    if path.suffix.lower() == ".json":
        data = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(data, list):
            return [str(item) for item in data]
        return extract_names_from_json(data)
    lines = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        lines.append(line)
    return lines


@dataclass
class AliasStats:
    occurrences: int = 0
    files: set[str] = field(default_factory=set)

    def to_dict(self) -> dict:
        return {
            "occurrences": self.occurrences,
            "files_with_match": len(self.files),
        }


@dataclass
class FrequencyEntry:
    name: str
    aliases: list[str]
    total_occurrences: int = 0
    files: set[str] = field(default_factory=set)
    file_lines: dict[str, list[int]] = field(default_factory=dict)
    matched_aliases: dict[str, AliasStats] = field(default_factory=dict)

    def add_match(self, alias: str, file_path: str, lines: list[int]) -> None:
        if not lines:
            return
        self.total_occurrences += len(lines)
        self.files.add(file_path)
        self.file_lines.setdefault(file_path, []).extend(lines)
        stats = self.matched_aliases.setdefault(alias, AliasStats())
        stats.occurrences += len(lines)
        stats.files.add(file_path)

    def to_dict(
        self,
        occurrence_threshold: int,
        pattern_map: dict[str, list[dict]],
    ) -> dict:
        files_with_match = len(self.files)
        high_frequency_reasons = []
        if files_with_match >= 3:
            high_frequency_reasons.append("files>=3")
        if self.total_occurrences >= occurrence_threshold:
            high_frequency_reasons.append(f"occurrences>={occurrence_threshold}")
        high_frequency = bool(high_frequency_reasons)
        file_lines = {
            path: sorted(set(lines)) for path, lines in self.file_lines.items()
        }
        return {
            "name": self.name,
            "aliases": self.aliases,
            "matched_aliases": {
                alias: stats.to_dict()
                for alias, stats in sorted(self.matched_aliases.items())
            },
            "files_with_match": files_with_match,
            "total_occurrences": self.total_occurrences,
            "high_frequency": high_frequency,
            "high_frequency_reason": high_frequency_reasons,
            "occurrence_threshold": occurrence_threshold,
            "files": sorted(self.files),
            "file_lines": file_lines,
            "search_patterns": pattern_map.get(self.name, []),
        }


def compile_patterns(
    alias_map: dict[str, list[str]]
) -> tuple[list[dict], dict[str, list[dict]]]:
    patterns: list[dict] = []
    pattern_map: dict[str, list[dict]] = {}
    for canonical, aliases in alias_map.items():
        for alias in aliases:
            regex = alias_to_regex(alias)
            entry = {
                "canonical": canonical,
                "alias": alias,
                "regex": regex,
                "compiled": re.compile(regex),
            }
            patterns.append(entry)
            pattern_map.setdefault(canonical, []).append(
                {"alias": alias, "regex": regex}
            )
    return patterns, pattern_map


def scan_frequency(
    names: list[str],
    roots: list[Path],
    system: str,
    mode: str = "token_aware",
    aliases: dict[str, list[str]] | None = None,
    occurrence_threshold: int = DEFAULT_OCCURRENCE_THRESHOLD,
    logger: Callable[[str], None] | None = None,
    file_paths: list[Path] | None = None,
    project_root: Path | None = None,
) -> tuple[dict, bool]:
    if project_root is None:
        project_root = Path.cwd()
    aliases = aliases or {}
    alias_map = normalize_aliases(names, aliases)
    patterns, pattern_map = compile_patterns(alias_map)

    log(f"{LOG_PREFIX} === Frequency Scan for {system} ===", logger)
    log(f"{LOG_PREFIX} Mode: {mode}", logger)
    log(
        f"{LOG_PREFIX} Roots: {', '.join([rel_path(r, project_root) for r in roots])}",
        logger,
    )
    log(f"{LOG_PREFIX} Patterns: {len(patterns)}", logger)

    if file_paths is None:
        file_paths = []
        for root in roots:
            file_paths.extend(sorted(root.rglob("*.lua")))

    entries = {
        name: FrequencyEntry(name=name, aliases=alias_map[name]) for name in names
    }
    fallback_used = False
    total_matches = 0

    for file_path in file_paths:
        rel_file = rel_path(file_path, project_root)
        log(f"{LOG_PREFIX} Scanning {rel_file}...", logger)
        try:
            content = file_path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        scan_text = content
        if mode == "token_aware":
            sanitized = sanitize_lua_source(content)
            if sanitized is None:
                fallback_used = True
            else:
                scan_text = sanitized

        line_starts = build_line_index(scan_text)
        file_matches: dict[str, list[int]] = {}

        for pattern in patterns:
            compiled = pattern["compiled"]
            matches = list(compiled.finditer(scan_text))
            if not matches:
                continue
            lines = [line_number(line_starts, m.start()) for m in matches]
            entry = entries[pattern["canonical"]]
            entry.add_match(pattern["alias"], rel_file, lines)
            file_matches.setdefault(pattern["canonical"], []).extend(lines)
            total_matches += len(lines)

        for name, lines in sorted(file_matches.items()):
            line_list = ", ".join(str(line) for line in sorted(set(lines)))
            log(
                f"{LOG_PREFIX}   {name}: {len(lines)} matches (line {line_list})",
                logger,
            )

    items = [
        entries[name].to_dict(occurrence_threshold, pattern_map)
        for name in sorted(entries.keys())
    ]
    high_frequency = [item for item in items if item["high_frequency"]]
    low_frequency = [
        item for item in items if item["total_occurrences"] > 0 and not item["high_frequency"]
    ]
    not_found = [item for item in items if item["total_occurrences"] == 0]

    log(f"{LOG_PREFIX} === Results Summary ===", logger)
    log(
        f"{LOG_PREFIX} High-frequency (>=3 files OR >=N): {len(high_frequency)}",
        logger,
    )
    log(f"{LOG_PREFIX} Low-frequency: {len(low_frequency)}", logger)
    log(f"{LOG_PREFIX} Not found: {len(not_found)}", logger)
    log(f"{LOG_PREFIX} Top 10 by frequency:", logger)

    top_10 = sorted(
        items,
        key=lambda item: (item["total_occurrences"], item["files_with_match"]),
        reverse=True,
    )[:10]
    for idx, item in enumerate(top_10, start=1):
        log(
            f"{LOG_PREFIX} {idx}. {item['name']}: "
            f"{item['total_occurrences']} occ in {item['files_with_match']} files",
            logger,
        )

    output = {
        "schema_version": "1.0",
        "generated_at": datetime.now(timezone.utc).isoformat(),  # noqa: UP017
        "system": system,
        "scan_config": {
            "mode": mode,
            "roots": [rel_path(r, project_root) for r in roots],
            "patterns_count": len(patterns),
            "patterns": [pattern["alias"] for pattern in patterns],
            "aliases_file": None,
            "occurrence_threshold": occurrence_threshold,
            "input_source": {},
            "cli": " ".join(sys.argv),
        },
        "scan_stats": {
            "files_scanned": len(file_paths),
            "fallback_used": fallback_used,
            "total_matches": total_matches,
        },
        "summary": {
            "total_items": len(items),
            "high_frequency": len(high_frequency),
            "low_frequency": len(low_frequency),
            "not_found": len(not_found),
        },
        "items": items,
        "top_10": [
            {
                "name": item["name"],
                "total_occurrences": item["total_occurrences"],
                "files_with_match": item["files_with_match"],
            }
            for item in top_10
        ],
    }

    return output, fallback_used


def validate_output(output: dict) -> None:
    if jsonschema is None:
        return
    jsonschema.validate(output, FREQUENCY_SCHEMA)


def main() -> int:
    parser = argparse.ArgumentParser(description="Scan Lua usage frequency.")
    parser.add_argument("--system", type=str, required=True, help="System name")
    parser.add_argument(
        "--input",
        type=Path,
        help="Input list of names (txt or json).",
    )
    parser.add_argument(
        "--bindings",
        type=Path,
        help="Bindings JSON to extract lua_name entries from.",
    )
    parser.add_argument(
        "--names",
        nargs="*",
        default=[],
        help="Explicit list of names to scan.",
    )
    parser.add_argument(
        "--roots",
        nargs="+",
        default=DEFAULT_ROOTS,
        help="Lua roots to scan (default: assets/scripts).",
    )
    parser.add_argument(
        "--mode",
        choices=["token_aware", "regex"],
        default="token_aware",
        help="Scan mode (default: token_aware).",
    )
    parser.add_argument(
        "--occurrence-threshold",
        type=int,
        default=DEFAULT_OCCURRENCE_THRESHOLD,
        help="High-frequency occurrence threshold (default: 10).",
    )
    parser.add_argument(
        "--aliases",
        type=Path,
        default=Path(DEFAULT_ALIAS_FILE),
        help="Alias config path (default: planning/frequency_aliases.yaml).",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(DEFAULT_OUTPUT_DIR),
        help="Output directory (default: planning/inventory).",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Override output file path.",
    )
    parser.add_argument(
        "--no-validate",
        action="store_true",
        help="Skip schema validation.",
    )

    args = parser.parse_args()

    script_dir = Path(__file__).parent
    project_root = script_dir.parent

    roots = [
        root if root.is_absolute() else project_root / root for root in args.roots
    ]
    aliases_path = (
        args.aliases
        if args.aliases.is_absolute()
        else project_root / args.aliases
    )
    output_dir = (
        args.output_dir
        if args.output_dir.is_absolute()
        else project_root / args.output_dir
    )

    names: list[str] = []
    bindings_used: Path | None = None
    input_used: Path | None = None
    if args.bindings:
        bindings_path = (
            args.bindings
            if args.bindings.is_absolute()
            else project_root / args.bindings
        )
        if bindings_path.exists():
            names.extend(load_names_from_file(bindings_path))
            bindings_used = bindings_path
    if args.input:
        input_path = (
            args.input if args.input.is_absolute() else project_root / args.input
        )
        if input_path.exists():
            names.extend(load_names_from_file(input_path))
            input_used = input_path
    if args.names:
        names.extend(args.names)

    if not names:
        default_bindings = project_root / "planning" / "inventory" / f"bindings.{args.system}.json"
        if default_bindings.exists():
            names.extend(load_names_from_file(default_bindings))
            bindings_used = default_bindings
        else:
            print(f"{LOG_PREFIX} ERROR: No input names provided.", file=sys.stderr)
            return 1

    names = sorted(set(names))

    alias_config = load_aliases(aliases_path) if aliases_path.exists() else {}

    output, _fallback_used = scan_frequency(
        names=names,
        roots=roots,
        system=args.system,
        mode=args.mode,
        aliases=alias_config,
        occurrence_threshold=args.occurrence_threshold,
        logger=None,
        project_root=project_root,
    )

    output["scan_config"]["aliases_file"] = rel_path(aliases_path, project_root)
    output["scan_config"]["input_source"] = {
        "bindings": rel_path(bindings_used, project_root) if bindings_used else None,
        "input": rel_path(input_used, project_root) if input_used else None,
        "names_count": len(names),
    }

    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = (
        args.output if args.output else output_dir / f"frequency.{args.system}.json"
    )
    output_path = (
        output_path if output_path.is_absolute() else project_root / output_path
    )

    if not args.no_validate:
        validate_output(output)

    log(f"{LOG_PREFIX} Writing {rel_path(output_path, project_root)}", None)
    output_path.write_text(json.dumps(output, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
