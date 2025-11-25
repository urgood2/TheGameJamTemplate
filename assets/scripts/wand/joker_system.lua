-- Joker System (Passive Artifacts)
-- Manages "Jokers" which are passive, global modifiers that react to game events.
-- Inspired by Balatro's Joker system.

local JokerSystem = {}

-- Active Jokers list
JokerSystem.jokers = {}

-- Joker Definitions (Registry)
-- In a real implementation, this might be loaded from a data file.
JokerSystem.definitions = {
    -- Example 1: The "Pyromaniac" (Buffs Fire Spells)
    pyromaniac = {
        id = "pyromaniac",
        name = "Pyromaniac",
        description = "+10 Damage to Mono-Element (Fire) Spells.",
        rarity = "Common",
        calculate = function(self, context)
            if context.event == "on_spell_cast" then
                if context.spell_type == "Mono-Element" and context.tags and context.tags.Fire then
                    return {
                        damage_mod = 10,
                        message = "Pyromaniac!"
                    }
                end
            end
        end
    },

    -- Example 2: "Echo Chamber" (Twin Cast Synergy)
    echo_chamber = {
        id = "echo_chamber",
        name = "Echo Chamber",
        description = "Twin Casts trigger twice.",
        rarity = "Rare",
        calculate = function(self, context)
            if context.event == "on_spell_cast" then
                if context.spell_type == "Twin Cast" then
                    return {
                        repeat_cast = 1,
                        message = "Echo!"
                    }
                end
            end
        end
    },

    -- Example 3: "Tag Master" (Scaling)
    tag_master = {
        id = "tag_master",
        name = "Tag Master",
        description = "+1% Damage for every Tag you have.",
        rarity = "Uncommon",
        calculate = function(self, context)
            if context.event == "calculate_damage" then
                local tag_count = 0
                if context.player and context.player.tag_counts then
                    for _, count in pairs(context.player.tag_counts) do
                        tag_count = tag_count + count
                    end
                end
                if tag_count > 0 then
                    return {
                        damage_mult = 1 + (tag_count * 0.01),
                        message = "Tag Master (" .. tag_count .. "%)"
                    }
                end
            end
        end
    }
}

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
