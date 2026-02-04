--[[
================================================================================
TEST: Delayed Spawn Logic
================================================================================
Tests decrementing delayed timers and moving expired entries to forced queue.

Run with: lua assets/scripts/serpent/tests/test_delayed_spawn_logic.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

package.loaded["serpent.delayed_spawn_logic"] = nil

local t = require("tests.test_runner")
local delayed_spawn_logic = require("serpent.delayed_spawn_logic")

t.describe("delayed_spawn_logic - processing", function()
    t.it("moves expired entries to forced_queue in order", function()
        local delayed_queue = {
            { t_left_sec = 0.1, def_id = "skeleton" },
            { t_left_sec = 0.5, def_id = "slime" },
            { t_left_sec = 0.1, def_id = "bat" }
        }

        local forced_queue = {
            { enemy_id = "orc", def_id = "orc" }
        }

        local updated_delayed, updated_forced, moved = delayed_spawn_logic.process(
            0.2, delayed_queue, forced_queue
        )

        t.expect(#updated_delayed).to_be(1)
        t.expect(updated_delayed[1].def_id).to_be("slime")
        t.expect(math.abs(updated_delayed[1].t_left_sec - 0.3) < 0.0001).to_be(true)

        t.expect(#updated_forced).to_be(3)
        t.expect(updated_forced[1].enemy_id).to_be("orc")
        t.expect(updated_forced[2].enemy_id).to_be("skeleton")
        t.expect(updated_forced[3].enemy_id).to_be("bat")

        t.expect(#moved).to_be(2)
        t.expect(moved[1].enemy_id).to_be("skeleton")
        t.expect(moved[2].enemy_id).to_be("bat")
    end)
end)
