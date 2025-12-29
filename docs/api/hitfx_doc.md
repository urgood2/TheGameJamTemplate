# Hit Effects (hitfx)

Per-entity flash effects with proper timing. Each entity's flash starts at white when triggered, regardless of when other entities were hit.

## Quick Start

```lua
local hitfx = require("core.hitfx")

-- Flash entity white for 0.2 seconds (default)
hitfx.flash(enemy)

-- Flash with custom duration
hitfx.flash(enemy, 0.5)

-- Get cancel function for early stopping
local cancel = hitfx.flash(enemy, 0.5)
-- Later:
cancel()
```

## API Reference

### hitfx.flash(entity, duration?)

Flash an entity with a white overlay that fades over time.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| entity | number | required | Entity ID to flash |
| duration | number | 0.2 | Duration in seconds |

**Returns:** `function` - Cancel function to stop flash early

**Example:**
```lua
-- On enemy hit
local function onEnemyHit(enemy, damage)
    hitfx.flash(enemy, 0.15)
    popup.damage(enemy, damage)
end
```

### hitfx.flash_start(entity)

Start an indefinite flash that must be manually stopped.

| Parameter | Type | Description |
|-----------|------|-------------|
| entity | number | Entity ID to flash |

**Returns:** `function` - Cancel function to stop flash

**Example:**
```lua
-- Flash while charging attack
local stopFlash = hitfx.flash_start(player)
timer.after(2.0, function()
    stopFlash()
    releaseAttack()
end)
```

### hitfx.flash_stop(entity)

Stop any active flash on an entity.

| Parameter | Type | Description |
|-----------|------|-------------|
| entity | number | Entity ID to stop flashing |

## How It Works

1. Ensures `ShaderPipelineComponent` exists on entity
2. Adds "flash" shader pass
3. Sets `flashStartTime` uniform to current time
4. Schedules removal of flash pass after duration

## Dependencies

- `shaders.ShaderUniformComponent` - Per-entity shader uniforms
- `shader_pipeline.ShaderPipelineComponent` - Shader pass management
- `core.timer` - Scheduled removal

## See Also

- [Shader Pipeline](shader_draw_commands_doc.md) - Shader system overview
- [popup.lua](../../CLAUDE.md#popup-helpers) - Damage/heal number popups
