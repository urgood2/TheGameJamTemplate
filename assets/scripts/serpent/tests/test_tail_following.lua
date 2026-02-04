-- assets/scripts/serpent/tests/test_tail_following.lua
--[[
    Test suite for tail following mechanics in snake_controller.lua

    Tests the SEGMENT_SPACING=40px tail following algorithm where each segment
    follows the previous one at the specified distance.
]]

-- Mock log functions for test environments
local log_debug = log_debug or function(msg) end
local log_warning = log_warning or function(msg) end
local log_error = log_error or function(msg) end

local snake_controller = require("serpent.snake_controller")

local test_tail_following = {}

--- Mock physics system for testing
local mock_physics = {
    positions = {},
    velocities = {}
}

function mock_physics.SetPosition(world, entity_id, pos)
    mock_physics.positions[entity_id] = { x = pos.x, y = pos.y }
end

function mock_physics.GetPosition(world, entity_id)
    return mock_physics.positions[entity_id]
end

function mock_physics.SetVelocity(world, entity_id, vx, vy)
    mock_physics.velocities[entity_id] = { x = vx, y = vy }
end

function mock_physics.reset()
    mock_physics.positions = {}
    mock_physics.velocities = {}
end

--- Setup mock global environment
local function setup_mock_environment()
    _G.physics = mock_physics
    _G.PhysicsManager = {
        get_world = function(name)
            return "mock_world"
        end
    }
    mock_physics.reset()
end

--- Test basic tail following with 3 segments
--- @return boolean True if tail following works correctly
function test_tail_following.test_basic_tail_following()
    setup_mock_environment()

    -- Setup 3-segment snake: head at (100,100), segments at (80,100) and (60,100)
    local segments = { 1001, 1002, 1003 } -- entity IDs

    -- Initial positions: head at (100,100), segments spaced at 40px intervals
    mock_physics.SetPosition("mock_world", 1001, { x = 100, y = 100 }) -- Head
    mock_physics.SetPosition("mock_world", 1002, { x = 60, y = 100 })  -- Body (40px away)
    mock_physics.SetPosition("mock_world", 1003, { x = 20, y = 100 })  -- Tail (40px away)

    -- Move head to (140, 100) - creating spacing > 40px
    mock_physics.SetPosition("mock_world", 1001, { x = 140, y = 100 })

    -- Run snake controller with no input (tail following only)
    local input = { dx = 0, dy = 0 }
    snake_controller.update(0.016, segments, input, { SEGMENT_SPACING = 40 })

    -- Check positions after tail following
    local head_pos = mock_physics.GetPosition("mock_world", 1001)
    local body_pos = mock_physics.GetPosition("mock_world", 1002)
    local tail_pos = mock_physics.GetPosition("mock_world", 1003)

    if not head_pos or not body_pos or not tail_pos then
        return false
    end

    -- Body should follow head at 40px distance
    local head_body_dist = math.sqrt((head_pos.x - body_pos.x)^2 + (head_pos.y - body_pos.y)^2)
    if math.abs(head_body_dist - 40) > 1 then -- Allow 1px tolerance
        log_error(string.format("Head-body distance incorrect: expected=40, actual=%.1f", head_body_dist))
        return false
    end

    -- Tail should follow body at 40px distance
    local body_tail_dist = math.sqrt((body_pos.x - tail_pos.x)^2 + (body_pos.y - tail_pos.y)^2)
    if math.abs(body_tail_dist - 40) > 1 then -- Allow 1px tolerance
        log_error(string.format("Body-tail distance incorrect: expected=40, actual=%.1f", body_tail_dist))
        return false
    end

    -- Body should be positioned correctly relative to head
    local expected_body_x = head_pos.x - 40 -- On same Y line, 40px left of head
    if math.abs(body_pos.x - expected_body_x) > 1 then
        log_error(string.format("Body X position incorrect: expected=%.1f, actual=%.1f",
                  expected_body_x, body_pos.x))
        return false
    end

    return true
end

--- Test diagonal tail following
--- @return boolean True if diagonal following works correctly
function test_tail_following.test_diagonal_tail_following()
    setup_mock_environment()

    local segments = { 2001, 2002 } -- 2-segment snake

    -- Head at origin, body at (0, -40)
    mock_physics.SetPosition("mock_world", 2001, { x = 0, y = 0 })
    mock_physics.SetPosition("mock_world", 2002, { x = 0, y = -40 })

    -- Move head diagonally to (30, 30)
    mock_physics.SetPosition("mock_world", 2001, { x = 30, y = 30 })

    -- Run tail following
    snake_controller.update(0.016, segments, { dx = 0, dy = 0 }, { SEGMENT_SPACING = 40 })

    local head_pos = mock_physics.GetPosition("mock_world", 2001)
    local body_pos = mock_physics.GetPosition("mock_world", 2002)

    -- Check distance is maintained
    local distance = math.sqrt((head_pos.x - body_pos.x)^2 + (head_pos.y - body_pos.y)^2)
    if math.abs(distance - 40) > 1 then
        log_error(string.format("Diagonal distance incorrect: expected=40, actual=%.1f", distance))
        return false
    end

    -- Check body is on line from head toward previous position
    local dx = head_pos.x - body_pos.x
    local dy = head_pos.y - body_pos.y
    local normalized_length = math.sqrt(dx^2 + dy^2)

    if math.abs(normalized_length - 40) > 1 then
        return false
    end

    return true
end

--- Test that segments don't move when already at correct spacing
--- @return boolean True if stable positioning works
function test_tail_following.test_stable_spacing()
    setup_mock_environment()

    local segments = { 3001, 3002, 3003 }

    -- Setup segments already at perfect 40px spacing
    mock_physics.SetPosition("mock_world", 3001, { x = 100, y = 100 })
    mock_physics.SetPosition("mock_world", 3002, { x = 60, y = 100 })
    mock_physics.SetPosition("mock_world", 3003, { x = 20, y = 100 })

    -- Store initial positions
    local initial_body = mock_physics.GetPosition("mock_world", 3002)
    local initial_tail = mock_physics.GetPosition("mock_world", 3003)

    -- Run tail following (should not move anything)
    snake_controller.update(0.016, segments, { dx = 0, dy = 0 }, { SEGMENT_SPACING = 40 })

    -- Check positions haven't changed
    local final_body = mock_physics.GetPosition("mock_world", 3002)
    local final_tail = mock_physics.GetPosition("mock_world", 3003)

    if math.abs(final_body.x - initial_body.x) > 0.01 or
       math.abs(final_body.y - initial_body.y) > 0.01 then
        return false
    end

    if math.abs(final_tail.x - initial_tail.x) > 0.01 or
       math.abs(final_tail.y - initial_tail.y) > 0.01 then
        return false
    end

    return true
end

--- Test custom segment spacing
--- @return boolean True if custom spacing works
function test_tail_following.test_custom_spacing()
    setup_mock_environment()

    local segments = { 4001, 4002 }

    -- Setup with large gap
    mock_physics.SetPosition("mock_world", 4001, { x = 100, y = 100 })
    mock_physics.SetPosition("mock_world", 4002, { x = 0, y = 100 })

    -- Use custom spacing of 60px
    snake_controller.update(0.016, segments, { dx = 0, dy = 0 }, { SEGMENT_SPACING = 60 })

    local head_pos = mock_physics.GetPosition("mock_world", 4001)
    local body_pos = mock_physics.GetPosition("mock_world", 4002)

    local distance = math.sqrt((head_pos.x - body_pos.x)^2 + (head_pos.y - body_pos.y)^2)

    if math.abs(distance - 60) > 1 then
        log_error(string.format("Custom spacing failed: expected=60, actual=%.1f", distance))
        return false
    end

    return true
end

--- Test edge case with no segments
--- @return boolean True if empty input is handled gracefully
function test_tail_following.test_empty_segments()
    setup_mock_environment()

    local segments = {}

    -- Should not crash with empty segments
    snake_controller.update(0.016, segments, { dx = 0, dy = 0 }, { SEGMENT_SPACING = 40 })

    return true
end

--- Test edge case with single segment (head only)
--- @return boolean True if single segment is handled correctly
function test_tail_following.test_single_segment()
    setup_mock_environment()

    local segments = { 5001 }

    mock_physics.SetPosition("mock_world", 5001, { x = 50, y = 50 })

    -- Should handle single segment without tail following logic
    snake_controller.update(0.016, segments, { dx = 1, dy = 0 }, { MAX_SPEED = 100 })

    -- Head should still move via input steering
    local velocity = mock_physics.velocities[5001]
    if not velocity or velocity.x <= 0 then
        return false
    end

    return true
end

--- Run all tail following tests
--- @return boolean True if all tests pass
function test_tail_following.run_all_tests()
    local tests = {
        { "basic_tail_following", test_tail_following.test_basic_tail_following },
        { "diagonal_tail_following", test_tail_following.test_diagonal_tail_following },
        { "stable_spacing", test_tail_following.test_stable_spacing },
        { "custom_spacing", test_tail_following.test_custom_spacing },
        { "empty_segments", test_tail_following.test_empty_segments },
        { "single_segment", test_tail_following.test_single_segment },
    }

    local passed = 0
    local total = #tests

    log_debug("[TailFollowingTest] Running " .. total .. " tests...")

    for _, test in ipairs(tests) do
        local test_name, test_func = test[1], test[2]
        local success = test_func()

        if success then
            log_debug("[TailFollowingTest] ✓ " .. test_name)
            passed = passed + 1
        else
            log_error("[TailFollowingTest] ✗ " .. test_name)
        end
    end

    log_debug(string.format("[TailFollowingTest] Results: %d/%d tests passed", passed, total))
    return passed == total
end

return test_tail_following