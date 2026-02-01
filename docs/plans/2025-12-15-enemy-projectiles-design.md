# Enemy Projectiles Design

**Date:** 2025-12-15
**Status:** Implemented

## Overview

Add enemy projectiles that can hit the player, with full parity to player projectiles (damage, knockback, status effects). Different enemy types use different aiming strategies and firing patterns.

## Design Decisions

| Decision | Choice |
|----------|--------|
| Hit behavior | Full parity - damage, knockback, status effects |
| Aiming | Mixed by enemy type (direct, lead target, patterns) |
| Firing timing | Timer-based, configurable per enemy type |
| Projectile definitions | In `projectiles.lua` with `enemy = true` flag |
| Collision detection | Target-based using `collideWithTags` |
| Firing logic | In enemy AI/behavior scripts |

## Implementation Details

### 1. Projectile Definitions

Add enemy projectile presets to `assets/scripts/data/projectiles.lua`:

```lua
--===========================================================================
-- ENEMY PROJECTILES
--===========================================================================
enemy_basic_shot = {
    id = "enemy_basic_shot",
    speed = 300,
    damage_type = "physical",
    movement = "straight",
    collision = "destroy",
    lifetime = 3000,
    enemy = true,
    tags = { "Projectile" },
},

enemy_fireball = {
    id = "enemy_fireball",
    speed = 250,
    damage_type = "fire",
    movement = "straight",
    collision = "destroy",
    lifetime = 2500,
    on_hit_effect = "burn",
    on_hit_duration = 2000,
    enemy = true,
    tags = { "Fire", "Projectile" },
},

enemy_homing_orb = {
    id = "enemy_homing_orb",
    speed = 200,
    damage_type = "arcane",
    movement = "homing",
    homing_strength = 4,
    collision = "destroy",
    lifetime = 4000,
    enemy = true,
    tags = { "Arcane", "Projectile" },
},
```

### 2. Spawning Enemy Projectiles

Enemy scripts call `ProjectileSystem.spawn()` directly with `collideWithTags = { "player", "WORLD" }`:

```lua
local ProjectileSystem = require("combat.projectile_system")
local Projectiles = require("data.projectiles")

function EnemyScript:fireAtPlayer()
    local playerEntity = getPlayerEntity()
    if not playerEntity then return end

    local myPos = self:getPosition()
    local playerPos = getEntityCenter(playerEntity)

    -- Calculate direction to player
    local dx = playerPos.x - myPos.x
    local dy = playerPos.y - myPos.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local direction = { x = dx / dist, y = dy / dist }

    local preset = Projectiles.enemy_basic_shot

    ProjectileSystem.spawn({
        position = myPos,
        positionIsCenter = true,
        direction = direction,
        baseSpeed = preset.speed,
        damage = self.attackDamage or 10,
        damageType = preset.damage_type,
        owner = self._eid,
        faction = "enemy",
        collideWithTags = { "player", "WORLD" },
        movementType = preset.movement,
        collisionBehavior = preset.collision,
        lifetime = (preset.lifetime or 3000) / 1000,
        onHitEffect = preset.on_hit_effect,
        onHitDuration = preset.on_hit_duration,
    })
end
```

### 3. Enemy Firing Timers

Each enemy type configures its own fire rate and range:

```lua
local timer = require("core.timer")

EnemyScript.fireRate = 2.0
EnemyScript.fireRange = 300
EnemyScript.projectilePreset = "enemy_basic_shot"

function EnemyScript:init()
    self:startFiringTimer()
end

function EnemyScript:startFiringTimer()
    timer.every_opts({
        delay = self.fireRate,
        action = function() self:tryFire() end,
        tag = "enemy_fire_" .. tostring(self._eid)
    })
end

function EnemyScript:tryFire()
    if not ensure_entity(self._eid) then return end

    local playerEntity = getPlayerEntity()
    if not playerEntity then return end

    local dist = self:distanceToPlayer()
    if dist > self.fireRange then return end

    self:fireAtPlayer()
end

function EnemyScript:onDestroy()
    timer.cancel("enemy_fire_" .. tostring(self._eid))
end
```

### 4. Aiming Strategies

Create `assets/scripts/combat/enemy_aiming.lua`:

```lua
local EnemyAiming = {}

-- Direct shot at current position (basic enemies)
function EnemyAiming.direct(shooterPos, targetPos, projectileSpeed)
    local dx = targetPos.x - shooterPos.x
    local dy = targetPos.y - shooterPos.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 0.001 then return { x = 1, y = 0 } end
    return { x = dx / dist, y = dy / dist }
end

-- Lead the target based on velocity (elite enemies)
function EnemyAiming.leadTarget(shooterPos, targetPos, targetVelocity, projectileSpeed)
    local dx = targetPos.x - shooterPos.x
    local dy = targetPos.y - shooterPos.y
    local dist = math.sqrt(dx * dx + dy * dy)

    local timeToHit = dist / projectileSpeed
    local predictedX = targetPos.x + (targetVelocity.x or 0) * timeToHit
    local predictedY = targetPos.y + (targetVelocity.y or 0) * timeToHit

    return EnemyAiming.direct(shooterPos, { x = predictedX, y = predictedY }, projectileSpeed)
end

-- Spread shot (shotgun-style enemies)
function EnemyAiming.spread(shooterPos, targetPos, projectileSpeed, spreadAngle, count)
    local baseDir = EnemyAiming.direct(shooterPos, targetPos, projectileSpeed)
    local baseAngle = math.atan(baseDir.y, baseDir.x)

    local directions = {}
    local halfSpread = math.rad(spreadAngle) / 2
    local step = math.rad(spreadAngle) / (count - 1)

    for i = 0, count - 1 do
        local angle = baseAngle - halfSpread + (step * i)
        directions[#directions + 1] = {
            x = math.cos(angle),
            y = math.sin(angle)
        }
    end
    return directions
end

-- Spiral pattern (boss attacks)
function EnemyAiming.spiral(shooterPos, baseAngle, count, spacing)
    local directions = {}
    for i = 0, count - 1 do
        local angle = baseAngle + math.rad(spacing * i)
        directions[#directions + 1] = {
            x = math.cos(angle),
            y = math.sin(angle)
        }
    end
    return directions
end

return EnemyAiming
```

### 5. Joker Integration

Add `"on_player_damaged"` event when player is hit. Example defensive joker:

```lua
iron_skin = {
    id = "iron_skin",
    name = "Iron Skin",
    description = "Reduce projectile damage by 5.",
    rarity = "Common",
    calculate = function(self, context)
        if context.event == "on_player_damaged" and context.source == "enemy_projectile" then
            return {
                damage_reduction = 5,
                message = "Iron Skin!"
            }
        end
    end
}
```

### 6. Avatar Progress Tracking

Call `AvatarSystem.record_progress()` when player takes damage:

```lua
local AvatarSystem = require("wand.avatar_system")
AvatarSystem.record_progress(playerScript, "hp_lost", finalDamage)
```

## Files to Create/Modify

| File | Change |
|------|--------|
| `assets/scripts/data/projectiles.lua` | Add enemy projectile presets |
| `assets/scripts/combat/enemy_aiming.lua` | **NEW** - Aiming utilities |
| `assets/scripts/data/jokers.lua` | Add defensive jokers |
| Enemy behavior scripts | Add firing logic |
| `assets/scripts/combat/projectile_system.lua` | Emit joker event on player hit |

## What Already Works

- Physics collision detection via `collideWithTags`
- Damage application through combat system
- Status effects (`on_hit_effect`)
- Projectile lifetime/despawn
- Visual rendering
- `onHit` / `onDestroy` callbacks

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
