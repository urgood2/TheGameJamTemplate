# bd-2qf.70: [Descent] S9 Entity rendering layer

## Implementation Summary

### File Created

**`assets/scripts/descent/render.lua`** (350+ lines)

#### Features

1. **Entity Rendering**
   - Player at current position
   - Enemies (visible only, not in explored-only tiles)
   - Ground items
   - Features (stairs, shops, altars)

2. **Visibility Distinction**
   - Visible tiles: full color
   - Explored tiles: dimmed (50% color, 180 alpha)
   - Unseen tiles: black

3. **Priority System**
   - Player: priority 100
   - Enemies: priority 50
   - Items: priority 10
   - Features: priority 5
   - Highest priority entity renders on top

#### Key Functions

```lua
M.init(game_state)           -- Initialize with state
M.get_tile_render(x, y)      -- Get render info for tile
M.build_render_grid()        -- Build full map grid
M.draw(offset_x, offset_y)   -- Render map
M.to_string()                -- ASCII representation
M.get_visible_enemies()      -- List visible enemies
M.get_visible_items()        -- List visible items
```

#### Render Info

Each tile returns:
- `char`: Display character
- `color`: RGBA color table
- `visible`: Currently in FOV
- `explored`: Ever been seen
- `entity`: Entity at position (if any)

### Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Player renders | OK @ symbol |
| Enemies render | OK with visibility check |
| Items render | OK visible/explored |
| Visible vs explored | OK dimming system |
| Uses existing system | OK integrates with fov |

## Agent

- **Agent**: BoldMountain
- **Date**: 2026-02-01
