-- assets/scripts/bargain/sim/actions/deal_skip.lua

local constants = require("bargain.sim.constants")
local events = require("bargain.sim.events")

local deal_skip = {}

function deal_skip.apply(world, input)
    if type(world) ~= "table" then
        return false, "world_not_table"
    end
    if world.phase ~= constants.PHASES.DEAL_CHOICE then
        return false, "not_in_deal_choice"
    end
    if type(input) ~= "table" or input.type ~= "deal_skip" then
        return false, "invalid_input"
    end

    world.deal_state = world.deal_state or {}
    if not world.deal_state.pending_offer then
        return false, "no_pending_offer"
    end

    local pending = world.deal_state.pending_offer
    local deals = nil
    if pending and type(pending.deals) == "table" then
        deals = {}
        for i, id in ipairs(pending.deals) do
            deals[i] = id
        end
    end
    world.deal_state.pending_offer = nil
    world.phase = constants.PHASES.PLAYER_INPUT
    events.emit(world, { type = "deal_skipped", deals = deals })

    return true
end

return deal_skip
