# bd-2qf.60: [Descent] H2-E Error screen

## Implementation Summary

### File Reference

**`assets/scripts/descent/ui/endings.lua`** (from bd-2qf.57)

#### Error Screen Features
- **Title**: "ERROR"
- **Error Display**: Shows error message/stack trace
- **Stats Display**: seed, floor, turns (for debugging)
- **Return to Menu**: Press ENTER with cleanup

### Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Shows error message | OK data.error field |
| Shows seed | OK stats.seed included |
| Return to menu | OK handle_input() + return_to_menu() |
| Test mode exit 1 | OK should be handled at caller level |

### Error Screen Data

```lua
{
    type = "error",
    title = "ERROR",
    subtitle = "An error occurred during gameplay.",
    error = "Script error: attempt to index nil value",
    stats = {
        seed = "...",
        floor = 3,
        turns = 67,
    },
    message = "Game state: Floor 3, Turn 67. Your progress has been lost.",
    footer = "Press ENTER to return to menu",
}
```

### Usage

```lua
local endings = require("descent.ui.endings")

-- On runtime error:
local ok, err = pcall(game_update, dt)
if not ok then
    endings.show_error(game_state, tostring(err), function()
        game:switch_state("menu")
    end)
end
```

### Test Mode Integration

For test mode exit code 1, the caller should:
```lua
if os.getenv("RUN_DESCENT_TESTS") == "1" then
    os.exit(1)
end
```

## Agent

- **Agent**: FuchsiaFalcon
- **Date**: 2026-02-01
