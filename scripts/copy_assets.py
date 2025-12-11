#!/usr/bin/env python3
"""
Copy assets directory with exclusions and optional Lua comment stripping.
Used by both CMake and justfile to ensure parity.

Usage:
    python3 scripts/copy_assets.py <src_dir> <dst_dir> [--strip-lua]

Exclusions (matching CMakeLists.txt lines 978-985):
    - .DS_Store files
    - graphics/pre-packing-files_globbed
    - scripts_archived/ directories
    - chugget_code_definitions.lua
    - siralim_data/ directories
    - docs/ directories
"""

import argparse
import shutil
import sys
from pathlib import Path

# Import strip_comments from sibling script
SCRIPT_DIR = Path(__file__).parent
sys.path.insert(0, str(SCRIPT_DIR))
from strip_lua_comments import strip_comments


# Exclusion patterns matching CMakeLists.txt lines 978-985
EXCLUDE_PATTERNS = [
    ".DS_Store",
    "graphics/pre-packing-files_globbed",
    "scripts_archived",
    "chugget_code_definitions.lua",
    "siralim_data",
    "docs",
]


def should_exclude(rel_path: Path) -> bool:
    """Check if a relative path should be excluded."""
    rel_str = str(rel_path)
    parts = rel_path.parts

    for pattern in EXCLUDE_PATTERNS:
        # Exact filename match (e.g., .DS_Store, chugget_code_definitions.lua)
        if rel_path.name == pattern:
            return True
        # Directory component match (e.g., scripts_archived, siralim_data, docs)
        if pattern in parts:
            return True
        # Path contains pattern (e.g., graphics/pre-packing-files_globbed)
        if pattern in rel_str:
            return True

    return False


def copy_assets(src_dir: Path, dst_dir: Path, strip_lua: bool, verbose: bool) -> int:
    """
    Copy assets from src_dir to dst_dir with exclusions.

    Returns the number of files copied.
    """
    if not src_dir.is_dir():
        print(f"ERROR: Source directory does not exist: {src_dir}", file=sys.stderr)
        return -1

    # Clean destination directory first (matches CMake behavior)
    if dst_dir.exists():
        shutil.rmtree(dst_dir)

    copied = 0
    skipped = 0

    for src_file in src_dir.rglob("*"):
        if not src_file.is_file():
            continue

        rel_path = src_file.relative_to(src_dir)

        if should_exclude(rel_path):
            skipped += 1
            if verbose:
                print(f"  SKIP: {rel_path}")
            continue

        dst_file = dst_dir / rel_path
        dst_file.parent.mkdir(parents=True, exist_ok=True)

        # Strip Lua comments if requested
        if strip_lua and src_file.suffix == ".lua":
            data = src_file.read_text(encoding="utf-8")
            stripped = strip_comments(data)
            dst_file.write_text(stripped, encoding="utf-8")
            if verbose:
                print(f"  STRIP: {rel_path}")
        else:
            shutil.copy2(src_file, dst_file)
            if verbose:
                print(f"  COPY: {rel_path}")

        copied += 1

    return copied, skipped


def main():
    parser = argparse.ArgumentParser(
        description="Copy assets with exclusions and optional Lua stripping"
    )
    parser.add_argument("src_dir", type=Path, help="Source assets directory")
    parser.add_argument("dst_dir", type=Path, help="Destination directory")
    parser.add_argument(
        "--strip-lua",
        action="store_true",
        help="Strip comments from .lua files (for release builds)",
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Print each file as it's processed",
    )

    args = parser.parse_args()

    print(f"Copying assets: {args.src_dir} -> {args.dst_dir}")
    if args.strip_lua:
        print("  Lua comment stripping: ENABLED")

    result = copy_assets(args.src_dir, args.dst_dir, args.strip_lua, args.verbose)

    if isinstance(result, tuple):
        copied, skipped = result
        print(f"Done: {copied} files copied, {skipped} files skipped")
        return 0
    else:
        return 1


if __name__ == "__main__":
    sys.exit(main())
