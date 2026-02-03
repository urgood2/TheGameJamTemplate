# Test Infrastructure

This directory contains the Lua test harness for verifying engine patterns and documentation.

Canonical test root: `assets/scripts/test/`.

## Quick Start

```bash
# Setup toolchain (first time)
./scripts/bootstrap_dev.sh

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

TestRunner:register("physics.raycast.basic", "physics", function()
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

## Output Wipe Policy

Each run wipes `test_output/` files and regenerates:

- `status.json`, `results.json`, `report.md`, `junit.xml`, `test_manifest.json`
- `screenshots/` and `artifacts/` folders (preserving `.gitkeep`)

Baselines are stored under `test_baselines/` and are never deleted by the runner.

## UBS (Unified Build Script)

Before committing, ensure tests pass:

```bash
# Full build + test
just build-debug && just test

# Quick test only
just test
```

UBS definition for this repo: `just build-debug && just test` (build + unit tests). The pass signal is a zero exit code and the `./build/tests/unit_tests` binary output.

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
    "test_scene": true,
    "output_writable": true,
    "world_reset": true
  }
}
```

Tests requiring missing capabilities are skipped, not failed.

## Directory Structure

```
assets/scripts/test/
├── README.md              # This file
├── test_runner.lua        # Main test harness
├── test_utils.lua         # Assertion helpers
├── test_registry.lua      # doc_id to test mapping
├── run_state.lua          # Crash detection sentinel
├── test_smoke.lua          # Harness self-tests
├── test_entity_lifecycle.lua  # Entity lifecycle tests
├── test_styled_localization.lua # Localization tests
└── ...                    # Additional test modules
```

## Troubleshooting

### Tests hang indefinitely
- Check `test_output/run_state.json` for last test
- Review timeout settings
- Ensure `reset_world()` is called between tests

### Screenshots not captured
- Verify `capabilities.json` shows `screenshot_available: true`
- Check test uses `requires = {"screenshot"}`
- Ensure frame timing allows capture

### Assertion failures
- Check `test_output/results.json` for stack traces
- Review `test_output/artifacts/<test_id>/` for captured state
