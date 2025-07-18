return function(entity)
    -- if blackboard.hunger > 0.7 then
    if (ai.get_worldstate(entity, "candigforgold")) then
        ai.set_goal(entity, { candigforgold = false }) -- use dig for gold action
    else 
        ai.set_goal(entity, { wander = true }) -- use idle action
    end
end