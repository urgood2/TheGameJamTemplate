-- This script is called every frame to decide on the next goal.

logic = {}

function logic.select_goal(entity)
    debug(entity, "Selecting goal...")
    -- is the creature hungry?
    if getCurrentWorldStateValue(entity, "hungry") then
        clearGoalWorldState(entity)
        setGoalWorldStateValue(entity, "hungry", false) -- appease hunger
    -- is an enemy visible?
    elseif getCurrentWorldStateValue(entity, "enemyvisible") then
        clearGoalWorldState(entity)
        setGoalWorldStateValue(entity, "enemyalive", false) -- kill the enemy
    -- default to wandering. Wandered is also set to false every tick in case the wander action completes and needs to be repeated.
    else
        clearGoalWorldState(entity)
        setGoalWorldStateValue(entity, "wandered", true) -- wander around
    end
end

