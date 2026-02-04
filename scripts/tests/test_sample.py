"""Sample tests demonstrating pytest fixtures and patterns.

This file serves as a template for writing unit tests for automation scripts.
Tests must be deterministic: no network calls, no engine execution.
"""

from __future__ import annotations

from pathlib import Path


class TestFixtureExamples:
    """Demonstrate fixture usage patterns."""

    def test_tmp_path_fixture(self, tmp_path: Path) -> None:
        """tmp_path provides a unique temporary directory per test."""
        # Create a file in the temp directory
        test_file = tmp_path / "example.txt"
        test_file.write_text("hello world")

        assert test_file.exists()
        assert test_file.read_text() == "hello world"

    def test_project_root_fixture(self, project_root: Path) -> None:
        """project_root points to the repository root."""
        assert project_root.exists()
        assert (project_root / "CLAUDE.md").exists()

    def test_scripts_dir_fixture(self, scripts_dir: Path) -> None:
        """scripts_dir points to scripts/ directory."""
        assert scripts_dir.exists()
        assert scripts_dir.name == "scripts"

    def test_temp_script_fixture(self, temp_script: Path) -> None:
        """temp_script creates a temporary Lua file."""
        assert temp_script.exists()
        assert temp_script.suffix == ".lua"
        content = temp_script.read_text()
        assert "function hello()" in content

    def test_mock_project_structure(self, mock_project_structure: Path) -> None:
        """mock_project_structure creates a test project layout."""
        root = mock_project_structure
        assert (root / "assets" / "scripts" / "core" / "test.lua").exists()
        assert (root / "assets" / "graphics" / "test.png").exists()
        assert (root / "docs" / "test.md").exists()


class TestDeterministicPatterns:
    """Demonstrate deterministic test patterns (no I/O, no network)."""

    def test_pure_function(self) -> None:
        """Test pure functions with known inputs/outputs."""

        def add(a: int, b: int) -> int:
            return a + b

        assert add(2, 3) == 5
        assert add(-1, 1) == 0

    def test_string_processing(self) -> None:
        """Test string processing without file I/O."""
        # Example: strip Lua comments
        lua_code = "-- comment\nlocal x = 1  -- inline\n"
        lines = lua_code.split("\n")
        stripped = [line.split("--")[0].rstrip() for line in lines]
        assert stripped[0] == ""  # comment-only line stripped
        assert stripped[1] == "local x = 1"

    def test_path_manipulation(self, tmp_path: Path) -> None:
        """Test path operations without actual filesystem."""
        # Test path joining
        base = Path("/fake/project")
        scripts = base / "scripts" / "core"
        assert str(scripts) == "/fake/project/scripts/core"

        # Test relative path computation
        full_path = Path("/fake/project/scripts/core/timer.lua")
        relative = full_path.relative_to(base)
        assert str(relative) == "scripts/core/timer.lua"


class TestErrorHandling:
    """Demonstrate error handling test patterns."""

    def test_expected_exception(self) -> None:
        """Test that expected exceptions are raised."""
        import pytest

        def parse_int(s: str) -> int:
            if not s.isdigit():
                raise ValueError(f"Invalid integer: {s}")
            return int(s)

        assert parse_int("123") == 123

        with pytest.raises(ValueError, match="Invalid integer"):
            parse_int("abc")

    def test_file_not_found_handling(self, tmp_path: Path) -> None:
        """Test handling of missing files."""
        missing = tmp_path / "does_not_exist.txt"
        assert not missing.exists()

        # Pattern: check existence before read
        if missing.exists():
            content = missing.read_text()
        else:
            content = None

        assert content is None
