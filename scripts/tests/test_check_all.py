"""Unit tests for scripts/check_all.sh orchestration.

Validates:
- Dry-run mode executes all steps in order
- Fail-step triggers non-zero exit and summary
- Log prefixes are stable for parsing
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

CHECK_ALL = Path(__file__).parent.parent / "check_all.sh"

STEP_NAMES = [
    "Validating toolchain",
    "Regenerating inventories",
    "Regenerating scope stats",
    "Regenerating doc skeletons",
    "Validating schemas",
    "Syncing registry from manifest",
    "Checking docs consistency",
    "Checking evidence blocks",
    "Running test suite",
]


def run_check_all(args: list[str]) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    return subprocess.run(
        ["bash", str(CHECK_ALL), *args],
        cwd=CHECK_ALL.parent.parent,
        env=env,
        text=True,
        capture_output=True,
    )


def test_dry_run_success() -> None:
    """Dry-run succeeds and logs all steps in order."""
    result = run_check_all(["--dry-run"])
    assert result.returncode == 0

    output = result.stdout
    positions: list[int] = []
    for idx, name in enumerate(STEP_NAMES, start=1):
        marker = f"[CHECK] [{idx}/9] {name}..."
        assert marker in output
        positions.append(output.index(marker))

    assert positions == sorted(positions)

    for line in output.splitlines():
        if line.strip():
            assert line.startswith("[CHECK]")


def test_fail_step_propagates() -> None:
    """Fail-step forces non-zero exit and reports the failed step."""
    result = run_check_all(["--dry-run", "--fail-step", "3"])
    assert result.returncode != 0

    output = result.stdout
    assert "FINAL RESULT: FAIL" in output
    assert "[CHECK]   - [3/9] Regenerating scope stats" in output
