#!/usr/bin/env python3
"""Validate wall autotile rule coverage for required Tiled asset folders.

This script guarantees every wall asset from the required manifest is explicitly
accounted for as either:
- mapped: referenced by at least one runtime wall ruleset, or
- excluded: intentionally deferred with a reason.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any

DEFAULT_MANIFEST = Path("planning/tiled_assets/required_asset_manifest.json")
DEFAULT_RULESETS_DIR = Path("planning/tiled_assets/rulesets")
DEFAULT_OUTPUT = Path("planning/tiled_assets/rulesets/wall_rule_coverage_report.json")


@dataclass(frozen=True)
class RulesetCoverage:
    ruleset_id: str
    runtime_path: Path
    source_assets: set[str]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate wall autotile ruleset coverage and emit a report."
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=DEFAULT_MANIFEST,
        help=f"Path to required asset manifest (default: {DEFAULT_MANIFEST})",
    )
    parser.add_argument(
        "--rulesets-dir",
        type=Path,
        default=DEFAULT_RULESETS_DIR,
        help=f"Directory containing *_walls.runtime.json rulesets (default: {DEFAULT_RULESETS_DIR})",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Coverage report output path (default: {DEFAULT_OUTPUT})",
    )
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path.cwd(),
        help="Project root for resolving relative paths (default: cwd).",
    )
    parser.add_argument(
        "--check-only",
        action="store_true",
        help="Run validation only and skip writing output file.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print compact summary JSON to stdout.",
    )
    return parser.parse_args()


def _resolve_path(project_root: Path, maybe_relative: Path) -> Path:
    p = Path(maybe_relative)
    if not p.is_absolute():
        p = (project_root / p).resolve()
    return p


def _to_rel(project_root: Path, path: Path) -> str:
    try:
        return path.resolve().relative_to(project_root.resolve()).as_posix()
    except Exception:
        return path.resolve().as_posix()


def _load_json_object(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        loaded = json.load(f)
    if not isinstance(loaded, dict):
        raise ValueError(f"JSON root must be an object: {path}")
    return loaded


def _normalize_asset_path(project_root: Path, path_like: str) -> str:
    p = Path(path_like)
    if p.is_absolute():
        return _to_rel(project_root, p)
    return p.as_posix()


def load_manifest_walls(manifest_path: Path, project_root: Path) -> set[str]:
    data = _load_json_object(manifest_path)
    category_files = data.get("category_files")
    if not isinstance(category_files, dict):
        raise ValueError("Manifest must contain object field 'category_files'.")

    walls_raw = category_files.get("walls")
    if not isinstance(walls_raw, list) or not walls_raw:
        raise ValueError("Manifest 'category_files.walls' must be a non-empty list.")

    walls: set[str] = set()
    for item in walls_raw:
        if not isinstance(item, str) or not item.strip():
            raise ValueError("Manifest wall entries must be non-empty strings.")
        walls.add(_normalize_asset_path(project_root, item.strip()))

    return walls


def load_runtime_ruleset(runtime_path: Path, project_root: Path) -> RulesetCoverage:
    data = _load_json_object(runtime_path)

    raw_ruleset_id = data.get("ruleset")
    if isinstance(raw_ruleset_id, str) and raw_ruleset_id.strip():
        ruleset_id = raw_ruleset_id.strip()
    else:
        stem = runtime_path.stem
        if stem.endswith(".runtime"):
            stem = stem[: -len(".runtime")]
        ruleset_id = stem

    source_assets_raw = data.get("source_assets", [])
    if not isinstance(source_assets_raw, list):
        raise ValueError(f"{runtime_path}: 'source_assets' must be a list.")

    source_assets: set[str] = set()
    for item in source_assets_raw:
        if not isinstance(item, str):
            raise ValueError(f"{runtime_path}: source_assets entries must be strings.")
        stripped = item.strip()
        if not stripped:
            continue
        source_assets.add(_normalize_asset_path(project_root, stripped))

    return RulesetCoverage(
        ruleset_id=ruleset_id,
        runtime_path=runtime_path,
        source_assets=source_assets,
    )


def discover_runtime_rulesets(rulesets_dir: Path, project_root: Path) -> list[RulesetCoverage]:
    runtime_paths = sorted(rulesets_dir.glob("*_walls.runtime.json"))
    if not runtime_paths:
        raise ValueError(
            f"No runtime wall rulesets found in {rulesets_dir} (expected *_walls.runtime.json)."
        )
    return [load_runtime_ruleset(path, project_root) for path in runtime_paths]


def infer_exclusion_reason(asset_path: str) -> str:
    stem = Path(asset_path).stem.lower()

    if "shade_" in stem:
        return "Lighting/shade variant excluded from structural cardinal autotiling in v1."
    if any(token in stem for token in ("block_lower", "block_left", "block_right", "block_upper")):
        return "Partial block wall variant reserved for bespoke placement, not auto-selected in v1."
    if "bridge" in stem:
        return "Bridge tile treated as a distinct gameplay feature layer, not wall autotile core."
    if "wall_" in stem:
        return "Standalone wall motif tile excluded from cardinal bitmask base in v1."
    if "box_" in stem:
        return "Wall glyph variant excluded from the canonical cardinal mapping in v1."

    return "Wall asset intentionally excluded from v1 canonical autotile mapping."


def build_coverage_report(
    manifest_walls: set[str],
    rulesets: list[RulesetCoverage],
    project_root: Path,
    manifest_path: Path,
    rulesets_dir: Path,
) -> dict[str, Any]:
    mapped_rulesets_by_asset: dict[str, set[str]] = defaultdict(set)
    unknown_mapped_assets: set[str] = set()

    ruleset_summaries: list[dict[str, Any]] = []
    for ruleset in rulesets:
        mapped_assets = sorted(asset for asset in ruleset.source_assets if asset in manifest_walls)
        unknown_assets = sorted(asset for asset in ruleset.source_assets if asset not in manifest_walls)

        ruleset_summaries.append(
            {
                "ruleset_id": ruleset.ruleset_id,
                "runtime_path": _to_rel(project_root, ruleset.runtime_path),
                "mapped_assets": mapped_assets,
                "mapped_count": len(mapped_assets),
                "unknown_assets": unknown_assets,
                "unknown_count": len(unknown_assets),
            }
        )

        for asset in mapped_assets:
            mapped_rulesets_by_asset[asset].add(ruleset.ruleset_id)
        for asset in unknown_assets:
            unknown_mapped_assets.add(asset)

    entries: list[dict[str, Any]] = []
    mapped_count = 0
    excluded_count = 0

    for asset in sorted(manifest_walls):
        mapped_by = sorted(mapped_rulesets_by_asset.get(asset, set()))
        if mapped_by:
            entries.append(
                {
                    "asset": asset,
                    "status": "mapped",
                    "rulesets": mapped_by,
                    "reason": "Referenced by runtime wall autotile ruleset source assets.",
                }
            )
            mapped_count += 1
        else:
            entries.append(
                {
                    "asset": asset,
                    "status": "excluded",
                    "rulesets": [],
                    "reason": infer_exclusion_reason(asset),
                }
            )
            excluded_count += 1

    accounted_assets = {entry["asset"] for entry in entries}
    uncovered_assets = sorted(manifest_walls - accounted_assets)

    return {
        "schema_version": "1.0",
        "project_root": project_root.resolve().as_posix(),
        "manifest": _to_rel(project_root, manifest_path),
        "rulesets_dir": _to_rel(project_root, rulesets_dir),
        "total_wall_assets": len(manifest_walls),
        "mapped_count": mapped_count,
        "excluded_count": excluded_count,
        "unknown_mapped_count": len(unknown_mapped_assets),
        "unknown_mapped_assets": sorted(unknown_mapped_assets),
        "uncovered_count": len(uncovered_assets),
        "uncovered_assets": uncovered_assets,
        "rulesets": sorted(ruleset_summaries, key=lambda item: item["ruleset_id"]),
        "entries": entries,
    }


def validate_coverage_report(report: dict[str, Any]) -> list[str]:
    errors: list[str] = []

    total = int(report.get("total_wall_assets", 0))
    mapped = int(report.get("mapped_count", 0))
    excluded = int(report.get("excluded_count", 0))
    uncovered_count = int(report.get("uncovered_count", 0))
    unknown_count = int(report.get("unknown_mapped_count", 0))

    if mapped + excluded != total:
        errors.append(
            f"Count mismatch: mapped({mapped}) + excluded({excluded}) != total_wall_assets({total})"
        )

    if uncovered_count > 0:
        errors.append(f"Found {uncovered_count} uncovered wall assets")

    if unknown_count > 0:
        errors.append(f"Found {unknown_count} mapped assets not present in manifest walls")

    entries = report.get("entries")
    if not isinstance(entries, list):
        errors.append("Report 'entries' must be a list")
    else:
        if len(entries) != total:
            errors.append(f"Report entries length {len(entries)} does not match total_wall_assets {total}")
        seen_assets: set[str] = set()
        for entry in entries:
            if not isinstance(entry, dict):
                errors.append("Report entry is not an object")
                continue
            asset = entry.get("asset")
            status = entry.get("status")
            reason = entry.get("reason")
            if not isinstance(asset, str) or not asset:
                errors.append("Report entry missing non-empty 'asset'")
                continue
            if asset in seen_assets:
                errors.append(f"Duplicate report entry for asset: {asset}")
            seen_assets.add(asset)
            if status not in {"mapped", "excluded"}:
                errors.append(f"Invalid status '{status}' for asset: {asset}")
            if not isinstance(reason, str) or not reason.strip():
                errors.append(f"Missing exclusion/mapping reason for asset: {asset}")

    rulesets = report.get("rulesets")
    if not isinstance(rulesets, list) or not rulesets:
        errors.append("Report must contain at least one runtime ruleset summary")

    return errors


def summary(report: dict[str, Any]) -> dict[str, Any]:
    return {
        "total_wall_assets": report.get("total_wall_assets", 0),
        "mapped_count": report.get("mapped_count", 0),
        "excluded_count": report.get("excluded_count", 0),
        "uncovered_count": report.get("uncovered_count", 0),
        "unknown_mapped_count": report.get("unknown_mapped_count", 0),
        "ruleset_count": len(report.get("rulesets", [])),
    }


def main() -> int:
    args = parse_args()
    project_root = args.project_root.resolve()
    manifest_path = _resolve_path(project_root, args.manifest)
    rulesets_dir = _resolve_path(project_root, args.rulesets_dir)
    output_path = _resolve_path(project_root, args.output)

    try:
        manifest_walls = load_manifest_walls(manifest_path, project_root)
        rulesets = discover_runtime_rulesets(rulesets_dir, project_root)
        report = build_coverage_report(
            manifest_walls=manifest_walls,
            rulesets=rulesets,
            project_root=project_root,
            manifest_path=manifest_path,
            rulesets_dir=rulesets_dir,
        )
        errors = validate_coverage_report(report)
    except Exception as exc:  # pragma: no cover - defensive CLI layer
        print(f"[TILED_WALL_RULE_COVERAGE] ERROR: {exc}", file=sys.stderr)
        return 2

    if not args.check_only:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(report, indent=2), encoding="utf-8")

    out_summary = summary(report)
    if args.json:
        print(json.dumps(out_summary, indent=2))
    else:
        print("[TILED_WALL_RULE_COVERAGE] Summary")
        print(f"[TILED_WALL_RULE_COVERAGE]   total_wall_assets : {out_summary['total_wall_assets']}")
        print(f"[TILED_WALL_RULE_COVERAGE]   mapped_count      : {out_summary['mapped_count']}")
        print(f"[TILED_WALL_RULE_COVERAGE]   excluded_count    : {out_summary['excluded_count']}")
        print(f"[TILED_WALL_RULE_COVERAGE]   uncovered_count   : {out_summary['uncovered_count']}")
        print(
            f"[TILED_WALL_RULE_COVERAGE]   unknown_mapped    : {out_summary['unknown_mapped_count']}"
        )
        print(f"[TILED_WALL_RULE_COVERAGE]   ruleset_count     : {out_summary['ruleset_count']}")

    if errors:
        for err in errors:
            print(f"[TILED_WALL_RULE_COVERAGE] ERROR: {err}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
