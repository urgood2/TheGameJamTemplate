-- assets/scripts/serpent/tests/test_enemy_factory.lua
--[[
    Test Suite: Enemy Factory Module

    Verifies enemy creation and scaling:
    - HP scaling formula: floor(base_hp * (1 + wave * 0.1))
    - Damage scaling formula: floor(base_damage * (1 + wave * 0.05))
    - Proper rounding (floor)
    - Boss tag preservation
    - Position setting

    Run with: lua assets/scripts/serpent/tests/test_enemy_factory.lua
]]

-- Load dependencies
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local enemy_factory = require("serpent.enemy_factory")

-- Test framework
local test = {}
test.passed = 0
test.failed = 0

function test.assert_eq(actual, expected, message)
    if actual == expected then
        test.passed = test.passed + 1
        return true
    else
        test.failed = test.failed + 1
        print(string.format("✗ FAILED: %s\n  Expected: %s\n  Actual: %s",
            message or "assertion", tostring(expected), tostring(actual)))
        return false
    end
end

function test.assert_true(condition, message)
    return test.assert_eq(condition, true, message)
end

function test.assert_false(condition, message)
    return test.assert_eq(condition, false, message)
end

function test.assert_near(actual, expected, tolerance, message)
    if math.abs(actual - expected) <= tolerance then
        test.passed = test.passed + 1
        return true
    else
        test.failed = test.failed + 1
        print(string.format("✗ FAILED: %s\n  Expected: %s (±%s)\n  Actual: %s",
            message or "assertion", tostring(expected), tostring(tolerance), tostring(actual)))
        return false
    end
end

-- Helper: Create a test enemy definition
local function make_enemy_def(id, base_hp, base_damage, speed, tags)
    return {
        id = id,
        type = id,
        base_hp = base_hp,
        base_damage = base_damage,
        speed = speed or 100,
        tags = tags
    }
end

--===========================================================================
-- TEST: HP Scaling Formula
--===========================================================================

function test.test_hp_mult_formula()
    print("\n=== Test: HP Multiplier Formula ===")

    -- Formula: hp_mult = 1 + wave * 0.1
    test.assert_near(enemy_factory.hp_mult(1), 1.1, 0.001, "Wave 1: 1 + 1*0.1 = 1.1")
    test.assert_near(enemy_factory.hp_mult(5), 1.5, 0.001, "Wave 5: 1 + 5*0.1 = 1.5")
    test.assert_near(enemy_factory.hp_mult(10), 2.0, 0.001, "Wave 10: 1 + 10*0.1 = 2.0")
    test.assert_near(enemy_factory.hp_mult(15), 2.5, 0.001, "Wave 15: 1 + 15*0.1 = 2.5")
    test.assert_near(enemy_factory.hp_mult(20), 3.0, 0.001, "Wave 20: 1 + 20*0.1 = 3.0")

    print("✓ HP multiplier formula correct")
end

function test.test_scale_hp_basic()
    print("\n=== Test: HP Scaling Basic ===")

    -- Wave 1: 100 * 1.1 = 110
    test.assert_eq(enemy_factory.scale_hp(100, 1), 110, "100 HP at wave 1 = 110")

    -- Wave 5: 100 * 1.5 = 150
    test.assert_eq(enemy_factory.scale_hp(100, 5), 150, "100 HP at wave 5 = 150")

    -- Wave 10: 100 * 2.0 = 200
    test.assert_eq(enemy_factory.scale_hp(100, 10), 200, "100 HP at wave 10 = 200")

    -- Wave 20: 100 * 3.0 = 300
    test.assert_eq(enemy_factory.scale_hp(100, 20), 300, "100 HP at wave 20 = 300")

    print("✓ HP scaling basic values correct")
end

function test.test_scale_hp_rounding()
    print("\n=== Test: HP Scaling Rounding (Floor) ===")

    -- Test value that produces non-integer: 77 * 1.1 = 84.7 -> 84
    test.assert_eq(enemy_factory.scale_hp(77, 1), 84, "77 * 1.1 = 84.7 floors to 84")

    -- Test another: 33 * 1.5 = 49.5 -> 49
    test.assert_eq(enemy_factory.scale_hp(33, 5), 49, "33 * 1.5 = 49.5 floors to 49")

    -- Test: 99 * 2.0 = 198 (exact)
    test.assert_eq(enemy_factory.scale_hp(99, 10), 198, "99 * 2.0 = 198 (exact)")

    print("✓ HP scaling rounds down (floor)")
end

--===========================================================================
-- TEST: Damage Scaling Formula
--===========================================================================

function test.test_dmg_mult_formula()
    print("\n=== Test: Damage Multiplier Formula ===")

    -- Formula: dmg_mult = 1 + wave * 0.05
    test.assert_near(enemy_factory.dmg_mult(1), 1.05, 0.001, "Wave 1: 1 + 1*0.05 = 1.05")
    test.assert_near(enemy_factory.dmg_mult(5), 1.25, 0.001, "Wave 5: 1 + 5*0.05 = 1.25")
    test.assert_near(enemy_factory.dmg_mult(10), 1.5, 0.001, "Wave 10: 1 + 10*0.05 = 1.5")
    test.assert_near(enemy_factory.dmg_mult(15), 1.75, 0.001, "Wave 15: 1 + 15*0.05 = 1.75")
    test.assert_near(enemy_factory.dmg_mult(20), 2.0, 0.001, "Wave 20: 1 + 20*0.05 = 2.0")

    print("✓ Damage multiplier formula correct")
end

function test.test_scale_damage_basic()
    print("\n=== Test: Damage Scaling Basic ===")

    -- Wave 1: 20 * 1.05 = 21
    test.assert_eq(enemy_factory.scale_damage(20, 1), 21, "20 damage at wave 1 = 21")

    -- Wave 5: 20 * 1.25 = 25
    test.assert_eq(enemy_factory.scale_damage(20, 5), 25, "20 damage at wave 5 = 25")

    -- Wave 10: 20 * 1.5 = 30
    test.assert_eq(enemy_factory.scale_damage(20, 10), 30, "20 damage at wave 10 = 30")

    -- Wave 20: 20 * 2.0 = 40
    test.assert_eq(enemy_factory.scale_damage(20, 20), 40, "20 damage at wave 20 = 40")

    print("✓ Damage scaling basic values correct")
end

function test.test_scale_damage_rounding()
    print("\n=== Test: Damage Scaling Rounding (Floor) ===")

    -- Test value: 17 * 1.05 = 17.85 -> 17
    test.assert_eq(enemy_factory.scale_damage(17, 1), 17, "17 * 1.05 = 17.85 floors to 17")

    -- Test: 15 * 1.25 = 18.75 -> 18
    test.assert_eq(enemy_factory.scale_damage(15, 5), 18, "15 * 1.25 = 18.75 floors to 18")

    -- Test: 10 * 1.75 = 17.5 -> 17
    test.assert_eq(enemy_factory.scale_damage(10, 15), 17, "10 * 1.75 = 17.5 floors to 17")

    print("✓ Damage scaling rounds down (floor)")
end

--===========================================================================
-- TEST: Boss Tag Preservation
--===========================================================================

function test.test_boss_tag_preserved()
    print("\n=== Test: Boss Tag Preserved ===")

    local boss_def = make_enemy_def("lich_king", 500, 50, 80, {"boss", "undead"})
    local snapshot = enemy_factory.create_snapshot(boss_def, 1, 10, {}, 100, 200)

    test.assert_true(enemy_factory.is_boss(snapshot), "Boss tag should be detected")
    test.assert_eq(#snapshot.tags, 2, "Should have 2 tags")

    -- Verify tags are copied, not referenced
    local has_boss = false
    local has_undead = false
    for _, tag in ipairs(snapshot.tags) do
        if tag == "boss" then has_boss = true end
        if tag == "undead" then has_undead = true end
    end
    test.assert_true(has_boss, "Boss tag should be present")
    test.assert_true(has_undead, "Undead tag should be present")

    print("✓ Boss and other tags preserved")
end

function test.test_non_boss_detection()
    print("\n=== Test: Non-Boss Detection ===")

    local minion_def = make_enemy_def("skeleton", 50, 10, 150, {"undead"})
    local snapshot = enemy_factory.create_snapshot(minion_def, 1, 1, {}, 0, 0)

    test.assert_false(enemy_factory.is_boss(snapshot), "Non-boss should not be detected as boss")

    print("✓ Non-boss correctly identified")
end

function test.test_no_tags()
    print("\n=== Test: No Tags Handling ===")

    local basic_def = make_enemy_def("goblin", 30, 8, 200, nil)
    local snapshot = enemy_factory.create_snapshot(basic_def, 1, 1, {}, 0, 0)

    test.assert_false(enemy_factory.is_boss(snapshot), "Enemy without tags is not boss")
    test.assert_eq(#snapshot.tags, 0, "Should have empty tags array")

    print("✓ No tags handled correctly")
end

--===========================================================================
-- TEST: Position Setting
--===========================================================================

function test.test_position_set()
    print("\n=== Test: Position Setting ===")

    local enemy_def = make_enemy_def("slime", 40, 5, 100)
    local snapshot = enemy_factory.create_snapshot(enemy_def, 1, 1, {}, 150, 300)

    test.assert_eq(snapshot.x, 150, "X position should be 150")
    test.assert_eq(snapshot.y, 300, "Y position should be 300")

    print("✓ Position set correctly")
end

function test.test_position_default_zero()
    print("\n=== Test: Position Defaults to Zero ===")

    local enemy_def = make_enemy_def("bat", 20, 3, 250)
    local snapshot = enemy_factory.create_snapshot(enemy_def, 1, 1, {}, nil, nil)

    test.assert_eq(snapshot.x, 0, "X should default to 0")
    test.assert_eq(snapshot.y, 0, "Y should default to 0")

    print("✓ Position defaults to (0, 0)")
end

function test.test_position_negative()
    print("\n=== Test: Negative Position ===")

    local enemy_def = make_enemy_def("ghost", 60, 12, 180)
    local snapshot = enemy_factory.create_snapshot(enemy_def, 1, 1, {}, -100, -50)

    test.assert_eq(snapshot.x, -100, "Negative X should be preserved")
    test.assert_eq(snapshot.y, -50, "Negative Y should be preserved")

    print("✓ Negative positions preserved")
end

--===========================================================================
-- TEST: Snapshot Creation
--===========================================================================

function test.test_snapshot_metadata()
    print("\n=== Test: Snapshot Metadata ===")

    local enemy_def = make_enemy_def("troll", 200, 30, 80)
    local snapshot = enemy_factory.create_snapshot(enemy_def, 42, 15, {}, 500, 600)

    test.assert_eq(snapshot.enemy_id, 42, "Enemy ID should be 42")
    test.assert_eq(snapshot.def_id, "troll", "Def ID should be 'troll'")
    test.assert_eq(snapshot.type, "troll", "Type should be 'troll'")
    test.assert_eq(snapshot.wave_num, 15, "Wave number should be 15")
    test.assert_eq(snapshot.speed, 80, "Speed should be preserved")
    test.assert_true(snapshot.is_alive, "Should be alive initially")

    print("✓ Snapshot metadata correct")
end

function test.test_snapshot_scaled_stats()
    print("\n=== Test: Snapshot Scaled Stats ===")

    local enemy_def = make_enemy_def("ogre", 100, 20, 60)
    local snapshot = enemy_factory.create_snapshot(enemy_def, 1, 10, {}, 0, 0)

    -- Wave 10: hp = 100 * 2.0 = 200, damage = 20 * 1.5 = 30
    test.assert_eq(snapshot.hp, 200, "HP should be scaled (100 * 2.0 = 200)")
    test.assert_eq(snapshot.max_hp, 200, "Max HP should match HP")
    test.assert_eq(snapshot.damage, 30, "Damage should be scaled (20 * 1.5 = 30)")

    print("✓ Snapshot stats correctly scaled")
end

--===========================================================================
-- TEST: Edge Cases
--===========================================================================

function test.test_nil_wave()
    print("\n=== Test: Nil Wave Handling ===")

    -- scale_hp and scale_damage should handle nil wave
    test.assert_eq(enemy_factory.scale_hp(100, nil), 100, "Nil wave should return base HP")
    test.assert_eq(enemy_factory.scale_damage(20, nil), 20, "Nil wave should return base damage")

    print("✓ Nil wave handled correctly")
end

function test.test_hp_mult_nil()
    print("\n=== Test: hp_mult Nil Handling ===")

    test.assert_eq(enemy_factory.hp_mult(nil), 1.0, "Nil wave should return 1.0 multiplier")

    print("✓ hp_mult nil handling correct")
end

function test.test_large_wave_numbers()
    print("\n=== Test: Large Wave Numbers ===")

    -- Wave 100: hp_mult = 1 + 100*0.1 = 11.0, dmg_mult = 1 + 100*0.05 = 6.0
    test.assert_near(enemy_factory.hp_mult(100), 11.0, 0.001, "Wave 100 HP mult = 11.0")
    test.assert_near(enemy_factory.dmg_mult(100), 6.0, 0.001, "Wave 100 dmg mult = 6.0")

    -- Scaled stats
    test.assert_eq(enemy_factory.scale_hp(100, 100), 1100, "100 HP at wave 100 = 1100")
    test.assert_eq(enemy_factory.scale_damage(10, 100), 60, "10 damage at wave 100 = 60")

    print("✓ Large wave numbers handled")
end

--===========================================================================
-- RUN ALL TESTS
--===========================================================================

function test.run_all()
    print("================================================================================")
    print("TEST SUITE: Enemy Factory (bd-2ab)")
    print("================================================================================")

    -- HP scaling tests
    test.test_hp_mult_formula()
    test.test_scale_hp_basic()
    test.test_scale_hp_rounding()

    -- Damage scaling tests
    test.test_dmg_mult_formula()
    test.test_scale_damage_basic()
    test.test_scale_damage_rounding()

    -- Boss tag tests
    test.test_boss_tag_preserved()
    test.test_non_boss_detection()
    test.test_no_tags()

    -- Position tests
    test.test_position_set()
    test.test_position_default_zero()
    test.test_position_negative()

    -- Snapshot tests
    test.test_snapshot_metadata()
    test.test_snapshot_scaled_stats()

    -- Edge cases
    test.test_nil_wave()
    test.test_hp_mult_nil()
    test.test_large_wave_numbers()

    print("\n================================================================================")
    print(string.format("RESULTS: %d passed, %d failed", test.passed, test.failed))
    print("================================================================================")

    return test.failed == 0
end

-- Execute tests if run directly
if arg and arg[0] and arg[0]:match("test_enemy_factory") then
    local success = test.run_all()
    os.exit(success and 0 or 1)
end

return test
