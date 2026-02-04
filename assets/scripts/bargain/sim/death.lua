-- assets/scripts/bargain/sim/death.lua

local constants = require("bargain.sim.constants")
local terminal = require("bargain.sim.terminal")

local death = {}

local function emit_event(world, reason)
    world.events = world.events or {}
    world.events[#world.events + 1] = { type = "death", reason = reason }
end

local function player_dead(world)
    if not world.entities or not world.entities.order or not world.entities.by_id then
        return false
    end
    local player = world.entities.by_id[world.player_id]
    return player and (player.hp or 0) <= 0
end

function death.set(world, reason)
    if world.run_state ~= constants.RUN_STATES.RUNNING then
        return world.run_state
    end

    local ok = terminal.set_death(world, reason)
    if ok and not world._death_emitted then
        emit_event(world, reason or "death")
        world._death_emitted = true
    end
    return world.run_state
end

function death.check(world)
    if world.run_state ~= constants.RUN_STATES.RUNNING then
        return world.run_state
    end

    if player_dead(world) then
        return death.set(world, "hp")
    end

    return world.run_state
end

return death
