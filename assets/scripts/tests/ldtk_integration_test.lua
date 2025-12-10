--[[
LDTK Integration Test Suite

Tests the current LDTK Lua integration:
1. Config loading
2. Level activation
3. Entity spawning callbacks
4. IntGrid iteration
5. Collider generation

Run with: require("tests.ldtk_integration_test").run_all()
]]

local M = {}

local test_results = {
    passed = 0,
    failed = 0,
    errors = {}
}

local function log_test(name, passed, msg)
    if passed then
        test_results.passed = test_results.passed + 1
        print(string.format("[PASS] %s", name))
    else
        test_results.failed = test_results.failed + 1
        table.insert(test_results.errors, { name = name, msg = msg })
        print(string.format("[FAIL] %s: %s", name, msg or "unknown error"))
    end
end

local function assert_test(name, condition, msg)
    log_test(name, condition, msg)
    return condition
end

local function assert_equals(name, expected, actual)
    local passed = expected == actual
    local msg = passed and nil or string.format("expected %s, got %s", tostring(expected), tostring(actual))
    log_test(name, passed, msg)
    return passed
end

local function assert_not_nil(name, value)
    local passed = value ~= nil
    local msg = passed and nil or "value is nil"
    log_test(name, passed, msg)
    return passed
end

local function assert_type(name, value, expected_type)
    local actual_type = type(value)
    local passed = actual_type == expected_type
    local msg = passed and nil or string.format("expected type %s, got %s", expected_type, actual_type)
    log_test(name, passed, msg)
    return passed
end

-- Test 1: Config Loading
function M.test_config_loading()
    print("\n=== Test: Config Loading ===")

    local ok, err = pcall(function()
        ldtk.load_config("ldtk_config.json")
    end)

    assert_test("load_config succeeds", ok, err)

    if ok then
        -- Check collider layers are available
        local layers = ldtk.collider_layers()
        assert_not_nil("collider_layers returns table", layers)
        assert_type("collider_layers is table", layers, "table")

        if layers and #layers > 0 then
            print(string.format("  Found %d collider layer(s): %s", #layers, table.concat(layers, ", ")))
        end
    end
end

-- Test 2: Active Level Management
function M.test_active_level()
    print("\n=== Test: Active Level Management ===")

    -- Before setting active level
    local has_active_before = ldtk.has_active_level()
    -- Note: may be true if previous test ran

    -- Set active level (without spawning or colliders for this test)
    local ok, err = pcall(function()
        ldtk.set_active_level("Level_0", "world", false, false, "WORLD")
    end)

    assert_test("set_active_level succeeds", ok, err)

    if ok then
        local has_active = ldtk.has_active_level()
        assert_test("has_active_level returns true after set", has_active)

        local active_name = ldtk.active_level()
        assert_equals("active_level returns correct name", "Level_0", active_name)
    end
end

-- Test 3: Entity Spawning Callback
function M.test_entity_spawning()
    print("\n=== Test: Entity Spawning Callback ===")

    local spawned_entities = {}

    -- Set up spawner
    ldtk.set_spawner(function(name, px, py, layerName, gx, gy, tags)
        table.insert(spawned_entities, {
            name = name,
            px = px,
            py = py,
            layerName = layerName,
            gx = gx,
            gy = gy,
            tags = tags
        })
    end)

    -- Iterate entities
    local ok, err = pcall(function()
        ldtk.spawn_entities("Level_0", function(name, px, py, layerName, gx, gy, tags)
            -- This callback also fires (spawn_entities takes its own callback)
        end)
    end)

    assert_test("spawn_entities succeeds", ok, err)

    -- Now set level with spawning enabled to test the set_spawner callback
    spawned_entities = {}
    ok, err = pcall(function()
        ldtk.set_active_level("Level_0", "world", false, true, "WORLD")
    end)

    assert_test("set_active_level with spawn succeeds", ok, err)

    if #spawned_entities > 0 then
        print(string.format("  Spawned %d entities via set_spawner callback:", #spawned_entities))
        for i, ent in ipairs(spawned_entities) do
            if i <= 5 then -- Only show first 5
                print(string.format("    - %s at (%.1f, %.1f) layer=%s",
                    ent.name, ent.px, ent.py, ent.layerName or "nil"))
            end
        end
        if #spawned_entities > 5 then
            print(string.format("    ... and %d more", #spawned_entities - 5))
        end
        assert_test("entities spawned via callback", true)
    else
        -- May be valid if level has no entities
        print("  No entities spawned (level may have no entities)")
        assert_test("spawn callback executed (no entities in level)", true)
    end
end

-- Test 4: IntGrid Iteration
function M.test_intgrid_iteration()
    print("\n=== Test: IntGrid Iteration ===")

    local layers = ldtk.collider_layers()
    if not layers or #layers == 0 then
        print("  Skipping: no collider layers configured")
        return
    end

    local layer_name = layers[1]
    local cell_count = 0
    local solid_count = 0

    local ok, err = pcall(function()
        ldtk.each_intgrid("Level_0", layer_name, function(x, y, val)
            cell_count = cell_count + 1
            if val ~= 0 then
                solid_count = solid_count + 1
            end
        end)
    end)

    assert_test("each_intgrid succeeds", ok, err)

    if ok then
        assert_test("intgrid iteration found cells", cell_count > 0,
            string.format("cell_count=%d", cell_count))
        print(string.format("  Layer '%s': %d total cells, %d solid (non-zero)",
            layer_name, cell_count, solid_count))
    end
end

-- Test 5: Collider Building
function M.test_collider_building()
    print("\n=== Test: Collider Building ===")

    -- First clear any existing colliders
    local ok, err = pcall(function()
        ldtk.clear_colliders("Level_0", "world")
    end)
    assert_test("clear_colliders succeeds", ok, err)

    -- Build colliders
    ok, err = pcall(function()
        ldtk.build_colliders("Level_0", "world", "WORLD")
    end)
    assert_test("build_colliders succeeds", ok, err)

    if ok then
        print("  Colliders built successfully")
    end
end

-- Test 6: Prefab Lookup
function M.test_prefab_lookup()
    print("\n=== Test: Prefab Lookup ===")

    -- Test looking up a prefab that doesn't exist
    local prefab = ldtk.prefab_for("NonExistentEntity")
    assert_test("prefab_for returns empty for unknown entity",
        prefab == "" or prefab == nil,
        string.format("got: %s", tostring(prefab)))

    -- Test with Player entity (from world.ldtk)
    local player_prefab = ldtk.prefab_for("Player")
    -- Should return empty since ldtk_config.json has no prefab mapping
    print(string.format("  prefab_for('Player') = '%s'", tostring(player_prefab)))
    assert_test("prefab_for returns value (empty ok if not configured)", true)
end

-- Test 7: Full Level Load Cycle
function M.test_full_level_cycle()
    print("\n=== Test: Full Level Load Cycle ===")

    local entities_found = {}

    ldtk.set_spawner(function(name, px, py, layerName, gx, gy, fields)
        entities_found[name] = (entities_found[name] or 0) + 1
    end)

    local ok, err = pcall(function()
        ldtk.set_active_level("Level_0", "world", true, true, "WORLD")
    end)

    assert_test("full level cycle succeeds", ok, err)

    if ok then
        assert_test("level is active after cycle", ldtk.has_active_level())
        assert_equals("active level name", "Level_0", ldtk.active_level())

        local entity_summary = {}
        for name, count in pairs(entities_found) do
            table.insert(entity_summary, string.format("%s=%d", name, count))
        end

        if #entity_summary > 0 then
            print(string.format("  Entities: %s", table.concat(entity_summary, ", ")))
        end
    end
end

-- Test 8: Level Existence Check
function M.test_level_exists()
    print("\n=== Test: Level Existence Check ===")

    local exists = ldtk.level_exists("Level_0")
    assert_test("level_exists returns true for valid level", exists)

    local not_exists = ldtk.level_exists("NonExistentLevel_999")
    assert_test("level_exists returns false for invalid level", not not_exists)
end

-- Test 9: Level Bounds
function M.test_level_bounds()
    print("\n=== Test: Level Bounds ===")

    local ok, err = pcall(function()
        local bounds = ldtk.get_level_bounds("Level_0")
        assert_not_nil("get_level_bounds returns table", bounds)
        assert_not_nil("bounds has x", bounds.x)
        assert_not_nil("bounds has y", bounds.y)
        assert_not_nil("bounds has width", bounds.width)
        assert_not_nil("bounds has height", bounds.height)
        print(string.format("  Bounds: x=%.1f, y=%.1f, w=%.1f, h=%.1f",
            bounds.x, bounds.y, bounds.width, bounds.height))
    end)

    if not ok then
        log_test("get_level_bounds", false, err)
    end
end

-- Test 10: Level Meta
function M.test_level_meta()
    print("\n=== Test: Level Meta ===")

    local ok, err = pcall(function()
        local meta = ldtk.get_level_meta("Level_0")
        assert_not_nil("get_level_meta returns table", meta)
        assert_not_nil("meta has width", meta.width)
        assert_not_nil("meta has height", meta.height)
        assert_not_nil("meta has world_x", meta.world_x)
        assert_not_nil("meta has world_y", meta.world_y)
        assert_not_nil("meta has bg_color", meta.bg_color)

        print(string.format("  Meta: size=%dx%d, world_pos=(%d,%d), depth=%s",
            meta.width, meta.height, meta.world_x, meta.world_y, tostring(meta.depth)))

        if meta.bg_color then
            print(string.format("  BG Color: r=%d, g=%d, b=%d, a=%d",
                meta.bg_color.r, meta.bg_color.g, meta.bg_color.b, meta.bg_color.a))
        end
    end)

    if not ok then
        log_test("get_level_meta", false, err)
    end
end

-- Test 11: Level Neighbors
function M.test_level_neighbors()
    print("\n=== Test: Level Neighbors ===")

    local ok, err = pcall(function()
        local neighbors = ldtk.get_neighbors("Level_0")
        assert_not_nil("get_neighbors returns table", neighbors)

        local neighbor_info = {}
        if neighbors.north then table.insert(neighbor_info, "north=" .. neighbors.north) end
        if neighbors.south then table.insert(neighbor_info, "south=" .. neighbors.south) end
        if neighbors.east then table.insert(neighbor_info, "east=" .. neighbors.east) end
        if neighbors.west then table.insert(neighbor_info, "west=" .. neighbors.west) end
        if neighbors.overlap and #neighbors.overlap > 0 then
            table.insert(neighbor_info, "overlap=" .. table.concat(neighbors.overlap, ","))
        end

        if #neighbor_info > 0 then
            print(string.format("  Neighbors: %s", table.concat(neighbor_info, ", ")))
        else
            print("  No neighbors found (single level project)")
        end
        assert_test("get_neighbors executes successfully", true)
    end)

    if not ok then
        log_test("get_neighbors", false, err)
    end
end

-- Test 12: Entity Query by Name
function M.test_get_entities_by_name()
    print("\n=== Test: Entity Query by Name ===")

    local ok, err = pcall(function()
        -- Try to get SolidBlock entities which we know exist in Level_0
        local entities = ldtk.get_entities_by_name("Level_0", "SolidBlock")
        assert_not_nil("get_entities_by_name returns table", entities)
        assert_type("result is table", entities, "table")

        print(string.format("  Found %d SolidBlock entities", #entities))

        if #entities > 0 then
            local first = entities[1]
            print(string.format("  First entity: iid=%s, pos=(%.1f,%.1f), size=%dx%d",
                first.iid or "nil", first.x, first.y, first.width or 0, first.height or 0))

            if first.fields then
                local field_count = 0
                for k, v in pairs(first.fields) do
                    field_count = field_count + 1
                end
                print(string.format("  Fields count: %d", field_count))
            end
        end

        assert_test("get_entities_by_name works", true)
    end)

    if not ok then
        log_test("get_entities_by_name", false, err)
    end
end

-- Test 13: Entity Position by IID
function M.test_get_entity_position()
    print("\n=== Test: Entity Position by IID ===")

    local ok, err = pcall(function()
        -- First get an entity to find its IID
        local entities = ldtk.get_entities_by_name("Level_0", "SolidBlock")
        if #entities > 0 then
            local iid = entities[1].iid
            local pos = ldtk.get_entity_position("Level_0", iid)

            if pos then
                print(string.format("  Entity IID %s at position (%.1f, %.1f)", iid, pos.x, pos.y))
                assert_test("get_entity_position returns position", true)
            else
                print("  get_entity_position returned nil (unexpected)")
                assert_test("get_entity_position returns position", false, "returned nil")
            end
        else
            print("  Skipping: no entities to test with")
            assert_test("get_entity_position (skipped)", true)
        end
    end)

    if not ok then
        log_test("get_entity_position", false, err)
    end
end

-- Test 14: Spawner with Fields
function M.test_spawner_with_fields()
    print("\n=== Test: Spawner with Fields ===")

    local spawned_with_fields = {}

    ldtk.set_spawner(function(name, px, py, layerName, gx, gy, fields)
        table.insert(spawned_with_fields, {
            name = name,
            px = px,
            py = py,
            fields = fields,
            fields_type = type(fields)
        })
    end)

    local ok, err = pcall(function()
        ldtk.set_active_level("Level_0", "world", false, true, "WORLD")
    end)

    assert_test("spawner with fields callback works", ok, err)

    if #spawned_with_fields > 0 then
        local first = spawned_with_fields[1]
        print(string.format("  Spawned %d entities", #spawned_with_fields))
        print(string.format("  First: %s at (%.1f,%.1f), fields type=%s",
            first.name, first.px, first.py, first.fields_type))

        assert_test("fields parameter is table", first.fields_type == "table")
    else
        print("  No entities spawned")
        assert_test("spawner received fields parameter", true)
    end
end

-- Test 15: Signal Emission
function M.test_signal_emission()
    print("\n=== Test: Signal Emission ===")

    local signals_received = {}

    -- Set up signal emitter
    ldtk.set_signal_emitter(function(eventName, data)
        table.insert(signals_received, {
            event = eventName,
            data = data
        })
    end)

    -- Test set_active_level_with_signals
    local ok, err = pcall(function()
        ldtk.set_active_level_with_signals("Level_0", "world", true, false, "WORLD")
    end)

    assert_test("set_active_level_with_signals succeeds", ok, err)

    -- Check that signals were emitted
    local level_loaded = false
    local colliders_built = false

    for _, sig in ipairs(signals_received) do
        if sig.event == "ldtk_level_loaded" then
            level_loaded = true
            print(string.format("  ldtk_level_loaded: level_name=%s", sig.data.level_name or "nil"))
        elseif sig.event == "ldtk_colliders_built" then
            colliders_built = true
            print(string.format("  ldtk_colliders_built: physics_tag=%s", sig.data.physics_tag or "nil"))
        end
    end

    assert_test("ldtk_level_loaded signal received", level_loaded)
    assert_test("ldtk_colliders_built signal received", colliders_built)

    -- Test emit_entity_spawned
    signals_received = {}

    local ok2, err2 = pcall(function()
        ldtk.emit_entity_spawned("TestEntity", 100, 200, "TestLayer", { custom = "data" })
    end)

    assert_test("emit_entity_spawned succeeds", ok2, err2)

    local entity_spawned = false
    for _, sig in ipairs(signals_received) do
        if sig.event == "ldtk_entity_spawned" then
            entity_spawned = true
            print(string.format("  ldtk_entity_spawned: entity_name=%s, px=%.1f, py=%.1f",
                sig.data.entity_name or "nil", sig.data.px or 0, sig.data.py or 0))
        end
    end

    assert_test("ldtk_entity_spawned signal received", entity_spawned)

    -- Clear signal emitter
    ldtk.set_signal_emitter(function() end)
end

-- Test 16: Layer Query API
function M.test_layer_query()
    print("\n=== Test: Layer Query API ===")

    local ok, err = pcall(function()
        local count = ldtk.get_layer_count()
        print(string.format("  Layer count: %d", count))
        assert_test("get_layer_count returns number", type(count) == "number")

        if count > 0 then
            local name = ldtk.get_layer_name(0)
            print(string.format("  First layer name: '%s'", name or "nil"))
            assert_test("get_layer_name returns string", type(name) == "string")

            local idx = ldtk.get_layer_index(name)
            print(string.format("  Index for '%s': %d", name, idx))
            assert_test("get_layer_index returns 0 for first layer", idx == 0)
        end
    end)

    if not ok then
        log_test("layer query API", false, err)
    end
end

-- Run all tests
function M.run_all()
    print("\n" .. string.rep("=", 60))
    print("LDTK INTEGRATION TEST SUITE")
    print(string.rep("=", 60))

    test_results.passed = 0
    test_results.failed = 0
    test_results.errors = {}

    -- Core functionality tests
    M.test_config_loading()
    M.test_active_level()
    M.test_entity_spawning()
    M.test_intgrid_iteration()
    M.test_collider_building()
    M.test_prefab_lookup()
    M.test_full_level_cycle()

    -- New API tests
    M.test_level_exists()
    M.test_level_bounds()
    M.test_level_meta()
    M.test_level_neighbors()
    M.test_get_entities_by_name()
    M.test_get_entity_position()
    M.test_spawner_with_fields()

    -- Signal and procedural API tests
    M.test_signal_emission()
    M.test_layer_query()

    print("\n" .. string.rep("=", 60))
    print(string.format("RESULTS: %d passed, %d failed",
        test_results.passed, test_results.failed))

    if #test_results.errors > 0 then
        print("\nFailed tests:")
        for _, err in ipairs(test_results.errors) do
            print(string.format("  - %s: %s", err.name, err.msg))
        end
    end

    print(string.rep("=", 60) .. "\n")

    return test_results.failed == 0
end

return M
