-- assets/scripts/tests/bargain/floors_spec.lua

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local sim = require("bargain.sim")
local generator = require("bargain.floors.generator")
local reachability = require("bargain.floors.reachability")

local function is_wall(grid, x, y)
    return grid.tiles[y][x] == "#"
end

t.describe("Bargain floors", function()
    t.it("generation_test", function()
        local world = sim.new_world(123)
        for floor = 1, 7 do
            local grid = generator.generate(world, floor)
            t.expect(grid.w).to_be(7)
            t.expect(grid.h).to_be(7)

            for x = 1, grid.w do
                t.expect(is_wall(grid, x, 1)).to_be(true)
                t.expect(is_wall(grid, x, grid.h)).to_be(true)
            end
            for y = 1, grid.h do
                t.expect(is_wall(grid, 1, y)).to_be(true)
                t.expect(is_wall(grid, grid.w, y)).to_be(true)
            end

            if floor == 1 then
                t.expect(grid.stairs_up).to_be_nil()
                t.expect(grid.stairs_down).to_be_type("table")
            elseif floor == 7 then
                t.expect(grid.stairs_down).to_be_nil()
                t.expect(grid.stairs_up).to_be_type("table")
            else
                t.expect(grid.stairs_up).to_be_type("table")
                t.expect(grid.stairs_down).to_be_type("table")
            end
        end

        local world_a = sim.new_world(77)
        local grid_a = generator.generate(world_a, 1)
        local world_b = sim.new_world(77)
        local grid_b = generator.generate(world_b, 1)

        if grid_a.stairs_down and grid_b.stairs_down then
            t.expect(grid_a.stairs_down.x).to_be(grid_b.stairs_down.x)
            t.expect(grid_a.stairs_down.y).to_be(grid_b.stairs_down.y)
        end
    end)

    t.it("reachability_test", function()
        local world = sim.new_world(44)
        for floor = 1, 7 do
            local grid = generator.generate(world, floor)
            local ok, errors = reachability.validate(grid)
            t.expect(ok).to_be(true)
            t.expect(#errors).to_be(0)
        end
    end)

    t.it("placement_test", function()
        local placement = require("bargain.floors.placement")
        local world = sim.new_world(99)
        local grid = generator.generate(world, 1)

        local ok = placement.apply(world, grid, { enemy_count = 2 })
        t.expect(ok).to_be(true)

        local player = world.entities.by_id[world.player_id]
        t.expect(player.pos.x).to_be(grid.spawn.x)
        t.expect(player.pos.y).to_be(grid.spawn.y)

        t.expect(grid.stairs_down).to_be_type("table")
        t.expect(grid.tiles[grid.stairs_down.y][grid.stairs_down.x]).to_be(">")

        local blocked = {}
        blocked[grid.spawn.x .. "," .. grid.spawn.y] = true
        blocked[grid.stairs_down.x .. "," .. grid.stairs_down.y] = true

        local enemies = {}
        for _, id in ipairs(world.entities.order) do
            if id ~= world.player_id then
                local entity = world.entities.by_id[id]
                local key = entity.pos.x .. "," .. entity.pos.y
                t.expect(blocked[key]).to_be_nil()
                t.expect(grid.tiles[entity.pos.y][entity.pos.x]).to_be(".")
                blocked[key] = true
                enemies[#enemies + 1] = key
            end
        end

        local world_b = sim.new_world(99)
        local grid_b = generator.generate(world_b, 1)
        placement.apply(world_b, grid_b, { enemy_count = 2 })
        local enemies_b = {}
        for _, id in ipairs(world_b.entities.order) do
            if id ~= world_b.player_id then
                local entity = world_b.entities.by_id[id]
                enemies_b[#enemies_b + 1] = entity.pos.x .. "," .. entity.pos.y
            end
        end
        t.expect(#enemies_b).to_be(#enemies)
        for i = 1, #enemies do
            t.expect(enemies[i]).to_be(enemies_b[i])
        end
    end)

    t.it("fallback_test", function()
        local world = sim.new_world(5)
        local grid = generator.generate(world, 1, { force_fallback = true })
        t.expect(grid.is_fallback).to_be(true)
        t.expect(grid.stairs_down).to_be_type("table")
    end)
end)
