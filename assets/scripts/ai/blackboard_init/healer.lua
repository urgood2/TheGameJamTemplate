return function(entity)
    -- TODO: Initialize the blackboard for a kobold entity
    local bb = ai.get_blackboard(entity)
    bb:set_float("hunger", 0.5)
    bb:set_float("health", 5)
    bb:set_float("max_health", 10)
    bb:set_float("last_heal_time", 0) -- last time the healer healed
    
    log_debug("entity", entity, "hunger is", bb:get_float("hunger"))
    log_debug("Blackboard initialized for kobold entity: " .. tostring(entity))
end