-- assets/scripts/bargain/sim/step.lua
--[[
================================================================================
BARGAIN SIM: Core step() API
================================================================================

The step function is the heart of the Bargain simulation. It takes the current
world state and a player input, then returns the new world state after that
action is processed.

DETERMINISM GUARANTEE:
Given the same (world, input) pair, step() MUST always produce the same output.
This is critical for replays and CI verification.

INPUT TYPES:
- move:        {type="move", dir="n"|"s"|"e"|"w"|"ne"|"nw"|"se"|"sw"}
- attack:      {type="attack", target_id=number}
- wait:        {type="wait"}
- deal_choose: {type="deal_choose", deal_index=number, choice="accept"|"decline"}
- deal_skip:   {type="deal_skip"}

RETURN SHAPE:
{
    ok = boolean,          -- true if input was valid and processed
    events = {...},        -- events generated this step
    world = world,         -- updated world state (or unchanged if ok=false)
    error = string|nil     -- error message if ok=false
}
]]

local Step = {}

--------------------------------------------------------------------------------
-- Input Validation
--------------------------------------------------------------------------------

--- Valid input types
local VALID_INPUT_TYPES = {
    move = true,
    attack = true,
    wait = true,
    deal_choose = true,
    deal_skip = true,
}

--- Valid move directions
local VALID_DIRECTIONS = {
    n = true, s = true, e = true, w = true,
    ne = true, nw = true, se = true, sw = true,
}

--- Validate an input object
--- @param input table The input to validate
--- @return boolean ok, string|nil error_message
local function validate_input(input)
    if type(input) ~= "table" then
        return false, "Input must be a table"
    end
    
    local input_type = input.type
    if not input_type then
        return false, "Input missing 'type' field"
    end
    
    if not VALID_INPUT_TYPES[input_type] then
        return false, string.format("Unknown input type: '%s'", tostring(input_type))
    end
    
    -- Type-specific validation
    if input_type == "move" then
        if not input.dir then
            return false, "Move input missing 'dir' field"
        end
        if not VALID_DIRECTIONS[input.dir] then
            return false, string.format("Invalid move direction: '%s'", tostring(input.dir))
        end
    elseif input_type == "attack" then
        if type(input.target_id) ~= "number" then
            return false, "Attack input missing or invalid 'target_id'"
        end
    elseif input_type == "deal_choose" then
        if type(input.deal_index) ~= "number" then
            return false, "Deal choose input missing or invalid 'deal_index'"
        end
        if input.choice ~= "accept" and input.choice ~= "decline" then
            return false, "Deal choose input missing or invalid 'choice'"
        end
    end
    -- wait and deal_skip require no additional fields
    
    return true, nil
end

--------------------------------------------------------------------------------
-- World Validation
--------------------------------------------------------------------------------

--- Validate that a world object has minimum required fields
--- @param world table The world state to validate
--- @return boolean ok, string|nil error_message
local function validate_world(world)
    if type(world) ~= "table" then
        return false, "World must be a table"
    end
    
    -- TODO: Add more validation as World schema is defined in M0-C2
    -- For now, just check it's a table
    
    return true, nil
end

--------------------------------------------------------------------------------
-- Input Processors (Stubs)
--------------------------------------------------------------------------------

--- Process a move input
--- @param world table Current world state
--- @param input table Move input {type="move", dir=string}
--- @return table result {ok, events, world, error}
local function process_move(world, input)
    -- TODO: Implement in M1-P1
    return {
        ok = true,
        events = {{type = "player_moved", dir = input.dir}},
        world = world,
    }
end

--- Process an attack input
--- @param world table Current world state
--- @param input table Attack input {type="attack", target_id=number}
--- @return table result {ok, events, world, error}
local function process_attack(world, input)
    -- TODO: Implement in M1-P2
    return {
        ok = true,
        events = {{type = "player_attacked", target_id = input.target_id}},
        world = world,
    }
end

--- Process a wait input
--- @param world table Current world state
--- @param input table Wait input {type="wait"}
--- @return table result {ok, events, world, error}
local function process_wait(world, input)
    -- TODO: Implement in M1-P3
    return {
        ok = true,
        events = {{type = "player_waited"}},
        world = world,
    }
end

--- Process a deal choice input
--- @param world table Current world state
--- @param input table Deal input {type="deal_choose", deal_index=number, choice=string}
--- @return table result {ok, events, world, error}
local function process_deal_choose(world, input)
    -- TODO: Implement in M3
    return {
        ok = true,
        events = {{type = "deal_chosen", deal_index = input.deal_index, choice = input.choice}},
        world = world,
    }
end

--- Process a deal skip input
--- @param world table Current world state
--- @param input table Skip input {type="deal_skip"}
--- @return table result {ok, events, world, error}
local function process_deal_skip(world, input)
    -- TODO: Implement in M3
    return {
        ok = true,
        events = {{type = "deal_skipped"}},
        world = world,
    }
end

--- Dispatch table for input processors
local INPUT_PROCESSORS = {
    move = process_move,
    attack = process_attack,
    wait = process_wait,
    deal_choose = process_deal_choose,
    deal_skip = process_deal_skip,
}

--------------------------------------------------------------------------------
-- Core step() API
--------------------------------------------------------------------------------

--- Execute one simulation step
--- @param world table The current world state
--- @param input table The player input
--- @return table result {ok=boolean, events=table, world=table, error=string|nil}
function Step.step(world, input)
    -- Validate world
    local world_ok, world_err = validate_world(world)
    if not world_ok then
        return {
            ok = false,
            events = {},
            world = world,
            error = "Invalid world: " .. (world_err or "unknown error"),
        }
    end
    
    -- Validate input
    local input_ok, input_err = validate_input(input)
    if not input_ok then
        return {
            ok = false,
            events = {},
            world = world,
            error = "Invalid input: " .. (input_err or "unknown error"),
        }
    end
    
    -- Dispatch to appropriate processor
    local processor = INPUT_PROCESSORS[input.type]
    if not processor then
        return {
            ok = false,
            events = {},
            world = world,
            error = "No processor for input type: " .. input.type,
        }
    end
    
    -- Execute processor (catch any errors)
    local ok, result = pcall(function()
        return processor(world, input)
    end)
    
    if not ok then
        -- processor threw an error
        return {
            ok = false,
            events = {},
            world = world,
            error = "Processor error: " .. tostring(result),
        }
    end
    
    -- Ensure result has required fields
    result.ok = result.ok ~= false
    result.events = result.events or {}
    result.world = result.world or world
    
    return result
end

--------------------------------------------------------------------------------
-- Module Export
--------------------------------------------------------------------------------

return Step
