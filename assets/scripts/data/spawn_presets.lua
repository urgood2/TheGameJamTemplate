--[[
================================================================================
SPAWN PRESETS - Entity Template Data
================================================================================
Data-driven entity preset templates for quick spawning.
Use with EntityBuilder or custom spawn functions.

Organization:
  - enemies: Enemy entity presets
  - projectiles: Projectile entity presets
  - pickups: Pickup/collectible presets
  - effects: Visual effect presets

Design Principles (per CLAUDE.md):
  - Data must be assigned BEFORE attach_ecs
  - Use EntityBuilder patterns
  - Keep presets data-only (no functions)
  - Presets are templates - modify as needed at spawn time

Usage with EntityBuilder:
    local SpawnPresets = require("data.spawn_presets")
    local EntityBuilder = require("core.entity_builder")

    local preset = SpawnPresets.enemies.kobold
    local entity, script = EntityBuilder.create({
        sprite = preset.sprite,
        position = { x = 100, y = 200 },
        size = preset.size,
        shadow = preset.shadow,
        data = preset.data,
        interactive = preset.interactive
    })

    -- Add physics separately if needed
    if preset.physics then
        local PhysicsBuilder = require("core.physics_builder")
        PhysicsBuilder.quick(entity, preset.physics)
    end
]]

local SpawnPresets = {}

--------------------------------------------------------------------------------
-- ENEMIES
--------------------------------------------------------------------------------

SpawnPresets.enemies = {
    -- Basic melee enemy
    kobold = {
        sprite = "b1060.png",
        size = { 32, 32 },
        shadow = true,
        physics = {
            shape = "rectangle",
            tag = "enemy",
            collideWith = { "player", "enemy", "projectile" },
            sensor = false,
            density = 1.0,
            inflate_px = -4
        },
        data = {
            health = 50,
            max_health = 50,
            damage = 10,
            faction = "enemy",
            xp_value = 10,
            gold_value = 2,
            movement_speed = 3000.0,  -- Used for steering
            max_acceleration = 30000.0,
            turn_rate = 6.28,  -- 2*pi rad/s
        },
        interactive = {
            hover = {
                title = "Kobold",
                body = "Basic melee enemy"
            },
            collision = true
        }
    },

    -- Fast, low-health enemy
    slime = {
        sprite = "b1060.png",  -- Reusing sprite, replace with actual slime sprite
        size = { 28, 28 },
        shadow = true,
        physics = {
            shape = "circle",
            tag = "enemy",
            collideWith = { "player", "enemy", "projectile" },
            sensor = false,
            density = 0.8
        },
        data = {
            health = 25,
            max_health = 25,
            damage = 5,
            faction = "enemy",
            xp_value = 5,
            gold_value = 1,
            movement_speed = 4500.0,  -- Faster than kobold
            max_acceleration = 40000.0,
            turn_rate = 9.42,  -- 3*pi rad/s
        },
        interactive = {
            hover = {
                title = "Slime",
                body = "Fast but weak"
            },
            collision = true
        }
    },

    -- Tanky enemy
    skeleton = {
        sprite = "b1060.png",  -- Reusing sprite, replace with actual skeleton sprite
        size = { 36, 36 },
        shadow = true,
        physics = {
            shape = "rectangle",
            tag = "enemy",
            collideWith = { "player", "enemy", "projectile" },
            sensor = false,
            density = 1.5
        },
        data = {
            health = 100,
            max_health = 100,
            damage = 15,
            faction = "enemy",
            xp_value = 20,
            gold_value = 5,
            movement_speed = 2000.0,  -- Slower than kobold
            max_acceleration = 20000.0,
            turn_rate = 4.71,  -- 1.5*pi rad/s
        },
        interactive = {
            hover = {
                title = "Skeleton",
                body = "Slow but durable"
            },
            collision = true
        }
    },
}

--------------------------------------------------------------------------------
-- PROJECTILES
--------------------------------------------------------------------------------

SpawnPresets.projectiles = {
    -- Basic projectile (matches basic_bolt from projectiles.lua)
    basic_bolt = {
        sprite = "b1060.png",  -- Replace with actual projectile sprite
        size = { 16, 16 },
        shadow = false,
        physics = {
            shape = "circle",
            tag = "projectile",
            collideWith = { "enemy", "WORLD" },
            sensor = false,
            density = 0.5,
            bullet = true,  -- Enable CCD for fast-moving objects
            fixedRotation = false
        },
        data = {
            damage = 10,
            damage_type = "physical",
            owner = nil,  -- Set at spawn time
            lifetime = 2000,
            speed = 500,
            pierce_count = 0,
        }
    },

    -- Fire projectile (matches fireball from projectiles.lua)
    fireball = {
        sprite = "b1060.png",  -- Replace with actual fireball sprite
        size = { 24, 24 },
        shadow = false,
        physics = {
            shape = "circle",
            tag = "projectile",
            collideWith = { "enemy", "WORLD" },
            sensor = false,
            density = 0.6,
            bullet = true
        },
        data = {
            damage = 25,
            damage_type = "fire",
            owner = nil,
            lifetime = 2000,
            speed = 400,
            explosion_radius = 60,
            on_hit_effect = "burn",
            on_hit_duration = 3000,
        }
    },

    -- Fast piercing projectile (matches ice_shard from projectiles.lua)
    ice_shard = {
        sprite = "b1060.png",  -- Replace with actual ice shard sprite
        size = { 20, 20 },
        shadow = false,
        physics = {
            shape = "rectangle",
            tag = "projectile",
            collideWith = { "enemy", "WORLD" },
            sensor = false,
            density = 0.4,
            bullet = true,
            fixedRotation = false
        },
        data = {
            damage = 15,
            damage_type = "ice",
            owner = nil,
            lifetime = 1800,
            speed = 600,
            pierce_count = 2,
            on_hit_effect = "freeze",
            on_hit_duration = 1000,
        }
    },
}

--------------------------------------------------------------------------------
-- PICKUPS
--------------------------------------------------------------------------------

SpawnPresets.pickups = {
    -- Experience pickup (matches gameplay.lua)
    exp_orb = {
        sprite = "b8090.png",  -- EXP_PICKUP_ANIMATION_ID from gameplay.lua
        size = { 16, 16 },
        shadow = false,
        physics = {
            shape = "rectangle",
            tag = "pickup",
            collideWith = { "player" },
            sensor = true,
            density = 1.0,
            inflate_px = 0
        },
        data = {
            pickup_type = "exp",
            value = 10,
            auto_collect = true,
        },
        interactive = {
            collision = true
        }
    },

    -- Gold pickup
    gold_coin = {
        sprite = "b8090.png",  -- Replace with actual gold sprite
        size = { 16, 16 },
        shadow = false,
        physics = {
            shape = "circle",
            tag = "pickup",
            collideWith = { "player" },
            sensor = true,
            density = 0.5
        },
        data = {
            pickup_type = "gold",
            value = 5,
            auto_collect = true,
        },
        interactive = {
            hover = {
                title = "Gold",
                body = "Currency for shops"
            },
            collision = true
        }
    },

    -- Health potion pickup
    health_potion = {
        sprite = "b8090.png",  -- Replace with actual potion sprite
        size = { 20, 20 },
        shadow = true,
        physics = {
            shape = "circle",
            tag = "pickup",
            collideWith = { "player" },
            sensor = true,
            density = 0.8
        },
        data = {
            pickup_type = "health",
            value = 25,
            auto_collect = false,  -- Manual pickup
        },
        interactive = {
            hover = {
                title = "Health Potion",
                body = "Restores 25 HP"
            },
            click = nil,  -- Set at spawn time if needed
            collision = true
        }
    },
}

--------------------------------------------------------------------------------
-- EFFECTS
--------------------------------------------------------------------------------

SpawnPresets.effects = {
    -- Explosion effect
    explosion = {
        sprite = "b3997.png",  -- Hazard sprite from gameplay.lua
        size = { 64, 64 },
        shadow = false,
        physics = nil,  -- Effects usually don't need physics
        data = {
            effect_type = "explosion",
            lifetime = 500,  -- ms
            damage = 0,  -- Visual only, damage handled separately
            scale_in_time = 100,
            scale_out_time = 200,
        }
    },

    -- Hit spark effect
    hit_spark = {
        sprite = "b3997.png",  -- Replace with actual spark sprite
        size = { 32, 32 },
        shadow = false,
        physics = nil,
        data = {
            effect_type = "hit_spark",
            lifetime = 300,
            scale_in_time = 50,
            scale_out_time = 150,
        }
    },

    -- Smoke puff effect
    smoke_puff = {
        sprite = "b3997.png",  -- Replace with actual smoke sprite
        size = { 48, 48 },
        shadow = false,
        physics = nil,
        data = {
            effect_type = "smoke",
            lifetime = 1000,
            scale_in_time = 200,
            scale_out_time = 400,
            drift_speed = { x = 0, y = -20 },  -- Drift upward
        }
    },
}

return SpawnPresets
