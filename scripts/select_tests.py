#!/usr/bin/env python3
"""Select tests based on changed files using impact map."""

import argparse
import fnmatch
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover - handled in main
    yaml = None


IMPACT_MAP_PATH = Path("planning/test_impact_map.yaml")


def log_line(stream, message):
    print(message, file=stream)


def load_impact_map(path=IMPACT_MAP_PATH):
    """Load test impact mapping from YAML."""
    if yaml is None:
        raise ImportError("PyYAML is required to read the impact map")
    with open(path, "r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle)
    return data or {}


def get_changed_files(base_ref="origin/main"):
    """Get list of changed files from git diff."""
    result = subprocess.run(
        ["git", "diff", "--name-only", base_ref],
        capture_output=True,
        text=True,
        check=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def parse_changes_arg(changes):
    """Parse newline-separated changes input."""
    if not changes:
        return []
    return [line.strip() for line in changes.splitlines() if line.strip()]


def match_rules(changed_files, impact_map, log=None):
    """Match changed files against impact rules."""
    matched_categories = set()
    matched_tags = set()
    skip_tests = False

    for rule in impact_map.get("impact_rules", []):
        rule_name = rule.get("name", "unnamed")
        globs = rule.get("globs", [])
        matched_files = []

        for file_path in changed_files:
            for pattern in globs:
                if fnmatch.fnmatch(file_path, pattern):
                    matched_files.append(file_path)
                    break

        if matched_files:
            if log:
                for file_path in matched_files:
                    log(f"[SELECT]   {file_path} matches rule: {rule_name}")

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

    default = impact_map.get("default", {})
    default_categories = default.get("categories")
    if not default_categories:
        default_categories = ["smoke"]
    matched_categories.update(default_categories)
    matched_tags.update(default.get("tags", []))

    return matched_categories, matched_tags, skip_tests


def format_runner_args(categories, tags, skip_tests=False, include_slow=False, include_visual=False):
    """Format arguments for test runner."""
    args = []

    if skip_tests:
        return "--skip-tests --validators-only"

    if "*" in categories:
        args.append("--all-categories")
    elif categories:
        args.append(f"--categories={','.join(sorted(categories))}")

    if "*" in tags:
        args.append("--tags-any=*")
    elif tags:
        args.append(f"--tags-any={','.join(sorted(tags))}")

    if include_slow:
        args.append("--include-slow")
    if include_visual:
        args.append("--include-visual")

    return " ".join(args)


def _sorted_display(values):
    return ", ".join(sorted(values)) if values else "(none)"


def select_tests(changed_files, impact_map, base_ref, stream, verbose=False):
    log_line(stream, "[SELECT] === Test Selection Based on Changed Files ===")
    log_line(stream, f"[SELECT] Base ref: {base_ref}")
    log_line(stream, f"[SELECT] Changed files: {len(changed_files)}")

    if verbose and changed_files:
        for file_path in changed_files:
            log_line(stream, f"[SELECT]   {file_path}")

    log_line(stream, "")
    log_line(stream, "[SELECT] Matching against impact rules...")

    categories, tags, skip_tests = match_rules(
        changed_files,
        impact_map,
        log=lambda msg: log_line(stream, msg),
    )

    log_line(stream, "")
    log_line(stream, "[SELECT] Results:")
    log_line(stream, f"[SELECT]   Categories: {_sorted_display(categories)}")
    log_line(stream, f"[SELECT]   Tags: {_sorted_display(tags)}")
    log_line(stream, f"[SELECT]   Skip tests: {str(skip_tests).lower()}")

    runner_args = format_runner_args(categories, tags, skip_tests=skip_tests)

    log_line(stream, "")
    log_line(stream, "[SELECT] Runner args:")
    log_line(stream, runner_args)

    return runner_args


def select_nightly(impact_map, stream):
    nightly = impact_map.get("nightly", {})
    categories = set(nightly.get("categories", ["*"]))
    include_slow = bool(nightly.get("include_slow"))
    include_visual = bool(nightly.get("include_visual"))

    log_line(stream, "[SELECT] Nightly mode: selecting full suite")
    log_line(stream, "[SELECT] Runner args:")

    runner_args = format_runner_args(
        categories,
        set(),
        include_slow=include_slow,
        include_visual=include_visual,
    )

    log_line(stream, runner_args)
    return runner_args


def main():
    parser = argparse.ArgumentParser(description="Select tests based on changed files")
    parser.add_argument("--base", default="origin/main", help="Base ref for diff")
    parser.add_argument("--changes", help="Explicit list of changed files (newline separated)")
    parser.add_argument("--nightly", action="store_true", help="Select nightly full suite")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    if yaml is None:
        print("ERROR: PyYAML is required. Install with: pip install pyyaml", file=sys.stderr)
        raise SystemExit(2)

    try:
        impact_map = load_impact_map()
    except FileNotFoundError:
        print(
            f"ERROR: Impact map not found at {IMPACT_MAP_PATH}.",
            file=sys.stderr,
        )
        raise SystemExit(1)

    if args.nightly:
        select_nightly(impact_map, sys.stdout)
        return

    if args.changes:
        changed_files = parse_changes_arg(args.changes)
    else:
        changed_files = get_changed_files(args.base)

    select_tests(changed_files, impact_map, args.base, sys.stdout, verbose=args.verbose)


if __name__ == "__main__":
    main()
