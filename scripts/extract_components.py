#!/usr/bin/env python3
"""
ECS Component Extractor for TheGameJamTemplate.

Extracts component definitions from C++ headers to generate:
- Component inventory JSON files by category
- Lua accessibility matrix skeleton

Usage:
    python3 scripts/extract_components.py [options]

Options:
    --verbose    Print detailed extraction info
    --dry-run    Parse but don't write output files

Output:
    planning/inventory/components.{category}.json
    planning/components/lua_accessibility_matrix.md
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from collections.abc import Generator

# Extraction logging prefix
LOG_PREFIX = "[EXTRACT]"


def log(msg: str, verbose: bool = True) -> None:
    """Log with extraction prefix."""
    if verbose:
        print(f"{LOG_PREFIX} {msg}")


@dataclass
class FieldInfo:
    """Information about a struct field."""

    name: str
    type: str
    default: str | None = None
    is_complex: bool = False


@dataclass
class ComponentInfo:
    """Information about an extracted component."""

    name: str
    category: str
    file_path: str
    line_number: int
    fields: list[FieldInfo] = field(default_factory=list)
    is_tag: bool = False  # Empty struct = tag component
    extraction_confidence: float = 1.0
    notes: list[str] = field(default_factory=list)


# Regex patterns for C++ parsing
STRUCT_PATTERN = re.compile(
    r"^struct\s+(\w+)(?:\s*:\s*\w+)?\s*\{",
    re.MULTILINE,
)

FIELD_PATTERN = re.compile(
    r"^\s*(?:const\s+)?(\w+(?:::\w+)?(?:<[^>]+>)?(?:\s*\*)?)\s+(\w+)(?:\s*\{([^}]*)\}|\s*=\s*([^;]+))?;",
    re.MULTILINE,
)

# Component categories by directory path
CATEGORY_MAP = {
    "components/": "core",
    "physics/": "physics",
    "composable_mechanics/": "combat",
    "ui/": "ui",
    "particles/": "particles",
    "layer/": "rendering",
    "input/": "input",
    "ai/": "ai",
    "scripting/": "scripting",
    "anim": "animation",
}

# Complex types that reduce extraction confidence
COMPLEX_TYPES = {
    "std::vector",
    "std::map",
    "std::unordered_map",
    "std::function",
    "std::queue",
    "std::any",
    "sol::table",
    "sol::function",
    "sol::coroutine",
    "sol::thread",
}


def categorize_file(file_path: Path) -> str:
    """Determine component category from file path."""
    path_str = str(file_path)
    for pattern, category in CATEGORY_MAP.items():
        if pattern in path_str:
            return category
    return "other"


def is_complex_type(type_str: str) -> bool:
    """Check if type is complex (templates, containers, etc.)."""
    return any(ct in type_str for ct in COMPLEX_TYPES)


def extract_struct_block(content: str, start_pos: int) -> tuple[str, int]:
    """Extract struct body handling nested braces."""
    brace_count = 0
    in_struct = False
    end_pos = start_pos

    for i, char in enumerate(content[start_pos:], start_pos):
        if char == "{":
            brace_count += 1
            in_struct = True
        elif char == "}":
            brace_count -= 1
            if in_struct and brace_count == 0:
                end_pos = i + 1
                break

    return content[start_pos:end_pos], end_pos


def extract_fields(struct_body: str, verbose: bool = False) -> list[FieldInfo]:
    """Extract fields from struct body."""
    fields = []

    # Skip methods and constructors - look for simple member declarations
    for match in FIELD_PATTERN.finditer(struct_body):
        type_str = match.group(1).strip()
        name = match.group(2).strip()
        default = match.group(3) or match.group(4)

        # Skip if looks like a method
        if "(" in type_str or name.startswith("operator"):
            continue

        is_complex = is_complex_type(type_str)

        fields.append(
            FieldInfo(
                name=name,
                type=type_str,
                default=default.strip() if default else None,
                is_complex=is_complex,
            )
        )

    return fields


def parse_header(file_path: Path, verbose: bool = False) -> list[ComponentInfo]:
    """Parse a header file for component definitions."""
    components = []

    try:
        content = file_path.read_text(encoding="utf-8", errors="replace")
    except Exception as e:
        log(f"  WARNING: Could not read {file_path}: {e}", verbose)
        return components

    category = categorize_file(file_path)

    for match in STRUCT_PATTERN.finditer(content):
        name = match.group(1)
        start_pos = match.start()

        # Get line number
        line_number = content[:start_pos].count("\n") + 1

        # Extract struct body
        struct_body, _ = extract_struct_block(content, match.end() - 1)

        # Extract fields
        fields = extract_fields(struct_body, verbose)

        # Check if tag component (empty or very few fields)
        is_tag = len(fields) == 0

        # Calculate extraction confidence
        complex_count = sum(1 for f in fields if f.is_complex)
        confidence = 1.0 - (complex_count * 0.1)
        confidence = max(0.5, confidence)

        notes = []
        if complex_count > 0:
            notes.append(f"{complex_count} complex types need manual review")

        component = ComponentInfo(
            name=name,
            category=category,
            file_path=str(file_path),
            line_number=line_number,
            fields=fields,
            is_tag=is_tag,
            extraction_confidence=confidence,
            notes=notes,
        )
        components.append(component)

        if verbose:
            field_info = "TAG" if is_tag else f"{len(fields)} fields"
            log(f"  Found component: {name} ({field_info})")
            for f in fields:
                complex_marker = " [COMPLEX]" if f.is_complex else ""
                log(f"    Field: {f.name}: {f.type}{complex_marker}")

    return components


def find_header_files(src_dir: Path) -> Generator[Path, None, None]:
    """Find all header files in source directory."""
    yield from src_dir.rglob("*.hpp")
    yield from src_dir.rglob("*.h")


def component_to_dict(comp: ComponentInfo) -> dict:
    """Convert ComponentInfo to serializable dict."""
    return {
        "name": comp.name,
        "category": comp.category,
        "file_path": comp.file_path,
        "line_number": comp.line_number,
        "is_tag": comp.is_tag,
        "extraction_confidence": comp.extraction_confidence,
        "notes": comp.notes,
        "fields": [
            {
                "name": f.name,
                "type": f.type,
                "default": f.default,
                "is_complex": f.is_complex,
            }
            for f in comp.fields
        ],
    }


def generate_lua_matrix(components: list[ComponentInfo]) -> str:
    """Generate Lua accessibility matrix skeleton."""
    lines = [
        "# Lua Accessibility Matrix",
        "",
        "Component accessibility from Lua. Status: skeleton - needs manual verification.",
        "",
        "| Component | Category | Lua Access | Via | Notes |",
        "|-----------|----------|------------|-----|-------|",
    ]

    for comp in sorted(components, key=lambda c: (c.category, c.name)):
        # Unknown access - needs manual verification
        lines.append(f"| {comp.name} | {comp.category} | ❓ Unknown | TBD | Needs verification |")

    lines.extend(
        [
            "",
            "## Legend",
            "- ✅ Full access - all fields readable/writable from Lua",
            "- 📖 Read-only - accessible but not modifiable",
            "- ⚠️ Partial - some fields accessible",
            "- ❌ No access - not exposed to Lua",
            "- ❓ Unknown - needs verification",
            "",
            f"_Generated: needs manual completion. {len(components)} components listed._",
        ]
    )

    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract ECS components from C++ headers")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    parser.add_argument("--dry-run", action="store_true", help="Don't write files")
    parser.add_argument(
        "--src-dir",
        type=Path,
        default=Path("src"),
        help="Source directory (default: src)",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("planning/inventory"),
        help="Output directory (default: planning/inventory)",
    )
    args = parser.parse_args()

    verbose = args.verbose

    log("=== ECS Component Extraction ===", True)

    # Find and parse headers
    all_components: list[ComponentInfo] = []
    header_count = 0

    for header in find_header_files(args.src_dir):
        header_count += 1
        log(f"Parsing {header}...", verbose)
        components = parse_header(header, verbose)
        all_components.extend(components)

    log(f"Parsed {header_count} headers, found {len(all_components)} components", True)

    # Group by category
    by_category: dict[str, list[ComponentInfo]] = {}
    for comp in all_components:
        by_category.setdefault(comp.category, []).append(comp)

    # Summary
    for category, comps in sorted(by_category.items()):
        total_fields = sum(len(c.fields) for c in comps)
        complex_count = sum(1 for c in comps for f in c.fields if f.is_complex)
        log(f"=== Category Summary: {category} ===", True)
        log(f"  Components: {len(comps)}", True)
        log(f"  Total fields: {total_fields}", True)
        log(f"  Complex types (need review): {complex_count}", True)

    if args.dry_run:
        log("Dry run - not writing files", True)
        return 0

    # Write JSON files per category
    args.output_dir.mkdir(parents=True, exist_ok=True)

    for category, comps in by_category.items():
        output_file = args.output_dir / f"components.{category}.json"
        log(f"Writing {output_file}", True)
        data = {
            "category": category,
            "count": len(comps),
            "components": [component_to_dict(c) for c in comps],
        }
        output_file.write_text(json.dumps(data, indent=2))

    # Write matrix skeleton
    matrix_dir = Path("planning/components")
    matrix_dir.mkdir(parents=True, exist_ok=True)
    matrix_file = matrix_dir / "lua_accessibility_matrix.md"
    log(f"Generating {matrix_file}...", True)
    log(f"  Components with unknown Lua access: {len(all_components)}", True)
    matrix_file.write_text(generate_lua_matrix(all_components))

    log("Extraction complete!", True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
