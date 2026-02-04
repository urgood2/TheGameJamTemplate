-- assets/scripts/bargain/sim/caps.lua
--[[
================================================================================
BARGAIN SIM: Caps (Termination Guards)
================================================================================

This module enforces hard limits to guarantee simulation termination.
Any cap breach triggers forced death state to prevent softlocks.

CAPS:
- MAX_INTERNAL_TRANSITIONS: 64  -- Max phase transitions per step() call
- MAX_STEPS_PER_RUN: 5000       -- Max steps in a single run
- MAX_PROCGEN_ATTEMPTS: 100     -- Max attempts per floor generation (future)

CONTRACT:
On any cap trip:
1. Set world.caps_hit = true
2. Set world.run_state = "death"
3. Emit repro JSON (via callback)

USAGE:
    local Caps = require("bargain.sim.caps")

    -- Check step cap
    if Caps.check_step_cap(world) then
        -- Cap hit, world modified to terminal state
        return
    end

    -- Check transition cap (within step)
    local transition_count = 0
    while transition_count < Caps.MAX_INTERNAL_TRANSITIONS do
        -- ... do transition
        transition_count = transition_count + 1
    end
    if transition_count >= Caps.MAX_INTERNAL_TRANSITIONS then
        Caps.trip_cap(world, "internal_transitions", transition_count)
    end

See: planning/PLAN.md §5.3 (Caps)
]]

local Caps = {}
local death = require("bargain.sim.death")

--------------------------------------------------------------------------------
-- Cap Constants (Hard)
--------------------------------------------------------------------------------

--- Maximum internal phase transitions allowed per step() call
--- Prevents infinite loops within a single step
Caps.MAX_INTERNAL_TRANSITIONS = 64

--- Maximum steps allowed in a single run
--- Prevents infinite runs that never terminate
Caps.MAX_STEPS_PER_RUN = 5000

--- Maximum procgen attempts per floor before deterministic fallback
--- Prevents infinite generation loops
Caps.MAX_PROCGEN_ATTEMPTS = 100

--------------------------------------------------------------------------------
-- Cap State Tracking
--------------------------------------------------------------------------------

--- Tracks the number of internal transitions in the current step
--- Reset at the start of each step() call
local current_step_transitions = 0

--- Resets the transition counter (call at start of each step)
function Caps.reset_transition_counter()
    current_step_transitions = 0
end

--- Increments and checks the transition counter
--- @param world table The world state
--- @return boolean True if cap was hit
function Caps.count_transition(world)
    current_step_transitions = current_step_transitions + 1
    if current_step_transitions >= Caps.MAX_INTERNAL_TRANSITIONS then
        Caps.trip_cap(world, "internal_transitions", current_step_transitions)
        return true
    end
    return false
end

--- Gets the current transition count
--- @return number Current count of transitions
function Caps.get_transition_count()
    return current_step_transitions
end

--------------------------------------------------------------------------------
-- Cap Check Functions
--------------------------------------------------------------------------------

--- Checks if step cap has been reached
--- @param world table The world state
--- @return boolean True if cap hit (world modified to terminal)
function Caps.check_step_cap(world)
    if world.turn >= Caps.MAX_STEPS_PER_RUN then
        Caps.trip_cap(world, "max_steps", world.turn)
        return true
    end
    return false
end

--- Checks if a cap condition is about to be violated
--- @param current number Current counter value
--- @param cap_type string Type of cap ("internal_transitions", "max_steps", "procgen_attempts")
--- @return boolean True if over cap limit
function Caps.is_over_cap(current, cap_type)
    if cap_type == "internal_transitions" then
        return current >= Caps.MAX_INTERNAL_TRANSITIONS
    elseif cap_type == "max_steps" then
        return current >= Caps.MAX_STEPS_PER_RUN
    elseif cap_type == "procgen_attempts" then
        return current >= Caps.MAX_PROCGEN_ATTEMPTS
    else
        error("Unknown cap type: " .. tostring(cap_type))
    end
end

--------------------------------------------------------------------------------
-- Cap Trip (Forced Termination)
--------------------------------------------------------------------------------

--- Trips a cap, forcing the game into terminal death state
--- @param world table The world state (will be modified)
--- @param cap_type string Type of cap that was hit
--- @param value number The value that triggered the cap
function Caps.trip_cap(world, cap_type, value)
    assert(type(world) == "table", "trip_cap requires world table")
    assert(type(cap_type) == "string", "trip_cap requires cap_type string")

    -- Mark cap as hit
    world.caps_hit = true
    world.caps_type = cap_type
    world.caps_value = value

    -- Force terminal state
    death.set(world, "cap_" .. cap_type)

    -- Log for debugging
    if io and io.stderr then
        io.stderr:write(string.format(
            "[CAPS] Tripped: %s = %d (limit: %d)\n",
            cap_type,
            value,
            cap_type == "internal_transitions" and Caps.MAX_INTERNAL_TRANSITIONS or
            cap_type == "max_steps" and Caps.MAX_STEPS_PER_RUN or
            cap_type == "procgen_attempts" and Caps.MAX_PROCGEN_ATTEMPTS or 0
        ))
    end
end

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

--- Creates a caps guard that can be used in a loop
--- @param world table The world state
--- @param cap_type string Type of cap to guard
--- @return function Iterator-like guard function that returns false when cap hit
function Caps.guard(world, cap_type)
    local count = 0
    local limit

    if cap_type == "internal_transitions" then
        limit = Caps.MAX_INTERNAL_TRANSITIONS
    elseif cap_type == "procgen_attempts" then
        limit = Caps.MAX_PROCGEN_ATTEMPTS
    else
        error("guard() does not support cap type: " .. tostring(cap_type))
    end

    return function()
        count = count + 1
        if count > limit then
            Caps.trip_cap(world, cap_type, count)
            return false
        end
        return true
    end
end

--- Validates that world has proper caps-related fields
--- @param world table The world state to validate
--- @return boolean, string True if valid, else false and error message
function Caps.validate_world(world)
    if type(world) ~= "table" then
        return false, "world must be a table"
    end

    -- Required fields
    if type(world.turn) ~= "number" then
        return false, "world.turn must be a number"
    end

    if type(world.run_state) ~= "string" then
        return false, "world.run_state must be a string"
    end

    -- caps_hit should be boolean or nil (defaults to false)
    if world.caps_hit ~= nil and type(world.caps_hit) ~= "boolean" then
        return false, "world.caps_hit must be boolean or nil"
    end

    return true
end

--- Checks if world is in a terminal state
--- @param world table The world state
--- @return boolean True if world has reached a terminal state
function Caps.is_terminal(world)
    return world.run_state == "death" or world.run_state == "victory"
end

return Caps
