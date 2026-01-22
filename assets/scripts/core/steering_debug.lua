--[[
================================================================================
steering_debug.lua - Steering Behavior Debug Visualization
================================================================================
Provides in-game debugging for steering behaviors (flee, attack, seek, etc.).

This module stores per-entity vector data for visualization:
  - Individual behavior force vectors
  - Final blended vector
  - Weights/priorities
  - Optional color hints for rendering

Like goap_debug, this is a **no-op when disabled** with zero overhead.

Usage:
    local steering_debug = require("core.steering_debug")

    -- Enable debugging (usually via debug key)
    steering_debug.enable()

    -- In your steering system, emit vector data:
    steering_debug.set_entity_position(entity, x, y)
    steering_debug.add_behavior_vector(entity, "flee", vx, vy, weight, color?)
    steering_debug.add_behavior_vector(entity, "attack", vx, vy, weight)
    steering_debug.set_final_vector(entity, final_x, final_y)

    -- In your renderer, get vectors for visualization:
    local vectors = steering_debug.get_entity_vectors(entity)
    if vectors then
        -- Draw arrows from vectors.position using vectors.behaviors
        -- Draw final blended arrow from vectors.final
    end

    -- Call at frame start to clear old data:
    steering_debug.begin_frame()

Performance:
    - When disabled: All functions are no-ops, zero allocations
    - When enabled: Minimal overhead, data cleared each frame
]]

---@class SteeringDebug
---@field enable fun() Enable debug mode
---@field disable fun() Disable debug mode
---@field is_enabled fun(): boolean Check if enabled
---@field begin_frame fun() Clear data for new frame
---@field set_entity_position fun(entity: number, x: number, y: number)
---@field add_behavior_vector fun(entity: number, name: string, x: number, y: number, weight: number, color?: table)
---@field set_final_vector fun(entity: number, x: number, y: number)
---@field get_entity_vectors fun(entity: number): SteeringVectors|nil
---@field clear_entity fun(entity: number)
---@field get_tracked_entities fun(): number[]

---@class SteeringVectors
---@field position {x: number, y: number}|nil Entity position for visualization
---@field behaviors SteeringBehavior[] List of behavior vectors
---@field final {x: number, y: number}|nil Final blended vector

---@class SteeringBehavior
---@field name string Behavior name
---@field x number X component of force vector
---@field y number Y component of force vector
---@field weight number Weight/priority (0-1)
---@field color table|nil Optional color hint {r, g, b}

------------------------------------------------------------

local steering_debug = {}

local _enabled = false
local _entity_data = {}  -- entity_id -> SteeringVectors

------------------------------------------------------------
-- Enable/Disable
------------------------------------------------------------

function steering_debug.enable()
    _enabled = true
end

function steering_debug.disable()
    _enabled = false
    _entity_data = {}
end

function steering_debug.is_enabled()
    return _enabled
end

------------------------------------------------------------
-- Frame Management
------------------------------------------------------------

function steering_debug.begin_frame()
    if not _enabled then return end
    _entity_data = {}
end

------------------------------------------------------------
-- Internal Helpers
------------------------------------------------------------

local function ensure_entity_data(entity)
    if not _enabled then return nil end
    if not _entity_data[entity] then
        _entity_data[entity] = {
            position = nil,
            behaviors = {},
            final = nil
        }
    end
    return _entity_data[entity]
end

------------------------------------------------------------
-- Data Setters
------------------------------------------------------------

--- Set entity position for visualization origin.
---@param entity number Entity ID
---@param x number World X position
---@param y number World Y position
function steering_debug.set_entity_position(entity, x, y)
    local data = ensure_entity_data(entity)
    if not data then return end
    data.position = { x = x, y = y }
end

--- Add a behavior's force vector.
---@param entity number Entity ID
---@param name string Behavior name (e.g., "flee", "attack")
---@param x number X component of force
---@param y number Y component of force
---@param weight number Weight/priority (0-1)
---@param color? table Optional color hint {r, g, b}
function steering_debug.add_behavior_vector(entity, name, x, y, weight, color)
    local data = ensure_entity_data(entity)
    if not data then return end

    table.insert(data.behaviors, {
        name = name,
        x = x,
        y = y,
        weight = weight,
        color = color
    })
end

--- Set the final blended vector.
---@param entity number Entity ID
---@param x number X component of final force
---@param y number Y component of final force
function steering_debug.set_final_vector(entity, x, y)
    local data = ensure_entity_data(entity)
    if not data then return end
    data.final = { x = x, y = y }
end

------------------------------------------------------------
-- Getters
------------------------------------------------------------

--- Get all vector data for an entity.
---@param entity number Entity ID
---@return SteeringVectors|nil
function steering_debug.get_entity_vectors(entity)
    if not _enabled then return nil end
    return _entity_data[entity]
end

--- Clear data for a specific entity.
---@param entity number Entity ID
function steering_debug.clear_entity(entity)
    if not _enabled then return end
    _entity_data[entity] = nil
end

--- Get list of all tracked entity IDs.
---@return number[]
function steering_debug.get_tracked_entities()
    local entities = {}
    for entity_id, _ in pairs(_entity_data) do
        table.insert(entities, entity_id)
    end
    return entities
end

------------------------------------------------------------
-- Initialization Log
------------------------------------------------------------
if _G.log_debug then
    log_debug("[steering_debug] Module loaded (disabled by default)")
end

return steering_debug
