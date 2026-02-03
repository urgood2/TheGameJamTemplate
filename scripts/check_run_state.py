#!/usr/bin/env python3
"""Check run_state.json for crash/hang detection.

This script is used by CI to determine if a test run completed successfully,
crashed, or hung.

Exit codes:
    0 - Tests passed
    1 - Tests failed (but completed)
    2 - Crash detected (run_state missing or incomplete)
    3 - Hang detected (in_progress after timeout)

Usage:
    python scripts/check_run_state.py [--state-file PATH]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


EXIT_PASSED = 0
EXIT_FAILED = 1
EXIT_CRASH = 2
EXIT_HANG = 3


def check_run_state(state_file: Path) -> int:
    """Check the run state file and return appropriate exit code.

    Args:
        state_file: Path to run_state.json

    Returns:
        Exit code (0-3)
    """
    print(f"[CHECK_RUN_STATE] Checking {state_file}...")

    # Check if file exists
    if not state_file.exists():
        print("[CHECK_RUN_STATE] CRASH: run_state.json not found")
        print("[CHECK_RUN_STATE]   This indicates crash before harness started")
        return EXIT_CRASH

    # Read and parse JSON
    try:
        with open(state_file, encoding="utf-8") as f:
            state = json.load(f)
    except json.JSONDecodeError as e:
        print(f"[CHECK_RUN_STATE] CRASH: Invalid JSON in run_state.json: {e}")
        return EXIT_CRASH
    except OSError as e:
        print(f"[CHECK_RUN_STATE] CRASH: Could not read run_state.json: {e}")
        return EXIT_CRASH

    # Check schema version
    schema_version = state.get("schema_version")
    if schema_version != "1.0":
        print(f"[CHECK_RUN_STATE] WARNING: Unknown schema version: {schema_version}")

    # Check if run is in progress (hang detection)
    in_progress = state.get("in_progress", True)
    if in_progress:
        last_started = state.get("last_test_started")
        last_completed = state.get("last_test_completed")

        print("[CHECK_RUN_STATE] HANG: Run still in progress after timeout")

        if last_started and last_started != last_completed:
            print(f"[CHECK_RUN_STATE]   Crashed/hung during test: {last_started}")
        elif last_started == last_completed and last_completed:
            print(f"[CHECK_RUN_STATE]   Last completed test: {last_completed}")
        else:
            print("[CHECK_RUN_STATE]   No tests completed")

        # Print partial counts
        counts = state.get("partial_counts", {})
        print(f"[CHECK_RUN_STATE]   Partial counts: {counts.get('passed', 0)} passed, "
              f"{counts.get('failed', 0)} failed, {counts.get('skipped', 0)} skipped")

        return EXIT_HANG

    # Run completed - check result
    passed = state.get("passed", False)
    completed_at = state.get("completed_at", "unknown")

    counts = state.get("partial_counts", {})
    passed_count = counts.get("passed", 0)
    failed_count = counts.get("failed", 0)
    skipped_count = counts.get("skipped", 0)

    print(f"[CHECK_RUN_STATE] Run completed at {completed_at}")
    print(f"[CHECK_RUN_STATE] Results: {passed_count} passed, {failed_count} failed, "
          f"{skipped_count} skipped")

    if passed:
        print("[CHECK_RUN_STATE] PASSED: All tests passed")
        return EXIT_PASSED
    else:
        print("[CHECK_RUN_STATE] FAILED: Some tests failed")
        return EXIT_FAILED


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Check run_state.json for crash/hang detection."
    )
    parser.add_argument(
        "--state-file",
        type=Path,
        default=Path("test_output/run_state.json"),
        help="Path to run_state.json (default: test_output/run_state.json)",
    )

    args = parser.parse_args()

    return check_run_state(args.state_file)


if __name__ == "__main__":
    sys.exit(main())
