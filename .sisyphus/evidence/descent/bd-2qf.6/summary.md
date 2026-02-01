# bd-2qf.6: [Descent] B1 Menu entry + ENABLE_DESCENT gating

## Implementation Summary

Added conditional Descent menu entry to main menu, gated by ENABLE_DESCENT=1 environment variable.

## Files Modified

### `assets/scripts/core/main.lua`

**Changes:**
- Refactored menu button setup to build buttons array dynamically
- Added conditional Descent button insertion when `os.getenv("ENABLE_DESCENT") == "1"`
- Descent button calls `require("descent.init").start()` on click
- Telemetry tracked via `record_telemetry("descent_clicked", { scene = "main_menu" })`

**Menu Order (with flag):**
1. Start Game
2. Descent (only when ENABLE_DESCENT=1)
3. Discord
4. Bluesky
5. Language

## Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| With ENABLE_DESCENT=1, menu shows Descent | ✅ Conditional insertion |
| Entering Descent works | ✅ Calls descent.init.start() |
| Without flag, no visible/accessible route | ✅ Button not inserted |

## Usage

```bash
# Run with Descent enabled
ENABLE_DESCENT=1 ./build/raylib-cpp-cmake-template

# Run without Descent (default)
./build/raylib-cpp-cmake-template
```

## Agent

- Agent: RedEagle (claude-code/opus-4.5)
- Date: 2026-02-01
