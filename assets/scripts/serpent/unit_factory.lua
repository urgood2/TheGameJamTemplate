-- Serpent unit factory (pure logic)
-- Creates UnitInstance tables and applies level-based stat scaling.

local unit_factory = {}

local function clamp_level(level)
    level = math.floor(tonumber(level) or 1)
    if level < 1 then
        level = 1
    elseif level > 3 then
        level = 3
    end
    return level
end

local function scale_stat(base_value, level)
    local scaled = (tonumber(base_value) or 0) * (2 ^ (level - 1))
    return math.floor(scaled + 0.00001)
end

--- Apply level scaling to a unit definition.
--- @param unit_def table
--- @param level number
--- @return table { hp_max_base_int, attack_base_int }
function unit_factory.apply_level_scaling(unit_def, level)
    local lvl = clamp_level(level)
    local base_hp = unit_def and unit_def.base_hp or 0
    local base_attack = unit_def and unit_def.base_attack or 0

    return {
        hp_max_base_int = scale_stat(base_hp, lvl),
        attack_base_int = scale_stat(base_attack, lvl),
    }
end

--- Create a level-1 UnitInstance from a UnitDef.
--- @param unit_def table
--- @param instance_id number
--- @param acquired_seq number
--- @return table UnitInstance
function unit_factory.create_instance(unit_def, instance_id, acquired_seq)
    local scaled = unit_factory.apply_level_scaling(unit_def, 1)
    local hp_max_base = scaled.hp_max_base_int
    local attack_base = scaled.attack_base_int

    return {
        instance_id = instance_id,
        def_id = unit_def and unit_def.id or nil,
        level = 1,
        hp = hp_max_base,
        hp_max_base = hp_max_base,
        attack_base = attack_base,
        range_base = unit_def and unit_def.range or 0,
        atk_spd_base = unit_def and unit_def.atk_spd or 0,
        cooldown = 0,
        acquired_seq = acquired_seq,
        special_state = {},
    }
end

return unit_factory
