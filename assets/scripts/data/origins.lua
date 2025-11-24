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
    }
}

return Origins
