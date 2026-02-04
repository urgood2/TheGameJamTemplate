--[[
================================================================================
MANUAL VERIFICATION: Warrior Units Definition
================================================================================
Verifies that all 4 Warrior units are properly defined:
- soldier (Tier 1)
- knight (Tier 2)
- berserker (Tier 3)
- champion (Tier 4)

Run with: lua verify_warrior_units.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local units = require("serpent.data.units")

print("================================================================================")
print("MANUAL VERIFICATION: Warrior Units Definition")
print("================================================================================")
print("Testing requirement: Define Warrior units (soldier, knight, berserker, champion)")
print()

-- Expected Warrior units
local expected_warriors = {
    {id = "soldier", tier = 1},
    {id = "knight", tier = 2},
    {id = "berserker", tier = 3},
    {id = "champion", tier = 4}
}

print("=== Warrior Units Verification ===")

local all_verified = true

for _, expected in ipairs(expected_warriors) do
    local unit = units.get_unit(expected.id)

    if unit then
        print(string.format("+ %s (Tier %d): FOUND", expected.id, expected.tier))

        -- Verify it's a Warrior class
        if unit.class == "Warrior" then
            print(string.format("  Class: Warrior - OK"))
        else
            print(string.format("  Class: %s - ERROR (expected Warrior)", unit.class or "nil"))
            all_verified = false
        end

        -- Verify tier matches
        if unit.tier == expected.tier then
            print(string.format("  Tier: %d - OK", unit.tier))
        else
            print(string.format("  Tier: %d - ERROR (expected %d)", unit.tier or 0, expected.tier))
            all_verified = false
        end

        -- Verify basic stats are present
        if unit.base_hp and unit.base_hp > 0 then
            print(string.format("  Base HP: %d - OK", unit.base_hp))
        else
            print("  Base HP: Missing or invalid")
            all_verified = false
        end

        if unit.base_attack and unit.base_attack > 0 then
            print(string.format("  Base Attack: %d - OK", unit.base_attack))
        else
            print("  Base Attack: Missing or invalid")
            all_verified = false
        end

    else
        print(string.format("- %s: NOT FOUND", expected.id))
        all_verified = false
    end
    print()
end

print("================================================================================")
print("VERIFICATION RESULTS")
print("================================================================================")

if all_verified then
    print("SUCCESS: All 4 Warrior units are properly defined!")
    print()
    print("+ soldier (Tier 1 Warrior) - Complete")
    print("+ knight (Tier 2 Warrior) - Complete")
    print("+ berserker (Tier 3 Warrior) - Complete")
    print("+ champion (Tier 4 Warrior) - Complete")
    print()
    print("REQUIREMENT VERIFIED: Warrior units definition is complete")

    return true
else
    print("FAILURE: Some Warrior units are missing or incorrectly defined")
    return false
end