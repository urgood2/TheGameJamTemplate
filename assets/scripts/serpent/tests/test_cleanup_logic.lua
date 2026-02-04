--[[
================================================================================
TEST: Cleanup Logic
================================================================================
Verifies removal of dead segments and pruning of stale contact cooldowns.

Run with: lua assets/scripts/serpent/tests/test_cleanup_logic.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")

_G.log_debug = function(msg) end
_G.log_warning = function(msg) end

t.describe("cleanup_logic.remove_dead_segments", function()
    t.it("filters out segments with hp <= 0 and preserves order", function()
        local cleanup_logic = require("serpent.cleanup_logic")

        local snake_state = {
            segments = {
                { instance_id = 1, hp = 10 },
                { instance_id = 2, hp = 0 },
                { instance_id = 3, hp = -5 },
                { instance_id = 4, hp = 25 }
            },
            min_len = 1,
            max_len = 8
        }

        local updated = cleanup_logic.remove_dead_segments(snake_state)

        t.expect(#updated.segments).to_be(2)
        t.expect(updated.segments[1].instance_id).to_be(1)
        t.expect(updated.segments[2].instance_id).to_be(4)
    end)
end)

t.describe("cleanup_logic.prune_contact_cooldowns", function()
    t.it("removes cooldowns for missing enemy or unit ids", function()
        local cleanup_logic = require("serpent.cleanup_logic")

        local enemy_snaps = {
            { enemy_id = 1 },
            { enemy_id = 2 }
        }

        local snake_state = {
            segments = {
                { instance_id = 101, hp = 10 },
                { instance_id = 102, hp = 0 }
            }
        }

        local contact_cooldowns = {
            ["1:101"] = 0.2,
            ["2:101"] = 0.3,
            ["1:999"] = 0.1,
            ["3:101"] = 0.1,
            ["bad"] = 0.1,
            ["2_101"] = 0.5
        }

        local cleaned = cleanup_logic.prune_contact_cooldowns(contact_cooldowns, enemy_snaps, snake_state)

        t.expect(cleaned["1:101"]).to_be(0.2)
        t.expect(cleaned["2:101"]).to_be(0.3)
        t.expect(cleaned["2_101"]).to_be(0.5)
        t.expect(cleaned["1:999"]).to_be(nil)
        t.expect(cleaned["3:101"]).to_be(nil)
        t.expect(cleaned["bad"]).to_be(nil)
    end)
end)

t.describe("cleanup_logic.apply", function()
    t.it("returns updated snake_state and pruned contact_cooldowns", function()
        local cleanup_logic = require("serpent.cleanup_logic")

        local snake_state = {
            segments = {
                { instance_id = 5, hp = 0 },
                { instance_id = 6, hp = 12 }
            },
            min_len = 1,
            max_len = 8
        }

        local enemy_snaps = {
            { enemy_id = 9 }
        }

        local combat_state = {
            contact_cooldowns = {
                ["9:6"] = 0.4,
                ["9:5"] = 0.4
            }
        }

        local updated_snake, updated_combat = cleanup_logic.apply(snake_state, enemy_snaps, combat_state)

        t.expect(#updated_snake.segments).to_be(1)
        t.expect(updated_snake.segments[1].instance_id).to_be(6)
        t.expect(updated_combat.contact_cooldowns["9:6"]).to_be(0.4)
        t.expect(updated_combat.contact_cooldowns["9:5"]).to_be(nil)
    end)
end)

local success = t.run()
os.exit(success and 0 or 1)
