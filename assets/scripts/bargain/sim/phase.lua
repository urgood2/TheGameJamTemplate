-- assets/scripts/bargain/sim/phase.lua
--[[
================================================================================
BARGAIN SIM: Phase State Machine
================================================================================

The game operates in distinct phases with well-defined transitions:

  DEAL_CHOICE -> PLAYER_INPUT -> PLAYER_ACTION -> ENEMY_ACTIONS -> END_TURN -> ...
                       ^______________________________________________|

Key Rules:
1. DEAL_CHOICE pins until the player accepts or declines the offer
2. Phases progress in canonical order
3. END_TURN increments the turn counter and loops back to PLAYER_INPUT
4. Enemy ordering: speed DESC, then id ASC for tie-breaks

This module provides a table-driven state machine for deterministic phase handling.
]]

local constants = require("bargain.sim.constants")

local Phase = {}

--------------------------------------------------------------------------------
-- Phase Constants (re-exported for convenience)
--------------------------------------------------------------------------------

Phase.PHASES = constants.PHASES

-- Canonical phase order (excluding DEAL_CHOICE which is interruptive)
Phase.CANONICAL_ORDER = {
    constants.PHASES.PLAYER_INPUT,
    constants.PHASES.PLAYER_ACTION,
    constants.PHASES.ENEMY_ACTIONS,
    constants.PHASES.END_TURN,
}

-- Map each phase to its next phase in the canonical cycle
Phase.TRANSITIONS = {
    [constants.PHASES.PLAYER_INPUT]  = constants.PHASES.PLAYER_ACTION,
    [constants.PHASES.PLAYER_ACTION] = constants.PHASES.ENEMY_ACTIONS,
    [constants.PHASES.ENEMY_ACTIONS] = constants.PHASES.END_TURN,
    [constants.PHASES.END_TURN]      = constants.PHASES.PLAYER_INPUT,
    -- DEAL_CHOICE always goes to PLAYER_INPUT when resolved
    [constants.PHASES.DEAL_CHOICE]   = constants.PHASES.PLAYER_INPUT,
}

-- Valid inputs for each phase
Phase.ALLOWED_INPUTS = {
    [constants.PHASES.DEAL_CHOICE] = {
        deal_choose = true,
        deal_skip = true,
    },
    [constants.PHASES.PLAYER_INPUT] = {
        move = true,
        attack = true,
        wait = true,
    },
    [constants.PHASES.PLAYER_ACTION] = {
        -- Player action phase is auto-resolved (no input)
    },
    [constants.PHASES.ENEMY_ACTIONS] = {
        -- Enemy action phase is auto-resolved (no input)
    },
    [constants.PHASES.END_TURN] = {
        -- End turn phase is auto-resolved (no input)
    },
}

--------------------------------------------------------------------------------
-- Phase Query Functions
--------------------------------------------------------------------------------

--- Check if input is valid for the current phase
--- @param phase string Current phase
--- @param input_type string Type of input
--- @return boolean is_valid
function Phase.is_input_allowed(phase, input_type)
    local allowed = Phase.ALLOWED_INPUTS[phase]
    if not allowed then
        return false
    end
    return allowed[input_type] == true
end

--- Check if phase requires player input
--- @param phase string
--- @return boolean needs_input
function Phase.needs_input(phase)
    return phase == constants.PHASES.DEAL_CHOICE or
           phase == constants.PHASES.PLAYER_INPUT
end

--- Check if phase is auto-resolved (no input needed)
--- @param phase string
--- @return boolean is_auto
function Phase.is_auto_resolved(phase)
    return phase == constants.PHASES.PLAYER_ACTION or
           phase == constants.PHASES.ENEMY_ACTIONS or
           phase == constants.PHASES.END_TURN
end

--- Check if currently in DEAL_CHOICE (pinned until resolved)
--- @param phase string
--- @return boolean is_deal
function Phase.is_deal_choice(phase)
    return phase == constants.PHASES.DEAL_CHOICE
end

--------------------------------------------------------------------------------
-- Phase Transition Functions
--------------------------------------------------------------------------------

--- Get the next phase in the canonical cycle
--- @param current_phase string
--- @return string next_phase
function Phase.get_next_phase(current_phase)
    return Phase.TRANSITIONS[current_phase] or constants.PHASES.PLAYER_INPUT
end

--- Advance to the next phase and update world state
--- @param world table World state to modify
--- @return string new_phase
function Phase.advance(world)
    local current = world.phase
    local next_phase = Phase.get_next_phase(current)
    
    -- END_TURN -> PLAYER_INPUT also increments turn
    if current == constants.PHASES.END_TURN then
        world.turn = (world.turn or 0) + 1
    end
    
    world.phase = next_phase
    return next_phase
end

--- Force transition to a specific phase (for testing/special events)
--- @param world table World state
--- @param target_phase string Phase to transition to
function Phase.force_transition(world, target_phase)
    world.phase = target_phase
end

--- Enter DEAL_CHOICE phase (interrupts normal flow)
--- @param world table World state
--- @param offer table The deal offer to present
function Phase.enter_deal_choice(world, offer)
    world.phase = constants.PHASES.DEAL_CHOICE
    world.deal_state = world.deal_state or {}
    world.deal_state.pending_offer = offer
end

--- Resolve DEAL_CHOICE and return to PLAYER_INPUT
--- @param world table World state
--- @param accepted boolean Whether the deal was accepted
--- @return table offer The resolved offer
function Phase.resolve_deal_choice(world, accepted)
    local offer = world.deal_state and world.deal_state.pending_offer
    
    if world.deal_state then
        world.deal_state.pending_offer = nil
        
        -- Track deal history
        world.deal_state.offers = world.deal_state.offers or {}
        world.deal_state.chosen = world.deal_state.chosen or {}
        
        if offer then
            if accepted then
                table.insert(world.deal_state.chosen, offer)
            else
                table.insert(world.deal_state.offers, offer)
            end
        end
    end
    
    world.phase = constants.PHASES.PLAYER_INPUT
    return offer
end

--------------------------------------------------------------------------------
-- Enemy Ordering
--------------------------------------------------------------------------------

--- Sort entities for action order: speed DESC, then id ASC
--- @param entities table List of entities
--- @return table sorted_entities
function Phase.sort_enemies_for_action(entities)
    local result = {}
    for _, entity in ipairs(entities) do
        table.insert(result, entity)
    end
    
    table.sort(result, function(a, b)
        -- Sort by speed descending
        local speed_a = a.speed or 0
        local speed_b = b.speed or 0
        if speed_a ~= speed_b then
            return speed_a > speed_b
        end
        -- Tie-break by id ascending (lexicographic)
        return (a.id or "") < (b.id or "")
    end)
    
    return result
end

--- Get ordered list of enemies from world for their action phase
--- @param world table World state
--- @return table ordered_enemies
function Phase.get_enemy_action_order(world)
    local enemies = {}
    
    if world.entities and world.entities.by_id and world.entities.order then
        for _, id in ipairs(world.entities.order) do
            local entity = world.entities.by_id[id]
            if entity and entity.kind ~= "player" and id ~= world.player_id then
                table.insert(enemies, entity)
            end
        end
    end
    
    return Phase.sort_enemies_for_action(enemies)
end

--------------------------------------------------------------------------------
-- Module Export
--------------------------------------------------------------------------------

return Phase
