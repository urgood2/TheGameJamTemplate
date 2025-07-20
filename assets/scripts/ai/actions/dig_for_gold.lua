
-- Update function returns ActionResult.SUCCESS, ActionResult.RUNNING or ActionResult.FAILURE
-- Each action should have a start, update and finish function. Start is called once, update is called each frame and finish is called once.
-- The update function should return ActionResult.SUCCESS when the action is complete, ActionResult.RUNNING when the action is still running and ActionResult.FAILURE when the action has failed. It can also use functions like wait() to wait for a certain amount of time, but it must return one of the three values eventually.

return {
    name = "digforgold",
    cost = 1,
    pre = { candigforgold = true },
    post = { candigforgold = false },

    start = function(e)
        log_debug("Entity", e, "is digging for gold.")
    end,

    update = function(e, dt) -- update can be coroutine
        log_debug("Entity", e, "dig update.")
        
        local doneDiggng = false
        -- TODO: shake the entity for X seconds, spawn particles.
        -- Then spawn a gold coin at the given pace, then complete the action
        timer.every(0.5, 
            function()
              
                if not registry:valid(e) or e == entt_null then
                    log_debug("Entity", e, "is no longer valid, stopping dig action.")
                    return ActionResult.FAILURE
                end
                -- get transform
                local transform = registry:get(e, Transform)
                
                -- pull visual X a little to the left or the right, occilating based on time
                local offsetX = math.sin(os.clock() * 10) * 30 -- oscillate between -30 and 30
                transform.visualX = transform.visualX + offsetX
                
                playSoundEffect("effects", "dig-sound") -- play acid rain damage sound effect
                
                spawnCircularBurstParticles(
                    transform.visualX + transform.visualW / 2, -- center X
                    transform.visualY + transform.visualH / 2, -- center Y
                    3, -- number of particles
                    0.5
                )
            end,
            5, -- five times
            true, -- immediate
            function() -- on complete
                -- spawn a gold coin at the center of the entity
                doneDiggng = true
            end
        )
        
        local transform = registry:get(e, Transform)
        newTextPopup(
            localization.get("ui.digging"),
            transform.visualX + transform.visualW / 2,
            transform.visualY + transform.visualH / 2   
        )
        
        while true do
            if (doneDiggng) then
                break -- exit the loop if done digging
            else 
                coroutine.yield() -- yield until the next frame
            end
        end
        
        -- spawn a gold coin at the center of the entity
        local coinImage = animation_system.createAnimatedObjectWithTransform(
          "4024-TheRoguelike_1_10_alpha_817.png", -- animation ID
          true             -- use animation, not sprite identifier, if false
        )
        animation_system.resizeAnimationObjectsInEntityToFit(
          coinImage,
            globals.tileSize,   -- width
            globals.tileSize    -- height
        )
        
        playSoundEffect("effects", "gold-gain") -- play coin sound effect
        local transformComp = registry:get(coinImage, Transform)
        local t = registry:get(e, Transform)
        -- align above the character
        transformComp.actualX = t.actualX + t.actualW / 2 - transformComp.actualW / 2
        transformComp.actualY = t.actualY - transformComp.actualH / 2 - 5
        transformComp.visualX = transformComp.actualX -- snap X
        transformComp.visualY = transformComp.actualY -- snap Y
        
        newTextPopup("+ "..findInTable(
            globals.creature_defs,
            "id",
            "gold_digger"
          ).gold_produced_each_dig.."G",
          transformComp.visualX + transformComp.visualW / 2,
          transformComp.visualY + transformComp.visualH / 2,
        3,
          "color=chiffon_lemon" -- effect
        )
        
        timer.after(
          1.5,
          function()
            if not registry:valid(coinImage) then
              log_debug("Coin image entity is not valid, skipping tweening")
              return
            end
            
            
            -- tween the coin image to the currency UI box
            local uiBoxTransform = registry:get(globals.ui.currencyUIBox, Transform)
            local transformComp = registry:get(coinImage, Transform)
            transformComp.actualX = uiBoxTransform.actualX + uiBoxTransform.actualW / 2 - transformComp.actualW / 2
            transformComp.actualY = uiBoxTransform.actualY + uiBoxTransform.actualH / 2 - transformComp.actualH / 2
            
            
            
          end
        )
        
        -- delete it after 0.5 seconds
        timer.after(
          1.9, -- delay in seconds
          function()
            playSoundEffect("effects", "money-to-cash-pile") -- play coin sound effect
            if registry:valid(coinImage) then
              registry:destroy(coinImage) -- remove the coin image entity
            end
            -- add the currency to the player's resources
            globals.currency = globals.currency + (findInTable(
              globals.creature_defs,
              "id",
              "gold_digger"
            ).gold_produced_each_dig or 1) -- add the currency per day for the colonist home
          end
        )
        
        -- save the last time the gold digger dug for gold
        setBlackboardFloat(e, "last_dig_time", GetTime())
        
        return ActionResult.SUCCESS
    end,

    finish = function(e)
        log_debug("Done digging: entity", e)
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