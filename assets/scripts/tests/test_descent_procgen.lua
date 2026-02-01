-- assets/scripts/tests/test_descent_procgen.lua
--[[
================================================================================
DESCENT PROCGEN TESTS
================================================================================
Validates procedural generation: walkable start/stairs, reachability, quotas.

Acceptance criteria:
- Walkable start and stairs
- Start->stairs reachable (BFS validated)
- Enemy quotas met
- No placement overlaps
- Fallback behavior
- Seeds 1-10 all generate valid floors
]]

local t = require("tests.test_runner")
local Procgen = require("descent.procgen")
local Map = require("descent.map")
local spec = require("descent.spec")
local pathfinding = require("descent.pathfinding")

--------------------------------------------------------------------------------
-- Walkable Start/Stairs Tests
--------------------------------------------------------------------------------

t.describe("Descent Procgen Walkable", function()
    t.it("player start is walkable", function()
        for seed = 1, 5 do
            local floor_data = Procgen.generate(1, seed)
            local start = floor_data.placements.player_start
            t.expect(start).to_not_be(nil)
            t.expect(Procgen.is_walkable(floor_data.map, start.x, start.y)).to_be(true)
        end
    end)

    t.it("stairs down is walkable", function()
        for seed = 1, 5 do
            local floor_data = Procgen.generate(1, seed)
            local stairs = floor_data.placements.stairs_down
            if stairs then
                t.expect(Procgen.is_walkable(floor_data.map, stairs.x, stairs.y)).to_be(true)
            end
        end
    end)

    t.it("stairs up is walkable on floor 2+", function()
        for seed = 1, 5 do
            local floor_data = Procgen.generate(2, seed)
            local stairs = floor_data.placements.stairs_up
            if stairs then
                t.expect(Procgen.is_walkable(floor_data.map, stairs.x, stairs.y)).to_be(true)
            end
        end
    end)
end)

--------------------------------------------------------------------------------
-- Reachability Tests
--------------------------------------------------------------------------------

t.describe("Descent Procgen Reachability", function()
    t.it("stairs down reachable from start", function()
        for seed = 1, 10 do
            local floor_data = Procgen.generate(1, seed)
            local start = floor_data.placements.player_start
            local stairs = floor_data.placements.stairs_down
            
            if start and stairs then
                local path = pathfinding.find_path(
                    floor_data.map,
                    start.x, start.y,
                    stairs.x, stairs.y
                )
                t.expect(path).to_not_be(nil)
            end
        end
    end)

    t.it("stairs up reachable from start on floor 2", function()
        for seed = 1, 5 do
            local floor_data = Procgen.generate(2, seed)
            local start = floor_data.placements.player_start
            local stairs = floor_data.placements.stairs_up
            
            if start and stairs then
                local path = pathfinding.find_path(
                    floor_data.map,
                    start.x, start.y,
                    stairs.x, stairs.y
                )
                t.expect(path).to_not_be(nil)
            end
        end
    end)
end)

--------------------------------------------------------------------------------
-- Quota Tests
--------------------------------------------------------------------------------

t.describe("Descent Procgen Quotas", function()
    t.it("enemy count within spec range", function()
        for floor_num = 1, 5 do
            local floor_spec = spec.floors.floors[floor_num]
            local floor_data = Procgen.generate(floor_num, 42)
            local enemies = floor_data.placements.enemies or {}
            
            t.expect(#enemies).to_be_greater_than_or_equal(floor_spec.enemies_min)
            t.expect(#enemies).to_be_less_than_or_equal(floor_spec.enemies_max)
        end
    end)

    t.it("shop placed on shop floors", function()
        for floor_num = 1, 5 do
            local floor_spec = spec.floors.floors[floor_num]
            if floor_spec.shop then
                local floor_data = Procgen.generate(floor_num, 42)
                t.expect(floor_data.placements.shop).to_not_be(nil)
            end
        end
    end)

    t.it("altar placed on altar floors", function()
        for floor_num = 1, 5 do
            local floor_spec = spec.floors.floors[floor_num]
            if floor_spec.altar then
                local floor_data = Procgen.generate(floor_num, 42)
                t.expect(floor_data.placements.altar).to_not_be(nil)
            end
        end
    end)
end)

--------------------------------------------------------------------------------
-- No Overlap Tests
--------------------------------------------------------------------------------

t.describe("Descent Procgen No Overlaps", function()
    t.it("no placement overlaps", function()
        for seed = 1, 5 do
            local floor_data = Procgen.generate(1, seed)
            local positions = {}
            
            local function check_position(name, pos)
                if pos then
                    local key = pos.x .. "," .. pos.y
                    if positions[key] then
                        t.fail("Overlap at " .. key .. ": " .. name .. " and " .. positions[key])
                    end
                    positions[key] = name
                end
            end
            
            check_position("player_start", floor_data.placements.player_start)
            check_position("stairs_down", floor_data.placements.stairs_down)
            check_position("stairs_up", floor_data.placements.stairs_up)
            check_position("shop", floor_data.placements.shop)
            check_position("altar", floor_data.placements.altar)
            
            if floor_data.placements.enemies then
                for i, enemy in ipairs(floor_data.placements.enemies) do
                    check_position("enemy_" .. i, enemy)
                end
            end
        end
    end)

    t.it("stairs not under player start", function()
        for seed = 1, 10 do
            local floor_data = Procgen.generate(1, seed)
            local start = floor_data.placements.player_start
            local stairs = floor_data.placements.stairs_down
            
            if start and stairs then
                local overlap = (start.x == stairs.x and start.y == stairs.y)
                t.expect(overlap).to_be(false)
            end
        end
    end)
end)

--------------------------------------------------------------------------------
-- Fallback Tests
--------------------------------------------------------------------------------

t.describe("Descent Procgen Fallback", function()
    t.it("fallback floor has valid layout", function()
        local floor_data = Procgen.generate_fallback(1)
        
        t.expect(floor_data).to_not_be(nil)
        t.expect(floor_data.fallback).to_be(true)
        t.expect(floor_data.placements.player_start).to_not_be(nil)
        
        -- Start should be walkable
        local start = floor_data.placements.player_start
        t.expect(Procgen.is_walkable(floor_data.map, start.x, start.y)).to_be(true)
    end)

    t.it("fallback has stairs if required", function()
        local floor_data = Procgen.generate_fallback(1)
        local floor_spec = spec.floors.floors[1]
        
        if floor_spec.stairs_down then
            t.expect(floor_data.placements.stairs_down).to_not_be(nil)
        end
    end)

    t.it("fallback has minimum enemies", function()
        local floor_data = Procgen.generate_fallback(1)
        local floor_spec = spec.floors.floors[1]
        
        t.expect(#floor_data.placements.enemies).to_be_greater_than_or_equal(floor_spec.enemies_min)
    end)
end)

--------------------------------------------------------------------------------
-- Hash Tests
--------------------------------------------------------------------------------

t.describe("Descent Procgen Hash", function()
    t.it("same seed produces same hash", function()
        local floor1 = Procgen.generate(1, 42)
        local floor2 = Procgen.generate(1, 42)
        
        t.expect(floor1.hash).to_be(floor2.hash)
    end)

    t.it("different seeds produce different hashes", function()
        local floor1 = Procgen.generate(1, 42)
        local floor2 = Procgen.generate(1, 43)
        
        t.expect(floor1.hash).to_not_be(floor2.hash)
    end)

    t.it("hash is 8 hex characters", function()
        local floor_data = Procgen.generate(1, 42)
        t.expect(#floor_data.hash).to_be(8)
        t.expect(floor_data.hash:match("^[0-9a-f]+$")).to_be_truthy()
    end)
end)

--------------------------------------------------------------------------------
-- Seed 1-10 Stress Test
--------------------------------------------------------------------------------

t.describe("Descent Procgen Seeds 1-10", function()
    t.it("all seeds produce valid floors for floor 1", function()
        for seed = 1, 10 do
            local floor_data, err = Procgen.generate(1, seed)
            t.expect(floor_data).to_not_be(nil)
            t.expect(floor_data.placements.player_start).to_not_be(nil)
        end
    end)

    t.it("all seeds produce valid floors for all floor types", function()
        for floor_num = 1, 5 do
            for seed = 1, 3 do
                local floor_data = Procgen.generate(floor_num, seed)
                t.expect(floor_data).to_not_be(nil)
                t.expect(floor_data.map).to_not_be(nil)
            end
        end
    end)
end)
