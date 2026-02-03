#!/usr/bin/env python3
"""Select tests based on changed files using impact map."""
from __future__ import annotations

import argparse
import fnmatch
import subprocess
from pathlib import Path
from typing import Any

import yaml

LOG_PREFIX = "[SELECT]"


def log(message: str) -> None:
    print(f"{LOG_PREFIX} {message}")


def load_impact_map(path: Path | None = None) -> dict[str, Any]:
    impact_path = path or Path("planning/test_impact_map.yaml")
    if not impact_path.exists():
        raise FileNotFoundError(f"Impact map not found: {impact_path}")
    with impact_path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


def get_changed_files(base_ref: str = "origin/main") -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--name-only", base_ref],
        capture_output=True,
        text=True,
        check=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def match_rules(changed_files: list[str], impact_map: dict[str, Any]) -> tuple[set[str], set[str], bool]:
    matched_categories: set[str] = set()
    matched_tags: set[str] = set()
    skip_tests = False

    for rule in impact_map.get("impact_rules", []):
        for pattern in rule.get("globs", []):
            for file_path in changed_files:
                if fnmatch.fnmatch(file_path, pattern):
                    log(f"{file_path} matches rule: {rule.get('name', 'unnamed')}")
                    filters = rule.get("filters", {})
                    categories = filters.get("categories", [])
                    tags = filters.get("tags", [])
                    if "*" in categories:
                        matched_categories.add("*")
                    else:
                        matched_categories.update(categories)
                    matched_tags.update(tags)
                    if rule.get("skip_tests"):
                        skip_tests = True
                    break

    default = impact_map.get("default", {})
    matched_categories.update(default.get("categories", ["smoke"]))
    matched_tags.update(default.get("tags", []))

    return matched_categories, matched_tags, skip_tests


def format_runner_args(categories: set[str], tags: set[str], skip_tests: bool) -> str:
    if skip_tests:
        return "--skip-tests --validators-only"

    args: list[str] = []
    if "*" in categories:
        args.append("--all-categories")
    elif categories:
        args.append(f"--categories={','.join(sorted(categories))}")

    if "*" in tags:
        args.append("--tags-any=*")
    elif tags:
        args.append(f"--tags-any={','.join(sorted(tags))}")

    return " ".join(args)


def nightly_args(impact_map: dict[str, Any]) -> str:
    nightly = impact_map.get("nightly", {})
    args = ["--all-categories"]
    if nightly.get("include_slow"):
        args.append("--include-slow")
    if nightly.get("include_visual"):
        args.append("--include-visual")
    return " ".join(args)


def main() -> int:
    parser = argparse.ArgumentParser(description="Select tests based on changed files")
    parser.add_argument("--base", default="origin/main", help="Base ref for git diff")
    parser.add_argument("--changes", help="Explicit list of changed files (newline separated)")
    parser.add_argument("--nightly", action="store_true", help="Select full nightly suite")
    parser.add_argument("--verbose", action="store_true", help="Verbose output")
    args = parser.parse_args()

    log("=== Test Selection Based on Changed Files ===")
    log(f"Base ref: {args.base}")

    impact_map = load_impact_map()

    if args.nightly:
        log("Nightly mode: selecting full suite")
        print(nightly_args(impact_map))
        return 0

    if args.changes:
        changed_files = [line.strip() for line in args.changes.splitlines() if line.strip()]
    else:
        changed_files = get_changed_files(args.base)

    log(f"Changed files: {len(changed_files)}")
    if args.verbose:
        for file_path in changed_files:
            log(f"  {file_path}")

    log("Matching against impact rules...")
    categories, tags, skip_tests = match_rules(changed_files, impact_map)

    log(f"Results:\n  Categories: {sorted(categories)}\n  Tags: {sorted(tags)}\n  Skip tests: {skip_tests}")

    runner_args = format_runner_args(categories, tags, skip_tests)
    print(runner_args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
