-- assets/scripts/data/enemies.lua
-- Enemy definitions using declarative behavior composition
--
-- MIGRATION NOTES (DX Audit 2024):
-- Before: Each enemy had on_spawn() with 8-15 lines of timer boilerplate
-- After:  Declarative behaviors array - 1-3 lines, auto-cleanup
--
-- OLD FORMAT (still supported for backwards compatibility):
--   on_spawn = function(e, ctx, helpers)
--       timer.every(0.5, function()
--           if not entity_cache.valid(e) then return false end
--           helpers.move_toward_player(e, ctx.speed)
--       end, "enemy_" .. e)
--   end,
--
-- NEW FORMAT:
--   behaviors = { "chase" },  -- Uses ctx.speed, interval 0.5, auto-cleanup
--
-- AVAILABLE BEHAVIORS:
--   "chase"   - Move toward player (interval=0.5, speed=ctx.speed)
--   "wander"  - Random movement (interval=0.5, speed=ctx.speed)
--   "flee"    - Move away from player (distance=150)
--   "kite"    - Maintain range from player (range=ctx.range)
--   "dash"    - Periodic dash attack (cooldown=ctx.dash_cooldown, speed=ctx.dash_speed)
--   "trap"    - Drop traps (cooldown=ctx.trap_cooldown, damage=ctx.trap_damage)
--   "summon"  - Summon minions (cooldown=ctx.summon_cooldown, type=ctx.summon_type)
--   "rush"    - Fast chase for aggressive enemies (interval=0.3)
--
-- OVERRIDE DEFAULTS with table syntax:
--   { "chase", interval = 0.3, speed = 100 }
--   { "dash", cooldown = 2.0, duration = 0.5 }
--
-- STRING REFERENCES look up ctx fields:
--   { "dash", cooldown = "dash_cooldown" }  -- Uses ctx.dash_cooldown

local enemies = {}

--============================================
-- GOBLIN - Basic chaser
--============================================

enemies.goblin = {
    sprite = "enemy_type_1.png",
    hp = 30,
    speed = 60,
    damage = 5,
    size = { 32, 32 },

    behaviors = {
        "chase",
    },

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("enemy_death", e)
    end,
}

--============================================
-- ARCHER - Kites and fires at player
--============================================

enemies.archer = {
    sprite = "enemy_type_2.png",
    hp = 20,
    speed = 40,
    damage = 8,
    attack_range = 200,
    attack_cooldown = 1.5,
    projectile_preset = "enemy_arrow",
    size = { 32, 32 },

    behaviors = {
        { "kite", range = "attack_range" },
        { "ranged_attack", interval = "attack_cooldown", range = "attack_range", damage = "damage", projectile = "projectile_preset" },
    },

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("enemy_death", e)
    end,
}

--============================================
-- DASHER - Wanders then periodically dashes at player
--============================================

enemies.dasher = {
    sprite = "enemy_type_1.png",
    hp = 25,
    speed = 50,
    dash_speed = 300,
    dash_cooldown = 3.0,
    damage = 12,
    size = { 32, 32 },

    behaviors = {
        "wander",
        { "dash", cooldown = "dash_cooldown", speed = "dash_speed", duration = 0.3 },
    },

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("enemy_death", e)
    end,
}

--============================================
-- TRAPPER - Wanders and drops traps
--============================================

enemies.trapper = {
    sprite = "enemy_type_2.png",
    hp = 35,
    speed = 30,
    trap_cooldown = 4.0,
    trap_damage = 15,
    trap_lifetime = 10.0,
    damage = 3,
    size = { 32, 32 },

    behaviors = {
        "wander",
        { "trap", cooldown = "trap_cooldown", damage = "trap_damage", lifetime = "trap_lifetime" },
    },

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("enemy_death", e)
    end,
}

--============================================
-- SUMMONER - Flees and summons minions
--============================================

enemies.summoner = {
    sprite = "elite_porcupine.png",
    hp = 50,
    speed = 25,
    summon_cooldown = 5.0,
    summon_type = "goblin",
    summon_count = 2,
    damage = 2,
    size = { 64, 32 },

    behaviors = {
        { "flee", distance = 150 },
        { "summon", cooldown = "summon_cooldown", enemy_type = "summon_type", count = "summon_count" },
    },

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("summoner_death", e)
    end,
}

--============================================
-- EXPLODER - Rushes player, explodes on death/contact
--============================================

enemies.exploder = {
    sprite = "enemy_type_1.png",
    hp = 15,
    speed = 80,
    explosion_radius = 60,
    explosion_damage = 25,
    damage = 0, -- no contact damage, only explosion
    size = { 28, 28 },

    behaviors = {
        "rush",  -- Fast chase (0.3 interval)
    },

    on_death = function(e, ctx, helpers)
        helpers.explode(e, ctx.explosion_radius, ctx.explosion_damage)
        helpers.screen_shake(0.2, 5)
    end,

    on_contact_player = function(e, ctx, helpers)
        helpers.kill_enemy(e) -- triggers on_death -> explode
    end,
}

--============================================
-- WANDERER - Basic fodder, random movement only
--============================================

enemies.wanderer = {
    sprite = "enemy_type_2.png",
    hp = 20,
    speed = 35,
    damage = 3,
    size = { 28, 28 },

    behaviors = {
        "wander",
    },

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("enemy_death", e)
    end,
}

--============================================
-- ORBITER - Circles around player while shooting
--============================================

enemies.orbiter = {
    sprite = "enemy_type_2.png",
    hp = 25,
    speed = 80,
    damage = 6,
    orbit_radius = 120,
    orbit_speed = 1.5,
    attack_cooldown = 2.0,
    attack_range = 200,
    projectile_preset = "enemy_basic_shot",
    size = { 28, 28 },

    behaviors = {
        { "orbit", radius = "orbit_radius", angular_speed = "orbit_speed", speed = "speed" },
        { "ranged_attack", interval = "attack_cooldown", range = "attack_range", damage = "damage", projectile = "projectile_preset" },
    },

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("enemy_death", e)
    end,
}

--============================================
-- SNIPER - Long range, flees when close
--============================================

enemies.sniper = {
    sprite = "enemy_type_2.png",
    hp = 15,
    speed = 35,
    damage = 15,
    attack_range = 350,
    min_range = 150,
    attack_cooldown = 2.5,
    projectile_preset = "enemy_sniper_shot",
    size = { 32, 32 },

    behaviors = {
        { "flee", distance = "min_range", speed = "speed" },
        { "ranged_attack", interval = "attack_cooldown", range = "attack_range", min_range = "min_range", damage = "damage", projectile = "projectile_preset" },
    },

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("enemy_death", e)
    end,
}

--============================================
-- SHOTGUNNER - Close range spread shot
--============================================

enemies.shotgunner = {
    sprite = "enemy_type_1.png",
    hp = 35,
    speed = 45,
    damage = 5,
    attack_range = 100,
    attack_cooldown = 2.0,
    projectile_preset = "enemy_pellet",
    size = { 36, 36 },

    behaviors = {
        "chase",
        { "spread_shot", interval = "attack_cooldown", range = "attack_range", damage = "damage", projectile = "projectile_preset", count = 5, spread_angle = 0.9 },
    },

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("enemy_death", e)
        helpers.explode(e, 30, 10)
    end,
}

--============================================
-- BOMBER - Fires ring of projectiles periodically
--============================================

enemies.bomber = {
    sprite = "elite_porcupine.png",
    hp = 60,
    speed = 25,
    damage = 8,
    attack_cooldown = 3.0,
    projectile_preset = "enemy_bomb",
    ring_count = 12,
    size = { 40, 40 },

    behaviors = {
        "wander",
        { "ring_shot", interval = "attack_cooldown", damage = "damage", projectile = "projectile_preset", count = "ring_count" },
    },

    on_death = function(e, ctx, helpers)
        helpers.fire_projectile_ring(e, "enemy_bomb", 10, 16)
        helpers.spawn_particles("summoner_death", e)
    end,
}

--============================================
-- ZIGZAGGER - Erratic movement pattern
--============================================

enemies.zigzagger = {
    sprite = "enemy_type_1.png",
    hp = 20,
    speed = 70,
    damage = 7,
    zigzag_amplitude = 60,
    zigzag_frequency = 3.0,
    size = { 28, 28 },

    behaviors = {
        { "zigzag", speed = "speed", zigzag_amplitude = "zigzag_amplitude", zigzag_frequency = "zigzag_frequency" },
    },

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("enemy_death", e)
    end,
}

--============================================
-- TELEPORTER_ENEMY - Blinks around the arena
--============================================

enemies.teleporter_enemy = {
    sprite = "enemy_type_2.png",
    hp = 30,
    speed = 30,
    damage = 10,
    teleport_cooldown = 3.0,
    attack_cooldown = 1.0,
    attack_range = 150,
    projectile_preset = "enemy_magic_bolt",
    size = { 32, 32 },

    behaviors = {
        { "teleport", interval = "teleport_cooldown", min_distance = 80, max_distance = 150 },
        { "ranged_attack", interval = "attack_cooldown", range = "attack_range", damage = "damage", projectile = "projectile_preset" },
    },

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("teleport_out", e)
        helpers.spawn_particles("enemy_death", e)
    end,
}

--============================================
-- AMBUSHER - Hides until player gets close
--============================================

enemies.ambusher = {
    sprite = "enemy_type_1.png",
    hp = 40,
    speed = 120,
    damage = 15,
    trigger_range = 100,
    size = { 32, 32 },

    behaviors = {
        { "ambush", trigger_range = "trigger_range", speed = "speed" },
    },

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("enemy_death", e)
    end,
}

--============================================
-- STRAFER - Dodges while attacking
--============================================

enemies.strafer = {
    sprite = "enemy_type_2.png",
    hp = 22,
    speed = 55,
    damage = 7,
    attack_cooldown = 1.2,
    attack_range = 180,
    projectile_preset = "enemy_basic_shot",
    size = { 30, 30 },

    behaviors = {
        { "strafe", speed = "speed", direction_change_chance = 0.15 },
        { "ranged_attack", interval = "attack_cooldown", range = "attack_range", damage = "damage", projectile = "projectile_preset" },
    },

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("enemy_death", e)
    end,
}

--============================================
-- BURST_SHOOTER - Fires in bursts
--============================================

enemies.burst_shooter = {
    sprite = "enemy_type_2.png",
    hp = 28,
    speed = 40,
    damage = 4,
    burst_cooldown = 2.5,
    attack_range = 200,
    projectile_preset = "enemy_basic_shot",
    size = { 32, 32 },

    behaviors = {
        { "kite", range = "attack_range" },
        { "burst_fire", interval = "burst_cooldown", range = "attack_range", damage = "damage", projectile = "projectile_preset", burst_count = 4, burst_delay = 0.15 },
    },

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("enemy_death", e)
    end,
}

return enemies
