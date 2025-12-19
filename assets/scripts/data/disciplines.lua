-- Disciplines restrict the "School" of cards that appear for this run.
-- This ensures you don't get a diluted pool of 1000 random cards.
-- NOTE: You always get your Discipline cards + a set of "Neutral" cards.

-- Helper to get localized text with fallback
local function L(key, fallback)
    if localization and localization.get then
        local result = localization.get(key)
        if result and result ~= key then return result end
    end
    return fallback
end

local Disciplines = {
    arcane_discipline = {
        name = "Arcane Discipline",
        description = "Mastery of pure magic and spell manipulation.",
        tags = { "Arcane", "Projectile" },

        -- These specific cards are added to the shop pool
        actions = {
            "arcane_missile",
            "chain_lightning",
            "rift_bolt",
            "magic_missile",
            "void_orb"
        },

        modifiers = {
            "echo",
            "chain",
            "pierce",
            "split",
            "homing",
            "loop" -- Meta-mod
        }
    },

    mobility_discipline = {
        name = "Mobility Discipline",
        description = "Speed, positioning, and evasion.",
        tags = { "Mobility", "Brute" },

        actions = {
            "dash_strike",
            "teleport_bolt",
            "phase_step",
            "blink_strike",
            "momentum_blast"
        },

        modifiers = {
            "move_speed_buff",
            "reduce_dash_cooldown",
            "on_move_burst",
            "knockback",
            "haste"
        }
    },

    summon_discipline = {
        name = "Summon Discipline",
        description = "Commanding minions and constructs.",
        tags = { "Summon", "Buff" },

        actions = {
            "summon_turret",
            "summon_minion",
            "raise_dead",
            "spirit_wolf",
            "totem_of_power"
        },

        modifiers = {
            "minion_health",
            "minion_damage",
            "minion_explode_on_death",
            "duplicate_summon",
            "aura_range"
        }
    },

    brute_discipline = {
        name = "Brute Discipline",
        description = "Raw physical force and durability.",
        tags = { "Brute", "Defense" },

        actions = {
            "shockwave",
            "ground_slam",
            "shield_bash",
            "warcry",
            "heavy_strike"
        },

        modifiers = {
            "stun",
            "bleed",
            "armor_break",
            "lifesteal",
            "size_up"
        }
    }
}

--- Get localized name for a discipline (call at runtime when localization is ready)
--- @param disciplineId string The discipline key (e.g., "arcane_discipline")
--- @return string The localized name or fallback English name
function Disciplines.getLocalizedName(disciplineId)
    local discipline = Disciplines[disciplineId]
    if not discipline then return disciplineId end
    -- Map keys like "arcane_discipline" to localization keys like "discipline.arcane"
    local locKey = disciplineId:gsub("_discipline$", "")
    return L("discipline." .. locKey .. ".name", discipline.name)
end

--- Get localized description for a discipline (call at runtime when localization is ready)
--- @param disciplineId string The discipline key (e.g., "arcane_discipline")
--- @return string The localized description or fallback English description
function Disciplines.getLocalizedDescription(disciplineId)
    local discipline = Disciplines[disciplineId]
    if not discipline then return "" end
    local locKey = disciplineId:gsub("_discipline$", "")
    return L("discipline." .. locKey .. ".description", discipline.description)
end

return Disciplines
