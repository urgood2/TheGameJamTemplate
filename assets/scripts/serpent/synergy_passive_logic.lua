-- assets/scripts/serpent/synergy_passive_logic.lua
--[[
    Synergy + Passive Computation Module

    Computes synergy_state and passive modifiers, then recalculates
    effective stats for each segment and builds combat snapshots.
]]

local synergy_system = require("serpent.synergy_system")
local specials_system = require("serpent.specials_system")
local unit_factory = require("serpent.unit_factory")

local synergy_passive_logic = {}

local function copy_table_shallow(t)
    if type(t) ~= "table" then
        return {}
    end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = v
    end
    return copy
end

local function resolve_base_stats(segment, unit_def)
    local hp_max_base = segment.hp_max_base or segment.hp_max_base_int
    local attack_base = segment.attack_base or segment.attack_base_int

    if (hp_max_base == nil or attack_base == nil) and unit_def then
        local scaled = unit_factory.apply_level_scaling(unit_def, segment.level or 1)
        if hp_max_base == nil then
            hp_max_base = scaled.hp_max_base_int
        end
        if attack_base == nil then
            attack_base = scaled.attack_base_int
        end
    end

    local range_base = segment.range_base
    if range_base == nil and unit_def then
        range_base = unit_def.range
    end

    local atk_spd_base = segment.atk_spd_base
    if atk_spd_base == nil and unit_def then
        atk_spd_base = unit_def.atk_spd
    end

    return hp_max_base or 0, attack_base or 0, range_base or 0, atk_spd_base or 0
end

local function apply_bonus(multipliers, bonuses)
    if not bonuses then
        return
    end

    if bonuses.hp_mult then
        multipliers.hp_mult = multipliers.hp_mult * bonuses.hp_mult
    end
    if bonuses.atk_mult then
        multipliers.atk_mult = multipliers.atk_mult * bonuses.atk_mult
    end
    if bonuses.range_mult then
        multipliers.range_mult = multipliers.range_mult * bonuses.range_mult
    end
    if bonuses.atk_spd_mult then
        multipliers.atk_spd_mult = multipliers.atk_spd_mult * bonuses.atk_spd_mult
    end
    if bonuses.cooldown_period_mult then
        multipliers.cooldown_period_mult = multipliers.cooldown_period_mult * bonuses.cooldown_period_mult
    end
end

local function extract_support_global_bonus(synergy_state)
    local support = synergy_state and synergy_state.active_bonuses and synergy_state.active_bonuses.Support or nil
    if not support then
        return nil
    end

    return {
        hp_mult = support.hp_mult,
        atk_mult = support.atk_mult,
        range_mult = support.range_mult,
        atk_spd_mult = support.atk_spd_mult
    }
end

local function hydrate_segments(snake_state, unit_defs)
    local hydrated = {
        segments = {},
        min_len = snake_state.min_len or 3,
        max_len = snake_state.max_len or 8
    }

    for _, segment in ipairs(snake_state.segments or {}) do
        local unit_def = unit_defs and segment.def_id and unit_defs[segment.def_id] or nil
        local updated_segment = {
            instance_id = segment.instance_id,
            def_id = segment.def_id,
            level = segment.level,
            hp = segment.hp,
            hp_max_base = segment.hp_max_base,
            attack_base = segment.attack_base,
            range_base = segment.range_base,
            atk_spd_base = segment.atk_spd_base,
            cooldown = segment.cooldown,
            acquired_seq = segment.acquired_seq,
            special_state = copy_table_shallow(segment.special_state),
            special_id = segment.special_id or (unit_def and unit_def.special_id) or nil
        }

        table.insert(hydrated.segments, updated_segment)
    end

    return hydrated
end

--- Compute synergy/passive multipliers and build combat snapshots.
--- @param snake_state table Snake state with segments in head->tail order
--- @param unit_defs table Unit definitions for class/special lookup
--- @param segment_positions_by_instance_id table Lookup for segment positions
--- @return table, table, table, table Updated snake_state, segment_combat_snaps, synergy_state, passive_mods
function synergy_passive_logic.compute(snake_state, unit_defs, segment_positions_by_instance_id)
    local safe_state = snake_state or { segments = {}, min_len = 3, max_len = 8 }
    local safe_unit_defs = unit_defs or {}

    local hydrated_state = hydrate_segments(safe_state, safe_unit_defs)
    local synergy_state = synergy_system.calculate(hydrated_state.segments, safe_unit_defs)
    local passive_mods = specials_system.get_passive_mods(hydrated_state, safe_unit_defs)
    local support_global_bonus = extract_support_global_bonus(synergy_state)

    local segment_combat_snaps = {}
    local updated_state = {
        segments = {},
        min_len = hydrated_state.min_len or 3,
        max_len = hydrated_state.max_len or 8
    }

    for _, segment in ipairs(hydrated_state.segments or {}) do
        local unit_def = safe_unit_defs[segment.def_id]
        local class = unit_def and unit_def.class or nil

        local hp_base, atk_base, range_base, atk_spd_base = resolve_base_stats(segment, unit_def)

        local multipliers = {
            hp_mult = 1.0,
            atk_mult = 1.0,
            range_mult = 1.0,
            atk_spd_mult = 1.0,
            cooldown_period_mult = 1.0
        }

        if class and class ~= "Support" and synergy_state and synergy_state.active_bonuses then
            apply_bonus(multipliers, synergy_state.active_bonuses[class])
        end

        apply_bonus(multipliers, support_global_bonus)

        local passive = passive_mods and segment.instance_id and passive_mods[segment.instance_id] or nil
        apply_bonus(multipliers, passive)

        local effective_hp_max = math.floor((hp_base or 0) * multipliers.hp_mult + 0.00001)
        local effective_attack = math.floor((atk_base or 0) * multipliers.atk_mult + 0.00001)
        local effective_range = (range_base or 0) * multipliers.range_mult
        local effective_atk_spd = (atk_spd_base or 0) * multipliers.atk_spd_mult

        local effective_period = math.huge
        if effective_atk_spd > 0 then
            effective_period = (1 / effective_atk_spd) * multipliers.cooldown_period_mult
        end

        local updated_segment = {
            instance_id = segment.instance_id,
            def_id = segment.def_id,
            level = segment.level,
            hp = segment.hp,
            hp_max_base = segment.hp_max_base,
            attack_base = segment.attack_base,
            range_base = segment.range_base,
            atk_spd_base = segment.atk_spd_base,
            cooldown = segment.cooldown,
            acquired_seq = segment.acquired_seq,
            special_state = copy_table_shallow(segment.special_state),
            special_id = segment.special_id
        }

        if updated_segment.hp and effective_hp_max ~= nil and updated_segment.hp > effective_hp_max then
            updated_segment.hp = effective_hp_max
        end
        if updated_segment.hp and updated_segment.hp < 0 then
            updated_segment.hp = 0
        end

        table.insert(updated_state.segments, updated_segment)

        if updated_segment.hp and updated_segment.hp > 0 then
            local pos = segment_positions_by_instance_id and segment.instance_id and
                segment_positions_by_instance_id[segment.instance_id] or nil

            local snap_attack = effective_attack
            local snap_period = effective_period
            if effective_atk_spd <= 0 then
                snap_attack = 0
                snap_period = math.huge
            end

            table.insert(segment_combat_snaps, {
                instance_id = segment.instance_id,
                def_id = segment.def_id,
                special_id = segment.special_id,
                x = pos and pos.x or 0,
                y = pos and pos.y or 0,
                cooldown_num = segment.cooldown or 0,
                effective_hp_max_int = effective_hp_max,
                effective_attack_int = snap_attack,
                effective_range_num = effective_range,
                effective_atk_spd_num = effective_atk_spd,
                effective_period_num = snap_period
            })
        end
    end

    return updated_state, segment_combat_snaps, synergy_state, passive_mods
end

return synergy_passive_logic
