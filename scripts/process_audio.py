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
from typing import Dict, Optional, Tuple

# Configuration
SOUNDS_DIR = Path("assets/sounds")
SOUNDS_JSON = SOUNDS_DIR / "sounds.json"
BOOST_CONFIG = SOUNDS_DIR / "audio_boost.json"
MARKER_FILE = SOUNDS_DIR / ".audio_processed.json"

DEFAULT_TARGET_RMS_DB = -18
OGG_QUALITY = 6  # 0-10, higher = better quality


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
    # IMPORTANT: -vn strips embedded album art (video streams) that break stb_vorbis
    # IMPORTANT: -ar 44100 resamples to standard rate (96kHz breaks stb_vorbis)
    cmd = [
        "ffmpeg", "-y",  # Overwrite output
        "-i", str(input_path),
        "-vn",           # Strip video streams (album art) - stb_vorbis can't handle them
        "-ar", "44100",  # Resample to 44.1kHz - stb_vorbis struggles with 96kHz
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
        """Update all filename references in sounds.json (handles duplicates)."""
        categories = self.sounds_data.get("categories", {})
        for cat_data in categories.values():
            sounds = cat_data.get("sounds", {})
            for key, filename in list(sounds.items()):
                if filename == old_filename:
                    sounds[key] = new_filename

    def save_sounds_json(self) -> None:
        """Save the updated sounds.json."""
        if not self.dry_run:
            save_json(SOUNDS_JSON, self.sounds_data)

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
