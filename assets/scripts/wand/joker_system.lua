-- Joker System (Passive Artifacts)
-- Manages "Jokers" which are passive, global modifiers that react to game events.
-- Inspired by Balatro's Joker system.

local JokerSystem = {}

-- Active Jokers list
JokerSystem.jokers = {}

-- Joker Definitions (Registry)
-- In a real implementation, this might be loaded from a data file.
-- Joker Definitions (Registry)
-- Loaded from data/jokers.lua
JokerSystem.definitions = require("data.jokers")

--- Add a Joker to the player's inventory
-- @param joker_id: String ID of the joker
function JokerSystem.add_joker(joker_id)
    local def = JokerSystem.definitions[joker_id]
    if not def then
        print("Error: Unknown Joker ID: " .. tostring(joker_id))
        return
    end

    -- Create instance (deep copy if needed, shallow for now)
    local instance = {
        id = def.id,
        name = def.name,
        calculate = def.calculate,
        -- Add instance-specific data here (e.g. counters)
    }

    table.insert(JokerSystem.jokers, instance)
    print("Added Joker: " .. def.name)
end

--- Clear all Jokers (for testing/reset)
function JokerSystem.clear_jokers()
    JokerSystem.jokers = {}
end

--- Trigger an event and collect effects from all Jokers
-- @param event_name: String name of the event (e.g., "on_spell_cast")
-- @param context: Table containing event data (spell_type, tags, player, etc.)
-- @return table: Aggregated effects { damage_mod = 0, damage_mult = 1, ... }
function JokerSystem.trigger_event(event_name, context)
    context = context or {}
    context.event = event_name

    local aggregate = {
        damage_mod = 0,
        damage_mult = 1,
        repeat_cast = 0,
        messages = {}
    }

    for _, joker in ipairs(JokerSystem.jokers) do
        if joker.calculate then
            local result = joker:calculate(context)
            if result then
                -- Aggregate numerical effects
                if result.damage_mod then aggregate.damage_mod = aggregate.damage_mod + result.damage_mod end
                if result.damage_mult then aggregate.damage_mult = aggregate.damage_mult * result.damage_mult end
                if result.repeat_cast then aggregate.repeat_cast = aggregate.repeat_cast + result.repeat_cast end

                -- Collect UI messages
                if result.message then
                    table.insert(aggregate.messages, { joker = joker.name, text = result.message })
                end
            end
        end
    end

    return aggregate
end

return JokerSystem
