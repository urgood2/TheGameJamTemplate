--[[
================================================================================
DEMO IDLE - Idle action for GOAP AI Demo
================================================================================
Makes the entity stand in place with a subtle breathing animation.
Low priority fallback action.
]]

local component_cache = require("core.component_cache")

return {
    name = "demo_idle",
    cost = 10, -- High cost makes it less desirable than other actions
    pre = { idle = false },
    post = { idle = true },
    watch = { "threat_detected", "tired", "patrolling" },

    start = function(e)
        log_debug("[DEMO] Entity", e, "starting idle")
        setBlackboardFloat(e, "idle_start_time", os.clock())
    end,

    update = function(e, dt)
        local transform = component_cache.get(e, Transform)
        if not transform then
            return ActionResult.FAILURE
        end

        local startTime = getBlackboardFloat(e, "idle_start_time") or os.clock()
        local elapsed = os.clock() - startTime

        -- Subtle breathing animation (scale pulse)
        local breathScale = 1.0 + math.sin(elapsed * 2) * 0.02
        transform.scaleX = breathScale
        transform.scaleY = breathScale

        -- Idle for 3 seconds then complete
        if elapsed >= 3.0 then
            transform.scaleX = 1.0
            transform.scaleY = 1.0
            return ActionResult.SUCCESS
        end

        coroutine.yield()
        return ActionResult.RUNNING
    end,

    finish = function(e)
        log_debug("[DEMO] Entity", e, "finished idle")
        local transform = component_cache.get(e, Transform)
        if transform then
            transform.scaleX = 1.0
            transform.scaleY = 1.0
        end
    end,

    abort = function(e, reason)
        log_debug("[DEMO] Idle aborted for entity", e, "reason:", tostring(reason))
        local transform = component_cache.get(e, Transform)
        if transform then
            transform.scaleX = 1.0
            transform.scaleY = 1.0
        end
    end
}
