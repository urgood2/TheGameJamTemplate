return function(entity)
    --TODO: Implement goal selector for kobold
    -- local blackboard = get_blackboard(entity)
    -- if blackboard.hunger > 0.7 then
    if (getBlackboardFloat(entity, "hunger")) > 0.3 then
        ai.set_worldstate(entity, "wander", false) -- reset wander state
        ai.set_goal(entity, { wander = true })
    else
        ai.set_goal(entity, { hungry = false }) -- eat
    end
    -- elseif blackboard.enemy_visible then
    --     ai.set_goal(entity, { enemyalive = false })
    -- else
    --     ai.set_goal(entity, { wandering = true })
    -- end
end