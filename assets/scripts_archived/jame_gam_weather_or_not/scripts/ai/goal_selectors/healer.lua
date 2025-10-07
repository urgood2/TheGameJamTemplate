return function(entity)
    -- if blackboard.hunger > 0.7 then
    if (ai.get_worldstate(entity, "canhealother")) then
        ai.set_goal(entity, { canhealother = false }) -- use heal other action
    else 
        ai.set_goal(entity, { wander = true }) -- use idle action
    end
end