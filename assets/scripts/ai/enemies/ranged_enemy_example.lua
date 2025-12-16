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
