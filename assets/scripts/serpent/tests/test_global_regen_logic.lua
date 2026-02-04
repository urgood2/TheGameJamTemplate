--[[
================================================================================
TEST: Global Regen Accumulator
================================================================================
Verifies Support synergy global regen accumulation and cursor-based
round-robin healing with wrap and dead-skip behavior.

Run with: lua assets/scripts/serpent/tests/test_global_regen_logic.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")

_G.log_debug = function(msg) end
_G.log_warning = function(msg) end

t.describe("global_regen_logic.tick", function()
    t.it("emits heals in round-robin order and wraps cursor", function()
        local global_regen_logic = require("serpent.global_regen_logic")

        local snake_state = {
            segments = {
                { instance_id = 10, hp = 50 },
                { instance_id = 11, hp = 60 },
                { instance_id = 12, hp = 70 }
            }
        }

        local synergy_state = {
            active_bonuses = {
                Support = { global_regen_per_sec = 2 }
            }
        }

        local combat_state = { global_regen_accum = 0.0, global_regen_cursor = 1 }

        local updated_state, events = global_regen_logic.tick(1.0, snake_state, synergy_state, combat_state)

        t.expect(#events).to_be(2)
        t.expect(events[1].target_instance_id).to_be(10)
        t.expect(events[2].target_instance_id).to_be(11)
        t.expect(updated_state.global_regen_cursor).to_be(3)
        t.expect(math.abs(updated_state.global_regen_accum - 0.0) < 0.0001).to_be(true)

        local updated_state2, events2 = global_regen_logic.tick(0.5, snake_state, synergy_state, updated_state)
        t.expect(#events2).to_be(1)
        t.expect(events2[1].target_instance_id).to_be(12)
        t.expect(updated_state2.global_regen_cursor).to_be(1)
    end)

    t.it("skips dead segments when selecting next heal target", function()
        local global_regen_logic = require("serpent.global_regen_logic")

        local snake_state = {
            segments = {
                { instance_id = 1, hp = 40 },
                { instance_id = 2, hp = 0 },
                { instance_id = 3, hp = 55 }
            }
        }

        local synergy_state = {
            active_bonuses = {
                Support = { global_regen_per_sec = 1 }
            }
        }

        local combat_state = { global_regen_accum = 0.0, global_regen_cursor = 2 }

        local updated_state, events = global_regen_logic.tick(1.0, snake_state, synergy_state, combat_state)

        t.expect(#events).to_be(1)
        t.expect(events[1].target_instance_id).to_be(3)
        t.expect(updated_state.global_regen_cursor).to_be(1)
    end)
end)

local success = t.run()
os.exit(success and 0 or 1)
