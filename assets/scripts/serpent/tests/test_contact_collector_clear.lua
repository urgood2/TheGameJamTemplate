--[[
================================================================================
TEST: Contact Collector Clear
================================================================================
Run with: lua assets/scripts/serpent/tests/test_contact_collector_clear.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

package.loaded["serpent.contact_collector"] = nil

local t = require("tests.test_runner")
local contact_collector = require("serpent.contact_collector")

t.describe("contact_collector.clear", function()
    t.it("wipes overlap state while preserving registrations", function()
        local state = contact_collector.create_state(15, 0.5)
        state.registered_enemies[1] = 100
        state.registered_units[2] = 200
        state.contact_cooldowns["1_2"] = 1.0
        state.active_contacts = {
            { enemy_id = 1, instance_id = 2, contact_time = 1.0 }
        }
        state.active_overlaps["1:2"] = {
            enemy_id = 1,
            instance_id = 2,
            contact_time = 1.0
        }
        state.total_contacts = 5

        local cleared = contact_collector.clear(state)

        t.expect(cleared.registered_enemies[1]).to_be(100)
        t.expect(cleared.registered_units[2]).to_be(200)
        t.expect(next(cleared.contact_cooldowns)).to_be_nil()
        t.expect(#cleared.active_contacts).to_be(0)
        t.expect(next(cleared.active_overlaps)).to_be_nil()
        t.expect(cleared.total_contacts).to_be(0)
    end)
end)
