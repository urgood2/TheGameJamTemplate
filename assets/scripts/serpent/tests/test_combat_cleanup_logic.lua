--[[
================================================================================
TEST: Combat Cleanup Logic
================================================================================
Tests for dead segment removal and cooldown pruning.

Run with: lua assets/scripts/serpent/tests/test_combat_cleanup_logic.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

package.loaded["serpent.combat_cleanup_logic"] = nil

local t = require("tests.test_runner")
local combat_cleanup_logic = require("serpent.combat_cleanup_logic")

t.describe("combat_cleanup_logic - remove_dead_units", function()
    t.it("removes segments with hp <= 0", function()
        local snake_state = {
            segments = {
                { instance_id = 1, hp = 10 },
                { instance_id = 2, hp = 0 },
                { instance_id = 3 } -- hp missing: keep
            },
            min_len = 1,
            max_len = 8
        }

        local updated = combat_cleanup_logic.remove_dead_units(snake_state)
        t.expect(#updated.segments).to_be(2)
        t.expect(updated.segments[1].instance_id).to_be(1)
        t.expect(updated.segments[2].instance_id).to_be(3)
    end)
end)

t.describe("combat_cleanup_logic - prune_contact_cooldowns", function()
    t.it("drops cooldowns for missing enemy or unit ids", function()
        local snake_state = {
            segments = {
                { instance_id = 10, hp = 10 },
                { instance_id = 12, hp = 10 }
            }
        }

        local enemy_snaps = {
            { enemy_id = 1, hp = 10 }
        }

        local contact_cooldowns = {
            ["1_10"] = 0.1,
            ["2_11"] = 0.2,
            ["bad_key"] = 0.3
        }

        local cleaned = combat_cleanup_logic.prune_contact_cooldowns(
            contact_cooldowns, snake_state, enemy_snaps
        )

        t.expect(cleaned["1_10"]).to_be(0.1)
        t.expect(cleaned["2_11"]).to_be_nil()
        t.expect(cleaned["bad_key"]).to_be_nil()
    end)
end)

t.describe("combat_cleanup_logic - cleanup", function()
    t.it("returns updated snake_state and cleaned cooldowns", function()
        local snake_state = {
            segments = {
                { instance_id = 5, hp = 0 },
                { instance_id = 6, hp = 10 }
            }
        }

        local enemy_snaps = {
            { enemy_id = 7, hp = 10 }
        }

        local contact_cooldowns = {
            ["7_6"] = 0.4,
            ["7_5"] = 0.5
        }

        local updated_state, cleaned = combat_cleanup_logic.cleanup(
            snake_state, enemy_snaps, contact_cooldowns
        )

        t.expect(#updated_state.segments).to_be(1)
        t.expect(updated_state.segments[1].instance_id).to_be(6)
        t.expect(cleaned["7_6"]).to_be(0.4)
        t.expect(cleaned["7_5"]).to_be_nil()
    end)
end)
