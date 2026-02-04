"""Tests for check_run_state.py.

These tests verify the crash/hang detection logic using fixture JSON files.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

# Add scripts directory to path
SCRIPTS_DIR = Path(__file__).parent.parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from check_run_state import (
    EXIT_CRASH,
    EXIT_FAILED,
    EXIT_HANG,
    EXIT_PASSED,
    check_run_state,
)


class TestCheckRunState:
    """Tests for check_run_state function."""

    def test_missing_file_returns_crash(self, tmp_path: Path) -> None:
        """Missing run_state.json indicates crash before harness started."""
        missing = tmp_path / "nonexistent.json"
        result = check_run_state(missing)
        assert result == EXIT_CRASH

    def test_invalid_json_returns_crash(self, tmp_path: Path) -> None:
        """Invalid JSON indicates crash/corruption."""
        state_file = tmp_path / "run_state.json"
        state_file.write_text("{ invalid json }")
        result = check_run_state(state_file)
        assert result == EXIT_CRASH

    def test_in_progress_returns_hang(self, tmp_path: Path) -> None:
        """in_progress: true after timeout indicates hang."""
        state_file = tmp_path / "run_state.json"
        state = {
            "schema_version": "1.0",
            "in_progress": True,
            "run_id": "123_456",
            "started_at": "2024-01-01T00:00:00Z",
            "last_test_started": "test_foo",
            "last_test_completed": "test_bar",
            "partial_counts": {"passed": 5, "failed": 0, "skipped": 0},
        }
        state_file.write_text(json.dumps(state))

        result = check_run_state(state_file)
        assert result == EXIT_HANG

    def test_hang_during_specific_test(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        """Hang during specific test is identified."""
        state_file = tmp_path / "run_state.json"
        state = {
            "schema_version": "1.0",
            "in_progress": True,
            "run_id": "123_456",
            "started_at": "2024-01-01T00:00:00Z",
            "last_test_started": "test_crash_here",
            "last_test_completed": "test_previous",
            "partial_counts": {"passed": 3, "failed": 0, "skipped": 0},
        }
        state_file.write_text(json.dumps(state))

        result = check_run_state(state_file)
        captured = capsys.readouterr()

        assert result == EXIT_HANG
        assert "test_crash_here" in captured.out

    def test_completed_passed_returns_passed(self, tmp_path: Path) -> None:
        """Completed run with all tests passed returns EXIT_PASSED."""
        state_file = tmp_path / "run_state.json"
        state = {
            "schema_version": "1.0",
            "in_progress": False,
            "run_id": "123_456",
            "started_at": "2024-01-01T00:00:00Z",
            "completed_at": "2024-01-01T00:01:00Z",
            "passed": True,
            "last_test_started": "test_last",
            "last_test_completed": "test_last",
            "partial_counts": {"passed": 10, "failed": 0, "skipped": 2},
        }
        state_file.write_text(json.dumps(state))

        result = check_run_state(state_file)
        assert result == EXIT_PASSED

    def test_completed_failed_returns_failed(self, tmp_path: Path) -> None:
        """Completed run with failures returns EXIT_FAILED."""
        state_file = tmp_path / "run_state.json"
        state = {
            "schema_version": "1.0",
            "in_progress": False,
            "run_id": "123_456",
            "started_at": "2024-01-01T00:00:00Z",
            "completed_at": "2024-01-01T00:01:00Z",
            "passed": False,
            "last_test_started": "test_last",
            "last_test_completed": "test_last",
            "partial_counts": {"passed": 8, "failed": 2, "skipped": 0},
        }
        state_file.write_text(json.dumps(state))

        result = check_run_state(state_file)
        assert result == EXIT_FAILED

    def test_outputs_partial_counts(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        """Output includes partial counts for debugging."""
        state_file = tmp_path / "run_state.json"
        state = {
            "schema_version": "1.0",
            "in_progress": False,
            "run_id": "123_456",
            "started_at": "2024-01-01T00:00:00Z",
            "completed_at": "2024-01-01T00:01:00Z",
            "passed": True,
            "partial_counts": {"passed": 15, "failed": 0, "skipped": 3},
        }
        state_file.write_text(json.dumps(state))

        check_run_state(state_file)
        captured = capsys.readouterr()

        assert "15 passed" in captured.out
        assert "3 skipped" in captured.out


class TestExitCodes:
    """Tests for exit code values."""

    def test_exit_codes_are_distinct(self) -> None:
        """All exit codes are unique integers."""
        codes = [EXIT_PASSED, EXIT_FAILED, EXIT_CRASH, EXIT_HANG]
        assert len(codes) == len(set(codes))
        assert all(isinstance(c, int) for c in codes)

    def test_exit_passed_is_zero(self) -> None:
        """EXIT_PASSED is 0 for shell compatibility."""
        assert EXIT_PASSED == 0
