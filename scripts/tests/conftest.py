"""Shared pytest fixtures for scripts tests.

Usage:
    pytest scripts/tests -q
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import TYPE_CHECKING

import pytest

if TYPE_CHECKING:
    from collections.abc import Generator

# Add scripts directory to path for imports
SCRIPTS_DIR = Path(__file__).parent.parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))


@pytest.fixture
def project_root() -> Path:
    """Return the project root directory."""
    return SCRIPTS_DIR.parent


@pytest.fixture
def scripts_dir() -> Path:
    """Return the scripts directory."""
    return SCRIPTS_DIR


@pytest.fixture
def assets_dir(project_root: Path) -> Path:
    """Return the assets directory."""
    return project_root / "assets"


@pytest.fixture
def sample_lua_content() -> str:
    """Sample Lua script content for testing."""
    return """\
-- This is a comment
local function hello()
    print("Hello")  -- inline comment
end
return hello
"""


@pytest.fixture
def temp_script(tmp_path: Path, sample_lua_content: str) -> Path:
    """Create a temporary Lua script for testing."""
    script = tmp_path / "test_script.lua"
    script.write_text(sample_lua_content)
    return script


@pytest.fixture
def mock_project_structure(tmp_path: Path) -> Generator[Path, None, None]:
    """Create a mock project structure for testing.

    Structure:
        tmp_path/
            assets/
                scripts/
                    core/
                        test.lua
                graphics/
                    test.png
            docs/
                test.md
    """
    # Create directories
    (tmp_path / "assets" / "scripts" / "core").mkdir(parents=True)
    (tmp_path / "assets" / "graphics").mkdir(parents=True)
    (tmp_path / "docs").mkdir(parents=True)

    # Create sample files
    (tmp_path / "assets" / "scripts" / "core" / "test.lua").write_text("-- test")
    (tmp_path / "assets" / "graphics" / "test.png").write_bytes(b"PNG")
    (tmp_path / "docs" / "test.md").write_text("# Test")

    yield tmp_path
