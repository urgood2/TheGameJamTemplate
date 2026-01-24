--[[
================================================================================
SKILLS - Full Skill System for Demo (32 Skills)
================================================================================
Skills organized by element with skill point costs for the skills panel.
Each element has 8 skills at varying costs (1-5 points).

Design decisions:
- 32 skills total (8 per element: fire, ice, lightning, void)
- Skills apply stat_buff effects like classes/gods
- Skills have costs (1-5 skill points) for the skills panel
- Sorted by cost for UI display
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
    -- FIRE SKILLS (8)
    --------------------------------------------------------------------------------

    -- Cost 1 skills (basic)
    kindle = {
        id = "kindle",
        name = "Kindle",
        description = "Your fire sparks to life faster. +10% fire damage, +5% cast speed for fire spells.",
        element = "fire",
        icon = "skill_kindle",
        cost = 1,
        effects = {
            { type = "stat_buff", stat = "fire_modifier_pct", value = 10 },
            { type = "stat_buff", stat = "fire_cast_speed_pct", value = 5 },
        }
    },

    pyrokinesis = {
        id = "pyrokinesis",
        name = "Pyrokinesis",
        description = "Control flames with your mind. +15% fire damage.",
        element = "fire",
        icon = "skill_pyrokinesis",
        cost = 1,
        effects = {
            { type = "stat_buff", stat = "fire_modifier_pct", value = 15 },
        }
    },

    -- Cost 2 skills (intermediate)
    fire_healing = {
        id = "fire_healing",
        name = "Fire Healing",
        description = "Flames cauterize your wounds. Heal 2 HP when dealing fire damage.",
        element = "fire",
        icon = "skill_fire_healing",
        cost = 2,
        effects = {
            { type = "on_fire_damage", effect = "heal_self", value = 2 },
        }
    },

    combustion = {
        id = "combustion",
        name = "Combustion",
        description = "Your fire burns with explosive force. +20% burn damage, burns spread to nearby enemies.",
        element = "fire",
        icon = "skill_combustion",
        cost = 2,
        effects = {
            { type = "stat_buff", stat = "burn_damage_pct", value = 20 },
            { type = "special", effect = "burn_spread" },
        }
    },

    -- Cost 3 skills (advanced)
    flame_familiar = {
        id = "flame_familiar",
        name = "Flame Familiar",
        description = "Summon a small fire spirit that attacks enemies. Deals fire damage over time.",
        element = "fire",
        icon = "skill_flame_familiar",
        cost = 3,
        effects = {
            { type = "summon", summon_id = "flame_familiar" },
        }
    },

    roil = {
        id = "roil",
        name = "Roil",
        description = "Fire churns within you. +25% fire damage when below 50% HP.",
        element = "fire",
        icon = "skill_roil",
        cost = 3,
        effects = {
            { type = "conditional_buff", condition = "hp_below_50", stat = "fire_modifier_pct", value = 25 },
        }
    },

    -- Cost 4 skills (expert)
    scorch_master = {
        id = "scorch_master",
        name = "Scorch Master",
        description = "Master of burning. +30% burn damage, +3s burn duration, burns ignore 20% resistance.",
        element = "fire",
        icon = "skill_scorch_master",
        cost = 4,
        effects = {
            { type = "stat_buff", stat = "burn_damage_pct", value = 30 },
            { type = "stat_buff", stat = "burn_duration_bonus", value = 3 },
            { type = "stat_buff", stat = "burn_penetration_pct", value = 20 },
        }
    },

    -- Cost 5 skills (ultimate)
    fire_form = {
        id = "fire_form",
        name = "Fire Form",
        description = "Become living flame. +50% fire damage, immune to burn, enemies touching you take fire damage.",
        element = "fire",
        icon = "skill_fire_form",
        cost = 5,
        effects = {
            { type = "stat_buff", stat = "fire_modifier_pct", value = 50 },
            { type = "immunity", damage_type = "burn" },
            { type = "aura", damage_type = "fire", value = 5 },
        }
    },

    --------------------------------------------------------------------------------
    -- ICE SKILLS (8)
    --------------------------------------------------------------------------------

    -- Cost 1 skills (basic)
    frostbite = {
        id = "frostbite",
        name = "Frostbite",
        description = "Your ice cuts to the bone. +10% ice damage, +5% slow effectiveness.",
        element = "ice",
        icon = "skill_frostbite",
        cost = 1,
        effects = {
            { type = "stat_buff", stat = "ice_modifier_pct", value = 10 },
            { type = "stat_buff", stat = "slow_effect_pct", value = 5 },
        }
    },

    cryokinesis = {
        id = "cryokinesis",
        name = "Cryokinesis",
        description = "Control ice with your mind. +15% ice damage.",
        element = "ice",
        icon = "skill_cryokinesis",
        cost = 1,
        effects = {
            { type = "stat_buff", stat = "ice_modifier_pct", value = 15 },
        }
    },

    -- Cost 2 skills (intermediate)
    ice_armor = {
        id = "ice_armor",
        name = "Ice Armor",
        description = "Encase yourself in protective ice. +15% damage resistance, attackers are slowed.",
        element = "ice",
        icon = "skill_ice_armor",
        cost = 2,
        effects = {
            { type = "stat_buff", stat = "damage_resistance_pct", value = 15 },
            { type = "on_hit_taken", effect = "slow_attacker", value = 30 },
        }
    },

    shatter_synergy = {
        id = "shatter_synergy",
        name = "Shatter Synergy",
        description = "Frozen enemies take +25% damage from all sources. Shattering deals bonus damage.",
        element = "ice",
        icon = "skill_shatter_synergy",
        cost = 2,
        effects = {
            { type = "debuff_amplify", condition = "frozen", damage_amp_pct = 25 },
            { type = "stat_buff", stat = "shatter_damage_pct", value = 30 },
        }
    },

    -- Cost 3 skills (advanced)
    frost_familiar = {
        id = "frost_familiar",
        name = "Frost Familiar",
        description = "Summon a frost spirit that slows and damages enemies.",
        element = "ice",
        icon = "skill_frost_familiar",
        cost = 3,
        effects = {
            { type = "summon", summon_id = "frost_familiar" },
        }
    },

    frost_turret = {
        id = "frost_turret",
        name = "Frost Turret",
        description = "Deploy a stationary ice turret that fires at enemies. Turret freezes on critical hits.",
        element = "ice",
        icon = "skill_frost_turret",
        cost = 3,
        effects = {
            { type = "deployable", deployable_id = "frost_turret" },
        }
    },

    -- Cost 4 skills (expert)
    freeze_master = {
        id = "freeze_master",
        name = "Freeze Master",
        description = "Master of freezing. +30% freeze duration, +20% chance to freeze, frozen enemies take +20% ice damage.",
        element = "ice",
        icon = "skill_freeze_master",
        cost = 4,
        effects = {
            { type = "stat_buff", stat = "freeze_duration_pct", value = 30 },
            { type = "stat_buff", stat = "freeze_chance_pct", value = 20 },
            { type = "conditional_damage", condition = "target_frozen", stat = "ice_modifier_pct", value = 20 },
        }
    },

    -- Cost 5 skills (ultimate)
    ice_form = {
        id = "ice_form",
        name = "Ice Form",
        description = "Become living ice. +50% ice damage, immune to freeze/slow, leave a trail that freezes enemies.",
        element = "ice",
        icon = "skill_ice_form",
        cost = 5,
        effects = {
            { type = "stat_buff", stat = "ice_modifier_pct", value = 50 },
            { type = "immunity", damage_type = "freeze" },
            { type = "immunity", damage_type = "slow" },
            { type = "trail", effect = "freeze_trail" },
        }
    },

    --------------------------------------------------------------------------------
    -- LIGHTNING SKILLS (8)
    --------------------------------------------------------------------------------

    -- Cost 1 skills (basic)
    spark = {
        id = "spark",
        name = "Spark",
        description = "Quick jolts of electricity. +10% lightning damage, +5% attack speed.",
        element = "lightning",
        icon = "skill_spark",
        cost = 1,
        effects = {
            { type = "stat_buff", stat = "lightning_modifier_pct", value = 10 },
            { type = "stat_buff", stat = "attack_speed_pct", value = 5 },
        }
    },

    electrokinesis = {
        id = "electrokinesis",
        name = "Electrokinesis",
        description = "Control lightning with your mind. +15% lightning damage.",
        element = "lightning",
        icon = "skill_electrokinesis",
        cost = 1,
        effects = {
            { type = "stat_buff", stat = "lightning_modifier_pct", value = 15 },
        }
    },

    -- Cost 2 skills (intermediate)
    chain_lightning = {
        id = "chain_lightning",
        name = "Chain Lightning",
        description = "Lightning arcs between enemies. +2 chain targets, +10% chain damage retention.",
        element = "lightning",
        icon = "skill_chain_lightning",
        cost = 2,
        effects = {
            { type = "stat_buff", stat = "chain_count_bonus", value = 2 },
            { type = "stat_buff", stat = "chain_damage_retention_pct", value = 10 },
        }
    },

    surge = {
        id = "surge",
        name = "Surge",
        description = "Burst of electrical power. +20% lightning damage for 3s after casting a lightning spell.",
        element = "lightning",
        icon = "skill_surge",
        cost = 2,
        effects = {
            { type = "on_cast_buff", spell_type = "lightning", stat = "lightning_modifier_pct", value = 20, duration = 3 },
        }
    },

    -- Cost 3 skills (advanced)
    storm_familiar = {
        id = "storm_familiar",
        name = "Storm Familiar",
        description = "Summon a lightning spirit that zaps enemies with chain lightning.",
        element = "lightning",
        icon = "skill_storm_familiar",
        cost = 3,
        effects = {
            { type = "summon", summon_id = "storm_familiar" },
        }
    },

    amplify_pain = {
        id = "amplify_pain",
        name = "Amplify Pain",
        description = "Shocked enemies take +20% damage from all sources. Shock duration +2s.",
        element = "lightning",
        icon = "skill_amplify_pain",
        cost = 3,
        effects = {
            { type = "debuff_amplify", condition = "shocked", damage_amp_pct = 20 },
            { type = "stat_buff", stat = "shock_duration_bonus", value = 2 },
        }
    },

    -- Cost 4 skills (expert)
    charge_master = {
        id = "charge_master",
        name = "Charge Master",
        description = "Master of electrical charge. +30% shock damage, +25% shock chance, shocked enemies chain to 2 extra targets.",
        element = "lightning",
        icon = "skill_charge_master",
        cost = 4,
        effects = {
            { type = "stat_buff", stat = "shock_damage_pct", value = 30 },
            { type = "stat_buff", stat = "shock_chance_pct", value = 25 },
            { type = "stat_buff", stat = "shock_chain_bonus", value = 2 },
        }
    },

    -- Cost 5 skills (ultimate)
    storm_form = {
        id = "storm_form",
        name = "Storm Form",
        description = "Become living lightning. +50% lightning damage, immune to shock, teleport short distances instead of walking.",
        element = "lightning",
        icon = "skill_storm_form",
        cost = 5,
        effects = {
            { type = "stat_buff", stat = "lightning_modifier_pct", value = 50 },
            { type = "immunity", damage_type = "shock" },
            { type = "movement", effect = "lightning_dash" },
        }
    },

    --------------------------------------------------------------------------------
    -- VOID SKILLS (8)
    --------------------------------------------------------------------------------

    -- Cost 1 skills (basic)
    entropy = {
        id = "entropy",
        name = "Entropy",
        description = "Embrace decay. +10% void damage, +5% damage to enemies below 50% HP.",
        element = "void",
        icon = "skill_entropy",
        cost = 1,
        effects = {
            { type = "stat_buff", stat = "void_modifier_pct", value = 10 },
            { type = "execute_damage", threshold_pct = 50, bonus_pct = 5 },
        }
    },

    necrokinesis = {
        id = "necrokinesis",
        name = "Necrokinesis",
        description = "Control death energy with your mind. +15% void damage.",
        element = "void",
        icon = "skill_necrokinesis",
        cost = 1,
        effects = {
            { type = "stat_buff", stat = "void_modifier_pct", value = 15 },
        }
    },

    -- Cost 2 skills (intermediate)
    cursed_flesh = {
        id = "cursed_flesh",
        name = "Cursed Flesh",
        description = "Your body is touched by the void. +20 max HP, heal for 10% of void damage dealt.",
        element = "void",
        icon = "skill_cursed_flesh",
        cost = 2,
        effects = {
            { type = "stat_buff", stat = "max_hp", value = 20 },
            { type = "lifesteal", damage_type = "void", percent = 10 },
        }
    },

    grave_summon = {
        id = "grave_summon",
        name = "Grave Summon",
        description = "Enemies you kill have a 20% chance to rise as temporary void minions.",
        element = "void",
        icon = "skill_grave_summon",
        cost = 2,
        effects = {
            { type = "on_kill", effect = "summon_minion", chance_pct = 20, minion_id = "void_minion" },
        }
    },

    -- Cost 3 skills (advanced)
    doom_mark = {
        id = "doom_mark",
        name = "Doom Mark",
        description = "Mark enemies for death. Marked enemies take +25% damage and explode on death.",
        element = "void",
        icon = "skill_doom_mark",
        cost = 3,
        effects = {
            { type = "mark", mark_id = "doom", damage_amp_pct = 25 },
            { type = "on_marked_death", effect = "explode", damage_pct = 50 },
        }
    },

    anchor_of_doom = {
        id = "anchor_of_doom",
        name = "Anchor of Doom",
        description = "Deploy a void anchor that pulls enemies toward it and deals void damage.",
        element = "void",
        icon = "skill_anchor_of_doom",
        cost = 3,
        effects = {
            { type = "deployable", deployable_id = "doom_anchor" },
        }
    },

    -- Cost 4 skills (expert)
    doom_master = {
        id = "doom_master",
        name = "Doom Master",
        description = "Master of doom. +30% void damage, doom marks spread on kill, +50% doom explosion damage.",
        element = "void",
        icon = "skill_doom_master",
        cost = 4,
        effects = {
            { type = "stat_buff", stat = "void_modifier_pct", value = 30 },
            { type = "on_marked_kill", effect = "spread_mark" },
            { type = "stat_buff", stat = "doom_explosion_pct", value = 50 },
        }
    },

    -- Cost 5 skills (ultimate)
    void_form = {
        id = "void_form",
        name = "Void Form",
        description = "Become living void. +50% void damage, phase through enemies, enemies near you lose 5% HP per second.",
        element = "void",
        icon = "skill_void_form",
        cost = 5,
        effects = {
            { type = "stat_buff", stat = "void_modifier_pct", value = 50 },
            { type = "movement", effect = "phase_through" },
            { type = "aura", effect = "hp_drain", percent_per_sec = 5 },
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
--- @param element string The element to filter by ("fire", "ice", "lightning", "void")
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

--- Get skills of an element, sorted by cost (then name for deterministic ordering)
--- @param element string The element to filter by
--- @return table Array of {id, def} pairs sorted by cost, then name
function Skills.getOrderedByElement(element)
    local results = Skills.getByElement(element)
    table.sort(results, function(a, b)
        if a.def.cost ~= b.def.cost then
            return a.def.cost < b.def.cost
        end
        return a.def.name < b.def.name
    end)
    return results
end

--- Get all skills in deterministic order (by element, then cost, then name)
--- @return table Array of {id, def} pairs in deterministic order
function Skills.getAllOrdered()
    local results = {}
    local elements = { "fire", "ice", "lightning", "void" }

    for _, element in ipairs(elements) do
        local elementSkills = Skills.getOrderedByElement(element)
        for _, entry in ipairs(elementSkills) do
            results[#results + 1] = entry
        end
    end

    return results
end

return Skills
