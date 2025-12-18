# Text Builder API

The Text Builder provides a particle-style API for game text with three layers: Recipe (immutable definition), Spawner (position configuration), and Handle (lifecycle control).

## Quick Start

```lua
local Text = require("core.text")

-- Define a reusable damage number recipe
local damageRecipe = Text.define()
    :content("[%d](color=red;pop=0.2)")
    :size(20)
    :fade()
    :lifespan(0.8)

-- Fire-and-forget: spawn at position
damageRecipe:spawn(25):at(enemy.x, enemy.y)

-- Spawn relative to entity
damageRecipe:spawn(50):above(enemy, 10)

-- Persistent text with following
local hpText = Text.define()
    :content(function() return "HP: " .. player.hp end)
    :size(14)
    :spawn()
    :above(player, 40)
    :follow()
    :attachTo(player)

-- REQUIRED: Update in game loop
function update(dt)
    Text.update(dt)
end
```

## Recipe Configuration Methods

| Method | Description |
|--------|-------------|
| `:content(str\|fn)` | Template string (`"[%d](red)"`) or callback function |
| `:size(n)` | Font size in pixels |
| `:color(name)` | Base color name or Color object |
| `:effects(str)` | Default effects for all characters (e.g., `"shake=2;float"`) |
| `:fade()` | Enable alpha fade over lifespan |
| `:fadeIn(pct)` | Fade-in percentage (0-1) |
| `:lifespan(n)` | Auto-destroy after N seconds |
| `:lifespan(min, max)` | Random lifespan range |
| `:width(n)` | Wrap width for multi-line text |
| `:anchor(mode)` | `"center"` or `"topleft"` |
| `:align(mode)` | `"left"`, `"center"`, `"right"`, `"justify"` |
| `:layer(obj)` | Render layer object |
| `:z(n)` | Z-index for draw order |
| `:space(name)` | `"screen"` or `"world"` |
| `:font(obj)` | Custom font object |

## Spawner Methods

| Method | Description |
|--------|-------------|
| `:spawn(value?)` | Create spawner (value for template substitution) |
| `:at(x, y)` | Absolute position (triggers spawn) |
| `:above(entity, offset?)` | Position above entity (triggers spawn) |
| `:below(entity, offset?)` | Position below entity (triggers spawn) |
| `:center(entity)` | Position at entity center (triggers spawn) |
| `:left(entity, offset?)` | Position left of entity (triggers spawn) |
| `:right(entity, offset?)` | Position right of entity (triggers spawn) |
| `:follow()` | Keep following entity position |
| `:attachTo(entity)` | Text dies when entity dies |
| `:tag(name)` | Tag for bulk operations |
| `:stream()` | Deferred spawn (set position later with handle:at()) |
| `:asEntity()` | Enable entity mode (creates ECS entity) |
| `:withShaders(list)` | Set shaders for entity mode |
| `:richEffects()` | Enable per-character effects (entity mode, expensive) |

## Handle Methods

| Method | Description |
|--------|-------------|
| `:setText(value)` | Update with template substitution |
| `:setContent(str)` | Replace entire content string |
| `:moveTo(x, y)` | Move to absolute position |
| `:moveBy(dx, dy)` | Move by relative offset |
| `:getPosition()` | Get current position `{ x, y }` |
| `:at(x, y)` | Set position (for streamed handles) |
| `:stop()` | Stop and remove text |
| `:isActive()` | Check if alive |
| `:follow()` | Enable following (can be called after spawn) |
| `:attachTo(entity)` | Attach lifecycle (can be called after spawn) |
| `:tag(name)` | Tag handle (can be called after spawn) |
| `:getEntity()` | Get ECS entity ID (only valid if `:asEntity()` used) |

## Module-Level Functions

| Function | Description |
|----------|-------------|
| `Text.update(dt)` | Update all text (call each frame, REQUIRED) |
| `Text.stopAll()` | Remove all active text |
| `Text.stopByTag(tag)` | Remove all text with specific tag |
| `Text.getActiveCount()` | Get count of active text handles |
| `Text.getActiveHandles()` | Get copy of active handles list (debugging) |

## Common Patterns

### Fire-and-Forget Damage Numbers

```lua
local damageRecipe = Text.define()
    :content("[%d](color=red;pop=0.2)")
    :size(20)
    :fade()
    :lifespan(0.8)

-- On enemy hit
damageRecipe:spawn(damage):above(enemy, 10)
```

### Persistent HP Bar Following Entity

```lua
local playerHP = 100

local hpRecipe = Text.define()
    :content(function() return "HP: " .. playerHP end)
    :size(14)
    :anchor("center")

local hpHandle = hpRecipe:spawn()
    :above(player, 40)
    :follow()
    :attachTo(player)

-- Update HP and text
playerHP = 75
hpHandle:setText()  -- Re-evaluates callback
```

### Tagged Combat Text with Bulk Cleanup

```lua
local combatRecipe = Text.define()
    :content("[%s](shake=1)")
    :size(16)
    :lifespan(1.5)

-- Spawn tagged combat messages
combatRecipe:spawn("CRITICAL!"):above(enemy, 20):tag("combat")
combatRecipe:spawn("MISS"):above(enemy, 25):tag("combat")

-- Clean up all combat text when battle ends
Text.stopByTag("combat")
```

### Stream Mode (Deferred Positioning)

```lua
local recipe = Text.define():content("Delayed"):width(100)

-- Create handle without spawning
local handle = recipe:spawn():stream()

-- Set position later (adds to active list)
timer.after(1.0, function()
    handle:at(100, 200)
end)
```

### Lifecycle Binding

```lua
-- Text dies with entity
local hpBar = Text.define()
    :content(function() return "HP: " .. entity.hp end)
    :spawn()
    :above(entity, 30)
    :attachTo(entity)  -- Auto-removed when entity dies

-- Text follows entity continuously
local nameTag = Text.define()
    :content("Enemy")
    :spawn()
    :above(entity, 40)
    :follow()  -- Updates position every frame

-- Combined: Follow + Attach
local statusText = Text.define()
    :content(function() return entity.status end)
    :spawn()
    :above(entity, 35)
    :follow()          -- Keep position updated
    :attachTo(entity)  -- Die with entity
```

## Best Practices

1. **Always call Text.update(dt)** in your game loop - text won't animate or expire without it
2. **Use :attachTo() for entity-bound text** to prevent memory leaks when entities die
3. **Use tags for bulk cleanup** of related text (e.g., all combat text, all tutorial text)
4. **Prefer recipes over one-offs** to reuse common text styles
5. **Use callbacks for dynamic content** that changes frequently (HP, status effects)
6. **Use :follow() sparingly** - position updates every frame can be expensive
7. **Clean up on state transitions** with `Text.stopAll()` or `Text.stopByTag()`
