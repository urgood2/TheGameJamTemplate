--[[
================================================================================
TEST: Serpent Wave Director
================================================================================
Tests spawn counts, determinism, boss injection, and pending_count semantics.

Run with: lua assets/scripts/serpent/tests/test_serpent_wave_director.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

package.loaded["serpent.serpent_wave_director"] = nil
package.loaded["serpent.wave_config"] = nil
package.loaded["serpent.rng"] = nil
package.loaded["serpent.data.enemies"] = nil

local t = require("tests.test_runner")
local serpent_wave_director = require("serpent.serpent_wave_director")
local wave_config = require("serpent.wave_config")
local rng_module = require("serpent.rng")
local enemies = require("serpent.data.enemies")

local function count_boss_events(events)
    local count = 0
    for _, event in ipairs(events or {}) do
        if event.is_boss then
            count = count + 1
        end
    end
    return count
end

t.describe("serpent_wave_director.start_wave", function()
    t.it("spawns expected counts without bosses on wave 1", function()
        local rng = rng_module.create(123)
        local state = serpent_wave_director.create_state(1)
        local _, spawn_events = serpent_wave_director.start_wave(state, enemies.enemy_lookup, rng)

        local expected_count = wave_config.enemy_count(1)
        t.expect(#spawn_events).to_be(expected_count)
        t.expect(count_boss_events(spawn_events)).to_be(0)
    end)

    t.it("injects swarm_queen at wave 10", function()
        local rng = rng_module.create(321)
        local state = serpent_wave_director.create_state(10)
        local _, spawn_events = serpent_wave_director.start_wave(state, enemies.enemy_lookup, rng)

        local expected_count = wave_config.enemy_count(10) + 1
        t.expect(#spawn_events).to_be(expected_count)

        local found = false
        for _, event in ipairs(spawn_events) do
            if event.enemy_id == "swarm_queen" and event.is_boss then
                found = true
            end
        end
        t.expect(found).to_be(true)
    end)

    t.it("injects lich_king at wave 20", function()
        local rng = rng_module.create(999)
        local state = serpent_wave_director.create_state(20)
        local _, spawn_events = serpent_wave_director.start_wave(state, enemies.enemy_lookup, rng)

        local expected_count = wave_config.enemy_count(20) + 1
        t.expect(#spawn_events).to_be(expected_count)

        local found = false
        for _, event in ipairs(spawn_events) do
            if event.enemy_id == "lich_king" and event.is_boss then
                found = true
            end
        end
        t.expect(found).to_be(true)
    end)
end)

t.describe("serpent_wave_director.start_wave determinism", function()
    t.it("produces identical spawn order with same seed", function()
        local rng_a = rng_module.create(444)
        local rng_b = rng_module.create(444)

        local state = serpent_wave_director.create_state(5)
        local _, events_a = serpent_wave_director.start_wave(state, enemies.enemy_lookup, rng_a)
        local _, events_b = serpent_wave_director.start_wave(state, enemies.enemy_lookup, rng_b)

        t.expect(#events_a).to_be(#events_b)
        for i = 1, #events_a do
            t.expect(events_a[i].enemy_id).to_be(events_b[i].enemy_id)
        end
    end)
end)

t.describe("serpent_wave_director.is_done_spawning", function()
    t.it("returns true when pending_count == 0", function()
        t.expect(serpent_wave_director.is_done_spawning({ pending_count = 0 })).to_be(true)
        t.expect(serpent_wave_director.is_done_spawning({ pending_count = 2 })).to_be(false)
    end)
end)
