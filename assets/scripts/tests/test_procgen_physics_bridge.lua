-- assets/scripts/tests/test_procgen_physics_bridge.lua
-- TDD: Tests written FIRST for Phase 3 Physics Bridge module
-- Note: physics_bridge delegates to C++ LDtk bindings, so we test structure
-- and mock the bindings where needed.

local t = require("tests.test_runner")
t.reset()

local procgen = require("core.procgen")

t.describe("physics_bridge module", function()
    local physics_bridge = require("core.procgen.physics_bridge")

    t.describe("module structure", function()
        t.it("exports buildColliders function", function()
            t.expect(type(physics_bridge.buildColliders)).to_be("function")
        end)
    end)

    t.describe("buildColliders()", function()
        t.it("requires ldtk bindings to be available", function()
            -- Save original
            local original_ldtk = _G.ldtk

            -- Remove ldtk binding to test assertion
            _G.ldtk = nil

            local grid = procgen.Grid(5, 5, 1)
            local success, err = pcall(function()
                physics_bridge.buildColliders(grid)
            end)

            -- Restore
            _G.ldtk = original_ldtk

            -- Should fail without ldtk
            t.expect(success).to_be(false)
            t.expect(err:find("ldtk") ~= nil).to_be(true)
        end)

        t.it("calls ldtk.build_colliders_from_grid with correct args", function()
            -- Save original
            local original_ldtk = _G.ldtk

            -- Mock ldtk binding
            local captured = {}
            _G.ldtk = {
                build_colliders_from_grid = function(gridTable, worldName, physicsTag, solidValues)
                    captured.gridTable = gridTable
                    captured.worldName = worldName
                    captured.physicsTag = physicsTag
                    captured.solidValues = solidValues
                end
            }

            local grid = procgen.Grid(5, 5, 1)
            physics_bridge.buildColliders(grid, {
                worldName = "test_world",
                physicsTag = "TEST_TAG",
                solidValues = {1, 2}
            })

            -- Restore
            _G.ldtk = original_ldtk

            t.expect(captured.worldName).to_be("test_world")
            t.expect(captured.physicsTag).to_be("TEST_TAG")
            t.expect(#captured.solidValues).to_be(2)
            t.expect(captured.gridTable.width).to_be(5)
            t.expect(captured.gridTable.height).to_be(5)
        end)

        t.it("uses default options when not provided", function()
            -- Save original
            local original_ldtk = _G.ldtk

            -- Mock ldtk binding
            local captured = {}
            _G.ldtk = {
                build_colliders_from_grid = function(gridTable, worldName, physicsTag, solidValues)
                    captured.worldName = worldName
                    captured.physicsTag = physicsTag
                    captured.solidValues = solidValues
                end
            }

            local grid = procgen.Grid(3, 3, 0)
            physics_bridge.buildColliders(grid)

            -- Restore
            _G.ldtk = original_ldtk

            t.expect(captured.worldName).to_be("world")
            t.expect(captured.physicsTag).to_be("WORLD")
            t.expect(#captured.solidValues).to_be(1)
            t.expect(captured.solidValues[1]).to_be(1)
        end)
    end)
end)

return t.run()
