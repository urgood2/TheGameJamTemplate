
-- Update function returns ActionResult.SUCCESS, ActionResult.RUNNING or ActionResult.FAILURE
-- Each action should have a start, update and finish function. Start is called once, update is called each frame and finish is called once.
-- The update function should return ActionResult.SUCCESS when the action is complete, ActionResult.RUNNING when the action is still running and ActionResult.FAILURE when the action has failed. It can also use functions like wait() to wait for a certain amount of time, but it must return one of the three values eventually.

return {
    name = "eat",
    cost = 1,
    pre = { hungry = true },
    post = { hungry = false },

    start = function(e)
        log_debug("Entity", e, "is eating.")
    end,

    update = function(e, dt) -- update can be coroutine
        log_debug("Entity", e, "eat update.")
        wait(1.0)
        local bb = ai.get_blackboard(e)
        bb:set_float("hunger", bb:get_float("hunger") + 0.5) -- increase hunger level
        return ActionResult.SUCCESS
    end,

    finish = function(e)
        log_debug("Done eating: entity", e)
    end
}


-- previous versio for reference:


-- wander = {}

-- function wander.start(entity)
--     log_debug(entity, "Wander action started");
--     setBlackboardFloat(entity, "time_spent_wandering", 0.0);  -- Store a custom variable
-- end

-- function wander.update(entity, deltaTime)
    
--     local timeSpent = getBlackboardFloat(entity, "time_spent_wandering");
--     timeSpent = timeSpent + deltaTime;
--     setBlackboardFloat(entity, "time_spent_wandering", timeSpent);
    
--     if timeSpent >= 10.0 then
--         log_debug(entity, "Wander action completed");
--         return ActionResult.SUCCESS;  -- Return true to indicate the action has completed
--     else 
--         log_debug(entity, "Wandering... " .. timeSpent .. " seconds passed.");
--         return ActionResult.RUNNING;  -- Return false to indicate the action is still running
--     end
    
--     --[[ alternatively, use yield() or one of the wait functions
    
--         while timeSpent < 10.0 do
--             coroutine.yield(); -- Yield until the next frame
--             timeSpent = getBlackboardFloat(entity, "time_spent_wandering");
--             timeSpent = timeSpent + deltaTime;
--             setBlackboardFloat(entity, "time_spent_wandering", timeSpent);
--         end
        
--     ]]
-- end

-- -- postconditions are updated automatically, no need to define them here
-- function wander.finish(entity)
--     log_debug(entity, "Wander action ended");
-- end