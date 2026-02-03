#!/usr/bin/env python3
"""Check visual baseline size for governance.

Default thresholds:
- Warn at 50 MB
- Fail at 200 MB
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

BYTES_IN_MB = 1024 * 1024


def bytes_to_mb(value: int) -> float:
    return value / BYTES_IN_MB


def dir_size(path: Path) -> int:
    total = 0
    for root, _, files in os.walk(path):
        for name in files:
            file_path = Path(root) / name
            try:
                total += file_path.stat().st_size
            except OSError:
                continue
    return total


def main() -> int:
    parser = argparse.ArgumentParser(description="Check visual baseline size.")
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

    args = parser.parse_args()
    root = args.root
    if not root.exists():
        print(f"[BASELINE_SIZE] {root} does not exist; nothing to check.")
        return 0

    total_bytes = dir_size(root)
    total_mb = bytes_to_mb(total_bytes)
    print(f"[BASELINE_SIZE] {root}: {total_mb:.2f} MB")

    if total_mb >= args.fail_mb:
        print(f"[BASELINE_SIZE] FAIL: exceeds {args.fail_mb:.2f} MB")
        return 1
    if total_mb >= args.warn_mb:
        print(f"[BASELINE_SIZE] WARN: exceeds {args.warn_mb:.2f} MB")
        return 0

    print("[BASELINE_SIZE] OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
