-- assets/scripts/data/enemies.lua
-- Enemy definitions with inline timer-based behaviors

local entity_cache = require("core.entity_cache")
local timer = require("core.timer")

local enemies = {}

--============================================
-- GOBLIN - Basic chaser
--============================================

enemies.goblin = {
    sprite = "goblin_idle",
    hp = 30,
    speed = 60,
    damage = 5,
    size = { 32, 32 },

    on_spawn = function(e, ctx, helpers)
        timer.every(0.5, function()
            if not entity_cache.valid(e) then return false end
            helpers.move_toward_player(e, ctx.speed)
        end, "enemy_" .. e)
    end,

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("enemy_death", e)
    end,
}

--============================================
-- ARCHER - Kites from player (ranged placeholder)
--============================================

enemies.archer = {
    sprite = "archer_idle",
    hp = 20,
    speed = 40,
    damage = 8,
    range = 200,
    size = { 32, 32 },

    on_spawn = function(e, ctx, helpers)
        timer.every(0.5, function()
            if not entity_cache.valid(e) then return false end
            helpers.kite_from_player(e, ctx.speed, ctx.range)
        end, "enemy_" .. e)

        -- Ranged attack placeholder (projectiles handled by parallel work)
        -- timer.every(2.0, function() ... end)
    end,

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("enemy_death", e)
    end,
}

--============================================
-- DASHER - Wanders then periodically dashes at player
--============================================

enemies.dasher = {
    sprite = "dasher_idle",
    hp = 25,
    speed = 50,
    dash_speed = 300,
    dash_cooldown = 3.0,
    damage = 12,
    size = { 32, 32 },

    on_spawn = function(e, ctx, helpers)
        -- Wander between dashes
        timer.every(0.5, function()
            if not entity_cache.valid(e) then return false end
            helpers.wander(e, ctx.speed)
        end, "enemy_" .. e)

        -- Periodic dash attack
        timer.every(ctx.dash_cooldown, function()
            if not entity_cache.valid(e) then return false end
            helpers.dash_toward_player(e, ctx.dash_speed, 0.3)
        end, "enemy_" .. e .. "_dash")
    end,

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("enemy_death", e)
    end,
}

--============================================
-- TRAPPER - Wanders and drops traps
--============================================

enemies.trapper = {
    sprite = "trapper_idle",
    hp = 35,
    speed = 30,
    trap_cooldown = 4.0,
    trap_damage = 15,
    trap_lifetime = 10.0,
    damage = 3,
    size = { 32, 32 },

    on_spawn = function(e, ctx, helpers)
        -- Slow wander
        timer.every(0.5, function()
            if not entity_cache.valid(e) then return false end
            helpers.wander(e, ctx.speed)
        end, "enemy_" .. e)

        -- Drop traps
        timer.every(ctx.trap_cooldown, function()
            if not entity_cache.valid(e) then return false end
            helpers.drop_trap(e, ctx.trap_damage, ctx.trap_lifetime)
        end, "enemy_" .. e .. "_trap")
    end,

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("enemy_death", e)
    end,
}

--============================================
-- SUMMONER - Flees and summons minions
--============================================

enemies.summoner = {
    sprite = "summoner_idle",
    hp = 50,
    speed = 25,
    summon_cooldown = 5.0,
    summon_type = "goblin",
    summon_count = 2,
    damage = 2,
    size = { 40, 40 },

    on_spawn = function(e, ctx, helpers)
        -- Flee from player
        timer.every(0.5, function()
            if not entity_cache.valid(e) then return false end
            helpers.flee_from_player(e, ctx.speed, 150)
        end, "enemy_" .. e)

        -- Summon minions
        timer.every(ctx.summon_cooldown, function()
            if not entity_cache.valid(e) then return false end
            helpers.summon_enemies(e, ctx.summon_type, ctx.summon_count)
        end, "enemy_" .. e .. "_summon")
    end,

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("summoner_death", e)
    end,
}

--============================================
-- EXPLODER - Rushes player, explodes on death/contact
--============================================

enemies.exploder = {
    sprite = "exploder_idle",
    hp = 15,
    speed = 80,
    explosion_radius = 60,
    explosion_damage = 25,
    damage = 0, -- no contact damage, only explosion
    size = { 28, 28 },

    on_spawn = function(e, ctx, helpers)
        -- Rush player
        timer.every(0.3, function()
            if not entity_cache.valid(e) then return false end
            helpers.move_toward_player(e, ctx.speed)
        end, "enemy_" .. e)
    end,

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
    sprite = "wanderer_idle",
    hp = 20,
    speed = 35,
    damage = 3,
    size = { 28, 28 },

    on_spawn = function(e, ctx, helpers)
        timer.every(0.5, function()
            if not entity_cache.valid(e) then return false end
            helpers.wander(e, ctx.speed)
        end, "enemy_" .. e)
    end,

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("enemy_death", e)
    end,
}

return enemies
