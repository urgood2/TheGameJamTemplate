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
        log_debug("Hunger level for entity " .. tostring(entity) .. ": " .. tostring(hunger))
        
        if hunger < 0 then
            hunger = 0 -- ensure hunger does not go below 0
        end
        
        if hunger < 0.3 then
            ai.set_worldstate(entity, "hungry", hunger < 0.3) -- set world state based on hunger level
            
            -- check if worldstate has been set correctly
            if ai.get_worldstate(entity, "hungry") then
                log_debug("Entity " .. tostring(entity) .. " is set to hungry.")
            else
                log_error("Entity " .. tostring(entity) .. " is not set to hungry.")
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
    end
}