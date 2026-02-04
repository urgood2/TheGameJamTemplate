-- assets/scripts/bargain/sim/terminal.lua
--[[
================================================================================
BARGAIN SIM: Terminal State Enforcement
================================================================================

This module enforces the terminal state contract:
- run_state can only be: "running", "victory", or "death"
- Transitions are ONE-WAY: running -> victory OR running -> death
- Once terminal, state cannot change (immutable)

CONTRACT:
No softlocks - every simulation path must eventually terminate in
either "victory" or "death". This is guaranteed by:
1. Step caps (MAX_STEPS_PER_RUN)
2. Transition caps (MAX_INTERNAL_TRANSITIONS)
3. HP depletion (always leads to death)
4. Boss defeat (always leads to victory)

USAGE:
    local Terminal = require("bargain.sim.terminal")
    local constants = require("bargain.sim.constants")

    -- Check if world is terminal
    if Terminal.is_terminal(world) then
        return  -- No more processing allowed
    end

    -- Attempt to transition (enforces one-way rule)
    local ok, err = Terminal.transition(world, constants.RUN_STATES.VICTORY)
    if not ok then
        -- Transition rejected (e.g., already terminal)
    end

    -- Validate run_state is legal
    if not Terminal.is_valid_state(world.run_state) then
        error("Invalid run_state")
    end

See: planning/PLAN.md §5.3, §4.3
]]

local Terminal = {}

local constants = require("bargain.sim.constants")

--------------------------------------------------------------------------------
-- State Validation
--------------------------------------------------------------------------------

--- Valid run states (frozen)
local VALID_STATES = {
    [constants.RUN_STATES.RUNNING] = true,
    [constants.RUN_STATES.VICTORY] = true,
    [constants.RUN_STATES.DEATH] = true,
}

--- Check if a run_state value is valid
--- @param state string The run_state to validate
--- @return boolean True if valid
function Terminal.is_valid_state(state)
    return VALID_STATES[state] == true
end

--- Check if world is in a terminal state (victory or death)
--- @param world table The world state
--- @return boolean True if terminal
function Terminal.is_terminal(world)
    return world.run_state == constants.RUN_STATES.VICTORY or
           world.run_state == constants.RUN_STATES.DEATH
end

--- Check if world is still running (not terminal)
--- @param world table The world state
--- @return boolean True if still running
function Terminal.is_running(world)
    return world.run_state == constants.RUN_STATES.RUNNING
end

--------------------------------------------------------------------------------
-- State Transitions
--------------------------------------------------------------------------------

--- Attempt to transition to a new run_state
--- Enforces one-way transition rule: running -> victory OR running -> death
--- @param world table The world state (will be modified on success)
--- @param new_state string The new run_state to transition to
--- @return boolean success True if transition was applied
--- @return string? error Error message if transition was rejected
function Terminal.transition(world, new_state)
    -- Validate new state
    if not Terminal.is_valid_state(new_state) then
        return false, "Invalid target state: " .. tostring(new_state)
    end

    -- Validate current state
    if not Terminal.is_valid_state(world.run_state) then
        return false, "World has invalid current state: " .. tostring(world.run_state)
    end

    -- If already terminal, no further transitions allowed
    if Terminal.is_terminal(world) then
        return false, "Cannot transition from terminal state: " .. world.run_state
    end

    -- Only transitions FROM running are allowed
    if world.run_state ~= constants.RUN_STATES.RUNNING then
        return false, "Can only transition from 'running', not: " .. world.run_state
    end

    -- Only transitions TO terminal states are allowed
    if new_state == constants.RUN_STATES.RUNNING then
        return false, "Cannot transition to 'running' - only victory or death"
    end

    -- Apply transition
    world.run_state = new_state
    return true
end

--- Force transition to death state (used by caps)
--- This bypasses normal validation for emergency termination
--- @param world table The world state (will be modified)
--- @param reason string? Optional reason for forced death
function Terminal.force_death(world, reason)
    world.run_state = constants.RUN_STATES.DEATH
    world.death_reason = reason or "forced"
end

--- Transition to victory state (used when boss is defeated)
--- @param world table The world state (will be modified)
--- @return boolean success True if transition was applied
--- @return string? error Error message if transition was rejected
function Terminal.set_victory(world)
    return Terminal.transition(world, constants.RUN_STATES.VICTORY)
end

--- Transition to death state (used when player HP <= 0)
--- @param world table The world state (will be modified)
--- @param reason string? Optional death reason
--- @return boolean success True if transition was applied
--- @return string? error Error message if transition was rejected
function Terminal.set_death(world, reason)
    local ok, err = Terminal.transition(world, constants.RUN_STATES.DEATH)
    if ok and reason then
        world.death_reason = reason
    end
    return ok, err
end

--------------------------------------------------------------------------------
-- Termination Guarantees
--------------------------------------------------------------------------------

--- Get a list of reasons why termination is guaranteed
--- @return table List of termination guarantees
function Terminal.get_termination_guarantees()
    return {
        {
            name = "step_cap",
            description = "MAX_STEPS_PER_RUN limits total steps",
            cap = constants.MAX_STEPS_PER_RUN,
        },
        {
            name = "transition_cap",
            description = "MAX_INTERNAL_TRANSITIONS prevents infinite loops per step",
            cap = constants.MAX_INTERNAL_TRANSITIONS,
        },
        {
            name = "hp_depletion",
            description = "Player HP <= 0 always triggers death",
            cap = nil,
        },
        {
            name = "boss_defeat",
            description = "Boss defeat on floor 7 always triggers victory",
            cap = nil,
        },
    }
end

--- Validate that a world state is not in a softlock
--- This checks for obvious impossible states
--- @param world table The world state to validate
--- @return boolean valid True if no softlock detected
--- @return string? error Description of detected softlock
function Terminal.check_for_softlock(world)
    -- Terminal states are always valid (not softlocked)
    if Terminal.is_terminal(world) then
        return true
    end

    -- Check for impossible states that could indicate softlock
    local player = world.entities[world.player_id]
    if player then
        -- Dead player but still running -> softlock
        if player.hp and player.hp <= 0 and world.run_state == constants.RUN_STATES.RUNNING then
            return false, "Player has 0 HP but run_state is still 'running'"
        end
    end

    -- Check turn count
    if world.turn >= constants.MAX_STEPS_PER_RUN then
        return false, "Turn count exceeds MAX_STEPS_PER_RUN but run_state is still 'running'"
    end

    return true
end

return Terminal
