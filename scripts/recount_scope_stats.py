#!/usr/bin/env python3
"""
Recount Scope Stats - Single source of truth for codebase statistics.

Counts:
- Sol2 bindings from C++ files
- ECS components from components.hpp
- Lua scripts by directory

Output:
- planning/inventory/stats.json (machine-readable)
- planning/stats.md (human summary)

Usage:
    python3 scripts/recount_scope_stats.py [options]

Options:
    --verbose    Print detailed scanning info
    --dry-run    Scan but don't write output files
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from collections.abc import Iterator

# Logging prefix for parseable output
LOG_PREFIX = "[STATS]"

# Schema version for output format
SCHEMA_VERSION = "1.0"


def log(msg: str, verbose: bool = True) -> None:
    """Print with stats prefix."""
    if verbose:
        print(f"{LOG_PREFIX} {msg}")


@dataclass
class Sol2BindingStats:
    """Statistics for Sol2 bindings in a single file."""

    file: str
    types: int = 0
    functions: int = 0
    constants: int = 0


@dataclass
class Sol2Stats:
    """Aggregate Sol2 binding statistics."""

    total_types: int = 0
    total_functions: int = 0
    by_file: list[Sol2BindingStats] = field(default_factory=list)


@dataclass
class ComponentStats:
    """ECS component statistics."""

    total: int = 0
    by_category: dict[str, int] = field(default_factory=dict)


@dataclass
class LuaStats:
    """Lua script statistics."""

    total: int = 0
    by_directory: dict[str, int] = field(default_factory=dict)


@dataclass
class ScopeStats:
    """Complete scope statistics."""

    sol2_bindings: Sol2Stats = field(default_factory=Sol2Stats)
    ecs_components: ComponentStats = field(default_factory=ComponentStats)
    lua_scripts: LuaStats = field(default_factory=LuaStats)


# Regex patterns
USERTYPE_PATTERN = re.compile(
    r'(?:lua\.new_usertype|lua\.new_enum)\s*[<(]'
)
FUNCTION_PATTERN = re.compile(
    r'(?:rec\.add_function|lua\["[^"]+"\]\s*=|\.set_function)'
)
STRUCT_PATTERN = re.compile(
    r'^struct\s+(\w+)(?:\s*:\s*\w+)?\s*\{',
    re.MULTILINE,
)


def find_cpp_files(src_dir: Path) -> Iterator[Path]:
    """Find C++ files that may contain Sol2 bindings."""
    if not src_dir.exists():
        return
    for pattern in ["**/*.cpp", "**/*.hpp"]:
        yield from src_dir.glob(pattern)


def count_sol2_bindings(file_path: Path, verbose: bool = False) -> Sol2BindingStats | None:
    """Count Sol2 bindings in a C++ file."""
    try:
        content = file_path.read_text(encoding="utf-8", errors="replace")
    except Exception as e:
        log(f"  WARNING: Could not read {file_path}: {e}", verbose)
        return None

    # Quick check - skip files without sol2 patterns
    if "sol::" not in content and "lua." not in content:
        return None

    types = len(USERTYPE_PATTERN.findall(content))
    functions = len(FUNCTION_PATTERN.findall(content))

    if types == 0 and functions == 0:
        return None

    return Sol2BindingStats(
        file=str(file_path),
        types=types,
        functions=functions,
    )


def scan_sol2_bindings(src_dir: Path, verbose: bool = False) -> Sol2Stats:
    """Scan all C++ files for Sol2 bindings."""
    stats = Sol2Stats()

    for cpp_file in find_cpp_files(src_dir):
        file_stats = count_sol2_bindings(cpp_file, verbose)
        if file_stats:
            stats.by_file.append(file_stats)
            stats.total_types += file_stats.types
            stats.total_functions += file_stats.functions
            if verbose:
                log(f"  {cpp_file.name}: {file_stats.types} types, {file_stats.functions} functions")

    return stats


def categorize_component(name: str, context: str = "") -> str:
    """Categorize a component based on its name and context."""
    name_lower = name.lower()

    # Category patterns - order matters! More specific patterns first.
    # Use word boundaries via regex for short keywords that might match substrings.
    categories = [
        # Put specific/longer keywords first to avoid substring matches
        (["container", "inventory", "item"], "Inventory"),  # Before AI (container has "ai")
        (["goap", "blackboard", "aicomponent", "aisystem"], "AI"),  # More specific AI patterns
        (["tile", "location", "region"], "Core"),
        (["ninepatch", "sprite", "graphic", "render", "vfx", "color"], "Graphics"),
        (["physics", "body", "shape", "collision", "velocity"], "Physics"),
        (["uibox", "uielement", "button", "textfield"], "UI"),  # More specific UI patterns
        (["combat", "health", "damage", "weapon", "attack"], "Combat"),
        (["statetag", "marker", "flag"], "State"),  # More specific state patterns
        (["animation", "anim", "frame"], "Animation"),
        (["sound", "audio", "music"], "Audio"),
        (["script", "luacomponent", "coroutine"], "Scripting"),
        (["particle", "emitter"], "Particles"),
        (["transform", "position", "rotation", "scale"], "Transform"),
        (["timer", "delay", "cooldown"], "Timer"),
        (["info", "infocomponent", "desc"], "Metadata"),
    ]

    for keywords, category in categories:
        if any(kw in name_lower for kw in keywords):
            return category

    # Fallback patterns for less specific matches
    fallback_patterns = [
        (["ai"], "AI"),
        (["ui", "box", "element"], "UI"),
        (["state", "tag"], "State"),
        (["name"], "Metadata"),
    ]

    for keywords, category in fallback_patterns:
        if any(kw in name_lower for kw in keywords):
            return category

    return "Other"


def scan_components(components_file: Path, verbose: bool = False) -> ComponentStats:
    """Scan components.hpp for struct definitions."""
    stats = ComponentStats()

    if not components_file.exists():
        log(f"  WARNING: Components file not found: {components_file}", True)
        return stats

    try:
        content = components_file.read_text(encoding="utf-8", errors="replace")
    except Exception as e:
        log(f"  WARNING: Could not read {components_file}: {e}", True)
        return stats

    for match in STRUCT_PATTERN.finditer(content):
        name = match.group(1)
        category = categorize_component(name)
        stats.by_category.setdefault(category, 0)
        stats.by_category[category] += 1
        stats.total += 1

        if verbose:
            log(f"    {name} -> {category}")

    return stats


def scan_all_component_files(src_dir: Path, verbose: bool = False) -> ComponentStats:
    """Scan all component header files."""
    stats = ComponentStats()

    components_dir = src_dir / "components"
    if not components_dir.exists():
        log(f"  WARNING: Components directory not found: {components_dir}", True)
        return stats

    for hpp_file in components_dir.glob("*.hpp"):
        file_stats = scan_components(hpp_file, verbose)
        stats.total += file_stats.total
        for category, count in file_stats.by_category.items():
            stats.by_category.setdefault(category, 0)
            stats.by_category[category] += count

    # Also scan system-specific component files
    systems_dir = src_dir / "systems"
    if systems_dir.exists():
        for hpp_file in systems_dir.rglob("*_components*.hpp"):
            file_stats = scan_components(hpp_file, verbose)
            stats.total += file_stats.total
            for category, count in file_stats.by_category.items():
                stats.by_category.setdefault(category, 0)
                stats.by_category[category] += count

    return stats


def find_lua_files(scripts_dir: Path) -> Iterator[Path]:
    """Find Lua script files."""
    if not scripts_dir.exists():
        return
    yield from scripts_dir.rglob("*.lua")


def scan_lua_scripts(scripts_dir: Path, verbose: bool = False) -> LuaStats:
    """Scan Lua scripts by directory."""
    stats = LuaStats()

    for lua_file in find_lua_files(scripts_dir):
        stats.total += 1

        # Get relative directory path
        rel_path = lua_file.relative_to(scripts_dir)
        if rel_path.parent == Path("."):
            dir_key = "root"
        else:
            dir_key = str(rel_path.parent) + "/"

        stats.by_directory.setdefault(dir_key, 0)
        stats.by_directory[dir_key] += 1

    # Sort by count descending
    stats.by_directory = dict(
        sorted(stats.by_directory.items(), key=lambda x: -x[1])
    )

    return stats


def run_scan(
    src_dir: Path,
    scripts_dir: Path,
    verbose: bool = False,
) -> ScopeStats:
    """Run all scans and return aggregate statistics."""
    stats = ScopeStats()

    log("=== Recount Scope Stats ===", True)

    # Scan Sol2 bindings
    log("Scanning Sol2 bindings...", True)
    stats.sol2_bindings = scan_sol2_bindings(src_dir, verbose)
    log(f"Total bindings: {stats.sol2_bindings.total_types} types, {stats.sol2_bindings.total_functions} functions", True)

    # Scan ECS components
    log("Scanning ECS components...", True)
    stats.ecs_components = scan_all_component_files(src_dir, verbose)
    log(f"  Total: {stats.ecs_components.total} components", True)
    categories_summary = " ".join(
        f"{k}({v})" for k, v in sorted(stats.ecs_components.by_category.items())
    )
    if categories_summary:
        log(f"  Categories: {categories_summary}", True)

    # Scan Lua scripts
    log("Scanning Lua scripts...", True)
    stats.lua_scripts = scan_lua_scripts(scripts_dir, verbose)
    log(f"  Total: {stats.lua_scripts.total} files", True)
    dirs_summary = " ".join(
        f"{k.rstrip('/')}({v})" for k, v in list(stats.lua_scripts.by_directory.items())[:5]
    )
    if dirs_summary:
        log(f"  By directory: {dirs_summary}...", True)

    return stats


def stats_to_dict(stats: ScopeStats) -> dict:
    """Convert ScopeStats to JSON-serializable dict."""
    return {
        "schema_version": SCHEMA_VERSION,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "sol2_bindings": {
            "total_types": stats.sol2_bindings.total_types,
            "total_functions": stats.sol2_bindings.total_functions,
            "by_file": [
                {
                    "file": s.file,
                    "types": s.types,
                    "functions": s.functions,
                    "constants": s.constants,
                }
                for s in stats.sol2_bindings.by_file
            ],
        },
        "ecs_components": {
            "total": stats.ecs_components.total,
            "by_category": stats.ecs_components.by_category,
        },
        "lua_scripts": {
            "total": stats.lua_scripts.total,
            "by_directory": stats.lua_scripts.by_directory,
        },
    }


def generate_markdown(stats: ScopeStats) -> str:
    """Generate human-readable markdown summary."""
    lines = [
        "# Codebase Statistics",
        "",
        f"Generated: {datetime.now(timezone.utc).isoformat()}",
        "",
        "## Sol2 Bindings",
        "",
        "| File | Types | Functions |",
        "|------|-------|-----------|",
    ]

    for s in sorted(stats.sol2_bindings.by_file, key=lambda x: -(x.types + x.functions)):
        short_name = Path(s.file).name
        lines.append(f"| {short_name} | {s.types} | {s.functions} |")

    lines.extend([
        "",
        f"**Totals:** {stats.sol2_bindings.total_types} types, {stats.sol2_bindings.total_functions} functions",
        "",
        "## ECS Components",
        "",
        "| Category | Count |",
        "|----------|-------|",
    ])

    for category, count in sorted(stats.ecs_components.by_category.items(), key=lambda x: -x[1]):
        lines.append(f"| {category} | {count} |")

    lines.extend([
        "",
        f"**Total:** {stats.ecs_components.total} components",
        "",
        "## Lua Scripts",
        "",
        "| Directory | Count |",
        "|-----------|-------|",
    ])

    for directory, count in stats.lua_scripts.by_directory.items():
        lines.append(f"| {directory} | {count} |")

    lines.extend([
        "",
        f"**Total:** {stats.lua_scripts.total} scripts",
    ])

    return "\n".join(lines)


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(description="Recount codebase scope statistics")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    parser.add_argument("--dry-run", action="store_true", help="Don't write files")
    parser.add_argument(
        "--src-dir",
        type=Path,
        default=Path("src"),
        help="Source directory (default: src)",
    )
    parser.add_argument(
        "--scripts-dir",
        type=Path,
        default=Path("assets/scripts"),
        help="Scripts directory (default: assets/scripts)",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("planning/inventory"),
        help="Output directory (default: planning/inventory)",
    )
    args = parser.parse_args()

    # Run scan
    stats = run_scan(args.src_dir, args.scripts_dir, args.verbose)

    if args.dry_run:
        log("Dry run - not writing files", True)
        return 0

    # Ensure output directory exists
    args.output_dir.mkdir(parents=True, exist_ok=True)

    # Write JSON
    json_file = args.output_dir / "stats.json"
    log(f"Writing {json_file}", True)
    json_file.write_text(json.dumps(stats_to_dict(stats), indent=2))

    # Write markdown
    md_file = args.output_dir.parent / "stats.md"
    log(f"Writing {md_file}", True)
    md_file.write_text(generate_markdown(stats))

    log("Complete.", True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
