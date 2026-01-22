-- assets/scripts/tests/test_procgen_debug.lua
-- TDD: Tests written FIRST for Phase 5 debug visualization

local t = require("tests.test_runner")
t.reset()

local procgen = require("core.procgen")

-- Mock the C++ drawing infrastructure for testing
local mockDrawCalls = {}
local function setupMocks()
    mockDrawCalls = {}
    _G.command_buffer = {
        queueDrawRectangle = function(layer, fn, z)
            local cmd = {}
            fn(cmd)
            table.insert(mockDrawCalls, {type = "rect", cmd = cmd})
        end,
        queueDrawCircleLines = function(layer, fn, z)
            local cmd = {}
            fn(cmd)
            table.insert(mockDrawCalls, {type = "circle", cmd = cmd})
        end,
        queueDrawLine = function(layer, fn, z)
            local cmd = {}
            fn(cmd)
            table.insert(mockDrawCalls, {type = "line", cmd = cmd})
        end,
        queueDrawText = function(layer, fn, z)
            local cmd = {}
            fn(cmd)
            table.insert(mockDrawCalls, {type = "text", cmd = cmd})
        end,
    }
    _G.layers = {
        debug = { name = "debug" }
    }
    -- Get the current debug singleton and enable it
    local debug = _G.__PROCGEN_DEBUG__ or require("core.procgen.debug")
    debug.enabled = true
    return debug
end

-- Initial load to establish the singleton
require("core.procgen.debug")

t.describe("procgen.debug enabled flag", function()
    t.it("defaults to false", function()
        -- Reset module to test default
        package.loaded["core.procgen.debug"] = nil
        _G.__PROCGEN_DEBUG__ = nil
        local freshDebug = require("core.procgen.debug")
        t.expect(freshDebug.enabled).to_be(false)
    end)

    t.it("can be toggled", function()
        local debug = setupMocks()
        debug.enabled = false
        debug.toggle()
        t.expect(debug.enabled).to_be(true)
        debug.toggle()
        t.expect(debug.enabled).to_be(false)
    end)
end)

t.describe("procgen.debug drawGrid()", function()
    t.it("draws nothing when disabled", function()
        local debug = setupMocks()
        debug.enabled = false
        local grid = procgen.Grid(5, 5, 0)
        debug.drawGrid(grid, 0, 0, 16)
        t.expect(#mockDrawCalls).to_be(0)
    end)

    t.it("draws rectangles for each cell", function()
        local debug = setupMocks()
        local grid = procgen.Grid(3, 3, 0)
        debug.drawGrid(grid, 0, 0, 16)
        -- 3x3 = 9 cells
        t.expect(#mockDrawCalls).to_be(9)
        t.expect(mockDrawCalls[1].type).to_be("rect")
    end)

    t.it("positions cells based on cellSize", function()
        local debug = setupMocks()
        local grid = procgen.Grid(2, 2, 0)
        debug.drawGrid(grid, 100, 200, 32)

        -- First cell at (100, 200)
        t.expect(mockDrawCalls[1].cmd.x).to_be(100)
        t.expect(mockDrawCalls[1].cmd.y).to_be(200)
        t.expect(mockDrawCalls[1].cmd.width).to_be(32)
        t.expect(mockDrawCalls[1].cmd.height).to_be(32)
    end)

    t.it("uses color function when provided", function()
        local debug = setupMocks()
        local grid = procgen.Grid(2, 2, 0)
        grid:set(1, 1, 1)

        local colorFn = function(value)
            if value == 1 then
                return {r = 255, g = 0, b = 0, a = 255}
            end
            return {r = 0, g = 0, b = 255, a = 255}
        end

        debug.drawGrid(grid, 0, 0, 16, colorFn)

        -- Check that different values get different colors
        local foundRed = false
        local foundBlue = false
        for _, call in ipairs(mockDrawCalls) do
            if call.cmd.color.r == 255 then foundRed = true end
            if call.cmd.color.b == 255 then foundBlue = true end
        end
        t.expect(foundRed).to_be(true)
        t.expect(foundBlue).to_be(true)
    end)

    t.it("uses default wall/floor colors when no colorFn", function()
        local debug = setupMocks()
        local grid = procgen.Grid(2, 2, 1)  -- All walls
        grid:set(1, 1, 0)  -- One floor

        debug.drawGrid(grid, 0, 0, 16)

        -- Should use default color mapping
        t.expect(#mockDrawCalls).to_be(4)
    end)
end)

t.describe("procgen.debug drawPattern()", function()
    t.it("draws nothing when disabled", function()
        local debug = setupMocks()
        debug.enabled = false
        local pattern = procgen.forma.pattern.new()
        pattern:insert(0, 0)
        debug.drawPattern(pattern, 0, 0, 16)
        t.expect(#mockDrawCalls).to_be(0)
    end)

    t.it("draws rectangle for each cell in pattern", function()
        local debug = setupMocks()
        local pattern = procgen.forma.pattern.new()
        pattern:insert(0, 0)
        pattern:insert(1, 0)
        pattern:insert(0, 1)

        debug.drawPattern(pattern, 0, 0, 16)

        t.expect(#mockDrawCalls).to_be(3)
        t.expect(mockDrawCalls[1].type).to_be("rect")
    end)

    t.it("converts pattern coords (0-indexed) to screen coords", function()
        local debug = setupMocks()
        local pattern = procgen.forma.pattern.new()
        pattern:insert(2, 3)

        debug.drawPattern(pattern, 100, 100, 32)

        -- Pattern (2,3) at 100,100 with cellSize 32
        -- Screen x = 100 + 2*32 = 164
        -- Screen y = 100 + 3*32 = 196
        t.expect(mockDrawCalls[1].cmd.x).to_be(164)
        t.expect(mockDrawCalls[1].cmd.y).to_be(196)
    end)

    t.it("accepts custom color", function()
        local debug = setupMocks()
        local pattern = procgen.forma.pattern.new()
        pattern:insert(0, 0)

        local customColor = {r = 128, g = 64, b = 32, a = 200}
        debug.drawPattern(pattern, 0, 0, 16, customColor)

        t.expect(mockDrawCalls[1].cmd.color.r).to_be(128)
        t.expect(mockDrawCalls[1].cmd.color.g).to_be(64)
    end)
end)

t.describe("procgen.debug drawGraph()", function()
    t.it("draws nothing when disabled", function()
        local debug = setupMocks()
        debug.enabled = false
        local builder = procgen.graph()
            :node("a", {x = 0, y = 0})
            :node("b", {x = 100, y = 0})
            :edge("a", "b")
        debug.drawGraph(builder)
        t.expect(#mockDrawCalls).to_be(0)
    end)

    t.it("draws circles for nodes", function()
        local debug = setupMocks()
        local builder = procgen.graph()
            :node("a", {x = 50, y = 50})
            :node("b", {x = 150, y = 50})

        debug.drawGraph(builder)

        local circles = {}
        for _, call in ipairs(mockDrawCalls) do
            if call.type == "circle" then
                table.insert(circles, call)
            end
        end
        t.expect(#circles).to_be(2)
    end)

    t.it("draws lines for edges", function()
        local debug = setupMocks()
        local builder = procgen.graph()
            :node("a", {x = 0, y = 0})
            :node("b", {x = 100, y = 0})
            :node("c", {x = 50, y = 100})
            :edge("a", "b")
            :edge("b", "c")

        debug.drawGraph(builder)

        local lines = {}
        for _, call in ipairs(mockDrawCalls) do
            if call.type == "line" then
                table.insert(lines, call)
            end
        end
        t.expect(#lines).to_be(2)
    end)

    t.it("uses node x,y for positioning", function()
        local debug = setupMocks()
        local builder = procgen.graph()
            :node("test", {x = 200, y = 300})

        debug.drawGraph(builder)

        local circle = nil
        for _, call in ipairs(mockDrawCalls) do
            if call.type == "circle" then
                circle = call
                break
            end
        end
        t.expect(circle).to_be_truthy()
        t.expect(circle.cmd.centerX).to_be(200)
        t.expect(circle.cmd.centerY).to_be(300)
    end)
end)

t.describe("procgen.debug drawInfluence()", function()
    t.it("draws nothing when disabled", function()
        local debug = setupMocks()
        debug.enabled = false
        local grid = procgen.Grid(5, 5, 0)
        debug.drawInfluence(grid, 0, 0, 16)
        t.expect(#mockDrawCalls).to_be(0)
    end)

    t.it("draws rectangles for each cell", function()
        local debug = setupMocks()
        local grid = procgen.Grid(3, 3, 0.5)
        debug.drawInfluence(grid, 0, 0, 16)
        t.expect(#mockDrawCalls).to_be(9)
    end)

    t.it("colors based on influence value", function()
        local debug = setupMocks()
        local grid = procgen.Grid(2, 2, 0)
        grid:set(1, 1, 0.0)  -- Low influence
        grid:set(2, 2, 1.0)  -- High influence

        debug.drawInfluence(grid, 0, 0, 16)

        -- Find the two different alpha values
        local alphas = {}
        for _, call in ipairs(mockDrawCalls) do
            alphas[call.cmd.color.a] = true
        end

        -- Should have at least 2 different alpha levels
        local count = 0
        for _ in pairs(alphas) do count = count + 1 end
        t.expect(count >= 2).to_be(true)
    end)

    t.it("accepts minValue and maxValue for normalization", function()
        local debug = setupMocks()
        local grid = procgen.Grid(2, 2, 50)  -- All values at 50

        debug.drawInfluence(grid, 0, 0, 16, 0, 100)

        -- All cells should have same alpha (50% of range)
        local firstAlpha = mockDrawCalls[1].cmd.color.a
        for _, call in ipairs(mockDrawCalls) do
            t.expect(call.cmd.color.a).to_be(firstAlpha)
        end
    end)
end)

t.describe("procgen.debug drawDungeon()", function()
    t.it("draws nothing when disabled", function()
        local debug = setupMocks()
        debug.enabled = false
        math.randomseed(12345)
        local dungeon = procgen.dungeon(30, 30)
            :generateRooms()
            :build()
        debug.drawDungeon(dungeon, 0, 0, 8)
        t.expect(#mockDrawCalls).to_be(0)
    end)

    t.it("draws grid and room outlines", function()
        local debug = setupMocks()
        math.randomseed(12345)
        local dungeon = procgen.dungeon(20, 20, {maxRooms = 3})
            :generateRooms()
            :connectRooms()
            :build()

        debug.drawDungeon(dungeon, 0, 0, 8)

        -- Should have grid cells (20*20=400) plus room outlines
        t.expect(#mockDrawCalls > 400).to_be(true)
    end)
end)

t.describe("procgen.debug color utilities", function()
    t.it("has predefined colors", function()
        local debug = setupMocks()
        t.expect(debug.colors.floor).to_be_truthy()
        t.expect(debug.colors.wall).to_be_truthy()
        t.expect(debug.colors.node).to_be_truthy()
        t.expect(debug.colors.edge).to_be_truthy()
    end)

    t.it("lerp() interpolates between colors", function()
        local debug = setupMocks()
        local c1 = {r = 0, g = 0, b = 0, a = 0}
        local c2 = {r = 100, g = 200, b = 50, a = 255}

        local mid = debug.lerp(c1, c2, 0.5)
        t.expect(mid.r).to_be(50)
        t.expect(mid.g).to_be(100)
        t.expect(mid.b).to_be(25)
    end)
end)

return t.run()
