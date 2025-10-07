

-- contains worldstate update functions that run every tick.
-- This is how we can have custom-added worldstate flags (i.e., isPoisoned) that are updated every tick of the ai loop.

-- Note that all functions in this file (under table "conditions") are read in indiscriminately and run every tick, as per scripting_config.json

-- This is a table of functions that are called every tick.
-- Each function should return true if the world state was updated, false otherwise.
-- The function signature is function(entity, deltaTime)

conditions = {}

-- update wandered to false every frame to let planner find new path if wander action is complete
function conditions.updateWandered(entity, deltaTime)
    setCurrentWorldStateValue(entity, "wandered", false)
    return true
end