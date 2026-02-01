# bd-2qf.63: [Descent] S2 Error handling + routing

## Implementation Summary

Added error boundary and graceful error handling to descent/init.lua.

## Files Modified

### `assets/scripts/descent/init.lua`

**Error Handling API:**
- `handle_error(err, context)` - Central error handler
- `pcall(fn, context)` - Protected call wrapper
- `show_error_screen(message)` - Route to error UI
- `get_last_error()` - Query last error
- `clear_error()` - Clear error state

**Error State:**
- `_last_error`: message, seed, timestamp, traceback

**Behavior:**
- Test mode (`RUN_DESCENT_TESTS=1`): exits 1 with seed+error
- Normal mode: routes to error ending screen
- Fallback: stops and returns to menu

**Protected Initialization:**
- State module init wrapped in pcall
- RNG init wrapped in pcall
- Errors logged with context

## Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Error boundary in init | ✅ handle_error() |
| Route to error screen | ✅ show_error_screen() |
| Test mode exits 1 | ✅ os.exit(1) with info |
| Graceful handling | ✅ pcall wrapper |

## Usage

```lua
local descent = require("descent.init")

-- Protected operation
local ok, result = descent.pcall(function()
    -- risky code
end, "my_operation")

if not ok then
    -- Error already handled, logged, and routed
end

-- Manual error
descent.handle_error("Something went wrong", "combat")
```

## Agent

- Agent: RedEagle (claude-code/opus-4.5)
- Date: 2026-02-01
