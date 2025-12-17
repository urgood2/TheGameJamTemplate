# TextBuilder Design

A fluent API for text rendering that matches the Particle Builder pattern.

## Overview

TextBuilder provides a three-layer architecture for game text:
- **Recipe**: Immutable definition (what text looks like)
- **Spawner**: Position configuration (where/when to show)
- **Handle**: Lifecycle controller (for persistent text)

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Primary use case | All three (damage numbers, entity labels, UI effects) | Need both fire-and-forget and persistent modes |
| Entity integration | Opt-in via `:asEntity()` | Lightweight by default, entity when needed for shaders |
| Position/following | Offset-based helpers (`:above()`, `:below()`) | Ergonomic for game text patterns |
| Content/templating | Hybrid (printf, literal, callback) | Flexibility for all use cases |
| Lifecycle/cleanup | All three (lifespan, entity-tied, manual) | Matches particle pattern |
| Effects integration | Wrap CommandBufferText | Reuse 50+ existing effects |
| Update mechanism | Global `Text.update(dt)` | Fire-and-forget becomes truly fire-and-forget |
| Entity mode rendering | User choice (simple vs rich) | Simple for shader compat, rich for effects |

## Architecture

```
Text.define()              -->   Recipe (immutable)
    :content(template)           - Visual definition
    :size(24)                    - Stores config only
    :color("red")                - Reusable across spawns
    :effects("shake")
    :lifespan(1.0)
    :fade()

recipe:spawn(value)        -->   Spawner (position config)
    :at(x, y)                    - WHERE to put text
    :above(entity, offset)       - Creates Handle on trigger
    :attachTo(entity)

spawner triggers           -->   Handle (lifecycle)
(via :at/:above/:stream)         - Wraps CommandBufferText
    handle:setText(new)          - Registered in global list
    handle:stop()                - Auto-updated each frame

Text.update(dt)            -->   Updates ALL active handles
                                 - Position following
                                 - Effect animation
                                 - Lifespan/cleanup
```

## Recipe API

```lua
local Text = require("core.text")

local recipe = Text.define()

-- CONTENT (what to render)
    :content("[%d](color=red)")       -- Printf template with effects
    :content("Literal string")         -- Or plain string
    :content(function()                -- Or callback for live updates
        return "HP: " .. player.hp
    end)

-- APPEARANCE
    :size(24)                          -- Font size (default: 16)
    :color("white")                    -- Base color (default: white)
    :font(customFont)                  -- Custom font (default: localization.getFont())

-- EFFECTS (applied to all characters)
    :effects("shake=2;float")          -- Default effects for entire text
    :fade()                            -- Alpha fade over lifespan (1->0)
    :fadeIn(0.2)                       -- Fade in first, then out

-- LIFECYCLE
    :lifespan(1.0)                     -- Auto-destroy after N seconds
    :lifespan(0.5, 1.0)                -- Random range

-- LAYOUT
    :width(200)                        -- Wrap width (required for multi-line)
    :anchor("center")                  -- "center" | "topleft" (default: center)
    :align("left")                     -- "left" | "center" | "right" | "justify"

-- RENDERING
    :layer(layers.ui)                  -- Which layer (default: layers.ui)
    :z(100)                            -- Z-index (default: 0)
    :space("screen")                   -- "screen" | "world" (default: screen)
```

## Spawner API

```lua
-- Start spawning by calling :spawn() on a recipe
local spawner = recipe:spawn(value)    -- value for %d/%s template
local spawner = recipe:spawn()         -- no value (literal or callback content)

-- ABSOLUTE POSITIONING (triggers immediately)
    :at(x, y)                          -- Spawn at exact position -> returns Handle

-- ENTITY-RELATIVE POSITIONING (triggers immediately)
    :above(entity, offset)             -- Center above entity, offset px up
    :below(entity, offset)             -- Center below entity
    :left(entity, offset)              -- Left of entity
    :right(entity, offset)             -- Right of entity
    :center(entity)                    -- Centered on entity

-- FOLLOWING (persists after spawn)
    :follow()                          -- Keep updating position relative to entity

-- LIFECYCLE BINDING
    :attachTo(entity)                  -- Destroy text when entity dies

-- ENTITY MODE (opt-in)
    :asEntity()                        -- Create real ECS entity with Transform

-- STREAM MODE (for persistent text)
    :stream()                          -- Don't trigger yet, return Handle for control
```

## Handle API

```lua
local handle = recipe:spawn(value):at(x, y)

-- CONTENT UPDATES
    handle:setText(newValue)           -- Update content (re-applies template)
    handle:setContent("[new](effect)") -- Replace entire content string

-- POSITION UPDATES (for non-following text)
    handle:moveTo(x, y)                -- Absolute reposition
    handle:moveBy(dx, dy)              -- Relative offset

-- LIFECYCLE
    handle:stop()                      -- Remove text immediately
    handle:isActive()                  -- Check if still alive -> boolean

-- STATE QUERIES
    handle:getPosition()               -- -> { x, y }
    handle:getSize()                   -- -> { w, h } (text bounds)
    handle:getEntity()                 -- -> entity ID (only if :asEntity() was used)
```

## Module API

```lua
local Text = require("core.text")

-- RECIPE CREATION
Text.define()                          -- Create new recipe -> Recipe

-- GLOBAL UPDATE (call once per frame in game loop)
Text.update(dt)                        -- Updates ALL active handles

-- BULK OPERATIONS
Text.stopAll()                         -- Remove all active text
Text.stopByTag(tag)                    -- Remove text with specific tag

-- INTROSPECTION (for debugging/tooling)
Text.getActiveCount()                  -- -> number of active handles
Text.getActiveHandles()                -- -> copy of handles list (read-only)
```

## Entity Mode & Shader Integration

```lua
-- Default: Text is NOT an entity (lightweight)
recipe:spawn("Hello"):at(100, 200)

-- Opt-in: Create real ECS entity
local handle = recipe:spawn("Hello")
    :at(100, 200)
    :asEntity()
    :withShaders({ "3d_skew_holo" })

-- Entity mode rendering options:
-- DEFAULT: Simple text (single local command, shader-compatible)
:asEntity():withShaders({ "3d_skew" })

-- OPT-IN: Per-character effects (expensive but full effects)
:asEntity():withShaders({ "3d_skew" }):richEffects()
```

### Shader Rendering Implementation

Entity mode uses `draw.local_command()` with the `"shaded_text"` preset:
- `textPass = true` for proper 3d_skew UV handling
- `uvPassthrough = true` for correct texture coordinates
- Coordinates are LOCAL to entity transform

Simple mode: Single `draw.local_command("text_pro", ...)` call.
Rich mode: Per-character `draw.local_command("text_pro", ...)` calls with effect transforms.

## Usage Examples

### Damage Numbers (fire-and-forget)

```lua
local damageRecipe = Text.define()
    :content("[%d](color=red;pop=0.2)")
    :size(20)
    :fade()
    :lifespan(0.8)
    :effects("rise=40")

function onDamageDealt(target, amount)
    damageRecipe:spawn(amount):above(target, 10)
end
```

### HP Bar (persistent, following)

```lua
local hpRecipe = Text.define()
    :content(function() return "HP: " .. player.hp end)
    :size(14)
    :color("white")
    :anchor("center")

local hpText = hpRecipe:spawn()
    :above(player, 40)
    :follow()
    :attachTo(player)
```

### Boss Introduction (timed announcement)

```lua
local bossIntro = Text.define()
    :size(48)
    :color("gold")
    :anchor("center")
    :lifespan(3.0)
    :fade()
    :fadeIn(0.3)

bossIntro:spawn("[DRAGON LORD](slam=0.5;shimmer)")
    :at(globals.screenWidth() / 2, globals.screenHeight() / 3)
```

### Card Label with Shader (entity mode)

```lua
local cardLabel = Text.define()
    :content("%s")
    :size(20)
    :color("white")
    :anchor("topleft")

cardLabel:spawn("FIREBALL")
    :at(cardTransform.actualX + 10, cardTransform.actualY + 10)
    :asEntity()
    :withShaders({ "3d_skew_holo" })
    :attachTo(cardEntity)
```

### Bulk Cleanup with Tags

```lua
damageRecipe:spawn(25):above(enemy1, 10):tag("combat")
damageRecipe:spawn(50):above(enemy2, 10):tag("combat")

Text.stopByTag("combat")
```

### Game Loop Integration

```lua
function update(dt)
    -- ... other game updates ...
    Text.update(dt)
end
```

## File Location

`assets/scripts/core/text.lua`

## Dependencies

- `ui.command_buffer_text` (CommandBufferText for effect rendering)
- `core.draw` (for entity mode local commands)
- `core.shader_builder` (for entity mode shader setup)
- `core.entity_cache` (for entity validation)
- `core.component_cache` (for Transform access)
