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


def process_animation(source: Path, aseprite_exe: str, verbose: bool, move: bool) -> bool:
    """Process an animation file - copy to assets/animations/."""
    if verbose:
        print(f"  Processing animation: {source.name}")

    # Wait for file to be fully synced
    if not is_file_stable(source):
        print(f"  Skipping {source.name} - still syncing")
        return False

    dest = ANIMATIONS_TARGET / source.name

    try:
        # Copy file (overwrite if exists)
        shutil.copy2(str(source), str(dest))

        if verbose:
            print(f"  Copied to {dest}")

        # Move to processed
        move_to_processed(source, move)

        notify("Pixquare Sync", f"Animation '{source.stem}' synced")
        return True

    except Exception as e:
        print(f"ERROR processing {source.name}: {e}")
        notify("Pixquare Sync Error", f"Failed: {source.name}")
        return False


def process_sprite(source: Path, aseprite_exe: str, verbose: bool, move: bool) -> bool:
    """Process a sprite file - merge layers into auto_export_assets.aseprite."""
    if verbose:
        print(f"  Processing sprite: {source.name}")

    # Wait for file to be fully synced
    if not is_file_stable(source):
        print(f"  Skipping {source.name} - still syncing")
        return False

    # Run merge script
    try:
        result = subprocess.run(
            [
                aseprite_exe,
                "-b",
                "--script-param", f"source={source}",
                "--script-param", f"target={SPRITES_TARGET}",
                "--script", str(MERGE_SCRIPT),
            ],
            capture_output=True,
            text=True,
            timeout=60,
        )

        # Parse JSON output from script
        output = result.stdout.strip()
        if verbose:
            print(f"  Script output: {output}")

        try:
            response = json.loads(output)
        except json.JSONDecodeError:
            print(f"ERROR: Invalid JSON from merge script: {output}")
            print(f"  stderr: {result.stderr}")
            return False

        status = response.get("status")

        if status == "success":
            layers = response.get("layers_added", 0)
            move_to_processed(source, move)
            notify("Pixquare Sync", f"Sprite '{source.stem}' merged ({layers} layers)")
            return True

        elif status == "skipped":
            reason = response.get("reason", "unknown")
            if reason == "layers_exist":
                prefix = response.get("prefix", source.stem)
                print(f"  Skipped: layers '{prefix}_*' already exist")
                notify("Pixquare Sync", f"Sprite '{source.stem}' exists, skipping")
            else:
                print(f"  Skipped: {reason}")
            return False

        else:
            reason = response.get("reason", "unknown error")
            print(f"ERROR: Merge failed - {reason}")
            notify("Pixquare Sync Error", f"Failed: {source.name}")
            return False

    except subprocess.TimeoutExpired:
        print(f"ERROR: Merge script timed out for {source.name}")
        return False
    except Exception as e:
        print(f"ERROR processing {source.name}: {e}")
        return False


def sync_once(aseprite_exe: str, verbose: bool, move: bool) -> Tuple[int, int]:
    """Run a single sync pass. Returns (animations_processed, sprites_processed)."""
    animations_processed = 0
    sprites_processed = 0

    # Process animations
    animation_files = get_aseprite_files(ANIMATIONS_ICLOUD)
    if animation_files:
        print(f"\nFound {len(animation_files)} animation(s) in {ANIMATIONS_ICLOUD.name}/")
        for f in animation_files:
            if process_animation(f, aseprite_exe, verbose, move):
                animations_processed += 1

    # Process sprites
    sprite_files = get_aseprite_files(SPRITES_ICLOUD)
    if sprite_files:
        print(f"\nFound {len(sprite_files)} sprite(s) in {SPRITES_ICLOUD.name}/")
        for f in sprite_files:
            if process_sprite(f, aseprite_exe, verbose, move):
                sprites_processed += 1

    return animations_processed, sprites_processed


def watch_loop(aseprite_exe: str, verbose: bool, move: bool) -> None:
    """Watch iCloud folders for changes using fswatch."""
    print("\n=== Watching for Pixquare exports ===")
    print("  Press Ctrl+C to stop\n")

    # Initial sync
    anims, sprites = sync_once(aseprite_exe, verbose, move)
    if anims or sprites:
        print(f"  Initial sync: {anims} animation(s), {sprites} sprite(s)\n")

    # Start fswatch on both directories
    try:
        process = subprocess.Popen(
            [
                "fswatch",
                "-l", "2.0",  # 2 second debounce
                "-e", r"\.DS_Store$",
                "-e", r"/processed/",  # Ignore processed folder
                str(ANIMATIONS_ICLOUD),
                str(SPRITES_ICLOUD),
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

        while True:
            line = process.stdout.readline()
            if not line:
                break

            changed_path = Path(line.strip())
            if not changed_path.suffix == ".aseprite":
                continue

            print(f"\n=== Change detected: {changed_path.name} ===")
            time.sleep(0.5)  # Brief delay for file to settle

            # Determine which folder and process accordingly
            if ANIMATIONS_ICLOUD in changed_path.parents or changed_path.parent == ANIMATIONS_ICLOUD:
                if changed_path.exists():
                    process_animation(changed_path, aseprite_exe, verbose, move)
            elif SPRITES_ICLOUD in changed_path.parents or changed_path.parent == SPRITES_ICLOUD:
                if changed_path.exists():
                    process_sprite(changed_path, aseprite_exe, verbose, move)

    except FileNotFoundError:
        print("ERROR: fswatch not installed")
        print("  Install with: brew install fswatch")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n=== Stopping Pixquare watcher ===")
        process.terminate()


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
        print("\n=== Running single sync ===")
        anims, sprites = sync_once(aseprite_exe, args.verbose, not args.no_move)
        print(f"\n=== Sync complete: {anims} animation(s), {sprites} sprite(s) ===")
    else:
        watch_loop(aseprite_exe, args.verbose, not args.no_move)


if __name__ == "__main__":
    main()
