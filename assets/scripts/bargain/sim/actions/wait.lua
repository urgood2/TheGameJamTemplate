-- assets/scripts/bargain/sim/actions/wait.lua

local events = require("bargain.sim.events")

local wait = {}

function wait.apply(world)
    if type(world) ~= "table" then
        return false, "world_not_table"
    end
    events.emit(world, { type = "wait", entity_id = world.player_id })
    return true
end

return wait
