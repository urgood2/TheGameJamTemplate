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

-- Active behavior info per entity for on_stop callbacks: { [entity] = { { def, ctx, helpers, config }, ... } }
local active_behavior_info = {}

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

    active_timers[e] = active_timers[e] or {}
    active_behavior_info[e] = active_behavior_info[e] or {}

    for i, spec in ipairs(behavior_list) do
        local name, instance_config

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

        local config = build_config(def, instance_config, ctx)
        local tag = string.format("behavior_%d_%s_%d", e, name, i)
        table.insert(active_timers[e], tag)

        table.insert(active_behavior_info[e], {
            def = def,
            ctx = ctx,
            helpers = helpers,
            config = config,
        })

        if def.on_start then
            def.on_start(e, ctx, helpers, config)
        end

        if def.on_tick then
            local interval = config.interval ~= nil and config.interval or 0.5
            local immediate = config.immediate ~= false

            timer.every(interval, function()
                if not entity_cache.valid(e) then
                    return false
                end
                def.on_tick(e, ctx, helpers, config)
            end, 0, immediate, nil, tag)
        end

        ::continue::
    end
end

function behaviors.cleanup(e)
    local info_list = active_behavior_info[e]
    if info_list then
        for _, info in ipairs(info_list) do
            if info.def.on_stop then
                pcall(info.def.on_stop, e, info.ctx, info.helpers, info.config)
            end
        end
        active_behavior_info[e] = nil
    end

    local timers = active_timers[e]
    if timers then
        for _, tag in ipairs(timers) do
            timer.cancel(tag)
        end
        active_timers[e] = nil
    end
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
        interval = 0.3,
        speed = "speed",
    },
    on_tick = function(e, ctx, helpers, config)
        helpers.move_toward_player(e, config.speed)
    end,
})

-- RANGED_ATTACK: Fire projectiles at player when in range
behaviors.register("ranged_attack", {
    defaults = {
        interval = "attack_cooldown",
        range = "attack_range",
        projectile = "projectile_preset",
        damage = "damage",
        min_range = 0,
    },
    on_tick = function(e, ctx, helpers, config)
        local dist = helpers.distance_to_player(e)
        local range = config.range ~= nil and config.range or 200
        local min_range = config.min_range ~= nil and config.min_range or 0
        local in_range = dist <= range and dist >= min_range
        if in_range then
            helpers.fire_projectile(e, config.projectile, config.damage)
        end
    end,
})

-- SPREAD_SHOT: Fire multiple projectiles in a spread pattern
behaviors.register("spread_shot", {
    defaults = {
        interval = "attack_cooldown",
        range = "attack_range",
        projectile = "projectile_preset",
        damage = "damage",
        count = 3,
        spread_angle = 0.785,
    },
    on_tick = function(e, ctx, helpers, config)
        local range = config.range ~= nil and config.range or 200
        if helpers.is_in_range(e, range) then
            local count = config.count ~= nil and config.count or 3
            local spread = config.spread_angle ~= nil and config.spread_angle or 0.785
            helpers.fire_projectile_spread(e, config.projectile, config.damage, count, spread)
        end
    end,
})

-- RING_SHOT: Fire projectiles in all directions
behaviors.register("ring_shot", {
    defaults = {
        interval = "attack_cooldown",
        projectile = "projectile_preset",
        damage = "damage",
        count = 8,
    },
    on_tick = function(e, ctx, helpers, config)
        local count = config.count ~= nil and config.count or 8
        helpers.fire_projectile_ring(e, config.projectile, config.damage, count)
    end,
})

-- BURST_FIRE: Fire multiple shots in quick succession
behaviors.register("burst_fire", {
    defaults = {
        interval = "burst_cooldown",
        range = "attack_range",
        projectile = "projectile_preset",
        damage = "damage",
        burst_count = 3,
        burst_delay = 0.1,
    },
    on_start = function(e, ctx, helpers, config)
        ctx._burst_id = 0
    end,
    on_tick = function(e, ctx, helpers, config)
        local range = config.range ~= nil and config.range or 200
        if not helpers.is_in_range(e, range) then return end
        
        local count = config.burst_count ~= nil and config.burst_count or 3
        local delay = config.burst_delay ~= nil and config.burst_delay or 0.1
        ctx._burst_id = (ctx._burst_id or 0) + 1
        local burst_id = ctx._burst_id
        
        for i = 0, count - 1 do
            local tag = string.format("burst_%d_%d_%d", e, burst_id, i)
            timer.after(delay * i, function()
                if entity_cache.valid(e) then
                    helpers.fire_projectile(e, config.projectile, config.damage)
                end
            end, tag)
            if active_timers[e] then
                table.insert(active_timers[e], tag)
            end
        end
    end,
})

-- ORBIT: Circle around player at fixed distance
behaviors.register("orbit", {
    defaults = {
        interval = 0.016,
        radius = "orbit_radius",
        angular_speed = "orbit_speed",
        speed = "speed",
    },
    on_start = function(e, ctx, helpers, config)
        local pos = helpers.get_entity_position(e) or { x = 0, y = 0 }
        local player = helpers.get_player_position()
        ctx._orbit_angle = math.atan2(pos.y - player.y, pos.x - player.x)
    end,
    on_tick = function(e, ctx, helpers, config)
        local angular_speed = config.angular_speed ~= nil and config.angular_speed or 1.0
        local radius = config.radius ~= nil and config.radius or 150
        local speed = config.speed ~= nil and config.speed or 100
        local interval = config.interval ~= nil and config.interval or 0.016
        
        ctx._orbit_angle = (ctx._orbit_angle or 0) + angular_speed * interval
        
        local player = helpers.get_player_position()
        local target_x = player.x + math.cos(ctx._orbit_angle) * radius
        local target_y = player.y + math.sin(ctx._orbit_angle) * radius
        
        helpers.move_toward_point(e, target_x, target_y, speed)
    end,
})

-- STRAFE: Move perpendicular to player (dodging behavior)
behaviors.register("strafe", {
    defaults = {
        interval = 0.5,
        speed = "speed",
        direction_change_chance = 0.1,
    },
    on_start = function(e, ctx, helpers, config)
        ctx._strafe_direction = math.random() > 0.5 and 1 or -1
    end,
    on_tick = function(e, ctx, helpers, config)
        if math.random() < (config.direction_change_chance or 0.1) then
            ctx._strafe_direction = -ctx._strafe_direction
        end
        helpers.strafe_around_player(e, config.speed, ctx._strafe_direction)
    end,
})

-- PATROL: Move between waypoints
behaviors.register("patrol", {
    defaults = {
        interval = 0.5,
        speed = "speed",
        waypoints = nil,
        loop = true,
        arrival_threshold = 10,
    },
    on_start = function(e, ctx, helpers, config)
        ctx._patrol_index = 1
        ctx._patrol_forward = true
    end,
    on_tick = function(e, ctx, helpers, config)
        local waypoints = config.waypoints
        if not waypoints or #waypoints == 0 then
            helpers.wander(e, config.speed)
            return
        end
        
        local current_wp = waypoints[ctx._patrol_index]
        if not current_wp then return end
        
        local pos = helpers.get_entity_position(e)
        if not pos then return end
        
        local dx = current_wp.x - pos.x
        local dy = current_wp.y - pos.y
        local dist = math.sqrt(dx * dx + dy * dy)
        
        if dist <= (config.arrival_threshold or 10) then
            if config.loop then
                ctx._patrol_index = (ctx._patrol_index % #waypoints) + 1
            else
                if ctx._patrol_forward then
                    if ctx._patrol_index < #waypoints then
                        ctx._patrol_index = ctx._patrol_index + 1
                    else
                        ctx._patrol_forward = false
                        ctx._patrol_index = ctx._patrol_index - 1
                    end
                else
                    if ctx._patrol_index > 1 then
                        ctx._patrol_index = ctx._patrol_index - 1
                    else
                        ctx._patrol_forward = true
                        ctx._patrol_index = ctx._patrol_index + 1
                    end
                end
            end
        else
            helpers.move_toward_point(e, current_wp.x, current_wp.y, config.speed)
        end
    end,
})

-- AMBUSH: Stay still until player is in range, then rush
behaviors.register("ambush", {
    defaults = {
        interval = 0.3,
        trigger_range = "trigger_range",
        speed = "speed",
    },
    on_start = function(e, ctx, helpers, config)
        ctx._ambush_triggered = false
    end,
    on_tick = function(e, ctx, helpers, config)
        if ctx._ambush_triggered then
            helpers.move_toward_player(e, config.speed)
            return
        end
        
        if helpers.is_in_range(e, config.trigger_range or 150) then
            ctx._ambush_triggered = true
            helpers.spawn_particles("ambush_alert", e)
        end
    end,
})

-- ZIGZAG: Move toward player in a zigzag pattern
behaviors.register("zigzag", {
    defaults = {
        interval = 0.1,
        speed = "speed",
        zigzag_amplitude = 50,
        zigzag_frequency = 2.0,
    },
    on_start = function(e, ctx, helpers, config)
        ctx._zigzag_time = 0
    end,
    on_tick = function(e, ctx, helpers, config)
        ctx._zigzag_time = (ctx._zigzag_time or 0) + config.interval
        
        local base_angle = helpers.angle_to_player(e)
        local offset = math.sin(ctx._zigzag_time * (config.zigzag_frequency or 2.0) * math.pi * 2)
        local zigzag_angle = base_angle + offset * 0.5
        
        helpers.move_in_direction(e, zigzag_angle, config.speed)
    end,
})

-- TELEPORT: Periodically teleport near player
behaviors.register("teleport", {
    defaults = {
        interval = "teleport_cooldown",
        min_distance = 60,
        max_distance = 120,
    },
    on_tick = function(e, ctx, helpers, config)
        local player = helpers.get_player_position()
        local angle = math.random() * math.pi * 2
        local dist = (config.min_distance or 60) + math.random() * ((config.max_distance or 120) - (config.min_distance or 60))
        
        local transform = require("core.component_cache").get(e, Transform)
        if transform then
            helpers.spawn_particles("teleport_out", e)
            transform.actualX = player.x + math.cos(angle) * dist
            transform.actualY = player.y + math.sin(angle) * dist
            transform.visualX = transform.actualX
            transform.visualY = transform.actualY
            helpers.spawn_particles("teleport_in", e)
        end
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
-- Behavior Composition
--------------------------------------------------------------------------------

local composite_registry = {}

function behaviors.register_composite(name, def)
    assert(type(name) == "string", "Composite behavior name must be a string")
    assert(type(def) == "table", "Composite behavior definition must be a table")
    composite_registry[name] = def
end

function behaviors.apply_composite(e, ctx, helpers, composite_name)
    local def = composite_registry[composite_name]
    if not def then
        print("[behaviors] Unknown composite: " .. tostring(composite_name))
        return
    end
    
    if def.type == "sequence" then
        behaviors._apply_sequence(e, ctx, helpers, def)
    elseif def.type == "selector" then
        behaviors._apply_selector(e, ctx, helpers, def)
    elseif def.type == "parallel" then
        behaviors._apply_parallel(e, ctx, helpers, def)
    end
end

function behaviors._apply_sequence(e, ctx, helpers, def)
    local steps = def.steps or {}
    local current_step = 1
    local step_elapsed = 0
    
    local tag = string.format("composite_seq_%d_%s", e, tostring(math.random(10000)))
    active_timers[e] = active_timers[e] or {}
    table.insert(active_timers[e], tag)
    
    timer.every(0.016, function()
        if not entity_cache.valid(e) then return false end
        if current_step > #steps then
            if def.loop then
                current_step = 1
                step_elapsed = 0
            else
                return false
            end
        end
        
        local step = steps[current_step]
        local behavior_name = type(step) == "string" and step or step[1]
        local step_duration = type(step) == "table" and step.duration or 1.0
        
        local behavior_def = registry[behavior_name]
        if behavior_def and behavior_def.on_tick then
            local config = build_config(behavior_def, type(step) == "table" and step or {}, ctx)
            behavior_def.on_tick(e, ctx, helpers, config)
        end
        
        step_elapsed = step_elapsed + 0.016
        if step_elapsed >= step_duration then
            current_step = current_step + 1
            step_elapsed = 0
        end
    end, 0, true, nil, tag)
end

function behaviors._apply_selector(e, ctx, helpers, def)
    local conditions = def.conditions or {}
    local fallback = def.fallback
    
    local tag = string.format("composite_sel_%d_%s", e, tostring(math.random(10000)))
    active_timers[e] = active_timers[e] or {}
    table.insert(active_timers[e], tag)
    
    timer.every(def.interval or 0.5, function()
        if not entity_cache.valid(e) then return false end
        
        local selected = fallback
        for _, cond in ipairs(conditions) do
            if cond.check and cond.check(e, ctx, helpers) then
                selected = cond.behavior
                break
            end
        end
        
        if selected then
            local behavior_name = type(selected) == "string" and selected or selected[1]
            local behavior_def = registry[behavior_name]
            if behavior_def and behavior_def.on_tick then
                local config = build_config(behavior_def, type(selected) == "table" and selected or {}, ctx)
                behavior_def.on_tick(e, ctx, helpers, config)
            end
        end
    end, 0, true, nil, tag)
end

function behaviors._apply_parallel(e, ctx, helpers, def)
    local behavior_list = def.behaviors or {}
    behaviors.apply(e, ctx, helpers, behavior_list)
end

behaviors.register_composite("hit_and_run", {
    type = "sequence",
    loop = true,
    steps = {
        { "dash", duration = 0.3 },
        { "flee", duration = 2.0 },
    },
})

behaviors.register_composite("sniper", {
    type = "selector",
    interval = 0.3,
    conditions = {
        {
            check = function(e, ctx, helpers)
                return helpers.is_in_range(e, ctx.attack_range or 200)
            end,
            behavior = "ranged_attack",
        },
        {
            check = function(e, ctx, helpers)
                return helpers.distance_to_player(e) < (ctx.min_range or 100)
            end,
            behavior = "flee",
        },
    },
    fallback = "kite",
})

behaviors.register_composite("berserker", {
    type = "selector",
    interval = 0.3,
    conditions = {
        {
            check = function(e, ctx, helpers)
                return (ctx.hp / ctx.max_hp) < 0.3
            end,
            behavior = "rush",
        },
    },
    fallback = "chase",
})

--------------------------------------------------------------------------------
-- Module Export
--------------------------------------------------------------------------------

_G.__behaviors__ = behaviors
return behaviors
