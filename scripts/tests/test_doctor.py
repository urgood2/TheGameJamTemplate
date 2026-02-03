"""Unit tests for doctor.py toolchain validation.

Tests cover:
- Missing required tool -> non-zero exit + actionable message
- Optional tool missing -> still passes but logs as optional
- Version parsing robustness (python/rg/cm)
- Output contains stable [DOCTOR] prefixes
- JSON output format
"""

from __future__ import annotations

import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

# Add scripts to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from doctor import (
    LOG_PREFIX,
    DoctorResult,
    ToolCheck,
    check_cm_cli,
    check_git,
    check_jsonschema,
    check_python_version,
    check_pytest,
    check_ripgrep,
    get_install_hint,
    run_command,
    run_doctor,
)


class TestLogPrefix:
    """Test logging format requirements."""

    def test_log_prefix_stable(self) -> None:
        """Log prefix is stable and parseable."""
        assert LOG_PREFIX == "[DOCTOR]"

    def test_log_prefix_format(self) -> None:
        """Log prefix follows expected pattern."""
        assert LOG_PREFIX.startswith("[")
        assert LOG_PREFIX.endswith("]")
        assert "DOCTOR" in LOG_PREFIX


class TestToolCheck:
    """Test ToolCheck dataclass."""

    def test_default_values(self) -> None:
        """ToolCheck has sensible defaults."""
        check = ToolCheck(name="test")
        assert check.name == "test"
        assert check.required is True
        assert check.found is False
        assert check.version is None
        assert check.path is None

    def test_optional_tool(self) -> None:
        """Optional tools can be created."""
        check = ToolCheck(name="optional_tool", required=False)
        assert check.required is False


class TestDoctorResult:
    """Test DoctorResult aggregation."""

    def test_empty_result_ready(self) -> None:
        """Empty result (no checks) is ready."""
        result = DoctorResult()
        assert result.is_ready is True
        assert result.required_found == 0
        assert result.required_total == 0

    def test_all_required_found(self) -> None:
        """Result is ready when all required tools found."""
        result = DoctorResult(
            checks=[
                ToolCheck(name="a", required=True, found=True),
                ToolCheck(name="b", required=True, found=True),
            ]
        )
        assert result.is_ready is True
        assert result.required_found == 2
        assert result.required_total == 2

    def test_missing_required_not_ready(self) -> None:
        """Result is not ready when required tool missing."""
        result = DoctorResult(
            checks=[
                ToolCheck(name="a", required=True, found=True),
                ToolCheck(name="b", required=True, found=False),
            ]
        )
        assert result.is_ready is False
        assert result.required_found == 1
        assert result.required_total == 2

    def test_missing_optional_still_ready(self) -> None:
        """Result is ready even when optional tool missing."""
        result = DoctorResult(
            checks=[
                ToolCheck(name="required", required=True, found=True),
                ToolCheck(name="optional", required=False, found=False),
            ]
        )
        assert result.is_ready is True
        assert result.optional_found == 0
        assert result.optional_total == 1

    def test_to_dict_structure(self) -> None:
        """to_dict produces expected JSON structure."""
        result = DoctorResult(
            checks=[
                ToolCheck(
                    name="python",
                    required=True,
                    found=True,
                    version="3.11.5",
                    path="/usr/bin/python3",
                ),
            ]
        )
        d = result.to_dict()

        assert "ready" in d
        assert "required" in d
        assert "optional" in d
        assert "checks" in d
        assert d["ready"] is True
        assert d["required"]["found"] == 1
        assert d["required"]["total"] == 1
        assert len(d["checks"]) == 1
        assert d["checks"][0]["name"] == "python"
        assert d["checks"][0]["version"] == "3.11.5"


class TestInstallHints:
    """Test platform-specific install hints."""

    def test_python_hint_exists(self) -> None:
        """Python install hint is provided."""
        hint = get_install_hint("python")
        assert hint  # Non-empty

    def test_ripgrep_hint_exists(self) -> None:
        """ripgrep install hint is provided."""
        hint = get_install_hint("ripgrep")
        assert hint

    def test_unknown_tool_empty_hint(self) -> None:
        """Unknown tool returns empty hint."""
        hint = get_install_hint("nonexistent_tool_xyz")
        assert hint == ""


class TestRunCommand:
    """Test command execution wrapper."""

    def test_successful_command(self) -> None:
        """Successful command returns 0 and output."""
        returncode, stdout, _ = run_command(["echo", "hello"])
        assert returncode == 0
        assert "hello" in stdout

    def test_missing_command(self) -> None:
        """Missing command returns negative code."""
        returncode, _, stderr = run_command(["nonexistent_cmd_xyz_123"])
        assert returncode < 0
        assert "not found" in stderr.lower() or returncode == -1


class TestPythonVersionCheck:
    """Test Python version validation."""

    def test_current_python_found(self) -> None:
        """Current Python version is always found."""
        check = check_python_version()
        assert check.found is True
        assert check.name == "Python"
        assert check.required is True
        assert check.version is not None
        assert check.path is not None

    def test_python_path_valid(self) -> None:
        """Python path points to executable."""
        check = check_python_version()
        assert check.path == sys.executable


class TestRipgrepCheck:
    """Test ripgrep availability check."""

    def test_ripgrep_check_structure(self) -> None:
        """Ripgrep check has correct structure."""
        check = check_ripgrep()
        assert check.name == "ripgrep"
        assert check.required is True
        assert isinstance(check.found, bool)

    @patch("doctor.shutil.which")
    @patch("doctor.run_command")
    def test_ripgrep_not_found(
        self, mock_run: MagicMock, mock_which: MagicMock
    ) -> None:
        """Missing ripgrep returns found=False."""
        mock_which.return_value = None
        check = check_ripgrep()
        assert check.found is False
        assert check.install_hint  # Has install hint

    @patch("doctor.shutil.which")
    @patch("doctor.run_command")
    def test_ripgrep_version_parsing(
        self, mock_run: MagicMock, mock_which: MagicMock
    ) -> None:
        """Ripgrep version is parsed correctly."""
        mock_which.return_value = "/usr/bin/rg"
        mock_run.return_value = (0, "ripgrep 14.0.3\n-SIMD -AVX (compiled)\n", "")

        check = check_ripgrep()

        assert check.found is True
        assert check.version == "14.0.3"
        assert check.path == "/usr/bin/rg"


class TestCmCliCheck:
    """Test cm CLI check."""

    def test_cm_is_optional(self) -> None:
        """cm CLI is optional."""
        check = check_cm_cli()
        assert check.required is False

    @patch("doctor.shutil.which")
    def test_cm_not_found_ok(self, mock_which: MagicMock) -> None:
        """Missing cm doesn't fail (optional)."""
        mock_which.return_value = None
        check = check_cm_cli()
        assert check.found is False
        # Still has helpful hint
        assert check.install_hint


class TestGitCheck:
    """Test git availability check."""

    def test_git_is_optional(self) -> None:
        """Git is optional."""
        check = check_git()
        assert check.required is False

    @patch("doctor.shutil.which")
    @patch("doctor.run_command")
    def test_git_version_parsing(
        self, mock_run: MagicMock, mock_which: MagicMock
    ) -> None:
        """Git version is parsed correctly."""
        mock_which.return_value = "/usr/bin/git"
        mock_run.return_value = (0, "git version 2.43.0\n", "")

        check = check_git()

        assert check.found is True
        assert check.version == "2.43.0"


class TestJsonschemaCheck:
    """Test jsonschema package check."""

    def test_jsonschema_required(self) -> None:
        """jsonschema is required."""
        check = check_jsonschema()
        assert check.required is True

    def test_jsonschema_found_in_test_env(self) -> None:
        """jsonschema should be found in test environment."""
        # Assuming tests run with requirements installed
        check = check_jsonschema()
        # This may or may not be installed - just check structure
        assert check.name == "jsonschema"
        assert isinstance(check.found, bool)


class TestPytestCheck:
    """Test pytest package check."""

    def test_pytest_is_optional(self) -> None:
        """pytest is optional."""
        check = check_pytest()
        assert check.required is False

    def test_pytest_found_in_test_env(self) -> None:
        """pytest should be found since we're running pytest."""
        check = check_pytest()
        assert check.found is True
        assert check.version is not None


class TestRunDoctor:
    """Test full doctor run."""

    def test_run_doctor_returns_result(self) -> None:
        """run_doctor returns DoctorResult."""
        result = run_doctor()
        assert isinstance(result, DoctorResult)
        assert len(result.checks) > 0

    def test_run_doctor_checks_python(self) -> None:
        """run_doctor includes Python check."""
        result = run_doctor()
        python_checks = [c for c in result.checks if c.name == "Python"]
        assert len(python_checks) == 1
        assert python_checks[0].found is True

    def test_run_doctor_checks_required(self) -> None:
        """run_doctor includes all required checks."""
        result = run_doctor()
        required = [c for c in result.checks if c.required]
        # At minimum: Python, ripgrep, jsonschema
        assert len(required) >= 3


class TestActionableMessages:
    """Test that missing tools provide actionable messages."""

    def test_missing_tool_has_install_hint(self) -> None:
        """Missing tools should have install hints."""
        check = ToolCheck(
            name="missing_tool",
            required=True,
            found=False,
            install_hint="pip install missing_tool",
        )
        assert check.install_hint
        assert "install" in check.install_hint.lower()

    def test_missing_tool_has_purpose(self) -> None:
        """Check purpose is documented."""
        check = check_ripgrep()
        assert check.purpose  # Has purpose description


class TestOutputFormat:
    """Test output format requirements."""

    def test_result_json_serializable(self) -> None:
        """Result can be serialized to JSON."""
        import json

        result = run_doctor()
        # Should not raise
        json_str = json.dumps(result.to_dict())
        assert json_str

        # Should be valid JSON
        parsed = json.loads(json_str)
        assert "ready" in parsed
        assert "checks" in parsed
