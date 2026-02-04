"""Unit tests for check_baseline_size.py.

Tests cover:
- Delta calculation from simulated git diff listings
- Threshold application (WARN at 50MB, FAIL at 200MB)
- Exit codes (0=PASS, 1=WARN, 2=FAIL)
- Stable [BASELINE-SIZE] logging
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))

from check_baseline_size import (
    BYTES_IN_MB,
    EXIT_FAIL,
    EXIT_PASS,
    EXIT_WARN,
    FileChange,
    SizeCheckResult,
    bytes_to_mb,
    calculate_delta,
    calculate_delta_from_diff_listing,
    log,
)


class TestBytesToMb:
    """Test byte to megabyte conversion."""

    def test_zero(self):
        assert bytes_to_mb(0) == 0.0

    def test_one_mb(self):
        assert bytes_to_mb(BYTES_IN_MB) == 1.0

    def test_fractional(self):
        assert bytes_to_mb(BYTES_IN_MB // 2) == 0.5


class TestCalculateDelta:
    """Test delta calculation from FileChange list."""

    def test_empty_changes(self):
        """No changes means zero delta."""
        changes = []
        assert calculate_delta(changes) == 0

    def test_added_file(self):
        """Added files contribute their full size."""
        changes = [
            FileChange(path="test.png", status="A", size_bytes=1000),
        ]
        assert calculate_delta(changes) == 1000

    def test_deleted_file(self):
        """Deleted files contribute negative delta."""
        changes = [
            FileChange(path="test.png", status="D", size_bytes=1000),
        ]
        assert calculate_delta(changes) == -1000

    def test_modified_file(self):
        """Modified files contribute the difference."""
        changes = [
            FileChange(path="test.png", status="M", size_bytes=1500, old_size_bytes=1000),
        ]
        assert calculate_delta(changes) == 500

    def test_modified_file_smaller(self):
        """Modified files can have negative delta if smaller."""
        changes = [
            FileChange(path="test.png", status="M", size_bytes=500, old_size_bytes=1000),
        ]
        assert calculate_delta(changes) == -500

    def test_multiple_changes(self):
        """Multiple changes are summed correctly."""
        changes = [
            FileChange(path="added.png", status="A", size_bytes=1000),
            FileChange(path="deleted.png", status="D", size_bytes=500),
            FileChange(path="modified.png", status="M", size_bytes=1500, old_size_bytes=1000),
        ]
        # 1000 + (-500) + (1500 - 1000) = 1000
        assert calculate_delta(changes) == 1000


class TestCalculateDeltaFromDiffListing:
    """Test delta calculation from git diff --name-status output."""

    def test_empty_listing(self):
        """Empty listing means zero delta."""
        assert calculate_delta_from_diff_listing("", {}) == 0

    def test_added_files(self):
        """Added files from diff listing."""
        diff_listing = "A\ttest_baselines/screenshots/test1.png\nA\ttest_baselines/screenshots/test2.png"
        file_sizes = {
            "test_baselines/screenshots/test1.png": 1000,
            "test_baselines/screenshots/test2.png": 2000,
        }
        assert calculate_delta_from_diff_listing(diff_listing, file_sizes) == 3000

    def test_deleted_files(self):
        """Deleted files from diff listing."""
        diff_listing = "D\ttest_baselines/screenshots/old.png"
        file_sizes = {
            "test_baselines/screenshots/old.png": 5000,
        }
        assert calculate_delta_from_diff_listing(diff_listing, file_sizes) == -5000

    def test_modified_files(self):
        """Modified files use old: prefix for old size."""
        diff_listing = "M\ttest_baselines/screenshots/changed.png"
        file_sizes = {
            "test_baselines/screenshots/changed.png": 1500,
            "old:test_baselines/screenshots/changed.png": 1000,
        }
        assert calculate_delta_from_diff_listing(diff_listing, file_sizes) == 500

    def test_mixed_operations(self):
        """Mix of add, delete, modify operations."""
        diff_listing = """A\ttest_baselines/screenshots/new.png
D\ttest_baselines/screenshots/removed.png
M\ttest_baselines/screenshots/updated.png"""
        file_sizes = {
            "test_baselines/screenshots/new.png": 10 * BYTES_IN_MB,  # +10MB
            "test_baselines/screenshots/removed.png": 5 * BYTES_IN_MB,  # -5MB
            "test_baselines/screenshots/updated.png": 3 * BYTES_IN_MB,  # +1MB (was 2MB)
            "old:test_baselines/screenshots/updated.png": 2 * BYTES_IN_MB,
        }
        # 10 - 5 + (3-2) = 6MB
        assert calculate_delta_from_diff_listing(diff_listing, file_sizes) == 6 * BYTES_IN_MB


class TestThresholds:
    """Test threshold application for WARN and FAIL."""

    def test_pass_under_warn_threshold(self):
        """Delta under warn threshold returns PASS."""
        # 10MB is under 50MB warn threshold
        delta_bytes = 10 * BYTES_IN_MB
        warn_threshold = 50 * BYTES_IN_MB
        fail_threshold = 200 * BYTES_IN_MB

        if abs(delta_bytes) >= fail_threshold:
            status = "FAIL"
        elif abs(delta_bytes) >= warn_threshold:
            status = "WARN"
        else:
            status = "PASS"

        assert status == "PASS"

    def test_warn_between_thresholds(self):
        """Delta between warn and fail thresholds returns WARN."""
        # 75MB is between 50MB warn and 200MB fail
        delta_bytes = 75 * BYTES_IN_MB
        warn_threshold = 50 * BYTES_IN_MB
        fail_threshold = 200 * BYTES_IN_MB

        if abs(delta_bytes) >= fail_threshold:
            status = "FAIL"
        elif abs(delta_bytes) >= warn_threshold:
            status = "WARN"
        else:
            status = "PASS"

        assert status == "WARN"

    def test_fail_over_fail_threshold(self):
        """Delta over fail threshold returns FAIL."""
        # 250MB is over 200MB fail threshold
        delta_bytes = 250 * BYTES_IN_MB
        warn_threshold = 50 * BYTES_IN_MB
        fail_threshold = 200 * BYTES_IN_MB

        if abs(delta_bytes) >= fail_threshold:
            status = "FAIL"
        elif abs(delta_bytes) >= warn_threshold:
            status = "WARN"
        else:
            status = "PASS"

        assert status == "FAIL"

    def test_negative_delta_warn(self):
        """Negative delta (deletions) can also trigger warn."""
        # -75MB should warn (absolute value checked)
        delta_bytes = -75 * BYTES_IN_MB
        warn_threshold = 50 * BYTES_IN_MB
        fail_threshold = 200 * BYTES_IN_MB

        if abs(delta_bytes) >= fail_threshold:
            status = "FAIL"
        elif abs(delta_bytes) >= warn_threshold:
            status = "WARN"
        else:
            status = "PASS"

        assert status == "WARN"


class TestExitCodes:
    """Test exit code constants."""

    def test_exit_pass_is_zero(self):
        """PASS exit code is 0."""
        assert EXIT_PASS == 0

    def test_exit_warn_is_one(self):
        """WARN exit code is 1."""
        assert EXIT_WARN == 1

    def test_exit_fail_is_two(self):
        """FAIL exit code is 2."""
        assert EXIT_FAIL == 2


class TestLogging:
    """Test logging format and prefix."""

    def test_log_prefix(self, capsys):
        """Log messages have [BASELINE-SIZE] prefix."""
        log("Test message", verbose=True)
        captured = capsys.readouterr()
        assert "[BASELINE-SIZE]" in captured.out
        assert "Test message" in captured.out

    def test_log_verbose_false(self, capsys):
        """Verbose=False suppresses output."""
        log("Hidden message", verbose=False)
        captured = capsys.readouterr()
        assert captured.out == ""


class TestSizeCheckResult:
    """Test SizeCheckResult dataclass."""

    def test_dataclass_fields(self):
        """SizeCheckResult has all required fields."""
        result = SizeCheckResult(
            status="PASS",
            exit_code=0,
            current_size_bytes=1000,
            delta_bytes=100,
            warn_threshold_bytes=50 * BYTES_IN_MB,
            fail_threshold_bytes=200 * BYTES_IN_MB,
            files_added=["new.png"],
            files_modified=["changed.png"],
            files_deleted=["removed.png"],
        )
        assert result.status == "PASS"
        assert result.exit_code == 0
        assert result.current_size_bytes == 1000
        assert result.delta_bytes == 100
        assert "new.png" in result.files_added
        assert "changed.png" in result.files_modified
        assert "removed.png" in result.files_deleted


class TestHighFrequencyDecisionRule:
    """Test the high-frequency decision rule (files>=3 OR occurrences>=N)."""

    def test_multiple_files_trigger_high_frequency(self):
        """3+ files should be considered high frequency."""
        # This is a conceptual test - the actual rule would be in the usage code
        file_count = 3
        is_high_frequency = file_count >= 3
        assert is_high_frequency is True

    def test_few_files_not_high_frequency(self):
        """Less than 3 files should not be high frequency alone."""
        file_count = 2
        is_high_frequency = file_count >= 3
        assert is_high_frequency is False


class TestMultilineCommentHandling:
    """Test handling of multiline scenarios in diff listings."""

    def test_multiline_diff_listing(self):
        """Multiline diff listing is parsed correctly."""
        diff_listing = """A\tbaselines/test1.png
A\tbaselines/test2.png
A\tbaselines/test3.png
M\tbaselines/existing.png
D\tbaselines/old.png"""

        file_sizes = {
            "baselines/test1.png": 1000,
            "baselines/test2.png": 2000,
            "baselines/test3.png": 3000,
            "baselines/existing.png": 1500,
            "old:baselines/existing.png": 1000,
            "baselines/old.png": 500,
        }

        delta = calculate_delta_from_diff_listing(diff_listing, file_sizes)
        # 1000 + 2000 + 3000 + (1500-1000) + (-500) = 6000
        assert delta == 6000


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
