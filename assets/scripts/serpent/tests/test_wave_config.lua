--[[
================================================================================
TEST: Wave Configuration Module
================================================================================
Verifies that wave_config.lua correctly implements:
- Enemy count formula: 5 + Wave * 2
- HP multiplier formula: 1 + Wave * 0.1
- Damage multiplier formula: 1 + Wave * 0.05
- Gold reward formula: 10 + Wave * 2
- Enemy pool selection based on wave brackets
- Wave validation (1-20 range)

Tests core wave progression mechanics as specified in PLAN.md.

Run with: lua assets/scripts/serpent/tests/test_wave_config.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")

-- Mock dependencies
_G.log_debug = function(msg) end
_G.log_warning = function(msg) end
_G.log_error = function(msg) end

t.describe("wave_config.lua - Formula Verification", function()
    t.it("calculates enemy count correctly (5 + Wave * 2)", function()
        local wave_config = require("serpent.wave_config")

        -- Test specific values from PLAN.md
        t.expect(wave_config.enemy_count(1)).to_be(7)   -- 5 + 1*2 = 7
        t.expect(wave_config.enemy_count(5)).to_be(15)  -- 5 + 5*2 = 15
        t.expect(wave_config.enemy_count(10)).to_be(25) -- 5 + 10*2 = 25
        t.expect(wave_config.enemy_count(15)).to_be(35) -- 5 + 15*2 = 35
        t.expect(wave_config.enemy_count(20)).to_be(45) -- 5 + 20*2 = 45

        -- Test edge cases
        t.expect(wave_config.enemy_count(2)).to_be(9)   -- 5 + 2*2 = 9
        t.expect(wave_config.enemy_count(3)).to_be(11)  -- 5 + 3*2 = 11
    end)

    t.it("calculates HP multiplier correctly (1 + Wave * 0.1)", function()
        local wave_config = require("serpent.wave_config")

        -- Test specific values
        t.expect(wave_config.hp_mult(1)).to_be(1.1)   -- 1 + 1*0.1 = 1.1
        t.expect(wave_config.hp_mult(5)).to_be(1.5)   -- 1 + 5*0.1 = 1.5
        t.expect(wave_config.hp_mult(10)).to_be(2.0)  -- 1 + 10*0.1 = 2.0
        t.expect(wave_config.hp_mult(15)).to_be(2.5)  -- 1 + 15*0.1 = 2.5
        t.expect(wave_config.hp_mult(20)).to_be(3.0)  -- 1 + 20*0.1 = 3.0

        -- Test intermediate values
        t.expect(wave_config.hp_mult(3)).to_be(1.3)   -- 1 + 3*0.1 = 1.3
        t.expect(wave_config.hp_mult(8)).to_be(1.8)   -- 1 + 8*0.1 = 1.8
    end)

    t.it("calculates damage multiplier correctly (1 + Wave * 0.05)", function()
        local wave_config = require("serpent.wave_config")

        -- Test specific values
        t.expect(wave_config.dmg_mult(1)).to_be(1.05)  -- 1 + 1*0.05 = 1.05
        t.expect(wave_config.dmg_mult(5)).to_be(1.25)  -- 1 + 5*0.05 = 1.25
        t.expect(wave_config.dmg_mult(10)).to_be(1.5)  -- 1 + 10*0.05 = 1.5
        t.expect(wave_config.dmg_mult(15)).to_be(1.75) -- 1 + 15*0.05 = 1.75
        t.expect(wave_config.dmg_mult(20)).to_be(2.0)  -- 1 + 20*0.05 = 2.0

        -- Test intermediate values
        t.expect(wave_config.dmg_mult(2)).to_be(1.1)   -- 1 + 2*0.05 = 1.1
        t.expect(wave_config.dmg_mult(4)).to_be(1.2)   -- 1 + 4*0.05 = 1.2
    end)

    t.it("calculates gold reward correctly (10 + Wave * 2)", function()
        local wave_config = require("serpent.wave_config")

        -- Test specific values
        t.expect(wave_config.gold_reward(1)).to_be(12)  -- 10 + 1*2 = 12
        t.expect(wave_config.gold_reward(5)).to_be(20)  -- 10 + 5*2 = 20
        t.expect(wave_config.gold_reward(10)).to_be(30) -- 10 + 10*2 = 30
        t.expect(wave_config.gold_reward(15)).to_be(40) -- 10 + 15*2 = 40
        t.expect(wave_config.gold_reward(20)).to_be(50) -- 10 + 20*2 = 50

        -- Test intermediate values
        t.expect(wave_config.gold_reward(3)).to_be(16)  -- 10 + 3*2 = 16
        t.expect(wave_config.gold_reward(7)).to_be(24)  -- 10 + 7*2 = 24
    end)

    t.it("provides built-in formula test", function()
        local wave_config = require("serpent.wave_config")

        -- Test the built-in enemy count formula test
        local formula_test_result = wave_config.test_enemy_count_formula()
        t.expect(formula_test_result).to_be(true)
    end)
end)

t.describe("wave_config.lua - Edge Cases and Validation", function()
    t.it("handles invalid wave numbers gracefully", function()
        local wave_config = require("serpent.wave_config")

        -- Test nil wave
        t.expect(wave_config.enemy_count(nil)).to_be(7)   -- Defaults to wave 1
        t.expect(wave_config.hp_mult(nil)).to_be(1.1)     -- Defaults to wave 1
        t.expect(wave_config.dmg_mult(nil)).to_be(1.05)   -- Defaults to wave 1
        t.expect(wave_config.gold_reward(nil)).to_be(12)  -- Defaults to wave 1

        -- Test zero wave
        t.expect(wave_config.enemy_count(0)).to_be(7)     -- Defaults to wave 1
        t.expect(wave_config.hp_mult(0)).to_be(1.1)       -- Defaults to wave 1

        -- Test negative wave
        t.expect(wave_config.enemy_count(-1)).to_be(7)    -- Defaults to wave 1
        t.expect(wave_config.gold_reward(-5)).to_be(12)   -- Defaults to wave 1
    end)

    t.it("validates wave numbers correctly", function()
        local wave_config = require("serpent.wave_config")

        -- Test valid waves
        local valid1, _ = wave_config.validate_wave(1)
        t.expect(valid1).to_be(true)

        local valid10, _ = wave_config.validate_wave(10)
        t.expect(valid10).to_be(true)

        local valid20, _ = wave_config.validate_wave(20)
        t.expect(valid20).to_be(true)

        -- Test invalid waves
        local invalid_nil, err_nil = wave_config.validate_wave(nil)
        t.expect(invalid_nil).to_be(false)
        t.expect(err_nil).to_be("Wave number is required")

        local invalid_string, err_string = wave_config.validate_wave("5")
        t.expect(invalid_string).to_be(false)
        t.expect(err_string).to_be("Wave number must be a number")

        local invalid_low, err_low = wave_config.validate_wave(0)
        t.expect(invalid_low).to_be(false)
        t.expect(err_low).to_be("Wave number must be between 1 and 20")

        local invalid_high, err_high = wave_config.validate_wave(21)
        t.expect(invalid_high).to_be(false)
        t.expect(err_high).to_be("Wave number must be between 1 and 20")
    end)
end)

t.describe("wave_config.lua - Enemy Pool Selection", function()
    t.it("filters enemies by wave range correctly", function()
        local wave_config = require("serpent.wave_config")

        -- Create test enemy definitions
        local test_enemies = {
            slime = {
                id = "slime",
                min_wave = 1,
                max_wave = 5,
                boss = false
            },
            goblin = {
                id = "goblin",
                min_wave = 3,
                max_wave = 10,
                boss = false
            },
            troll = {
                id = "troll",
                min_wave = 10,
                max_wave = 20,
                boss = false
            },
            boss_enemy = {
                id = "boss_enemy",
                min_wave = 10,
                max_wave = 10,
                boss = true  -- Boss should be excluded
            }
        }

        -- Test wave 1: should include only slime
        local pool_1 = wave_config.get_pool(1, test_enemies)
        t.expect(#pool_1).to_be(1)
        t.expect(pool_1[1]).to_be("slime")

        -- Test wave 5: should include slime and goblin
        local pool_5 = wave_config.get_pool(5, test_enemies)
        t.expect(#pool_5).to_be(2)
        table.sort(pool_5) -- Ensure deterministic ordering
        t.expect(pool_5[1]).to_be("goblin")
        t.expect(pool_5[2]).to_be("slime")

        -- Test wave 10: should include goblin and troll (not boss)
        local pool_10 = wave_config.get_pool(10, test_enemies)
        t.expect(#pool_10).to_be(2)
        table.sort(pool_10)
        t.expect(pool_10[1]).to_be("goblin")
        t.expect(pool_10[2]).to_be("troll")

        -- Test wave 15: should include only troll
        local pool_15 = wave_config.get_pool(15, test_enemies)
        t.expect(#pool_15).to_be(1)
        t.expect(pool_15[1]).to_be("troll")
    end)

    t.it("excludes boss enemies correctly", function()
        local wave_config = require("serpent.wave_config")

        -- Test enemies with different boss marking methods
        local test_enemies = {
            normal_enemy = {
                id = "normal_enemy",
                min_wave = 5,
                max_wave = 15,
                boss = false
            },
            boss_with_flag = {
                id = "boss_with_flag",
                min_wave = 5,
                max_wave = 15,
                boss = true
            },
            boss_with_tags = {
                id = "boss_with_tags",
                min_wave = 5,
                max_wave = 15,
                boss = false,
                tags = {"large", "boss", "dangerous"}
            },
            normal_with_other_tags = {
                id = "normal_with_other_tags",
                min_wave = 5,
                max_wave = 15,
                boss = false,
                tags = {"fast", "weak"}
            }
        }

        local pool = wave_config.get_pool(10, test_enemies)

        -- Should only include normal enemies
        t.expect(#pool).to_be(2)
        table.sort(pool)
        t.expect(pool[1]).to_be("normal_enemy")
        t.expect(pool[2]).to_be("normal_with_other_tags")
    end)

    t.it("handles empty and invalid enemy definitions", function()
        local wave_config = require("serpent.wave_config")

        -- Test with nil enemy_defs
        local empty_pool = wave_config.get_pool(5, nil)
        t.expect(#empty_pool).to_be(0)

        -- Test with empty enemy_defs table
        local empty_pool2 = wave_config.get_pool(5, {})
        t.expect(#empty_pool2).to_be(0)

        -- Test with nil wave
        local empty_pool3 = wave_config.get_pool(nil, {})
        t.expect(#empty_pool3).to_be(0)

        -- Test with invalid enemy definitions (missing wave ranges)
        local invalid_enemies = {
            broken_enemy1 = {
                id = "broken_enemy1"
                -- Missing min_wave, max_wave
            },
            broken_enemy2 = {
                id = "broken_enemy2",
                min_wave = 5
                -- Missing max_wave
            },
            nil_enemy = nil
        }

        local pool_invalid = wave_config.get_pool(5, invalid_enemies)
        t.expect(#pool_invalid).to_be(0)
    end)

    t.it("returns deterministically ordered pools", function()
        local wave_config = require("serpent.wave_config")

        local test_enemies = {
            zebra = { id = "zebra", min_wave = 1, max_wave = 10, boss = false },
            alpha = { id = "alpha", min_wave = 1, max_wave = 10, boss = false },
            beta = { id = "beta", min_wave = 1, max_wave = 10, boss = false }
        }

        local pool1 = wave_config.get_pool(5, test_enemies)
        local pool2 = wave_config.get_pool(5, test_enemies)

        -- Both pools should be identical and sorted
        t.expect(#pool1).to_be(#pool2)
        for i = 1, #pool1 do
            t.expect(pool1[i]).to_be(pool2[i])
        end

        -- Should be sorted alphabetically
        t.expect(pool1[1]).to_be("alpha")
        t.expect(pool1[2]).to_be("beta")
        t.expect(pool1[3]).to_be("zebra")
    end)
end)

t.describe("wave_config.lua - Real Enemy Integration", function()
    t.it("works with real enemy definitions", function()
        local wave_config = require("serpent.wave_config")
        local enemies_module = require("serpent.data.enemies")

        -- Get real enemy definitions
        local enemy_defs = {}
        for _, enemy in ipairs(enemies_module.get_all_enemies()) do
            enemy_defs[enemy.id] = enemy
        end

        -- Test early waves (should have slime, bat)
        local pool_1 = wave_config.get_pool(1, enemy_defs)
        t.expect(#pool_1 > 0).to_be(true)

        -- Pool should include early game enemies
        local has_slime = false
        local has_bat = false
        for _, enemy_id in ipairs(pool_1) do
            if enemy_id == "slime" then has_slime = true end
            if enemy_id == "bat" then has_bat = true end
        end
        t.expect(has_slime).to_be(true)
        t.expect(has_bat).to_be(true)

        -- Test mid-game waves
        local pool_10 = wave_config.get_pool(10, enemy_defs)
        t.expect(#pool_10 > #pool_1).to_be(true) -- More enemies available

        -- Test late game waves
        local pool_20 = wave_config.get_pool(20, enemy_defs)
        t.expect(#pool_20 > 0).to_be(true)

        -- Verify no boss enemies in any pool
        for _, pool in ipairs({pool_1, pool_10, pool_20}) do
            for _, enemy_id in ipairs(pool) do
                local enemy_def = enemy_defs[enemy_id]
                t.expect(enemy_def.boss).to_be(false)
            end
        end
    end)
end)

t.describe("wave_config.lua - Wave Summary and Constants", function()
    t.it("provides comprehensive wave summary", function()
        local wave_config = require("serpent.wave_config")

        local summary = wave_config.get_wave_summary(10)

        t.expect(summary.wave).to_be(10)
        t.expect(summary.enemy_count).to_be(25)   -- 5 + 10*2
        t.expect(summary.hp_mult).to_be(2.0)      -- 1 + 10*0.1
        t.expect(summary.dmg_mult).to_be(1.5)     -- 1 + 10*0.05
        t.expect(summary.gold_reward).to_be(30)   -- 10 + 10*2
    end)

    t.it("provides correct formula constants", function()
        local wave_config = require("serpent.wave_config")

        local constants = wave_config.get_constants()

        -- Enemy count constants
        t.expect(constants.enemy_count.base).to_be(5)
        t.expect(constants.enemy_count.per_wave).to_be(2)

        -- HP multiplier constants
        t.expect(constants.hp_mult.base).to_be(1)
        t.expect(constants.hp_mult.per_wave).to_be(0.1)

        -- Damage multiplier constants
        t.expect(constants.dmg_mult.base).to_be(1)
        t.expect(constants.dmg_mult.per_wave).to_be(0.05)

        -- Gold reward constants
        t.expect(constants.gold_reward.base).to_be(10)
        t.expect(constants.gold_reward.per_wave).to_be(2)
    end)
end)

t.describe("wave_config.lua - PLAN.md Specification Compliance", function()
    t.it("matches PLAN.md wave scaling exactly", function()
        local wave_config = require("serpent.wave_config")

        -- Test the exact examples from PLAN.md
        -- Wave 1: 7 enemies, HP mult 1.1, DMG mult 1.05, 12 gold
        local w1_enemies = wave_config.enemy_count(1)
        local w1_hp = wave_config.hp_mult(1)
        local w1_dmg = wave_config.dmg_mult(1)
        local w1_gold = wave_config.gold_reward(1)

        t.expect(w1_enemies).to_be(7)
        t.expect(w1_hp).to_be(1.1)
        t.expect(w1_dmg).to_be(1.05)
        t.expect(w1_gold).to_be(12)

        -- Wave 20: 45 enemies, HP mult 3.0, DMG mult 2.0, 50 gold
        local w20_enemies = wave_config.enemy_count(20)
        local w20_hp = wave_config.hp_mult(20)
        local w20_dmg = wave_config.dmg_mult(20)
        local w20_gold = wave_config.gold_reward(20)

        t.expect(w20_enemies).to_be(45)
        t.expect(w20_hp).to_be(3.0)
        t.expect(w20_dmg).to_be(2.0)
        t.expect(w20_gold).to_be(50)
    end)

    t.it("provides proper progression curves", function()
        local wave_config = require("serpent.wave_config")

        -- Verify linear progression for enemy count and gold
        for wave = 1, 20 do
            local expected_enemies = 5 + wave * 2
            local expected_gold = 10 + wave * 2

            t.expect(wave_config.enemy_count(wave)).to_be(expected_enemies)
            t.expect(wave_config.gold_reward(wave)).to_be(expected_gold)
        end

        -- Verify multiplier progressions
        for wave = 1, 20 do
            local expected_hp_mult = 1 + wave * 0.1
            local expected_dmg_mult = 1 + wave * 0.05

            t.expect(wave_config.hp_mult(wave)).to_be(expected_hp_mult)
            t.expect(wave_config.dmg_mult(wave)).to_be(expected_dmg_mult)
        end
    end)
end)

local success = t.run()
os.exit(success and 0 or 1)