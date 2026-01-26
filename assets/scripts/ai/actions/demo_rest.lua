--[[
================================================================================
DEMO REST - Rest action for GOAP AI Demo
================================================================================
Survival-band action triggered when tired is true.
Makes the entity shrink down briefly to show resting.
]]

local component_cache = require("core.component_cache")

return {
    name = "demo_rest",
    cost = 1,
    pre = { tired = true, rested = false },
    post = { tired = false, rested = true },
    watch = { "threat_detected" }, -- Will abort rest if threat detected

    start = function(e)
        log_debug("[DEMO] Entity", e, "starting rest (tired)")
        setBlackboardFloat(e, "rest_start_time", os.clock())
    end,

    update = function(e, dt)
        local transform = component_cache.get(e, Transform)
        if not transform then
            return ActionResult.FAILURE
        end

        local startTime = getBlackboardFloat(e, "rest_start_time") or os.clock()
        local elapsed = os.clock() - startTime
        local restDuration = 2.5

        -- Resting animation: shrink down then back up
        local progress = elapsed / restDuration
        local restScale
        if progress < 0.5 then
            -- Shrinking down
            restScale = 1.0 - (progress * 2) * 0.3
        else
            -- Growing back up
            restScale = 0.7 + ((progress - 0.5) * 2) * 0.3
        end

        transform.scaleX = restScale
        transform.scaleY = restScale

        -- Subtle bob
        transform.visualY = transform.actualY + math.sin(elapsed * 4) * 3

        if elapsed >= restDuration then
            transform.scaleX = 1.0
            transform.scaleY = 1.0
            transform.visualY = transform.actualY
            return ActionResult.SUCCESS
        end

        coroutine.yield()
        return ActionResult.RUNNING
    end,

    finish = function(e)
        log_debug("[DEMO] Entity", e, "finished resting, now rested")
        local transform = component_cache.get(e, Transform)
        if transform then
            transform.scaleX = 1.0
            transform.scaleY = 1.0
            transform.visualY = transform.actualY
        end
    end,

    abort = function(e, reason)
        log_debug("[DEMO] Rest aborted for entity", e, "reason:", tostring(reason))
        local transform = component_cache.get(e, Transform)
        if transform then
            transform.scaleX = 1.0
            transform.scaleY = 1.0
        end
    end
}
