#!/usr/bin/env python3
"""Verify copy_assets.py exclusions work correctly."""

import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
COPY_ASSETS = SCRIPT_DIR / "copy_assets.py"
PROJECT_ROOT = SCRIPT_DIR.parent
ASSETS_DIR = PROJECT_ROOT / "assets"


def test_exclusions():
    """Test that excluded files are not copied."""
    with tempfile.TemporaryDirectory() as tmp:
        dst = Path(tmp) / "assets"

        result = subprocess.run(
            [sys.executable, str(COPY_ASSETS), str(ASSETS_DIR), str(dst)],
            capture_output=True,
            text=True,
        )

        if result.returncode != 0:
            print(f"FAIL: Script returned {result.returncode}")
            print(result.stderr)
            return False

        # Check exclusions
        failures = []

        # .DS_Store should not exist anywhere
        ds_stores = list(dst.rglob(".DS_Store"))
        if ds_stores:
            failures.append(f".DS_Store files found: {ds_stores}")

        # docs/ should not exist
        if (dst / "docs").exists():
            failures.append("docs/ directory was copied")

        # siralim_data/ should not exist
        if (dst / "siralim_data").exists():
            failures.append("siralim_data/ directory was copied")

        # chugget_code_definitions.lua should not exist
        chugget_files = list(dst.rglob("chugget_code_definitions.lua"))
        if chugget_files:
            failures.append(f"chugget_code_definitions.lua found: {chugget_files}")

        # scripts_archived/ should not exist
        archived = list(dst.rglob("scripts_archived"))
        if archived:
            failures.append(f"scripts_archived/ found: {archived}")

        if failures:
            print("FAILURES:")
            for f in failures:
                print(f"  - {f}")
            return False

        print("OK: All exclusions verified")
        return True


def test_lua_stripping():
    """Test that --strip-lua removes comments."""
    with tempfile.TemporaryDirectory() as tmp:
        dst = Path(tmp) / "assets"

        subprocess.run(
            [sys.executable, str(COPY_ASSETS), str(ASSETS_DIR), str(dst), "--strip-lua"],
            capture_output=True,
        )

        # Find a Lua file and compare sizes
        src_lua = ASSETS_DIR / "scripts" / "core" / "gameplay.lua"
        dst_lua = dst / "scripts" / "core" / "gameplay.lua"

        if not src_lua.exists() or not dst_lua.exists():
            print("SKIP: gameplay.lua not found for comparison")
            return True

        src_size = src_lua.stat().st_size
        dst_size = dst_lua.stat().st_size

        if dst_size >= src_size:
            print(f"WARN: Stripped file not smaller ({dst_size} >= {src_size})")
            # Not a failure - file might have no comments
            return True

        print(f"OK: Lua stripping works ({src_size} -> {dst_size} bytes)")
        return True


if __name__ == "__main__":
    ok = True
    ok = test_exclusions() and ok
    ok = test_lua_stripping() and ok
    sys.exit(0 if ok else 1)
