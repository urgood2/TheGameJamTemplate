
-- Update function returns ActionResult.SUCCESS, ActionResult.RUNNING or ActionResult.FAILURE
-- Each action should have a start, update and finish function. Start is called once, update is called each frame and finish is called once.
-- The update function should return ActionResult.SUCCESS when the action is complete, ActionResult.RUNNING when the action is still running and ActionResult.FAILURE when the action has failed. It can also use functions like wait() to wait for a certain amount of time, but it must return one of the three values eventually.

return {
    name = "heal_other",
    cost = 1,
    pre = { canhealother = true },
    post = { canhealother = false },

    start = function(e)
        log_debug("Entity", e, "is healing others.")
    end,

    update = function(e, dt) -- update can be coroutine
        log_debug("Entity", e, "healing update.")
        
        -- TODO: make the sprite wooze, then apply healing to an entity who has less than max hp.
        local woozeDone = false
        timer.every(0.2,
            function()
                -- get transform
                local transform = registry:get(e, Transform)
                
                -- stretch either y or x, oscillating based on time
                local offsetY = math.sin(os.clock() * 10) * 30 -- oscillate between 
                transform.visualH = transform.visualH + offsetY
                local offsetX = math.sin(os.clock() * -10) * 30 -- oscillate between -30 and 30
                transform.visualW = transform.visualW + offsetX
                
            end,
            4, -- 4 times
            true, -- immediate
            function() -- on complete
                woozeDone = true
            end
        )
        while true do
            if (woozeDone) then
                break -- exit the loop if done healing
            else 
                coroutine.yield() -- yield until the next frame
            end
        end
        
        -- apply healing to an entity who has less than max hp
        local allEntities = {}
        lume.extend(allEntities, globals.gold_diggers)
        lume.extend(allEntities, globals.healers)
        lume.extend(allEntities, globals.damage_cushions)
        lume.extend(allEntities, globals.colonists)
        
        local toHeal = nil
        for _, entity in ipairs(allEntities) do
            local hp = getBlackboardFloat(entity, "health")
            local maxHp = getBlackboardFloat(entity, "max_health")
            if hp < maxHp then
                toHeal = entity
                break -- found an entity to heal
            end
        end
        
        if toHeal then
            -- heal the entity
            local hp = getBlackboardFloat(toHeal, "health")
            local maxHp = getBlackboardFloat(toHeal, "max_health")
            local healAmount = findInTable(globals.creature_defs, "id", "healer").heal_amount or 1 -- default to 1 if not found
            setBlackboardFloat(toHeal, "health", math.min(hp + healAmount, maxHp)) -- heal by 1, but not above max health
            log_debug("Healed entity", toHeal, "to", getBlackboardFloat(toHeal, "health"), "/", maxHp)
            
            -- local 
            local selfTransform = registry:get(e, Transform)
            newTextPopup(
                localization.get("ui.healing"),
                selfTransform.visualX + selfTransform.visualW / 2,
                selfTransform.visualY + selfTransform.visualH / 2   
            )
            
            -- spawn a healing particle effect at the entity's position
            local transform = registry:get(toHeal, Transform)
            spawnCircularBurstParticles(
                transform.visualX + transform.visualW / 2, -- center X
                transform.visualY + transform.visualH / 2, -- center Y
                19, -- number of particles
                0.5, -- particle size
                util.getColor("cyan_green"),
                util.getColor("blue_teal")
            )
            
            newTextPopup(
                "+ "..healAmount,
                transform.visualX + transform.visualW / 2,
                transform.visualY + transform.visualH / 2,
                3.0, -- duration
                "color=pastel_pink" -- effect
            )
        else
            log_debug("No entity to heal found.")
            newTextPopup("No entity to heal!")
        end
        
        -- set last heal time
        setBlackboardFloat(e, "last_heal_time", GetTime())
        
        return ActionResult.SUCCESS
    end,

    finish = function(e)
        log_debug("Done healing: entity", e)
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