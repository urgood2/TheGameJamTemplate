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
