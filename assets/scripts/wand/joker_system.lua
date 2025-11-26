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
    },

    -- Example 4: "Elemental Master" (Scaling with Elemental Tags)
    elemental_master = {
        id = "elemental_master",
        name = "Elemental Master",
        description = "+5% Damage for every Elemental Tag (Fire, Ice, Lightning).",
        rarity = "Rare",
        calculate = function(self, context)
            if context.event == "calculate_damage" then
                local elem_tags = 0
                if context.player and context.player.tag_counts then
                    elem_tags = (context.player.tag_counts["Fire"] or 0) +
                        (context.player.tag_counts["Ice"] or 0) +
                        (context.player.tag_counts["Lightning"] or 0)
                end

                if elem_tags > 0 then
                    return {
                        damage_mult = 1 + (elem_tags * 0.05),
                        message = "Elem Master (" .. (elem_tags * 5) .. "%)"
                    }
                end
            end
        end
    },

    -- Example 5: "Synergy Seeker" (Reward for Sets)
    synergy_seeker = {
        id = "synergy_seeker",
        name = "Synergy Seeker",
        description = "Gain +10 Mana when a Set Bonus is active.",
        rarity = "Uncommon",
        calculate = function(self, context)
            -- This would need a hook into "on_set_bonus_active" or similar
            -- For now, we can check during cast if any set bonus is active
            if context.event == "on_spell_cast" then
                -- Mock check for active set bonuses
                -- In real implementation, check context.player.active_tag_bonuses
                return {
                    mana_restore = 10,
                    message = "Synergy!"
                }
            end
        end
    },

    -- NEW: Tag Density Jokers

    -- Reacts to tag-heavy casts (3+ of same tag)
    tag_specialist = {
        id = "tag_specialist",
        name = "Tag Specialist",
        description = "+30% damage if 3+ actions share the same tag",
        rarity = "Uncommon",
        calculate = function(self, context)
            if context.event == "on_spell_cast" then
                if context.tag_analysis and context.tag_analysis.is_tag_heavy then
                    return {
                        damage_mult = 1.3,
                        message = string.format("Tag Focus! (%s x%d)",
                            context.tag_analysis.primary_tag or "?",
                            context.tag_analysis.primary_count or 0)
                    }
                end
            end
        end
    },

    -- Reacts to diverse casts (3+ different tags)
    rainbow_mage = {
        id = "rainbow_mage",
        name = "Rainbow Mage",
        description = "+10% damage per distinct tag type in cast",
        rarity = "Rare",
        calculate = function(self, context)
            if context.event == "on_spell_cast" then
                if context.tag_analysis and context.tag_analysis.diversity > 0 then
                    local bonus = context.tag_analysis.diversity * 10
                    return {
                        damage_mult = 1 + (bonus / 100),
                        message = string.format("Rainbow! +%d%%", bonus)
                    }
                end
            end
        end
    },

    -- Reacts to single actions with multiple tags
    combo_catalyst = {
        id = "combo_catalyst",
        name = "Combo Catalyst",
        description = "Single actions with 2+ tags cast twice",
        rarity = "Epic",
        calculate = function(self, context)
            if context.event == "on_spell_cast" then
                if context.tag_analysis and context.tag_analysis.is_multi_tag then
                    return {
                        repeat_cast = 1,
                        message = "Multi-Tag Combo!"
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
