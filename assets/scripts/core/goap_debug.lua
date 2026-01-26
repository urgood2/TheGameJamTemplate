--[[
================================================================================
goap_debug.lua - GOAP Debug Overlay System
================================================================================
Provides in-game debugging for GOAP (Goal-Oriented Action Planning) AI systems.

This module is designed to be a **no-op when disabled** with zero overhead.
When enabled, it stores per-entity debug info about:
  - Current goal and priority
  - Active plan (action sequence)
  - Current plan index (which step is executing)
  - World state driving decisions
  - Rejected actions with reasons (bounded ring buffer)

Usage:
    local goap_debug = require("core.goap_debug")

    -- Enable debugging (usually via debug key like F3)
    goap_debug.enable()

    -- In your GOAP planner, emit debug info:
    goap_debug.set_current_goal(entity, "KillPlayer", 0.9)
    goap_debug.set_plan(entity, { "FindWeapon", "ApproachTarget", "AttackMelee" })
    goap_debug.set_plan_index(entity, 2)
    goap_debug.set_world_state(entity, { has_weapon = true, ammo = 0 })
    goap_debug.add_rejected_action(entity, "RangedAttack", "ammo = 0 (need > 0)")

    -- In your renderer, get info for selected entity:
    local info = goap_debug.get_entity_debug_info(selected_entity)
    if info then
        -- Render overlay with info.goal_name, info.plan, etc.
    end

    -- Selection for detailed view:
    goap_debug.select_entity(clicked_entity)
    local selected = goap_debug.get_selected_entity()

Performance:
    - When disabled: All functions are no-ops, zero allocations
    - When enabled: Minimal overhead, bounded data structures
    - Rejected actions use ring buffer (default max: 10)
]]

---@class GOAPDebug
---@field enable fun() Enable debug mode
---@field disable fun() Disable debug mode
---@field is_enabled fun(): boolean Check if enabled
---@field set_current_goal fun(entity: number, goal_name: string, priority: number)
---@field set_plan fun(entity: number, plan: string[])
---@field set_plan_index fun(entity: number, index: number)
---@field set_world_state fun(entity: number, state: table)
---@field add_rejected_action fun(entity: number, action: string, reason: string)
---@field get_entity_debug_info fun(entity: number): GOAPEntityInfo|nil
---@field clear_entity fun(entity: number)
---@field get_tracked_entities fun(): number[]
---@field select_entity fun(entity: number|nil)
---@field get_selected_entity fun(): number|nil
---@field set_max_rejected_actions fun(max: number)

---@class GOAPEntityInfo
---@field goal_name string|nil Current goal name
---@field goal_priority number|nil Goal priority (0-1)
---@field plan string[]|nil Current plan (action sequence)
---@field plan_index number|nil Current step index (1-based)
---@field world_state table|nil World state key-value pairs
---@field rejected_actions GOAPRejectedAction[] Rejected actions with reasons
---@field current_action string|nil Currently executing action
---@field action_preconditions GOAPActionPreconditions|nil Preconditions for current action
---@field action_cost GOAPActionCost|nil Cost breakdown for current action
---@field competing_actions GOAPCompetingAction[] Actions that lost to current action

---@class GOAPRejectedAction
---@field action string Action name
---@field reason string Why it was rejected

---@class GOAPActionPreconditions
---@field action string Action name
---@field conditions GOAPPrecondition[] List of preconditions

---@class GOAPPrecondition
---@field name string Precondition name
---@field met boolean Whether the precondition is met
---@field required any Required value
---@field actual any Actual value

---@class GOAPActionCost
---@field action string Action name
---@field total number Total cost
---@field breakdown GOAPCostComponent[] Cost breakdown

---@class GOAPCostComponent
---@field name string Component name
---@field value number Component value

---@class GOAPCompetingAction
---@field action string Action name
---@field cost number|nil Cost (nil if preconditions failed)
---@field reason string Why it was not chosen

------------------------------------------------------------
-- Internal State
------------------------------------------------------------
local goap_debug = {}

local _enabled = false
local _entity_data = {}  -- entity_id -> GOAPEntityInfo
local _selected_entity = nil
local _max_rejected = 10  -- Ring buffer size for rejected actions
local _max_competing = 10  -- Ring buffer size for competing actions

------------------------------------------------------------
-- Enable/Disable
------------------------------------------------------------

--- Enable GOAP debug overlay.
function goap_debug.enable()
    _enabled = true
end

--- Disable GOAP debug overlay. Clears all stored data.
function goap_debug.disable()
    _enabled = false
    _entity_data = {}
    _selected_entity = nil
end

--- Check if debug mode is enabled.
---@return boolean
function goap_debug.is_enabled()
    return _enabled
end

------------------------------------------------------------
-- Configuration
------------------------------------------------------------

--- Set maximum number of rejected actions to store per entity.
---@param max number Maximum size of ring buffer (default: 10)
function goap_debug.set_max_rejected_actions(max)
    _max_rejected = max or 10
end

--- Set maximum number of competing actions to store per entity.
---@param max number Maximum size of ring buffer (default: 10)
function goap_debug.set_max_competing_actions(max)
    _max_competing = max or 10
end

------------------------------------------------------------
-- Internal Helpers
------------------------------------------------------------

--- Ensure entity has a data table (only when enabled).
---@param entity number
---@return table|nil
local function ensure_entity_data(entity)
    if not _enabled then return nil end
    if not _entity_data[entity] then
        _entity_data[entity] = {
            goal_name = nil,
            goal_priority = nil,
            plan = nil,
            plan_index = nil,
            world_state = nil,
            rejected_actions = {},
            -- Action selection breakdown
            current_action = nil,
            action_preconditions = nil,
            action_cost = nil,
            competing_actions = {}
        }
    end
    return _entity_data[entity]
end

------------------------------------------------------------
-- Goal/Plan/State Setters
------------------------------------------------------------

--- Set the current goal for an entity.
---@param entity number Entity ID
---@param goal_name string Name of the goal
---@param priority number Priority (0-1, higher = more important)
function goap_debug.set_current_goal(entity, goal_name, priority)
    local data = ensure_entity_data(entity)
    if not data then return end
    data.goal_name = goal_name
    data.goal_priority = priority
end

--- Set the current plan (action sequence) for an entity.
---@param entity number Entity ID
---@param plan string[] List of action names
function goap_debug.set_plan(entity, plan)
    local data = ensure_entity_data(entity)
    if not data then return end
    if plan == nil then
        data.plan = nil
        return
    end
    -- Copy the plan to avoid external mutation
    data.plan = {}
    for i, action in ipairs(plan) do
        data.plan[i] = action
    end
end

--- Set the current plan index (which step is executing).
---@param entity number Entity ID
---@param index number 1-based index into the plan
function goap_debug.set_plan_index(entity, index)
    local data = ensure_entity_data(entity)
    if not data then return end
    data.plan_index = index
end

--- Set the world state for an entity.
---@param entity number Entity ID
---@param state table Key-value pairs of world state
function goap_debug.set_world_state(entity, state)
    local data = ensure_entity_data(entity)
    if not data then return end
    if state == nil then
        data.world_state = nil
        return
    end
    -- Shallow copy the state
    data.world_state = {}
    for k, v in pairs(state) do
        data.world_state[k] = v
    end
end

--- Add a rejected action with reason (ring buffer, bounded).
---@param entity number Entity ID
---@param action string Action name that was rejected
---@param reason string Explanation of why it was rejected
function goap_debug.add_rejected_action(entity, action, reason)
    local data = ensure_entity_data(entity)
    if not data then return end

    local rejected = data.rejected_actions

    -- Add new entry
    table.insert(rejected, { action = action, reason = reason })

    -- Enforce ring buffer limit (remove oldest)
    while #rejected > _max_rejected do
        table.remove(rejected, 1)
    end
end

------------------------------------------------------------
-- Action Selection Breakdown
------------------------------------------------------------

--- Set the current action being executed.
---@param entity number Entity ID
---@param action_name string Name of the action
function goap_debug.set_current_action(entity, action_name)
    local data = ensure_entity_data(entity)
    if not data then return end
    data.current_action = action_name
end

--- Set preconditions for an action with met/unmet status.
---@param entity number Entity ID
---@param action string Action name
---@param preconditions table[] Array of {name, met, required, actual}
function goap_debug.set_action_preconditions(entity, action, preconditions)
    local data = ensure_entity_data(entity)
    if not data then return end
    if preconditions == nil then
        data.action_preconditions = nil
        return
    end

    -- Copy preconditions to avoid external mutation
    local conditions = {}
    for i, cond in ipairs(preconditions) do
        conditions[i] = {
            name = cond.name,
            met = cond.met,
            required = cond.required,
            actual = cond.actual
        }
    end

    data.action_preconditions = {
        action = action,
        conditions = conditions
    }
end

--- Set the cost breakdown for the current action.
---@param entity number Entity ID
---@param action string Action name
---@param total number Total cost
---@param breakdown table[] Array of {name, value} cost components
function goap_debug.set_action_cost(entity, action, total, breakdown)
    local data = ensure_entity_data(entity)
    if not data then return end
    if breakdown == nil then
        data.action_cost = {
            action = action,
            total = total,
            breakdown = {}
        }
        return
    end

    -- Copy breakdown to avoid external mutation
    local components = {}
    for i, comp in ipairs(breakdown) do
        components[i] = {
            name = comp.name,
            value = comp.value
        }
    end

    data.action_cost = {
        action = action,
        total = total,
        breakdown = components
    }
end

--- Add a competing action with why it lost (ring buffer, bounded).
---@param entity number Entity ID
---@param action string Action name that lost
---@param cost number|nil Cost of the action (nil if preconditions failed)
---@param reason string Why it was not chosen
function goap_debug.add_competing_action(entity, action, cost, reason)
    local data = ensure_entity_data(entity)
    if not data then return end

    local competing = data.competing_actions

    -- Add new entry
    table.insert(competing, {
        action = action,
        cost = cost,
        reason = reason
    })

    -- Enforce ring buffer limit (remove oldest)
    while #competing > _max_competing do
        table.remove(competing, 1)
    end
end

------------------------------------------------------------
-- Getters
------------------------------------------------------------

--- Get debug info for an entity.
---@param entity number Entity ID
---@return GOAPEntityInfo|nil Debug info or nil if not tracked/disabled
function goap_debug.get_entity_debug_info(entity)
    if not _enabled then return nil end
    return _entity_data[entity]
end

--- Clear all debug data for an entity.
---@param entity number Entity ID
function goap_debug.clear_entity(entity)
    if not _enabled then return end
    _entity_data[entity] = nil
end

--- Get list of all tracked entity IDs.
---@return number[] List of entity IDs
function goap_debug.get_tracked_entities()
    local entities = {}
    for entity_id, _ in pairs(_entity_data) do
        table.insert(entities, entity_id)
    end
    return entities
end

------------------------------------------------------------
-- Entity Selection (for detailed view)
------------------------------------------------------------

--- Select an entity for detailed debug view.
---@param entity number|nil Entity ID or nil to deselect
function goap_debug.select_entity(entity)
    _selected_entity = entity
end

--- Get the currently selected entity.
---@return number|nil Selected entity ID or nil
function goap_debug.get_selected_entity()
    return _selected_entity
end

------------------------------------------------------------
-- Initialization Log
------------------------------------------------------------
if _G.log_debug then
    log_debug("[goap_debug] Module loaded (disabled by default)")
end

return goap_debug
