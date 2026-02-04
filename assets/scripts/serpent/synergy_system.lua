-- assets/scripts/serpent/synergy_system.lua
--[[
    Synergy System Module

    Calculates class-based synergy bonuses from current snake segments.
    Provides multipliers for HP, attack, range, attack speed, cooldown, and global regen.
]]

local synergy_system = {}

-- Synergy thresholds and bonuses
local SYNERGY_THRESHOLDS = {2, 4}
local SYNERGY_BONUSES = {
    Warrior = {
        [2] = { atk_mult = 1.2 }, -- +20% attack damage to Warriors
        [4] = { atk_mult = 1.4, hp_mult = 1.2 } -- +40% attack damage, +20% HP to Warriors
    },
    Mage = {
        [2] = { atk_mult = 1.2 }, -- +20% spell damage to Mages
        [4] = { atk_mult = 1.4, cooldown_period_mult = 0.8 } -- +40% spell damage, -20% cooldown to Mages
    },
    Ranger = {
        [2] = { atk_spd_mult = 1.2 }, -- +20% attack speed to Rangers
        [4] = { atk_spd_mult = 1.4, range_mult = 1.2 } -- +40% attack speed, +20% range to Rangers
    },
    Support = {
        [2] = { global_regen_per_sec = 5 }, -- Heal snake 5 HP/sec
        [4] = { global_regen_per_sec = 10, hp_mult = 1.1, atk_mult = 1.1,
               range_mult = 1.1, atk_spd_mult = 1.1 } -- Heal 10 HP/sec, +10% all stats
    }
}

--- Calculate synergy state from current snake segments
--- @param segments table Array of unit instances (post-combine)
--- @param unit_defs table Unit definitions for class lookup
--- @return table Synergy state with class counts and active bonuses
function synergy_system.calculate(segments, unit_defs)
    local synergy_state = {
        class_counts = {
            Warrior = 0,
            Mage = 0,
            Ranger = 0,
            Support = 0
        },
        active_bonuses = {
            Warrior = {},
            Mage = {},
            Ranger = {},
            Support = {}
        }
    }

    if not segments or not unit_defs then
        return synergy_state
    end

    -- Count units by class
    for _, segment in ipairs(segments) do
        if segment and segment.def_id and segment.hp and segment.hp > 0 then
            local unit_def = unit_defs[segment.def_id]
            if unit_def and unit_def.class then
                local class = unit_def.class
                synergy_state.class_counts[class] = synergy_state.class_counts[class] + 1
            end
        end
    end

    -- Calculate active bonuses for each class
    for class, count in pairs(synergy_state.class_counts) do
        local bonuses = SYNERGY_BONUSES[class]
        if bonuses then
            -- Check thresholds in descending order (4, then 2)
            for i = #SYNERGY_THRESHOLDS, 1, -1 do
                local threshold = SYNERGY_THRESHOLDS[i]
                if count >= threshold and bonuses[threshold] then
                    synergy_state.active_bonuses[class] = bonuses[threshold]
                    break
                end
            end
        end
    end

    return synergy_state
end

--- Get effective multipliers for each segment
--- @param synergy_state table Synergy state from calculate()
--- @param segments table Array of unit instances
--- @param unit_defs table Unit definitions for class lookup
--- @return table Multipliers by instance_id
function synergy_system.get_effective_multipliers(synergy_state, segments, unit_defs)
    local multipliers_by_instance_id = {}

    if not synergy_state or not segments or not unit_defs then
        return multipliers_by_instance_id
    end

    -- Base multipliers (no bonuses)
    local base_multipliers = {
        hp_mult = 1.0,
        atk_mult = 1.0,
        range_mult = 1.0,
        atk_spd_mult = 1.0,
        cooldown_period_mult = 1.0,
        global_regen_per_sec = 0.0
    }

    -- Process each segment
    for _, segment in ipairs(segments) do
        if segment and segment.instance_id and segment.def_id and segment.hp and segment.hp > 0 then
            local unit_def = unit_defs[segment.def_id]
            if unit_def and unit_def.class then
                local class = unit_def.class
                local bonuses = synergy_state.active_bonuses[class] or {}

                -- Copy base multipliers
                local multipliers = {
                    hp_mult = base_multipliers.hp_mult,
                    atk_mult = base_multipliers.atk_mult,
                    range_mult = base_multipliers.range_mult,
                    atk_spd_mult = base_multipliers.atk_spd_mult,
                    cooldown_period_mult = base_multipliers.cooldown_period_mult,
                    global_regen_per_sec = base_multipliers.global_regen_per_sec
                }

                -- Apply class-specific bonuses
                for bonus_type, bonus_value in pairs(bonuses) do
                    if multipliers[bonus_type] ~= nil then
                        multipliers[bonus_type] = bonus_value
                    end
                end

                -- Note: Support global regen is applied globally, not per instance
                -- This is handled separately in the combat system

                multipliers_by_instance_id[segment.instance_id] = multipliers
            end
        end
    end

    return multipliers_by_instance_id
end

--- Get global regen rate from Support synergy
--- @param synergy_state table Synergy state from calculate()
--- @return number Global regen HP per second
function synergy_system.get_global_regen_rate(synergy_state)
    if not synergy_state or not synergy_state.active_bonuses then
        return 0.0
    end

    local support_bonuses = synergy_state.active_bonuses.Support or {}
    return support_bonuses.global_regen_per_sec or 0.0
end

--- Get synergy summary for UI display
--- @param synergy_state table Synergy state from calculate()
--- @return table Summary with class counts and bonus descriptions
function synergy_system.get_synergy_summary(synergy_state)
    local summary = {
        class_counts = synergy_state.class_counts or {},
        active_synergies = {}
    }

    if not synergy_state or not synergy_state.active_bonuses then
        return summary
    end

    -- Generate descriptions for active bonuses
    for class, bonuses in pairs(synergy_state.active_bonuses) do
        if next(bonuses) then -- Check if bonuses table is not empty
            local count = summary.class_counts[class] or 0
            local description = synergy_system._format_bonus_description(class, count, bonuses)
            table.insert(summary.active_synergies, {
                class = class,
                count = count,
                description = description
            })
        end
    end

    return summary
end

--- Format bonus description for UI display
--- @param class string Class name
--- @param count number Number of units
--- @param bonuses table Active bonuses
--- @return string Formatted description
function synergy_system._format_bonus_description(class, count, bonuses)
    local parts = {}

    if bonuses.atk_mult and bonuses.atk_mult > 1.0 then
        local percent = math.floor((bonuses.atk_mult - 1.0) * 100)
        if class == "Mage" then
            table.insert(parts, string.format("+%d%% spell damage", percent))
        else
            table.insert(parts, string.format("+%d%% attack damage", percent))
        end
    end

    if bonuses.hp_mult and bonuses.hp_mult > 1.0 then
        local percent = math.floor((bonuses.hp_mult - 1.0) * 100)
        table.insert(parts, string.format("+%d%% HP", percent))
    end

    if bonuses.atk_spd_mult and bonuses.atk_spd_mult > 1.0 then
        local percent = math.floor((bonuses.atk_spd_mult - 1.0) * 100)
        table.insert(parts, string.format("+%d%% attack speed", percent))
    end

    if bonuses.range_mult and bonuses.range_mult > 1.0 then
        local percent = math.floor((bonuses.range_mult - 1.0) * 100)
        table.insert(parts, string.format("+%d%% range", percent))
    end

    if bonuses.cooldown_period_mult and bonuses.cooldown_period_mult < 1.0 then
        local percent = math.floor((1.0 - bonuses.cooldown_period_mult) * 100)
        table.insert(parts, string.format("-%d%% cooldown", percent))
    end

    if bonuses.global_regen_per_sec and bonuses.global_regen_per_sec > 0 then
        table.insert(parts, string.format("Heal snake %d HP/sec", bonuses.global_regen_per_sec))
    end

    -- Handle Support 4-unit "all stats" bonus
    if class == "Support" and count >= 4 and bonuses.atk_mult and bonuses.hp_mult and
       bonuses.range_mult and bonuses.atk_spd_mult then
        local all_same = (bonuses.atk_mult == bonuses.hp_mult and
                         bonuses.hp_mult == bonuses.range_mult and
                         bonuses.range_mult == bonuses.atk_spd_mult)
        if all_same and bonuses.atk_mult > 1.0 then
            local percent = math.floor((bonuses.atk_mult - 1.0) * 100)
            -- Replace individual stat bonuses with "all stats" description
            parts = {string.format("Heal snake %d HP/sec", bonuses.global_regen_per_sec or 10),
                    string.format("+%d%% all stats", percent)}
        end
    end

    return table.concat(parts, ", ")
end

--- Check if Mage synergy bonuses are correctly implemented (for testing)
--- @return boolean True if Mage synergy implementation is correct
function synergy_system.verify_mage_synergy()
    -- Test 2 Mages: +20% spell damage
    local bonuses_2 = SYNERGY_BONUSES.Mage[2]
    if not bonuses_2 or bonuses_2.atk_mult ~= 1.2 then
        return false
    end

    -- Test 4 Mages: +40% spell damage, -20% cooldown
    local bonuses_4 = SYNERGY_BONUSES.Mage[4]
    if not bonuses_4 or bonuses_4.atk_mult ~= 1.4 or bonuses_4.cooldown_period_mult ~= 0.8 then
        return false
    end

    return true
end

return synergy_system
