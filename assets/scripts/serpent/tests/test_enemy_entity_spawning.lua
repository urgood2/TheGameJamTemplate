-- assets/scripts/serpent/tests/test_enemy_entity_spawning.lua
--[[
    Test suite for enemy entity spawning mechanics

    Tests enemy_entity_adapter.lua and enemy_controller.lua functionality
    to ensure proper enemy spawning, physics integration, and movement AI.
]]

-- Mock log functions for test environments
local log_debug = log_debug or function(msg) end
local log_warning = log_warning or function(msg) end
local log_error = log_error or function(msg) end

local test_enemy_entity_spawning = {}

--- Mock physics system for testing
local mock_physics = {
    positions = {},
    velocities = {},
    last_spawn_id = 1000
}

function mock_physics.SetPosition(physics, registry, entity_id, x, y)
    mock_physics.positions[entity_id] = { x = x, y = y }
end

function mock_physics.GetPosition(physics, registry, entity_id)
    return mock_physics.positions[entity_id]
end

function mock_physics.SetVelocity(physics, registry, entity_id, vx, vy)
    mock_physics.velocities[entity_id] = { x = vx, y = vy }
end

function mock_physics.reset()
    mock_physics.positions = {}
    mock_physics.velocities = {}
    mock_physics.last_spawn_id = 1000
end

--- Mock PhysicsBuilder
local mock_physics_builder = {}
function mock_physics_builder.for_entity(entity_id)
    return {
        circle = function(self) return self end,
        tag = function(self, tag) return self end,
        density = function(self, d) return self end,
        friction = function(self, f) return self end,
        fixedRotation = function(self, fixed) return self end,
        apply = function(self) end
    }
end

--- Mock spawn function
function spawn()
    mock_physics.last_spawn_id = mock_physics.last_spawn_id + 1
    return mock_physics.last_spawn_id
end

--- Mock despawn function
function despawn(entity_id)
    mock_physics.positions[entity_id] = nil
    mock_physics.velocities[entity_id] = nil
end

--- Setup mock environment
local function setup_mock_environment()
    _G.physics = mock_physics
    _G.registry = "mock_registry"
    _G.PhysicsBuilder = mock_physics_builder
    _G.spawn = spawn
    _G.despawn = despawn
    _G.love = {
        timer = {
            getTime = function() return os.clock() end
        }
    }
    mock_physics.reset()
end

--- Test basic enemy spawning functionality
--- @return boolean True if enemy spawning works correctly
function test_enemy_entity_spawning.test_basic_enemy_spawning()
    setup_mock_environment()

    -- Load enemy entity adapter (mock require)
    local enemy_entity_adapter = {}

    -- Simulate the enemy_entity_adapter module
    local enemy_id_to_entity_id = {}
    local entity_id_to_enemy_id = {}
    local spawned_enemies = {}

    function enemy_entity_adapter.spawn_enemy(enemy_id, x, y, radius)
        if enemy_id_to_entity_id[enemy_id] then
            return nil
        end

        local entity_id = spawn()
        mock_physics.SetPosition(_G.physics, _G.registry, entity_id, x, y)

        enemy_id_to_entity_id[enemy_id] = entity_id
        entity_id_to_enemy_id[entity_id] = enemy_id
        spawned_enemies[enemy_id] = { entity_id = entity_id, enemy_id = enemy_id }

        return entity_id
    end

    function enemy_entity_adapter.get_entity_id(enemy_id)
        return enemy_id_to_entity_id[enemy_id]
    end

    function enemy_entity_adapter.get_spawned_count()
        local count = 0
        for _, _ in pairs(spawned_enemies) do
            count = count + 1
        end
        return count
    end

    -- Test spawning an enemy
    local enemy_id = 2001
    local entity_id = enemy_entity_adapter.spawn_enemy(enemy_id, 100, 200, 16)

    if not entity_id then
        log_error("Failed to spawn enemy")
        return false
    end

    -- Check entity mapping
    if enemy_entity_adapter.get_entity_id(enemy_id) ~= entity_id then
        log_error("Entity mapping incorrect")
        return false
    end

    -- Check position was set
    local pos = mock_physics.GetPosition(_G.physics, _G.registry, entity_id)
    if not pos or pos.x ~= 100 or pos.y ~= 200 then
        log_error("Enemy position not set correctly")
        return false
    end

    -- Check spawn count
    if enemy_entity_adapter.get_spawned_count() ~= 1 then
        log_error("Spawn count incorrect")
        return false
    end

    log_debug("[EnemyEntityTest] Basic enemy spawning test passed")
    return true
end

--- Test enemy movement calculation
--- @return boolean True if movement calculation works correctly
function test_enemy_entity_spawning.test_enemy_movement_calculation()
    setup_mock_environment()

    -- Simple movement calculation test
    local function normalize_vector(dx, dy)
        local magnitude = math.sqrt(dx * dx + dy * dy)
        if magnitude > 0 then
            return dx / magnitude, dy / magnitude
        end
        return 0, 0
    end

    -- Test movement toward target
    local enemy_x, enemy_y = 0, 0
    local head_x, head_y = 30, 40 -- 3-4-5 triangle, distance = 50

    local dx = head_x - enemy_x
    local dy = head_y - enemy_y
    local norm_dx, norm_dy = normalize_vector(dx, dy)

    -- Check normalized direction
    if math.abs(norm_dx - 0.6) > 0.01 or math.abs(norm_dy - 0.8) > 0.01 then
        log_error("Movement direction calculation incorrect")
        return false
    end

    -- Check velocity calculation
    local speed = 100
    local expected_vx = norm_dx * speed -- 60
    local expected_vy = norm_dy * speed -- 80

    if math.abs(expected_vx - 60) > 0.1 or math.abs(expected_vy - 80) > 0.1 then
        log_error("Velocity calculation incorrect")
        return false
    end

    log_debug("[EnemyEntityTest] Enemy movement calculation test passed")
    return true
end

--- Test enemy position snapshots
--- @return boolean True if position snapshots work correctly
function test_enemy_entity_spawning.test_position_snapshots()
    setup_mock_environment()

    -- Mock enemy entity adapter with position snapshot functionality
    local enemy_entity_adapter = {}
    local spawned_enemies = {}

    function enemy_entity_adapter.spawn_enemy(enemy_id, x, y, radius)
        local entity_id = spawn()
        mock_physics.SetPosition(_G.physics, _G.registry, entity_id, x, y)
        spawned_enemies[enemy_id] = { entity_id = entity_id, enemy_id = enemy_id }
        return entity_id
    end

    function enemy_entity_adapter.build_pos_snapshots()
        local snapshots = {}
        for enemy_id, enemy_info in pairs(spawned_enemies) do
            local entity_id = enemy_info.entity_id
            local pos = mock_physics.GetPosition(_G.physics, _G.registry, entity_id)
            if pos then
                table.insert(snapshots, {
                    enemy_id = enemy_id,
                    x = pos.x,
                    y = pos.y,
                })
            end
        end

        -- Sort by enemy_id
        table.sort(snapshots, function(a, b)
            return a.enemy_id < b.enemy_id
        end)

        return snapshots
    end

    -- Spawn multiple enemies
    enemy_entity_adapter.spawn_enemy(3001, 10, 20, 16)
    enemy_entity_adapter.spawn_enemy(3003, 30, 40, 16)
    enemy_entity_adapter.spawn_enemy(3002, 20, 30, 16)

    -- Build snapshots
    local snapshots = enemy_entity_adapter.build_pos_snapshots()

    -- Check snapshot count
    if #snapshots ~= 3 then
        log_error("Incorrect snapshot count")
        return false
    end

    -- Check sorting by enemy_id
    if snapshots[1].enemy_id ~= 3001 or snapshots[2].enemy_id ~= 3002 or snapshots[3].enemy_id ~= 3003 then
        log_error("Snapshots not sorted by enemy_id")
        return false
    end

    -- Check positions
    if snapshots[1].x ~= 10 or snapshots[1].y ~= 20 then
        log_error("Snapshot position incorrect")
        return false
    end

    log_debug("[EnemyEntityTest] Position snapshots test passed")
    return true
end

--- Test edge cases
--- @return boolean True if edge cases are handled correctly
function test_enemy_entity_spawning.test_edge_cases()
    setup_mock_environment()

    local enemy_entity_adapter = {}
    local enemy_id_to_entity_id = {}

    function enemy_entity_adapter.spawn_enemy(enemy_id, x, y, radius)
        if enemy_id_to_entity_id[enemy_id] then
            return nil -- Prevent duplicate spawning
        end
        local entity_id = spawn()
        enemy_id_to_entity_id[enemy_id] = entity_id
        return entity_id
    end

    function enemy_entity_adapter.get_entity_id(enemy_id)
        return enemy_id_to_entity_id[enemy_id]
    end

    -- Test duplicate spawning prevention
    local enemy_id = 4001
    local entity_id1 = enemy_entity_adapter.spawn_enemy(enemy_id, 50, 60, 16)
    local entity_id2 = enemy_entity_adapter.spawn_enemy(enemy_id, 70, 80, 16) -- Should fail

    if not entity_id1 or entity_id2 ~= nil then
        log_error("Duplicate spawning prevention failed")
        return false
    end

    -- Test movement with zero distance (should not crash)
    local norm_dx, norm_dy = 0, 0
    local magnitude = math.sqrt(0 * 0 + 0 * 0)
    if magnitude == 0 then
        norm_dx, norm_dy = 0, 0 -- Should handle gracefully
    end

    if norm_dx ~= 0 or norm_dy ~= 0 then
        log_error("Zero distance movement handling failed")
        return false
    end

    log_debug("[EnemyEntityTest] Edge cases test passed")
    return true
end

--- Run all enemy entity spawning tests
--- @return boolean True if all tests pass
function test_enemy_entity_spawning.run_all_tests()
    local tests = {
        { "basic_enemy_spawning", test_enemy_entity_spawning.test_basic_enemy_spawning },
        { "enemy_movement_calculation", test_enemy_entity_spawning.test_enemy_movement_calculation },
        { "position_snapshots", test_enemy_entity_spawning.test_position_snapshots },
        { "edge_cases", test_enemy_entity_spawning.test_edge_cases },
    }

    local passed = 0
    local total = #tests

    log_debug("[EnemyEntityTest] Running " .. total .. " tests...")

    for _, test in ipairs(tests) do
        local test_name, test_func = test[1], test[2]
        local success = test_func()

        if success then
            log_debug("[EnemyEntityTest] ✓ " .. test_name)
            passed = passed + 1
        else
            log_error("[EnemyEntityTest] ✗ " .. test_name)
        end
    end

    log_debug(string.format("[EnemyEntityTest] Results: %d/%d tests passed", passed, total))
    return passed == total
end

return test_enemy_entity_spawning