#!/usr/bin/env python3
"""
Animation auto-export system for TheGameJamTemplate.

Exports animated sprites from Aseprite files in assets/animations/ to individual
frame PNGs and updates animations.json with timing and direction metadata.

Usage:
    python3 scripts/export_animations.py [options]

Options:
    --once          Run a single export without watching
    --verbose       Print detailed export information
    --dry-run       Show what would be exported without making changes
    --clean         Clean orphaned animation frames (frames without source .aseprite)

See docs/specs/animation-auto-export.md for full documentation.
"""

import argparse
import glob
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

ANIMATIONS_SOURCE_DIR = Path("assets/animations")
EXPORT_DIR = Path("assets/graphics/auto-exported-sprites-from-aseprite")
ANIMATIONS_JSON = Path("assets/graphics/animations.json")

DIRECTION_MAP = {
    "forward": "forward",
    "reverse": "reverse",
    "pingpong": "pingpong",
    "pingpong_reverse": "pingpong_reverse",
}


def find_aseprite_executable() -> Optional[str]:
    locations = [
        os.path.expanduser("~/Applications/Aseprite.app/Contents/MacOS/aseprite"),
        os.path.expanduser(
            "~/Library/Application Support/Steam/steamapps/common/Aseprite/Aseprite.app/Contents/MacOS/aseprite"
        ),
        "/Applications/Aseprite.app/Contents/MacOS/aseprite",
        os.path.expanduser("~/Desktop/Aseprite.app/Contents/MacOS/aseprite"),
    ]

    for loc in locations:
        if os.path.isfile(loc) and os.access(loc, os.X_OK):
            return loc

    try:
        result = subprocess.run(["which", "aseprite"], capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout.strip()
    except Exception:
        pass

    return None


def get_aseprite_files() -> List[Path]:
    if not ANIMATIONS_SOURCE_DIR.exists():
        return []
    return sorted(ANIMATIONS_SOURCE_DIR.glob("*.aseprite"))


def export_aseprite_metadata(
    aseprite_exe: str, source_file: Path, verbose: bool = False
) -> Optional[dict]:
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as tmp:
        tmp_json = tmp.name

    try:
        cmd = [
            aseprite_exe,
            "-b",
            str(source_file),
            "--data",
            tmp_json,
            "--format",
            "json-array",
            "--list-tags",
        ]

        if verbose:
            print(f"  Running: {' '.join(cmd)}")

        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0:
            print(f"ERROR: Aseprite metadata export failed for {source_file}")
            if result.stderr:
                print(f"  stderr: {result.stderr}")
            return None

        with open(tmp_json, "r", encoding="utf-8") as f:
            return json.load(f)

    finally:
        if os.path.exists(tmp_json):
            os.unlink(tmp_json)


def clean_existing_frames(
    base_name: str, verbose: bool = False, dry_run: bool = False
) -> int:
    pattern = EXPORT_DIR / f"{base_name}_*_*.png"
    matching_files = glob.glob(str(pattern))

    if verbose and matching_files:
        print(
            f"  Cleaning {len(matching_files)} existing frame(s) matching {base_name}_*_*.png"
        )

    if not dry_run:
        for f in matching_files:
            try:
                os.unlink(f)
            except FileNotFoundError:
                pass  # File already deleted (race condition or stale glob)

    return len(matching_files)


def build_frame_data_for_tag(
    base_name: str, tag_name: str, tag_from: int, tag_to: int, frames_meta: list
) -> List[dict]:
    frame_data = []
    for frame_idx in range(tag_from, tag_to + 1):
        frame_filename = f"{base_name}_{tag_name}_{frame_idx - tag_from:04d}.png"
        frame_meta = (
            frames_meta[frame_idx] if frame_idx < len(frames_meta) else frames_meta[0]
        )
        duration_ms = frame_meta.get("duration", 100)
        duration_s = duration_ms / 1000.0

        frame_data.append(
            {
                "sprite_UUID": frame_filename,
                "duration_seconds": duration_s,
                "fg_color": "WHITE",
                "bg_color": "NONE",
            }
        )
    return frame_data


def build_frame_data_no_tag(base_name: str, frames_meta: list) -> List[dict]:
    frame_data = []
    for frame_idx, frame_meta in enumerate(frames_meta):
        frame_filename = f"{base_name}_no-tag_{frame_idx:04d}.png"
        duration_ms = frame_meta.get("duration", 100)
        duration_s = duration_ms / 1000.0

        frame_data.append(
            {
                "sprite_UUID": frame_filename,
                "duration_seconds": duration_s,
                "fg_color": "WHITE",
                "bg_color": "NONE",
            }
        )
    return frame_data


def export_tagged_frames(
    aseprite_exe: str, source_file: Path, base_name: str, tags_meta: list, verbose: bool
) -> None:
    for tag in tags_meta:
        tag_name = tag["name"]
        tag_from = tag["from"]
        tag_to = tag["to"]

        output_pattern = str(EXPORT_DIR / f"{base_name}_{tag_name}_{{frame0000}}.png")

        cmd = [
            aseprite_exe,
            "-b",
            str(source_file),
            "--frame-range",
            f"{tag_from},{tag_to}",
            "--save-as",
            output_pattern,
        ]

        if verbose:
            print(f"    Running: {' '.join(cmd)}")

        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0:
            print(f"ERROR: Frame export failed for tag '{tag_name}' in {source_file}")
            if result.stderr:
                print(f"  stderr: {result.stderr}")


def export_untagged_frames(
    aseprite_exe: str, source_file: Path, base_name: str, verbose: bool
) -> None:
    output_pattern = str(EXPORT_DIR / f"{base_name}_no-tag_{{frame0000}}.png")

    cmd = [
        aseprite_exe,
        "-b",
        str(source_file),
        "--save-as",
        output_pattern,
    ]

    if verbose:
        print(f"    Running: {' '.join(cmd)}")

    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        print(f"ERROR: Frame export failed for {source_file}")
        if result.stderr:
            print(f"  stderr: {result.stderr}")


def export_animation_frames(
    aseprite_exe: str,
    source_file: Path,
    metadata: dict,
    verbose: bool = False,
    dry_run: bool = False,
) -> List[Tuple[str, dict]]:
    base_name = source_file.stem
    animations = []

    frames_meta = metadata.get("frames", [])
    if not frames_meta:
        print(f"WARNING: No frames found in {source_file}")
        return []

    tags_meta = metadata.get("meta", {}).get("frameTags", [])

    if tags_meta:
        for tag in tags_meta:
            tag_name = tag["name"]
            tag_from = tag["from"]
            tag_to = tag["to"]
            tag_direction = tag.get("direction", "forward")
            direction = DIRECTION_MAP.get(tag_direction, "forward")
            animation_name = f"{base_name}_{tag_name}"

            if verbose:
                print(
                    f"  Exporting tag '{tag_name}' (frames {tag_from}-{tag_to}, {direction})"
                )

            frame_data = build_frame_data_for_tag(
                base_name, tag_name, tag_from, tag_to, frames_meta
            )
            animations.append(
                (
                    animation_name,
                    {
                        "frames": frame_data,
                        "aseDirection": direction,
                    },
                )
            )
    else:
        animation_name = f"{base_name}_no-tag"

        if verbose:
            print(f"  No tags found, exporting as '{animation_name}'")

        frame_data = build_frame_data_no_tag(base_name, frames_meta)
        animations.append(
            (
                animation_name,
                {
                    "frames": frame_data,
                    "aseDirection": "forward",
                },
            )
        )

    if not dry_run:
        EXPORT_DIR.mkdir(parents=True, exist_ok=True)

        if tags_meta:
            export_tagged_frames(
                aseprite_exe, source_file, base_name, tags_meta, verbose
            )
        else:
            export_untagged_frames(aseprite_exe, source_file, base_name, verbose)

    return animations


def load_animations_json() -> dict:
    if not ANIMATIONS_JSON.exists():
        return {}

    try:
        with open(ANIMATIONS_JSON, "r", encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        print(f"WARNING: Could not parse {ANIMATIONS_JSON}: {e}")
        return {}


def save_animations_json(data: dict) -> None:
    tmp_path = ANIMATIONS_JSON.with_suffix(".json.tmp")
    try:
        with open(tmp_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write("\n")
            f.flush()
            os.fsync(f.fileno())
        tmp_path.rename(ANIMATIONS_JSON)
    except Exception:
        if tmp_path.exists():
            tmp_path.unlink()
        raise


def get_auto_exported_base_names(aseprite_files: List[Path]) -> Set[str]:
    return {f.stem for f in aseprite_files}


def is_auto_exported_animation(anim_name: str, auto_bases: Set[str]) -> bool:
    for base in auto_bases:
        if anim_name.startswith(f"{base}_"):
            return True
    return False


def update_animations_json(
    new_animations: List[Tuple[str, dict]],
    auto_bases: Set[str],
    verbose: bool = False,
    dry_run: bool = False,
) -> Tuple[int, int]:
    existing = load_animations_json()

    added = 0
    updated = 0

    keys_to_remove = [
        key for key in existing if is_auto_exported_animation(key, auto_bases)
    ]

    new_keys = {name for name, _ in new_animations}

    for key in keys_to_remove:
        if key not in new_keys:
            if verbose:
                print(f"  Removing stale animation: {key}")
            if not dry_run:
                del existing[key]

    for name, data in new_animations:
        if name in existing:
            updated += 1
            if verbose:
                print(f"  Updating animation: {name}")
        else:
            added += 1
            if verbose:
                print(f"  Adding animation: {name}")

        if not dry_run:
            existing[name] = data

    if not dry_run:
        save_animations_json(existing)

    return added, updated


def export_all_animations(
    aseprite_exe: str, verbose: bool = False, dry_run: bool = False
) -> Tuple[int, int, int]:
    aseprite_files = get_aseprite_files()

    if not aseprite_files:
        print("No .aseprite files found in assets/animations/")
        return 0, 0, 0

    print(f"Found {len(aseprite_files)} Aseprite file(s)")

    all_animations = []
    auto_bases = set()

    for source_file in aseprite_files:
        base_name = source_file.stem
        auto_bases.add(base_name)

        print(f"\nProcessing: {source_file.name}")

        metadata = export_aseprite_metadata(aseprite_exe, source_file, verbose)
        if metadata is None:
            continue

        clean_existing_frames(base_name, verbose, dry_run)

        animations = export_animation_frames(
            aseprite_exe, source_file, metadata, verbose, dry_run
        )
        all_animations.extend(animations)

    print(f"\nUpdating {ANIMATIONS_JSON}")
    added, updated = update_animations_json(
        all_animations, auto_bases, verbose, dry_run
    )

    return len(aseprite_files), added, updated


def clean_orphaned_frames(verbose: bool = False, dry_run: bool = False) -> int:
    aseprite_files = get_aseprite_files()
    valid_bases = {f.stem for f in aseprite_files}

    all_frames = list(EXPORT_DIR.glob("*_*_*.png"))

    orphaned = []
    for frame in all_frames:
        name = frame.stem
        is_orphan = not any(name.startswith(f"{base}_") for base in valid_bases)
        if is_orphan:
            orphaned.append(frame)

    if orphaned:
        print(f"Found {len(orphaned)} orphaned frame(s)")
        for frame in orphaned:
            if verbose:
                print(f"  Deleting: {frame.name}")
            if not dry_run:
                frame.unlink()

    return len(orphaned)


def main():
    parser = argparse.ArgumentParser(
        description="Export animations from Aseprite files to PNG frames and animations.json"
    )
    parser.add_argument(
        "--verbose", "-v", action="store_true", help="Print detailed output"
    )
    parser.add_argument(
        "--dry-run",
        "-n",
        action="store_true",
        help="Show what would be done without making changes",
    )
    parser.add_argument(
        "--clean", action="store_true", help="Clean orphaned animation frames"
    )
    parser.add_argument(
        "--once",
        action="store_true",
        help="Run once (default behavior, for compatibility)",
    )

    args = parser.parse_args()

    if Path.cwd().name == "scripts":
        os.chdir("..")

    aseprite_exe = find_aseprite_executable()
    if not aseprite_exe:
        print("ERROR: Aseprite not found")
        print("  Checked: ~/Applications, Steam, /Applications, ~/Desktop, PATH")
        sys.exit(1)

    print(f"Using Aseprite: {aseprite_exe}")

    if args.dry_run:
        print("DRY RUN - no changes will be made\n")

    if not args.dry_run:
        EXPORT_DIR.mkdir(parents=True, exist_ok=True)

    if not ANIMATIONS_SOURCE_DIR.exists():
        if not args.dry_run:
            ANIMATIONS_SOURCE_DIR.mkdir(parents=True, exist_ok=True)
        print(f"Created {ANIMATIONS_SOURCE_DIR}")

    if args.clean:
        deleted = clean_orphaned_frames(args.verbose, args.dry_run)
        print(f"\n=== Cleaned {deleted} orphaned frame(s) ===")
        return

    files, added, updated = export_all_animations(
        aseprite_exe, args.verbose, args.dry_run
    )

    print(f"\n=== Export complete ===")
    print(f"  Files processed: {files}")
    print(f"  Animations added: {added}")
    print(f"  Animations updated: {updated}")


if __name__ == "__main__":
    main()
