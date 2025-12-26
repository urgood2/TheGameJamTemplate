--[[
================================================================================
JOKER DEFINITIONS
================================================================================
Centralized registry for all Joker (Passive Artifact) definitions.
]]

-- Helper to get localized text with fallback
local function L(key, fallback)
    if localization and localization.get then
        local result = localization.get(key)
        if result and result ~= key then return result end
    end
    return fallback
end

local Jokers = {
    
    lightning_rod = {
        id = "lightning_rod",
        name = "Lightning Rod",
        description = "+15 Damage to Lightning spells. Critical hits chain to one extra enemy.",
        rarity = "Uncommon",
        sprite = "test_lightning_artifact.png",  -- Use your new sprite!

        calculate = function(self, context)
            -- React to spell casting
            if context.event == "on_spell_cast" then
                -- Check if the spell has the Lightning tag
                if context.tags and context.tags.Lightning then
                    print("[JOKER] Lightning Rod triggered! +15 damage, +1 chain")
                    return {
                        damage_mod = 15,           -- Flat damage increase
                        extra_chain = 1,           -- +1 chain target
                        message = "Lightning Rod!"
                    }
                end
            end
        end
    },
    
    
    -- Example 1: The "Pyromaniac" (Buffs Fire Spells)
    pyromaniac = {
        id = "pyromaniac",
        name = "Pyromaniac",
        description = "+10 Damage to Mono-Element (Fire) Spells.",
        rarity = "Common",
        -- sprite = "joker_pyromaniac",  -- Optional: custom sprite (default: joker_sample.png)
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
    },

    --===========================================================================
    -- DEFENSIVE JOKERS (React to on_player_damaged)
    --===========================================================================

    iron_skin = {
        id = "iron_skin",
        name = "Iron Skin",
        description = "Reduce projectile damage by 5.",
        rarity = "Common",
        calculate = function(self, context)
            if context.event == "on_player_damaged" and context.source == "enemy_projectile" then
                return {
                    damage_reduction = 5,
                    message = "Iron Skin!"
                }
            end
        end
    },

    flame_ward = {
        id = "flame_ward",
        name = "Flame Ward",
        description = "Immune to Fire damage from projectiles.",
        rarity = "Uncommon",
        calculate = function(self, context)
            if context.event == "on_player_damaged"
               and context.source == "enemy_projectile"
               and context.damage_type == "fire" then
                return {
                    damage_reduction = context.damage,
                    message = "Flame Ward!"
                }
            end
        end
    },

    thorns = {
        id = "thorns",
        name = "Thorns",
        description = "Reflect 50% of projectile damage back to attacker.",
        rarity = "Rare",
        calculate = function(self, context)
            if context.event == "on_player_damaged" and context.source == "enemy_projectile" then
                return {
                    reflect_damage = math.floor(context.damage * 0.5),
                    message = "Thorns!"
                }
            end
        end
    },

    survival_instinct = {
        id = "survival_instinct",
        name = "Survival Instinct",
        description = "+20% damage for 3s after taking projectile damage.",
        rarity = "Uncommon",
        calculate = function(self, context)
            if context.event == "on_player_damaged" and context.source == "enemy_projectile" then
                return {
                    buff = { stat = "damage_mult", value = 1.2, duration = 3.0 },
                    message = "Survival!"
                }
            end
        end
    },
}

-- Apply defaults to all jokers at load time
local ContentDefaults = require("data.content_defaults")

for key, joker in pairs(Jokers) do
    -- Apply joker defaults (non-destructive, fills in missing fields)
    local defaults = ContentDefaults.JOKER_FIELDS
    for field, default_value in pairs(defaults) do
        if joker[field] == nil then
            joker[field] = default_value
        end
    end
end

--- Get localized name for a joker (call at runtime when localization is ready)
--- @param jokerId string The joker key (e.g., "pyromaniac")
--- @return string The localized name or fallback English name
function Jokers.getLocalizedName(jokerId)
    local joker = Jokers[jokerId]
    if not joker then return jokerId end
    return L("joker." .. jokerId .. ".name", joker.name)
end

--- Get localized description for a joker (call at runtime when localization is ready)
--- @param jokerId string The joker key (e.g., "pyromaniac")
--- @return string The localized description or fallback English description
function Jokers.getLocalizedDescription(jokerId)
    local joker = Jokers[jokerId]
    if not joker then return "" end
    return L("joker." .. jokerId .. ".description", joker.description)
end

return Jokers
