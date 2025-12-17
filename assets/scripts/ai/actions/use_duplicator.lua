
-- Update function returns ActionResult.SUCCESS, ActionResult.RUNNING or ActionResult.FAILURE
-- Each action should have a start, update and finish function. Start is called once, update is called each frame and finish is called once.
-- The update function should return ActionResult.SUCCESS when the action is complete, ActionResult.RUNNING when the action is still running and ActionResult.FAILURE when the action has failed. It can also use functions like wait() to wait for a certain amount of time, but it must return one of the three values eventually.

local component_cache = require("core.component_cache")

return {
    name = "use_duplicator",
    cost = 1, -- lowest cost, as it is a common action
    pre = { duplicator_available = true },
    post = { duplicator_available = false },

    start = function(e)
        log_debug("Entity", e, "is going to duplicator.")
    end,

    update = function(e, dt) -- update can be coroutine
        log_debug("Entity", e, "use_duplicator update.")
        
        -- get the duplicator from the blackboard
        local duplicatorEntity = getBlackboardInt(e, "duplicator_available")
        
        -- set the duplicator to taken
        local entry = findInTable(globals.structures.duplicators, "entity", duplicatorEntity)
        entry.taken = true
        log_debug("use_duplicator: Entity", e, "is using duplicator", duplicatorEntity)

        local t = component_cache.get(duplicatorEntity, Transform)
        
        local goalLoc = Vec2(t.actualX, t.actualY)
        
        startEntityWalkMotion(e)
        -- while the entity is not at the target location, continue wandering
        while true do
            log_debug("use_duplicator: Entity", e, "moving towards duplicator at", goalLoc.x, goalLoc.y)
            if moveEntityTowardGoalOneIncrement(e, goalLoc, dt) == false then
                log_debug("Entity", e, "has reached the target location.")
                break -- exit the loop when the entity reaches the target location
            end
            setBlackboardInt(e, "duplicator_available", -1) -- reset the duplicator available in blackboard
        end
        return ActionResult.SUCCESS
    end,

    finish = function(e)
        log_debug("Done use_duplicator: entity", e)
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