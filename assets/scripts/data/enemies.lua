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
-- ARCHER - Kites from player (ranged placeholder)
--============================================

enemies.archer = {
    sprite = "enemy_type_2.png",
    hp = 20,
    speed = 40,
    damage = 8,
    range = 200,
    size = { 32, 32 },

    behaviors = {
        { "kite", range = "range" },
        -- TODO: Add ranged attack behavior when projectile system ready
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
    size = { 40, 40 },

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

return enemies
