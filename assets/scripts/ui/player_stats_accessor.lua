--[[
  Player Stats Accessor
  Provides correct access to player stats from combat_context.
  Used by combat_debug_panel.lua.
]]

local PlayerStatsAccessor = {}

--- Get the player actor from combat context
-- @return table|nil player actor or nil if not in combat
function PlayerStatsAccessor.get_player()
    if not combat_context or not combat_context.side1 or not combat_context.side1[1] then
        return nil
    end
    return combat_context.side1[1]
end

--- Get the player's Stats instance
-- @return Stats|nil
function PlayerStatsAccessor.get_stats()
    local player = PlayerStatsAccessor.get_player()
    return player and player.stats
end

--- Safely get a stat value (computed)
-- @param stat_name string
-- @return number
function PlayerStatsAccessor.get(stat_name)
    local stats = PlayerStatsAccessor.get_stats()
    if not stats then return 0 end
    return stats:get(stat_name)
end

--- Safely get raw stat bucket
-- @param stat_name string
-- @return table {base, add_pct, mul_pct} or default
function PlayerStatsAccessor.get_raw(stat_name)
    local stats = PlayerStatsAccessor.get_stats()
    if not stats then return { base = 0, add_pct = 0, mul_pct = 0 } end
    local raw = stats:get_raw(stat_name)
    return raw or { base = 0, add_pct = 0, mul_pct = 0 }
end

--- Set base value and recompute
-- @param stat_name string
-- @param value number
function PlayerStatsAccessor.set_base(stat_name, value)
    local stats = PlayerStatsAccessor.get_stats()
    if not stats then
        print("[PlayerStatsAccessor] No player stats available")
        return false
    end

    local raw = stats:get_raw(stat_name)
    if raw then
        raw.base = value
    else
        -- Ensure the stat exists
        stats:_ensure(stat_name)
        stats.values[stat_name].base = value
    end

    stats:recompute()
    print(string.format("[PlayerStatsAccessor] Set %s.base = %s, recomputed", stat_name, tostring(value)))
    return true
end

--- Get combat damage types (for iteration)
-- @return table array of damage type strings
function PlayerStatsAccessor.get_damage_types()
    if CombatSystem and CombatSystem.Core and CombatSystem.Core.DAMAGE_TYPES then
        return CombatSystem.Core.DAMAGE_TYPES
    end
    -- Fallback
    return {
        'physical', 'pierce', 'bleed', 'trauma',
        'fire', 'cold', 'lightning', 'acid',
        'vitality', 'aether', 'chaos',
        'burn', 'frostburn', 'electrocute', 'poison', 'vitality_decay'
    }
end

--- Get player current HP
function PlayerStatsAccessor.get_hp()
    local player = PlayerStatsAccessor.get_player()
    if not player then return 0, 100 end
    local max_hp = player.max_health or PlayerStatsAccessor.get('health') or 100
    local hp = player.hp or max_hp
    return hp, max_hp
end

--- Set player current HP
function PlayerStatsAccessor.set_hp(value)
    local player = PlayerStatsAccessor.get_player()
    if not player then return false end
    local _, max_hp = PlayerStatsAccessor.get_hp()
    player.hp = math.max(0, math.min(max_hp, value))
    return true
end

--- Calculate expected damage after defenses (for preview)
-- @param incoming_damage number raw damage
-- @param damage_type string e.g. 'physical', 'fire'
-- @return number damage after defenses, table breakdown
function PlayerStatsAccessor.preview_damage(incoming_damage, damage_type)
    local stats = PlayerStatsAccessor.get_stats()
    if not stats then
        return incoming_damage, { raw = incoming_damage, final = incoming_damage }
    end

    damage_type = damage_type or 'physical'
    local breakdown = { raw = incoming_damage }
    local damage = incoming_damage

    -- 1. Dodge chance (probabilistic - show expected value)
    local dodge = stats:get('dodge_chance_pct') or 0
    dodge = math.min(75, math.max(0, dodge)) -- cap at 75%
    breakdown.dodge_chance = dodge
    local expected_after_dodge = damage * (1 - dodge / 100)
    breakdown.after_dodge_expected = expected_after_dodge

    -- 2. Block (probabilistic + flat reduction)
    local block_chance = stats:get('block_chance_pct') or 0
    local block_amount = stats:get('block_amount') or 0
    breakdown.block_chance = block_chance
    breakdown.block_amount = block_amount
    -- Expected: (1 - block%) * damage + block% * max(0, damage - block_amount)
    local blocked_damage = math.max(0, damage - block_amount)
    local expected_after_block = (1 - block_chance/100) * damage + (block_chance/100) * blocked_damage
    breakdown.after_block_expected = expected_after_block

    -- 3. Armor (physical only)
    local after_armor = expected_after_block
    if damage_type == 'physical' then
        local armor = stats:get('armor') or 0
        local armor_absorption = 0.70 * (1 + (stats:get('armor_absorption_bonus_pct') or 0) / 100)
        local mitigation = math.min(expected_after_block, armor) * armor_absorption
        after_armor = expected_after_block - mitigation
        breakdown.armor = armor
        breakdown.armor_mitigation = mitigation
    end
    breakdown.after_armor = after_armor

    -- 4. Resistance
    local resist_key = damage_type .. '_resist_pct'
    local resist = stats:get(resist_key) or 0
    local max_cap = 100 + (stats:get('max_resist_cap_pct') or 0)
    local min_cap = -100 + (stats:get('min_resist_cap_pct') or 0)
    resist = math.max(min_cap, math.min(max_cap, resist))
    breakdown.resistance = resist
    local after_resist = after_armor * (1 - resist / 100)
    breakdown.after_resist = after_resist

    -- 5. Damage reduction
    local dr = stats:get('damage_taken_reduction_pct') or 0
    local type_dr_key = 'damage_taken_' .. damage_type .. '_reduction_pct'
    local type_dr = stats:get(type_dr_key) or 0
    local after_dr = after_resist * (1 - dr / 100) * (1 - type_dr / 100)
    breakdown.damage_reduction = dr
    breakdown.type_damage_reduction = type_dr
    breakdown.after_dr = after_dr

    -- 6. Absorb
    local pct_absorb = stats:get('percent_absorb_pct') or 0
    local flat_absorb = stats:get('flat_absorb') or 0
    local after_pct = after_dr * (1 - pct_absorb / 100)
    local final = math.max(0, after_pct - flat_absorb)
    breakdown.percent_absorb = pct_absorb
    breakdown.flat_absorb = flat_absorb
    breakdown.final = final

    return final, breakdown
end

return PlayerStatsAccessor
