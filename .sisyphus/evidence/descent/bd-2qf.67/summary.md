# bd-2qf.67: [Descent] S6 HUD floor/turn/position display

## Implementation Summary

### File Verified

**`assets/scripts/descent/ui/hud.lua`** (264 lines)

#### Required HUD Elements (lines 186-192)

```lua
table.insert(lines, { "Seed", tostring(_state.seed or "?") })
table.insert(lines, { "Floor", tostring(_state.floor or 1) })
table.insert(lines, { "Turn", tostring(_state.turn or 0) })
table.insert(lines, { "Pos", format_pos(_state.pos) })
```

#### Always Visible

- `_visible = true` is the default
- Visibility can be toggled but defaults to showing

#### Additional Fields

- HP/HP_max
- MP/MP_max
- Gold
- Level/XP

### Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Floor number | OK shown |
| Turn count | OK shown |
| Player position | OK shown as "x,y" |
| Always visible | OK default true |

## Agent

- **Agent**: BoldMountain
- **Date**: 2026-02-01
