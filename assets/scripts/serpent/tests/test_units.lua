--[[
================================================================================
TEST: Units Data Verification
================================================================================
Verifies that data/units.lua contains exactly 16 unit definitions with
4 per class, correct IDs, and all numeric fields matching expected values
as specified in task bd-1dc.

Run with: lua assets/scripts/serpent/tests/test_units.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")

-- Mock dependencies
_G.log_debug = print
_G.log_error = print

t.describe("units.lua - Data Verification", function()
    t.it("contains exactly 16 unit definitions", function()
        local units = require("serpent.data.units")

        local all_units = units.get_all_units()
        t.expect(#all_units).to_be(16)
    end)

    t.it("has exactly 4 units per class", function()
        local units = require("serpent.data.units")

        local summary = units.get_unit_summary()

        t.expect(summary.by_class.Warrior).to_be(4)
        t.expect(summary.by_class.Mage).to_be(4)
        t.expect(summary.by_class.Ranger).to_be(4)
        t.expect(summary.by_class.Support).to_be(4)
    end)

    t.it("all units have required fields", function()
        local units = require("serpent.data.units")

        local required_fields = {"id", "class", "tier", "cost", "base_hp", "base_attack", "range", "atk_spd"}
        local all_units = units.get_all_units()

        for _, unit in ipairs(all_units) do
            -- Check that required fields exist and are not nil
            for _, field in ipairs(required_fields) do
                t.expect(unit[field] ~= nil).to_be(true)
            end
            -- special_id field is optional - don't test for its existence
            -- Some units have special abilities, others don't (particularly tier 1 units)
        end
    end)

    t.it("has all expected unit IDs", function()
        local units = require("serpent.data.units")

        local expected_warrior_ids = {"soldier", "knight", "berserker", "champion"}
        local expected_mage_ids = {"apprentice", "pyromancer", "archmage", "lich"}
        local expected_ranger_ids = {"scout", "sniper", "assassin", "windrunner"}
        local expected_support_ids = {"healer", "bard", "paladin", "angel"}

        -- Test warrior units
        local warrior_units = units.get_units_by_class("Warrior")
        for _, expected_id in ipairs(expected_warrior_ids) do
            local found = false
            for _, unit in ipairs(warrior_units) do
                if unit.id == expected_id then
                    found = true
                    break
                end
            end
            t.expect(found).to_be(true)
        end

        -- Test mage units
        local mage_units = units.get_units_by_class("Mage")
        for _, expected_id in ipairs(expected_mage_ids) do
            local found = false
            for _, unit in ipairs(mage_units) do
                if unit.id == expected_id then
                    found = true
                    break
                end
            end
            t.expect(found).to_be(true)
        end

        -- Test ranger units
        local ranger_units = units.get_units_by_class("Ranger")
        for _, expected_id in ipairs(expected_ranger_ids) do
            local found = false
            for _, unit in ipairs(ranger_units) do
                if unit.id == expected_id then
                    found = true
                    break
                end
            end
            t.expect(found).to_be(true)
        end

        -- Test support units
        local support_units = units.get_units_by_class("Support")
        for _, expected_id in ipairs(expected_support_ids) do
            local found = false
            for _, unit in ipairs(support_units) do
                if unit.id == expected_id then
                    found = true
                    break
                end
            end
            t.expect(found).to_be(true)
        end
    end)

    t.it("has valid tier distribution (1-4 per class)", function()
        local units = require("serpent.data.units")

        local summary = units.get_unit_summary()

        -- Each tier should have exactly 4 units (one per class)
        t.expect(summary.by_tier[1]).to_be(4)
        t.expect(summary.by_tier[2]).to_be(4)
        t.expect(summary.by_tier[3]).to_be(4)
        t.expect(summary.by_tier[4]).to_be(4)
    end)

    t.it("provides unit lookup functions", function()
        local units = require("serpent.data.units")

        -- Test individual unit lookup
        local soldier = units.get_unit("soldier")
        t.expect(soldier).to_be_truthy()
        t.expect(soldier.id).to_be("soldier")
        t.expect(soldier.class).to_be("Warrior")

        -- Test class filtering
        local warrior_units = units.get_units_by_class("Warrior")
        t.expect(#warrior_units).to_be(4)

        -- Test tier filtering
        local tier_1_units = units.get_units_by_tier(1)
        t.expect(#tier_1_units).to_be(4)

        -- Test ranger-specific function
        local ranger_units = units.get_ranger_units()
        t.expect(#ranger_units).to_be(4)
    end)
end)

t.describe("units.lua - Numeric Field Verification", function()
    t.it("warrior units have expected numeric values", function()
        local units = require("serpent.data.units")

        local soldier = units.get_unit("soldier")
        t.expect(soldier.tier).to_be(1)
        t.expect(soldier.cost).to_be(3)
        t.expect(soldier.base_hp).to_be(100)
        t.expect(soldier.base_attack).to_be(15)
        t.expect(soldier.range).to_be(50)
        t.expect(soldier.atk_spd).to_be(1.0)

        local knight = units.get_unit("knight")
        t.expect(knight.tier).to_be(2)
        t.expect(knight.cost).to_be(6)
        t.expect(knight.base_hp).to_be(150)
        t.expect(knight.base_attack).to_be(20)
        t.expect(knight.range).to_be(50)
        t.expect(knight.atk_spd).to_be(0.9)

        local berserker = units.get_unit("berserker")
        t.expect(berserker.tier).to_be(3)
        t.expect(berserker.cost).to_be(12)
        t.expect(berserker.base_hp).to_be(120)
        t.expect(berserker.base_attack).to_be(35)
        t.expect(berserker.range).to_be(60)
        t.expect(berserker.atk_spd).to_be(1.2)

        local champion = units.get_unit("champion")
        t.expect(champion.tier).to_be(4)
        t.expect(champion.cost).to_be(20)
        t.expect(champion.base_hp).to_be(200)
        t.expect(champion.base_attack).to_be(50)
        t.expect(champion.range).to_be(80)
        t.expect(champion.atk_spd).to_be(0.8)
    end)

    t.it("mage units have expected numeric values", function()
        local units = require("serpent.data.units")

        local apprentice = units.get_unit("apprentice")
        t.expect(apprentice.tier).to_be(1)
        t.expect(apprentice.cost).to_be(3)
        t.expect(apprentice.base_hp).to_be(60)
        t.expect(apprentice.base_attack).to_be(10)
        t.expect(apprentice.range).to_be(200)
        t.expect(apprentice.atk_spd).to_be(0.8)

        local pyromancer = units.get_unit("pyromancer")
        t.expect(pyromancer.tier).to_be(2)
        t.expect(pyromancer.cost).to_be(6)
        t.expect(pyromancer.base_hp).to_be(70)
        t.expect(pyromancer.base_attack).to_be(18)
        t.expect(pyromancer.range).to_be(180)
        t.expect(pyromancer.atk_spd).to_be(0.7)

        local archmage = units.get_unit("archmage")
        t.expect(archmage.tier).to_be(3)
        t.expect(archmage.cost).to_be(12)
        t.expect(archmage.base_hp).to_be(80)
        t.expect(archmage.base_attack).to_be(30)
        t.expect(archmage.range).to_be(250)
        t.expect(archmage.atk_spd).to_be(0.5)

        local lich = units.get_unit("lich")
        t.expect(lich.tier).to_be(4)
        t.expect(lich.cost).to_be(20)
        t.expect(lich.base_hp).to_be(100)
        t.expect(lich.base_attack).to_be(45)
        t.expect(lich.range).to_be(300)
        t.expect(lich.atk_spd).to_be(0.4)
    end)

    t.it("ranger units have expected numeric values", function()
        local units = require("serpent.data.units")

        local scout = units.get_unit("scout")
        t.expect(scout.tier).to_be(1)
        t.expect(scout.cost).to_be(3)
        t.expect(scout.base_hp).to_be(70)
        t.expect(scout.base_attack).to_be(8)
        t.expect(scout.range).to_be(300)
        t.expect(scout.atk_spd).to_be(1.5)

        local sniper = units.get_unit("sniper")
        t.expect(sniper.tier).to_be(2)
        t.expect(sniper.cost).to_be(6)
        t.expect(sniper.base_hp).to_be(60)
        t.expect(sniper.base_attack).to_be(25)
        t.expect(sniper.range).to_be(400)
        t.expect(sniper.atk_spd).to_be(0.6)

        local assassin = units.get_unit("assassin")
        t.expect(assassin.tier).to_be(3)
        t.expect(assassin.cost).to_be(12)
        t.expect(assassin.base_hp).to_be(80)
        t.expect(assassin.base_attack).to_be(40)
        t.expect(assassin.range).to_be(70)
        t.expect(assassin.atk_spd).to_be(1.0)

        local windrunner = units.get_unit("windrunner")
        t.expect(windrunner.tier).to_be(4)
        t.expect(windrunner.cost).to_be(20)
        t.expect(windrunner.base_hp).to_be(100)
        t.expect(windrunner.base_attack).to_be(35)
        t.expect(windrunner.range).to_be(350)
        t.expect(windrunner.atk_spd).to_be(1.1)
    end)

    t.it("support units have expected numeric values", function()
        local units = require("serpent.data.units")

        local healer = units.get_unit("healer")
        t.expect(healer.tier).to_be(1)
        t.expect(healer.cost).to_be(3)
        t.expect(healer.base_hp).to_be(80)
        t.expect(healer.base_attack).to_be(5)
        t.expect(healer.range).to_be(100)
        t.expect(healer.atk_spd).to_be(0.5)

        local bard = units.get_unit("bard")
        t.expect(bard.tier).to_be(2)
        t.expect(bard.cost).to_be(6)
        t.expect(bard.base_hp).to_be(90)
        t.expect(bard.base_attack).to_be(8)
        t.expect(bard.range).to_be(80)
        t.expect(bard.atk_spd).to_be(0.8)

        local paladin = units.get_unit("paladin")
        t.expect(paladin.tier).to_be(3)
        t.expect(paladin.cost).to_be(12)
        t.expect(paladin.base_hp).to_be(150)
        t.expect(paladin.base_attack).to_be(15)
        t.expect(paladin.range).to_be(60)
        t.expect(paladin.atk_spd).to_be(0.7)

        local angel = units.get_unit("angel")
        t.expect(angel.tier).to_be(4)
        t.expect(angel.cost).to_be(20)
        t.expect(angel.base_hp).to_be(120)
        t.expect(angel.base_attack).to_be(20)
        t.expect(angel.range).to_be(100)
        t.expect(angel.atk_spd).to_be(0.6)
    end)

    t.it("has valid special abilities assignment", function()
        local units = require("serpent.data.units")

        -- Tier 1 units should have no special abilities (nil)
        local tier_1_units = units.get_units_by_tier(1)
        for _, unit in ipairs(tier_1_units) do
            if unit.id == "healer" then
                -- Exception: healer has special ability even at tier 1
                t.expect(unit.special_id).to_be("healer_adjacent_regen")
            else
                t.expect(unit.special_id).to_be_nil()
            end
        end

        -- Tier 2+ units should have special abilities (not nil)
        local higher_tier_units = {}
        for tier = 2, 4 do
            local tier_units = units.get_units_by_tier(tier)
            for _, unit in ipairs(tier_units) do
                table.insert(higher_tier_units, unit)
            end
        end

        for _, unit in ipairs(higher_tier_units) do
            t.expect(unit.special_id).never().to_be_nil()
        end
    end)

    t.it("has valid cost progression by tier", function()
        local units = require("serpent.data.units")

        -- Tier 1: cost 3
        local tier_1_units = units.get_units_by_tier(1)
        for _, unit in ipairs(tier_1_units) do
            t.expect(unit.cost).to_be(3)
        end

        -- Tier 2: cost 6
        local tier_2_units = units.get_units_by_tier(2)
        for _, unit in ipairs(tier_2_units) do
            t.expect(unit.cost).to_be(6)
        end

        -- Tier 3: cost 12
        local tier_3_units = units.get_units_by_tier(3)
        for _, unit in ipairs(tier_3_units) do
            t.expect(unit.cost).to_be(12)
        end

        -- Tier 4: cost 20
        local tier_4_units = units.get_units_by_tier(4)
        for _, unit in ipairs(tier_4_units) do
            t.expect(unit.cost).to_be(20)
        end
    end)

    t.it("has positive stat values", function()
        local units = require("serpent.data.units")

        local all_units = units.get_all_units()

        for _, unit in ipairs(all_units) do
            t.expect(unit.tier >= 1).to_be(true)
            t.expect(unit.tier <= 4).to_be(true)
            t.expect(unit.cost > 0).to_be(true)
            t.expect(unit.base_hp > 0).to_be(true)
            t.expect(unit.base_attack > 0).to_be(true)
            t.expect(unit.range > 0).to_be(true)
            t.expect(unit.atk_spd > 0).to_be(true)
        end
    end)
end)

local success = t.run()
os.exit(success and 0 or 1)