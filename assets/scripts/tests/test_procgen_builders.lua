-- assets/scripts/tests/test_procgen_builders.lua
-- TDD: Tests written FIRST for Phase 2 Builders

local t = require("tests.test_runner")
t.reset()

local procgen = require("core.procgen")

t.describe("GridBuilder", function()
    local GridBuilder = require("core.procgen.grid_builder")

    t.describe("construction", function()
        t.it("creates builder with dimensions and default value", function()
            local builder = GridBuilder.new(10, 10, 0)
            t.expect(builder).to_be_truthy()
            t.expect(builder._w).to_be(10)
            t.expect(builder._h).to_be(10)
            t.expect(builder._default).to_be(0)
        end)

        t.it("defaults fill value to 0", function()
            local builder = GridBuilder.new(5, 5)
            t.expect(builder._default).to_be(0)
        end)
    end)

    t.describe("fluent API", function()
        t.it("fill() returns self for chaining", function()
            local builder = GridBuilder.new(5, 5, 0)
            local result = builder:fill(1)
            t.expect(result).to_be(builder)
        end)

        t.it("rect() returns self for chaining", function()
            local builder = GridBuilder.new(10, 10, 0)
            local result = builder:rect(1, 1, 5, 5, 1)
            t.expect(result).to_be(builder)
        end)

        t.it("circle() returns self for chaining", function()
            local builder = GridBuilder.new(20, 20, 0)
            local result = builder:circle(10, 10, 5, 1)
            t.expect(result).to_be(builder)
        end)

        t.it("supports method chaining", function()
            local builder = GridBuilder.new(20, 20, 0)
            local result = builder
                :fill(0)
                :rect(5, 5, 10, 10, 1)
                :circle(10, 10, 3, 2)
            t.expect(result).to_be(builder)
        end)
    end)

    t.describe("fill()", function()
        t.it("fills entire grid with value", function()
            local grid = GridBuilder.new(3, 3, 0)
                :fill(5)
                :build()

            t.expect(grid:get(1, 1)).to_be(5)
            t.expect(grid:get(2, 2)).to_be(5)
            t.expect(grid:get(3, 3)).to_be(5)
        end)
    end)

    t.describe("rect()", function()
        t.it("draws filled rectangle", function()
            local grid = GridBuilder.new(10, 10, 0)
                :rect(2, 2, 4, 4, 1)
                :build()

            -- Inside rectangle
            t.expect(grid:get(2, 2)).to_be(1)
            t.expect(grid:get(3, 3)).to_be(1)
            t.expect(grid:get(5, 5)).to_be(1)
            -- Outside rectangle
            t.expect(grid:get(1, 1)).to_be(0)
            t.expect(grid:get(6, 6)).to_be(0)
        end)
    end)

    t.describe("circle()", function()
        t.it("draws filled circle", function()
            local grid = GridBuilder.new(20, 20, 0)
                :circle(10, 10, 3, 1)
                :build()

            -- Center should be filled
            t.expect(grid:get(10, 10)).to_be(1)
            -- Points within radius should be filled
            t.expect(grid:get(10, 8)).to_be(1)  -- Above center
            t.expect(grid:get(10, 12)).to_be(1) -- Below center
            -- Points outside radius should not be filled
            t.expect(grid:get(1, 1)).to_be(0)
            t.expect(grid:get(20, 20)).to_be(0)
        end)
    end)

    t.describe("noise()", function()
        t.it("fills cells randomly based on density", function()
            -- Seed for reproducibility
            math.randomseed(12345)
            local grid = GridBuilder.new(10, 10, 0)
                :noise(0.5, {1})
                :build()

            -- Count filled cells
            local count = 0
            for x = 1, 10 do
                for y = 1, 10 do
                    if grid:get(x, y) == 1 then
                        count = count + 1
                    end
                end
            end
            -- With 50% density, should have roughly 50 cells filled
            t.expect(count > 20).to_be(true)
            t.expect(count < 80).to_be(true)
        end)
    end)

    t.describe("stamp()", function()
        t.it("pastes another grid at position", function()
            local stamp = procgen.Grid(2, 2, 9)
            local grid = GridBuilder.new(10, 10, 0)
                :stamp(stamp, 3, 3)
                :build()

            -- Stamped area
            t.expect(grid:get(3, 3)).to_be(9)
            t.expect(grid:get(4, 4)).to_be(9)
            -- Outside stamp
            t.expect(grid:get(1, 1)).to_be(0)
            t.expect(grid:get(5, 5)).to_be(0)
        end)
    end)

    t.describe("apply()", function()
        t.it("applies custom function to cells", function()
            local grid = GridBuilder.new(5, 5, 1)
                :apply(function(g, x, y)
                    if x == y then
                        g:set(x, y, 9)
                    end
                end)
                :build()

            -- Diagonal should be 9
            t.expect(grid:get(1, 1)).to_be(9)
            t.expect(grid:get(2, 2)).to_be(9)
            t.expect(grid:get(3, 3)).to_be(9)
            -- Off-diagonal should remain 1
            t.expect(grid:get(1, 2)).to_be(1)
            t.expect(grid:get(2, 1)).to_be(1)
        end)
    end)

    t.describe("build()", function()
        t.it("returns a Grid instance", function()
            local grid = GridBuilder.new(5, 5, 0):build()
            t.expect(grid.w).to_be(5)
            t.expect(grid.h).to_be(5)
            t.expect(type(grid.get)).to_be("function")
            t.expect(type(grid.set)).to_be("function")
        end)
    end)

    t.describe("findIslands()", function()
        t.it("finds connected components with value", function()
            local builder = GridBuilder.new(10, 10, 0)
                :rect(1, 1, 2, 2, 1)  -- Island 1
                :rect(5, 5, 3, 3, 1)  -- Island 2

            local islands = builder:findIslands(1)
            t.expect(#islands >= 2).to_be(true)
        end)
    end)
end)

t.describe("GraphBuilder", function()
    local GraphBuilder = require("core.procgen.graph_builder")

    t.describe("construction", function()
        t.it("creates empty builder", function()
            local builder = GraphBuilder.new()
            t.expect(builder).to_be_truthy()
        end)
    end)

    t.describe("fluent API", function()
        t.it("node() returns self for chaining", function()
            local builder = GraphBuilder.new()
            local result = builder:node("a", {x = 0})
            t.expect(result).to_be(builder)
        end)

        t.it("edge() returns self for chaining", function()
            local builder = GraphBuilder.new()
            local result = builder:node("a"):node("b"):edge("a", "b")
            t.expect(result).to_be(builder)
        end)

        t.it("supports method chaining", function()
            local builder = GraphBuilder.new()
            local result = builder
                :node("a", {x = 0, y = 0})
                :node("b", {x = 10, y = 0})
                :node("c", {x = 5, y = 10})
                :edge("a", "b")
                :edge("b", "c")
                :edge("c", "a")
            t.expect(result).to_be(builder)
        end)
    end)

    t.describe("node()", function()
        t.it("adds node with data", function()
            local graph = GraphBuilder.new()
                :node("room1", {type = "spawn", x = 0, y = 0})
                :build()

            local node = graph:get_node_by_property("type", "spawn")
            t.expect(node).to_be_truthy()
            t.expect(node.x).to_be(0)
        end)
    end)

    t.describe("edge()", function()
        t.it("connects two nodes", function()
            local builder = GraphBuilder.new()
                :node("a")
                :node("b")
                :edge("a", "b")

            -- Use builder's neighbors method which handles ID lookup
            local neighbors = builder:neighbors("a")
            t.expect(#neighbors).to_be(1)
        end)
    end)

    t.describe("build()", function()
        t.it("returns a Graph instance", function()
            local graph = GraphBuilder.new()
                :node("start")
                :node("end")
                :edge("start", "end")
                :build()

            t.expect(type(graph.add_node)).to_be("function")
            t.expect(type(graph.add_edge)).to_be("function")
            t.expect(type(graph.shortest_path_bfs)).to_be("function")
        end)
    end)

    t.describe("shortestPath()", function()
        t.it("finds shortest path between nodes", function()
            local builder = GraphBuilder.new()
                :node("a")
                :node("b")
                :node("c")
                :edge("a", "b")
                :edge("b", "c")

            local path = builder:shortestPath("a", "c")
            t.expect(#path).to_be(3)  -- a -> b -> c
        end)
    end)

    t.describe("neighbors()", function()
        t.it("returns neighbors of a node", function()
            local builder = GraphBuilder.new()
                :node("center")
                :node("n1")
                :node("n2")
                :edge("center", "n1")
                :edge("center", "n2")

            local neighbors = builder:neighbors("center")
            t.expect(#neighbors).to_be(2)
        end)
    end)
end)

t.describe("PatternBuilder", function()
    local PatternBuilder = require("core.procgen.pattern_builder")

    t.describe("construction", function()
        t.it("creates empty builder", function()
            local builder = PatternBuilder.new()
            t.expect(builder).to_be_truthy()
        end)
    end)

    t.describe("fluent API", function()
        t.it("square() returns self for chaining", function()
            local builder = PatternBuilder.new()
            local result = builder:square(10, 10)
            t.expect(result).to_be(builder)
        end)

        t.it("supports method chaining", function()
            local builder = PatternBuilder.new()
            local result = builder
                :square(20, 20)
                :sample(100)
            t.expect(result).to_be(builder)
        end)
    end)

    t.describe("square()", function()
        t.it("creates rectangular domain", function()
            local pattern = PatternBuilder.new()
                :square(5, 3)
                :build()

            t.expect(pattern:size()).to_be(15)  -- 5 * 3
            t.expect(pattern:has_cell(0, 0)).to_be(true)
            t.expect(pattern:has_cell(4, 2)).to_be(true)
            t.expect(pattern:has_cell(5, 0)).to_be(false)
        end)
    end)

    t.describe("sample()", function()
        t.it("samples random cells from domain", function()
            math.randomseed(12345)
            local pattern = PatternBuilder.new()
                :square(20, 20)
                :sample(50)
                :build()

            -- Sample should reduce cell count
            t.expect(pattern:size()).to_be(50)
        end)
    end)

    t.describe("automata()", function()
        t.it("applies cellular automata rules", function()
            math.randomseed(12345)
            local pattern = PatternBuilder.new()
                :square(20, 20)
                :sample(200)
                :automata("B5678/S45678", 5)
                :build()

            -- After CA, pattern should have changed
            t.expect(pattern:size() > 0).to_be(true)
        end)
    end)

    t.describe("erode()", function()
        t.it("applies erosion morphology", function()
            local pattern = PatternBuilder.new()
                :square(10, 10)
                :erode()
                :build()

            -- Erosion shrinks the pattern
            t.expect(pattern:size() < 100).to_be(true)
        end)
    end)

    t.describe("dilate()", function()
        t.it("applies dilation morphology", function()
            local builder = PatternBuilder.new()
            builder._pattern = procgen.forma.pattern.new()
            builder._pattern:insert(5, 5)

            local pattern = builder:dilate():build()

            -- Dilation expands the single cell
            t.expect(pattern:size() > 1).to_be(true)
        end)
    end)

    t.describe("keepLargest()", function()
        t.it("keeps only largest connected component", function()
            local builder = PatternBuilder.new()
            builder._pattern = procgen.forma.pattern.new()
            -- Create two separate regions
            -- Region 1: 4 cells
            builder._pattern:insert(0, 0)
            builder._pattern:insert(1, 0)
            builder._pattern:insert(0, 1)
            builder._pattern:insert(1, 1)
            -- Region 2: 1 cell (isolated)
            builder._pattern:insert(10, 10)

            local pattern = builder:keepLargest():build()

            -- Should only have the larger region (4 cells)
            t.expect(pattern:size()).to_be(4)
            t.expect(pattern:has_cell(0, 0)).to_be(true)
            t.expect(pattern:has_cell(10, 10)).to_be(false)
        end)
    end)

    t.describe("translate()", function()
        t.it("shifts pattern by offset", function()
            local pattern = PatternBuilder.new()
                :square(2, 2)
                :translate(5, 5)
                :build()

            -- Original (0,0) should now be at (5,5)
            t.expect(pattern:has_cell(0, 0)).to_be(false)
            t.expect(pattern:has_cell(5, 5)).to_be(true)
            t.expect(pattern:has_cell(6, 6)).to_be(true)
        end)
    end)

    t.describe("build()", function()
        t.it("returns a forma pattern", function()
            local pattern = PatternBuilder.new()
                :square(5, 5)
                :build()

            t.expect(type(pattern.insert)).to_be("function")
            t.expect(type(pattern.has_cell)).to_be("function")
            t.expect(type(pattern.cells)).to_be("function")
        end)
    end)

    t.describe("cells()", function()
        t.it("returns iterator over cells", function()
            local builder = PatternBuilder.new():square(3, 3)
            local count = 0
            for cell in builder:cells() do
                count = count + 1
            end
            t.expect(count).to_be(9)
        end)
    end)

    t.describe("components()", function()
        t.it("returns connected components", function()
            local builder = PatternBuilder.new()
            builder._pattern = procgen.forma.pattern.new()
            builder._pattern:insert(0, 0)
            builder._pattern:insert(1, 0)
            builder._pattern:insert(5, 5)  -- Separate component

            local comps = builder:components()
            t.expect(#comps >= 2).to_be(true)
        end)
    end)
end)

t.describe("procgen factory functions return builders", function()
    t.it("procgen.grid() returns builder-like object", function()
        local result = procgen.grid(10, 10, 0)
        -- After Phase 2, this should have builder methods
        -- For now, just verify it's usable
        t.expect(result).to_be_truthy()
    end)

    t.it("procgen.graph() returns builder-like object", function()
        local result = procgen.graph()
        t.expect(result).to_be_truthy()
    end)

    t.it("procgen.pattern() returns builder-like object", function()
        local result = procgen.pattern()
        t.expect(result).to_be_truthy()
    end)
end)

return t.run()
