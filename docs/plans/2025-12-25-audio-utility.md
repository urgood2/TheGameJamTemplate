# Audio Processing Utility Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a one-click utility to normalize SFX volume (RMS), convert WAV to OGG, update sounds.json references, with optional per-file boost and smart re-processing detection.

**Architecture:** Python script using ffmpeg for audio processing. Marker file tracks processed files by hash to enable incremental re-runs. Config file allows per-file volume boosts.

**Tech Stack:** Python 3, ffmpeg (CLI), JSON config files

---

## Task 1: Install ffmpeg Dependency

**Files:**
- None (system installation)

**Step 1: Check if ffmpeg is installed**

Run: `which ffmpeg`

**Step 2: Install ffmpeg if missing**

Run: `brew install ffmpeg`

**Step 3: Verify installation**

Run: `ffmpeg -version | head -1`
Expected: `ffmpeg version X.X.X ...`

---

## Task 2: Create Audio Boost Config File

**Files:**
- Create: `assets/sounds/audio_boost.json`

**Step 1: Create the config file**

```json
{
    "_comment": "Per-file volume boost in dB (applied before normalization). Target RMS in dBFS.",
    "boost_db": {},
    "target_rms_db": -18
}
```

**Step 2: Verify file was created**

Run: `cat assets/sounds/audio_boost.json`

---

## Task 3: Add Marker File to .gitignore

**Files:**
- Modify: `.gitignore`

**Step 1: Add the marker file pattern**

Add to `.gitignore`:
```
# Audio processing marker file
assets/sounds/.audio_processed.json
```

**Step 2: Verify the change**

Run: `grep -n "audio_processed" .gitignore`
Expected: Line showing the pattern was added

---

## Task 4: Create Core Audio Processing Script - File Structure

**Files:**
- Create: `scripts/process_audio.py`

**Step 1: Create the script with imports and constants**

```python
#!/usr/bin/env python3
"""
Audio processing utility for TheGameJamTemplate.

Normalizes SFX to target RMS, converts WAV to OGG, updates sounds.json.
Tracks processed files to avoid redundant work.

Usage:
    python3 scripts/process_audio.py [--dry-run] [--force]

Options:
    --dry-run    Preview changes without modifying files
    --force      Reprocess all files, ignoring marker cache
"""

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional, Set, Tuple

# Configuration
SOUNDS_DIR = Path("assets/sounds")
SOUNDS_JSON = SOUNDS_DIR / "sounds.json"
BOOST_CONFIG = SOUNDS_DIR / "audio_boost.json"
MARKER_FILE = SOUNDS_DIR / ".audio_processed.json"

DEFAULT_TARGET_RMS_DB = -18
OGG_QUALITY = 6  # 0-10, higher = better quality


def main():
    parser = argparse.ArgumentParser(description="Process audio files for game")
    parser.add_argument("--dry-run", action="store_true", help="Preview changes only")
    parser.add_argument("--force", action="store_true", help="Reprocess all files")
    args = parser.parse_args()

    # Change to project root if running from scripts/
    if Path.cwd().name == "scripts":
        os.chdir("..")

    if not SOUNDS_JSON.exists():
        print(f"ERROR: {SOUNDS_JSON} not found")
        print("  Run from project root directory")
        sys.exit(1)

    processor = AudioProcessor(dry_run=args.dry_run, force=args.force)
    processor.run()


if __name__ == "__main__":
    main()
```

**Step 2: Verify syntax**

Run: `python3 -m py_compile scripts/process_audio.py`
Expected: No output (success)

---

## Task 5: Implement Helper Functions

**Files:**
- Modify: `scripts/process_audio.py`

**Step 1: Add file hash function after imports**

Add after the constants:

```python
def file_hash(path: Path) -> str:
    """Compute MD5 hash of file contents."""
    hasher = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def load_json(path: Path) -> dict:
    """Load JSON file, return empty dict if missing."""
    if not path.exists():
        return {}
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def save_json(path: Path, data: dict) -> None:
    """Save JSON with consistent formatting."""
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4, ensure_ascii=False)
        f.write("\n")


def check_ffmpeg() -> bool:
    """Verify ffmpeg is installed."""
    try:
        result = subprocess.run(
            ["ffmpeg", "-version"],
            capture_output=True,
            text=True,
            check=False
        )
        return result.returncode == 0
    except FileNotFoundError:
        return False
```

**Step 2: Verify syntax**

Run: `python3 -m py_compile scripts/process_audio.py`
Expected: No output (success)

---

## Task 6: Implement RMS Measurement

**Files:**
- Modify: `scripts/process_audio.py`

**Step 1: Add RMS measurement function after helper functions**

```python
def get_rms_db(audio_path: Path) -> Optional[float]:
    """
    Get RMS level of audio file in dBFS using ffmpeg.
    Returns None if measurement fails.
    """
    result = subprocess.run(
        [
            "ffmpeg", "-i", str(audio_path),
            "-af", "volumedetect",
            "-f", "null", "-"
        ],
        capture_output=True,
        text=True,
        check=False
    )

    # Parse RMS from stderr (ffmpeg outputs stats there)
    output = result.stderr
    match = re.search(r"mean_volume:\s*(-?\d+\.?\d*)\s*dB", output)
    if match:
        return float(match.group(1))
    return None
```

**Step 2: Verify syntax**

Run: `python3 -m py_compile scripts/process_audio.py`
Expected: No output (success)

---

## Task 7: Implement Audio Processing Function

**Files:**
- Modify: `scripts/process_audio.py`

**Step 1: Add the normalize and convert function**

```python
def process_audio_file(
    input_path: Path,
    output_path: Path,
    target_rms_db: float,
    boost_db: float = 0.0,
    dry_run: bool = False
) -> bool:
    """
    Normalize audio to target RMS and convert to OGG.

    Args:
        input_path: Source WAV file
        output_path: Destination OGG file
        target_rms_db: Target RMS level in dBFS
        boost_db: Additional volume boost in dB (applied first)
        dry_run: If True, only print what would happen

    Returns:
        True if successful, False otherwise
    """
    # Measure current RMS
    current_rms = get_rms_db(input_path)
    if current_rms is None:
        print(f"    ERROR: Could not measure RMS for {input_path.name}")
        return False

    # Calculate adjustment: target - current + boost
    adjustment_db = target_rms_db - current_rms + boost_db

    print(f"    Current RMS: {current_rms:.1f} dB")
    print(f"    Target RMS:  {target_rms_db:.1f} dB")
    if boost_db != 0:
        print(f"    Boost:       {boost_db:+.1f} dB")
    print(f"    Adjustment:  {adjustment_db:+.1f} dB")

    if dry_run:
        print(f"    [DRY RUN] Would create: {output_path.name}")
        return True

    # Build ffmpeg command
    # Uses volume filter for adjustment, then converts to OGG
    cmd = [
        "ffmpeg", "-y",  # Overwrite output
        "-i", str(input_path),
        "-af", f"volume={adjustment_db}dB",
        "-c:a", "libvorbis",
        "-q:a", str(OGG_QUALITY),
        str(output_path)
    ]

    result = subprocess.run(cmd, capture_output=True, text=True, check=False)

    if result.returncode != 0:
        print(f"    ERROR: ffmpeg failed")
        print(f"    {result.stderr[:200]}")
        return False

    print(f"    Created: {output_path.name}")
    return True
```

**Step 2: Verify syntax**

Run: `python3 -m py_compile scripts/process_audio.py`
Expected: No output (success)

---

## Task 8: Implement AudioProcessor Class - Init and Config Loading

**Files:**
- Modify: `scripts/process_audio.py`

**Step 1: Add AudioProcessor class before main()**

```python
class AudioProcessor:
    """Main audio processing orchestrator."""

    def __init__(self, dry_run: bool = False, force: bool = False):
        self.dry_run = dry_run
        self.force = force
        self.sounds_data = load_json(SOUNDS_JSON)
        self.marker_data = load_json(MARKER_FILE) if not force else {}
        self.boost_config = self._load_boost_config()
        self.processed_count = 0
        self.skipped_count = 0
        self.error_count = 0

    def _load_boost_config(self) -> dict:
        """Load boost config, creating default if missing."""
        if not BOOST_CONFIG.exists():
            default = {
                "_comment": "Per-file volume boost in dB (applied before normalization). Target RMS in dBFS.",
                "boost_db": {},
                "target_rms_db": DEFAULT_TARGET_RMS_DB
            }
            if not self.dry_run:
                save_json(BOOST_CONFIG, default)
                print(f"Created default config: {BOOST_CONFIG}")
            return default
        return load_json(BOOST_CONFIG)

    @property
    def target_rms(self) -> float:
        return self.boost_config.get("target_rms_db", DEFAULT_TARGET_RMS_DB)

    def get_boost(self, filename: str) -> float:
        """Get boost in dB for a specific file."""
        return self.boost_config.get("boost_db", {}).get(filename, 0.0)
```

**Step 2: Verify syntax**

Run: `python3 -m py_compile scripts/process_audio.py`
Expected: No output (success)

---

## Task 9: Implement Marker File Management

**Files:**
- Modify: `scripts/process_audio.py`

**Step 1: Add marker methods to AudioProcessor class**

Add these methods to the AudioProcessor class:

```python
    def is_already_processed(self, wav_path: Path) -> bool:
        """Check if file was already processed (hash matches)."""
        if "processed" not in self.marker_data:
            return False

        ogg_name = wav_path.stem + ".ogg"
        entry = self.marker_data["processed"].get(ogg_name)
        if not entry:
            return False

        # Check if source file hash matches
        current_hash = file_hash(wav_path)
        return entry.get("source_hash") == current_hash

    def mark_processed(self, wav_path: Path, ogg_path: Path) -> None:
        """Record that a file has been processed."""
        if "processed" not in self.marker_data:
            self.marker_data["processed"] = {}

        self.marker_data["processed"][ogg_path.name] = {
            "source": wav_path.name,
            "source_hash": file_hash(wav_path),
            "processed_at": datetime.now().isoformat()
        }

    def save_marker(self) -> None:
        """Save the marker file."""
        if not self.dry_run:
            save_json(MARKER_FILE, self.marker_data)
```

**Step 2: Verify syntax**

Run: `python3 -m py_compile scripts/process_audio.py`
Expected: No output (success)

---

## Task 10: Implement sounds.json Update Logic

**Files:**
- Modify: `scripts/process_audio.py`

**Step 1: Add sounds.json update method to AudioProcessor**

```python
    def get_wav_references(self) -> Dict[str, Tuple[str, str]]:
        """
        Get all .wav file references from sounds.json categories (not music).

        Returns:
            Dict mapping filename to (category_name, key_name)
        """
        references = {}

        categories = self.sounds_data.get("categories", {})
        for cat_name, cat_data in categories.items():
            sounds = cat_data.get("sounds", {})
            for key, filename in sounds.items():
                if filename.lower().endswith(".wav"):
                    references[filename] = (cat_name, key)

        return references

    def update_sounds_json(self, old_filename: str, new_filename: str) -> None:
        """Update a filename reference in sounds.json."""
        categories = self.sounds_data.get("categories", {})
        for cat_data in categories.values():
            sounds = cat_data.get("sounds", {})
            for key, filename in sounds.items():
                if filename == old_filename:
                    sounds[key] = new_filename
                    return

    def save_sounds_json(self) -> None:
        """Save the updated sounds.json."""
        if not self.dry_run:
            save_json(SOUNDS_JSON, self.sounds_data)
```

**Step 2: Verify syntax**

Run: `python3 -m py_compile scripts/process_audio.py`
Expected: No output (success)

---

## Task 11: Implement Main Processing Loop

**Files:**
- Modify: `scripts/process_audio.py`

**Step 1: Add the run() method to AudioProcessor**

```python
    def run(self) -> None:
        """Execute the audio processing pipeline."""
        print("=" * 60)
        print("Audio Processing Utility")
        print("=" * 60)

        if self.dry_run:
            print("MODE: Dry run (no files will be modified)")
        if self.force:
            print("MODE: Force reprocess all files")
        print()

        # Check ffmpeg
        if not check_ffmpeg():
            print("ERROR: ffmpeg not found")
            print("  Install with: brew install ffmpeg")
            sys.exit(1)

        print(f"Target RMS: {self.target_rms} dBFS")
        print()

        # Get all .wav references from sounds.json
        wav_refs = self.get_wav_references()

        if not wav_refs:
            print("No .wav files found in sounds.json categories.")
            return

        print(f"Found {len(wav_refs)} .wav file(s) in sounds.json categories")
        print()

        # Process each file
        for filename, (category, key) in sorted(wav_refs.items()):
            wav_path = SOUNDS_DIR / filename
            ogg_path = SOUNDS_DIR / (Path(filename).stem + ".ogg")

            print(f"Processing: {filename}")
            print(f"  Category: {category}, Key: {key}")

            # Check if file exists
            if not wav_path.exists():
                print(f"  WARNING: File not found, skipping")
                self.skipped_count += 1
                continue

            # Check if already processed
            if not self.force and self.is_already_processed(wav_path):
                print(f"  Already processed (hash match), skipping")
                self.skipped_count += 1
                continue

            # Get boost for this file
            boost = self.get_boost(filename)

            # Process the file
            success = process_audio_file(
                wav_path, ogg_path,
                target_rms_db=self.target_rms,
                boost_db=boost,
                dry_run=self.dry_run
            )

            if success:
                # Update sounds.json reference
                self.update_sounds_json(filename, ogg_path.name)

                # Mark as processed
                if not self.dry_run:
                    self.mark_processed(wav_path, ogg_path)

                # Delete original .wav
                if not self.dry_run:
                    wav_path.unlink()
                    print(f"    Deleted: {filename}")
                else:
                    print(f"    [DRY RUN] Would delete: {filename}")

                self.processed_count += 1
            else:
                self.error_count += 1

            print()

        # Save updated files
        if not self.dry_run:
            self.save_sounds_json()
            self.save_marker()

        # Print summary
        print("=" * 60)
        print("Summary")
        print("=" * 60)
        print(f"  Processed: {self.processed_count}")
        print(f"  Skipped:   {self.skipped_count}")
        print(f"  Errors:    {self.error_count}")

        if self.dry_run:
            print()
            print("This was a dry run. No files were modified.")
            print("Run without --dry-run to apply changes.")
```

**Step 2: Verify syntax**

Run: `python3 -m py_compile scripts/process_audio.py`
Expected: No output (success)

---

## Task 12: Add Just Recipe

**Files:**
- Modify: `Justfile`

**Step 1: Add audio processing recipes to Justfile**

Find the `# Sound File Automation` section and add after `scan-sounds`:

```just
# Process audio files (normalize, convert to ogg, update sounds.json)
audio-process *args:
	python3 scripts/process_audio.py {{args}}

# Preview audio processing changes without modifying files
audio-process-dry:
	python3 scripts/process_audio.py --dry-run

# Force reprocess all audio files
audio-process-force:
	python3 scripts/process_audio.py --force
```

**Step 2: Verify recipes are registered**

Run: `just --list | grep audio`
Expected: Shows audio-process, audio-process-dry, audio-process-force

---

## Task 13: Make Script Executable

**Files:**
- Modify: `scripts/process_audio.py` (permissions)

**Step 1: Set executable permission**

Run: `chmod +x scripts/process_audio.py`

**Step 2: Verify**

Run: `ls -la scripts/process_audio.py`
Expected: Shows `-rwxr-xr-x` (executable)

---

## Task 14: Test Dry Run

**Files:**
- None (testing)

**Step 1: Run dry-run mode**

Run: `just audio-process --dry-run`

Expected output should show:
- Found N .wav files in sounds.json categories
- For each file: Current RMS, Target RMS, Adjustment
- [DRY RUN] messages for what would happen
- Summary with counts

**Step 2: Verify no files were modified**

Run: `git status assets/sounds/`
Expected: No changes (clean)

---

## Task 15: Test Full Processing (on a test file)

**Files:**
- None (testing)

**Step 1: Create a backup first**

Run: `cp assets/sounds/sounds.json assets/sounds/sounds.json.backup`

**Step 2: Run on a single file**

Modify sounds.json temporarily to have only one test .wav in categories, then:
Run: `just audio-process`

**Step 3: Verify results**
- Check that .ogg file was created
- Check that sounds.json was updated with .ogg reference
- Check that .audio_processed.json was created
- Check that original .wav was deleted

**Step 4: Restore backup if needed**

Run: `mv assets/sounds/sounds.json.backup assets/sounds/sounds.json`

---

## Task 16: Test Re-run Detection

**Files:**
- None (testing)

**Step 1: Run processing again**

Run: `just audio-process`

Expected: Files should be skipped with "Already processed (hash match)"

**Step 2: Test force flag**

Run: `just audio-process --force`

Expected: All files reprocessed regardless of marker

---

## Task 17: Test Boost Config

**Files:**
- Modify: `assets/sounds/audio_boost.json`

**Step 1: Add a test boost entry**

```json
{
    "_comment": "Per-file volume boost in dB (applied before normalization). Target RMS in dBFS.",
    "boost_db": {
        "some_quiet_sound.wav": 6
    },
    "target_rms_db": -18
}
```

**Step 2: Run dry-run to verify boost is applied**

Run: `just audio-process --dry-run`

Expected: Output shows "Boost: +6.0 dB" for that file

---

## Task 18: Commit Implementation

**Files:**
- `scripts/process_audio.py`
- `assets/sounds/audio_boost.json`
- `.gitignore`
- `Justfile`

**Step 1: Stage files**

```bash
git add scripts/process_audio.py assets/sounds/audio_boost.json .gitignore Justfile
```

**Step 2: Commit**

```bash
git commit -m "feat(audio): add audio processing utility

- Normalize SFX to target RMS level (-18 dBFS default)
- Convert WAV to OGG (Vorbis quality 6)
- Update sounds.json references automatically
- Track processed files via marker file to avoid redundant work
- Support per-file volume boosts via config
- Add just recipes: audio-process, audio-process-dry, audio-process-force"
```

---

## Summary

After completing all tasks:

1. **Install ffmpeg**: `brew install ffmpeg`
2. **Preview changes**: `just audio-process --dry-run`
3. **Process all files**: `just audio-process`
4. **Force reprocess**: `just audio-process --force`
5. **Boost specific files**: Edit `assets/sounds/audio_boost.json`

The utility will:
- Skip music files (only processes `categories` section)
- Skip already-processed files (detected by hash)
- Delete original .wav files after successful conversion
- Update sounds.json with new .ogg filenames

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
