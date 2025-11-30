--[[
    Lightweight validation that wand execution consults card upgrade behaviors and
    player-facing behavior hooks at runtime.

    Run with: lua assets/scripts/tests/wand_upgrade_behavior_test.lua
]]

package.path = package.path .. ";./?.lua;./assets/scripts/?.lua"

-- Globals/stubs
_G.log_debug = function() end
_G.entt_null = -1
component_cache = { get = function() return nil end }
Transform = {}

-- Stub projectile system so we can capture spawn params and explosions
local spawned = {}
local explosions = {}
package.loaded["combat.projectile_system"] = {
    MovementType = {
        STRAIGHT = "straight",
        HOMING = "homing",
        ARC = "arc"
    },
    CollisionBehavior = {
        DESTROY = "destroy",
        PIERCE = "pierce",
        BOUNCE = "bounce",
        EXPLODE = "explode",
        PASS_THROUGH = "pass_through"
    },
    spawn = function(params)
        spawned[#spawned + 1] = params
        return #spawned
    end,
    getProjectileScript = function()
        return {
            projectileData = { damage = 10, damageMultiplier = 1.0 },
            projectileBehavior = {}
        }
    end,
    handleExplosion = function(projectile, data, behavior)
        explosions[#explosions + 1] = { projectile = projectile, behavior = behavior }
    end
}

local WandActions = require("wand.wand_actions")
local WandModifiers = require("wand.wand_modifiers")
local BehaviorRegistry = require("wand.card_behavior_registry")

-- Register a behavior to verify registry hooks run
local behaviorCalled = false
BehaviorRegistry.register("test_behavior", function(ctx)
    behaviorCalled = true
    return ctx
end, "test behavior for upgrade plumbing")

local function resetState()
    spawned = {}
    explosions = {}
    behaviorCalled = false
end

local function testUpgradeBehaviorsFlowIntoSpawnAndHit()
    resetState()

    local actionCard = {
        type = "action",
        id = "ACTION_UPGRADE_BEHAVIOR_TEST",
        damage = 12,
        projectile_speed = 300,
        lifetime = 1000,
        custom_behaviors = {
            on_hit_explosion = { radius = 42, damage_mult = 1.5 },
            registry_hook = { behavior_id = "test_behavior" }
        }
    }

    local modifiers = WandModifiers.createAggregate()
    local context = {
        playerPosition = { x = 0, y = 0 },
        playerAngle = 0,
        playerEntity = 1,
        findNearestEnemy = function() return nil end
    }

    WandActions.executeProjectileAction(actionCard, modifiers, context)

    assert(#spawned == 1, "expected a projectile to spawn")
    local spawnParams = spawned[1]

    assert(spawnParams.collisionBehavior == package.loaded["combat.projectile_system"].CollisionBehavior.EXPLODE,
        "upgrade behavior should force explosive collision")
    assert(spawnParams.explosionRadius == 42, "explosion radius should come from upgrade behavior")
    assert(spawnParams.explosionDamageMult == 1.5, "explosion damage multiplier should come from upgrade behavior")

    -- Simulate a hit to ensure behavior registry is consulted
    assert(type(spawnParams.onHit) == "function", "onHit callback should be present")
    spawnParams.onHit(1, 99, { damage = 25 })

    assert(behaviorCalled, "behavior registry-backed upgrade should execute on hit")
end

local function main()
    testUpgradeBehaviorsFlowIntoSpawnAndHit()
    print("wand_upgrade_behavior_test: PASS")
end

main()
