--[[
================================================================================
DEMO PATROL - Patrol action for GOAP AI Demo
================================================================================
Makes the entity walk in a square pattern to demonstrate action execution
and worldstate changes visible in the AI Inspector.
]]

local component_cache = require("core.component_cache")

return {
    name = "demo_patrol",
    cost = 2,
    pre = { patrolling = false },
    post = { patrolling = true, patrol_complete = true },
    watch = { "threat_detected", "tired" },

    start = function(e)
        log_debug("[DEMO] Entity", e, "starting patrol")
        setBlackboardFloat(e, "patrol_waypoint", 0)
    end,

    update = function(e, dt)
        local transform = component_cache.get(e, Transform)
        if not transform then
            return ActionResult.FAILURE
        end

        -- Get patrol center from blackboard or use current position
        local centerX = getBlackboardFloat(e, "patrol_center_x") or transform.actualX
        local centerY = getBlackboardFloat(e, "patrol_center_y") or transform.actualY

        -- Define patrol waypoints in a square pattern
        local waypoints = {
            { x = centerX + 50, y = centerY },
            { x = centerX + 50, y = centerY + 50 },
            { x = centerX, y = centerY + 50 },
            { x = centerX, y = centerY },
        }

        local currentWaypoint = math.floor(getBlackboardFloat(e, "patrol_waypoint") or 0) + 1
        if currentWaypoint > #waypoints then currentWaypoint = 1 end

        local target = waypoints[currentWaypoint]
        local speed = 60 -- pixels per second

        -- Move towards waypoint
        local dx = target.x - transform.actualX
        local dy = target.y - transform.actualY
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist > 5 then
            -- Still moving
            local moveX = (dx / dist) * speed * dt
            local moveY = (dy / dist) * speed * dt
            transform.actualX = transform.actualX + moveX
            transform.actualY = transform.actualY + moveY

            -- Add a slight wobble for visual feedback
            transform.visualX = transform.actualX + math.sin(os.clock() * 8) * 2
            transform.visualY = transform.actualY

            coroutine.yield()
            return ActionResult.RUNNING
        else
            -- Reached waypoint
            log_debug("[DEMO] Entity", e, "reached waypoint", currentWaypoint)
            setBlackboardFloat(e, "patrol_waypoint", currentWaypoint)

            -- Complete after visiting all waypoints
            if currentWaypoint >= #waypoints then
                log_debug("[DEMO] Entity", e, "completed patrol circuit")
                return ActionResult.SUCCESS
            end

            coroutine.yield()
            return ActionResult.RUNNING
        end
    end,

    finish = function(e)
        log_debug("[DEMO] Entity", e, "finished patrol")
    end,

    abort = function(e, reason)
        log_debug("[DEMO] Patrol aborted for entity", e, "reason:", tostring(reason))
    end
}
