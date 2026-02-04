-- assets/scripts/tests/bargain/fov_spec.lua

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local fov = require("bargain.fov.fov")

local GOLDEN_DIR = "assets/scripts/tests/bargain/goldens/fov"

local MAPS = {
    split = {
        rows = {
            "#######",
            "#..#..#",
            "#..#..#",
            "#.....#",
            "#..#..#",
            "#..#..#",
            "#######",
        },
    },
    corner = {
        rows = {
            "#######",
            "#.....#",
            "#.###.#",
            "#.#...#",
            "#.#.###",
            "#.....#",
            "#######",
        },
    },
}

local SCENARIOS = {
    { id = "split_left_r4", map = "split", origin = { x = 2, y = 4 }, radius = 4 },
    { id = "split_right_r4", map = "split", origin = { x = 6, y = 4 }, radius = 4 },
    { id = "corner_mid_r4", map = "corner", origin = { x = 4, y = 5 }, radius = 4 },
}

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function parse_map(rows)
    local h = #rows
    local w = #rows[1]
    local tiles = {}
    for y = 1, h do
        local row = rows[y]
        tiles[y] = {}
        for x = 1, w do
            tiles[y][x] = row:sub(x, x)
        end
    end
    return { w = w, h = h, tiles = tiles }
end

local function render_visibility(grid, origin, visible)
    local lines = {}
    for y = 1, grid.h do
        local row = {}
        for x = 1, grid.w do
            if x == origin.x and y == origin.y then
                row[x] = "@"
            elseif visible[x .. "," .. y] then
                row[x] = grid.tiles[y][x]
            else
                row[x] = "?"
            end
        end
        lines[y] = table.concat(row)
    end
    return table.concat(lines, "\n")
end

t.describe("Bargain FOV", function()
    t.it("matches golden visibility masks", function()
        for _, scenario in ipairs(SCENARIOS) do
            local grid = parse_map(MAPS[scenario.map].rows)
            local v1 = fov.compute(grid, scenario.origin, scenario.radius)
            local v2 = fov.compute(grid, scenario.origin, scenario.radius)
            local out1 = render_visibility(grid, scenario.origin, v1)
            local out2 = render_visibility(grid, scenario.origin, v2)

            t.expect(out1).to_be(out2)

            local golden_path = string.format("%s/%s.txt", GOLDEN_DIR, scenario.id)
            local golden = read_file(golden_path)
            t.expect(golden).to_be_type("string")
            t.expect(trim(out1)).to_be(trim(golden))
        end
    end)

    t.it("updates visibility on player move", function()
        local grid = parse_map(MAPS.split.rows)
        local v1 = fov.compute(grid, { x = 2, y = 4 }, 4)
        local v2 = fov.compute(grid, { x = 3, y = 4 }, 4)
        local out1 = render_visibility(grid, { x = 2, y = 4 }, v1)
        local out2 = render_visibility(grid, { x = 3, y = 4 }, v2)
        t.expect(out1).never().to_be(out2)
    end)
end)
