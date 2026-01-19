--[[
================================================================================
SKILLS - Minimal Skill Layer for Demo
================================================================================
A simplified skill system that adds build variety without a complex tree.
Skills are organized by element and provide passive stat bonuses.

Design decisions:
- 8-10 skills total (2 per element: fire, ice, lightning, void)
- Skills apply stat_buff effects like classes/gods
- No prerequisites or tree structure for demo
- Skills are learned via level-up or shop (handled by acquisition layer)
================================================================================
]]

-- Helper to get localized text with fallback
local function L(key, fallback)
    if localization and localization.get then
        local result = localization.get(key)
        if result and result ~= key then return result end
    end
    return fallback
end

local Skills = {

    --------------------------------------------------------------------------------
    -- FIRE SKILLS (2)
    --------------------------------------------------------------------------------

    flame_affinity = {
        id = "flame_affinity",
        name = "Flame Affinity",
        description = "Your fire burns hotter. +15% fire damage.",
        element = "fire",
        icon = "skill_flame_affinity",
        effects = {
            {
                type = "stat_buff",
                stat = "fire_modifier_pct",
                value = 15
            }
        }
    },

    pyromaniac = {
        id = "pyromaniac",
        name = "Pyromaniac",
        description = "Burn effects last longer and deal more damage. +20% burn damage, +2s burn duration.",
        element = "fire",
        icon = "skill_pyromaniac",
        effects = {
            {
                type = "stat_buff",
                stat = "burn_damage_pct",
                value = 20
            },
            {
                type = "stat_buff",
                stat = "burn_duration_bonus",
                value = 2
            }
        }
    },

    --------------------------------------------------------------------------------
    -- ICE SKILLS (2)
    --------------------------------------------------------------------------------

    frost_affinity = {
        id = "frost_affinity",
        name = "Frost Affinity",
        description = "Your ice cuts deeper. +15% ice damage.",
        element = "ice",
        icon = "skill_frost_affinity",
        effects = {
            {
                type = "stat_buff",
                stat = "ice_modifier_pct",
                value = 15
            }
        }
    },

    permafrost = {
        id = "permafrost",
        name = "Permafrost",
        description = "Frozen enemies stay frozen longer. +30% freeze duration, +10% slow effectiveness.",
        element = "ice",
        icon = "skill_permafrost",
        effects = {
            {
                type = "stat_buff",
                stat = "freeze_duration_pct",
                value = 30
            },
            {
                type = "stat_buff",
                stat = "slow_effect_pct",
                value = 10
            }
        }
    },

    --------------------------------------------------------------------------------
    -- LIGHTNING SKILLS (2)
    --------------------------------------------------------------------------------

    storm_affinity = {
        id = "storm_affinity",
        name = "Storm Affinity",
        description = "Lightning strikes true. +15% lightning damage.",
        element = "lightning",
        icon = "skill_storm_affinity",
        effects = {
            {
                type = "stat_buff",
                stat = "lightning_modifier_pct",
                value = 15
            }
        }
    },

    chain_mastery = {
        id = "chain_mastery",
        name = "Chain Mastery",
        description = "Your lightning arcs further. +2 chain targets, +10% chain damage retention.",
        element = "lightning",
        icon = "skill_chain_mastery",
        effects = {
            {
                type = "stat_buff",
                stat = "chain_count_bonus",
                value = 2
            },
            {
                type = "stat_buff",
                stat = "chain_damage_retention_pct",
                value = 10
            }
        }
    },

    --------------------------------------------------------------------------------
    -- VOID SKILLS (2)
    --------------------------------------------------------------------------------

    void_affinity = {
        id = "void_affinity",
        name = "Void Affinity",
        description = "The void empowers you. +15% void damage, +10% summon damage.",
        element = "void",
        icon = "skill_void_affinity",
        effects = {
            {
                type = "stat_buff",
                stat = "void_modifier_pct",
                value = 15
            },
            {
                type = "stat_buff",
                stat = "summon_damage_pct",
                value = 10
            }
        }
    },

    void_conduit = {
        id = "void_conduit",
        name = "Void Conduit",
        description = "Channel the void's energy. +15% mana regeneration, -10% spell cost.",
        element = "void",
        icon = "skill_void_conduit",
        effects = {
            {
                type = "stat_buff",
                stat = "mana_regen_pct",
                value = 15
            },
            {
                type = "stat_buff",
                stat = "spell_cost_reduction_pct",
                value = 10
            }
        }
    },

    --------------------------------------------------------------------------------
    -- UNIVERSAL SKILLS (2)
    --------------------------------------------------------------------------------

    battle_hardened = {
        id = "battle_hardened",
        name = "Battle Hardened",
        description = "You've seen worse. +20 max HP, +5% damage resistance.",
        element = "universal",
        icon = "skill_battle_hardened",
        effects = {
            {
                type = "stat_buff",
                stat = "max_hp",
                value = 20
            },
            {
                type = "stat_buff",
                stat = "damage_resistance_pct",
                value = 5
            }
        }
    },

    swift_casting = {
        id = "swift_casting",
        name = "Swift Casting",
        description = "Cast faster. +10% cast speed, +5% cooldown reduction.",
        element = "universal",
        icon = "skill_swift_casting",
        effects = {
            {
                type = "stat_buff",
                stat = "cast_speed_pct",
                value = 10
            },
            {
                type = "stat_buff",
                stat = "cooldown_reduction_pct",
                value = 5
            }
        }
    },
}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

--- Get localized name for a skill
--- @param skillId string The skill key
--- @return string The localized name or fallback
function Skills.getLocalizedName(skillId)
    local skill = Skills[skillId]
    if not skill then return skillId end
    return L("skill." .. skillId .. ".name", skill.name)
end

--- Get localized description for a skill
--- @param skillId string The skill key
--- @return string The localized description or fallback
function Skills.getLocalizedDescription(skillId)
    local skill = Skills[skillId]
    if not skill then return "" end
    return L("skill." .. skillId .. ".description", skill.description)
end

--- Get all skills of a specific element
--- @param element string The element to filter by ("fire", "ice", "lightning", "void", "universal")
--- @return table Array of {id, def} pairs matching the element
function Skills.getByElement(element)
    local results = {}
    for id, def in pairs(Skills) do
        if type(def) == "table" and def.element == element then
            results[#results + 1] = { id = id, def = def }
        end
    end
    return results
end

--- Get all skills as an array
--- @return table Array of {id, def} pairs
function Skills.getAllSkills()
    local results = {}
    for id, def in pairs(Skills) do
        if type(def) == "table" and def.name then
            results[#results + 1] = { id = id, def = def }
        end
    end
    return results
end

--- Get skill by ID
--- @param skillId string The skill ID
--- @return table|nil The skill definition or nil
function Skills.get(skillId)
    local skill = Skills[skillId]
    if type(skill) == "table" and skill.name then
        return skill
    end
    return nil
end

return Skills
