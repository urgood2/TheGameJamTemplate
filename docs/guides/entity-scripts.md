# Lua Entity Script Table Pattern

Scripts in this engine follow a specific initialization pattern. Getting this wrong causes data loss bugs.

## Critical Rule

**Data must be assigned BEFORE `attach_ecs()`!**

```lua
local Node = require("monobehavior.behavior_script_v2")

local entity = registry:create()
local EntityType = Node:extend()
local script = EntityType {}

-- Assign data FIRST
script.customData = { foo = "bar" }
script.someValue = 42

-- Call attach_ecs LAST
script:attach_ecs { create_new = false, existing_entity = entity }

-- Use script variable directly (don't call getScriptTableFromEntityID immediately)
```

**Why:** `getScriptTableFromEntityID()` returns nil without proper initialization. Data assigned after `attach_ecs()` is lost.

## Safer Alternatives: Node.quick() and Node.create()

Use factory methods to prevent initialization bugs:

```lua
local Node = require("monobehavior.behavior_script_v2")

-- For existing entity: assigns data BEFORE attach_ecs
local script = Node.quick(entity, { health = 100, damage = 10 })

-- For new entity: creates entity and attaches script
local script = Node.create({ health = 100, damage = 10 })
local entity = script:handle()

-- With extended class
local EntityType = Node:extend()
local script = EntityType.quick(entity, { customData = { foo = "bar" } })
```

**Benefits:**
- Guarantees correct initialization order
- Cleaner syntax than manual attach_ecs
- Works with both base Node and extended classes

## State Management

Use `script:setState()` instead of manual state tag manipulation:

```lua
-- Instead of:
clear_state_tags(entity)
add_state_tag(entity, PLANNING_STATE)

-- Use:
script:setState(PLANNING_STATE)
```

## Entity Links (Horizontal Dependencies)

Use `script:linkTo()` for "die when target dies" behavior:

```lua
local projectile = spawn.projectile("fireball", x, y, angle)
projectile:linkTo(owner)  -- Projectile dies when owner dies
```

Or use EntityLinks directly:

```lua
local EntityLinks = require("core.entity_links")
EntityLinks.link(projectile, owner)
EntityLinks.unlink(projectile, owner)
EntityLinks.unlinkAll(projectile)
```

## Game Phase Visibility (State Tags)

Entities are rendered conditionally based on active game states.

**Available state constants** (defined in `gameplay.lua`):

| Constant | Value | Phase |
|----------|-------|-------|
| `PLANNING_STATE` | `"PLANNING"` | Card arrangement phase |
| `ACTION_STATE` | `"ACTION"` | Combat/survivors phase |
| `SHOP_STATE` | `"SHOP"` | Shop between rounds |

### For Regular Entities

```lua
-- WRONG: Entity won't respect game phase visibility
add_state_tag(entity, "default_state")

-- CORRECT: Entity visible only during planning phase
add_state_tag(entity, PLANNING_STATE)

-- Check active state
if is_state_active and is_state_active(PLANNING_STATE) then
    -- Currently in planning phase
end
```

### For DSL UI Boxes

Use UI-specific functions (NOT `add_state_tag`):

```lua
-- Add a state tag (box visible when ANY assigned state is active)
ui.box.AddStateTagToUIBox(entity, PLANNING_STATE)

-- Assign state tag (replaces existing - box visible ONLY in this state)
ui.box.AssignStateTagsToUIBox(entity, PLANNING_STATE)

-- For proper z-ordering with cards
ui.box.set_draw_layer(entity, "sprites")
```

### Complete Example

```lua
local dsl = require("ui.ui_syntax_sugar")

local markerDef = dsl.hbox {
    config = { padding = 4, minWidth = 48, minHeight = 32 },
    children = { dsl.anim("my-sprite.png", { w = 48, h = 32 }) }
}

local entity = dsl.spawn({ x = 100, y = 200 }, markerDef, "ui", z_orders.ui_tooltips + 100)

-- Set draw layer for proper z-ordering
ui.box.set_draw_layer(entity, "sprites")

-- Make visible only during PLANNING phase
ui.box.AssignStateTagsToUIBox(entity, PLANNING_STATE)

-- CRITICAL: Remove default state tag so visibility works!
remove_default_state_tag(entity)
```

## Screen-Space Animated Sprites

Animated sprites in screen-space need special handling:

```lua
-- Create screen-space sprite
local entity = animation_system.createAnimatedObjectWithTransform(sprite, true, x, y, nil, true)
transform.set_space(entity, "screen")

-- CRITICAL: Enable legacy pipeline for automatic rendering
local animComp = component_cache.get(entity, AnimationQueueComponent)
if animComp then
    animComp.drawWithLegacyPipeline = true
end

-- Set phase visibility
remove_default_state_tag(entity)
add_state_tag(entity, PLANNING_STATE)
```

**Without `drawWithLegacyPipeline = true`**, screen-space animated sprites won't render. UI boxes don't need this - they render through the UI system.

## See Also

- [EntityBuilder API](../api/entity-builder.md)
- [ChildBuilder API](../api/child-builder.md)
- [UI DSL Reference](../api/ui-dsl-reference.md)

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
