-- assets/scripts/tests/test_procgen_init.lua
-- TDD: Tests for the main procgen entry point

local t = require("tests.test_runner")
t.reset()

local procgen = require("core.procgen")

t.describe("procgen (main module)", function()

    t.describe("library access", function()
        t.it("exposes Graph class", function()
            t.expect(procgen.Graph).to_be_truthy()
            t.expect(type(procgen.Graph.init)).to_be("function")
        end)

        t.it("exposes Grid class", function()
            t.expect(procgen.Grid).to_be_truthy()
            t.expect(type(procgen.Grid.init)).to_be("function")
        end)

        t.it("exposes forma table with submodules", function()
            t.expect(procgen.forma).to_be_truthy()
            t.expect(procgen.forma.pattern).to_be_truthy()
            t.expect(procgen.forma.cell).to_be_truthy()
            t.expect(procgen.forma.primitives).to_be_truthy()
            t.expect(procgen.forma.automata).to_be_truthy()
            t.expect(procgen.forma.neighbourhood).to_be_truthy()
            t.expect(procgen.forma.multipattern).to_be_truthy()
            t.expect(procgen.forma.raycasting).to_be_truthy()
        end)
    end)

    t.describe("coords access", function()
        t.it("exposes coords module", function()
            t.expect(procgen.coords).to_be_truthy()
            t.expect(type(procgen.coords.worldToGrid)).to_be("function")
            t.expect(type(procgen.coords.gridToWorld)).to_be("function")
            t.expect(type(procgen.coords.gridToWorldRect)).to_be("function")
            t.expect(type(procgen.coords.patternToGrid)).to_be("function")
            t.expect(type(procgen.coords.gridToPattern)).to_be("function")
        end)
    end)

    t.describe("ldtk_bridge access", function()
        t.it("exposes ldtk_bridge module", function()
            t.expect(procgen.ldtk_bridge).to_be_truthy()
            t.expect(type(procgen.ldtk_bridge.gridToIntGrid)).to_be("function")
            t.expect(type(procgen.ldtk_bridge.applyRules)).to_be("function")
            t.expect(type(procgen.ldtk_bridge.buildColliders)).to_be("function")
            t.expect(type(procgen.ldtk_bridge.cleanup)).to_be("function")
        end)
    end)

    t.describe("builder factory functions", function()
        t.it("has grid() factory returning GridBuilder", function()
            t.expect(type(procgen.grid)).to_be("function")
            -- Builder implementation comes in Phase 2, but factory should exist
        end)

        t.it("has graph() factory returning GraphBuilder", function()
            t.expect(type(procgen.graph)).to_be("function")
        end)

        t.it("has pattern() factory returning PatternBuilder", function()
            t.expect(type(procgen.pattern)).to_be("function")
        end)
    end)

    t.describe("Grid class usage", function()
        t.it("can create and use Grid instance", function()
            local grid = procgen.Grid(5, 5, 0)
            t.expect(grid.w).to_be(5)
            t.expect(grid.h).to_be(5)
            t.expect(grid:get(1, 1)).to_be(0)

            grid:set(3, 3, 7)
            t.expect(grid:get(3, 3)).to_be(7)
        end)
    end)

    t.describe("Graph class usage", function()
        t.it("can create and use Graph instance", function()
            local graph = procgen.Graph()
            graph:add_node("a")
            graph:add_node("b")
            graph:add_edge("a", "b")

            local neighbors = graph:get_node_neighbors("a")
            t.expect(#neighbors).to_be(1)
            t.expect(neighbors[1]).to_be("b")
        end)
    end)

    t.describe("forma pattern usage", function()
        t.it("can create and use forma pattern", function()
            local pattern = procgen.forma.pattern.new()
            pattern:insert(0, 0)
            pattern:insert(1, 1)

            t.expect(pattern:size()).to_be(2)
            t.expect(pattern:has_cell(0, 0)).to_be(true)
            t.expect(pattern:has_cell(1, 1)).to_be(true)
            t.expect(pattern:has_cell(2, 2)).to_be(false)
        end)
    end)

end)

return t.run()
