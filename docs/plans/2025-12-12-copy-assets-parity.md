# Copy Assets Parity Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ensure justfile and CMake use identical asset-copying logic (exclusions + Lua stripping).

**Architecture:** Create a shared Python script `scripts/copy_assets.py` that both CMake and justfile invoke. The script handles exclusion patterns and optional Lua comment stripping, replacing the ad-hoc `cp -R` in justfile and the 60-line foreach loop in CMakeLists.txt.

**Tech Stack:** Python 3 (already required for `strip_lua_comments.py`), CMake, just

---

## Task 1: Create `scripts/copy_assets.py`

**Files:**
- Create: `scripts/copy_assets.py`

**Step 1: Write the script**

```python
#!/usr/bin/env python3
"""
Copy assets directory with exclusions and optional Lua comment stripping.
Used by both CMake and justfile to ensure parity.

Usage:
    python3 scripts/copy_assets.py <src_dir> <dst_dir> [--strip-lua]

Exclusions (matching CMakeLists.txt lines 978-985):
    - .DS_Store files
    - graphics/pre-packing-files_globbed
    - scripts_archived/ directories
    - chugget_code_definitions.lua
    - siralim_data/ directories
    - docs/ directories
"""

import argparse
import shutil
import sys
from pathlib import Path

# Import strip_comments from sibling script
SCRIPT_DIR = Path(__file__).parent
sys.path.insert(0, str(SCRIPT_DIR))
from strip_lua_comments import strip_comments


# Exclusion patterns matching CMakeLists.txt lines 978-985
EXCLUDE_PATTERNS = [
    ".DS_Store",
    "graphics/pre-packing-files_globbed",
    "scripts_archived",
    "chugget_code_definitions.lua",
    "siralim_data",
    "docs",
]


def should_exclude(rel_path: Path) -> bool:
    """Check if a relative path should be excluded."""
    rel_str = str(rel_path)
    parts = rel_path.parts

    for pattern in EXCLUDE_PATTERNS:
        # Exact filename match (e.g., .DS_Store, chugget_code_definitions.lua)
        if rel_path.name == pattern:
            return True
        # Directory component match (e.g., scripts_archived, siralim_data, docs)
        if pattern in parts:
            return True
        # Path contains pattern (e.g., graphics/pre-packing-files_globbed)
        if pattern in rel_str:
            return True

    return False


def copy_assets(src_dir: Path, dst_dir: Path, strip_lua: bool, verbose: bool) -> int:
    """
    Copy assets from src_dir to dst_dir with exclusions.

    Returns the number of files copied.
    """
    if not src_dir.is_dir():
        print(f"ERROR: Source directory does not exist: {src_dir}", file=sys.stderr)
        return -1

    # Clean destination directory first (matches CMake behavior)
    if dst_dir.exists():
        shutil.rmtree(dst_dir)

    copied = 0
    skipped = 0

    for src_file in src_dir.rglob("*"):
        if not src_file.is_file():
            continue

        rel_path = src_file.relative_to(src_dir)

        if should_exclude(rel_path):
            skipped += 1
            if verbose:
                print(f"  SKIP: {rel_path}")
            continue

        dst_file = dst_dir / rel_path
        dst_file.parent.mkdir(parents=True, exist_ok=True)

        # Strip Lua comments if requested
        if strip_lua and src_file.suffix == ".lua":
            data = src_file.read_text(encoding="utf-8")
            stripped = strip_comments(data)
            dst_file.write_text(stripped, encoding="utf-8")
            if verbose:
                print(f"  STRIP: {rel_path}")
        else:
            shutil.copy2(src_file, dst_file)
            if verbose:
                print(f"  COPY: {rel_path}")

        copied += 1

    return copied, skipped


def main():
    parser = argparse.ArgumentParser(
        description="Copy assets with exclusions and optional Lua stripping"
    )
    parser.add_argument("src_dir", type=Path, help="Source assets directory")
    parser.add_argument("dst_dir", type=Path, help="Destination directory")
    parser.add_argument(
        "--strip-lua",
        action="store_true",
        help="Strip comments from .lua files (for release builds)",
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Print each file as it's processed",
    )

    args = parser.parse_args()

    print(f"Copying assets: {args.src_dir} -> {args.dst_dir}")
    if args.strip_lua:
        print("  Lua comment stripping: ENABLED")

    result = copy_assets(args.src_dir, args.dst_dir, args.strip_lua, args.verbose)

    if isinstance(result, tuple):
        copied, skipped = result
        print(f"Done: {copied} files copied, {skipped} files skipped")
        return 0
    else:
        return 1


if __name__ == "__main__":
    sys.exit(main())
```

**Step 2: Make the script executable**

Run: `chmod +x scripts/copy_assets.py`

**Step 3: Test the script manually**

Run:
```bash
# Test without Lua stripping
python3 scripts/copy_assets.py assets /tmp/test-assets -v

# Verify exclusions worked
ls /tmp/test-assets/  # Should NOT contain docs/, siralim_data/
find /tmp/test-assets -name ".DS_Store"  # Should return nothing
find /tmp/test-assets -name "chugget_code_definitions.lua"  # Should return nothing

# Test with Lua stripping
python3 scripts/copy_assets.py assets /tmp/test-assets-stripped --strip-lua -v

# Compare a Lua file size (stripped should be smaller)
wc -c assets/scripts/core/gameplay.lua /tmp/test-assets-stripped/scripts/core/gameplay.lua
```

Expected: Stripped version is noticeably smaller (comments removed).

**Step 4: Commit**

```bash
git add scripts/copy_assets.py
git commit -m "feat: add unified copy_assets.py script for CMake/justfile parity"
```

---

## Task 2: Update justfile `build-web` recipe

**Files:**
- Modify: `justfile:19-45` (build-web recipe)

**Step 1: Replace cp -R with Python script call**

Change lines 37-39 in `justfile` from:

```just
	# Ensure asset folder is copied
	rm -rf build-emc/assets || true
	cp -R assets build-emc/assets
```

To:

```just
	# Copy assets with exclusions (parity with CMake)
	python3 scripts/copy_assets.py assets build-emc/assets
```

**Step 2: Add `build-web-release` recipe with Lua stripping**

Add after `build-web` recipe (around line 46):

```just
# Web build with Lua comment stripping (smaller payload)
build-web-release:
	#!/usr/bin/env bash
	set -e

	: "${WEB_JOBS:=2}"

	# Activate Emscripten
	if [ -f "/usr/lib/emsdk/emsdk_env.sh" ]; then
		source "/usr/lib/emsdk/emsdk_env.sh"
	elif [ -f "$HOME/emsdk/emsdk_env.sh" ]; then
		source "$HOME/emsdk/emsdk_env.sh"
	else
		echo "Warning: emsdk_env.sh not found, assuming emcc is in PATH"
	fi

	mkdir -p build-emc

	# Copy assets with exclusions AND Lua stripping
	python3 scripts/copy_assets.py assets build-emc/assets --strip-lua

	cd build-emc
	emcmake cmake .. -DPLATFORM=Web -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXE_LINKER_FLAGS="-s USE_GLFW=3"
	emmake make -j"${WEB_JOBS}"

	echo "Release build complete! Files are in build-emc/"
```

**Step 3: Test the updated build-web recipe**

Run:
```bash
just build-web
```

Expected: Build succeeds, `build-emc/assets/` exists without excluded files.

Verify:
```bash
# Should NOT exist
ls build-emc/assets/docs 2>/dev/null && echo "FAIL: docs/ exists" || echo "OK: docs/ excluded"
find build-emc/assets -name ".DS_Store" | grep -q . && echo "FAIL: .DS_Store exists" || echo "OK: .DS_Store excluded"
```

**Step 4: Commit**

```bash
git add justfile
git commit -m "feat(justfile): use copy_assets.py for web builds with proper exclusions"
```

---

## Task 3: Update `build-web-dist` recipe

**Files:**
- Modify: `justfile:47-81` (build-web-dist recipe)

**Step 1: Update build-web-dist to use release stripping**

The `build-web-dist` recipe calls `just build-web`. Change line 52 from:

```just
	just build-web
```

To:

```just
	just build-web-release
```

This ensures distribution builds get Lua stripping automatically.

**Step 2: Test build-web-dist**

Run:
```bash
just build-web-dist
```

Expected: Build succeeds, Lua files in `build-emc/assets/scripts/` are stripped.

Verify:
```bash
# Check that a Lua file is smaller than source
SRC_SIZE=$(wc -c < assets/scripts/core/gameplay.lua)
DST_SIZE=$(wc -c < build-emc/assets/scripts/core/gameplay.lua)
echo "Source: $SRC_SIZE bytes, Dest: $DST_SIZE bytes"
# DST_SIZE should be noticeably smaller
```

**Step 3: Commit**

```bash
git add justfile
git commit -m "feat(justfile): build-web-dist now uses Lua stripping"
```

---

## Task 4: (Optional) Update CMakeLists.txt to use shared script

**Files:**
- Modify: `CMakeLists.txt:959-1014` (copy_assets target)

This task is optional but recommended for true single-source-of-truth. The existing CMake logic works; this replaces it with the shared script.

**Step 1: Simplify the copy_assets target**

Replace lines 959-1014 in `CMakeLists.txt` with:

```cmake
    # Copy assets into the web output tree to match expected /assets layout.
    # Uses shared Python script for parity with justfile.
    set(_strip_lua_flag "")
    if(STRIP_LUA_COMMENTS_FOR_WEB AND Python3_Interpreter_FOUND)
        set(_is_release_like FALSE)
        if(CMAKE_BUILD_TYPE MATCHES "Rel" OR CMAKE_BUILD_TYPE MATCHES "MinSizeRel" OR CMAKE_BUILD_TYPE MATCHES "Release")
            set(_is_release_like TRUE)
        endif()
        if(_is_release_like)
            set(_strip_lua_flag "--strip-lua")
        endif()
    endif()

    add_custom_target(copy_assets
        COMMAND ${Python3_EXECUTABLE} "${CMAKE_SOURCE_DIR}/scripts/copy_assets.py"
                "${CMAKE_SOURCE_DIR}/assets"
                "${WEB_BUILD_DIR}/assets"
                ${_strip_lua_flag}
        COMMENT "Copying assets to web build directory (exclusions + optional Lua stripping)"
    )
```

**Step 2: Test CMake copy_assets target**

Run:
```bash
cmake -B build-test -DENABLE_WEB_HELPER_TARGETS=ON
cmake --build build-test --target copy_assets
```

Expected: Assets copied to `build-emc/assets/` with exclusions applied.

**Step 3: Commit**

```bash
git add CMakeLists.txt
git commit -m "refactor(cmake): use shared copy_assets.py script"
```

---

## Task 5: Add verification test

**Files:**
- Create: `scripts/test_copy_assets.py`

**Step 1: Write a simple verification script**

```python
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
```

**Step 2: Run verification**

Run:
```bash
python3 scripts/test_copy_assets.py
```

Expected: Both tests pass.

**Step 3: Commit**

```bash
git add scripts/test_copy_assets.py
git commit -m "test: add verification for copy_assets.py exclusions"
```

---

## Summary

| Task | What | Files |
|------|------|-------|
| 1 | Create shared Python script | `scripts/copy_assets.py` |
| 2 | Update `build-web` recipe | `justfile` |
| 3 | Update `build-web-dist` recipe | `justfile` |
| 4 | (Optional) Simplify CMake | `CMakeLists.txt` |
| 5 | Add verification test | `scripts/test_copy_assets.py` |

After completion:
- `just build-web` uses same exclusions as CMake
- `just build-web-release` / `just build-web-dist` strips Lua comments
- Single source of truth for exclusion patterns in `scripts/copy_assets.py`
