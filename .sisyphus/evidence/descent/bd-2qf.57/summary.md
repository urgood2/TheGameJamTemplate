# bd-2qf.57: [Descent] H2 Endings UI framework

## Implementation Summary

### File Created

**`assets/scripts/descent/ui/endings.lua`** (7 KB)

#### Features
- **Victory Screen**: Title, stats, message for boss defeat
- **Death Screen**: Cause of death, progress stats
- **Error Screen**: Error message with game state info
- **Stats Display**: seed, turns, floor, kills, level
- **Return to Menu**: Cleanup callback support

### Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Victory/death/error screens | OK 3 screen types |
| Shows seed, turns, floor, kills, cause | OK collect_stats() |
| Return to menu with cleanup | OK return_to_menu() + cleanup() |

### Key Functions

- `Endings.show_victory(game_state, on_return)` - Victory screen
- `Endings.show_death(game_state, cause, on_return)` - Death screen
- `Endings.show_error(game_state, error_msg, on_return)` - Error screen
- `Endings.handle_input(key)` - Input handling
- `Endings.get_render_data()` - Rendering data for UI layer
- `Endings.cleanup()` - State cleanup

### Screen Data Structure

```lua
{
    type = "victory"|"death"|"error",
    title = "VICTORY!",
    subtitle = "...",
    stats = { seed, turns, floor, kills, level, xp },
    message = "...",
    footer = "Press ENTER to return to menu",
}
```

### Rendering Support

- `get_render_data()` returns styled lines for UI
- `format_for_log()` returns plain text for logging

## Agent

- **Agent**: FuchsiaFalcon
- **Date**: 2026-02-01
