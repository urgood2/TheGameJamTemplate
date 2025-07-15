return function(entity)
    --TODO: Implement goal selector for kobold
    -- local blackboard = get_blackboard(entity)
    -- if blackboard.hunger > 0.7 then
    log_debug("Kobold goal selector: Setting goal to not hungry for entity " .. tostring(entity))
        ai.set_goal(entity, { hungry = false })
    -- elseif blackboard.enemy_visible then
    --     ai.set_goal(entity, { enemyalive = false })
    -- else
    --     ai.set_goal(entity, { wandering = true })
    -- end
end