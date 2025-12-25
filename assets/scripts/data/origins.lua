-- Helper to get localized text with fallback
local function L(key, fallback)
    if localization and localization.get then
        local result = localization.get(key)
        if result and result ~= key then return result end
    end
    return fallback
end

local Origins = {
    ember_nomad = {
        name = "Ember Nomad",
        description = "A wanderer from the scorched wastes.",
        tags = { "Fire", "Hazard" },

        -- Passive stats applied to the player
        passive_stats = {
            fire_modifier_pct = 10,
            hazard_duration_pct = 15
        },

        -- Active ability (Prayer)
        prayer = "ember_psalm",

        -- Shop RNG Bias: Multiplies weight of cards with these tags
        -- 1.0 = normal, 1.3 = 30% more likely to appear
        tag_weights = {
            Fire = 1.3,
            Hazard = 1.2
        }
    },

    tundra_sentinel = {
        name = "Tundra Sentinel",
        description = "Guardian of the eternal ice.",
        tags = { "Ice", "Defense" },

        passive_stats = {
            ice_modifier_pct = 10,
            block_chance_pct = 5
        },

        prayer = "glacier_litany",

        tag_weights = {
            Ice = 1.3,
            Defense = 1.2
        }
    },

    plague_scribe = {
        name = "Plague Scribe",
        description = "Scholar of forbidden decay.",
        tags = { "Poison", "Arcane" },

        passive_stats = {
            poison_duration_pct = 15,
            max_poison_stacks = 10
        },

        prayer = "contagion",

        tag_weights = {
            Poison = 1.3,
            Arcane = 1.2
        }
    },

    void_cultist = {
        name = "Void Cultist",
        description = "Worshipper of the empty dark.",
        tags = { "Arcane", "Summon" },

        passive_stats = {
            arcane_modifier_pct = 10,
            summon_hp_pct = 15
        },

        prayer = "void_rift",

        tag_weights = {
            Arcane = 1.3,
            Summon = 1.2
        }
    },

    storm_caller = {
        name = "Storm Caller",
        description = "Born in the heart of the tempest.",
        tags = { "Lightning", "Arcane" },

        passive_stats = {
            lightning_modifier_pct = 15,
            chain_count_bonus = 1,
            electrocute_duration_pct = 20,
        },

        prayer = "thunderclap",

        tag_weights = {
            Lightning = 1.5,
            Arcane = 1.2,
        },

        starting_cards = {
            "ACTION_CHAIN_LIGHTNING",
            "ACTION_STATIC_CHARGE",
        },
    },
}

--- Get localized name for an origin (call at runtime when localization is ready)
--- @param originId string The origin key (e.g., "ember_nomad")
--- @return string The localized name or fallback English name
function Origins.getLocalizedName(originId)
    local origin = Origins[originId]
    if not origin then return originId end
    return L("origin." .. originId .. ".name", origin.name)
end

--- Get localized description for an origin (call at runtime when localization is ready)
--- @param originId string The origin key (e.g., "ember_nomad")
--- @return string The localized description or fallback English description
function Origins.getLocalizedDescription(originId)
    local origin = Origins[originId]
    if not origin then return "" end
    return L("origin." .. originId .. ".description", origin.description)
end

return Origins
