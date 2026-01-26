--[[
================================================================================
DEMO ALERT - Alert action for GOAP AI Demo
================================================================================
High priority action triggered when threat_detected is true.
Makes the entity shake and turn red to show alert state.
]]

local component_cache = require("core.component_cache")

return {
    name = "demo_alert",
    cost = 1, -- Low cost = high priority when conditions met
    pre = { threat_detected = true, alert_complete = false },
    post = { threat_detected = false, alert_complete = true },
    watch = {}, -- Don't abort when worldstate changes - complete the alert

    start = function(e)
        log_debug("[DEMO] Entity", e, "ALERT! Threat detected!")
        setBlackboardFloat(e, "alert_start_time", os.clock())

        -- Visual feedback: spawn particles
        local transform = component_cache.get(e, Transform)
        if transform then
            spawnCircularBurstParticles(
                transform.actualX + (transform.actualW or 32) / 2,
                transform.actualY + (transform.actualH or 32) / 2,
                8, -- particle count
                0.5 -- duration
            )
        end
    end,

    update = function(e, dt)
        local transform = component_cache.get(e, Transform)
        if not transform then
            return ActionResult.FAILURE
        end

        local startTime = getBlackboardFloat(e, "alert_start_time") or os.clock()
        local elapsed = os.clock() - startTime

        -- Shake animation
        local shakeIntensity = 5 * (1 - elapsed / 2) -- Decreasing shake
        transform.visualX = transform.actualX + math.sin(elapsed * 30) * shakeIntensity
        transform.visualY = transform.actualY + math.cos(elapsed * 25) * shakeIntensity * 0.5

        -- Alert for 2 seconds then complete
        if elapsed >= 2.0 then
            transform.visualX = transform.actualX
            transform.visualY = transform.actualY
            return ActionResult.SUCCESS
        end

        coroutine.yield()
        return ActionResult.RUNNING
    end,

    finish = function(e)
        log_debug("[DEMO] Entity", e, "alert complete, returning to normal")
        local transform = component_cache.get(e, Transform)
        if transform then
            transform.visualX = transform.actualX
            transform.visualY = transform.actualY
        end
    end,

    abort = function(e, reason)
        log_debug("[DEMO] Alert aborted for entity", e, "reason:", tostring(reason))
    end
}
