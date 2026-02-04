--[[
================================================================================
TEST: Serpent Wave Director - is_done_spawning
================================================================================
Run with: lua assets/scripts/serpent/tests/test_serpent_wave_director_done_spawning.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

package.loaded["serpent.serpent_wave_director"] = nil

local t = require("tests.test_runner")
local serpent_wave_director = require("serpent.serpent_wave_director")

t.describe("serpent_wave_director.is_done_spawning", function()
    t.it("returns true only when pending_count == 0", function()
        t.expect(serpent_wave_director.is_done_spawning({ pending_count = 0 })).to_be(true)
        t.expect(serpent_wave_director.is_done_spawning({ pending_count = 1 })).to_be(false)
        t.expect(serpent_wave_director.is_done_spawning(nil)).to_be(false)
    end)
end)
