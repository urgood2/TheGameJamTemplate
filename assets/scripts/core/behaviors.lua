--[[
================================================================================
behaviors.lua - Declarative Enemy Behavior Composition Library
================================================================================
Replaces repetitive timer-based behavior code with declarative composition.

USAGE (in data/enemies.lua):
    enemies.goblin = {
        sprite = "enemy_type_1.png",
        hp = 30, speed = 60, damage = 5,
        size = { 32, 32 },

        behaviors = {
            "chase",  -- Simple: uses ctx.speed, default interval
        },

        on_death = "particles:enemy_death",  -- Shorthand for particle effect
    }

    enemies.dasher = {
        sprite = "enemy_type_1.png",
        hp = 25, speed = 50, dash_speed = 300, dash_cooldown = 3.0,

        behaviors = {
            "wander",
            { "dash", cooldown = "dash_cooldown", speed = "dash_speed" },
        },
    }

BEHAVIOR DEFINITION FORMAT:
    behaviors.register("chase", {
        -- Default config values
        defaults = { interval = 0.5, speed = "speed" },

        -- Called once when behavior starts
        on_start = function(e, ctx, helpers, config) end,

        -- Called each interval (timer-based)
        on_tick = function(e, ctx, helpers, config)
            helpers.move_toward_player(e, config.speed)
        end,

        -- Called when behavior stops (entity destroyed or behavior removed)
        on_stop = function(e, ctx, helpers, config) end,
    })

CONFIG VALUE RESOLUTION:
    - Numbers/strings/tables: Used directly
    - String matching ctx field: Looked up from ctx (e.g., "dash_speed" -> ctx.dash_speed)
    - Functions: Called with (ctx) to get value

AUTO-CLEANUP:
    - All timers tagged with entity ID for automatic cleanup
    - Call behaviors.cleanup(e) to stop all behaviors for an entity
]]

-- Singleton guard
if _G.__behaviors__ then return _G.__behaviors__ end

local entity_cache = require("core.entity_cache")
local timer = require("core.timer")

local behaviors = {}

-- Registry of available behaviors
local registry = {}

-- Active behaviors per entity: { [entity] = { tag1, tag2, ... } }
local active_timers = {}

--------------------------------------------------------------------------------
-- Value Resolution
--------------------------------------------------------------------------------

--- Resolve a config value that may reference ctx fields
--- @param value any The config value (number, string referencing ctx field, or function)
--- @param ctx table The enemy context
--- @return any The resolved value
local function resolve_value(value, ctx)
    if type(value) == "function" then
        return value(ctx)
    elseif type(value) == "string" and ctx[value] ~= nil then
        -- String matches a ctx field name - use that value
        return ctx[value]
    else
        -- Use value directly (number, string literal, table)
        return value
    end
end

--- Build resolved config from behavior definition defaults and instance overrides
--- @param def table Behavior definition with defaults
--- @param instance_config table Instance overrides from enemy definition
--- @param ctx table Enemy context
--- @return table Resolved config with all values
local function build_config(def, instance_config, ctx)
    local config = {}

    -- Start with defaults
    if def.defaults then
        for k, v in pairs(def.defaults) do
            config[k] = resolve_value(v, ctx)
        end
    end

    -- Apply instance overrides
    if instance_config then
        for k, v in pairs(instance_config) do
            if k ~= 1 then  -- Skip the behavior name at index 1
                config[k] = resolve_value(v, ctx)
            end
        end
    end

    return config
end

--------------------------------------------------------------------------------
-- Behavior Registration
--------------------------------------------------------------------------------

--- Register a named behavior
--- @param name string Behavior name (e.g., "chase", "wander", "dash")
--- @param def table Behavior definition { defaults, on_start, on_tick, on_stop }
function behaviors.register(name, def)
    assert(type(name) == "string", "Behavior name must be a string")
    assert(type(def) == "table", "Behavior definition must be a table")

    registry[name] = def
end

--- Check if a behavior is registered
--- @param name string Behavior name
--- @return boolean
function behaviors.is_registered(name)
    return registry[name] ~= nil
end

--- Get list of all registered behavior names
--- @return string[]
function behaviors.list()
    local names = {}
    for name, _ in pairs(registry) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

--------------------------------------------------------------------------------
-- Behavior Application
--------------------------------------------------------------------------------

--- Apply behaviors to an entity based on its definition
--- Called from EnemyFactory.spawn() after entity creation
--- @param e number Entity ID
--- @param ctx table Enemy context from EnemyFactory
--- @param helpers table Wave helpers (move_toward_player, etc.)
--- @param behavior_list table Array of behavior specs from enemy definition
function behaviors.apply(e, ctx, helpers, behavior_list)
    if not behavior_list or #behavior_list == 0 then
        return
    end

    -- Initialize timer tracking for this entity
    active_timers[e] = active_timers[e] or {}

    for i, spec in ipairs(behavior_list) do
        local name, instance_config

        -- Parse spec: can be string or table
        if type(spec) == "string" then
            name = spec
            instance_config = {}
        elseif type(spec) == "table" then
            name = spec[1]
            instance_config = spec
        else
            print("[behaviors] Invalid behavior spec at index " .. i .. ": " .. type(spec))
            goto continue
        end

        local def = registry[name]
        if not def then
            print("[behaviors] Unknown behavior: " .. tostring(name))
            goto continue
        end

        -- Build resolved config
        local config = build_config(def, instance_config, ctx)

        -- Generate unique timer tag
        local tag = string.format("behavior_%d_%s_%d", e, name, i)
        table.insert(active_timers[e], tag)

        -- Call on_start if defined
        if def.on_start then
            def.on_start(e, ctx, helpers, config)
        end

        -- Set up timer for on_tick
        if def.on_tick then
            local interval = config.interval or 0.5
            local immediate = config.immediate ~= false  -- Default true

            timer.every(interval, function()
                -- Auto validity check - stop timer if entity invalid
                if not entity_cache.valid(e) then
                    return false
                end

                -- Call tick handler
                def.on_tick(e, ctx, helpers, config)
            end, 0, immediate, nil, tag)
        end

        ::continue::
    end
end

--- Stop all behaviors for an entity
--- Called from EnemyFactory.kill() or when entity is destroyed
--- @param e number Entity ID
function behaviors.cleanup(e)
    local timers = active_timers[e]
    if not timers then return end

    -- Cancel all tracked timers
    for _, tag in ipairs(timers) do
        timer.cancel(tag)
    end

    -- Clear tracking
    active_timers[e] = nil
end

--- Get count of active behaviors for an entity (for debugging)
--- @param e number Entity ID
--- @return number
function behaviors.count(e)
    local timers = active_timers[e]
    return timers and #timers or 0
end

--------------------------------------------------------------------------------
-- Built-in Behaviors
--------------------------------------------------------------------------------

-- CHASE: Move toward player
behaviors.register("chase", {
    defaults = {
        interval = 0.5,
        speed = "speed",  -- Looks up ctx.speed
    },
    on_tick = function(e, ctx, helpers, config)
        helpers.move_toward_player(e, config.speed)
    end,
})

-- WANDER: Random movement
behaviors.register("wander", {
    defaults = {
        interval = 0.5,
        speed = "speed",
    },
    on_tick = function(e, ctx, helpers, config)
        helpers.wander(e, config.speed)
    end,
})

-- FLEE: Move away from player
behaviors.register("flee", {
    defaults = {
        interval = 0.5,
        speed = "speed",
        distance = 150,  -- How far to maintain from player
    },
    on_tick = function(e, ctx, helpers, config)
        helpers.flee_from_player(e, config.speed, config.distance)
    end,
})

-- KITE: Maintain distance from player (for ranged enemies)
behaviors.register("kite", {
    defaults = {
        interval = 0.5,
        speed = "speed",
        range = "range",  -- Looks up ctx.range
    },
    on_tick = function(e, ctx, helpers, config)
        helpers.kite_from_player(e, config.speed, config.range)
    end,
})

-- DASH: Periodic dash toward player
behaviors.register("dash", {
    defaults = {
        interval = "dash_cooldown",  -- Looks up ctx.dash_cooldown
        speed = "dash_speed",        -- Looks up ctx.dash_speed
        duration = 0.3,
    },
    on_tick = function(e, ctx, helpers, config)
        helpers.dash_toward_player(e, config.speed, config.duration)
    end,
})

-- TRAP: Drop traps periodically
behaviors.register("trap", {
    defaults = {
        interval = "trap_cooldown",
        damage = "trap_damage",
        lifetime = "trap_lifetime",
    },
    on_tick = function(e, ctx, helpers, config)
        helpers.drop_trap(e, config.damage, config.lifetime)
    end,
})

-- SUMMON: Summon minion enemies periodically
behaviors.register("summon", {
    defaults = {
        interval = "summon_cooldown",
        enemy_type = "summon_type",
        count = "summon_count",
    },
    on_tick = function(e, ctx, helpers, config)
        helpers.summon_enemies(e, config.enemy_type, config.count)
    end,
})

-- RUSH: Fast chase (for exploders, etc.)
behaviors.register("rush", {
    defaults = {
        interval = 0.3,  -- Faster update for aggressive chase
        speed = "speed",
    },
    on_tick = function(e, ctx, helpers, config)
        helpers.move_toward_player(e, config.speed)
    end,
})

--------------------------------------------------------------------------------
-- Death Effect Shortcuts
--------------------------------------------------------------------------------

--- Parse on_death shorthand and return a proper callback
--- Supports: "particles:name", "explode:radius:damage", function
--- @param on_death any The on_death value from enemy definition
--- @return function? The death callback
function behaviors.parse_on_death(on_death)
    if type(on_death) == "function" then
        return on_death
    end

    if type(on_death) ~= "string" then
        return nil
    end

    -- Parse shorthand strings
    local effect_type, arg1, arg2 = on_death:match("^(%w+):([^:]+):?(.*)$")
    if not effect_type then
        effect_type = on_death:match("^(%w+)$")
    end

    if effect_type == "particles" then
        local particle_name = arg1 or "enemy_death"
        return function(e, ctx, helpers)
            helpers.spawn_particles(particle_name, e)
        end
    elseif effect_type == "explode" then
        return function(e, ctx, helpers)
            local radius = tonumber(arg1) or ctx.explosion_radius or 60
            local damage = tonumber(arg2) or ctx.explosion_damage or 25
            helpers.explode(e, radius, damage)
            helpers.screen_shake(0.2, 5)
        end
    end

    return nil
end

--------------------------------------------------------------------------------
-- Module Export
--------------------------------------------------------------------------------

_G.__behaviors__ = behaviors
return behaviors
