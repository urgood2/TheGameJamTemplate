--[[
================================================================================
SKILLS - Demo Skill Definitions
================================================================================
Skill data for the demo skills panel.
Skills are organized by element and described via triggers and effects.

Design decisions:
- 32 skills total (8 per element: fire, ice, lightning, void)
- Each skill includes cost and trigger metadata for UI
- Effects are descriptive; runtime behavior is implemented elsewhere
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

    kindle = {
        id = "kindle",
        name = "Kindle",
        description = "On hit: apply +2 Scorch.",
        element = "fire",
        icon = "skill_kindle",
        cost = 1,
        order = 1,
        triggers = { "on_hit" },
        effects = {
            { type = "proc", trigger = "on_hit", effect = "+2 Scorch per hit" }
        }
    },

    pyrokinesis = {
        id = "pyrokinesis",
        name = "Pyrokinesis",
        description = "On hit: 30 Fire AoE around the target.",
        element = "fire",
        icon = "skill_pyrokinesis",
        cost = 2,
        order = 2,
        triggers = { "on_hit" },
        effects = {
            { type = "proc", trigger = "on_hit", effect = "30 Fire AoE around target" }
        }
    },

    fire_healing = {
        id = "fire_healing",
        name = "Fire Healing",
        description = "On fire damage: heal 3.",
        element = "fire",
        icon = "skill_fire_healing",
        cost = 2,
        order = 3,
        triggers = { "on_fire_damage" },
        effects = {
            { type = "proc", trigger = "on_fire_damage", effect = "Heal 3" }
        }
    },

    combustion = {
        id = "combustion",
        name = "Combustion",
        description = "On enemy killed: explode for Scorch x10 Fire damage.",
        element = "fire",
        icon = "skill_combustion",
        cost = 3,
        order = 4,
        triggers = { "enemy_killed" },
        effects = {
            { type = "proc", trigger = "enemy_killed", effect = "Explode for Scorch x10 Fire damage" }
        }
    },

    flame_familiar = {
        id = "flame_familiar",
        name = "Flame Familiar",
        description = "On wave start: summon a Fire Sprite.",
        element = "fire",
        icon = "skill_flame_familiar",
        cost = 3,
        order = 5,
        triggers = { "on_wave_start" },
        effects = {
            { type = "proc", trigger = "on_wave_start", effect = "Summon a Fire Sprite" }
        }
    },

    roil = {
        id = "roil",
        name = "Roil",
        description = "On hit + on fire damage: heal 5, gain 2 Inflame, take 15 Fire self-damage.",
        element = "fire",
        icon = "skill_roil",
        cost = 3,
        order = 6,
        triggers = { "on_hit", "on_fire_damage" },
        effects = {
            { type = "proc", trigger = "on_hit + on_fire_damage", effect = "Heal 5, +2 Inflame, 15 Fire self-damage" }
        }
    },

    scorch_master = {
        id = "scorch_master",
        name = "Scorch Master",
        description = "Passive: Immune to Scorch. Scorch never expires.",
        element = "fire",
        icon = "skill_scorch_master",
        cost = 4,
        order = 7,
        triggers = { "passive" },
        effects = {
            { type = "rule_change", desc = "Immune to Scorch. Scorch never expires." }
        }
    },

    fire_form = {
        id = "fire_form",
        name = "Fire Form",
        description = "On threshold (100 Fire damage): gain Fireform.",
        element = "fire",
        icon = "skill_fire_form",
        cost = 5,
        order = 8,
        triggers = { "on_threshold" },
        effects = {
            { type = "proc", trigger = "on_threshold (100 Fire damage)", effect = "Gain Fireform" }
        }
    },

    --------------------------------------------------------------------------------
    -- ICE SKILLS (8)
    --------------------------------------------------------------------------------

    frostbite = {
        id = "frostbite",
        name = "Frostbite",
        description = "On hit: apply +2 Freeze.",
        element = "ice",
        icon = "skill_frostbite",
        cost = 1,
        order = 1,
        triggers = { "on_hit" },
        effects = {
            { type = "proc", trigger = "on_hit", effect = "+2 Freeze per hit" }
        }
    },

    cryokinesis = {
        id = "cryokinesis",
        name = "Cryokinesis",
        description = "On hit: ice to 2 adjacent targets and +3 Freeze.",
        element = "ice",
        icon = "skill_cryokinesis",
        cost = 2,
        order = 2,
        triggers = { "on_hit" },
        effects = {
            { type = "proc", trigger = "on_hit", effect = "Ice to 2 adjacent, +3 Freeze" }
        }
    },

    ice_armor = {
        id = "ice_armor",
        name = "Ice Armor",
        description = "On player hit: +50 Armor and counter-Freeze attackers.",
        element = "ice",
        icon = "skill_ice_armor",
        cost = 2,
        order = 3,
        triggers = { "on_player_hit" },
        effects = {
            { type = "proc", trigger = "on_player_hit", effect = "+50 Armor, counter-Freeze attackers" }
        }
    },

    shatter_synergy = {
        id = "shatter_synergy",
        name = "Shatter Synergy",
        description = "On freeze applied + enemy killed: AoE = Freeze x15.",
        element = "ice",
        icon = "skill_shatter_synergy",
        cost = 3,
        order = 4,
        triggers = { "on_freeze_applied", "enemy_killed" },
        effects = {
            { type = "proc", trigger = "on_freeze_applied + enemy_killed", effect = "AoE = Freeze x15" }
        }
    },

    frost_familiar = {
        id = "frost_familiar",
        name = "Frost Familiar",
        description = "On wave start: summon an Ice Elemental.",
        element = "ice",
        icon = "skill_frost_familiar",
        cost = 3,
        order = 5,
        triggers = { "on_wave_start" },
        effects = {
            { type = "proc", trigger = "on_wave_start", effect = "Summon an Ice Elemental" }
        }
    },

    frost_turret = {
        id = "frost_turret",
        name = "Frost Turret",
        description = "On stand still: summon an ice turret that fires.",
        element = "ice",
        icon = "skill_frost_turret",
        cost = 3,
        order = 6,
        triggers = { "on_stand_still" },
        effects = {
            { type = "proc", trigger = "on_stand_still", effect = "Summon an ice turret" }
        }
    },

    freeze_master = {
        id = "freeze_master",
        name = "Freeze Master",
        description = "Passive: Immune to Freeze. +2 Armor per enemy Freeze.",
        element = "ice",
        icon = "skill_freeze_master",
        cost = 4,
        order = 7,
        triggers = { "passive" },
        effects = {
            { type = "rule_change", desc = "Immune to Freeze. +2 Armor per enemy Freeze." }
        }
    },

    ice_form = {
        id = "ice_form",
        name = "Ice Form",
        description = "On threshold (50 Freeze): gain Iceform.",
        element = "ice",
        icon = "skill_ice_form",
        cost = 5,
        order = 8,
        triggers = { "on_threshold" },
        effects = {
            { type = "proc", trigger = "on_threshold (50 Freeze)", effect = "Gain Iceform" }
        }
    },

    --------------------------------------------------------------------------------
    -- LIGHTNING SKILLS (8)
    --------------------------------------------------------------------------------

    spark = {
        id = "spark",
        name = "Spark",
        description = "On hit: +5% Move Speed.",
        element = "lightning",
        icon = "skill_spark",
        cost = 1,
        order = 1,
        triggers = { "on_hit" },
        effects = {
            { type = "proc", trigger = "on_hit", effect = "+5% Move Speed" }
        }
    },

    electrokinesis = {
        id = "electrokinesis",
        name = "Electrokinesis",
        description = "On hit: lightning line through target.",
        element = "lightning",
        icon = "skill_electrokinesis",
        cost = 2,
        order = 2,
        triggers = { "on_hit" },
        effects = {
            { type = "proc", trigger = "on_hit", effect = "Lightning line through target" }
        }
    },

    chain_lightning = {
        id = "chain_lightning",
        name = "Chain Lightning",
        description = "On enemy killed: lightning chains to 2 enemies.",
        element = "lightning",
        icon = "skill_chain_lightning",
        cost = 2,
        order = 3,
        triggers = { "enemy_killed" },
        effects = {
            { type = "proc", trigger = "enemy_killed", effect = "Lightning chains to 2 enemies" }
        }
    },

    surge = {
        id = "surge",
        name = "Surge",
        description = "On step: deal Move Speed damage.",
        element = "lightning",
        icon = "skill_surge",
        cost = 3,
        order = 4,
        triggers = { "on_step" },
        effects = {
            { type = "proc", trigger = "on_step", effect = "Deal Move Speed damage" }
        }
    },

    storm_familiar = {
        id = "storm_familiar",
        name = "Storm Familiar",
        description = "On wave start: summon Ball Lightning.",
        element = "lightning",
        icon = "skill_storm_familiar",
        cost = 3,
        order = 5,
        triggers = { "on_wave_start" },
        effects = {
            { type = "proc", trigger = "on_wave_start", effect = "Summon Ball Lightning" }
        }
    },

    amplify_pain = {
        id = "amplify_pain",
        name = "Amplify Pain",
        description = "On player hit + on self damage: 5 self-damage -> 20 Lightning AoE.",
        element = "lightning",
        icon = "skill_amplify_pain",
        cost = 3,
        order = 6,
        triggers = { "on_player_hit", "on_self_damage" },
        effects = {
            { type = "proc", trigger = "on_player_hit + on_self_damage", effect = "5 self-damage -> 20 Lightning AoE" }
        }
    },

    charge_master = {
        id = "charge_master",
        name = "Charge Master",
        description = "On crit: +3 Charge. +1% crit per Charge.",
        element = "lightning",
        icon = "skill_charge_master",
        cost = 4,
        order = 7,
        triggers = { "on_crit", "passive" },
        effects = {
            { type = "rule_change", desc = "+1% crit per Charge" },
            { type = "proc", trigger = "on_crit", effect = "+3 Charge" }
        }
    },

    storm_form = {
        id = "storm_form",
        name = "Storm Form",
        description = "On threshold (20 Speed): gain Stormform.",
        element = "lightning",
        icon = "skill_storm_form",
        cost = 5,
        order = 8,
        triggers = { "on_threshold" },
        effects = {
            { type = "proc", trigger = "on_threshold (20 Speed)", effect = "Gain Stormform" }
        }
    },

    --------------------------------------------------------------------------------
    -- VOID SKILLS (8)
    --------------------------------------------------------------------------------

    entropy = {
        id = "entropy",
        name = "Entropy",
        description = "On hit: apply +1 Doom.",
        element = "void",
        icon = "skill_entropy",
        cost = 1,
        order = 1,
        triggers = { "on_hit" },
        effects = {
            { type = "proc", trigger = "on_hit", effect = "+1 Doom per hit" }
        }
    },

    necrokinesis = {
        id = "necrokinesis",
        name = "Necrokinesis",
        description = "On hit or on heal: 30 Death to closest. On heal: +50 Death.",
        element = "void",
        icon = "skill_necrokinesis",
        cost = 2,
        order = 2,
        triggers = { "on_hit", "on_heal" },
        effects = {
            { type = "proc", trigger = "on_hit or on_heal", effect = "30 Death to closest; on heal: +50 Death" }
        }
    },

    cursed_flesh = {
        id = "cursed_flesh",
        name = "Cursed Flesh",
        description = "On enemy killed: heal 10, 50 Death to 2 adjacent.",
        element = "void",
        icon = "skill_cursed_flesh",
        cost = 3,
        order = 3,
        triggers = { "enemy_killed" },
        effects = {
            { type = "proc", trigger = "enemy_killed", effect = "Heal 10, 50 Death to 2 adjacent" }
        }
    },

    grave_summon = {
        id = "grave_summon",
        name = "Grave Summon",
        description = "On wave start + enemy killed: summon 2 Skeletons. 30% more on kill.",
        element = "void",
        icon = "skill_grave_summon",
        cost = 3,
        order = 4,
        triggers = { "on_wave_start", "enemy_killed" },
        effects = {
            { type = "proc", trigger = "on_wave_start + enemy_killed", effect = "Summon 2 Skeletons; 30% more on kill" }
        }
    },

    doom_mark = {
        id = "doom_mark",
        name = "Doom Mark",
        description = "Passive: Enemies with Doom take +20% damage.",
        element = "void",
        icon = "skill_doom_mark",
        cost = 3,
        order = 5,
        triggers = { "passive" },
        effects = {
            { type = "rule_change", desc = "Enemies with Doom take +20% damage." }
        }
    },

    anchor_of_doom = {
        id = "anchor_of_doom",
        name = "Anchor of Doom",
        description = "On stand still: all enemies in range gain 1 Doom/sec.",
        element = "void",
        icon = "skill_anchor_of_doom",
        cost = 3,
        order = 6,
        triggers = { "on_stand_still" },
        effects = {
            { type = "proc", trigger = "on_stand_still", effect = "Enemies in range gain 1 Doom/sec" }
        }
    },

    doom_master = {
        id = "doom_master",
        name = "Doom Master",
        description = "Passive: Immune to Doom. Doom threshold -> 5.",
        element = "void",
        icon = "skill_doom_master",
        cost = 4,
        order = 7,
        triggers = { "passive" },
        effects = {
            { type = "rule_change", desc = "Immune to Doom. Doom threshold -> 5." }
        }
    },

    void_form = {
        id = "void_form",
        name = "Void Form",
        description = "On threshold (100 Death): gain Voidform.",
        element = "void",
        icon = "skill_void_form",
        cost = 5,
        order = 8,
        triggers = { "on_threshold" },
        effects = {
            { type = "proc", trigger = "on_threshold (100 Death)", effect = "Gain Voidform" }
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

local ELEMENT_ORDER = {
    fire = 1,
    ice = 2,
    lightning = 3,
    void = 4,
}

local function sortSkills(results, useElementOrder)
    table.sort(results, function(a, b)
        local aDef = a.def or {}
        local bDef = b.def or {}
        if useElementOrder then
            local aElem = ELEMENT_ORDER[aDef.element or ""] or 99
            local bElem = ELEMENT_ORDER[bDef.element or ""] or 99
            if aElem ~= bElem then
                return aElem < bElem
            end
        end

        local aCost = aDef.cost or 0
        local bCost = bDef.cost or 0
        if aCost ~= bCost then
            return aCost < bCost
        end

        local aOrder = aDef.order or 0
        local bOrder = bDef.order or 0
        if aOrder ~= bOrder then
            return aOrder < bOrder
        end

        return tostring(a.id) < tostring(b.id)
    end)
end

--- Get all skills of a specific element in display order
--- @param element string The element to filter by ("fire", "ice", "lightning", "void")
--- @return table Array of {id, def} pairs matching the element
function Skills.getOrderedByElement(element)
    local results = Skills.getByElement(element)
    sortSkills(results, false)
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

--- Get all skills in display order (element -> cost -> order)
--- @return table Array of {id, def} pairs
function Skills.getAllOrdered()
    local results = Skills.getAllSkills()
    sortSkills(results, true)
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
