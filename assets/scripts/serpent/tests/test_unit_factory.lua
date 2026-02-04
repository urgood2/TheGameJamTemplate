--[[
================================================================================
TEST: Unit Factory Stat Scaling
================================================================================
Verifies that unit_factory.lua correctly implements:
- Stat scaling with formula: base * 2^(level-1)
- Level capping at level 3
- Unit instance creation with proper field mapping

Tests the core unit progression mechanics as specified in PLAN.md.

Run with: lua assets/scripts/serpent/tests/test_unit_factory.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")

-- Mock dependencies
_G.log_debug = function(msg) end
_G.log_warning = function(msg) end

t.describe("unit_factory.lua - Stat Scaling", function()
    t.it("applies correct 2^(level-1) scaling formula", function()
        local unit_factory = require("serpent.unit_factory")

        local test_unit = {
            id = "test_soldier",
            base_hp = 100,
            base_attack = 20
        }

        -- Test level 1: 2^(1-1) = 2^0 = 1 (no scaling)
        local scaled_1 = unit_factory.apply_level_scaling(test_unit, 1)
        t.expect(scaled_1.hp_max_base_int).to_be(100) -- 100 * 1 = 100
        t.expect(scaled_1.attack_base_int).to_be(20)   -- 20 * 1 = 20

        -- Test level 2: 2^(2-1) = 2^1 = 2 (double)
        local scaled_2 = unit_factory.apply_level_scaling(test_unit, 2)
        t.expect(scaled_2.hp_max_base_int).to_be(200) -- 100 * 2 = 200
        t.expect(scaled_2.attack_base_int).to_be(40)   -- 20 * 2 = 40

        -- Test level 3: 2^(3-1) = 2^2 = 4 (quadruple)
        local scaled_3 = unit_factory.apply_level_scaling(test_unit, 3)
        t.expect(scaled_3.hp_max_base_int).to_be(400) -- 100 * 4 = 400
        t.expect(scaled_3.attack_base_int).to_be(80)   -- 20 * 4 = 80
    end)

    t.it("caps level at 3 maximum", function()
        local unit_factory = require("serpent.unit_factory")

        local test_unit = {
            id = "test_knight",
            base_hp = 150,
            base_attack = 25
        }

        -- Test level 4 should be capped to level 3
        local scaled_4 = unit_factory.apply_level_scaling(test_unit, 4)
        t.expect(scaled_4.hp_max_base_int).to_be(600) -- 150 * 4 (level 3)
        t.expect(scaled_4.attack_base_int).to_be(100) -- 25 * 4 (level 3)

        -- Test level 5 should also be capped to level 3
        local scaled_5 = unit_factory.apply_level_scaling(test_unit, 5)
        t.expect(scaled_5.hp_max_base_int).to_be(600) -- 150 * 4 (level 3)
        t.expect(scaled_5.attack_base_int).to_be(100) -- 25 * 4 (level 3)

        -- Test very high level should still be capped
        local scaled_10 = unit_factory.apply_level_scaling(test_unit, 10)
        t.expect(scaled_10.hp_max_base_int).to_be(600) -- 150 * 4 (level 3)
        t.expect(scaled_10.attack_base_int).to_be(100) -- 25 * 4 (level 3)
    end)

    t.it("clamps level to minimum 1", function()
        local unit_factory = require("serpent.unit_factory")

        local test_unit = {
            id = "test_mage",
            base_hp = 60,
            base_attack = 15
        }

        -- Test level 0 should be clamped to level 1
        local scaled_0 = unit_factory.apply_level_scaling(test_unit, 0)
        t.expect(scaled_0.hp_max_base_int).to_be(60)  -- 60 * 1 (level 1)
        t.expect(scaled_0.attack_base_int).to_be(15)  -- 15 * 1 (level 1)

        -- Test negative level should be clamped to level 1
        local scaled_neg = unit_factory.apply_level_scaling(test_unit, -1)
        t.expect(scaled_neg.hp_max_base_int).to_be(60)  -- 60 * 1 (level 1)
        t.expect(scaled_neg.attack_base_int).to_be(15)  -- 15 * 1 (level 1)
    end)

    t.it("handles fractional levels correctly", function()
        local unit_factory = require("serpent.unit_factory")

        local test_unit = {
            id = "test_ranger",
            base_hp = 80,
            base_attack = 30
        }

        -- Test level 1.5 should be floored to level 1
        local scaled_1_5 = unit_factory.apply_level_scaling(test_unit, 1.5)
        t.expect(scaled_1_5.hp_max_base_int).to_be(80)  -- 80 * 1 (level 1)
        t.expect(scaled_1_5.attack_base_int).to_be(30)  -- 30 * 1 (level 1)

        -- Test level 2.9 should be floored to level 2
        local scaled_2_9 = unit_factory.apply_level_scaling(test_unit, 2.9)
        t.expect(scaled_2_9.hp_max_base_int).to_be(160) -- 80 * 2 (level 2)
        t.expect(scaled_2_9.attack_base_int).to_be(60)  -- 30 * 2 (level 2)
    end)

    t.it("handles edge case values", function()
        local unit_factory = require("serpent.unit_factory")

        -- Test unit with base stats of 1
        local minimal_unit = {
            id = "test_minimal",
            base_hp = 1,
            base_attack = 1
        }

        local scaled = unit_factory.apply_level_scaling(minimal_unit, 3)
        t.expect(scaled.hp_max_base_int).to_be(4)  -- 1 * 4 (level 3)
        t.expect(scaled.attack_base_int).to_be(4)  -- 1 * 4 (level 3)

        -- Test unit with large base stats
        local big_unit = {
            id = "test_big",
            base_hp = 500,
            base_attack = 100
        }

        local scaled_big = unit_factory.apply_level_scaling(big_unit, 3)
        t.expect(scaled_big.hp_max_base_int).to_be(2000) -- 500 * 4 (level 3)
        t.expect(scaled_big.attack_base_int).to_be(400)  -- 100 * 4 (level 3)
    end)

    t.it("returns integer values", function()
        local unit_factory = require("serpent.unit_factory")

        -- Test with odd base stats to ensure proper flooring
        local odd_unit = {
            id = "test_odd",
            base_hp = 33,  -- 33 * 2 = 66
            base_attack = 7  -- 7 * 4 = 28 at level 3
        }

        local scaled = unit_factory.apply_level_scaling(odd_unit, 2)
        t.expect(scaled.hp_max_base_int).to_be(66)
        t.expect(scaled.attack_base_int).to_be(14)

        -- Verify return values are integers
        t.expect(scaled.hp_max_base_int).to_be(math.floor(scaled.hp_max_base_int))
        t.expect(scaled.attack_base_int).to_be(math.floor(scaled.attack_base_int))
    end)
end)

t.describe("unit_factory.lua - Instance Creation", function()
    t.it("creates level 1 instances with correct fields", function()
        local unit_factory = require("serpent.unit_factory")

        local test_unit = {
            id = "soldier",
            base_hp = 100,
            base_attack = 15,
            range = 50,
            atk_spd = 1.0
        }

        local instance = unit_factory.create_instance(test_unit, 123, 5)

        -- Check identity fields
        t.expect(instance.instance_id).to_be(123)
        t.expect(instance.def_id).to_be("soldier")
        t.expect(instance.level).to_be(1)
        t.expect(instance.acquired_seq).to_be(5)

        -- Check scaled stats (level 1, no scaling)
        t.expect(instance.hp).to_be(100)
        t.expect(instance.hp_max_base).to_be(100)
        t.expect(instance.attack_base).to_be(15)

        -- Check unscaled properties
        t.expect(instance.range_base).to_be(50)
        t.expect(instance.atk_spd_base).to_be(1.0)

        -- Check initial state
        t.expect(instance.cooldown).to_be(0)
        t.expect(type(instance.special_state)).to_be("table")
    end)

    t.it("handles nil unit definition gracefully", function()
        local unit_factory = require("serpent.unit_factory")

        local instance = unit_factory.create_instance(nil, 456, 10)

        -- Should create instance with default/zero values
        t.expect(instance.instance_id).to_be(456)
        t.expect(instance.def_id).to_be_nil()
        t.expect(instance.level).to_be(1)
        t.expect(instance.acquired_seq).to_be(10)

        -- Stats should default to 0
        t.expect(instance.hp).to_be(0)
        t.expect(instance.hp_max_base).to_be(0)
        t.expect(instance.attack_base).to_be(0)
        t.expect(instance.range_base).to_be(0)
        t.expect(instance.atk_spd_base).to_be(0)
    end)

    t.it("handles missing unit definition fields", function()
        local unit_factory = require("serpent.unit_factory")

        local incomplete_unit = {
            id = "incomplete",
            base_hp = 75
            -- Missing base_attack, range, atk_spd
        }

        local instance = unit_factory.create_instance(incomplete_unit, 789, 15)

        t.expect(instance.instance_id).to_be(789)
        t.expect(instance.def_id).to_be("incomplete")
        t.expect(instance.hp).to_be(75)
        t.expect(instance.hp_max_base).to_be(75)

        -- Missing fields should default to 0
        t.expect(instance.attack_base).to_be(0)
        t.expect(instance.range_base).to_be(0)
        t.expect(instance.atk_spd_base).to_be(0)
    end)

    t.it("always creates level 1 instances", function()
        local unit_factory = require("serpent.unit_factory")

        local test_unit = {
            id = "always_level_1",
            base_hp = 200,
            base_attack = 40
        }

        local instance = unit_factory.create_instance(test_unit, 999, 20)

        -- Should always be level 1 regardless of base stats
        t.expect(instance.level).to_be(1)

        -- Stats should not be scaled (level 1 = 1x multiplier)
        t.expect(instance.hp).to_be(200)
        t.expect(instance.hp_max_base).to_be(200)
        t.expect(instance.attack_base).to_be(40)
    end)
end)

t.describe("unit_factory.lua - Real Unit Integration", function()
    t.it("correctly scales real unit definitions", function()
        local unit_factory = require("serpent.unit_factory")
        local units_module = require("serpent.data.units")

        -- Get a real unit definition
        local soldier = units_module.get_unit("soldier")
        t.expect(soldier).to_be_truthy()

        -- Test scaling progression
        local level_1 = unit_factory.apply_level_scaling(soldier, 1)
        local level_2 = unit_factory.apply_level_scaling(soldier, 2)
        local level_3 = unit_factory.apply_level_scaling(soldier, 3)

        -- Soldier has base_hp = 100, base_attack = 15
        t.expect(level_1.hp_max_base_int).to_be(100)  -- 100 * 1
        t.expect(level_1.attack_base_int).to_be(15)   -- 15 * 1

        t.expect(level_2.hp_max_base_int).to_be(200)  -- 100 * 2
        t.expect(level_2.attack_base_int).to_be(30)   -- 15 * 2

        t.expect(level_3.hp_max_base_int).to_be(400)  -- 100 * 4
        t.expect(level_3.attack_base_int).to_be(60)   -- 15 * 4
    end)

    t.it("creates proper instances from real unit definitions", function()
        local unit_factory = require("serpent.unit_factory")
        local units_module = require("serpent.data.units")

        -- Test with knight unit
        local knight = units_module.get_unit("knight")
        t.expect(knight).to_be_truthy()

        local knight_instance = unit_factory.create_instance(knight, 1001, 25)

        t.expect(knight_instance.def_id).to_be("knight")
        t.expect(knight_instance.level).to_be(1)
        t.expect(knight_instance.instance_id).to_be(1001)
        t.expect(knight_instance.acquired_seq).to_be(25)

        -- Knight has base_hp = 150, base_attack = 20, range = 50, atk_spd = 0.9
        t.expect(knight_instance.hp_max_base).to_be(150)
        t.expect(knight_instance.attack_base).to_be(20)
        t.expect(knight_instance.range_base).to_be(50)
        t.expect(knight_instance.atk_spd_base).to_be(0.9)
    end)
end)

t.describe("unit_factory.lua - Edge Cases and Error Handling", function()
    t.it("handles non-numeric level values", function()
        local unit_factory = require("serpent.unit_factory")

        local test_unit = {
            id = "test",
            base_hp = 50,
            base_attack = 10
        }

        -- Test string level
        local scaled_str = unit_factory.apply_level_scaling(test_unit, "2")
        t.expect(scaled_str.hp_max_base_int).to_be(100) -- Should parse "2" as level 2

        -- Test nil level
        local scaled_nil = unit_factory.apply_level_scaling(test_unit, nil)
        t.expect(scaled_nil.hp_max_base_int).to_be(50)  -- Should default to level 1

        -- Test invalid string level
        local scaled_invalid = unit_factory.apply_level_scaling(test_unit, "invalid")
        t.expect(scaled_invalid.hp_max_base_int).to_be(50)  -- Should default to level 1
    end)

    t.it("handles non-numeric base stat values", function()
        local unit_factory = require("serpent.unit_factory")

        local invalid_unit = {
            id = "invalid",
            base_hp = "not_a_number",
            base_attack = nil
        }

        local scaled = unit_factory.apply_level_scaling(invalid_unit, 2)

        -- Should default to 0 and scale properly
        t.expect(scaled.hp_max_base_int).to_be(0)  -- 0 * 2 = 0
        t.expect(scaled.attack_base_int).to_be(0)  -- 0 * 2 = 0
    end)

    t.it("maintains precision with large numbers", function()
        local unit_factory = require("serpent.unit_factory")

        local large_unit = {
            id = "large",
            base_hp = 999999,
            base_attack = 100000
        }

        local scaled = unit_factory.apply_level_scaling(large_unit, 3)

        -- Level 3 multiplier is 4
        t.expect(scaled.hp_max_base_int).to_be(3999996)  -- 999999 * 4
        t.expect(scaled.attack_base_int).to_be(400000)   -- 100000 * 4

        -- Should still be integers
        t.expect(scaled.hp_max_base_int).to_be(math.floor(scaled.hp_max_base_int))
        t.expect(scaled.attack_base_int).to_be(math.floor(scaled.attack_base_int))
    end)
end)

local success = t.run()
os.exit(success and 0 or 1)