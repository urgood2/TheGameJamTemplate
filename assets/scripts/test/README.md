# Test Infrastructure

This directory contains the Lua test harness for verifying engine patterns and documentation.

Canonical test root: `assets/scripts/test/`.

## Quick Start

```bash
# Setup toolchain (first time)
./scripts/bootstrap_dev.sh

# Full verification pipeline (inventory + docs + tests)
./scripts/check_all.sh

# Run all tests (from project root)
./build/raylib-cpp-cmake-template --scene test

# Check results
cat test_output/status.json

# Smoke run (Lua CLI, no engine)
lua -e 'package.path = package.path .. ";./assets/scripts/?.lua"; local r = require("test.test_runner"); require("test.test_smoke"); r.run({filter="harness."})'
```

## Tooling Setup

1. **Python 3.10+** required for scripts
2. Run `./scripts/bootstrap_dev.sh` to create Python venv
3. Verify dependencies: `uv run --with pytest pytest scripts/tests -q`

## Running Tests

### Full Suite
Run the game executable with the test scene:
```bash
./build/raylib-cpp-cmake-template --scene test
```

Or use the build system:
```bash
just test
```

### Specific Category
Filter tests by category:
```bash
./build/raylib-cpp-cmake-template --scene test --filter category=physics
```

### Sharded (CI)
For parallel CI execution:
```bash
./build/raylib-cpp-cmake-template --scene test --shard-count 4 --shard-index 0
```

## Test Output

All outputs are written to `test_output/` in the project root:

| File | Purpose |
|------|---------|
| `status.json` | Pass/fail summary |
| `results.json` | Per-test details with timing |
| `report.md` | Human-readable report |
| `junit.xml` | CI integration format |
| `coverage_report.md` | Doc/test coverage report |
| `run_state.json` | Crash/hang detection sentinel |
| `capabilities.json` | Environment Go/No-Go gates |
| `test_manifest.json` | Test registration and doc_id mappings |
| `screenshots/` | Visual test captures |
| `artifacts/` | Test failure artifacts |

## Writing Tests

### Basic Test Registration

```lua
local TestRunner = require("test.test_runner")
local test_utils = require("test.test_utils")

TestRunner.register("physics.raycast.basic", "physics", function()
    -- Arrange
    local start = vec2(0, 0)
    local target = vec2(100, 0)

    -- Act
    local hit = physics.segment_query(start, target)

    -- Assert
    test_utils.assert_eq(hit.entity, expected_entity, "Expected entity hit")
end, {
    tags = {"physics", "query"},
    doc_ids = {"binding:physics.segment_query"},
    requires = {}
})
```

### Test with Screenshot

```lua
TestRunner.register("ui.layout.alignment", "ui", function()
    -- Setup UI elements
    local panel = create_test_panel()

    -- Trigger layout
    ui.box.RenewAlignment(registry, panel)

    -- Capture for visual verification
    test_utils.capture_screenshot("ui.layout.alignment")

    -- Assert positions
    local child = get_first_child(panel)
    test_utils.assert_gt(child.x, 0, "Child should be positioned")
end, {
    tags = {"visual", "ui"},
    doc_ids = {"pattern:ui.uibox_alignment.renew_after_offset"},
    requires = {"screenshot"}
})
```

### Test Metadata Fields

| Field | Required | Description |
|-------|----------|-------------|
| `tags` | No | Categories for filtering (visual, smoke, integration) |
| `doc_ids` | Yes | Documentation IDs this test verifies |
| `requires` | No | Capabilities needed (screenshot, log_capture) |
| `timeout_ms` | No | Override default timeout |
| `self_test` | No | Marks harness self-tests (run first) |

## doc_id Formats

Tests should reference doc_ids in one of these formats:

- `binding:<lua_name>` - For Sol2 bindings (e.g., `binding:physics.segment_query`)
- `component:<ComponentName>` - For ECS components (e.g., `component:Transform`)
- `pattern:<system>.<feature>.<case>` - For behavioral patterns (e.g., `pattern:ui.uibox_alignment.renew_after_offset`)

## Assertion Helpers

Available in `test_utils.lua`:

```lua
test_utils.assert_eq(actual, expected, message)     -- Equality
test_utils.assert_neq(actual, expected, message)    -- Inequality
test_utils.assert_true(condition, message)          -- Boolean true
test_utils.assert_false(condition, message)         -- Boolean false
test_utils.assert_nil(value, message)               -- Is nil
test_utils.assert_not_nil(value, message)           -- Is not nil
test_utils.assert_gt(actual, expected, message)     -- Greater than
test_utils.assert_gte(actual, expected, message)    -- Greater or equal
test_utils.assert_lt(actual, expected, message)     -- Less than
test_utils.assert_lte(actual, expected, message)    -- Less or equal
test_utils.assert_contains(haystack, needle, msg)   -- String contains
test_utils.assert_throws(fn, message)               -- Function throws
test_utils.assert_error(fn, message)                -- Error contains message
test_utils.safe_filename(name)                      -- Stable path-safe name
```

## Determinism Requirements

The harness enforces determinism assumptions used by documentation verification:

1. RNG seeding per test: `math.randomseed(12345)`
2. Fixed timestep: use frame-driven waits (avoid time-based sleeps)
3. Explicit camera reset before/after each test
4. Rendering config recorded in `capabilities.json` when available
5. Output wipe policy enforced each run
6. Test isolation via `reset_world()` between tests

If any of these are not possible in the runtime environment, record the limitation in `test_output/capabilities.json` and mark affected tests as skipped.

## Known Non-Determinism

See [planning/known_nondeterminism.md](../../../../planning/known_nondeterminism.md)
for documented sources of nondeterminism, mitigations, and tolerance
configuration details.

## Output Wipe Policy

Each run wipes `test_output/` files and regenerates:

- `status.json`, `results.json`, `report.md`, `junit.xml`, `test_manifest.json`
- `screenshots/` and `artifacts/` folders (preserving `.gitkeep`)

Baselines are stored under `test_baselines/` and are never deleted by the runner.

## Visual Baselines

Visual baselines are stored under:

`test_baselines/screenshots/<platform>/<renderer>/<resolution>/`

To record baselines manually:

```lua
local TestRunner = require("test.test_runner")
TestRunner.run({ record_baselines = true })
```

Baselines are never deleted by the runner. Use `python3 scripts/check_baseline_size.py` to enforce size limits.

## Full Verification Pipeline

For a single-command verification pass (inventory regen + schemas + docs + tests):

```bash
./scripts/check_all.sh
```

For a fast subset (validators only, no regeneration/tests):

```bash
./scripts/check_fast.sh
```

## Build Validation (UBS)

**What is UBS?** Justfile-driven build + unit test validation gate.

**Commands:**

```bash
# Full build validation
just build-debug && just test

# Quick validation
just test
```

**Pass/Fail Signal:**
- Exit code `0` = PASS
- Exit code non-zero = FAIL

**Log Location:**
- Stdout/stderr from `just`/`cmake`
- Unit test output from `./build/tests/unit_tests`

## CM Playbook Backup

Export the cm playbook after updates:

```bash
cm playbook export > planning/cm_rules_backup.json
```

## Crash Detection

The test harness uses `run_state.json` as a sentinel:

1. `init` written at start
2. `test_start` before each test
3. `test_end` after each test
4. `complete` at end

If execution stops mid-test, the sentinel reveals where. Use:

```bash
python scripts/check_run_state.py test_output/run_state.json
```

Exit codes: `0` = passed, `1` = failed, `2` = crash, `3` = hang

## Pre-flight Verification

Phase 1 pre-flight verification completed. All Go/No-Go gates documented below.

```
[PREFLIGHT] === Pre-flight Environment Verification ===
[PREFLIGHT] Test scene loading: NOT VERIFIED
[PREFLIGHT]   Entrypoint: Lua scripts loaded by scripting::initLuaMasterState
[PREFLIGHT]   File: src/systems/scripting/scripting_functions.cpp
[PREFLIGHT] Screenshot capture: CONDITIONAL
[PREFLIGHT]   Function: TakeScreenshot() or capture_screenshot()
[PREFLIGHT]   Safe timing: end-of-frame via screenshot_after_frames()
[PREFLIGHT] UBS definition: IDENTIFIED
[PREFLIGHT]   Command: just build-debug && just test
[PREFLIGHT]   Pass/fail signal: exit code 0 = PASS
```

### 1. Test Scene Loading
- **Status**: NOT VERIFIED (no explicit C++ test scene switch found)
- **Entrypoint**: Lua scripts are loaded by `scripting::initLuaMasterState` (C++), which consumes a file list and sets Lua `package.path`
- **Known Lua root**: `assets/scripts/core/main.lua` (main loop)
- **Scene selection**: `TEST_SCENE=1` env var and/or `_G.TEST_SCENE` are used by the harness to mark test mode
- **Authoritative files**: `test_runner.lua`, `test_smoke.lua`, `test_selftest.lua`, `run_smoke.lua`

### 2. Deterministic Execution
- **RNG seeding**: `math.randomseed(12345)` via `test_utils.reset_world()`
- **Frame-driven waits**: `test_utils.step_frames(n)` helper available
- **Camera reset**: `camera.set_position(0,0); camera.set_zoom(1.0)` in reset_world
- **Animation isolation**: Frame-count driven, not time-based

### 3. Rendering Config
- **Resolution**: Recorded in `capabilities.json` as `environment.resolution`
- **DPI scale**: Recorded in `capabilities.json` as `environment.dpi_scale`
- **Renderer**: Recorded in `capabilities.json` as `environment.renderer`
- **VSync**: Should be disabled for deterministic capture (engine-dependent)

### 4. Screenshot Capture
- **Status**: CONDITIONALLY AVAILABLE (fallback to placeholder outside engine)
- **Functions**: `TakeScreenshot`, `capture_screenshot`, or `take_screenshot`
- **Safe timing**: End-of-frame (via `screenshot_after_frames()`)
- **Helper**: `test_utils.screenshot_after_frames(name, nFrames)`

### 5. Write Access
- **Status**: VERIFIED (test_output/ writable)
- **Directories**: `test_output/`, `test_output/screenshots/`, `test_output/artifacts/`
- **Gitkeep markers**: Committed in screenshots/ and artifacts/

### 6. World Reset Strategy
- **Function**: `test_utils.reset_world()`
- **Clears**: Spawned entities, registries (UI/physics), component cache
- **Resets**: RNG seed, camera position/zoom, UI root
- **Logging**: `[RESET]` prefix for debugging

### 7. Log Capture
- **Status**: NOT DETECTED in current runtime
- **Methods**: `capture_log_start/end`, `log_capture_start/end`, or `test_logger`
- **Fallback**: Tests log directly via print(), captured by runner

### 8. UBS Definition
- **Name**: Unified Build Script (build + test validation)
- **Command**: `just build-debug && just test`
- **Pass signal**: Exit code 0
- **Log location**: Stdout/stderr + `./build/tests/unit_tests`
- **CI gate**: Required before merge / Phase 8 changes

### 9. Run Procedure
- **Interactive (current)**: `lua5.4 assets/scripts/test/run_smoke.lua`
- **In-engine (pending)**: hook a test scene or console command to `require("test.test_runner")`
- **CI/Headless (pending)**: provide a `--scene test` switch once wired
- **Smoke only**: `lua5.4 assets/scripts/test/run_smoke.lua`
- **Sharded**: `--shard-count N --shard-index I`

## Go/No-Go Gates

Check `test_output/capabilities.json` for environment capabilities:

```json
{
  "schema_version": "1.0",
  "generated_at": "2026-02-03T00:00:00Z",
  "capabilities": {
    "screenshot": true,
    "log_capture": true,
    "input_simulation": false,
    "headless": false,
    "network": false,
    "gpu": true,
    "test_scene": false,
    "output_writable": true,
    "world_reset": true,
    "ubs": true
  },
  "gates": {
    "deterministic_test_scene": false,
    "test_output_writable": true,
    "screenshot_capture": false,
    "log_capture": false,
    "world_reset": true,
    "ubs_identified": true
  },
  "details": {
    "screenshot_api": "TakeScreenshot",
    "screenshot_timing": "end_of_frame",
    "log_capture_method": "engine_logger",
    "world_reset_strategy": "test_utils.reset_world()",
    "ubs_command": "just build-debug && just test",
    "ubs_quick_command": "just test",
    "ubs_pass_fail": "Exit code 0 = PASS; non-zero = FAIL",
    "ubs_log_location": "stdout/stderr"
  },
  "environment": {
    "renderer": "opengl",
    "resolution": "1920x1080",
    "dpi_scale": 1.0
  }
}
```

Tests requiring missing capabilities are skipped, not failed.

## Directory Structure

```
assets/scripts/test/
├── README.md              # This file
├── capabilities.lua       # Capability detection helper (optional)
├── json.lua               # Deterministic JSON encoder (optional)
├── test_runner.lua        # Main test harness
├── test_utils.lua         # Assertion helpers
├── test_registry.lua      # doc_id to test mapping
├── run_state.lua          # Crash detection sentinel
├── test_selftest.lua      # Harness self-tests
├── test_smoke.lua         # Smoke tests
├── run_smoke.lua          # Standalone smoke runner
├── test_entity_lifecycle.lua  # Entity lifecycle tests
├── test_styled_localization.lua # Localization tests
└── ...                    # Additional test modules
```

## Full Verification Pipeline (check_all)

Run the full verification pipeline from the repo root:

- Unix/macOS: `./scripts/check_all.sh`
- Windows: `.\scripts\check_all.ps1`

Dry-run (logs steps without executing commands):

- `python3 scripts/check_all.py --dry-run`

The pipeline runs toolchain validation, inventory regeneration, scope stats,
doc skeleton generation, schema validation, registry sync, docs consistency
checks, evidence block checks, and the test suite (plus coverage report
generation when available).

## Troubleshooting

### Tests hang indefinitely
- Check `test_output/run_state.json` for last test
- Review timeout settings
- Ensure `reset_world()` is called between tests

### Screenshots not captured
- Verify `capabilities.json` shows `capabilities.screenshot: true`
- Check test uses `requires = {"screenshot"}`
- Ensure frame timing allows capture

### Assertion failures
- Check `test_output/results.json` for stack traces
- Review `test_output/artifacts/<test_id>/` for captured state
