# Projectile Spawning & Management System

## Overview

A complete projectile system for the Lua/C++ game engine (Raylib + EnTT + Chipmunk2D physics). This system provides a data-driven, extensible framework for spawning and managing projectiles with various movement patterns, collision behaviors, and lifecycle management.

## Architecture

### Core Components

The system uses three main components attached to projectile entities:

1. **ProjectileData** - Stores damage, owner, piercing state, modifiers
2. **ProjectileBehavior** - Defines movement pattern and collision behavior
3. **ProjectileLifetime** - Manages despawn conditions

### System Design

```
┌─────────────────────────────────────────────────────────────┐
│                   Projectile System                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │ Spawning API │───▶│ Update Loop  │───▶│ Destruction  │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│         │                    │                    │          │
│         │                    │                    │          │
│         ▼                    ▼                    ▼          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │  Physics     │    │  Movement    │    │  Pooling     │  │
│  │  Integration │    │  Patterns    │    │  System      │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│         │                    │                    │          │
│         └────────────┬───────┴────────────────────┘          │
│                      ▼                                        │
│            ┌──────────────────┐                              │
│            │ Collision System │                              │
│            └──────────────────┘                              │
│                      │                                        │
│                      ▼                                        │
│            ┌──────────────────┐                              │
│            │ Combat System    │                              │
│            │ (Damage Apply)   │                              │
│            └──────────────────┘                              │
└─────────────────────────────────────────────────────────────┘
```

## Features

### Movement Patterns

- **Straight Line** - Basic directional movement
- **Homing** - Tracks and follows a target entity
- **Orbital** - Circles around a center point
- **Arc/Gravity** - Affected by gravity (grenade-style)
- **Custom** - User-defined update function for complex patterns

### Collision Behaviors

- **Destroy** - Despawn on first hit
- **Pierce** - Pass through N enemies before despawning
- **Bounce** - Ricochet off surfaces with dampening
- **Explode** - Deal AoE damage on impact
- **Pass-Through** - Deal damage but don't collide

### Lifetime Management

- **Time-based** - Despawn after X seconds
- **Distance-based** - Despawn after traveling X units
- **Hit-count based** - Despawn after hitting N entities

### Integration Points

- **Physics System** (Chipmunk2D) - Collision detection and resolution
- **Combat System** - Damage application
- **Event System** - Emit events for wand system subscriptions
- **Modifier System** - Apply card-based modifications (speed, damage, size)
- **Entity Pooling** - Performance optimization for frequent spawning

## Usage Guide

### Basic Setup

```lua
local ProjectileSystem = require("combat.projectile_system")

-- Initialize the system (call once during game init)
ProjectileSystem.init()

-- In your game update loop
function update(dt)
    ProjectileSystem.update(dt)
    -- ... other game logic
end

-- Cleanup (call when exiting game state)
function cleanup()
    ProjectileSystem.cleanup()
end
```

### Simple Projectile Spawning

```lua
-- Spawn a basic projectile
local projectile = ProjectileSystem.spawnBasic(
    playerX, playerY,  -- position
    angle,             -- direction (radians)
    400,               -- speed (pixels/second)
    25,                -- damage
    playerEntity       -- owner entity
)
```

### Advanced Spawning

```lua
local projectile = ProjectileSystem.spawn({
    -- Position & Direction
    position = {x = 100, y = 200},
    angle = math.pi / 4,  -- or use 'direction' or 'velocity'

    -- Movement Type
    movementType = ProjectileSystem.MovementType.STRAIGHT,
    baseSpeed = 300,

    -- Damage
    damage = 35,
    damageType = "fire",
    owner = playerEntity,
    faction = "player",

    -- Collision Behavior
    collisionBehavior = ProjectileSystem.CollisionBehavior.PIERCE,
    maxPierceCount = 3,

    -- Lifetime
    lifetime = 4.0,        -- seconds
    maxDistance = 500,     -- pixels

    -- Visual
    sprite = "fireball_anim",
    size = 16,
    shadow = true,
    looping = true,

    -- Modifiers (from cards/wand system)
    speedMultiplier = 1.5,
    damageMultiplier = 2.0,
    sizeMultiplier = 1.2,

    -- Event Hooks
    onSpawn = function(entity, params)
        log_debug("Projectile spawned!")
    end,

    onHit = function(projectile, target, data)
        log_debug("Hit target:", target)
    end,

    onDestroy = function(entity, data)
        log_debug("Projectile destroyed:", data.despawnReason)
    end
})
```

## Movement Pattern Examples

### 1. Homing Missile

```lua
ProjectileSystem.spawn({
    position = {x = x, y = y},
    movementType = ProjectileSystem.MovementType.HOMING,
    homingTarget = enemyEntity,
    baseSpeed = 300,
    homingStrength = 10.0,    -- Turn rate
    homingMaxSpeed = 500,
    damage = 40,
    owner = owner,
    lifetime = 6.0
})
```

### 2. Orbital Shield

```lua
ProjectileSystem.spawn({
    position = {x = centerX, y = centerY},
    movementType = ProjectileSystem.MovementType.ORBITAL,
    orbitCenter = {x = centerX, y = centerY},
    orbitRadius = 100,
    orbitSpeed = 2.0,  -- radians/sec
    damage = 15,
    collisionBehavior = ProjectileSystem.CollisionBehavior.PASS_THROUGH,
    lifetime = 10.0
})
```

### 3. Grenade (Arc with Gravity)

```lua
ProjectileSystem.spawn({
    position = {x = x, y = y},
    angle = -math.pi/4,  -- Upward angle
    movementType = ProjectileSystem.MovementType.ARC,
    baseSpeed = 400,
    gravityScale = 1.5,
    damage = 50,
    collisionBehavior = ProjectileSystem.CollisionBehavior.EXPLODE,
    explosionRadius = 100,
    lifetime = 5.0
})
```

### 4. Custom Pattern (Sine Wave)

```lua
local time = 0
ProjectileSystem.spawn({
    position = {x = x, y = y},
    angle = angle,
    movementType = ProjectileSystem.MovementType.CUSTOM,

    customUpdate = function(entity, dt, transform, behavior, data)
        time = time + dt

        -- Calculate sine wave offset
        local perpX = -math.sin(angle)
        local perpY = math.cos(angle)
        local offset = math.sin(time * 5) * 50

        -- Apply movement
        transform.actualX = transform.actualX + math.cos(angle) * 300 * dt
        transform.actualY = transform.actualY + math.sin(angle) * 300 * dt
        transform.actualX = transform.actualX + perpX * offset * dt
        transform.actualY = transform.actualY + perpY * offset * dt
    end
})
```

## Collision Behavior Examples

### Piercing Arrow

```lua
ProjectileSystem.spawn({
    position = {x = x, y = y},
    angle = angle,
    movementType = ProjectileSystem.MovementType.STRAIGHT,
    baseSpeed = 600,

    damage = 20,
    damageType = "pierce",

    collisionBehavior = ProjectileSystem.CollisionBehavior.PIERCE,
    maxPierceCount = 5,  -- Pierce through 5 enemies

    onHit = function(projectile, target, data)
        -- Reduce damage on each pierce
        data.damageMultiplier = data.damageMultiplier * 0.85
    end
})
```

### Bouncing Orb

```lua
ProjectileSystem.spawn({
    position = {x = x, y = y},
    direction = direction,
    movementType = ProjectileSystem.MovementType.STRAIGHT,
    baseSpeed = 350,

    damage = 18,

    collisionBehavior = ProjectileSystem.CollisionBehavior.BOUNCE,
    maxBounces = 5,
    bounceDampening = 0.9,  -- 90% speed retained per bounce

    restitution = 0.95,  -- Physics bounciness
    friction = 0.1
})
```

### Explosive Projectile

```lua
ProjectileSystem.spawn({
    position = {x = x, y = y},
    angle = angle,
    movementType = ProjectileSystem.MovementType.ARC,
    baseSpeed = 400,

    damage = 60,
    damageType = "fire",

    collisionBehavior = ProjectileSystem.CollisionBehavior.EXPLODE,
    explosionRadius = 120,
    explosionDamageMult = 1.5,  -- 150% damage in AoE

    onHit = function(projectile, target, data)
        -- Camera shake, sound effects, etc.
    end
})
```

## Wand System Integration

The projectile system is designed to work seamlessly with the card/wand execution engine:

```lua
-- In your wand action card execution:
function fireProjectileAction(ctx, cardData)
    -- Get modifiers from card stack
    local modifiers = {
        speedMultiplier = 1.0,
        damageMultiplier = 1.0,
        pierceCount = 0,
        homingEnabled = false
    }

    -- Apply modifier cards
    for _, modCard in ipairs(cardData.modifierStack) do
        if modCard.id == "double_damage" then
            modifiers.damageMultiplier = modifiers.damageMultiplier * 2.0
        elseif modCard.id == "pierce_twice" then
            modifiers.pierceCount = modifiers.pierceCount + 2
        elseif modCard.id == "homing" then
            modifiers.homingEnabled = true
            modifiers.homingTarget = findNearestEnemy(playerPos)
        end
    end

    -- Spawn projectile with applied modifiers
    local projectile = ProjectileSystem.spawn({
        position = getPlayerPosition(),
        angle = getPlayerFacingAngle(),

        movementType = modifiers.homingEnabled
            and ProjectileSystem.MovementType.HOMING
            or ProjectileSystem.MovementType.STRAIGHT,

        homingTarget = modifiers.homingTarget,
        baseSpeed = 350,

        damage = 25,
        damageType = cardData.damageType or "physical",
        owner = playerEntity,

        collisionBehavior = modifiers.pierceCount > 0
            and ProjectileSystem.CollisionBehavior.PIERCE
            or ProjectileSystem.CollisionBehavior.DESTROY,

        maxPierceCount = modifiers.pierceCount,

        speedMultiplier = modifiers.speedMultiplier,
        damageMultiplier = modifiers.damageMultiplier,

        lifetime = 4.0,
        sprite = cardData.projectileSprite or "b488.png"
    })

    return projectile
end
```

## Event System

The projectile system emits events that can be subscribed to:

```lua
-- Subscribe to projectile events
subscribeToLuaEvent("projectile_spawned", function(data)
    log_debug("Projectile spawned by", data.owner, "at", data.position.x, data.position.y)
end)

subscribeToLuaEvent("projectile_hit", function(data)
    log_debug("Projectile hit target:", data.target, "for", data.damage, "damage")
    -- Trigger on-hit card effects
end)

subscribeToLuaEvent("projectile_destroyed", function(data)
    log_debug("Projectile destroyed. Reason:", data.reason)
end)

subscribeToLuaEvent("projectile_exploded", function(data)
    log_debug("Explosion at", data.position.x, data.position.y, "radius:", data.radius)
    -- Apply AoE damage to all entities in radius
end)
```

## Performance Optimization

### Entity Pooling

The system includes automatic projectile pooling to reduce entity creation overhead:

```lua
-- Pooling is automatic, but you can configure it:
ProjectileSystem.pool = {}  -- Pool of inactive projectiles
ProjectileSystem.active_projectiles = {}  -- Currently active projectiles

-- Max pooled projectiles (default: 50)
-- Adjust based on your game's needs
```

### Physics Optimization

```lua
-- Disable physics for simple projectiles if not needed
ProjectileSystem.spawn({
    -- ... other params
    usePhysics = false,  -- Manual collision detection
})

-- Use sensors (pass-through) instead of solid collision
ProjectileSystem.spawn({
    -- ... other params
    collisionBehavior = ProjectileSystem.CollisionBehavior.PASS_THROUGH,
    -- Creates a sensor body instead of solid collider
})
```

## API Reference

### ProjectileSystem.spawn(params)

Main spawning function. Returns entity ID of spawned projectile.

**Parameters:**
- `position` (required) - {x, y} spawn location
- `angle` - Direction in radians (alternative to direction/velocity)
- `direction` - Normalized direction vector {x, y}
- `velocity` - Direct velocity {x, y}
- `movementType` - Movement pattern (default: STRAIGHT)
- `baseSpeed` - Base movement speed in pixels/second
- `damage` - Damage amount
- `damageType` - Type of damage (physical, fire, cold, etc.)
- `owner` - Owner entity ID
- `faction` - Faction string for friendly fire logic
- `collisionBehavior` - How projectile handles collisions
- `targetCollisionTag` - Physics tag this projectile should damage (default `"enemy"`)
- `collideWithWorld` - Whether to collide with terrain/world geometry (default `true`)
- `collideWithTags` - Explicit list of physics tags to collide with (overrides defaults)
- `lifetime` - Max seconds before despawn
- `maxDistance` - Max pixels traveled before despawn
- `maxHits` - Max number of hits before despawn
- `sprite` - Animation/sprite ID for visual
- `size` - Size in pixels
- `shadow` - Enable shadow rendering
- `speedMultiplier` - Speed modifier (from cards)
- `damageMultiplier` - Damage modifier (from cards)
- `sizeMultiplier` - Size modifier (from cards)
- `onSpawn` - Callback when spawned
- `onHit` - Callback when hitting entity
- `onDestroy` - Callback when destroyed

### ProjectileSystem.update(dt)

Updates all active projectiles. Call once per frame.

### ProjectileSystem.init()

Initializes the projectile system and physics categories. Call once at game start.

### ProjectileSystem.cleanup()

Destroys all projectiles and clears pools. Call when changing game states.

### Helper Functions

```lua
-- Quick spawn helpers
ProjectileSystem.spawnBasic(x, y, angle, speed, damage, owner)
ProjectileSystem.spawnHoming(x, y, target, speed, damage, owner)
ProjectileSystem.spawnArc(x, y, angle, speed, damage, owner)
```

## Troubleshooting

### Projectiles not visible
- Check that `sprite` parameter is valid
- Ensure z-order is correct for rendering
- Verify position is within screen bounds

### Projectiles not colliding
- Confirm physics world is initialized
- Check collision categories are set up
- Verify collision masks allow interaction
- Ensure `usePhysics` is not set to false

### Homing not working
- Verify target entity is valid
- Check that target has Transform component
- Ensure `homingStrength` is high enough
- Confirm target is not too close (causes jittering)

### Performance issues
- Reduce number of simultaneous projectiles
- Disable physics for simple projectiles
- Use pooling (automatic by default)
- Simplify custom update functions
- Reduce particle effects

## Future Enhancements

Planned features for future versions:
- Spatial query optimization for AoE damage
- Trail/particle system integration
- Chain lightning projectiles
- Splitting projectiles
- Curved path projectiles
- Projectile-to-projectile collision
- Save/load projectile state

## Example Integration

See `projectile_examples.lua` for complete working examples of all projectile types and patterns.

## Credits

Created for TheGameJamTemplate - Lua/C++ Game Engine
Compatible with: Raylib, EnTT, Chipmunk2D, LuaJIT
