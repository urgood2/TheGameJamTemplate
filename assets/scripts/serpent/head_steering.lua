-- assets/scripts/serpent/head_steering.lua
--[[
    Head Steering Module

    Implements player input handling for snake head movement using WASD/arrow keys.
    Controls head velocity through physics system for smooth directional movement.
]]

-- Mock log functions for environments that don't have them
local log_debug = log_debug or function(msg) end
local log_warning = log_warning or function(msg) end

local head_steering = {}

-- Movement configuration
local MOVE_SPEED = 150 -- pixels per second
local DIAGONAL_FACTOR = 0.707 -- For smooth diagonal movement (1/sqrt(2))

-- Input key mappings
local INPUT_KEYS = {
    -- WASD keys
    w = "up",
    a = "left",
    s = "down",
    d = "right",

    -- Arrow keys
    up = "up",
    left = "left",
    down = "down",
    right = "right"
}

--- Initialize head steering system
--- @param head_entity_id number Physics entity ID of the snake head
--- @return table Head steering state
function head_steering.create_state(head_entity_id)
    return {
        head_entity_id = head_entity_id,
        move_speed = MOVE_SPEED,
        current_velocity = { x = 0, y = 0 },
        input_state = {
            up = false,
            down = false,
            left = false,
            right = false
        }
    }
end

--- Update input state from keyboard input
--- @param steering_state table Current steering state
--- @param input_table table Input state (key -> boolean mapping)
--- @return table Updated steering state
function head_steering.update_input(steering_state, input_table)
    local updated_state = head_steering._copy_state(steering_state)

    -- Clear all input state first
    for direction in pairs(updated_state.input_state) do
        updated_state.input_state[direction] = false
    end

    -- Update input state based on key mappings
    for key, pressed in pairs(input_table or {}) do
        local direction = INPUT_KEYS[key]
        if direction and pressed then
            updated_state.input_state[direction] = true
        end
    end

    return updated_state
end

--- Process input and update head velocity
--- @param steering_state table Current steering state
--- @return table Updated steering state
function head_steering.process_steering(steering_state)
    local updated_state = head_steering._copy_state(steering_state)

    -- Calculate movement vector from input
    local move_x = 0
    local move_y = 0

    if updated_state.input_state.left then
        move_x = move_x - 1
    end
    if updated_state.input_state.right then
        move_x = move_x + 1
    end
    if updated_state.input_state.up then
        move_y = move_y - 1
    end
    if updated_state.input_state.down then
        move_y = move_y + 1
    end

    -- Apply diagonal movement factor if moving diagonally
    local is_diagonal = (move_x ~= 0) and (move_y ~= 0)
    local speed_factor = is_diagonal and DIAGONAL_FACTOR or 1.0

    -- Calculate final velocity
    local velocity_x = move_x * updated_state.move_speed * speed_factor
    local velocity_y = move_y * updated_state.move_speed * speed_factor

    updated_state.current_velocity.x = velocity_x
    updated_state.current_velocity.y = velocity_y

    -- Apply velocity to physics entity
    if updated_state.head_entity_id and _G.physics and _G.physics.SetVelocity then
        _G.physics.SetVelocity(_G.physics, _G.registry, updated_state.head_entity_id, velocity_x, velocity_y)

        log_debug(string.format("[HeadSteering] Set velocity: entity=%d, vel=(%.1f,%.1f)",
                  updated_state.head_entity_id, velocity_x, velocity_y))
    else
        log_warning("[HeadSteering] Could not apply velocity - missing physics system or entity")
    end

    return updated_state
end

--- Update both input and steering in one call
--- @param steering_state table Current steering state
--- @param input_table table Input state from input system
--- @return table Updated steering state
function head_steering.update(steering_state, input_table)
    local state_with_input = head_steering.update_input(steering_state, input_table)
    return head_steering.process_steering(state_with_input)
end

--- Get current movement direction as a string
--- @param steering_state table Steering state
--- @return string Direction description
function head_steering.get_movement_direction(steering_state)
    local input = steering_state.input_state
    local directions = {}

    if input.up then table.insert(directions, "up") end
    if input.down then table.insert(directions, "down") end
    if input.left then table.insert(directions, "left") end
    if input.right then table.insert(directions, "right") end

    if #directions == 0 then
        return "stationary"
    elseif #directions == 1 then
        return directions[1]
    else
        return table.concat(directions, "+")
    end
end

--- Check if head is currently moving
--- @param steering_state table Steering state
--- @return boolean True if head is moving
function head_steering.is_moving(steering_state)
    local vel = steering_state.current_velocity
    return (vel.x ~= 0) or (vel.y ~= 0)
end

--- Get current speed magnitude
--- @param steering_state table Steering state
--- @return number Current speed in pixels per second
function head_steering.get_speed(steering_state)
    local vel = steering_state.current_velocity
    return math.sqrt(vel.x * vel.x + vel.y * vel.y)
end

--- Set movement speed (useful for powerups or effects)
--- @param steering_state table Steering state
--- @param new_speed number New movement speed
--- @return table Updated steering state
function head_steering.set_speed(steering_state, new_speed)
    local updated_state = head_steering._copy_state(steering_state)
    updated_state.move_speed = math.max(0, new_speed)
    return updated_state
end

--- Stop all movement immediately
--- @param steering_state table Steering state
--- @return table Updated steering state
function head_steering.stop(steering_state)
    local updated_state = head_steering._copy_state(steering_state)

    updated_state.current_velocity.x = 0
    updated_state.current_velocity.y = 0

    -- Clear input state
    for direction in pairs(updated_state.input_state) do
        updated_state.input_state[direction] = false
    end

    -- Apply zero velocity to physics entity
    if updated_state.head_entity_id and _G.physics and _G.physics.SetVelocity then
        _G.physics.SetVelocity(_G.physics, _G.registry, updated_state.head_entity_id, 0, 0)
        log_debug("[HeadSteering] Stopped movement for entity " .. updated_state.head_entity_id)
    end

    return updated_state
end

--- Get steering status for debugging
--- @param steering_state table Steering state
--- @return table Status information
function head_steering.get_status(steering_state)
    return {
        head_entity_id = steering_state.head_entity_id,
        move_speed = steering_state.move_speed,
        current_velocity = steering_state.current_velocity,
        input_state = steering_state.input_state,
        direction = head_steering.get_movement_direction(steering_state),
        is_moving = head_steering.is_moving(steering_state),
        speed = head_steering.get_speed(steering_state)
    }
end

--- Deep copy steering state
--- @param state table State to copy
--- @return table Deep copy of state
function head_steering._copy_state(state)
    return {
        head_entity_id = state.head_entity_id,
        move_speed = state.move_speed,
        current_velocity = {
            x = state.current_velocity.x,
            y = state.current_velocity.y
        },
        input_state = {
            up = state.input_state.up,
            down = state.input_state.down,
            left = state.input_state.left,
            right = state.input_state.right
        }
    }
end

--- Test input processing and movement calculation
--- @return boolean True if input processing works correctly
function head_steering.test_input_processing()
    local steering_state = head_steering.create_state(1001)

    -- Test single direction input
    local input = { w = true } -- Up key
    local updated_state = head_steering.update(steering_state, input)

    -- Should move up
    if updated_state.current_velocity.x ~= 0 or updated_state.current_velocity.y >= 0 then
        return false
    end

    if head_steering.get_movement_direction(updated_state) ~= "up" then
        return false
    end

    -- Test diagonal movement
    input = { w = true, d = true } -- Up + Right
    updated_state = head_steering.update(steering_state, input)

    -- Should move diagonally with reduced speed
    if updated_state.current_velocity.x <= 0 or updated_state.current_velocity.y >= 0 then
        return false
    end

    local speed = head_steering.get_speed(updated_state)
    local expected_speed = MOVE_SPEED * DIAGONAL_FACTOR
    if math.abs(speed - expected_speed) > 1 then
        return false
    end

    return true
end

--- Test movement state management
--- @return boolean True if state management works correctly
function head_steering.test_state_management()
    local steering_state = head_steering.create_state(1002)

    -- Test speed modification
    steering_state = head_steering.set_speed(steering_state, 200)
    if steering_state.move_speed ~= 200 then
        return false
    end

    -- Test stopping
    local input = { a = true, s = true } -- Left + Down
    steering_state = head_steering.update(steering_state, input)

    if not head_steering.is_moving(steering_state) then
        return false
    end

    steering_state = head_steering.stop(steering_state)

    if head_steering.is_moving(steering_state) then
        return false
    end

    if head_steering.get_movement_direction(steering_state) ~= "stationary" then
        return false
    end

    return true
end

--- Test key mapping support
--- @return boolean True if key mapping works correctly
function head_steering.test_key_mapping()
    local steering_state = head_steering.create_state(1003)

    -- Test WASD keys
    local wasd_input = { w = true, a = false, s = false, d = true }
    steering_state = head_steering.update(steering_state, wasd_input)

    if head_steering.get_movement_direction(steering_state) ~= "up+right" then
        return false
    end

    -- Test arrow keys
    local arrow_input = { up = false, left = true, down = true, right = false }
    steering_state = head_steering.update(steering_state, arrow_input)

    if head_steering.get_movement_direction(steering_state) ~= "down+left" then
        return false
    end

    return true
end

return head_steering