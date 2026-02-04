-- assets/scripts/bargain/deals/apply.lua

local loader = require("bargain.deals.loader")
local events = require("bargain.sim.events")

local apply = {}

local function ensure_stats(world)
    world.stats = world.stats or {}
    local defaults = {
        hp_lost_total = 0,
        turns_elapsed = 0,
        damage_dealt_total = 0,
        damage_taken_total = 0,
        forced_actions_count = 0,
        denied_actions_count = 0,
        visible_tiles_count = 0,
        resources_spent_total = 0,
    }
    for k, v in pairs(defaults) do
        if type(world.stats[k]) ~= "number" then
            world.stats[k] = v
        end
    end
end

local function apply_downside(world, downside)
    if type(downside) ~= "table" then
        return
    end
    ensure_stats(world)
    for key, delta in pairs(downside) do
        if type(delta) == "number" then
            world.stats[key] = (world.stats[key] or 0) + delta
        end
    end
end

local DISPATCH = {
    on_apply = function(world, deal)
        if type(deal.on_apply) == "function" then
            deal.on_apply(world)
        end
    end,
    on_floor_start = function(world, deal)
        if type(deal.on_floor_start) == "function" then
            deal.on_floor_start(world)
        end
    end,
    on_level_up = function(world, deal)
        if type(deal.on_level_up) == "function" then
            deal.on_level_up(world)
        end
    end,
}

local function run_hook(world, deal, hook)
    local handler = DISPATCH[hook]
    if handler then
        handler(world, deal)
    end
end

function apply.apply_deal(world, deal_id)
    if type(world) ~= "table" then
        return false, "world_not_table"
    end
    local data = loader.load()
    local deal = data.by_id[deal_id]
    if not deal then
        return false, "unknown_deal"
    end

    world.deal_state = world.deal_state or {}
    world.deal_state.chosen = world.deal_state.chosen or {}

    for _, existing in ipairs(world.deal_state.chosen) do
        if existing == deal_id then
            return false, "deal_already_chosen"
        end
    end

    apply_downside(world, deal.downside)
    table.insert(world.deal_state.chosen, deal_id)

    run_hook(world, deal, "on_apply")
    events.emit(world, { type = "deal_applied", deal_id = deal_id })

    return true
end

function apply.dispatch(world, hook)
    if type(world) ~= "table" then
        return false, "world_not_table"
    end
    local handler = DISPATCH[hook]
    if not handler then
        return false, "unknown_hook"
    end
    local chosen = {}
    if world.deal_state and type(world.deal_state.chosen) == "table" then
        chosen = world.deal_state.chosen
    end
    if #chosen == 0 then
        return true
    end
    local data = loader.load()
    for _, deal_id in ipairs(chosen) do
        local deal = data.by_id[deal_id]
        if deal then
            handler(world, deal)
        end
    end
    return true
end

return apply
