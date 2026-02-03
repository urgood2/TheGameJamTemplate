# Pixquare iPad Sync Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Automatically sync .aseprite files from iPad (Pixquare via iCloud) into the existing sprite/animation pipeline.

**Architecture:** Python watcher monitors two iCloud folders. Animations are copied directly to `assets/animations/`. Static sprites are merged into `auto_export_assets.aseprite` via an Aseprite Lua script that imports layers with prefixed names.

**Tech Stack:** Python 3, fswatch, Aseprite CLI + Lua scripting, terminal-notifier

**Design Doc:** `docs/plans/2026-02-03-pixquare-ipad-sync-design.md`

---

## Task 1: Create Aseprite Layer Merge Script

**Files:**
- Create: `scripts/aseprite_merge_layers.lua`

**Step 1: Write the Lua script**

This script is called via `aseprite -b --script-param source=X --script-param target=Y --script scripts/aseprite_merge_layers.lua`

```lua
-- aseprite_merge_layers.lua
-- Merges layers from a source .aseprite file into a target .aseprite file
-- with prefixed layer names to avoid collisions.
--
-- Usage:
--   aseprite -b \
--     --script-param source=/path/to/source.aseprite \
--     --script-param target=/path/to/target.aseprite \
--     --script scripts/aseprite_merge_layers.lua
--
-- Exit codes (written to stdout as JSON):
--   {"status": "success", "layers_added": N}
--   {"status": "skipped", "reason": "layers_exist", "prefix": "..."}
--   {"status": "error", "reason": "..."}

local source_path = app.params["source"]
local target_path = app.params["target"]

-- Validate params
if not source_path or source_path == "" then
    print('{"status": "error", "reason": "missing source param"}')
    return
end

if not target_path or target_path == "" then
    print('{"status": "error", "reason": "missing target param"}')
    return
end

-- Extract prefix from source filename (without extension)
local prefix = source_path:match("([^/]+)%.aseprite$")
if not prefix then
    print('{"status": "error", "reason": "invalid source filename"}')
    return
end

-- Open source sprite
local source_sprite = Sprite{ fromFile = source_path }
if not source_sprite then
    print('{"status": "error", "reason": "failed to open source file"}')
    return
end

-- Open target sprite
local target_sprite = Sprite{ fromFile = target_path }
if not target_sprite then
    source_sprite:close()
    print('{"status": "error", "reason": "failed to open target file"}')
    return
end

-- Check if layers with this prefix already exist in target
for _, layer in ipairs(target_sprite.layers) do
    if layer.name:find("^" .. prefix .. "_") then
        source_sprite:close()
        target_sprite:close()
        print('{"status": "skipped", "reason": "layers_exist", "prefix": "' .. prefix .. '"}')
        return
    end
end

-- Expand target canvas if source is larger
local new_width = math.max(target_sprite.width, source_sprite.width)
local new_height = math.max(target_sprite.height, source_sprite.height)
if new_width > target_sprite.width or new_height > target_sprite.height then
    target_sprite:resize(new_width, new_height)
end

-- Ensure target has at least as many frames as source
while #target_sprite.frames < #source_sprite.frames do
    target_sprite:newEmptyFrame()
end

-- Copy layers from source to target
local layers_added = 0
for _, src_layer in ipairs(source_sprite.layers) do
    if src_layer.isImage then
        -- Create new layer in target with prefixed name
        local new_layer = target_sprite:newLayer()
        new_layer.name = prefix .. "_" .. src_layer.name

        -- Copy cels from source layer to new layer
        for _, src_cel in ipairs(src_layer.cels) do
            local frame_num = src_cel.frameNumber
            -- Ensure frame exists
            while #target_sprite.frames < frame_num do
                target_sprite:newEmptyFrame()
            end
            -- Create cel with copied image
            target_sprite:newCel(new_layer, frame_num, src_cel.image, src_cel.position)
        end

        layers_added = layers_added + 1
    end
end

-- Save target sprite
target_sprite:saveAs(target_path)

-- Clean up
source_sprite:close()
target_sprite:close()

print('{"status": "success", "layers_added": ' .. layers_added .. '}')
```

**Step 2: Test the script manually**

Create a test source file and run:
```bash
# From project root
aseprite -b \
  --script-param source=/tmp/test_sprite.aseprite \
  --script-param target=assets/auto_export_assets.aseprite \
  --script scripts/aseprite_merge_layers.lua
```

Expected: JSON output like `{"status": "success", "layers_added": 1}`

**Step 3: Commit**

```bash
git add scripts/aseprite_merge_layers.lua
git commit -m "feat: add Aseprite layer merge script for Pixquare import"
```

---

## Task 2: Create Python Watcher Script - Core Structure

**Files:**
- Create: `scripts/watch_pixquare.py`

**Step 1: Write the script skeleton with configuration and helpers**

```python
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
```

**Step 2: Test the script runs and validates environment**

```bash
python3 scripts/watch_pixquare.py --once
```

Expected: Either "ERROR: iCloud folders not found" or finds Aseprite and prints paths.

**Step 3: Commit**

```bash
git add scripts/watch_pixquare.py
git commit -m "feat: add Pixquare watcher script skeleton"
```

---

## Task 3: Implement Animation Processing

**Files:**
- Modify: `scripts/watch_pixquare.py` (replace `process_animation` placeholder)

**Step 1: Implement process_animation function**

Replace the placeholder with:

```python
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
```

**Step 2: Test manually**

Create a test file and run:
```bash
# Create test animation in iCloud folder
touch ~/Library/Mobile\ Documents/com~apple~CloudDocs/pixquare-animations/test_anim.aseprite

# Test (will fail since it's not a real aseprite file, but logic runs)
python3 -c "
from scripts.watch_pixquare import *
import os
os.chdir('/Users/joshuashin/Projects/TheGameJamTemplate@pixquare-sync')
source = ANIMATIONS_ICLOUD / 'test_anim.aseprite'
if source.exists():
    process_animation(source, 'aseprite', True, False)
"
```

**Step 3: Commit**

```bash
git add scripts/watch_pixquare.py
git commit -m "feat: implement animation processing in Pixquare watcher"
```

---

## Task 4: Implement Sprite Processing

**Files:**
- Modify: `scripts/watch_pixquare.py` (replace `process_sprite` placeholder)

**Step 1: Implement process_sprite function**

Replace the placeholder with:

```python
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
```

**Step 2: Test manually (requires real aseprite files)**

```bash
python3 -c "
from scripts.watch_pixquare import *
print('Sprite processing implemented')
"
```

**Step 3: Commit**

```bash
git add scripts/watch_pixquare.py
git commit -m "feat: implement sprite merge processing in Pixquare watcher"
```

---

## Task 5: Implement Single Sync Mode

**Files:**
- Modify: `scripts/watch_pixquare.py` (implement `--once` mode in main)

**Step 1: Add sync_once function and wire up main**

Add this function before `main()`:

```python
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
```

Update the `--once` branch in `main()`:

```python
    if args.once:
        print("\n=== Running single sync ===")
        anims, sprites = sync_once(aseprite_exe, args.verbose, not args.no_move)
        print(f"\n=== Sync complete: {anims} animation(s), {sprites} sprite(s) ===")
    else:
        # Watch loop - implemented in Task 6
        print("watch mode not yet implemented")
```

**Step 2: Test single sync**

```bash
python3 scripts/watch_pixquare.py --once --verbose --no-move
```

Expected: Shows files found (or "0 animation(s), 0 sprite(s)" if folders empty)

**Step 3: Commit**

```bash
git add scripts/watch_pixquare.py
git commit -m "feat: implement single sync mode for Pixquare watcher"
```

---

## Task 6: Implement Watch Loop

**Files:**
- Modify: `scripts/watch_pixquare.py` (implement watch mode in main)

**Step 1: Add watch_loop function**

Add this function before `main()`:

```python
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
```

Update the else branch in `main()`:

```python
    else:
        watch_loop(aseprite_exe, args.verbose, not args.no_move)
```

**Step 2: Test watch mode briefly**

```bash
# Start watcher (Ctrl+C to stop)
python3 scripts/watch_pixquare.py --verbose --no-move
```

Expected: Shows "Watching for Pixquare exports" and waits

**Step 3: Commit**

```bash
git add scripts/watch_pixquare.py
git commit -m "feat: implement watch loop for Pixquare watcher"
```

---

## Task 7: Add Justfile Recipes

**Files:**
- Modify: `Justfile` (add recipes near other watch recipes)

**Step 1: Find insertion point**

Look for `watch-sounds` recipe and add after it.

**Step 2: Add recipes**

```just
# Watch for Pixquare exports from iCloud (animations + sprites)
watch-pixquare:
	python3 scripts/watch_pixquare.py --verbose

# One-time sync of Pixquare exports from iCloud
sync-pixquare-once:
	python3 scripts/watch_pixquare.py --once --verbose

# Sync without moving files to processed/ folder
sync-pixquare-dry:
	python3 scripts/watch_pixquare.py --once --verbose --no-move
```

**Step 3: Test recipes**

```bash
just sync-pixquare-dry
```

**Step 4: Commit**

```bash
git add Justfile
git commit -m "feat: add Justfile recipes for Pixquare sync"
```

---

## Task 8: Update Documentation

**Files:**
- Modify: `CLAUDE.md` (add Pixquare workflow section)

**Step 1: Add section after Build Commands**

Add under "## Build Commands" or create new section:

```markdown
## Pixquare iPad Workflow

Sync pixel art from iPad (Pixquare app) via iCloud:

```bash
just watch-pixquare    # Watch mode (continuous)
just sync-pixquare-once # One-time sync
```

**iCloud folder setup (one-time):**
```bash
mkdir -p ~/Library/Mobile\ Documents/com~apple~CloudDocs/pixquare-animations
mkdir -p ~/Library/Mobile\ Documents/com~apple~CloudDocs/pixquare-sprites
```

**Workflow:**
- Animations: Export .aseprite to `pixquare-animations/` → auto-copied to `assets/animations/`
- Static sprites: Export .aseprite to `pixquare-sprites/` → layers merged into `auto_export_assets.aseprite`

Processed files are moved to `processed/` subfolder. To update an existing sprite, delete its `{name}_*` layers from `auto_export_assets.aseprite` first.

See `docs/plans/2026-02-03-pixquare-ipad-sync-design.md` for full design.
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add Pixquare iPad workflow to CLAUDE.md"
```

---

## Task 9: Create iCloud Folders and End-to-End Test

**Step 1: Create iCloud folders**

```bash
mkdir -p ~/Library/Mobile\ Documents/com~apple~CloudDocs/pixquare-animations
mkdir -p ~/Library/Mobile\ Documents/com~apple~CloudDocs/pixquare-sprites
mkdir -p ~/Library/Mobile\ Documents/com~apple~CloudDocs/pixquare-animations/processed
mkdir -p ~/Library/Mobile\ Documents/com~apple~CloudDocs/pixquare-sprites/processed
```

**Step 2: Test with real files**

1. Copy a test .aseprite animation file to `pixquare-animations/`
2. Run `just sync-pixquare-once`
3. Verify file appears in `assets/animations/`
4. Verify original moved to `processed/`

5. Copy a test .aseprite sprite file to `pixquare-sprites/`
6. Run `just sync-pixquare-once`
7. Verify layers merged into `auto_export_assets.aseprite`
8. Verify original moved to `processed/`

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat: complete Pixquare iPad sync pipeline"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Aseprite layer merge Lua script | `scripts/aseprite_merge_layers.lua` |
| 2 | Python watcher skeleton | `scripts/watch_pixquare.py` |
| 3 | Animation processing | `scripts/watch_pixquare.py` |
| 4 | Sprite merge processing | `scripts/watch_pixquare.py` |
| 5 | Single sync mode | `scripts/watch_pixquare.py` |
| 6 | Watch loop | `scripts/watch_pixquare.py` |
| 7 | Justfile recipes | `Justfile` |
| 8 | Documentation | `CLAUDE.md` |
| 9 | iCloud setup + E2E test | (manual) |
