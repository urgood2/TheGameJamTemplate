-- assets/scripts/serpent/enemy_controller.lua
--[[
    Enemy Controller Module

    Handles enemy movement AI for the Serpent minigame.
    Enemies move toward the snake head position at their specified speed.
]]

-- Mock log functions for environments that don't have them
local log_debug = log_debug or function(msg) end
local log_warning = log_warning or function(msg) end
local log_error = log_error or function(msg) end

local enemy_controller = {}

--- Normalize a 2D vector
--- @param dx number X component
--- @param dy number Y component
--- @return number, number Normalized X and Y components
local function normalize_vector(dx, dy)
    local magnitude = math.sqrt(dx * dx + dy * dy)
    if magnitude > 0 then
        return dx / magnitude, dy / magnitude
    end
    return 0, 0
end

--- Calculate distance between two points
--- @param x1 number First point X
--- @param y1 number First point Y
--- @param x2 number Second point X
--- @param y2 number Second point Y
--- @return number Distance between points
local function calculate_distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

--- Find the head position from snake entity adapter
--- @param snake_entity_adapter table Snake entity adapter instance
--- @param snake_state table Current snake state with segments
--- @return number|nil, number|nil Head X and Y position, or nil if not found
local function get_head_position(snake_entity_adapter, snake_state)
    -- Try to get head position from snake state (most reliable)
    if snake_state and snake_state.segments and #snake_state.segments > 0 then
        local head_segment = snake_state.segments[1] -- Head is first segment
        if head_segment and head_segment.instance_id then
            local head_entity_id = snake_entity_adapter.get_entity_id(head_segment.instance_id)
            if head_entity_id then
                local head_pos = physics.GetPosition(_G.physics, _G.registry, head_entity_id)
                if head_pos then
                    return head_pos.x, head_pos.y
                end
            end
            -- Fallback: use snake_state position if entity position not available
            if head_segment.x and head_segment.y then
                return head_segment.x, head_segment.y
            end
        end
    end

    -- Fallback: try to get head position from position snapshots
    local pos_snapshots = snake_entity_adapter.build_pos_snapshots()
    if pos_snapshots and #pos_snapshots > 0 then
        -- Assume first segment is head (sorted by instance_id)
        local head_snapshot = pos_snapshots[1]
        if head_snapshot then
            return head_snapshot.x, head_snapshot.y
        end
    end

    return nil, nil
end

--- Update enemy movement toward snake head
--- @param dt number Delta time in seconds
--- @param enemy_snapshots table Array of enemy snapshots with enemy_id, x, y, speed
--- @param enemy_entity_adapter table Enemy entity adapter instance
--- @param snake_entity_adapter table Snake entity adapter instance
--- @param snake_state table Current snake state (optional, for head position)
function enemy_controller.update(dt, enemy_snapshots, enemy_entity_adapter, snake_entity_adapter, snake_state)
    if not enemy_snapshots or #enemy_snapshots == 0 then
        return
    end

    if not enemy_entity_adapter or not snake_entity_adapter then
        log_warning("[EnemyController] Missing required adapters")
        return
    end

    -- Get snake head position
    local head_x, head_y = get_head_position(snake_entity_adapter, snake_state)
    if not head_x or not head_y then
        log_debug("[EnemyController] No snake head position found")
        return
    end

    -- Update each enemy's movement toward head
    for _, enemy_snap in ipairs(enemy_snapshots) do
        if enemy_snap and enemy_snap.enemy_id then
            local entity_id = enemy_entity_adapter.get_entity_id(enemy_snap.enemy_id)
            if entity_id then
                -- Get current enemy position
                local enemy_pos = physics.GetPosition(_G.physics, _G.registry, entity_id)
                if enemy_pos then
                    -- Calculate direction from enemy to head
                    local dx = head_x - enemy_pos.x
                    local dy = head_y - enemy_pos.y

                    -- Don't move if already very close to head
                    local distance = math.sqrt(dx * dx + dy * dy)
                    if distance > 2.0 then -- 2 pixel dead zone to prevent jitter
                        -- Normalize direction and apply speed
                        local norm_dx, norm_dy = normalize_vector(dx, dy)
                        local speed = enemy_snap.speed or 50 -- Default speed if not specified

                        local velocity_x = norm_dx * speed
                        local velocity_y = norm_dy * speed

                        -- Apply velocity to physics entity
                        physics.SetVelocity(_G.physics, _G.registry, entity_id, velocity_x, velocity_y)

                        log_debug(string.format("[EnemyController] Enemy %d moving toward head: vel=(%.1f,%.1f), distance=%.1f",
                                  enemy_snap.enemy_id, velocity_x, velocity_y, distance))
                    else
                        -- Stop movement if very close to head
                        physics.SetVelocity(_G.physics, _G.registry, entity_id, 0, 0)
                    end
                end
            else
                log_warning(string.format("[EnemyController] No entity found for enemy_id %d", enemy_snap.enemy_id))
            end
        end
    end
end

--- Stop all enemy movement (useful for pausing)
--- @param enemy_entity_adapter table Enemy entity adapter instance
function enemy_controller.stop_all_movement(enemy_entity_adapter)
    if not enemy_entity_adapter then
        return
    end

    local spawned_enemy_ids = enemy_entity_adapter.get_spawned_enemy_ids()
    for _, enemy_id in ipairs(spawned_enemy_ids) do
        local entity_id = enemy_entity_adapter.get_entity_id(enemy_id)
        if entity_id then
            physics.SetVelocity(_G.physics, _G.registry, entity_id, 0, 0)
        end
    end

    log_debug("[EnemyController] Stopped all enemy movement")
end

--- Update single enemy movement (for targeted control)
--- @param enemy_id number Enemy ID to update
--- @param target_x number Target X position
--- @param target_y number Target Y position
--- @param speed number Movement speed
--- @param enemy_entity_adapter table Enemy entity adapter instance
function enemy_controller.update_single_enemy(enemy_id, target_x, target_y, speed, enemy_entity_adapter)
    if not enemy_entity_adapter then
        return
    end

    local entity_id = enemy_entity_adapter.get_entity_id(enemy_id)
    if not entity_id then
        return
    end

    local enemy_pos = physics.GetPosition(_G.physics, _G.registry, entity_id)
    if not enemy_pos then
        return
    end

    -- Calculate direction to target
    local dx = target_x - enemy_pos.x
    local dy = target_y - enemy_pos.y
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance > 2.0 then
        -- Normalize and apply speed
        local norm_dx, norm_dy = normalize_vector(dx, dy)
        local velocity_x = norm_dx * speed
        local velocity_y = norm_dy * speed

        physics.SetVelocity(_G.physics, _G.registry, entity_id, velocity_x, velocity_y)
    else
        -- Stop if close to target
        physics.SetVelocity(_G.physics, _G.registry, entity_id, 0, 0)
    end
end

--- Get movement status for debugging
--- @param enemy_snapshots table Array of enemy snapshots
--- @param enemy_entity_adapter table Enemy entity adapter instance
--- @param snake_entity_adapter table Snake entity adapter instance
--- @param snake_state table Current snake state
--- @return table Movement status information
function enemy_controller.get_movement_status(enemy_snapshots, enemy_entity_adapter, snake_entity_adapter, snake_state)
    local status = {
        head_position = nil,
        enemy_movements = {},
        total_enemies = 0
    }

    -- Get head position
    local head_x, head_y = get_head_position(snake_entity_adapter, snake_state)
    if head_x and head_y then
        status.head_position = { x = head_x, y = head_y }
    end

    -- Get enemy movement info
    if enemy_snapshots then
        for _, enemy_snap in ipairs(enemy_snapshots) do
            if enemy_snap and enemy_snap.enemy_id then
                local entity_id = enemy_entity_adapter.get_entity_id(enemy_snap.enemy_id)
                if entity_id then
                    local enemy_pos = physics.GetPosition(_G.physics, _G.registry, entity_id)
                    if enemy_pos and head_x and head_y then
                        local distance = calculate_distance(enemy_pos.x, enemy_pos.y, head_x, head_y)
                        table.insert(status.enemy_movements, {
                            enemy_id = enemy_snap.enemy_id,
                            position = { x = enemy_pos.x, y = enemy_pos.y },
                            distance_to_head = distance,
                            speed = enemy_snap.speed or 50
                        })
                    end
                end
            end
        end
        status.total_enemies = #status.enemy_movements
    end

    return status
end

--- Test enemy movement calculation
--- @return boolean True if movement calculation works correctly
function enemy_controller.test_movement_calculation()
    -- Test vector normalization
    local dx, dy = normalize_vector(3, 4) -- 3-4-5 triangle
    if math.abs(dx - 0.6) > 0.01 or math.abs(dy - 0.8) > 0.01 then
        log_error("[EnemyController] Vector normalization test failed")
        return false
    end

    -- Test zero vector normalization
    dx, dy = normalize_vector(0, 0)
    if dx ~= 0 or dy ~= 0 then
        log_error("[EnemyController] Zero vector normalization test failed")
        return false
    end

    -- Test distance calculation
    local distance = calculate_distance(0, 0, 3, 4)
    if math.abs(distance - 5) > 0.01 then
        log_error("[EnemyController] Distance calculation test failed")
        return false
    end

    log_debug("[EnemyController] Movement calculation tests passed")
    return true
end

return enemy_controller