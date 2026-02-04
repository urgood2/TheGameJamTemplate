-- assets/scripts/bargain/sim/victory.lua

local constants = require("bargain.sim.constants")
local terminal = require("bargain.sim.terminal")

local victory = {}

local function boss_alive(world)
    if not world.entities or not world.entities.order or not world.entities.by_id then
        return false
    end
    for _, id in ipairs(world.entities.order) do
        local entity = world.entities.by_id[id]
        if entity and entity.kind == "enemy" and entity.is_boss and (entity.hp or 0) > 0 then
            return true
        end
    end
    return false
end

local function emit_event(world)
    world.events = world.events or {}
    world.events[#world.events + 1] = { type = "victory" }
end

function victory.check(world)
    if world.run_state ~= constants.RUN_STATES.RUNNING then
        return world.run_state
    end

    if (world.floor_num or 0) >= 7 and not boss_alive(world) then
        local ok = terminal.set_victory(world)
        if ok and not world._victory_emitted then
            emit_event(world)
            world._victory_emitted = true
        end
    end

    return world.run_state
end

return victory
