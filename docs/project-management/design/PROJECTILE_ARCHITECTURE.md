# Projectile System Architecture Document

## Executive Summary

This document outlines the design and implementation of the Projectile Spawning & Management System for the Lua/C++ game engine using Raylib, EnTT, and Chipmunk2D physics.

## Design Goals

1. **Data-Driven**: Projectiles configured via parameters, not code
2. **Extensible**: Easy to add new movement patterns and behaviors
3. **Performance**: Entity pooling and efficient update loops
4. **Integration**: Seamless connection to combat and wand systems
5. **Flexibility**: Support for modifiers from card/wand system

## System Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────┐
│                  PROJECTILE ENTITY                       │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Transform Component (ECS)                        │   │
│  │ - actualX, actualY (position)                    │   │
│  │ - actualW, actualH (size)                        │   │
│  │ - actualR (rotation)                             │   │
│  └─────────────────────────────────────────────────┘   │
│                                                           │
│  ┌─────────────────────────────────────────────────┐   │
│  │ GameObject Component                             │   │
│  │ - projectileData                                 │   │
│  │ - projectileBehavior                             │   │
│  │ - projectileLifetime                             │   │
│  └─────────────────────────────────────────────────┘   │
│                                                           │
│  ┌─────────────────────────────────────────────────┐   │
│  │ AnimatedObject Component (optional)              │   │
│  │ - sprite animation                               │   │
│  │ - visual effects                                 │   │
│  └─────────────────────────────────────────────────┘   │
│                                                           │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Physics Components (Chipmunk2D)                  │   │
│  │ - cpBody (dynamic body)                          │   │
│  │ - cpShape (collider)                             │   │
│  │ - collision category/mask                        │   │
│  └─────────────────────────────────────────────────┘   │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

### Data Structures

#### ProjectileData
Stores core damage and ownership information.

```lua
{
    damage = number,              -- Base damage amount
    damageType = string,          -- Type: physical, fire, cold, etc.
    owner = entity,               -- Entity that spawned projectile
    faction = string,             -- For friendly fire logic

    pierceCount = number,         -- Current pierce count
    maxPierceCount = number,      -- Max enemies to pierce
    hitEntities = {entity -> bool}, -- Track hit entities

    modifiers = table,            -- Card/wand modifiers
    speedMultiplier = number,     -- Speed modifier
    damageMultiplier = number,    -- Damage modifier
    sizeMultiplier = number,      -- Size modifier

    onSpawnCallback = function,   -- Event hook
    onHitCallback = function,     -- Event hook
    onDestroyCallback = function, -- Event hook

    projectileId = number,        -- Unique ID
    creationTime = number         -- Timestamp
}
```

#### ProjectileBehavior
Defines movement pattern and collision behavior.

```lua
{
    movementType = enum,          -- STRAIGHT, HOMING, ORBITAL, ARC, CUSTOM

    collisionBehavior = enum,     -- DESTROY, PIERCE, BOUNCE, EXPLODE, PASS_THROUGH

    velocity = {x, y},            -- Current velocity vector
    baseSpeed = number,           -- Base movement speed

    -- Homing parameters
    homingTarget = entity,        -- Target to track
    homingStrength = number,      -- Turn rate
    homingMaxSpeed = number,      -- Max homing speed

    -- Orbital parameters
    orbitCenter = {x, y},         -- Center point
    orbitRadius = number,         -- Orbit distance
    orbitSpeed = number,          -- Angular velocity
    orbitAngle = number,          -- Current angle

    -- Gravity parameters
    gravityScale = number,        -- Gravity multiplier

    -- Bounce parameters
    bounceCount = number,         -- Current bounces
    maxBounces = number,          -- Max bounces allowed
    bounceDampening = number,     -- Speed retention per bounce

    -- Custom update
    customUpdate = function       -- Custom movement function
}
```

#### ProjectileLifetime
Manages despawn conditions.

```lua
{
    maxLifetime = number,         -- Max seconds alive
    currentLifetime = number,     -- Current age

    maxDistance = number,         -- Max travel distance
    distanceTraveled = number,    -- Current distance
    startPosition = {x, y},       -- Starting location

    maxHits = number,             -- Max hits before despawn
    hitCount = number,            -- Current hit count

    shouldDespawn = boolean,      -- Despawn flag
    despawnReason = string        -- Why despawning
}
```

## Data Flow

### Spawning Flow

```
User/Wand System
       │
       │ spawn({params})
       ▼
┌──────────────────┐
│ ProjectileSystem │
│   .spawn()       │
└────────┬─────────┘
         │
         ├─► Get/Create Entity (from pool or new)
         │
         ├─► Create Components
         │   - Transform
         │   - GameObject (with projectile data)
         │   - AnimatedObject
         │
         ├─► Setup Physics
         │   - Create cpBody
         │   - Add cpShape collider
         │   - Set collision category/mask
         │   - Set physics properties
         │
         ├─► Initialize Movement
         │   - Calculate initial velocity
         │   - Apply to physics body
         │   - Setup movement-specific state
         │
         ├─► Add to Active Tracking
         │   - ProjectileSystem.active_projectiles
         │
         ├─► Fire onSpawn Callback
         │
         └─► Emit "projectile_spawned" Event
```

### Update Flow

```
Game Loop (every frame)
       │
       │ update(dt)
       ▼
┌──────────────────────┐
│ ProjectileSystem     │
│   .update(dt)        │
└──────┬───────────────┘
       │
       │ for each active projectile:
       │
       ├─► Update Lifetime
       │   - Increment currentLifetime
       │   - Check time-based despawn
       │   - Check distance-based despawn
       │   - Check hit-count despawn
       │
       ├─► Update Movement
       │   ├─ STRAIGHT: Apply velocity
       │   ├─ HOMING: Steer towards target
       │   ├─ ORBITAL: Calculate orbit position
       │   ├─ ARC: Apply gravity (via physics)
       │   └─ CUSTOM: Call custom update function
       │
       ├─► Check Despawn Conditions
       │   - If shouldDespawn, add to removal list
       │
       └─► Remove Destroyed Projectiles
           - Call destroy() for each
           - Emit events
           - Return to pool or destroy entity
```

### Collision Flow

```
Chipmunk2D Physics World
       │
       │ collision detected
       ▼
┌─────────────────────┐
│ Collision Callback  │
│  on_collision()     │
└─────────┬───────────┘
          │
          │ ProjectileSystem.handleCollision()
          │
          ├─► Check if already hit this entity
          │   (for piercing projectiles)
          │
          ├─► Mark entity as hit
          │
          ├─► Apply Damage
          │   - Use CombatSystem if available
          │   - Fallback to blackboard health
          │
          ├─► Fire onHit Callback
          │
          ├─► Emit "projectile_hit" Event
          │
          └─► Handle Collision Behavior
              ├─ DESTROY: Set shouldDespawn
              ├─ PIERCE: Increment pierceCount, check max
              ├─ BOUNCE: Reverse velocity, apply dampening
              ├─ EXPLODE: Deal AoE damage, particles, despawn
              └─ PASS_THROUGH: Do nothing (already dealt damage)
```

## Movement Pattern Implementations

### Straight Line
**Physics-based:**
```lua
-- Set initial velocity on physics body
physics.SetVelocity(world, entity, vx, vy)
-- Physics handles movement
```

**Manual (no physics):**
```lua
-- Update position each frame
transform.actualX = transform.actualX + velocity.x * dt
transform.actualY = transform.actualY + velocity.y * dt
```

### Homing
**Algorithm:**
```lua
1. Get target position
2. Calculate direction vector to target
3. Normalize direction
4. Apply steering force:
   velocity = velocity + (direction * steerStrength * dt * currentSpeed)
5. Clamp to max speed
6. Apply velocity to entity
7. Update rotation to face direction
```

**Advantages:**
- Smooth tracking
- Configurable aggressiveness
- Natural-looking movement

### Orbital
**Algorithm:**
```lua
1. Update orbit angle: angle = angle + orbitSpeed * dt
2. Calculate position on circle:
   x = centerX + cos(angle) * radius
   y = centerY + sin(angle) * radius
3. Set transform position directly
4. Update rotation to tangent direction
```

**Use cases:**
- Shield projectiles
- Satellites
- Defensive orbitals

### Arc (Gravity-Affected)
**Implementation:**
```lua
1. Set initial velocity at angle
2. Physics applies gravity:
   velocity.y += gravity * gravityScale * dt
3. Update rotation to face velocity direction
```

**Use cases:**
- Grenades
- Thrown objects
- Mortar shells

### Custom
**Flexibility:**
```lua
customUpdate = function(entity, dt, transform, behavior, data)
    -- User-defined logic
    -- Full access to all components
    -- Can implement any pattern:
    --   - Sine wave
    --   - Spiral
    --   - Zigzag
    --   - Bezier curves
    --   - etc.
end
```

## Collision Behavior Implementations

### Destroy
```lua
on collision:
    apply damage
    set shouldDespawn = true
    despawnReason = "hit"
```

### Pierce
```lua
on collision:
    if entity not in hitEntities:
        hitEntities[entity] = true
        apply damage
        pierceCount++

        if pierceCount >= maxPierceCount:
            shouldDespawn = true
            despawnReason = "pierce_depleted"
```

### Bounce
```lua
on collision:
    velocity = -velocity * bounceDampening
    bounceCount++

    if bounceCount >= maxBounces:
        shouldDespawn = true
        despawnReason = "bounce_depleted"
```

### Explode
```lua
on collision:
    apply damage to hit entity
    query all entities in explosionRadius
    for each entity in radius:
        apply AoE damage (reduced by distance)
    spawn particle explosion
    emit "projectile_exploded" event
    shouldDespawn = true
```

### Pass-Through
```lua
on collision:
    apply damage
    continue moving (don't despawn)
    -- Physics sensor allows passing through
```

## Performance Optimizations

### Entity Pooling

**Strategy:**
```
Pool Size: 50 entities (configurable)

Spawn Process:
1. Check pool for inactive entity
2. If available, reuse entity
3. If not, create new entity

Destroy Process:
1. If pool not full, return to pool
2. Clean components but keep entity alive
3. Move entity off-screen
4. Otherwise, destroy entity
```

**Benefits:**
- Reduces entity creation overhead
- Fewer memory allocations
- Better cache coherency
- Reduced GC pressure (Lua)

### Spatial Partitioning (Future)

For AoE damage queries:
```
Current: O(n) linear search
Future: O(log n) with quadtree/grid
```

### Physics Optimization

**Collision Categories:**
```lua
-- Projectiles don't collide with each other
disable_collision_between("projectile", "projectile")

-- Only collide with relevant entities
enable_collision_between("projectile", {"enemy", "terrain"})
```

**Bullet Bodies:**
```lua
-- High-speed collision detection
physics.SetBullet(body, true)
```

**Sensors for Pass-Through:**
```lua
-- No physical collision, just triggers
isSensor = true
```

## Integration Points

### Combat System Integration

```lua
-- ProjectileSystem → CombatSystem
function applyDamage(projectile, target, data)
    CombatSystem.applyDamage({
        target = target,
        source = data.owner,
        damage = data.damage * data.damageMultiplier,
        damageType = data.damageType,
        projectile = projectile  -- For combat log
    })
end
```

**Benefits:**
- Consistent damage calculation
- Resistance/armor application
- Damage events for UI
- Combat statistics tracking

### Wand System Integration

```lua
-- Wand Action Card → ProjectileSystem
function executeFireball(ctx, cardData, modifierStack)
    -- Aggregate modifiers from card stack
    local mods = {}
    for _, mod in ipairs(modifierStack) do
        applyModifier(mod, mods)
    end

    -- Spawn projectile with modifiers
    return ProjectileSystem.spawn({
        position = getPlayerPos(),
        angle = getPlayerAngle(),
        damage = cardData.baseDamage,
        speedMultiplier = mods.speed,
        damageMultiplier = mods.damage,
        -- ... other params
    })
end
```

**Benefits:**
- Modular card effects
- Stackable modifiers
- Reusable projectile logic

### Event System Integration

```lua
-- ProjectileSystem → Event Bus
publishLuaEvent("projectile_spawned", {...})
publishLuaEvent("projectile_hit", {...})
publishLuaEvent("projectile_destroyed", {...})
publishLuaEvent("projectile_exploded", {...})

-- Wand System subscribes to events
subscribeToLuaEvent("projectile_hit", function(data)
    -- Trigger "on hit" card effects
    executeOnHitModifiers(data.projectile)
end)
```

**Benefits:**
- Decoupled systems
- Event-driven gameplay
- Easy to add new features
- Debug/telemetry

## Design Decisions

### Why attach data to GameObject instead of separate components?

**Decision:** Store ProjectileData, ProjectileBehavior, ProjectileLifetime as tables in GameObject component.

**Reasoning:**
1. Simplicity: Easier to access all projectile data from one component
2. Lua-friendly: No need for C++ component bindings
3. Flexibility: Can add fields dynamically
4. Performance: One component lookup instead of three

**Trade-off:** Less ECS-pure, but more practical for Lua scripting

### Why manual movement for some patterns?

**Decision:** Support both physics-based and manual movement.

**Reasoning:**
1. Physics overhead: Not all projectiles need full physics
2. Determinism: Manual movement is more predictable
3. Flexibility: Some patterns easier without physics
4. Performance: Can disable physics for simple projectiles

### Why entity pooling instead of object pooling?

**Decision:** Pool entire entities, not just Lua tables.

**Reasoning:**
1. Entity creation is expensive (registry, components)
2. Physics body creation is expensive
3. Reusing entities avoids allocation spikes
4. Better performance for high projectile count

### Why separate collision behaviors from movement patterns?

**Decision:** Movement and collision are independent dimensions.

**Reasoning:**
1. Flexibility: Any movement can have any collision behavior
2. Reusability: Same collision code for different movements
3. Modularity: Easy to add new behaviors
4. Clarity: Easier to understand and debug

## Testing Strategy

### Unit Tests (Future)
```lua
test "basic projectile spawn":
    entity = ProjectileSystem.spawnBasic(0, 0, 0, 100, 10, null)
    assert entity ~= entt_null
    assert active_projectiles[entity] == true

test "homing projectile tracks target":
    target = createTestEntity(100, 100)
    projectile = ProjectileSystem.spawnHoming(0, 0, target, 100, 10, null)
    -- simulate frames
    update(0.1)
    -- check projectile moved towards target

test "piercing projectile hits multiple":
    projectile = spawn with maxPierceCount = 3
    hit enemy1, enemy2, enemy3
    assert pierceCount == 3
    hit enemy4
    assert shouldDespawn == true
```

### Integration Tests
```lua
test "projectile applies damage via combat system":
    enemy = createEnemy(100 health)
    projectile = spawn with 25 damage
    simulateCollision(projectile, enemy)
    assert enemy health == 75

test "wand modifiers apply correctly":
    modifiers = {damageMultiplier = 2.0}
    projectile = spawnWithModifiers(modifiers)
    assert projectile.data.damageMultiplier == 2.0
```

## Future Enhancements

### Planned Features

1. **Spatial Query Optimization**
   - Implement quadtree for AoE damage
   - O(log n) instead of O(n) queries

2. **Advanced Behaviors**
   - Chain lightning (arc between enemies)
   - Split projectiles (divide on hit)
   - Curved path projectiles (bezier)
   - Seeking clusters (target groups)

3. **Visual Effects**
   - Integrated trail systems
   - Per-projectile particle emitters
   - Hit effect templates

4. **Networking (if needed)**
   - Projectile state serialization
   - Client-side prediction
   - Server reconciliation

5. **Save/Load**
   - Serialize active projectiles
   - Restore projectile state

## Conclusion

The Projectile System provides a robust, extensible foundation for projectile-based gameplay. The architecture balances flexibility with performance, and integrates cleanly with existing systems. The data-driven approach makes it easy to create new projectile types without code changes, ideal for a card/wand-based game.

## References

- Chipmunk2D Documentation: https://chipmunk-physics.net/
- EnTT ECS: https://github.com/skypjack/entt
- Existing Combat System: `/assets/scripts/combat/combat_system.lua`
- Physics Docs: `/assets/scripts/physics_docs.md`
