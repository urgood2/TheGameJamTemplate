-- These will run every frame per ai entity.

return {
    hunger_check = function(entity, dt)
        -- TODO: Implement hunger check logic
        local bb = ai.get_blackboard(entity)
        if (bb:contains("hunger")) == false then
            log_debug("Hunger key not found in blackboard for entity: " .. tostring(entity))
            return
        end
        local hunger = bb:get_float("hunger")
        bb:set_float("hunger", hunger - dt * 0.01) -- decrement hunger over time
        log_debug("hunger_check: Hunger level for entity " .. tostring(entity) .. ": " .. tostring(hunger))
        
        if hunger < 0 then
            hunger = 0 -- ensure hunger does not go below 0
        end
        
        if hunger < 0.3 then
            ai.set_worldstate(entity, "hungry", hunger < 0.3) -- set world state based on hunger level
            
            -- check if worldstate has been set correctly
            if ai.get_worldstate(entity, "hungry") then
                log_debug("hunger_check: Entity " .. tostring(entity) .. " is set to hungry.")
            else
                log_error("hunger_check: Entity " .. tostring(entity) .. " is not set to hungry.")
            end
            
            log_debug("Entity " .. tostring(entity) .. " is hungry.")
        end
        
        
        -- bb.hunger = bb.hunger + dt * 0.01
        -- ai.set_worldstate(entity, "hungry", bb.hunger > 0.7)
    end,

    enemy_sight = function(entity, dt)
        -- TODO: Implement enemy sight check logic
        -- local visible = check_if_enemy_visible(entity)
        -- ai.set_worldstate(entity, "enemyvisible", visible)
        -- local bb = get_blackboard(entity)
        -- bb.enemy_visible = visible
    end,
    
    can_dig_for_gold = function(entity, dt)
        -- when's the last time the gold digger dug for gold?
        if (blackboardContains(entity, "last_dig_time") == false) then
            return
        end
        local dig_time =  getBlackboardFloat(entity, "last_dig_time")
        if (GetTime() - dig_time) < 10 then
            -- if the last dig time is less than 5 seconds ago, then we cannot dig for gold
            ai.set_worldstate(entity, "candigforgold", false)
            log_debug("can_dig_for_gold: Entity " .. tostring(entity) .. " cannot dig for gold yet.")
        else
            ai.set_worldstate(entity, "candigforgold", true)
            log_debug("can_dig_for_gold: Entity " .. tostring(entity) .. " can dig for gold now.")
        end
    end,
    
    avilable_duplicator = function(entity, dt)
        -- Check if the duplicator table is not empty, and there is one with taken flag not set
        local duplicatorAvailable = false
        if #globals.structures.duplicators > 0 then
            for _, duplicatorEntry in ipairs(globals.structures.duplicators) do
                if not duplicatorEntry.taken then
                    -- If we find a duplicator that is not taken, set the world state
                    ai.set_worldstate(entity, "duplicator_available", true)
                    log_debug("avilable_duplicator: Found an available duplicator for entity " .. tostring(entity))
                    -- save in blackboard
                    setBlackboardInt(entity, "duplicator_available", duplicatorEntry.entity)
                    duplicatorEntry.taken = true -- mark it as taken
                    
                    duplicatorAvailable = true
                    break
                end
            end
        end
        
        if not duplicatorAvailable then
            
            -- if we previously found one, then don't touch world state
            if blackboardContains(entity, "duplicator_available") and
               getBlackboardInt(entity, "duplicator_available") ~= -1 then
                log_debug("avilable_duplicator: one still available for entity ", tostring(entity))
                return
            end
            -- If no duplicator is available, set the world state to false
            ai.set_worldstate(entity, "duplicator_available", false)
            log_debug("avilable_duplicator: No available duplicators for entity " .. tostring(entity))
            -- save in blackboard
            setBlackboardInt(entity, "duplicator_available", -1) -- -1 indicates no duplicator available
        end
    end
}