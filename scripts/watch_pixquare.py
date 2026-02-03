#!/usr/bin/env python3
"""
Pixquare iCloud sync watcher for TheGameJamTemplate.

Watches iCloud folders for .aseprite files exported from Pixquare on iPad:
- pixquare-animations/ → copied to assets/animations/
- pixquare-sprites/ → layers merged into auto_export_assets.aseprite

Usage:
    python3 scripts/watch_pixquare.py [options]

Options:
    --once              Run a single sync without watching
    --verbose           Print detailed output
    --no-move           Don't move processed files to processed/ subfolder
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional, Tuple

# Configuration
ICLOUD_BASE = Path.home() / "Library/Mobile Documents/com~apple~CloudDocs"
ANIMATIONS_ICLOUD = ICLOUD_BASE / "pixquare-animations"
SPRITES_ICLOUD = ICLOUD_BASE / "pixquare-sprites"

ANIMATIONS_TARGET = Path("assets/animations")
SPRITES_TARGET = Path("assets/auto_export_assets.aseprite")
MERGE_SCRIPT = Path("scripts/aseprite_merge_layers.lua")


def find_aseprite_executable() -> Optional[str]:
    """Find Aseprite executable, same logic as export_animations.py."""
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


def notify(title: str, message: str, sound: bool = False) -> None:
    """Send macOS notification via terminal-notifier."""
    try:
        cmd = ["terminal-notifier", "-title", title, "-message", message]
        if sound:
            cmd.extend(["-sound", "default"])
        subprocess.run(cmd, check=False, capture_output=True)
    except FileNotFoundError:
        print(f"[Notification] {title}: {message}")


def is_file_stable(path: Path, wait_seconds: float = 1.0) -> bool:
    """Check if file size is stable (not still syncing from iCloud)."""
    try:
        size1 = path.stat().st_size
        time.sleep(wait_seconds)
        size2 = path.stat().st_size
        return size1 == size2 and size1 > 0
    except OSError:
        return False


def move_to_processed(source: Path, move: bool = True) -> None:
    """Move processed file to processed/ subfolder."""
    if not move:
        return
    processed_dir = source.parent / "processed"
    processed_dir.mkdir(exist_ok=True)
    dest = processed_dir / source.name
    # Handle existing file with same name
    if dest.exists():
        dest.unlink()
    shutil.move(str(source), str(dest))


def get_aseprite_files(directory: Path) -> list[Path]:
    """Get all .aseprite files in directory (not in processed/)."""
    if not directory.exists():
        return []
    return [
        f for f in directory.glob("*.aseprite")
        if f.is_file() and "processed" not in f.parts
    ]


# Placeholder for processing functions (next tasks)
def process_animation(source: Path, aseprite_exe: str, verbose: bool, move: bool) -> bool:
    """Process an animation file - copy to assets/animations/."""
    raise NotImplementedError("Task 3")


def process_sprite(source: Path, aseprite_exe: str, verbose: bool, move: bool) -> bool:
    """Process a sprite file - merge into auto_export_assets.aseprite."""
    raise NotImplementedError("Task 4")


def main():
    parser = argparse.ArgumentParser(description="Sync Pixquare exports from iCloud")
    parser.add_argument("--once", action="store_true", help="Single sync without watching")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    parser.add_argument("--no-move", action="store_true", help="Don't move processed files")
    args = parser.parse_args()

    # Change to project root if in scripts/
    if Path.cwd().name == "scripts":
        os.chdir("..")

    # Validate environment
    aseprite_exe = find_aseprite_executable()
    if not aseprite_exe:
        print("ERROR: Aseprite not found")
        sys.exit(1)

    if not ANIMATIONS_ICLOUD.exists() or not SPRITES_ICLOUD.exists():
        print("ERROR: iCloud folders not found. Please create:")
        print(f"  {ANIMATIONS_ICLOUD}")
        print(f"  {SPRITES_ICLOUD}")
        sys.exit(1)

    print(f"Using Aseprite: {aseprite_exe}")
    print(f"Watching: {ANIMATIONS_ICLOUD}")
    print(f"Watching: {SPRITES_ICLOUD}")

    if args.once:
        # Single sync - implemented in Task 5
        print("--once mode not yet implemented")
    else:
        # Watch loop - implemented in Task 6
        print("watch mode not yet implemented")


if __name__ == "__main__":
    main()
