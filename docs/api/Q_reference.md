# Q.lua Quick Reference

Single-letter import for minimal friction transform operations.

```lua
local Q = require("core.Q")
```

## Position & Movement

| Function | Description | Example |
|----------|-------------|---------|
| `Q.move(e, x, y)` | Set absolute position | `Q.move(player, 100, 200)` |
| `Q.offset(e, dx, dy)` | Move relative | `Q.offset(enemy, 10, 0)` |
| `Q.center(e)` | Get center (physics) | `local cx, cy = Q.center(e)` |
| `Q.visualCenter(e)` | Get center (rendered) | `local vx, vy = Q.visualCenter(e)` |

### Visual vs Physics Position

```lua
-- Physics (for calculations, AI, collision)
local cx, cy = Q.center(enemy)

-- Visual (for effects, popups, particles)
local vx, vy = Q.visualCenter(enemy)
```

**Use `Q.center()` for:** Physics, collision, AI pathfinding, gameplay logic

**Use `Q.visualCenter()` for:** Spawning particles, damage numbers, screen UI

## Dimensions & Bounds

| Function | Returns | Example |
|----------|---------|---------|
| `Q.size(e)` | `width, height` | `local w, h = Q.size(e)` |
| `Q.bounds(e)` | `x, y, w, h` | `local x, y, w, h = Q.bounds(e)` |
| `Q.visualBounds(e)` | `x, y, w, h` (rendered) | `local vx, vy, vw, vh = Q.visualBounds(e)` |

## Rotation

| Function | Description | Example |
|----------|-------------|---------|
| `Q.rotation(e)` | Get rotation (radians) | `local rad = Q.rotation(e)` |
| `Q.setRotation(e, rad)` | Set absolute rotation | `Q.setRotation(e, math.pi/4)` |
| `Q.rotate(e, delta)` | Rotate by delta | `Q.rotate(e, 0.1)` |

## Validation

| Function | Description | Example |
|----------|-------------|---------|
| `Q.isValid(e)` | Check if entity exists | `if Q.isValid(e) then ... end` |
| `Q.ensure(e, ctx)` | Assert valid or warn | `Q.ensure(e, "spawn_effect")` |

```lua
-- Quick validation pattern
if Q.isValid(enemy) then
    Q.move(enemy, targetX, targetY)
end

-- With context for debugging
Q.ensure(projectile, "update_projectile")  -- Logs if invalid
```

## Spatial Queries

| Function | Description | Example |
|----------|-------------|---------|
| `Q.distance(e1, e2)` | Distance between entities | `local d = Q.distance(player, enemy)` |
| `Q.distanceToPoint(e, x, y)` | Distance to point | `local d = Q.distanceToPoint(e, 100, 200)` |
| `Q.direction(e1, e2)` | Normalized direction | `local dx, dy = Q.direction(e1, e2)` |
| `Q.isInRange(e1, e2, r)` | Range check | `if Q.isInRange(player, enemy, 100) then` |

```lua
-- Check if enemy is in attack range
if Q.isInRange(player, enemy, attackRange) then
    attack(enemy)
end

-- Move toward target
local dx, dy = Q.direction(enemy, player)
Q.offset(enemy, dx * speed * dt, dy * speed * dt)
```

## Component Access

| Function | Description | Example |
|----------|-------------|---------|
| `Q.getTransform(e)` | Get Transform component | `local t = Q.getTransform(e)` |
| `Q.withTransform(e, fn)` | Execute if valid | `Q.withTransform(e, function(t) ... end)` |

```lua
-- Safe transform access
Q.withTransform(entity, function(t)
    t.actualX = t.actualX + 10
    t.actualR = math.pi / 4
end)
```

## Replaces This Boilerplate

```lua
-- OLD (4 lines)
local transform = component_cache.get(entity, Transform)
if transform then
    transform.actualX = x
    transform.actualY = y
end

-- NEW (1 line)
Q.move(entity, x, y)
```

## Common Patterns

### Spawning Effects at Entity Position
```lua
local vx, vy = Q.visualCenter(enemy)
particle.spawn("explosion", vx, vy)
popup.damage(enemy, 25)  -- Uses visualCenter internally
```

### Following Player
```lua
local dx, dy = Q.direction(enemy, player)
local dist = Q.distance(enemy, player)
if dist > 50 then
    Q.offset(enemy, dx * speed * dt, dy * speed * dt)
end
```

### Rotating Toward Target
```lua
local dx, dy = Q.direction(turret, target)
local angle = math.atan2(dy, dx)
Q.setRotation(turret, angle)
```

## See Also

- [component_cache.lua](../../assets/scripts/core/component_cache.lua) - Underlying cache
- [entity_cache.lua](../../assets/scripts/core/entity_cache.lua) - Entity validation
