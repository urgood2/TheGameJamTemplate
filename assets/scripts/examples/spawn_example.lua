--[[
================================================================================
SPAWN MODULE USAGE EXAMPLES
================================================================================
Demonstrates how to use the spawn module for one-line entity creation.

This file serves as documentation and can be loaded in-game to test spawning.
]]

local spawn = require("core.spawn")
local signal = require("external.hump.signal")

local SpawnExample = {}

--------------------------------------------------------------------------------
-- EXAMPLE 1: Basic Enemy Spawning
--------------------------------------------------------------------------------

function SpawnExample.spawn_basic_enemies()
    print("\n=== Example 1: Basic Enemy Spawning ===")

    -- Spawn a kobold at position (100, 200)
    local kobold, kobold_script = spawn.enemy("kobold", 100, 200)
    print("Spawned kobold entity:", kobold)
    print("  Health:", kobold_script.health)
    print("  Damage:", kobold_script.damage)

    -- Spawn a slime at position (200, 200)
    local slime = spawn.enemy("slime", 200, 200)
    print("Spawned slime entity:", slime)

    -- Spawn a skeleton at position (300, 200)
    local skeleton = spawn.enemy("skeleton", 300, 200)
    print("Spawned skeleton entity:", skeleton)
end

--------------------------------------------------------------------------------
-- EXAMPLE 2: Enemy Spawning with Overrides
--------------------------------------------------------------------------------

function SpawnExample.spawn_custom_enemies()
    print("\n=== Example 2: Enemy Spawning with Overrides ===")

    -- Spawn a stronger kobold with custom stats
    local boss_kobold, boss_script = spawn.enemy("kobold", 400, 200, {
        data = {
            health = 200,      -- Override: double health
            max_health = 200,
            damage = 25,       -- Override: more damage
            xp_value = 50,     -- Override: more XP
            gold_value = 20,   -- Override: more gold
        }
    })
    print("Spawned boss kobold entity:", boss_kobold)
    print("  Health:", boss_script.health)
    print("  Damage:", boss_script.damage)
    print("  XP Value:", boss_script.xp_value)

    -- Spawn a fast skeleton (override movement speed)
    local fast_skeleton, fast_script = spawn.enemy("skeleton", 500, 200, {
        data = {
            movement_speed = 5000.0,  -- Override: faster movement
        }
    })
    print("Spawned fast skeleton entity:", fast_skeleton)
    print("  Movement speed:", fast_script.movement_speed)
end

--------------------------------------------------------------------------------
-- EXAMPLE 3: Projectile Spawning
--------------------------------------------------------------------------------

function SpawnExample.spawn_projectiles()
    print("\n=== Example 3: Projectile Spawning ===")

    -- Spawn a basic bolt moving right
    local bolt = spawn.projectile("basic_bolt", 100, 300, 0)  -- 0 radians = right
    print("Spawned basic bolt entity:", bolt)

    -- Spawn a fireball moving at 45 degrees
    local fireball = spawn.projectile("fireball", 200, 300, math.pi / 4, {
        owner = 999,  -- Set owner entity (e.g., player ID)
        damage = 50,  -- Override: more damage
    })
    print("Spawned fireball entity:", fireball)

    -- Spawn an ice shard moving left
    local ice_shard = spawn.projectile("ice_shard", 300, 300, math.pi)  -- pi radians = left
    print("Spawned ice shard entity:", ice_shard)
end

--------------------------------------------------------------------------------
-- EXAMPLE 4: Pickup Spawning
--------------------------------------------------------------------------------

function SpawnExample.spawn_pickups()
    print("\n=== Example 4: Pickup Spawning ===")

    -- Spawn an XP orb
    local exp_orb, exp_script = spawn.pickup("exp_orb", 100, 400)
    print("Spawned exp orb entity:", exp_orb)
    print("  Type:", exp_script.pickup_type)
    print("  Value:", exp_script.value)

    -- Spawn gold coins with custom value
    local gold, gold_script = spawn.pickup("gold_coin", 200, 400, {
        data = {
            value = 25,  -- Override: more gold
        }
    })
    print("Spawned gold coin entity:", gold)
    print("  Value:", gold_script.value)

    -- Spawn a health potion
    local health_potion = spawn.pickup("health_potion", 300, 400)
    print("Spawned health potion entity:", health_potion)
end

--------------------------------------------------------------------------------
-- EXAMPLE 5: Effect Spawning
--------------------------------------------------------------------------------

function SpawnExample.spawn_effects()
    print("\n=== Example 5: Effect Spawning ===")

    -- Spawn an explosion effect
    local explosion, explosion_script = spawn.effect("explosion", 100, 500)
    print("Spawned explosion effect:", explosion)
    print("  Type:", explosion_script.effect_type)
    print("  Lifetime:", explosion_script.lifetime, "ms")

    -- Spawn a hit spark
    local hit_spark = spawn.effect("hit_spark", 200, 500)
    print("Spawned hit spark effect:", hit_spark)

    -- Spawn a smoke puff with custom lifetime
    local smoke, smoke_script = spawn.effect("smoke_puff", 300, 500, {
        data = {
            lifetime = 2000,  -- Override: longer lifetime (2 seconds)
        }
    })
    print("Spawned smoke puff effect:", smoke)
    print("  Lifetime:", smoke_script.lifetime, "ms")
end

--------------------------------------------------------------------------------
-- EXAMPLE 6: Event Listening
--------------------------------------------------------------------------------

function SpawnExample.setup_event_listeners()
    print("\n=== Example 6: Event Listening ===")

    -- Listen for enemy spawns
    signal.register("enemy_spawned", function(entity, data)
        print("Enemy spawned:", entity, "Preset:", data.preset_id)
    end)

    -- Listen for projectile spawns
    signal.register("projectile_spawned", function(entity, data)
        print("Projectile spawned:", entity, "Direction:", data.direction, "Speed:", data.speed)
    end)

    -- Listen for pickup spawns
    signal.register("pickup_spawned", function(entity, data)
        print("Pickup spawned:", entity, "Type:", data.pickup_type)
    end)

    -- Listen for effect spawns
    signal.register("effect_spawned", function(entity, data)
        print("Effect spawned:", entity, "Type:", data.effect_type)
    end)

    print("Event listeners registered!")
end

--------------------------------------------------------------------------------
-- EXAMPLE 7: Batch Spawning
--------------------------------------------------------------------------------

function SpawnExample.spawn_wave_of_enemies()
    print("\n=== Example 7: Batch Spawning ===")

    -- Spawn a wave of enemies in a grid
    local wave_entities = {}
    for i = 0, 4 do
        for j = 0, 2 do
            local x = 100 + i * 80
            local y = 100 + j * 80

            -- Randomly pick enemy type
            local enemy_types = { "kobold", "slime", "skeleton" }
            local enemy_type = enemy_types[math.random(1, #enemy_types)]

            local enemy = spawn.enemy(enemy_type, x, y)
            table.insert(wave_entities, enemy)
        end
    end

    print("Spawned wave of", #wave_entities, "enemies!")
    return wave_entities
end

--------------------------------------------------------------------------------
-- EXAMPLE 8: Advanced Usage with Imports Bundle
--------------------------------------------------------------------------------

function SpawnExample.spawn_with_imports()
    print("\n=== Example 8: Using Spawn with Imports Bundle ===")

    -- Use imports bundle for convenience
    local imports = require("core.imports")
    local Node, animation_system, EntityBuilder, spawn = imports.entity()

    -- Now you have all entity creation tools in one place
    local enemy = spawn.enemy("kobold", 600, 100)
    print("Spawned enemy using imports bundle:", enemy)
end

--------------------------------------------------------------------------------
-- RUN ALL EXAMPLES
--------------------------------------------------------------------------------

function SpawnExample.run_all()
    print("\n╔════════════════════════════════════════════════════════════════╗")
    print("║                    SPAWN MODULE EXAMPLES                       ║")
    print("╚════════════════════════════════════════════════════════════════╝")

    SpawnExample.setup_event_listeners()
    SpawnExample.spawn_basic_enemies()
    SpawnExample.spawn_custom_enemies()
    SpawnExample.spawn_projectiles()
    SpawnExample.spawn_pickups()
    SpawnExample.spawn_effects()
    SpawnExample.spawn_wave_of_enemies()
    SpawnExample.spawn_with_imports()

    print("\n✓ All examples completed!")
end

return SpawnExample
