# Enemy Projectiles Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add enemy projectiles that can hit the player with full parity (damage, knockback, status effects).

**Architecture:** Enemy projectile presets live in `projectiles.lua`. Enemy scripts own firing logic using timers and call `ProjectileSystem.spawn()` with `collideWithTags = {"player", "WORLD"}`. Aiming utilities provide reusable targeting strategies.

**Tech Stack:** Lua, ProjectileSystem, timer system, physics collision system, JokerSystem events

---

## Task 1: Add Enemy Projectile Presets

**Files:**
- Modify: `assets/scripts/data/projectiles.lua`

**Step 1: Add enemy projectile presets to projectiles.lua**

Open `assets/scripts/data/projectiles.lua` and add after the existing `holy_beam` entry (before the closing `}`):

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

    enemy_ice_shard = {
        id = "enemy_ice_shard",
        speed = 350,
        damage_type = "ice",
        movement = "straight",
        collision = "destroy",
        lifetime = 2000,
        on_hit_effect = "freeze",
        on_hit_duration = 1500,
        enemy = true,
        tags = { "Ice", "Projectile" },
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

    enemy_spread_shot = {
        id = "enemy_spread_shot",
        speed = 280,
        damage_type = "physical",
        movement = "straight",
        collision = "destroy",
        lifetime = 2000,
        enemy = true,
        tags = { "Projectile" },
    },
```

**Step 2: Verify syntax is correct**

Run: `luac -p assets/scripts/data/projectiles.lua`

Expected: No output (successful parse)

**Step 3: Commit**

```bash
git add assets/scripts/data/projectiles.lua
git commit -m "feat: add enemy projectile presets"
```

---

## Task 2: Create Enemy Aiming Utilities

**Files:**
- Create: `assets/scripts/combat/enemy_aiming.lua`

**Step 1: Create the enemy aiming module**

Create file `assets/scripts/combat/enemy_aiming.lua`:

```lua
--[[
================================================================================
ENEMY AIMING UTILITIES
================================================================================
Provides reusable aiming strategies for enemy projectiles.

Strategies:
- direct: Shoot at target's current position
- leadTarget: Predict where target will be
- spread: Multiple projectiles in a cone
- spiral: Circular pattern (for bosses)
================================================================================
]]

local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")

local EnemyAiming = {}

--- Get center position of an entity
--- @param entity number Entity ID
--- @return table|nil {x, y} or nil if invalid
function EnemyAiming.getEntityCenter(entity)
    if not entity or not entity_cache.valid(entity) then
        return nil
    end

    local transform = component_cache.get(entity, Transform)
    if not transform then
        return nil
    end

    return {
        x = transform.actualX + (transform.actualW or 0) * 0.5,
        y = transform.actualY + (transform.actualH or 0) * 0.5
    }
end

--- Direct shot at current position (basic enemies)
--- @param shooterPos table {x, y}
--- @param targetPos table {x, y}
--- @return table {x, y} normalized direction
function EnemyAiming.direct(shooterPos, targetPos)
    local dx = targetPos.x - shooterPos.x
    local dy = targetPos.y - shooterPos.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < 0.001 then
        return { x = 1, y = 0 }
    end

    return { x = dx / dist, y = dy / dist }
end

--- Lead the target based on velocity (elite enemies)
--- @param shooterPos table {x, y}
--- @param targetPos table {x, y}
--- @param targetVelocity table {x, y} target's current velocity
--- @param projectileSpeed number speed of projectile
--- @return table {x, y} normalized direction
function EnemyAiming.leadTarget(shooterPos, targetPos, targetVelocity, projectileSpeed)
    local dx = targetPos.x - shooterPos.x
    local dy = targetPos.y - shooterPos.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < 0.001 or projectileSpeed < 0.001 then
        return EnemyAiming.direct(shooterPos, targetPos)
    end

    -- Predict where target will be when projectile arrives
    local timeToHit = dist / projectileSpeed
    local predictedX = targetPos.x + (targetVelocity.x or 0) * timeToHit
    local predictedY = targetPos.y + (targetVelocity.y or 0) * timeToHit

    return EnemyAiming.direct(shooterPos, { x = predictedX, y = predictedY })
end

--- Spread shot - multiple directions in a cone (shotgun-style enemies)
--- @param shooterPos table {x, y}
--- @param targetPos table {x, y}
--- @param spreadAngleDegrees number total spread angle in degrees
--- @param count number number of projectiles
--- @return table array of {x, y} directions
function EnemyAiming.spread(shooterPos, targetPos, spreadAngleDegrees, count)
    local baseDir = EnemyAiming.direct(shooterPos, targetPos)
    local baseAngle = math.atan(baseDir.y, baseDir.x)

    local directions = {}

    if count == 1 then
        directions[1] = baseDir
        return directions
    end

    local halfSpread = math.rad(spreadAngleDegrees) / 2
    local step = math.rad(spreadAngleDegrees) / (count - 1)

    for i = 0, count - 1 do
        local angle = baseAngle - halfSpread + (step * i)
        directions[#directions + 1] = {
            x = math.cos(angle),
            y = math.sin(angle)
        }
    end

    return directions
end

--- Spiral pattern - radial burst (boss attacks)
--- @param baseAngle number starting angle in radians
--- @param count number number of projectiles
--- @param spacingDegrees number degrees between each projectile
--- @return table array of {x, y} directions
function EnemyAiming.spiral(baseAngle, count, spacingDegrees)
    local directions = {}

    for i = 0, count - 1 do
        local angle = baseAngle + math.rad(spacingDegrees * i)
        directions[#directions + 1] = {
            x = math.cos(angle),
            y = math.sin(angle)
        }
    end

    return directions
end

--- Ring pattern - evenly spaced around a circle
--- @param count number number of projectiles
--- @param offsetAngle number starting angle offset in radians (default 0)
--- @return table array of {x, y} directions
function EnemyAiming.ring(count, offsetAngle)
    offsetAngle = offsetAngle or 0
    local directions = {}
    local angleStep = (2 * math.pi) / count

    for i = 0, count - 1 do
        local angle = offsetAngle + (angleStep * i)
        directions[#directions + 1] = {
            x = math.cos(angle),
            y = math.sin(angle)
        }
    end

    return directions
end

--- Calculate distance between two positions
--- @param pos1 table {x, y}
--- @param pos2 table {x, y}
--- @return number distance
function EnemyAiming.distance(pos1, pos2)
    local dx = pos2.x - pos1.x
    local dy = pos2.y - pos1.y
    return math.sqrt(dx * dx + dy * dy)
end

return EnemyAiming
```

**Step 2: Verify syntax is correct**

Run: `luac -p assets/scripts/combat/enemy_aiming.lua`

Expected: No output (successful parse)

**Step 3: Commit**

```bash
git add assets/scripts/combat/enemy_aiming.lua
git commit -m "feat: add enemy aiming utilities module"
```

---

## Task 3: Create Enemy Shooter Mixin

**Files:**
- Create: `assets/scripts/combat/enemy_shooter.lua`

**Step 1: Create reusable shooting behavior mixin**

Create file `assets/scripts/combat/enemy_shooter.lua`:

```lua
--[[
================================================================================
ENEMY SHOOTER MIXIN
================================================================================
Provides reusable projectile firing behavior for enemy scripts.

Usage in enemy script:
    local EnemyShooter = require("combat.enemy_shooter")

    function MyEnemy:init()
        EnemyShooter.setup(self, {
            fireRate = 2.0,
            fireRange = 300,
            projectilePreset = "enemy_basic_shot",
            damage = 10,
            aimStrategy = "direct"  -- or "lead", "spread"
        })
    end

    function MyEnemy:onDestroy()
        EnemyShooter.cleanup(self)
    end
================================================================================
]]

local timer = require("core.timer")
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
local EnemyAiming = require("combat.enemy_aiming")
local ProjectileSystem = require("combat.projectile_system")
local Projectiles = require("data.projectiles")

local EnemyShooter = {}

-- Get player entity (uses WandExecutor if available)
local function getPlayerEntity()
    local WandExecutor = rawget(_G, "WandExecutor")
    if WandExecutor and WandExecutor.getPlayerEntity then
        return WandExecutor.getPlayerEntity()
    end
    -- Fallback to global survivorEntity
    return rawget(_G, "survivorEntity")
end

-- Get player velocity for lead targeting
local function getPlayerVelocity(playerEntity)
    if not playerEntity or not entity_cache.valid(playerEntity) then
        return { x = 0, y = 0 }
    end

    local PhysicsManager = require("core.physics_manager")
    local world = PhysicsManager.get_world("world")

    if world and physics and physics.GetVelocity then
        local vel = physics.GetVelocity(world, playerEntity)
        if vel then
            return { x = vel.x or 0, y = vel.y or 0 }
        end
    end

    return { x = 0, y = 0 }
end

--- Setup shooting behavior on an enemy script
--- @param enemyScript table The enemy's script table (self)
--- @param config table Configuration options
function EnemyShooter.setup(enemyScript, config)
    config = config or {}

    -- Store config on script
    enemyScript._shooterConfig = {
        fireRate = config.fireRate or 2.0,
        fireRange = config.fireRange or 300,
        projectilePreset = config.projectilePreset or "enemy_basic_shot",
        damage = config.damage or 10,
        aimStrategy = config.aimStrategy or "direct",
        spreadAngle = config.spreadAngle or 30,
        spreadCount = config.spreadCount or 3,
        enabled = true,
    }

    -- Start firing timer
    EnemyShooter.startFiringTimer(enemyScript)
end

--- Start the firing timer for an enemy
--- @param enemyScript table The enemy's script table
function EnemyShooter.startFiringTimer(enemyScript)
    local config = enemyScript._shooterConfig
    if not config then return end

    local entityId = enemyScript._eid or enemyScript.entityId
    if not entityId then return end

    local timerTag = "enemy_fire_" .. tostring(entityId)

    timer.every_opts({
        delay = config.fireRate,
        action = function()
            EnemyShooter.tryFire(enemyScript)
        end,
        tag = timerTag
    })

    enemyScript._shooterTimerTag = timerTag
end

--- Attempt to fire at player (checks range and validity)
--- @param enemyScript table The enemy's script table
function EnemyShooter.tryFire(enemyScript)
    local config = enemyScript._shooterConfig
    if not config or not config.enabled then return end

    local entityId = enemyScript._eid or enemyScript.entityId
    if not entityId or not entity_cache.valid(entityId) then return end

    local playerEntity = getPlayerEntity()
    if not playerEntity or not entity_cache.valid(playerEntity) then return end

    -- Get positions
    local myPos = EnemyAiming.getEntityCenter(entityId)
    local playerPos = EnemyAiming.getEntityCenter(playerEntity)

    if not myPos or not playerPos then return end

    -- Range check
    local dist = EnemyAiming.distance(myPos, playerPos)
    if dist > config.fireRange then return end

    -- Fire based on aim strategy
    EnemyShooter.fire(enemyScript, myPos, playerPos, playerEntity)
end

--- Fire projectile(s) at target
--- @param enemyScript table The enemy's script table
--- @param myPos table {x, y} shooter position
--- @param targetPos table {x, y} target position
--- @param targetEntity number target entity ID
function EnemyShooter.fire(enemyScript, myPos, targetPos, targetEntity)
    local config = enemyScript._shooterConfig
    local preset = Projectiles[config.projectilePreset]

    if not preset then
        log_error("Unknown projectile preset: " .. tostring(config.projectilePreset))
        return
    end

    local entityId = enemyScript._eid or enemyScript.entityId
    local directions = {}

    -- Determine directions based on aim strategy
    if config.aimStrategy == "lead" then
        local velocity = getPlayerVelocity(targetEntity)
        directions[1] = EnemyAiming.leadTarget(myPos, targetPos, velocity, preset.speed)

    elseif config.aimStrategy == "spread" then
        directions = EnemyAiming.spread(myPos, targetPos, config.spreadAngle, config.spreadCount)

    elseif config.aimStrategy == "ring" then
        directions = EnemyAiming.ring(config.spreadCount or 8)

    else -- "direct" or default
        directions[1] = EnemyAiming.direct(myPos, targetPos)
    end

    -- Spawn projectile for each direction
    for _, direction in ipairs(directions) do
        EnemyShooter.spawnProjectile(enemyScript, myPos, direction, preset, targetEntity)
    end
end

--- Spawn a single projectile
--- @param enemyScript table The enemy's script table
--- @param position table {x, y} spawn position
--- @param direction table {x, y} normalized direction
--- @param preset table Projectile preset from projectiles.lua
--- @param targetEntity number Target entity (for homing)
function EnemyShooter.spawnProjectile(enemyScript, position, direction, preset, targetEntity)
    local config = enemyScript._shooterConfig
    local entityId = enemyScript._eid or enemyScript.entityId

    local spawnParams = {
        position = position,
        positionIsCenter = true,
        direction = direction,
        baseSpeed = preset.speed,
        damage = config.damage,
        damageType = preset.damage_type,
        owner = entityId,
        faction = "enemy",

        -- KEY: Target the player, not enemies
        collideWithTags = { "player", "WORLD" },

        movementType = preset.movement,
        collisionBehavior = preset.collision,
        lifetime = (preset.lifetime or 3000) / 1000,

        -- Homing parameters
        homingTarget = (preset.movement == "homing") and targetEntity or nil,
        homingStrength = preset.homing_strength,

        -- Status effects
        onHitEffect = preset.on_hit_effect,
        onHitDuration = preset.on_hit_duration,
    }

    ProjectileSystem.spawn(spawnParams)
end

--- Enable/disable shooting for an enemy
--- @param enemyScript table The enemy's script table
--- @param enabled boolean Whether shooting is enabled
function EnemyShooter.setEnabled(enemyScript, enabled)
    if enemyScript._shooterConfig then
        enemyScript._shooterConfig.enabled = enabled
    end
end

--- Update configuration at runtime
--- @param enemyScript table The enemy's script table
--- @param updates table Partial config updates
function EnemyShooter.updateConfig(enemyScript, updates)
    if not enemyScript._shooterConfig then return end

    for key, value in pairs(updates) do
        enemyScript._shooterConfig[key] = value
    end
end

--- Cleanup when enemy is destroyed
--- @param enemyScript table The enemy's script table
function EnemyShooter.cleanup(enemyScript)
    if enemyScript._shooterTimerTag then
        timer.cancel(enemyScript._shooterTimerTag)
        enemyScript._shooterTimerTag = nil
    end
    enemyScript._shooterConfig = nil
end

return EnemyShooter
```

**Step 2: Verify syntax is correct**

Run: `luac -p assets/scripts/combat/enemy_shooter.lua`

Expected: No output (successful parse)

**Step 3: Commit**

```bash
git add assets/scripts/combat/enemy_shooter.lua
git commit -m "feat: add enemy shooter mixin for reusable firing behavior"
```

---

## Task 4: Enable Projectile-Player Collision

**Files:**
- Modify: `assets/scripts/combat/projectile_system.lua`

**Step 1: Register "player" as a collision target**

The ProjectileSystem already dynamically registers collision targets via `registerCollisionTargets()`. When an enemy projectile is spawned with `collideWithTags = {"player", "WORLD"}`, the system will automatically set up the collision callback.

However, we need to ensure the collision callback triggers the joker system. Find the `applyDamage` function (around line 1675) and add joker event emission.

In `assets/scripts/combat/projectile_system.lua`, locate the `applyDamage` function and modify it to emit a joker event when the player is hit. Find this section (around line 1697-1705):

```lua
        CombatSystem.Game.Effects.deal_damage {
            components = { { type = dmgType, amount = finalDamage } },
            tags = { projectile = true }
        }(ctx, sourceCombatActor or targetCombatActor, targetCombatActor)
        return targetCombatActor, sourceCombatActor
```

Replace it with:

```lua
        CombatSystem.Game.Effects.deal_damage {
            components = { { type = dmgType, amount = finalDamage } },
            tags = { projectile = true }
        }(ctx, sourceCombatActor or targetCombatActor, targetCombatActor)

        -- Emit joker event if player was hit by enemy projectile
        if data.faction == "enemy" and targetCombatActor and targetCombatActor.side == 1 then
            local JokerSystem = require("wand.joker_system")
            local effects = JokerSystem.trigger_event("on_player_damaged", {
                damage = finalDamage,
                damage_type = dmgType,
                source = "enemy_projectile",
                attacker = data.owner,
                player = targetCombatActor,
            })

            -- Track avatar progress
            local AvatarSystem = require("wand.avatar_system")
            local playerScript = getScriptTableFromEntityID(targetEntity)
            if playerScript then
                AvatarSystem.record_progress(playerScript, "hp_lost", finalDamage)
            end
        end

        return targetCombatActor, sourceCombatActor
```

**Step 2: Verify syntax is correct**

Run: `luac -p assets/scripts/combat/projectile_system.lua`

Expected: No output (successful parse)

**Step 3: Commit**

```bash
git add assets/scripts/combat/projectile_system.lua
git commit -m "feat: emit joker event and track avatar progress on player hit"
```

---

## Task 5: Add Defensive Jokers

**Files:**
- Modify: `assets/scripts/data/jokers.lua`

**Step 1: Add jokers that react to player damage**

Open `assets/scripts/data/jokers.lua` and add these defensive jokers before the closing `}`:

```lua
    --===========================================================================
    -- DEFENSIVE JOKERS (React to on_player_damaged)
    --===========================================================================

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
    },

    flame_ward = {
        id = "flame_ward",
        name = "Flame Ward",
        description = "Immune to Fire damage from projectiles.",
        rarity = "Uncommon",
        calculate = function(self, context)
            if context.event == "on_player_damaged"
               and context.source == "enemy_projectile"
               and context.damage_type == "fire" then
                return {
                    damage_reduction = context.damage,
                    message = "Flame Ward!"
                }
            end
        end
    },

    thorns = {
        id = "thorns",
        name = "Thorns",
        description = "Reflect 50% of projectile damage back to attacker.",
        rarity = "Rare",
        calculate = function(self, context)
            if context.event == "on_player_damaged" and context.source == "enemy_projectile" then
                return {
                    reflect_damage = math.floor(context.damage * 0.5),
                    message = "Thorns!"
                }
            end
        end
    },

    survival_instinct = {
        id = "survival_instinct",
        name = "Survival Instinct",
        description = "+20% damage for 3s after taking projectile damage.",
        rarity = "Uncommon",
        calculate = function(self, context)
            if context.event == "on_player_damaged" and context.source == "enemy_projectile" then
                return {
                    buff = { stat = "damage_mult", value = 1.2, duration = 3.0 },
                    message = "Survival!"
                }
            end
        end
    },
```

**Step 2: Verify syntax is correct**

Run: `luac -p assets/scripts/data/jokers.lua`

Expected: No output (successful parse)

**Step 3: Commit**

```bash
git add assets/scripts/data/jokers.lua
git commit -m "feat: add defensive jokers for enemy projectile damage"
```

---

## Task 6: Create Example Shooting Enemy

**Files:**
- Create: `assets/scripts/ai/enemies/ranged_enemy_example.lua`

**Step 1: Create example enemy that uses the shooter mixin**

Create directory if needed, then create file `assets/scripts/ai/enemies/ranged_enemy_example.lua`:

```lua
--[[
================================================================================
RANGED ENEMY EXAMPLE
================================================================================
Example enemy that uses EnemyShooter mixin to fire projectiles at the player.

This serves as a template for creating new ranged enemies.
================================================================================
]]

local Node = require("monobehavior.behavior_script_v2")
local EnemyShooter = require("combat.enemy_shooter")
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")

local RangedEnemy = Node:extend()

-- Default configuration (can be overridden per-instance)
RangedEnemy.defaults = {
    fireRate = 2.0,
    fireRange = 300,
    projectilePreset = "enemy_basic_shot",
    damage = 10,
    aimStrategy = "direct",
}

function RangedEnemy:init()
    -- Called when script is created (before attach_ecs)
end

function RangedEnemy:on_attach()
    -- Called after attach_ecs - entity is now valid
    local config = self.config or self.defaults

    EnemyShooter.setup(self, {
        fireRate = config.fireRate or self.defaults.fireRate,
        fireRange = config.fireRange or self.defaults.fireRange,
        projectilePreset = config.projectilePreset or self.defaults.projectilePreset,
        damage = config.damage or self.defaults.damage,
        aimStrategy = config.aimStrategy or self.defaults.aimStrategy,
        spreadAngle = config.spreadAngle,
        spreadCount = config.spreadCount,
    })

    log_debug("[RangedEnemy] Setup complete for entity", self._eid)
end

function RangedEnemy:update(dt)
    -- Optional: Add custom update logic here
    -- The EnemyShooter handles firing via timers
end

function RangedEnemy:on_destroy()
    -- Clean up shooter timer
    EnemyShooter.cleanup(self)
    log_debug("[RangedEnemy] Cleaned up entity", self._eid)
end

--[[
================================================================================
FACTORY FUNCTION
================================================================================
Creates a ranged enemy with the specified configuration.

Usage:
    local RangedEnemy = require("ai.enemies.ranged_enemy_example")
    local entity, script = RangedEnemy.create(x, y, {
        fireRate = 1.5,
        projectilePreset = "enemy_fireball",
        damage = 15,
        aimStrategy = "lead",
    })
================================================================================
]]

function RangedEnemy.create(x, y, config)
    local animation_system = require("core.animation_system")

    -- Create entity with sprite (use a placeholder - replace with actual enemy sprite)
    local entity = animation_system.createAnimatedObjectWithTransform(
        "kobold",  -- Replace with actual enemy sprite
        true
    )

    if not entity or entity == entt_null then
        log_error("[RangedEnemy] Failed to create entity")
        return nil, nil
    end

    -- Set position
    local transform = component_cache.get(entity, Transform)
    if transform then
        transform.actualX = x
        transform.actualY = y
        transform.actualW = 32
        transform.actualH = 32
    end

    -- Create and attach script
    local script = RangedEnemy {}
    script.config = config or {}
    script:attach_ecs { create_new = false, existing_entity = entity }

    -- Trigger on_attach manually since it may not be called automatically
    if script.on_attach then
        script:on_attach()
    end

    return entity, script
end

return RangedEnemy
```

**Step 2: Verify syntax is correct**

Run: `luac -p assets/scripts/ai/enemies/ranged_enemy_example.lua`

Expected: No output (successful parse)

**Step 3: Commit**

```bash
git add assets/scripts/ai/enemies/ranged_enemy_example.lua
git commit -m "feat: add ranged enemy example using shooter mixin"
```

---

## Task 7: Integration Test Script

**Files:**
- Create: `assets/scripts/tests/test_enemy_projectiles.lua`

**Step 1: Create manual test script**

Create file `assets/scripts/tests/test_enemy_projectiles.lua`:

```lua
--[[
================================================================================
ENEMY PROJECTILES TEST SCRIPT
================================================================================
Manual test script to verify enemy projectile system works.

Run in-game via console or require from a test file.

Usage:
    local test = require("tests.test_enemy_projectiles")
    test.run_all()
================================================================================
]]

local EnemyAiming = require("combat.enemy_aiming")
local EnemyShooter = require("combat.enemy_shooter")
local ProjectileSystem = require("combat.projectile_system")
local Projectiles = require("data.projectiles")

local TestEnemyProjectiles = {}

local function log_test(name, passed, message)
    local status = passed and "PASS" or "FAIL"
    print(string.format("[%s] %s: %s", status, name, message or ""))
end

--- Test that enemy projectile presets exist
function TestEnemyProjectiles.test_presets_exist()
    local required_presets = {
        "enemy_basic_shot",
        "enemy_fireball",
        "enemy_ice_shard",
        "enemy_homing_orb",
        "enemy_spread_shot",
    }

    local all_found = true
    for _, preset_id in ipairs(required_presets) do
        if not Projectiles[preset_id] then
            log_test("presets_exist", false, "Missing preset: " .. preset_id)
            all_found = false
        end
    end

    if all_found then
        log_test("presets_exist", true, "All enemy presets found")
    end

    return all_found
end

--- Test that enemy presets have enemy flag
function TestEnemyProjectiles.test_presets_have_enemy_flag()
    local all_flagged = true
    for id, preset in pairs(Projectiles) do
        if id:match("^enemy_") and not preset.enemy then
            log_test("enemy_flag", false, "Missing enemy flag on: " .. id)
            all_flagged = false
        end
    end

    if all_flagged then
        log_test("enemy_flag", true, "All enemy presets have enemy=true")
    end

    return all_flagged
end

--- Test EnemyAiming.direct
function TestEnemyProjectiles.test_aiming_direct()
    local shooter = { x = 0, y = 0 }
    local target = { x = 100, y = 0 }

    local dir = EnemyAiming.direct(shooter, target)

    local passed = math.abs(dir.x - 1) < 0.001 and math.abs(dir.y) < 0.001
    log_test("aiming_direct", passed, string.format("dir={%.2f, %.2f}", dir.x, dir.y))

    return passed
end

--- Test EnemyAiming.spread
function TestEnemyProjectiles.test_aiming_spread()
    local shooter = { x = 0, y = 0 }
    local target = { x = 100, y = 0 }

    local dirs = EnemyAiming.spread(shooter, target, 30, 3)

    local passed = #dirs == 3
    log_test("aiming_spread", passed, "Got " .. #dirs .. " directions")

    return passed
end

--- Test EnemyAiming.ring
function TestEnemyProjectiles.test_aiming_ring()
    local dirs = EnemyAiming.ring(8)

    local passed = #dirs == 8
    log_test("aiming_ring", passed, "Got " .. #dirs .. " directions")

    return passed
end

--- Run all tests
function TestEnemyProjectiles.run_all()
    print("\n=== Enemy Projectiles Test Suite ===\n")

    local tests = {
        TestEnemyProjectiles.test_presets_exist,
        TestEnemyProjectiles.test_presets_have_enemy_flag,
        TestEnemyProjectiles.test_aiming_direct,
        TestEnemyProjectiles.test_aiming_spread,
        TestEnemyProjectiles.test_aiming_ring,
    }

    local passed = 0
    local failed = 0

    for _, test_fn in ipairs(tests) do
        local ok, result = pcall(test_fn)
        if ok and result then
            passed = passed + 1
        else
            failed = failed + 1
            if not ok then
                print("  Error: " .. tostring(result))
            end
        end
    end

    print(string.format("\n=== Results: %d passed, %d failed ===\n", passed, failed))

    return failed == 0
end

return TestEnemyProjectiles
```

**Step 2: Verify syntax is correct**

Run: `luac -p assets/scripts/tests/test_enemy_projectiles.lua`

Expected: No output (successful parse)

**Step 3: Commit**

```bash
git add assets/scripts/tests/test_enemy_projectiles.lua
git commit -m "test: add enemy projectiles test script"
```

---

## Task 8: Update Design Document Status

**Files:**
- Modify: `docs/plans/2025-12-15-enemy-projectiles-design.md`

**Step 1: Mark design as implemented**

At the top of `docs/plans/2025-12-15-enemy-projectiles-design.md`, change:

```markdown
**Status:** Approved
```

To:

```markdown
**Status:** Implemented
```

**Step 2: Commit**

```bash
git add docs/plans/2025-12-15-enemy-projectiles-design.md
git commit -m "docs: mark enemy projectiles design as implemented"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Add enemy projectile presets | `data/projectiles.lua` |
| 2 | Create aiming utilities | `combat/enemy_aiming.lua` (new) |
| 3 | Create shooter mixin | `combat/enemy_shooter.lua` (new) |
| 4 | Enable player collision + joker events | `combat/projectile_system.lua` |
| 5 | Add defensive jokers | `data/jokers.lua` |
| 6 | Create example enemy | `ai/enemies/ranged_enemy_example.lua` (new) |
| 7 | Add test script | `tests/test_enemy_projectiles.lua` (new) |
| 8 | Update design doc status | `docs/plans/...design.md` |

**After completing all tasks:**
1. Run test script: `require("tests.test_enemy_projectiles").run_all()`
2. Build and run game
3. Spawn a ranged enemy and verify it shoots at player
4. Verify projectile collision damages player

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
