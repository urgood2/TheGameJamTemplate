--[[
================================================================================
TEST: Arena Boundary Clamping
================================================================================
Run with: lua assets/scripts/serpent/tests/test_arena_clamping.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local snake_controller = require("serpent.snake_controller")

-- Mock physics system for testing
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

local function setup_mock_environment()
    _G.physics = mock_physics
    _G.PhysicsManager = {
        get_world = function(name)
            return "mock_world"
        end
    }
    mock_physics.positions = {}
    mock_physics.velocities = {}
end

t.describe("snake_controller.update arena clamp", function()
    t.it("clamps head position to arena bounds", function()
        setup_mock_environment()

        local head_id = 1001
        local segments = { head_id }

        -- Place head outside arena bounds
        mock_physics.SetPosition("mock_world", head_id, { x = 900, y = 10 })

        snake_controller.update(0.016, segments, { dx = 0, dy = 0 }, {
            ARENA_WIDTH = 800,
            ARENA_HEIGHT = 600,
            ARENA_PADDING = 50,
            MAX_SPEED = 0
        })

        local head_pos = mock_physics.GetPosition("mock_world", head_id)
        t.expect(head_pos.x).to_be(750) -- max_x = 800 - 50
        t.expect(head_pos.y).to_be(50)  -- min_y = 50
    end)
end)
