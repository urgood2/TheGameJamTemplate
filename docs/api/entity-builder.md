# EntityBuilder API

Streamlined entity creation with sprites, physics, interactions, and script attachment.

## Quick Methods

```lua
local EntityBuilder = require("core.entity_builder")

-- Simple sprite entity
local entity = EntityBuilder.simple("kobold", 100, 200, 64, 64)

-- Validated script attachment (prevents data-after-attach bug)
local script = EntityBuilder.validated(MyScript, entity, { health = 100 })
```

## Full Options

```lua
local entity, script = EntityBuilder.create({
    -- Appearance
    sprite = "kobold",
    size = { 64, 64 },
    shadow = true,
    shaders = { "3d_skew_holo" },

    -- Position
    position = { x = 100, y = 200 },

    -- Script data (assigned before attach_ecs)
    data = { health = 100, faction = "enemy" },

    -- Interactivity
    interactive = {
        hover = { title = "Enemy", body = "A dangerous kobold" },
        click = function(reg, eid) print("clicked!") end,
        collision = true  -- Add collision shape
    },

    -- State visibility
    state = PLANNING_STATE,
})
```

## Options Reference

| Option | Type | Description |
|--------|------|-------------|
| `sprite` | string | Sprite ID or filename |
| `position` | table | `{ x, y }` world position |
| `size` | table | `{ width, height }` |
| `shadow` | bool | Add drop shadow |
| `data` | table | Script data (merged into script table) |
| `interactive.hover` | table | `{ title, body }` for tooltip |
| `interactive.click` | function | Click handler `fn(registry, entityId)` |
| `interactive.collision` | bool | Add collision shape |
| `state` | string | State tag (PLANNING_STATE, etc.) |
| `shaders` | table | List of shader names |

## Why `validated()`?

When extending scripts manually, data assigned after `attach_ecs()` is lost:

```lua
-- WRONG: data lost!
script:attach_ecs { ... }
script.health = 100  -- This disappears!

-- RIGHT: Use validated()
local script = EntityBuilder.validated(MyScript, entity, { health = 100 })
```

`validated()` ensures data is assigned before `attach_ecs()` is called.

## Integration with Node

```lua
local Node = require("monobehavior.behavior_script_v2")

-- Prefer Node.quick() for simple cases
local script = Node.quick(entity, { health = 100 })

-- Or Node.create() for new entities
local script = Node.create({ health = 100 })
local entity = script:handle()
```
