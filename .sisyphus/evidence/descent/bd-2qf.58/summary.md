# bd-2qf.58: [Descent] H2-V Victory screen

## Implementation Summary

### File Reference

**`assets/scripts/descent/ui/endings.lua`** (from bd-2qf.57)

#### Victory Screen Features
- **Title**: "VICTORY!" with "You have defeated The Guardian!"
- **Stats Display**: seed, floor, turns, kills, level, XP
- **Message**: Summary of achievement
- **Return to Menu**: Press ENTER with cleanup callback

### Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Shows win stats | OK collect_stats() gathers all stats |
| Shows seed | OK stats.seed included |
| Option to return to menu | OK handle_input() + return_to_menu() |

### Victory Screen Data

```lua
{
    type = "victory",
    title = "VICTORY!",
    subtitle = "You have defeated The Guardian!",
    stats = {
        seed = "...",
        floor = 5,
        turns = 123,
        kills = 45,
        level = 5,
        xp = 500,
    },
    message = "After X turns and Y kills...",
    footer = "Press ENTER to return to menu",
}
```

### Usage

```lua
local endings = require("descent.ui.endings")

-- On boss defeat:
endings.show_victory(game_state, function()
    -- Return to main menu
    game:switch_state("menu")
end)
```

### Rendering

`get_render_data()` returns styled lines for ImGui integration.

## Agent

- **Agent**: FuchsiaFalcon
- **Date**: 2026-02-01
