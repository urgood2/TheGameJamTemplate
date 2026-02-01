# Unified Lua API Reference

> Auto-generated from binding definitions and api.lua module

**Last updated:** 2025-12-19


## Core API (from api.lua)

See `assets/scripts/core/api.lua` for the authoritative documentation table.

Key modules:
- `registry` - ECS entity management
- `component_cache` - Cached component access
- `physics` - Physics world and collision
- `timer` - Timer and sequence API
- `signal` - Event pub/sub system
- `draw` - Drawing commands

## Builder APIs

### EntityBuilder

```lua
local EntityBuilder = require('core.entity_builder')

-- Full options
local entity, script = EntityBuilder.create({
    sprite = 'kobold',
    position = { x = 100, y = 200 },
    size = { 64, 64 },
    shadow = true,
    data = { health = 100 },
})

-- Simple creation
local entity = EntityBuilder.simple('sprite', x, y, w, h)

-- Validated (prevents data-after-attach bug)
local script = EntityBuilder.validated(MyScript, entity, { health = 100 })
```

### PhysicsBuilder

```lua
local PhysicsBuilder = require('core.physics_builder')

PhysicsBuilder.for_entity(entity)
    :circle()
    :tag('projectile')
    :bullet()
    :collideWith({ 'enemy', 'WORLD' })
    :apply()
```

### ShaderBuilder

```lua
local ShaderBuilder = require('core.shader_builder')

ShaderBuilder.for_entity(entity)
    :add('3d_skew_holo', { sheen_strength = 1.5 })
    :add('dissolve', { dissolve = 0.5 })
    :apply()
```


## Quick Helpers (Q.lua)

```lua
local Q = require('core.Q')

Q.move(entity, x, y)       -- Move to absolute position
Q.offset(entity, dx, dy)   -- Move relative
local cx, cy = Q.center(entity)  -- Get center point
```


## Timer API

```lua
local timer = require('core.timer')

-- One-shot
timer.after(2.0, function() print('done') end, 'my_tag')

-- Repeating
timer.every(0.5, function() print('tick') end, 'heartbeat')

-- Sequence
timer.sequence('anim')
    :wait(0.5)
    :do_now(function() print('start') end)
    :wait(0.3)
    :do_now(function() print('end') end)
    :start()

-- Cancel
timer.cancel('my_tag')
```


## Event System (Signal)

```lua
local signal = require('external.hump.signal')

-- Emit event
signal.emit('player_damaged', player_entity, { damage = 25, type = 'fire' })

-- Register handler
signal.register('player_damaged', function(entity, data)
    log_debug('Player took', data.damage, data.type, 'damage')
end)
```


## Common Patterns

### Safe Entity Access

```lua
if ensure_entity(eid) then
    local script = safe_script_get(eid)
    local health = script_field(eid, 'health', 100)  -- with default
end
```

### Component Cache

```lua
local transform = component_cache.get(entity, Transform)
if transform then
    transform.actualX = 100
end
```


## Performance Settings

```lua
-- Enable shader/texture batching (reduces GPU state changes)
set_shader_texture_batching(true)

-- Check current state
local enabled = get_shader_texture_batching()
```


## See Also

- `CLAUDE.md` - Quick reference and patterns
- `docs/api/` - Individual API documentation files
- `docs/content-creation/` - Content creation guides
- `assets/scripts/core/api.lua` - Full API documentation table

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
