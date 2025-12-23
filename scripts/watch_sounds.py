#!/usr/bin/env python3
"""
Sound file watcher for TheGameJamTemplate.

Watches assets/sounds/ for new audio files and automatically adds them to sounds.json
with placeholder names. Sends a non-intrusive notification prompting the user to rename.

Usage:
    python3 scripts/watch_sounds.py [--once]

Options:
    --once    Run a single scan without watching (useful for testing/CI)
"""

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Set

# Configuration
SOUNDS_DIR = Path("assets/sounds")
SOUNDS_JSON = SOUNDS_DIR / "sounds.json"
AUDIO_EXTENSIONS = {".wav", ".ogg", ".mp3", ".flac"}


def load_sounds_json() -> dict:
    """Load and parse sounds.json."""
    with open(SOUNDS_JSON, "r", encoding="utf-8") as f:
        return json.load(f)


def save_sounds_json(data: dict) -> None:
    """Save sounds.json with consistent formatting."""
    with open(SOUNDS_JSON, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4, ensure_ascii=False)
        f.write("\n")


def get_registered_filenames(data: dict) -> Set[str]:
    """Get all filenames currently registered in sounds.json."""
    filenames = set()

    # Check music section
    if "music" in data:
        for filename in data["music"].values():
            filenames.add(filename)

    # Check categories (effects, ui, etc.)
    if "categories" in data:
        for category in data["categories"].values():
            if "sounds" in category:
                for filename in category["sounds"].values():
                    filenames.add(filename)

    return filenames


def get_existing_sound_keys(data: dict) -> Set[str]:
    """Get all sound keys currently in sounds.json (to avoid key collisions)."""
    keys = set()

    if "music" in data:
        keys.update(data["music"].keys())

    if "categories" in data:
        for category in data["categories"].values():
            if "sounds" in category:
                keys.update(category["sounds"].keys())

    return keys


def generate_unique_key(base: str, existing_keys: Set[str]) -> str:
    """Generate a unique key that doesn't conflict with existing ones."""
    # Clean the base name: remove extension, convert to snake_case
    base = Path(base).stem
    base = re.sub(r'[^a-zA-Z0-9]+', '_', base)
    base = base.strip('_').lower()

    # Try the clean base name first
    if base and base not in existing_keys:
        return base

    # Fall back to numbered placeholder
    counter = 1
    while True:
        key = f"new_sound_{counter:03d}"
        if key not in existing_keys:
            return key
        counter += 1


def get_audio_files_on_disk() -> Set[str]:
    """Get all audio files currently in the sounds directory."""
    files = set()
    for item in SOUNDS_DIR.iterdir():
        if item.is_file() and item.suffix.lower() in AUDIO_EXTENSIONS:
            files.add(item.name)
    return files


def notify_user(title: str, message: str) -> None:
    """Send a macOS notification using terminal-notifier."""
    try:
        subprocess.run(
            ["terminal-notifier", "-title", title, "-message", message],
            check=False,
            capture_output=True
        )
    except FileNotFoundError:
        # terminal-notifier not installed, just print
        print(f"[Notification] {title}: {message}")


def add_new_sounds(new_files: Set[str]) -> int:
    """Add new sound files to sounds.json and return count of files added."""
    if not new_files:
        return 0

    data = load_sounds_json()
    existing_keys = get_existing_sound_keys(data)

    # Ensure effects category exists
    if "categories" not in data:
        data["categories"] = {}
    if "effects" not in data["categories"]:
        data["categories"]["effects"] = {"sounds": {}, "volume": 0.3}
    if "sounds" not in data["categories"]["effects"]:
        data["categories"]["effects"]["sounds"] = {}

    effects = data["categories"]["effects"]["sounds"]
    added_count = 0
    added_names = []

    for filename in sorted(new_files):
        key = generate_unique_key(filename, existing_keys)
        effects[key] = filename
        existing_keys.add(key)
        added_count += 1
        added_names.append(f"{key} -> {filename}")
        print(f"  Added: {key} -> {filename}")

    save_sounds_json(data)

    # Send notification
    if added_count == 1:
        notify_user("New Sound Added", f"'{added_names[0]}' - Edit sounds.json to rename")
    else:
        notify_user("New Sounds Added", f"{added_count} sounds added to sounds.json - edit to rename")

    return added_count


def scan_for_new_sounds() -> Set[str]:
    """Scan for sound files not yet registered in sounds.json."""
    data = load_sounds_json()
    registered = get_registered_filenames(data)
    on_disk = get_audio_files_on_disk()

    # Find files on disk but not in JSON
    new_files = on_disk - registered

    return new_files


def run_once() -> None:
    """Run a single scan and add any new sounds."""
    print(f"=== Scanning {SOUNDS_DIR} for new sounds ===")

    new_files = scan_for_new_sounds()

    if new_files:
        print(f"Found {len(new_files)} new sound(s):")
        added = add_new_sounds(new_files)
        print(f"=== Added {added} sound(s) to sounds.json ===")
    else:
        print("No new sounds found.")


def watch_loop() -> None:
    """Main watch loop using fswatch."""
    print(f"=== Watching {SOUNDS_DIR} for new sounds ===")
    print("  Press Ctrl+C to stop")
    print()

    # Initial scan
    new_files = scan_for_new_sounds()
    if new_files:
        print(f"Found {len(new_files)} new sound(s) on startup:")
        add_new_sounds(new_files)
        print()

    # Start fswatch process
    try:
        process = subprocess.Popen(
            [
                "fswatch",
                "-l", "2.0",  # 2 second debounce
                "-e", r"\.json$",  # Exclude JSON files (our own edits)
                "-e", r"\.DS_Store$",  # Exclude macOS metadata
                str(SOUNDS_DIR)
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        while True:
            # Read a line from fswatch (blocks until change detected)
            line = process.stdout.readline()
            if not line:
                break

            changed_path = line.strip()
            if not changed_path:
                continue

            # Check if it's an audio file
            path = Path(changed_path)
            if path.suffix.lower() not in AUDIO_EXTENSIONS:
                continue

            print(f"\n=== Change detected: {path.name} ===")
            time.sleep(0.5)  # Small delay to ensure file is fully written

            new_files = scan_for_new_sounds()
            if new_files:
                add_new_sounds(new_files)

    except FileNotFoundError:
        print("ERROR: fswatch not installed")
        print("  Install with: brew install fswatch")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n=== Stopping sound watcher ===")
        process.terminate()


def main():
    # Change to project root if running from scripts/
    if Path.cwd().name == "scripts":
        os.chdir("..")

    if not SOUNDS_JSON.exists():
        print(f"ERROR: {SOUNDS_JSON} not found")
        print("  Run from project root directory")
        sys.exit(1)

    if "--once" in sys.argv:
        run_once()
    else:
        watch_loop()


if __name__ == "__main__":
    main()
