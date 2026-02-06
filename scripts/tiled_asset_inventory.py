#!/usr/bin/env python3
"""Build and validate mandatory Tiled asset taxonomy coverage.

Scans configured asset folders, extracts descriptor names from filenames, maps
them to taxonomy categories via ordered regex rules, and emits a machine-readable
manifest. Intended for strict "no missing assets" coverage gates.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any


DEFAULT_CONFIG = Path("planning/tiled_assets/asset_taxonomy_rules.json")
DEFAULT_OUTPUT = Path("planning/tiled_assets/required_asset_manifest.json")
FILENAME_RE = re.compile(r"^(?P<prefix>[A-Za-z0-9]+)_(?P<index>\d{3})_(?P<desc>.+)$")


@dataclass(frozen=True)
class SourceSpec:
    name: str
    path: Path
    expected_count: int | None


@dataclass(frozen=True)
class RuleSpec:
    category: str
    pattern: str
    source: str | None


@dataclass(frozen=True)
class Config:
    categories: set[str]
    sources: list[SourceSpec]
    rules: list[RuleSpec]
    extensions: set[str]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate strict taxonomy coverage manifest for required dungeon assets."
    )
    parser.add_argument(
        "--config",
        type=Path,
        default=DEFAULT_CONFIG,
        help=f"Path to taxonomy config JSON (default: {DEFAULT_CONFIG})",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Output manifest path (default: {DEFAULT_OUTPUT})",
    )
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path.cwd(),
        help="Project root for resolving relative source/config paths (default: cwd).",
    )
    parser.add_argument(
        "--check-only",
        action="store_true",
        help="Validate and print summary without writing output.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print summary JSON to stdout.",
    )
    parser.add_argument(
        "--allow-uncategorized",
        action="store_true",
        help="Do not fail when uncategorized files are present.",
    )
    return parser.parse_args()


def _load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        loaded = json.load(f)
    if not isinstance(loaded, dict):
        raise ValueError(f"Config root must be an object: {path}")
    return loaded


def _resolve_path(project_root: Path, maybe_relative: str | Path) -> Path:
    p = Path(maybe_relative)
    if not p.is_absolute():
        p = (project_root / p).resolve()
    return p


def load_config(config_path: Path, project_root: Path) -> Config:
    data = _load_json(config_path)

    categories_raw = data.get("categories", [])
    if not isinstance(categories_raw, list) or not categories_raw:
        raise ValueError("Config must include non-empty 'categories' list.")
    categories = {str(c) for c in categories_raw}

    extensions_raw = data.get("extensions", [".png"])
    if not isinstance(extensions_raw, list) or not extensions_raw:
        raise ValueError("Config must include non-empty 'extensions' list.")
    extensions = {str(e).lower() for e in extensions_raw}

    sources_raw = data.get("sources", [])
    if not isinstance(sources_raw, list) or not sources_raw:
        raise ValueError("Config must include non-empty 'sources' list.")
    sources: list[SourceSpec] = []
    for idx, src in enumerate(sources_raw):
        if not isinstance(src, dict):
            raise ValueError(f"sources[{idx}] must be an object.")
        name = str(src.get("name", "")).strip()
        path_str = str(src.get("path", "")).strip()
        if not name or not path_str:
            raise ValueError(f"sources[{idx}] must include non-empty 'name' and 'path'.")
        expected = src.get("expected_count")
        if expected is not None:
            expected = int(expected)
            if expected < 0:
                raise ValueError(f"sources[{idx}].expected_count cannot be negative.")
        sources.append(
            SourceSpec(
                name=name,
                path=_resolve_path(project_root, path_str),
                expected_count=expected,
            )
        )

    rules_raw = data.get("rules", [])
    if not isinstance(rules_raw, list) or not rules_raw:
        raise ValueError("Config must include non-empty 'rules' list.")
    rules: list[RuleSpec] = []
    for idx, rule in enumerate(rules_raw):
        if not isinstance(rule, dict):
            raise ValueError(f"rules[{idx}] must be an object.")
        category = str(rule.get("category", "")).strip()
        pattern = str(rule.get("pattern", "")).strip()
        source = rule.get("source")
        source_name = str(source).strip() if source is not None else None
        if not category or not pattern:
            raise ValueError(f"rules[{idx}] must include non-empty 'category' and 'pattern'.")
        if category not in categories:
            raise ValueError(f"rules[{idx}] references unknown category '{category}'.")
        if source_name is not None and source_name not in {s.name for s in sources}:
            raise ValueError(f"rules[{idx}] references unknown source '{source_name}'.")
        re.compile(pattern)
        rules.append(RuleSpec(category=category, pattern=pattern, source=source_name))

    return Config(categories=categories, sources=sources, rules=rules, extensions=extensions)


def descriptor_from_stem(stem: str) -> str:
    m = FILENAME_RE.match(stem)
    if m is not None:
        return m.group("desc")
    return stem


def _to_rel(project_root: Path, path: Path) -> str:
    try:
        return path.resolve().relative_to(project_root.resolve()).as_posix()
    except Exception:
        return path.resolve().as_posix()


def build_manifest(config: Config, project_root: Path) -> dict[str, Any]:
    compiled_rules: list[tuple[RuleSpec, re.Pattern[str]]] = [
        (rule, re.compile(rule.pattern)) for rule in config.rules
    ]

    files: list[dict[str, Any]] = []
    uncategorized: list[str] = []
    source_errors: list[str] = []
    source_counts: dict[str, int] = {}
    category_counts: Counter[str] = Counter()
    category_files: dict[str, list[str]] = defaultdict(list)

    for source in config.sources:
        if not source.path.exists():
            source_errors.append(f"Missing source path: {source.path}")
            source_counts[source.name] = 0
            continue
        if not source.path.is_dir():
            source_errors.append(f"Source is not a directory: {source.path}")
            source_counts[source.name] = 0
            continue

        matched_files = [
            p for p in sorted(source.path.rglob("*")) if p.is_file() and p.suffix.lower() in config.extensions
        ]
        source_counts[source.name] = len(matched_files)
        if source.expected_count is not None and len(matched_files) != source.expected_count:
            source_errors.append(
                f"Source '{source.name}' expected {source.expected_count} files, found {len(matched_files)}"
            )

        for p in matched_files:
            descriptor = descriptor_from_stem(p.stem)
            category = None
            matched_pattern = None
            for rule, pattern in compiled_rules:
                if rule.source is not None and rule.source != source.name:
                    continue
                if pattern.search(descriptor):
                    category = rule.category
                    matched_pattern = rule.pattern
                    break

            rel_path = _to_rel(project_root, p)
            if category is None:
                category = "uncategorized"
                uncategorized.append(rel_path)
            else:
                category_counts[category] += 1
                category_files[category].append(rel_path)

            files.append(
                {
                    "source": source.name,
                    "path": rel_path,
                    "filename": p.name,
                    "stem": p.stem,
                    "descriptor": descriptor,
                    "category": category,
                    "matched_pattern": matched_pattern,
                }
            )

    files.sort(key=lambda f: f["path"])
    uncategorized.sort()

    return {
        "schema_version": "1.0",
        "project_root": project_root.resolve().as_posix(),
        "sources": [
            {
                "name": s.name,
                "path": _to_rel(project_root, s.path),
                "expected_count": s.expected_count,
                "actual_count": source_counts.get(s.name, 0),
            }
            for s in config.sources
        ],
        "total_files": len(files),
        "categorized_files": int(sum(category_counts.values())),
        "uncategorized_count": len(uncategorized),
        "category_counts": dict(sorted(category_counts.items())),
        "category_files": {k: sorted(v) for k, v in sorted(category_files.items())},
        "uncategorized_files": uncategorized,
        "source_errors": source_errors,
        "files": files,
    }


def validate_manifest(manifest: dict[str, Any], fail_on_uncategorized: bool) -> list[str]:
    errors: list[str] = []
    source_errors = manifest.get("source_errors", [])
    if source_errors:
        errors.extend(str(e) for e in source_errors)

    uncategorized_count = int(manifest.get("uncategorized_count", 0))
    if fail_on_uncategorized and uncategorized_count > 0:
        errors.append(f"Found {uncategorized_count} uncategorized files")

    total = int(manifest.get("total_files", 0))
    categorized = int(manifest.get("categorized_files", 0))
    if categorized + uncategorized_count != total:
        errors.append(
            f"Count mismatch: categorized({categorized}) + uncategorized({uncategorized_count}) != total({total})"
        )

    return errors


def _summary(manifest: dict[str, Any]) -> dict[str, Any]:
    return {
        "total_files": manifest.get("total_files", 0),
        "categorized_files": manifest.get("categorized_files", 0),
        "uncategorized_count": manifest.get("uncategorized_count", 0),
        "source_errors": manifest.get("source_errors", []),
        "category_counts": manifest.get("category_counts", {}),
    }


def main() -> int:
    args = parse_args()
    project_root = args.project_root.resolve()
    config_path = _resolve_path(project_root, args.config)
    output_path = _resolve_path(project_root, args.output)

    try:
        config = load_config(config_path, project_root)
        manifest = build_manifest(config, project_root)
        errors = validate_manifest(manifest, fail_on_uncategorized=not args.allow_uncategorized)
    except Exception as exc:  # pragma: no cover - defensive CLI layer
        print(f"[TILED_ASSET_INVENTORY] ERROR: {exc}", file=sys.stderr)
        return 2

    if not args.check_only:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    summary = _summary(manifest)
    if args.json:
        print(json.dumps(summary, indent=2))
    else:
        print("[TILED_ASSET_INVENTORY] Summary")
        print(f"[TILED_ASSET_INVENTORY]   total_files       : {summary['total_files']}")
        print(f"[TILED_ASSET_INVENTORY]   categorized_files : {summary['categorized_files']}")
        print(f"[TILED_ASSET_INVENTORY]   uncategorized     : {summary['uncategorized_count']}")
        if summary["source_errors"]:
            print("[TILED_ASSET_INVENTORY]   source_errors:")
            for err in summary["source_errors"]:
                print(f"[TILED_ASSET_INVENTORY]     - {err}")
        if summary["category_counts"]:
            print("[TILED_ASSET_INVENTORY]   category_counts:")
            for category, count in summary["category_counts"].items():
                print(f"[TILED_ASSET_INVENTORY]     - {category}: {count}")

    if errors:
        for err in errors:
            print(f"[TILED_ASSET_INVENTORY] ERROR: {err}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

