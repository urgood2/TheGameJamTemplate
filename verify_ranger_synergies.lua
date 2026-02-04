--[[
================================================================================
MANUAL VERIFICATION: Ranger Synergy Bonuses
================================================================================
Verifies that Ranger synergy bonuses are correctly implemented:
- 2 Rangers: +20% atk_spd to Rangers
- 4 Rangers: +40% atk_spd, +20% range to Rangers

Run with: lua verify_ranger_synergies.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local synergy_system = require("serpent.synergy_system")
local units = require("serpent.data.units")

print("================================================================================")
print("MANUAL VERIFICATION: Ranger Synergy Bonuses")
print("================================================================================")
print("Testing requirement: 2: +20% atk_spd to Rangers, 4: +40% atk_spd, +20% range to Rangers")
print()

-- Get unit definitions for testing
local all_units = units.get_all_units()
local unit_defs = {}
for _, unit in ipairs(all_units) do
    unit_defs[unit.id] = unit
end

print("=== Ranger Synergy Verification ===")

-- Test 2 Rangers: +20% atk_spd
print("--- Testing 2 Rangers ---")
local ranger_segments_2 = {
    {instance_id = 1, def_id = "scout", hp = 60, level = 1},
    {instance_id = 2, def_id = "sniper", hp = 50, level = 1}
}

local synergy_state_2 = synergy_system.calculate(ranger_segments_2, unit_defs)
local multipliers_2 = synergy_system.get_effective_multipliers(synergy_state_2, ranger_segments_2, unit_defs)

print("Active Rangers: 2")
print("Expected bonuses: +20% attack speed")

if synergy_state_2.active_bonuses.Ranger then
    local ranger_bonus = synergy_state_2.active_bonuses.Ranger
    print(string.format("+ Attack speed multiplier: %.1fx (%+.0f%%)",
        ranger_bonus.atk_spd_mult, (ranger_bonus.atk_spd_mult - 1) * 100))

    if ranger_bonus.atk_spd_mult == 1.2 then
        print("+ SUCCESS: Attack speed bonus correct")
    else
        print("+ ERROR: Expected 1.2x, got " .. tostring(ranger_bonus.atk_spd_mult))
    end

    if not ranger_bonus.range_mult then
        print("+ SUCCESS: No range bonus (as expected)")
    else
        print("+ ERROR: Unexpected range bonus: " .. tostring(ranger_bonus.range_mult))
    end
else
    print("- ERROR: No Ranger bonuses found")
end
print()

-- Test 4 Rangers: +40% atk_spd, +20% range
print("--- Testing 4 Rangers ---")
local ranger_segments_4 = {
    {instance_id = 1, def_id = "scout", hp = 60, level = 1},
    {instance_id = 2, def_id = "sniper", hp = 50, level = 1},
    {instance_id = 3, def_id = "assassin", hp = 80, level = 1},
    {instance_id = 4, def_id = "windrunner", hp = 110, level = 1}
}

local synergy_state_4 = synergy_system.calculate(ranger_segments_4, unit_defs)
local multipliers_4 = synergy_system.get_effective_multipliers(synergy_state_4, ranger_segments_4, unit_defs)

print("Active Rangers: 4")
print("Expected bonuses: +40% attack speed, +20% range")

if synergy_state_4.active_bonuses.Ranger then
    local ranger_bonus = synergy_state_4.active_bonuses.Ranger
    print(string.format("+ Attack speed multiplier: %.1fx (%+.0f%%)",
        ranger_bonus.atk_spd_mult, (ranger_bonus.atk_spd_mult - 1) * 100))
    print(string.format("+ Range multiplier: %.1fx (%+.0f%%)",
        ranger_bonus.range_mult, (ranger_bonus.range_mult - 1) * 100))

    local atk_spd_correct = (ranger_bonus.atk_spd_mult == 1.4)
    local range_correct = (ranger_bonus.range_mult == 1.2)

    if atk_spd_correct then
        print("+ SUCCESS: Attack speed bonus correct")
    else
        print("+ ERROR: Expected 1.4x attack speed, got " .. tostring(ranger_bonus.atk_spd_mult))
    end

    if range_correct then
        print("+ SUCCESS: Range bonus correct")
    else
        print("+ ERROR: Expected 1.2x range, got " .. tostring(ranger_bonus.range_mult))
    end

    if atk_spd_correct and range_correct then
        print("+ SUCCESS: All 4-Ranger bonuses correct")
    end
else
    print("- ERROR: No Ranger bonuses found")
end
print()

-- Test multiplier application to individual Rangers
print("--- Testing Multiplier Application ---")
print("Verifying that each Ranger unit receives the correct multipliers:")

for _, segment in ipairs(ranger_segments_4) do
    local multiplier = multipliers_4[segment.instance_id]
    if multiplier then
        local atk_spd = multiplier.atk_spd_mult or 1.0
        local range = multiplier.range_mult or 1.0
        print(string.format("+ Instance %d (%s): atk_spd=%.1fx, range=%.1fx",
            segment.instance_id, segment.def_id, atk_spd, range))
    else
        print(string.format("- Instance %d: No multipliers found", segment.instance_id))
    end
end
print()

print("================================================================================")
print("VERIFICATION RESULTS")
print("================================================================================")

local all_correct = true

-- Verify 2-Ranger bonus
local bonus_2 = synergy_state_2.active_bonuses.Ranger
if not bonus_2 or bonus_2.atk_spd_mult ~= 1.2 or bonus_2.range_mult then
    all_correct = false
end

-- Verify 4-Ranger bonus
local bonus_4 = synergy_state_4.active_bonuses.Ranger
if not bonus_4 or bonus_4.atk_spd_mult ~= 1.4 or bonus_4.range_mult ~= 1.2 then
    all_correct = false
end

if all_correct then
    print("SUCCESS: Ranger synergy bonuses are correctly implemented!")
    print()
    print("+ 2 Rangers: +20% attack speed (1.2x multiplier)")
    print("+ 4 Rangers: +40% attack speed (1.4x multiplier)")
    print("+ 4 Rangers: +20% range (1.2x multiplier)")
    print()
    print("REQUIREMENT VERIFIED: Ranger synergy implementation is complete and accurate")
    return true
else
    print("FAILURE: Ranger synergy bonuses have implementation errors")
    return false
end