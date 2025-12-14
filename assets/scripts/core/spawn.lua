--[[
================================================================================
SPAWN MODULE - Fluent API for One-Line Entity Spawning
================================================================================
Provides convenient one-line functions to spawn entities using presets from
data.spawn_presets. Built on top of EntityBuilder and PhysicsBuilder.

Usage:
    local spawn = require("core.spawn")

    -- Spawn enemy at position
    local entity, script = spawn.enemy("kobold", 100, 200)

    -- Spawn with overrides
    local entity, script = spawn.enemy("kobold", 100, 200, {
        health = 200,  -- Override default health
        damage = 25    -- Override default damage
    })

    -- Spawn projectile with direction and owner
    local entity = spawn.projectile("fireball", x, y, direction, {
        owner = playerEntity,
        damage = 50
    })

    -- Spawn pickup
    local entity = spawn.pickup("gold_coin", x, y)

    -- Spawn effect
    local entity = spawn.effect("explosion", x, y)

Design Principles (per CLAUDE.md):
  - Data must be assigned BEFORE attach_ecs (EntityBuilder handles this)
  - Use signal.emit() for events
  - Validate entities with entity_cache.valid()
  - Use PhysicsManager.get_world("world") for physics

Dependencies:
    - data.spawn_presets (preset data)
    - core.entity_builder (EntityBuilder API)
    - core.physics_builder (PhysicsBuilder API)
    - core.entity_cache (validation)
    - external.hump.signal (events)
]]

-- Singleton guard
if _G.__SPAWN_MODULE__ then
    return _G.__SPAWN_MODULE__
end

local spawn = {}

-- Dependencies
local SpawnPresets = require("data.spawn_presets")
local EntityBuilder = require("core.entity_builder")
local entity_cache = require("core.entity_cache")
local signal = require("external.hump.signal")

-- Optional dependencies (lazy-loaded)
local PhysicsBuilder
local component_cache
local physics
local PhysicsManager

--------------------------------------------------------------------------------
-- PRIVATE HELPERS
--------------------------------------------------------------------------------

--- Deep merge two tables (overrides take precedence)
--- @param base table The base table
--- @param overrides table? The overrides table
--- @return table merged The merged table
local function deep_merge(base, overrides)
    if not overrides then
        -- Return a shallow copy of base
        local result = {}
        for k, v in pairs(base) do
            result[k] = v
        end
        return result
    end

    local result = {}

    -- Copy base
    for k, v in pairs(base) do
        if type(v) == "table" and type(overrides[k]) == "table" then
            result[k] = deep_merge(v, overrides[k])
        else
            result[k] = v
        end
    end

    -- Apply overrides
    for k, v in pairs(overrides) do
        if type(v) == "table" and type(base[k]) == "table" then
            result[k] = deep_merge(base[k], v)
        else
            result[k] = v
        end
    end

    return result
end

--- Apply physics to entity using PhysicsBuilder
--- @param entity number Entity ID
--- @param physicsConfig table Physics configuration
--- @return boolean success
local function apply_physics(entity, physicsConfig)
    if not physicsConfig then return true end

    -- Lazy-load PhysicsBuilder
    if not PhysicsBuilder then
        local ok, pb = pcall(require, "core.physics_builder")
        if ok then
            PhysicsBuilder = pb
        else
            log_warn("spawn: PhysicsBuilder not available, skipping physics setup")
            return false
        end
    end

    return PhysicsBuilder.quick(entity, physicsConfig)
end

--- Apply velocity to entity based on direction and speed
--- @param entity number Entity ID
--- @param direction number Angle in radians
--- @param speed number Speed in pixels/second
local function apply_velocity(entity, direction, speed)
    -- Lazy-load dependencies
    if not component_cache then
        component_cache = require("core.component_cache")
    end
    if not physics then
        physics = _G.physics
    end
    if not PhysicsManager then
        local ok, pm = pcall(require, "core.physics_manager")
        if ok then PhysicsManager = pm end
    end

    if not physics or not PhysicsManager then
        log_warn("spawn: physics not available, cannot set velocity")
        return
    end

    local world = PhysicsManager.get_world("world")
    if not world then
        log_warn("spawn: physics world not available")
        return
    end

    -- Calculate velocity components
    local vx = math.cos(direction) * speed
    local vy = math.sin(direction) * speed

    -- Set velocity on physics body
    if physics.SetVelocity then
        physics.SetVelocity(world, entity, { x = vx, y = vy })
    end
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Spawn an entity from a preset
--- @param category string Category name (enemies, projectiles, pickups, effects)
--- @param preset_id string Preset ID within category
--- @param x number X position
--- @param y number Y position
--- @param overrides table? Override values
--- @return number? entity The entity ID (nil on failure)
--- @return table? script The script table (nil if no data)
function spawn.from_preset(category, preset_id, x, y, overrides)
    -- Validate category
    if not SpawnPresets[category] then
        log_warn("spawn.from_preset: unknown category '" .. tostring(category) .. "'")
        return nil, nil
    end

    -- Validate preset
    local preset = SpawnPresets[category][preset_id]
    if not preset then
        log_warn("spawn.from_preset: unknown preset '" .. tostring(preset_id) .. "' in category '" .. category .. "'")
        return nil, nil
    end

    -- Validate position
    if type(x) ~= "number" or type(y) ~= "number" then
        log_warn("spawn.from_preset: invalid position (" .. tostring(x) .. ", " .. tostring(y) .. ")")
        return nil, nil
    end

    -- Merge preset with overrides
    local config = deep_merge(preset, overrides)

    -- Extract physics config (separate from EntityBuilder opts)
    local physicsConfig = config.physics
    config.physics = nil  -- Remove from EntityBuilder config

    -- Build EntityBuilder options
    local opts = {
        sprite = config.sprite,
        position = { x = x, y = y },
        size = config.size,
        shadow = config.shadow,
        data = config.data,
        interactive = config.interactive,
        state = config.state,
        shaders = config.shaders,
    }

    -- Create entity
    local entity, script = EntityBuilder.create(opts)

    if not entity or not entity_cache.valid(entity) then
        log_warn("spawn.from_preset: failed to create entity for preset '" .. preset_id .. "'")
        return nil, nil
    end

    -- Apply physics if config provided
    if physicsConfig then
        apply_physics(entity, physicsConfig)
    end

    return entity, script
end

--- Spawn an enemy entity
--- @param preset_id string Preset ID (e.g., "kobold", "slime", "skeleton")
--- @param x number X position
--- @param y number Y position
--- @param overrides table? Override values
--- @return number? entity The entity ID (nil on failure)
--- @return table? script The script table (nil if no data)
function spawn.enemy(preset_id, x, y, overrides)
    local entity, script = spawn.from_preset("enemies", preset_id, x, y, overrides)

    if entity then
        -- Emit event
        signal.emit("enemy_spawned", entity, { preset_id = preset_id })
    end

    return entity, script
end

--- Spawn a projectile entity
--- @param preset_id string Preset ID (e.g., "basic_bolt", "fireball", "ice_shard")
--- @param x number X position
--- @param y number Y position
--- @param direction number? Direction angle in radians (default: 0)
--- @param overrides table? Override values
--- @return number? entity The entity ID (nil on failure)
function spawn.projectile(preset_id, x, y, direction, overrides)
    direction = direction or 0
    overrides = overrides or {}

    -- Spawn entity
    local entity, script = spawn.from_preset("projectiles", preset_id, x, y, overrides)

    if not entity then
        return nil
    end

    -- Apply velocity based on direction and speed
    local speed = (script and script.speed) or (overrides.speed) or 300
    apply_velocity(entity, direction, speed)

    -- Emit event
    signal.emit("projectile_spawned", entity, {
        preset_id = preset_id,
        direction = direction,
        speed = speed,
        owner = script and script.owner
    })

    return entity
end

--- Spawn a pickup entity
--- @param preset_id string Preset ID (e.g., "exp_orb", "gold_coin", "health_potion")
--- @param x number X position
--- @param y number Y position
--- @param overrides table? Override values
--- @return number? entity The entity ID (nil on failure)
--- @return table? script The script table (nil if no data)
function spawn.pickup(preset_id, x, y, overrides)
    local entity, script = spawn.from_preset("pickups", preset_id, x, y, overrides)

    if entity then
        -- Emit event
        signal.emit("pickup_spawned", entity, {
            preset_id = preset_id,
            pickup_type = script and script.pickup_type
        })
    end

    return entity, script
end

--- Spawn an effect entity
--- @param preset_id string Preset ID (e.g., "explosion", "hit_spark", "smoke_puff")
--- @param x number X position
--- @param y number Y position
--- @param overrides table? Override values
--- @return number? entity The entity ID (nil on failure)
--- @return table? script The script table (nil if no data)
function spawn.effect(preset_id, x, y, overrides)
    local entity, script = spawn.from_preset("effects", preset_id, x, y, overrides)

    if entity then
        -- Auto-destroy effect after lifetime (if specified)
        local lifetime = script and script.lifetime
        if lifetime and type(lifetime) == "number" and lifetime > 0 then
            -- Lazy-load timer
            local timer = require("core.timer")
            timer.after(lifetime / 1000, function()
                if entity_cache.valid(entity) then
                    local registry = _G.registry
                    if registry then
                        registry:destroy(entity)
                    end
                end
            end)
        end

        -- Emit event
        signal.emit("effect_spawned", entity, {
            preset_id = preset_id,
            effect_type = script and script.effect_type
        })
    end

    return entity, script
end

_G.__SPAWN_MODULE__ = spawn
return spawn
