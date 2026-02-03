#!/usr/bin/env python3
"""Check visual baseline size for PR governance.

Calculates the size delta of visual baselines compared to a base ref
and enforces thresholds to prevent repository bloat.

Default thresholds:
- WARN at 50MB PR delta
- FAIL at 200MB PR delta

Exit codes:
- 0: PASS (delta within limits)
- 1: WARN (delta exceeds warn threshold)
- 2: FAIL (delta exceeds fail threshold)

Logging prefix: [BASELINE-SIZE]
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

# Exit codes
EXIT_PASS = 0
EXIT_WARN = 1
EXIT_FAIL = 2

# Constants
BYTES_IN_MB = 1024 * 1024


@dataclass
class FileChange:
    """Represents a file change in the baseline directory."""
    path: str
    status: str  # 'A' (added), 'M' (modified), 'D' (deleted)
    size_bytes: int
    old_size_bytes: int | None = None


@dataclass
class SizeCheckResult:
    """Result of the baseline size check."""
    status: str  # 'PASS', 'WARN', 'FAIL'
    exit_code: int
    current_size_bytes: int
    delta_bytes: int
    warn_threshold_bytes: int
    fail_threshold_bytes: int
    files_added: list
    files_modified: list
    files_deleted: list


def bytes_to_mb(value: int) -> float:
    """Convert bytes to megabytes."""
    return value / BYTES_IN_MB


def log(message: str, verbose: bool = True) -> None:
    """Log a message with the BASELINE-SIZE prefix."""
    if verbose:
        print(f"[BASELINE-SIZE] {message}")


def get_git_root() -> Path | None:
    """Get the root directory of the git repository."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True,
        )
        return Path(result.stdout.strip())
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def get_file_size(path: Path) -> int:
    """Get file size in bytes, handling Git LFS pointer files."""
    if not path.exists():
        return 0

    # Check if this is a Git LFS pointer file
    try:
        with open(path, "rb") as f:
            header = f.read(100)
            if b"version https://git-lfs.github.com" in header:
                # Parse LFS pointer to get actual size
                content = header + f.read()
                for line in content.decode("utf-8", errors="ignore").splitlines():
                    if line.startswith("size "):
                        return int(line.split()[1])
    except (OSError, ValueError):
        pass

    # Regular file size
    return path.stat().st_size


def get_dir_size(path: Path) -> int:
    """Calculate total size of a directory."""
    total = 0
    if not path.exists():
        return 0

    for root, _, files in os.walk(path):
        for name in files:
            file_path = Path(root) / name
            try:
                total += get_file_size(file_path)
            except OSError:
                continue

    return total


def get_changed_baselines(
    baselines_dir: Path,
    base_ref: str,
    verbose: bool = False,
) -> list[FileChange]:
    """Get list of changed baseline files compared to base ref."""
    changes = []
    baselines_str = str(baselines_dir)

    try:
        # Get list of changed files
        result = subprocess.run(
            ["git", "diff", "--name-status", base_ref, "--", baselines_str],
            capture_output=True,
            text=True,
            check=True,
        )
    except subprocess.CalledProcessError as e:
        log(f"Git diff failed: {e.stderr}", verbose)
        return changes

    for line in result.stdout.strip().splitlines():
        if not line:
            continue

        parts = line.split("\t", 1)
        if len(parts) != 2:
            continue

        status, path = parts
        status = status[0]  # Handle rename status (R100, etc.)
        file_path = Path(path)

        # Get current file size
        current_size = 0
        if status != "D":
            current_size = get_file_size(file_path)

        # Get old file size (for modified files)
        old_size = None
        if status == "M":
            try:
                result = subprocess.run(
                    ["git", "show", f"{base_ref}:{path}"],
                    capture_output=True,
                    check=True,
                )
                old_size = len(result.stdout)
            except subprocess.CalledProcessError:
                old_size = 0

        changes.append(FileChange(
            path=str(file_path),
            status=status,
            size_bytes=current_size,
            old_size_bytes=old_size,
        ))

        if verbose:
            status_name = {"A": "added", "M": "modified", "D": "deleted"}.get(status, status)
            log(f"  {status_name}: {path} ({bytes_to_mb(current_size):.2f}MB)", verbose)

    return changes


def calculate_delta(changes: list[FileChange]) -> int:
    """Calculate the net size delta from file changes."""
    delta = 0
    for change in changes:
        if change.status == "A":
            # Added: full size is new
            delta += change.size_bytes
        elif change.status == "M":
            # Modified: difference between new and old
            old_size = change.old_size_bytes or 0
            delta += change.size_bytes - old_size
        elif change.status == "D":
            # Deleted: negative delta
            delta -= change.size_bytes

    return delta


def calculate_delta_from_diff_listing(diff_listing: str, file_sizes: dict[str, int]) -> int:
    """
    Calculate delta from a git diff listing and file sizes.

    This is useful for testing without actual git operations.

    Args:
        diff_listing: Output from git diff --name-status
        file_sizes: Dict mapping path -> size in bytes

    Returns:
        Net delta in bytes
    """
    delta = 0
    for line in diff_listing.strip().splitlines():
        if not line:
            continue
        parts = line.split("\t", 1)
        if len(parts) != 2:
            continue

        status, path = parts
        status = status[0]
        size = file_sizes.get(path, 0)

        if status == "A":
            delta += size
        elif status == "D":
            delta -= size
        elif status == "M":
            # For modified, we need old and new sizes
            old_size = file_sizes.get(f"old:{path}", 0)
            delta += size - old_size

    return delta


def check_baseline_size(
    baselines_dir: Path,
    base_ref: str = "origin/main",
    warn_threshold_mb: float = 50.0,
    fail_threshold_mb: float = 200.0,
    verbose: bool = False,
) -> SizeCheckResult:
    """
    Check baseline size delta and return result.

    Args:
        baselines_dir: Path to the baselines directory
        base_ref: Git ref to compare against
        warn_threshold_mb: Size delta (MB) to trigger warning
        fail_threshold_mb: Size delta (MB) to trigger failure
        verbose: Enable verbose logging

    Returns:
        SizeCheckResult with status and details
    """
    warn_threshold = int(warn_threshold_mb * BYTES_IN_MB)
    fail_threshold = int(fail_threshold_mb * BYTES_IN_MB)

    log(f"Scanning {baselines_dir}...", verbose)
    log(f"Comparing against: {base_ref}", verbose)
    log(f"Thresholds: warn={warn_threshold_mb}MB, fail={fail_threshold_mb}MB", verbose)

    # Get current total size
    current_size = get_dir_size(baselines_dir)
    log(f"Current size: {bytes_to_mb(current_size):.2f}MB", verbose)

    # Get changed files
    changes = get_changed_baselines(baselines_dir, base_ref, verbose)

    # Calculate delta
    delta = calculate_delta(changes)
    delta_sign = "+" if delta >= 0 else ""
    log(f"PR delta: {delta_sign}{bytes_to_mb(delta):.2f}MB", verbose)

    # Categorize changes
    files_added = [c.path for c in changes if c.status == "A"]
    files_modified = [c.path for c in changes if c.status == "M"]
    files_deleted = [c.path for c in changes if c.status == "D"]

    # Determine status based on absolute delta
    abs_delta = abs(delta)
    if abs_delta >= fail_threshold:
        status = "FAIL"
        exit_code = EXIT_FAIL
        log(f"Status: FAIL (delta {bytes_to_mb(delta):.2f}MB exceeds {fail_threshold_mb}MB threshold)", verbose)
    elif abs_delta >= warn_threshold:
        status = "WARN"
        exit_code = EXIT_WARN
        log(f"Status: WARN (delta {bytes_to_mb(delta):.2f}MB exceeds {warn_threshold_mb}MB threshold)", verbose)
    else:
        status = "PASS"
        exit_code = EXIT_PASS
        log("Status: PASS (delta within limits)", verbose)

    return SizeCheckResult(
        status=status,
        exit_code=exit_code,
        current_size_bytes=current_size,
        delta_bytes=delta,
        warn_threshold_bytes=warn_threshold,
        fail_threshold_bytes=fail_threshold,
        files_added=files_added,
        files_modified=files_modified,
        files_deleted=files_deleted,
    )


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Check visual baseline size delta for PR governance.",
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=Path("test_baselines/screenshots"),
        help="Baseline root directory (default: test_baselines/screenshots)",
    )
    parser.add_argument(
        "--warn-mb",
        type=float,
        default=50.0,
        help="Warn threshold in MB (default: 50)",
    )
    parser.add_argument(
        "--fail-mb",
        type=float,
        default=200.0,
        help="Fail threshold in MB (default: 200)",
    )
    parser.add_argument(
        "--base-ref",
        default="origin/main",
        help="Git ref to compare against (default: origin/main)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output results as JSON",
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable verbose logging",
    )

    args = parser.parse_args()

    # Check we're in a git repo
    git_root = get_git_root()
    if git_root is None:
        log("ERROR: Not in a git repository", True)
        return EXIT_FAIL

    # Resolve baselines directory
    baselines_dir = args.root
    if not baselines_dir.is_absolute():
        baselines_dir = git_root / baselines_dir

    if not baselines_dir.exists():
        log(f"{baselines_dir} does not exist; nothing to check.", True)
        return EXIT_PASS

    # Run check
    result = check_baseline_size(
        baselines_dir=baselines_dir,
        base_ref=args.base_ref,
        warn_threshold_mb=args.warn_mb,
        fail_threshold_mb=args.fail_mb,
        verbose=not args.json and args.verbose,
    )

    # Output results
    if args.json:
        output = {
            "status": result.status,
            "exit_code": result.exit_code,
            "current_size_mb": bytes_to_mb(result.current_size_bytes),
            "delta_mb": bytes_to_mb(result.delta_bytes),
            "warn_threshold_mb": bytes_to_mb(result.warn_threshold_bytes),
            "fail_threshold_mb": bytes_to_mb(result.fail_threshold_bytes),
            "files_added": result.files_added,
            "files_modified": result.files_modified,
            "files_deleted": result.files_deleted,
        }
        print(json.dumps(output, indent=2))
    else:
        # Summary
        print(f"[BASELINE-SIZE] {baselines_dir}: {bytes_to_mb(result.current_size_bytes):.2f}MB")
        delta_sign = "+" if result.delta_bytes >= 0 else ""
        print(f"[BASELINE-SIZE] PR delta: {delta_sign}{bytes_to_mb(result.delta_bytes):.2f}MB")

        if result.files_added:
            print(f"[BASELINE-SIZE] Files added: {len(result.files_added)}")
        if result.files_modified:
            print(f"[BASELINE-SIZE] Files modified: {len(result.files_modified)}")
        if result.files_deleted:
            print(f"[BASELINE-SIZE] Files deleted: {len(result.files_deleted)}")

        if result.exit_code == EXIT_FAIL:
            print(f"[BASELINE-SIZE] FAIL: exceeds {args.fail_mb:.2f}MB")
        elif result.exit_code == EXIT_WARN:
            print(f"[BASELINE-SIZE] WARN: exceeds {args.warn_mb:.2f}MB")
        else:
            print("[BASELINE-SIZE] OK")

    return result.exit_code


if __name__ == "__main__":
    sys.exit(main())
