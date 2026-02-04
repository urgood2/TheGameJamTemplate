-- assets/scripts/bargain/sim/actions/deal_choose.lua

local constants = require("bargain.sim.constants")
local deal_apply = require("bargain.deals.apply")

local deal_choose = {}

local function offered_lookup(pending_offer)
    local lookup = {}
    if pending_offer and type(pending_offer.deals) == "table" then
        for _, id in ipairs(pending_offer.deals) do
            if type(id) == "string" then
                lookup[id] = true
            end
        end
    end
    return lookup
end

function deal_choose.apply(world, input)
    if type(world) ~= "table" then
        return false, "world_not_table"
    end
    if world.phase ~= constants.PHASES.DEAL_CHOICE then
        return false, "not_in_deal_choice"
    end
    if type(input) ~= "table" or input.type ~= "deal_choose" then
        return false, "invalid_input"
    end
    if type(input.deal_id) ~= "string" then
        return false, "missing_deal_id"
    end

    world.deal_state = world.deal_state or {}
    local pending = world.deal_state.pending_offer
    if not pending then
        return false, "no_pending_offer"
    end

    local offered = offered_lookup(pending)
    if not offered[input.deal_id] then
        return false, "deal_not_offered"
    end

    local ok, err = deal_apply.apply_deal(world, input.deal_id)
    if not ok then
        return false, err or "deal_apply_failed"
    end

    world.deal_state.pending_offer = nil
    world.phase = constants.PHASES.PLAYER_INPUT

    return true
end

return deal_choose
