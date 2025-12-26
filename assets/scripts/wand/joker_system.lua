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
--- Jokers can return ANY field - no need to register fields here.
--- Aggregation mode is determined by JOKER_EFFECT_SCHEMA in wand_modifiers.lua
--- @param event_name string Name of the event (e.g., "on_spell_cast", "on_player_damaged")
--- @param context table Event data (spell_type, tags, player, etc.)
--- @return table Aggregated effects from all jokers
function JokerSystem.trigger_event(event_name, context)
    context = context or {}
    context.event = event_name

    local aggregate = { messages = {} }

    -- Load schema for determining aggregation mode
    local WandModifiers = require("wand.wand_modifiers")
    local schema = WandModifiers.JOKER_EFFECT_SCHEMA

    for _, joker in ipairs(JokerSystem.jokers) do
        if joker.calculate then
            local result = joker:calculate(context)
            if result then
                -- Auto-aggregate all fields from joker result
                for field, value in pairs(result) do
                    if field == "message" then
                        -- Collect UI messages
                        table.insert(aggregate.messages, { joker = joker.name, text = value })
                    elseif type(value) == "number" then
                        -- Determine aggregation mode from schema
                        local fieldSchema = schema[field]
                        local mode = fieldSchema and fieldSchema.mode or "add"

                        if mode == "multiply" then
                            aggregate[field] = (aggregate[field] or 1) * value
                        elseif mode == "max" then
                            aggregate[field] = math.max(aggregate[field] or 0, value)
                        elseif mode == "min" then
                            aggregate[field] = math.min(aggregate[field] or value, value)
                        else -- "add" is the default
                            aggregate[field] = (aggregate[field] or 0) + value
                        end
                    elseif type(value) == "table" then
                        -- Tables (like buff definitions) are collected into arrays
                        aggregate[field] = aggregate[field] or {}
                        table.insert(aggregate[field], value)
                    elseif type(value) == "boolean" and value then
                        -- Booleans OR together (any true = true)
                        aggregate[field] = true
                    end
                end
            end
        end
    end

    return aggregate
end

return JokerSystem
