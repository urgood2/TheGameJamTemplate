return function(entity)
    local bb = get_blackboard(entity)
    bb.hunger = 0.5
    bb.enemy_visible = false
    bb.last_ate_time = 0
end