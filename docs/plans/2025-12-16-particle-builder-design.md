# Particle Builder API Design

**Date:** 2025-12-16
**Status:** Approved

## Overview

A fluent, composable API for creating particles in Lua with minimal boilerplate. Addresses two main pain points:
1. Too many fields to specify for simple effects
2. Clunky emitter setup and attachment

## Core Concepts

| Concept | Description |
|---------|-------------|
| **Recipe** | Immutable definition of particle appearance + behaviors. Create once, reuse anywhere. |
| **Emission** | Configured spawn event (position, count, duration). Consumed on use. |
| **Handle** | Controller for streams - stop, pause, resume, destroy. |

## API Reference

### Defining Recipes

```lua
local Particles = require("core.particles")

local spark = Particles.define()
    :shape("circle")              -- circle, rect, line, sprite
    :size(4, 8)                   -- random range or fixed
    :color("orange", "red")       -- start -> end interpolation
    :lifespan(0.3, 0.5)
    :velocity(100, 200)
    :gravity(200)
    :fade()
    :shrink()
    :drag(0.95)
```

### Emission Methods

**One-shot burst:**
```lua
spark:burst(10):at(x, y)
spark:burst(10):at(x, y):spread(30)
spark:burst(5):from(a, b):toward(target)
spark:burst(20):inCircle(x, y, radius):outward()
```

**Continuous stream:**
```lua
local handle = spark:stream()
    :every(0.05)
    :for(2.0)                     -- or :times(50), :whileAlive(entity)
    :attachTo(entity, { offset = Vec2(0, -10) })

handle:stop()
handle:pause()
handle:resume()
```

### Positioning Modes

**Point-based:**
```lua
:at(x, y)                           -- spawn at exact location
:at(x, y):angle(45)                 -- aimed at 45 degrees
:at(x, y):angle(30, 60)             -- random between 30-60 degrees
:at(x, y):spread(30)                -- +/-30 degree cone
```

**Target-based:**
```lua
:from(ax, ay):toward(bx, by)        -- fly toward point
:from(ax, ay):toward(entity)        -- fly toward entity
:from(entity):toward(targetEntity)  -- entity to entity
```

**Area-based:**
```lua
:inRect(x, y, w, h)                 -- random in rectangle
:inCircle(x, y, radius)             -- random in circle
:onLine(x1, y1, x2, y2)             -- random along line
:onEdge(x, y, w, h)                 -- rectangle perimeter only
```

**Direction modifiers:**
```lua
:outward()          -- away from spawn center
:inward()           -- toward spawn center
:direction(0, -1)   -- explicit vector
:velocity(100, 200) -- explicit speed range
```

### Customization

**Override at emit time:**
```lua
spark:burst(10):at(x, y):override({ color = "blue", size = 12 })
```

**Per-particle variation:**
```lua
spark:burst(10):at(x, y):each(function(index, count)
    return { angle = (index / count) * 360 }
end)
```

**Mixed recipes:**
```lua
Particles.mix(spark, smoke, ember):burst(15):at(x, y)
Particles.mix({ spark, 5 }, { smoke, 3 }):burst(16):at(x, y)  -- weighted
```

**Lifecycle callbacks:**
```lua
Particles.define()
    :shape("circle")
    :onSpawn(function(p, entity) p.data = { custom = true } end)
    :onUpdate(function(p, dt, entity) ... end)
    :onDeath(function(p, entity) ... end)
```

### Shader Integration

**Shader-enabled particles (creates full entity):**
```lua
Particles.define()
    :shape("circle")
    :shaders({ "glow", "3d_skew_holo" })
    :fade()
```

**Custom draw command with shaders:**
```lua
Particles.define()
    :drawCommand(function(p)
        return { type = "circle", x = p.x, y = p.y, radius = p.scale * 8 }
    end)
    :shaders({ "dissolve" })
```

### Duration Control (Streams)

```lua
:for(2.0)              -- emit for 2 seconds
:times(50)             -- emit 50 particles total
:whileAlive(entity)    -- emit until entity destroyed
-- (no modifier)       -- infinite until handle:stop()
```

### Attachment Options

```lua
:attachTo(entity)
:attachTo(entity, { offset = Vec2(0, -20) })
:attachTo(entity, { inheritRotation = true })
```

## Behaviors Reference

| Method | Effect |
|--------|--------|
| `:gravity(g)` | Pull down (negative = float up) |
| `:drag(d)` | Velocity multiplier per frame |
| `:wiggle(amt)` | Random lateral jitter |
| `:spin(speed)` | Rotation speed (deg/sec) |
| `:stretch()` | Elongate based on velocity |
| `:fade()` | Alpha 1->0 |
| `:fadeIn(pct)` | Alpha 0->1->0 |
| `:shrink()` / `:grow(s,e)` | Scale over lifetime |
| `:bounce(restitution)` | Bounce off world |
| `:homing(strength)` | Curve toward target |
| `:trail(recipe, rate)` | Spawn child particles |
| `:flash(colors...)` | Cycle colors |

## Particle State in Callbacks

The `p` parameter in callbacks is a lightweight wrapper over the C++ Particle component:

```lua
:onUpdate(function(p, dt, entity)
    p.x, p.y           -- position (read/write)
    p.velocity.x       -- velocity vector (read/write)
    p.velocity.y
    p.age              -- seconds since spawn (read-only)
    p.lifespan         -- total lifetime (read-only)
    p.progress         -- age/lifespan, 0->1 (read-only)
    p.scale            -- current scale (read/write)
    p.rotation         -- current rotation degrees (read/write)
    p.alpha            -- current alpha 0-1 (read/write)
    p.color            -- current Color (read/write)
    p.data             -- custom table you attached (read/write)
end)
```

## Return Values

```lua
-- Recipes return self for chaining
local recipe = Particles.define():shape("circle"):size(6)  -- returns Recipe

-- Emission methods return Emission object
local emission = recipe:burst(10)      -- returns Emission
emission:at(x, y)                      -- returns self (Emission), triggers spawn

-- Streams return a Handle for control
local handle = recipe:stream()
    :every(0.05)
    :attachTo(entity)                  -- returns Handle

handle:stop()                          -- stop emitting
handle:pause()                         -- pause (can resume)
handle:resume()                        -- resume after pause
handle:isActive()                      -- boolean
handle:destroy()                       -- stop and clean up

-- Burst can optionally return handle
local handle = spark:burst(10):at(x, y):asHandle()
handle:isComplete()  -- true when all particles dead
```

## Architecture

```
+-----------------------------------------------------------+
|                      Lua API Layer                         |
|   Particles.define() -> Recipe -> Emission -> spawn        |
+-----------------------------+-----------------------------+
                              |
              +---------------+---------------+
              v                               v
+---------------------+       +---------------------------+
|   Native Particles  |       |    Shader Particles       |
|                     |       |                           |
| particle.CreatePart |       | particle.CreateParticle   |
| DrawParticles()     |       | + ShaderParticleTag       |
|                     |       | + ShaderBuilder           |
| (excludes tagged)   |       | + draw.local_command      |
+---------------------+       +---------------------------+
```

## Mapping to C++ Bindings

| Fluent Method | C++ Particle Field |
|---------------|-------------------|
| `:shape("circle")` | `renderType = CIRCLE_FILLED` |
| `:shape("rect")` | `renderType = RECTANGLE_FILLED` |
| `:shape("line")` | `renderType = LINE_FACING` |
| `:shape("sprite", id)` | `renderType = TEXTURE` + animConfig |
| `:size(w, h)` | `size = Vec2(w, h)` |
| `:color(start, end)` | `startColor`, `endColor` |
| `:lifespan(t)` | `lifespan = t` |
| `:gravity(g)` | `gravity = g` |
| `:velocity(min, max)` | `velocity = Vec2(...)` |
| `:spin(speed)` | `rotationSpeed = speed` |
| `:fade()` | `startColor.a = 255`, `endColor.a = 0` |
| `:shrink()` | via `onUpdateCallback` |
| `:drag(d)` | via `onUpdateCallback` |
| `:wiggle(amt)` | via `onUpdateCallback` |
| `:bounce()` | via `onUpdateCallback` |
| `:homing(t)` | via `onUpdateCallback` |
| `:stretch()` | `autoAspect = true` or `ELLIPSE_STRETCH` |
| `:trail(recipe)` | via `onUpdateCallback` |
| `:z(order)` | `z = order` |
| `:space("screen")` | `space = RenderSpace.SCREEN` |

## Avoiding Overlapping Draws

Shader-enabled particles could be drawn twice without exclusion.

**Solution:** Add `ShaderParticleTag` marker component.

```cpp
// In particle.hpp
struct ShaderParticleTag {};

// In DrawParticles
void DrawParticles(entt::registry& registry, ...) {
    auto view = registry.view<Particle, Transform>(entt::exclude<ShaderParticleTag>);
    // ... existing draw logic
}
```

**Lua creation for shader particles:**
```lua
function Emission:_spawnShaderParticle(config)
    local entity = particle.CreateParticle(
        config.position,
        config.size,
        self:_buildParticleOpts(),
        config.animConfig,
        config.tag
    )

    registry:emplace(entity, ShaderParticleTag)

    ShaderBuilder.for_entity(entity)
        :add(unpack(self._recipe._shaders))
        :apply()

    draw.local_command(entity, config.drawType, config.drawProps, {
        z = config.z
    })

    return entity
end
```

## Testing Strategy

1. **Unit tests** - Recipe config, method chaining, emission resolution
2. **Integration tests** - Mock `particle.CreateParticle`, verify params
3. **Shader integration tests** - Verify local_command routing, no double-draws
4. **Visual smoke tests** - Manual test scene

## Files to Create/Modify

| File | Purpose |
|------|---------|
| `assets/scripts/core/particles.lua` | Main API (Recipe, Emission, Handle) |
| `tests/lua/test_particle_builder.lua` | Unit + integration tests |
| `src/systems/particles/particle.hpp` | Add `ShaderParticleTag` component |
| `assets/scripts/test_scenes/particle_test.lua` | Visual test scene |

## C++ Changes Required

- Add `ShaderParticleTag` component to particle.hpp
- Modify `DrawParticles` to exclude entities with `ShaderParticleTag`
