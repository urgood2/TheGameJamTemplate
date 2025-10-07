return function(entity)
    -- if blackboard.hunger > 0.7 then
    if (ai.get_worldstate(entity, "duplicator_available")) then
        ai.set_goal(entity, { duplicator_available = false }) -- use duplicator
    else if (getBlackboardFloat(entity, "hunger")) > 0.3 then
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
end