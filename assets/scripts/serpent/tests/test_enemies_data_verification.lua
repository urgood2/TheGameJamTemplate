--[[
================================================================================
TEST: Enemy Data Verification
================================================================================
Verifies that data/enemies.lua contains exactly 11 enemy definitions with
all required fields as specified in task bd-sdn.

Run with: lua assets/scripts/serpent/tests/test_enemies_data_verification.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")

-- Mock dependencies
_G.log_debug = print
_G.log_error = print

t.describe("enemies.lua - Data Verification", function()
    t.it("contains exactly 11 enemy definitions", function()
        local enemies = require("serpent.data.enemies")

        local all_enemies = enemies.get_all_enemies()
        t.expect(#all_enemies).to_be(11)
    end)

    t.it("all enemies have required fields", function()
        local enemies = require("serpent.data.enemies")

        local required_fields = {"id", "base_hp", "base_damage", "speed", "min_wave", "max_wave", "boss"}
        local all_enemies = enemies.get_all_enemies()

        for _, enemy in ipairs(all_enemies) do
            for _, field in ipairs(required_fields) do
                t.expect(enemy[field]).never().to_be_nil()
            end
        end
    end)

    t.it("passes built-in validation", function()
        local enemies = require("serpent.data.enemies")

        local validation_passed = enemies.test_all_enemies_valid()
        t.expect(validation_passed).to_be(true)
    end)

    t.it("has correct boss enemy flags", function()
        local enemies = require("serpent.data.enemies")

        local swarm_queen = enemies.get_enemy("swarm_queen")
        t.expect(swarm_queen.boss).to_be(true)
        t.expect(swarm_queen.tags).to_be_truthy()

        local lich_king = enemies.get_enemy("lich_king")
        t.expect(lich_king.boss).to_be(true)
        t.expect(lich_king.tags).to_be_truthy()

        -- Check non-boss enemies
        local slime = enemies.get_enemy("slime")
        t.expect(slime.boss).to_be(false)
    end)

    t.it("has valid wave ranges", function()
        local enemies = require("serpent.data.enemies")

        local all_enemies = enemies.get_all_enemies()

        for _, enemy in ipairs(all_enemies) do
            t.expect(enemy.min_wave >= 1).to_be(true)
            t.expect(enemy.max_wave <= 20).to_be(true)
            t.expect(enemy.min_wave <= enemy.max_wave).to_be(true)
        end
    end)

    t.it("has positive stats", function()
        local enemies = require("serpent.data.enemies")

        local all_enemies = enemies.get_all_enemies()

        for _, enemy in ipairs(all_enemies) do
            t.expect(enemy.base_hp >= 1).to_be(true)
            t.expect(enemy.base_damage >= 1).to_be(true)
            t.expect(enemy.speed >= 1).to_be(true)
        end
    end)

    t.it("provides enemy lookup functions", function()
        local enemies = require("serpent.data.enemies")

        -- Test individual enemy lookup
        local goblin = enemies.get_enemy("goblin")
        t.expect(goblin).to_be_truthy()
        t.expect(goblin.id).to_be("goblin")

        -- Test wave filtering
        local wave_5_enemies = enemies.get_enemies_for_wave(5)
        t.expect(#wave_5_enemies >= 1).to_be(true)

        -- Test boss filtering
        local boss_enemies = enemies.get_boss_enemies_for_wave(10)
        t.expect(#boss_enemies >= 1).to_be(true)
    end)
end)

t.describe("enemies.lua - Specific Enemy Verification", function()
    t.it("contains expected enemy types", function()
        local enemies = require("serpent.data.enemies")

        local expected_enemies = {
            "slime", "bat", "goblin", "orc", "skeleton",
            "wizard", "troll", "demon", "dragon", "swarm_queen", "lich_king"
        }

        for _, enemy_id in ipairs(expected_enemies) do
            local enemy = enemies.get_enemy(enemy_id)
            t.expect(enemy).to_be_truthy()
            t.expect(enemy.id).to_be(enemy_id)
        end
    end)

    t.it("has boss enemies at correct waves", function()
        local enemies = require("serpent.data.enemies")

        local swarm_queen = enemies.get_enemy("swarm_queen")
        t.expect(swarm_queen.min_wave).to_be(10)
        t.expect(swarm_queen.max_wave).to_be(10)

        local lich_king = enemies.get_enemy("lich_king")
        t.expect(lich_king.min_wave).to_be(20)
        t.expect(lich_king.max_wave).to_be(20)
    end)

    t.it("has increasing difficulty progression", function()
        local enemies = require("serpent.data.enemies")

        -- Early game enemy (low stats)
        local slime = enemies.get_enemy("slime")
        t.expect(slime.base_hp <= 30).to_be(true)

        -- Late game enemy (high stats)
        local dragon = enemies.get_enemy("dragon")
        t.expect(dragon.base_hp >= 100).to_be(true)

        -- Boss enemies (very high stats)
        local lich_king = enemies.get_enemy("lich_king")
        t.expect(lich_king.base_hp >= 500).to_be(true)
    end)
end)

local success = t.run()
os.exit(success and 0 or 1)