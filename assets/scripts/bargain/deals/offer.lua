-- assets/scripts/bargain/deals/offer.lua

local loader = require("bargain.deals.loader")
local RNG = require("bargain.sim.rng")

local offer = {}

local function get_rng(world)
    if world and type(world.rng) == "table" and type(world.rng.weighted) == "function" then
        return world.rng
    end
    local seed = 0
    if world and type(world.seed) == "number" then
        seed = world.seed
    end
    return RNG.new(seed)
end

local function build_chosen_lookup(world)
    local chosen = {}
    if world and world.deal_state and type(world.deal_state.chosen) == "table" then
        for _, id in ipairs(world.deal_state.chosen) do
            chosen[id] = true
        end
    end
    return chosen
end

local function requirements_met(deal, chosen)
    if type(deal.requires) ~= "table" then
        return true
    end
    if #deal.requires == 0 then
        return true
    end
    for _, id in ipairs(deal.requires) do
        if type(id) == "string" and not chosen[id] then
            return false
        end
    end
    return true
end

local function collect_candidates(world)
    local data = loader.load()
    local chosen = build_chosen_lookup(world)
    local candidates = {}
    for _, deal in ipairs(data.list) do
        if not chosen[deal.id] and requirements_met(deal, chosen) then
            candidates[#candidates + 1] = deal
        end
    end
    return candidates
end

local function select_weighted(rng, candidates, count)
    local take = count or 3
    local pool = {}
    for i = 1, #candidates do
        pool[i] = candidates[i]
    end

    local out = {}
    local n = math.min(take, #pool)
    for _ = 1, n do
        local weights = {}
        for i = 1, #pool do
            weights[i] = pool[i].offers_weight or 1
        end
        local idx = rng:weighted(weights)
        local deal = table.remove(pool, idx)
        out[#out + 1] = deal.id
    end

    return out
end

function offer.generate(world, count)
    local rng = get_rng(world)
    local candidates = collect_candidates(world)
    if #candidates == 0 then
        return {}
    end
    return select_weighted(rng, candidates, count)
end

function offer.create_pending_offer(world, reason)
    if not world or type(world) ~= "table" then
        return nil
    end

    world.deal_state = world.deal_state or {}
    if world.deal_state.pending_offer then
        return world.deal_state.pending_offer
    end

    local ids = offer.generate(world, 3)
    local offer_data = {
        reason = reason or "floor_start",
        deals = ids,
    }

    world.deal_state.pending_offer = offer_data
    world.deal_state.offers = world.deal_state.offers or {}
    table.insert(world.deal_state.offers, offer_data)

    return offer_data
end

return offer
