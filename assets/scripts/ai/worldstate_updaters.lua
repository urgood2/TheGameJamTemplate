return {
    hunger_check = function(entity, dt)
        -- TODO: Implement hunger check logic
        -- local bb = get_blackboard(entity)
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