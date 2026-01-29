--[[
================================================================================
action_helpers.lua - Behavior Templates for GOAP Actions
================================================================================
Provides reusable helper functions for common AI action patterns.

Usage:
    local helpers = require("ai.action_helpers")
    local ActionContext = require("ai.action_context")

    -- In action update:
    function action.update(e, dt)
        local ctx = ActionContext.new(e)
        ctx.dt = dt
        
        -- Move toward target
        local result = helpers.move_toward(ctx, target_pos, speed)
        if result == ActionResult.SUCCESS then
            -- Arrived at target
        end
        
        -- Wait for duration
        local result = helpers.wait_seconds(ctx, 2.0)
        if result == ActionResult.SUCCESS then
            -- Duration elapsed
        end
        
        -- Find nearest entity
        local nearest = helpers.find_nearest(ctx, function(e)
            return entity_has_tag(e, "enemy")
        end)
    end
]]

local action_helpers = {}

local component_cache = nil
pcall(function()
    component_cache = require("core.component_cache")
end)

--------------------------------------------------------------------------------
-- move_toward(ctx, target, speed)
--------------------------------------------------------------------------------
--- Move entity toward a target position.
--- @param ctx table ActionContext with ctx.entity, ctx.blackboard, ctx.dt
--- @param target table Vec2 position {x, y}
--- @param speed number Movement speed in pixels per second
--- @return string ActionResult.SUCCESS when arrived, ActionResult.RUNNING while moving
function action_helpers.move_toward(ctx, target, speed)
    if not ctx or not ctx.entity then
        return ActionResult.FAILURE
    end
    
    -- Use the global moveEntityTowardGoalOneIncrement if available
    if moveEntityTowardGoalOneIncrement then
        local still_moving = moveEntityTowardGoalOneIncrement(ctx.entity, target, ctx.dt or 0.016)
        if still_moving == false then
            return ActionResult.SUCCESS
        else
            return ActionResult.RUNNING
        end
    end
    
    -- Fallback: basic movement implementation
    if component_cache and Transform then
        local transform = component_cache.get(ctx.entity, Transform)
        if transform then
            local dx = target.x - transform.actualX
            local dy = target.y - transform.actualY
            local dist = math.sqrt(dx * dx + dy * dy)
            
            local threshold = 5  -- Arrival threshold in pixels
            if dist < threshold then
                return ActionResult.SUCCESS
            end
            
            -- Normalize and move
            local dt = ctx.dt or 0.016
            local move_dist = speed * dt
            if move_dist >= dist then
                transform.actualX = target.x
                transform.actualY = target.y
                return ActionResult.SUCCESS
            else
                local nx, ny = dx / dist, dy / dist
                transform.actualX = transform.actualX + nx * move_dist
                transform.actualY = transform.actualY + ny * move_dist
                return ActionResult.RUNNING
            end
        end
    end
    
    return ActionResult.FAILURE
end

--------------------------------------------------------------------------------
-- wait_seconds(ctx, duration, key_suffix)
--------------------------------------------------------------------------------
--- Wait for a specified duration using blackboard timer.
--- @param ctx table ActionContext with ctx.entity, ctx.blackboard
--- @param duration number Duration to wait in seconds
--- @param key_suffix string|nil Optional suffix to allow multiple concurrent waits (e.g., "phase1", "cooldown")
--- @return string ActionResult.SUCCESS after duration, ActionResult.RUNNING before
function action_helpers.wait_seconds(ctx, duration, key_suffix)
    if not ctx or not ctx.blackboard then
        return ActionResult.FAILURE
    end
    
    local bb = ctx.blackboard
    local key = "_wait_start_time" .. (key_suffix or "")
    
    -- Get current time
    local current_time = GetTime and GetTime() or os.clock()
    
    -- Initialize start time if not set
    if not bb:contains(key) then
        if bb.set_float then
            bb:set_float(key, current_time)
        elseif bb.set_double then
            bb:set_double(key, current_time)
        end
        return ActionResult.RUNNING
    end
    
    -- Get start time
    local start_time = 0
    if bb.get_float then
        start_time = bb:get_float(key)
    elseif bb.get_double then
        start_time = bb:get_double(key)
    elseif bb.get_or_float then
        start_time = bb:get_or_float(key, current_time)
    end
    
    -- Check if duration has elapsed
    local elapsed = current_time - start_time
    if elapsed >= duration then
        -- Clear the timer for next use
        if bb.remove then
            bb:remove(key)
        end
        return ActionResult.SUCCESS
    end
    
    return ActionResult.RUNNING
end

--------------------------------------------------------------------------------
-- find_nearest(ctx, filter_fn)
--------------------------------------------------------------------------------
--- Find the nearest entity matching a filter function.
--- @param ctx table ActionContext with ctx.entity
--- @param filter_fn function Function(entity) -> boolean, returns true if entity matches
--- @return number|nil Entity ID of nearest match, or nil if none found
function action_helpers.find_nearest(ctx, filter_fn)
    if not ctx or not ctx.entity then
        return nil
    end
    
    -- Get our position
    local my_x, my_y = 0, 0
    if component_cache and Transform then
        local transform = component_cache.get(ctx.entity, Transform)
        if transform then
            my_x = transform.actualX or 0
            my_y = transform.actualY or 0
        end
    end
    
    local nearest_entity = nil
    local nearest_dist_sq = math.huge
    
    -- Iterate through entities using registry view
    if registry and registry.view then
        -- Try to iterate with Transform component if available
        local view = nil
        pcall(function()
            if Transform then
                view = registry:view(Transform)
            end
        end)
        
        if view then
            for entity, transform in view:each() do
                if entity ~= ctx.entity and filter_fn(entity) then
                    local dx = (transform.actualX or 0) - my_x
                    local dy = (transform.actualY or 0) - my_y
                    local dist_sq = dx * dx + dy * dy
                    
                    if dist_sq < nearest_dist_sq then
                        nearest_dist_sq = dist_sq
                        nearest_entity = entity
                    end
                end
            end
        end
    end
    
    return nearest_entity
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------
if _G.log_debug then
    log_debug("[action_helpers] Module loaded")
end

return action_helpers
