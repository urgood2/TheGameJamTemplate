# Noita Spell System: Detailed Implementation Specification

**Date:** 2026-01-05  
**Branch:** `feature/noita-spells`  
**Scope:** Formations, Friendly Fire, New Movement Types, Teleport, Divide

---

## Overview

This spec provides **exact code locations and snippets** for implementing Noita-style spell mechanics. Each section includes:
- File path and line numbers
- Exact code to add/modify
- Test cases to verify

**OUT OF SCOPE (per user request):**
- ❌ Terrain drilling
- ❌ Water/material interactions
- ❌ Material physics system

---

## 1. Friendly Fire System

### Problem
Currently projectiles only damage enemies. Noita has many spells that can hurt the caster.

### Solution
Add `friendlyFire` flag to projectile data and check faction before applying damage.

### File: `assets/scripts/combat/projectile_system.lua`

**Location:** `createProjectileData()` (line ~162)

```lua
-- Add to projectileData return table (after line 173)
friendlyFire = params.friendlyFire or false,  -- Can damage owner/allies
```

**Location:** `applyDamage()` (line ~1769)

```lua
-- Add after line 1771, before combat actor lookup
-- Friendly fire check
if not data.friendlyFire then
    -- Check if target is same faction as owner
    local ownerFaction = data.faction or "player"
    local targetScript = getScriptTableFromEntityID(targetEntity)
    local targetFaction = targetScript and targetScript.faction or "enemy"
    
    -- Skip damage if same faction (unless friendlyFire enabled)
    if ownerFaction == targetFaction then
        return nil, nil
    end
    
    -- Also skip if target is the owner
    if targetEntity == data.owner then
        return nil, nil
    end
end
```

### File: `assets/scripts/wand/wand_actions.lua`

**Location:** `spawnSingleProjectile()` (line ~395)

```lua
-- Add to spawnParams (after line 417)
friendlyFire = actionCard.friendly_fire or modifiers.friendlyFire or false,
```

### Card Definition Pattern
```lua
Cards.PIERCING_SHOT = {
    id = "PIERCING_SHOT",
    type = "action",
    mana_cost = 30,
    damage = 40,
    friendly_fire = true,  -- NEW: Can hurt caster
    -- ...
}
```

---

## 2. Formation System

### Problem
Multicast currently only supports linear spread. Need geometric patterns (pentagon, hexagon, etc.)

### Solution
Add `formation` field to modifiers and calculate angles based on pattern.

### File: `assets/scripts/wand/wand_modifiers.lua`

**Location:** After line ~298 (in createAggregate)

```lua
-- Formation pattern
formation = nil,  -- nil, "pentagon", "hexagon", "behind_back", "bifurcated", "trifurcated"
```

**Location:** Add new function after `calculateMulticastAngles` (~line 400)

```lua
--- Formation angle patterns (in radians)
WandModifiers.FORMATIONS = {
    pentagon = { 0, math.pi * 2/5, math.pi * 4/5, math.pi * 6/5, math.pi * 8/5 },
    hexagon = { 0, math.pi/3, math.pi * 2/3, math.pi, math.pi * 4/3, math.pi * 5/3 },
    behind_back = { 0, math.pi },
    bifurcated = { -math.pi/12, math.pi/12 },  -- +/- 15 degrees
    trifurcated = { -math.pi/9, 0, math.pi/9 },  -- -20, 0, +20 degrees
    above_below = { -math.pi/2, math.pi/2 },
}

--- Calculate formation angles (replaces multicast angles when formation is set)
--- @param modifiers table Modifier aggregate
--- @param baseAngle number Base firing angle in radians
--- @return table List of angles
function WandModifiers.calculateFormationAngles(modifiers, baseAngle)
    local formation = modifiers.formation
    if not formation then
        return WandModifiers.calculateMulticastAngles(modifiers, baseAngle)
    end
    
    local pattern = WandModifiers.FORMATIONS[formation]
    if not pattern then
        log_warn("Unknown formation:", formation)
        return { baseAngle }
    end
    
    local angles = {}
    for _, offset in ipairs(pattern) do
        table.insert(angles, baseAngle + offset)
    end
    
    return angles
end
```

**Location:** Modify `aggregate()` to collect formation from modifier cards

```lua
-- In the loop processing modifier cards, add:
if card.formation then
    result.formation = card.formation
end
```

### File: `assets/scripts/wand/wand_actions.lua`

**Location:** `executeProjectileAction()` (line ~308)

```lua
-- Replace:
local angles = WandModifiers.calculateMulticastAngles(modifiers, baseAngle)

-- With:
local angles = WandModifiers.calculateFormationAngles(modifiers, baseAngle)
```

### Card Definition Pattern
```lua
Cards.FORMATION_PENTAGON = {
    id = "FORMATION_PENTAGON",
    type = "modifier",
    mana_cost = 5,
    formation = "pentagon",
    tags = { "Arcane", "AoE" },
    description = "Casts in 5 directions",
}
```

---

## 3. New Movement Types

### 3.1 Boomerang Movement

**File:** `assets/scripts/combat/projectile_system.lua`

**Location:** Add to MovementType table (line ~68)

```lua
BOOMERANG = "boomerang",
```

**Location:** Add new movement function (after line ~1642)

```lua
function ProjectileSystem.updateBoomerangMovement(entity, dt, transform, behavior, projectileScript)
    -- Track return state
    if not behavior._boomerangState then
        behavior._boomerangState = {
            returning = false,
            startX = transform.actualX + (transform.actualW or 0) * 0.5,
            startY = transform.actualY + (transform.actualH or 0) * 0.5,
            maxDistance = behavior.boomerangDistance or 300,
            returnSpeed = behavior.baseSpeed * 1.2,
        }
    end
    
    local state = behavior._boomerangState
    local cx = transform.actualX + (transform.actualW or 0) * 0.5
    local cy = transform.actualY + (transform.actualH or 0) * 0.5
    
    -- Check if should start returning
    if not state.returning then
        local dx = cx - state.startX
        local dy = cy - state.startY
        local dist = math.sqrt(dx * dx + dy * dy)
        
        if dist >= state.maxDistance then
            state.returning = true
        end
    end
    
    local world = getPhysicsWorld(projectileScript)
    
    if state.returning then
        -- Home back to owner
        local owner = projectileScript.projectileData and projectileScript.projectileData.owner
        local targetX, targetY = state.startX, state.startY
        
        if owner and entity_cache.valid(owner) then
            local ownerT = component_cache.get(owner, Transform)
            if ownerT then
                targetX = ownerT.actualX + (ownerT.actualW or 0) * 0.5
                targetY = ownerT.actualY + (ownerT.actualH or 0) * 0.5
            end
        end
        
        local dx = targetX - cx
        local dy = targetY - cy
        local dist = math.sqrt(dx * dx + dy * dy)
        
        -- Check if returned to owner
        if dist < 30 then
            projectileScript.projectileLifetime.shouldDespawn = true
            projectileScript.projectileLifetime.despawnReason = "boomerang_returned"
            return
        end
        
        if dist > 0.1 then
            local speed = state.returnSpeed
            behavior.velocity.x = (dx / dist) * speed
            behavior.velocity.y = (dy / dist) * speed
        end
    end
    
    -- Apply movement
    if world then
        physics.SetVelocity(world, entity, behavior.velocity.x, behavior.velocity.y)
    else
        transform.actualX = transform.actualX + behavior.velocity.x * dt
        transform.actualY = transform.actualY + behavior.velocity.y * dt
    end
    
    -- Update rotation
    if behavior.velocity.x ~= 0 or behavior.velocity.y ~= 0 then
        transform.actualR = math.atan(behavior.velocity.y, behavior.velocity.x)
        transform.visualR = transform.actualR
    end
end
```

**Location:** Add to `updateProjectile()` switch (line ~1129)

```lua
elseif behavior.movementType == ProjectileSystem.MovementType.BOOMERANG then
    ProjectileSystem.updateBoomerangMovement(entity, dt, transform, behavior, projectileScript)
```

### 3.2 Spiral Movement

**Location:** Add to MovementType table

```lua
SPIRAL = "spiral",
```

**Location:** Add movement function

```lua
function ProjectileSystem.updateSpiralMovement(entity, dt, transform, behavior, projectileScript)
    if not behavior._spiralState then
        behavior._spiralState = {
            angle = 0,
            spiralRate = behavior.spiralRate or 8.0,  -- radians per second
            spiralAmplitude = behavior.spiralAmplitude or 30,  -- pixels
        }
    end
    
    local state = behavior._spiralState
    state.angle = state.angle + state.spiralRate * dt
    
    -- Base velocity (forward direction)
    local baseVx = behavior.velocity.x
    local baseVy = behavior.velocity.y
    local speed = math.sqrt(baseVx * baseVx + baseVy * baseVy)
    
    if speed > 0.1 then
        -- Calculate perpendicular offset
        local perpX = -baseVy / speed
        local perpY = baseVx / speed
        local offset = math.sin(state.angle) * state.spiralAmplitude
        
        local targetX = transform.actualX + baseVx * dt + perpX * offset * dt
        local targetY = transform.actualY + baseVy * dt + perpY * offset * dt
        
        transform.actualX = targetX
        transform.actualY = targetY
    end
    
    local world = getPhysicsWorld(projectileScript)
    if world then
        local cx = transform.actualX + (transform.actualW or 0) * 0.5
        local cy = transform.actualY + (transform.actualH or 0) * 0.5
        physics.SetPosition(world, entity, { x = cx, y = cy })
    end
    
    transform.actualR = math.atan(baseVy, baseVx)
    transform.visualR = transform.actualR
end
```

### 3.3 Ping-Pong (Zigzag) Movement

```lua
PINGPONG = "pingpong",

function ProjectileSystem.updatePingPongMovement(entity, dt, transform, behavior, projectileScript)
    if not behavior._pingpongState then
        behavior._pingpongState = {
            timer = 0,
            zigInterval = behavior.zigInterval or 0.15,
            zigAmplitude = behavior.zigAmplitude or 60,
            direction = 1,
        }
    end
    
    local state = behavior._pingpongState
    state.timer = state.timer + dt
    
    if state.timer >= state.zigInterval then
        state.timer = 0
        state.direction = -state.direction
    end
    
    local baseVx = behavior.velocity.x
    local baseVy = behavior.velocity.y
    local speed = math.sqrt(baseVx * baseVx + baseVy * baseVy)
    
    if speed > 0.1 then
        local perpX = -baseVy / speed
        local perpY = baseVx / speed
        
        local zigVx = baseVx + perpX * state.zigAmplitude * state.direction
        local zigVy = baseVy + perpY * state.zigAmplitude * state.direction
        
        transform.actualX = transform.actualX + zigVx * dt
        transform.actualY = transform.actualY + zigVy * dt
    end
    
    local world = getPhysicsWorld(projectileScript)
    if world then
        local cx = transform.actualX + (transform.actualW or 0) * 0.5
        local cy = transform.actualY + (transform.actualH or 0) * 0.5
        physics.SetPosition(world, entity, { x = cx, y = cy })
    end
    
    transform.actualR = math.atan(baseVy, baseVx)
    transform.visualR = transform.actualR
end
```

---

## 4. Teleport System

### File: `assets/scripts/wand/wand_actions.lua`

**Location:** Replace `executeTeleportAction()` (line ~894)

```lua
--- Executes a teleport action card
--- @param actionCard table Action card definition
--- @param modifiers table Modifier aggregate
--- @param context table Execution context
--- @return boolean Success
function WandActions.executeTeleportAction(actionCard, modifiers, context)
    if not context.playerEntity then
        log_warn("WandActions.executeTeleportAction: no player entity")
        return false
    end
    
    -- Teleport bolt: spawn projectile that teleports player on hit
    if actionCard.teleport_on_hit then
        -- Spawn a special projectile
        local props = WandModifiers.applyToAction(actionCard, modifiers)
        local spawnPos = context.playerPosition
        local angle = context.playerAngle or 0
        
        local projectileId = ProjectileSystem.spawn({
            position = spawnPos,
            positionIsCenter = true,
            angle = angle,
            movementType = ProjectileSystem.MovementType.STRAIGHT,
            baseSpeed = props.speed or 800,
            damage = props.damage or 0,
            damageType = props.damageType or "arcane",
            owner = context.playerEntity,
            faction = "player",
            lifetime = props.lifetime or 2.0,
            collisionBehavior = ProjectileSystem.CollisionBehavior.DESTROY,
            size = 8,
            
            -- Teleport callback
            onHit = function(proj, target, data)
                local transform = component_cache.get(proj, Transform)
                if transform then
                    WandActions.teleportEntity(context.playerEntity, 
                        transform.actualX + (transform.actualW or 0) * 0.5,
                        transform.actualY + (transform.actualH or 0) * 0.5)
                end
            end,
            onDestroy = function(proj, data)
                -- Also teleport on hitting wall (destroy)
                local transform = component_cache.get(proj, Transform)
                if transform and data.despawnReason ~= "timeout" then
                    WandActions.teleportEntity(context.playerEntity,
                        transform.actualX + (transform.actualW or 0) * 0.5,
                        transform.actualY + (transform.actualH or 0) * 0.5)
                end
            end,
        })
        
        return projectileId ~= entt_null
    end
    
    -- Direct teleport to target location
    if actionCard.teleport_to_impact then
        -- Spawn projectile that teleports on any collision
        return WandActions.executeTeleportAction({
            teleport_on_hit = true,
            projectile_speed = actionCard.projectile_speed or 800,
            lifetime = actionCard.lifetime or 2.0,
        }, modifiers, context)
    end
    
    return false
end

--- Teleport an entity to a position with effects
--- @param entity number Entity to teleport
--- @param x number Target X
--- @param y number Target Y
function WandActions.teleportEntity(entity, x, y)
    if not entity or not entity_cache.valid(entity) then return end
    
    local transform = component_cache.get(entity, Transform)
    if not transform then return end
    
    -- Store old position for effects
    local oldX = transform.actualX + (transform.actualW or 0) * 0.5
    local oldY = transform.actualY + (transform.actualH or 0) * 0.5
    
    -- Move entity
    transform.actualX = x - (transform.actualW or 0) * 0.5
    transform.actualY = y - (transform.actualH or 0) * 0.5
    
    -- Sync physics if present
    local world = PhysicsManager and PhysicsManager.get_world("world")
    if world and physics and physics.SetPosition then
        physics.SetPosition(world, entity, { x = x, y = y })
        physics.SetVelocity(world, entity, 0, 0)  -- Stop momentum
    end
    
    -- Visual effects
    local Particles = require("core.particles")
    local z_orders = require("core.z_orders")
    
    -- Departure effect
    Particles.define()
        :shape("circle")
        :size(4, 8)
        :color("cyan", "white")
        :velocity(100, 200)
        :lifespan(0.2, 0.4)
        :fade()
        :z(z_orders.particle_vfx)
        :burst(15)
        :at(oldX, oldY)
    
    -- Arrival effect
    Particles.define()
        :shape("circle")
        :size(4, 8)
        :color("cyan", "white")
        :velocity(100, 200)
        :lifespan(0.2, 0.4)
        :fade()
        :z(z_orders.particle_vfx)
        :burst(15)
        :at(x, y)
    
    -- Sound
    if playSoundEffect then
        playSoundEffect("effects", "teleport_whoosh")
    end
    
    -- Emit event
    local signal = require("external.hump.signal")
    signal.emit("entity_teleported", entity, { from = { x = oldX, y = oldY }, to = { x = x, y = y } })
    
    log_debug("Teleported entity", entity, "to", x, y)
end
```

---

## 5. Divide System

### Problem
Divide is different from multicast:
- **Multicast**: Consumes N spells from wand, casts them together
- **Divide**: Takes 1 spell, creates N identical copies

### File: `assets/scripts/wand/wand_modifiers.lua`

**Location:** Add to `createAggregate()` (line ~250)

```lua
-- Divide (spell duplication)
divideCount = 1,  -- 1 = no divide, 2 = duplicate, etc.
```

**Location:** Add to `aggregate()` loop

```lua
if card.divide_count then
    result.divideCount = (result.divideCount or 1) * card.divide_count
end
```

### File: `assets/scripts/wand/wand_actions.lua`

**Location:** Modify `executeProjectileAction()` to apply divide

```lua
-- After calculating angles, before spawning (around line 314)
local divideCount = modifiers.divideCount or 1
local spawnedProjectiles = {}

for _, angle in ipairs(angles) do
    -- Spawn divide copies for each angle
    for d = 1, divideCount do
        local projectileId = WandActions.spawnSingleProjectile(
            actionCard,
            props,
            modifiers,
            context,
            spawnPos,
            angle,
            childInfo,
            upgradeBehaviors
        )

        if projectileId and projectileId ~= entt_null then
            table.insert(spawnedProjectiles, projectileId)
        end
    end
end
```

---

## 6. Card Definitions to Add

### File: `assets/scripts/data/cards.lua`

```lua
-- ============================================================================
-- NOITA-STYLE CARDS
-- ============================================================================

-- BASIC PROJECTILES
Cards.SPARK_BOLT = {
    id = "SPARK_BOLT",
    type = "action",
    mana_cost = 5,
    damage = 3,
    projectile_speed = 800,
    lifetime = 0.67,
    cast_delay = 50,
    spread_angle = -1,
    critical_hit_chance = 5,
    tags = { "Projectile", "Arcane" },
    description = "A weak but enchanting sparkling projectile",
}

Cards.BOUNCING_BURST = {
    id = "BOUNCING_BURST",
    type = "action",
    mana_cost = 5,
    damage = 3,
    projectile_speed = 700,
    lifetime = 12.5,
    cast_delay = -30,
    ricochet_count = 10,
    spread_angle = -1,
    tags = { "Projectile" },
    description = "A bouncing projectile with long lifetime",
}

Cards.MAGIC_MISSILE = {
    id = "MAGIC_MISSILE",
    type = "action",
    max_uses = 10,
    mana_cost = 70,
    damage = 75,
    radius_of_effect = 15,
    projectile_speed = 85,
    lifetime = 6.0,
    cast_delay = 1000,
    homing_strength = 5,
    tags = { "Projectile", "Arcane", "AoE" },
    description = "A magical missile that homes in on enemies",
}

Cards.BOMB = {
    id = "BOMB",
    type = "action",
    max_uses = 3,
    mana_cost = 25,
    damage = 125,
    radius_of_effect = 60,
    projectile_speed = 60,
    lifetime = 3.0,
    cast_delay = 1670,
    gravity_affected = true,
    friendly_fire = true,  -- Can hurt caster!
    tags = { "AoE", "Brute" },
    description = "An explosive bomb affected by gravity",
}

-- TELEPORT
Cards.TELEPORT_BOLT = {
    id = "TELEPORT_BOLT",
    type = "action",
    mana_cost = 40,
    projectile_speed = 800,
    lifetime = 2.0,
    cast_delay = 50,
    teleport_on_hit = true,
    tags = { "Mobility", "Arcane" },
    description = "Teleports you to where the bolt lands",
}

-- FORMATIONS
Cards.FORMATION_PENTAGON = {
    id = "FORMATION_PENTAGON",
    type = "modifier",
    mana_cost = 5,
    formation = "pentagon",
    tags = { "Arcane", "AoE" },
    description = "Casts in 5 directions",
}

Cards.FORMATION_HEXAGON = {
    id = "FORMATION_HEXAGON",
    type = "modifier",
    mana_cost = 6,
    formation = "hexagon",
    tags = { "Arcane", "AoE" },
    description = "Casts in 6 directions",
}

Cards.FORMATION_BEHIND_BACK = {
    id = "FORMATION_BEHIND_BACK",
    type = "modifier",
    mana_cost = 0,
    formation = "behind_back",
    tags = { "Defense" },
    description = "Also casts behind you",
}

-- PATH MODIFIERS
Cards.MOD_BOOMERANG = {
    id = "MOD_BOOMERANG",
    type = "modifier",
    mana_cost = 10,
    movement_type = "boomerang",
    tags = { "Projectile" },
    description = "Projectile returns to caster",
}

Cards.MOD_SPIRAL_ARC = {
    id = "MOD_SPIRAL_ARC",
    type = "modifier",
    mana_cost = 0,
    cast_delay = -100,
    lifetime_modifier = 50,
    movement_type = "spiral",
    tags = { "Projectile" },
    description = "Spiraling corkscrew path",
}

-- DIVIDE
Cards.DIVIDE_BY_2 = {
    id = "DIVIDE_BY_2",
    type = "modifier",
    mana_cost = 35,
    cast_delay = 330,
    divide_count = 2,
    tags = { "Arcane" },
    description = "Splits the next spell into 2 copies",
}

Cards.DIVIDE_BY_4 = {
    id = "DIVIDE_BY_4",
    type = "modifier",
    mana_cost = 70,
    cast_delay = 830,
    divide_count = 4,
    tags = { "Arcane" },
    description = "Splits the next spell into 4 copies",
}

-- FRIENDLY FIRE EXAMPLES
Cards.PIERCING_SHOT = {
    id = "PIERCING_SHOT",
    type = "modifier",
    mana_cost = 20,
    pierceCount = 3,
    friendly_fire = true,
    tags = { "Projectile", "Brute" },
    description = "Pierces enemies but can hurt you",
}

Cards.LIGHTNING_BOLT = {
    id = "LIGHTNING_BOLT",
    type = "action",
    mana_cost = 60,
    damage = 25,
    damage_type = "lightning",
    projectile_speed = 2000,
    lifetime = 0.5,
    friendly_fire = true,  -- Noita's lightning can hurt you
    tags = { "Projectile", "Lightning" },
    description = "Extremely fast lightning. Can hurt you!",
}
```

---

## 7. Implementation Order

### Phase 1: Foundation (Day 1)
1. Add `friendlyFire` to projectileData
2. Add faction check in `applyDamage()`
3. Add basic cards that use existing systems

### Phase 2: Formations (Day 2)
1. Add `formation` field to modifier aggregate
2. Implement `calculateFormationAngles()`
3. Add formation modifier cards
4. Test with pentagon + spark bolt

### Phase 3: Movement Types (Days 3-4)
1. Add BOOMERANG movement type
2. Add SPIRAL movement type
3. Add PINGPONG movement type
4. Add path modifier cards

### Phase 4: Teleport (Day 5)
1. Implement `teleportEntity()` helper
2. Implement `executeTeleportAction()` with projectile
3. Add visual/audio effects
4. Test teleport bolt

### Phase 5: Divide (Day 6)
1. Add `divideCount` to modifier aggregate
2. Modify spawn loop to create copies
3. Test divide + formations combo

---

## 8. Test Cases

### Friendly Fire
```lua
-- Test: Bomb damages caster
local bomb = Cards.BOMB
assert(bomb.friendly_fire == true)
-- Spawn bomb, walk into explosion, verify damage taken
```

### Formations
```lua
-- Test: Pentagon spawns 5 projectiles
-- Cast spark bolt with pentagon modifier
-- Verify 5 projectiles at 72° intervals
```

### Boomerang
```lua
-- Test: Boomerang returns to caster
-- Spawn boomerang projectile
-- Wait for max distance
-- Verify returns and despawns near owner
```

### Teleport
```lua
-- Test: Teleport bolt moves player
-- Record player position
-- Cast teleport bolt at wall
-- Verify player position changed to impact point
```

### Divide
```lua
-- Test: Divide by 2 creates duplicates
-- Cast spark bolt with divide_by_2
-- Verify 2 projectiles spawned (not 1)
```

---

## 9. Files Modified Summary

| File | Changes |
|------|---------|
| `assets/scripts/combat/projectile_system.lua` | friendlyFire, new movement types |
| `assets/scripts/wand/wand_actions.lua` | formations, teleport, divide spawn loop |
| `assets/scripts/wand/wand_modifiers.lua` | formation field, divideCount, calculateFormationAngles |
| `assets/scripts/data/cards.lua` | New card definitions |

---

## 10. Rollback Plan

If issues arise:
1. All changes are additive (new fields, new functions)
2. Existing behavior unchanged unless `friendlyFire = true` or `formation` set
3. Can revert individual features by removing card definitions
