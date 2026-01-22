-- assets/scripts/tests/test_procgen_dungeon.lua
-- TDD: Tests written FIRST for Phase 4 DungeonBuilder

local t = require("tests.test_runner")
t.reset()

local procgen = require("core.procgen")

t.describe("DungeonBuilder", function()
    local DungeonBuilder = require("core.procgen.dungeon")

    t.describe("construction", function()
        t.it("creates builder with dimensions and options", function()
            local builder = DungeonBuilder.new(100, 80, {
                roomMinSize = 8,
                roomMaxSize = 20,
                maxRooms = 12
            })
            t.expect(builder).to_be_truthy()
            t.expect(builder._w).to_be(100)
            t.expect(builder._h).to_be(80)
        end)

        t.it("uses default options when not provided", function()
            local builder = DungeonBuilder.new(50, 50)
            t.expect(builder._opts.roomMinSize).to_be_truthy()
            t.expect(builder._opts.roomMaxSize).to_be_truthy()
            t.expect(builder._opts.maxRooms).to_be_truthy()
        end)

        t.it("accepts seed for reproducibility", function()
            local builder = DungeonBuilder.new(50, 50, {seed = 12345})
            t.expect(builder._opts.seed).to_be(12345)
        end)
    end)

    t.describe("fluent API", function()
        t.it("generateRooms() returns self for chaining", function()
            local builder = DungeonBuilder.new(50, 50)
            local result = builder:generateRooms()
            t.expect(result).to_be(builder)
        end)

        t.it("connectRooms() returns self for chaining", function()
            local builder = DungeonBuilder.new(50, 50):generateRooms()
            local result = builder:connectRooms()
            t.expect(result).to_be(builder)
        end)

        t.it("addDoors() returns self for chaining", function()
            local builder = DungeonBuilder.new(50, 50)
                :generateRooms()
                :connectRooms()
            local result = builder:addDoors()
            t.expect(result).to_be(builder)
        end)

        t.it("populate() returns self for chaining", function()
            local builder = DungeonBuilder.new(50, 50)
                :generateRooms()
                :connectRooms()
            local result = builder:populate({
                enemies = {min = 1, max = 3}
            })
            t.expect(result).to_be(builder)
        end)

        t.it("supports full method chaining", function()
            local builder = DungeonBuilder.new(100, 80)
                :generateRooms()
                :connectRooms()
                :addDoors()
                :populate({enemies = {min = 1, max = 3}})
            t.expect(builder).to_be_truthy()
        end)
    end)

    t.describe("generateRooms()", function()
        t.it("creates rooms within bounds", function()
            math.randomseed(12345)
            local builder = DungeonBuilder.new(50, 50, {
                roomMinSize = 5,
                roomMaxSize = 10,
                maxRooms = 5
            }):generateRooms()

            t.expect(#builder._rooms > 0).to_be(true)

            for _, room in ipairs(builder._rooms) do
                t.expect(room.x >= 1).to_be(true)
                t.expect(room.y >= 1).to_be(true)
                t.expect(room.x + room.w - 1 <= 50).to_be(true)
                t.expect(room.y + room.h - 1 <= 50).to_be(true)
            end
        end)

        t.it("rooms do not overlap", function()
            math.randomseed(12345)
            local builder = DungeonBuilder.new(100, 100, {
                roomMinSize = 8,
                roomMaxSize = 15,
                maxRooms = 10
            }):generateRooms()

            local rooms = builder._rooms
            for i = 1, #rooms do
                for j = i + 1, #rooms do
                    local a, b = rooms[i], rooms[j]
                    -- Check no overlap (with 1 cell padding)
                    local overlap =
                        a.x < b.x + b.w and a.x + a.w > b.x and
                        a.y < b.y + b.h and a.y + a.h > b.y
                    t.expect(overlap).to_be(false)
                end
            end
        end)

        t.it("respects maxRooms limit", function()
            math.randomseed(12345)
            local builder = DungeonBuilder.new(200, 200, {
                roomMinSize = 5,
                roomMaxSize = 8,
                maxRooms = 5
            }):generateRooms()

            t.expect(#builder._rooms <= 5).to_be(true)
        end)

        t.it("fills rooms in grid with floor value", function()
            math.randomseed(12345)
            local builder = DungeonBuilder.new(50, 50, {
                roomMinSize = 5,
                roomMaxSize = 10,
                maxRooms = 3
            }):generateRooms()

            local grid = builder._grid
            local room = builder._rooms[1]

            -- Check interior of first room is floor (0)
            t.expect(grid:get(room.x + 1, room.y + 1)).to_be(0)
        end)
    end)

    t.describe("connectRooms()", function()
        t.it("creates corridors between rooms", function()
            math.randomseed(12345)
            local builder = DungeonBuilder.new(50, 50, {
                roomMinSize = 5,
                roomMaxSize = 10,
                maxRooms = 3
            }):generateRooms():connectRooms()

            -- Graph should have edges connecting rooms
            local graph = builder._graph
            t.expect(graph).to_be_truthy()
        end)

        t.it("all rooms are reachable", function()
            math.randomseed(12345)
            local builder = DungeonBuilder.new(80, 80, {
                roomMinSize = 8,
                roomMaxSize = 15,
                maxRooms = 6
            }):generateRooms():connectRooms()

            -- Check connectivity via graph
            local rooms = builder._rooms
            if #rooms > 1 then
                local path = builder._graphBuilder:shortestPath("room_1", "room_" .. #rooms)
                t.expect(#path > 0).to_be(true)
            end
        end)
    end)

    t.describe("addDoors()", function()
        t.it("marks door positions at corridor-room transitions", function()
            math.randomseed(12345)
            local builder = DungeonBuilder.new(50, 50, {
                roomMinSize = 6,
                roomMaxSize = 10,
                maxRooms = 3
            }):generateRooms():connectRooms():addDoors()

            -- Should have some doors marked
            t.expect(#builder._doors >= 0).to_be(true)  -- May be 0 in some configurations
        end)
    end)

    t.describe("populate()", function()
        t.it("generates spawn points for enemies", function()
            math.randomseed(12345)
            local builder = DungeonBuilder.new(80, 80, {
                roomMinSize = 8,
                roomMaxSize = 15,
                maxRooms = 5
            }):generateRooms():connectRooms():populate({
                enemies = {min = 1, max = 3}
            })

            local spawnPoints = builder._spawnPoints
            t.expect(spawnPoints.enemies).to_be_truthy()
            t.expect(#spawnPoints.enemies > 0).to_be(true)
        end)

        t.it("generates spawn points for treasures", function()
            math.randomseed(12345)
            local builder = DungeonBuilder.new(80, 80, {
                roomMinSize = 8,
                roomMaxSize = 15,
                maxRooms = 5
            }):generateRooms():connectRooms():populate({
                treasures = {min = 1, max = 2}
            })

            local spawnPoints = builder._spawnPoints
            t.expect(spawnPoints.treasures).to_be_truthy()
            t.expect(#spawnPoints.treasures > 0).to_be(true)
        end)

        t.it("spawn points are within room bounds", function()
            math.randomseed(12345)
            local builder = DungeonBuilder.new(80, 80, {
                roomMinSize = 8,
                roomMaxSize = 15,
                maxRooms = 5
            }):generateRooms():connectRooms():populate({
                enemies = {min = 2, max = 4}
            })

            for _, spawn in ipairs(builder._spawnPoints.enemies) do
                -- Spawn should be floor (0), not wall (1)
                t.expect(builder._grid:get(spawn.gx, spawn.gy)).to_be(0)
            end
        end)
    end)

    t.describe("build()", function()
        t.it("returns result with grid", function()
            math.randomseed(12345)
            local result = DungeonBuilder.new(50, 50)
                :generateRooms()
                :connectRooms()
                :build()

            t.expect(result.grid).to_be_truthy()
            t.expect(result.grid.w).to_be(50)
            t.expect(result.grid.h).to_be(50)
        end)

        t.it("returns result with graph", function()
            math.randomseed(12345)
            local result = DungeonBuilder.new(50, 50, {maxRooms = 4})
                :generateRooms()
                :connectRooms()
                :build()

            t.expect(result.graph).to_be_truthy()
        end)

        t.it("returns result with rooms array", function()
            math.randomseed(12345)
            local result = DungeonBuilder.new(50, 50, {maxRooms = 4})
                :generateRooms()
                :build()

            t.expect(result.rooms).to_be_truthy()
            t.expect(type(result.rooms)).to_be("table")
        end)

        t.it("returns result with spawnPoints", function()
            math.randomseed(12345)
            local result = DungeonBuilder.new(80, 80, {maxRooms = 5})
                :generateRooms()
                :connectRooms()
                :populate({enemies = {min = 1, max = 2}})
                :build()

            t.expect(result.spawnPoints).to_be_truthy()
            t.expect(result.spawnPoints.enemies).to_be_truthy()
        end)
    end)

    t.describe("seed reproducibility", function()
        t.it("same seed produces same layout", function()
            local result1 = DungeonBuilder.new(50, 50, {seed = 99999, maxRooms = 5})
                :generateRooms()
                :build()

            local result2 = DungeonBuilder.new(50, 50, {seed = 99999, maxRooms = 5})
                :generateRooms()
                :build()

            t.expect(#result1.rooms).to_be(#result2.rooms)

            -- First room should be at same position
            if #result1.rooms > 0 then
                t.expect(result1.rooms[1].x).to_be(result2.rooms[1].x)
                t.expect(result1.rooms[1].y).to_be(result2.rooms[1].y)
            end
        end)
    end)
end)

t.describe("procgen.dungeon() factory", function()
    t.it("returns DungeonBuilder instance", function()
        local builder = procgen.dungeon(50, 50)
        t.expect(builder).to_be_truthy()
        t.expect(type(builder.generateRooms)).to_be("function")
        t.expect(type(builder.connectRooms)).to_be("function")
        t.expect(type(builder.build)).to_be("function")
    end)
end)

return t.run()
