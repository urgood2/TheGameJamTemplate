-- assets/scripts/tests/test_tiled_capability_demo.lua
-- Tests for examples.tiled_capability_demo using mocked tiled bindings.

local t = require("tests.test_runner")
t.reset()

local function install_fake_tiled()
    local calls = {
        loaded_map = nil,
        active_map = nil,
        draw_all = 0,
        draw_all_ysorted = 0,
        draw_layer = 0,
        draw_layer_ysorted = 0,
        objects_requested = 0,
        spawned = 0,
        loaded_rules = {},
        applied_rules = {},
        colliders = 0,
    }

    local fakeObjects = {
        { id = 1, name = "hero_start", type = "PlayerSpawn", layer = "Objects", x = 32, y = 64 },
        { id = 2, name = "goblin_a", type = "Enemy", layer = "Objects", x = 96, y = 64 },
        { id = 3, name = "chest_a", type = "Loot", layer = "Objects", x = 160, y = 96 },
    }

    local spawner = nil

    local tiled = {}

    function tiled.load_map(path)
        calls.loaded_map = path
        return "demo_map"
    end

    function tiled.set_active_map(mapId)
        calls.active_map = mapId
    end

    function tiled.draw_all_layers(_, _)
        calls.draw_all = calls.draw_all + 1
        return 12
    end

    function tiled.draw_all_layers_ysorted(_, _)
        calls.draw_all_ysorted = calls.draw_all_ysorted + 1
        return 13
    end

    function tiled.draw_layer(_, _, _)
        calls.draw_layer = calls.draw_layer + 1
        return 4
    end

    function tiled.draw_layer_ysorted(_, _, _)
        calls.draw_layer_ysorted = calls.draw_layer_ysorted + 1
        return 5
    end

    function tiled.get_objects(_)
        calls.objects_requested = calls.objects_requested + 1
        return fakeObjects
    end

    function tiled.set_spawner(fn)
        spawner = fn
    end

    function tiled.spawn_objects(_)
        if not spawner then
            error("spawner not set")
        end
        for i = 1, #fakeObjects do
            spawner(fakeObjects[i])
        end
        calls.spawned = calls.spawned + #fakeObjects
        return #fakeObjects
    end

    function tiled.load_rule_defs(path)
        calls.loaded_rules[#calls.loaded_rules + 1] = path
        if string.find(path, "dungeon_mode", 1, true) then
            return "dungeon_mode_walls"
        end
        if string.find(path, "dungeon_437", 1, true) then
            return "dungeon_437_walls"
        end
        return "unknown_ruleset"
    end

    function tiled.apply_rules(grid, rulesetId)
        calls.applied_rules[#calls.applied_rules + 1] = rulesetId
        local cells = {}
        for i = 1, (grid.width * grid.height) do
            cells[i] = {
                {
                    tile_id = i,
                    flip_x = false,
                    flip_y = false,
                    rotation = 0,
                    offset_x = 0,
                    offset_y = 0,
                    opacity = 1.0,
                }
            }
        end
        return {
            width = grid.width,
            height = grid.height,
            cells = cells,
        }
    end

    function tiled.build_colliders_from_grid(_, _, _, _, _)
        calls.colliders = calls.colliders + 1
        return 9
    end

    function tiled.cleanup_procedural() end

    return tiled, calls
end

t.describe("examples.tiled_capability_demo", function()

    t.it("runs end-to-end capability flow including both required rulesets", function()
        local originalTiled = _G.tiled
        local fakeTiled, calls = install_fake_tiled()
        _G.tiled = fakeTiled
        package.loaded["examples.tiled_capability_demo"] = nil

        local ok, summary = pcall(function()
            local demo = require("examples.tiled_capability_demo")
            return demo.run({
                mapPath = "maps/demo.tmj",
                mapLayerName = "Ground",
                targetLayer = "background",
                printSummary = false,
            })
        end)

        _G.tiled = originalTiled
        t.expect(ok).to_be(true)
        t.expect(summary.map_id).to_be("demo_map")
        t.expect(summary.draw_all_count).to_be(12)
        t.expect(summary.draw_all_ysorted_count).to_be(13)
        t.expect(summary.draw_layer_count).to_be(4)
        t.expect(summary.draw_layer_ysorted_count).to_be(5)
        t.expect(summary.object_count).to_be(3)
        t.expect(summary.spawn_count).to_be(3)
        t.expect(summary.procedural_collider_count).to_be(9)
        t.expect(summary.ruleset_count).to_be(2)
        t.expect(type(summary.rulesets)).to_be("table")
        t.expect(#summary.rulesets).to_be(2)

        t.expect(calls.loaded_map).to_be("maps/demo.tmj")
        t.expect(calls.active_map).to_be("demo_map")
        t.expect(calls.draw_all).to_be(1)
        t.expect(calls.draw_all_ysorted).to_be(1)
        t.expect(calls.draw_layer).to_be(1)
        t.expect(calls.draw_layer_ysorted).to_be(1)
        t.expect(calls.objects_requested).to_be(1)
        t.expect(calls.spawned).to_be(3)
        t.expect(#calls.loaded_rules).to_be(2)
        t.expect(calls.loaded_rules[1]).to_contain("dungeon_mode_walls.rules.txt")
        t.expect(calls.loaded_rules[2]).to_contain("dungeon_437_walls.rules.txt")
        t.expect(#calls.applied_rules).to_be(2)
        t.expect(calls.applied_rules[1]).to_be("dungeon_mode_walls")
        t.expect(calls.applied_rules[2]).to_be("dungeon_437_walls")
        t.expect(calls.colliders).to_be(1)
    end)

    t.it("fails fast when tiled bindings are unavailable", function()
        local originalTiled = _G.tiled
        _G.tiled = nil
        package.loaded["examples.tiled_capability_demo"] = nil

        local demo = require("examples.tiled_capability_demo")
        local ok, err = pcall(function()
            demo.run({ printSummary = false })
        end)

        _G.tiled = originalTiled
        t.expect(ok).to_be(false)
        t.expect(err).to_contain("tiled")
    end)

    t.it("loads rules from catalog for procedural autotiling when enabled", function()
        local originalTiled = _G.tiled
        local fakeTiled, calls = install_fake_tiled()
        _G.tiled = fakeTiled
        package.loaded["examples.tiled_capability_demo"] = nil

        local catalogPath = "tests/out/tiled_demo_rules_catalog_test.json"
        local handle = io.open(catalogPath, "w")
        t.expect(handle ~= nil).to_be(true)
        handle:write([[
{
  "schema_version": "1.0",
  "rulesets": [
    { "id": "dm_canonical", "mode": "canonical", "source": "dungeon_mode", "rules_path": "planning/tiled_assets/rulesets/dungeon_mode_walls.rules.txt" },
    { "id": "dm_fill", "mode": "single_tile_fill", "source": "dungeon_mode", "rules_path": "planning/tiled_assets/rulesets/generated/dungeon_mode_dm_196_wall_stone_fill.rules.txt" },
    { "id": "d437_fill", "mode": "single_tile_fill", "source": "dungeon_437", "rules_path": "planning/tiled_assets/rulesets/generated/dungeon_437_d437_197_box_cross_fill.rules.txt" }
  ]
}
]])
        handle:close()

        local ok, summary = pcall(function()
            local demo = require("examples.tiled_capability_demo")
            return demo.run({
                drawMap = false,
                spawnObjects = false,
                buildProceduralColliders = false,
                printSummary = false,
                useRulesCatalog = true,
                rulesCatalogPath = catalogPath,
                rulesCatalogIncludeModes = { "single_tile_fill" },
                rulesCatalogLimit = 2,
            })
        end)

        os.remove(catalogPath)
        _G.tiled = originalTiled

        t.expect(ok).to_be(true)
        t.expect(summary.ruleset_count).to_be(2)
        t.expect(summary.rules_catalog_error).to_be(nil)
        t.expect(#calls.loaded_rules).to_be(2)
        t.expect(calls.loaded_rules[1]).to_contain("generated/")
        t.expect(calls.loaded_rules[2]).to_contain("generated/")
    end)

end)

return t.run()
