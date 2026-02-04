-- Serpent shop system (pure logic)
-- Handles shop offer generation, rerolls, buying, and selling.

local unit_factory = require("serpent.unit_factory")

local shop = {}

shop.SHOP_SLOTS = 5
shop.BASE_REROLL_COST = 2

local function rng_float(rng)
    if rng and rng.float then
        return rng:float()
    end
    if rng and rng.next then
        return rng:next()
    end
    return math.random()
end

local function rng_int(rng, min, max)
    if rng and rng.int then
        return rng:int(min, max)
    end
    return math.floor(rng_float(rng) * (max - min + 1)) + min
end

local function clone_snake_state(snake_state)
    local segments = {}
    if snake_state and snake_state.segments then
        for i, segment in ipairs(snake_state.segments) do
            segments[i] = segment
        end
    end

    return {
        segments = segments,
        min_len = snake_state and snake_state.min_len or 3,
        max_len = snake_state and snake_state.max_len or 8,
    }
end

local function clone_shop_state(shop_state)
    local offers = {}
    if shop_state and shop_state.offers then
        for i, offer in ipairs(shop_state.offers) do
            offers[i] = offer
        end
    end

    return {
        upcoming_wave = shop_state and shop_state.upcoming_wave or 1,
        reroll_count = shop_state and shop_state.reroll_count or 0,
        offers = offers,
    }
end

local function resolve_unit_def(unit_defs, def_id)
    if not unit_defs or not def_id then
        return nil
    end
    local direct = unit_defs[def_id]
    if direct then
        return direct
    end
    for _, def in pairs(unit_defs) do
        if def and def.id == def_id then
            return def
        end
    end
    return nil
end

local function build_tier_pools(unit_defs)
    local pools = { [1] = {}, [2] = {}, [3] = {}, [4] = {} }

    if unit_defs then
        for key, def in pairs(unit_defs) do
            if def and def.tier then
                local id = def.id or key
                table.insert(pools[def.tier], { id = id, def = def })
            end
        end
    end

    for tier = 1, 4 do
        table.sort(pools[tier], function(a, b)
            return a.id < b.id
        end)
    end

    return pools
end

local function select_tier(shop_odds, wave_num, rng)
    if shop_odds and shop_odds.select_tier then
        return shop_odds.select_tier(wave_num, rng_float(rng))
    end
    if shop_odds and shop_odds.get_tier_odds then
        local odds = shop_odds.get_tier_odds(wave_num)
        local roll = rng_float(rng)
        local cumulative = 0
        for tier = 1, 4 do
            cumulative = cumulative + (odds[tier] or 0)
            if roll < cumulative then
                return tier
            end
        end
    end
    return 1
end

local function unit_cost(unit_def, level)
    local lvl = math.floor(tonumber(level) or 1)
    if lvl < 1 then
        lvl = 1
    end
    local base_cost = unit_def and unit_def.cost or 0
    local scaled = base_cost * (3 ^ (lvl - 1))
    return math.floor(scaled + 0.00001)
end

local function refund_for_unit(unit_def, level)
    local refund = unit_cost(unit_def, level) * 0.5
    return math.floor(refund + 0.00001)
end

local function get_combine_logic(override)
    if override and override.apply_combines_until_stable then
        return override
    end
    local ok, combine_logic = pcall(require, "serpent.combine_logic")
    if ok and combine_logic and combine_logic.apply_combines_until_stable then
        return combine_logic
    end
    return nil
end

local function generate_offers(wave_num, rng, unit_defs, shop_odds)
    local pools = build_tier_pools(unit_defs)
    local offers = {}

    for slot = 1, shop.SHOP_SLOTS do
        local tier = select_tier(shop_odds, wave_num, rng)
        local pool = pools[tier] or {}
        if #pool == 0 then
            error("No unit defs available for tier " .. tostring(tier))
        end
        local idx = rng_int(rng, 1, #pool)
        local entry = pool[idx]
        offers[slot] = {
            slot = slot,
            def_id = entry.id,
            tier = tier,
            cost = entry.def.cost,
        }
    end

    return offers
end

function shop.enter_shop(upcoming_wave, gold, rng, unit_defs, shop_odds)
    return {
        upcoming_wave = upcoming_wave or 1,
        reroll_count = 0,
        offers = generate_offers(upcoming_wave or 1, rng, unit_defs, shop_odds),
    }
end

function shop.reroll(shop_state, rng, unit_defs, shop_odds)
    local reroll_count = shop_state and shop_state.reroll_count or 0
    local cost = shop.BASE_REROLL_COST + reroll_count
    local next_state = clone_shop_state(shop_state)
    next_state.reroll_count = reroll_count + 1
    next_state.offers = generate_offers(next_state.upcoming_wave, rng, unit_defs, shop_odds)
    return next_state, -cost
end

function shop.can_buy(shop_state, snake_state, gold, offer_index, unit_defs, id_state, combine_logic)
    local offers = shop_state and shop_state.offers or {}
    local offer = offers[offer_index]
    if not offer or not offer.def_id then
        return false
    end

    local unit_def = resolve_unit_def(unit_defs, offer.def_id)
    if not unit_def then
        return false
    end

    local cost = unit_cost(unit_def, 1)
    if (tonumber(gold) or 0) < cost then
        return false
    end

    local segments = snake_state and snake_state.segments or {}
    local max_len = snake_state and snake_state.max_len or 8
    if #segments < max_len then
        return true
    end

    local combiner = get_combine_logic(combine_logic)
    if not combiner or not id_state then
        return false
    end

    local temp_state = clone_snake_state(snake_state)
    local instance = unit_factory.create_instance(
        unit_def,
        id_state.next_instance_id or 1,
        id_state.next_acquired_seq or 1
    )
    table.insert(temp_state.segments, instance)

    local combined_state = combiner.apply_combines_until_stable(temp_state, unit_defs)
    return #combined_state.segments <= max_len
end

function shop.buy(shop_state, snake_state, gold, id_state, offer_index, unit_defs, combine_logic)
    if not shop.can_buy(shop_state, snake_state, gold, offer_index, unit_defs, id_state, combine_logic) then
        return shop_state, snake_state, gold, id_state, {}
    end

    local offers = shop_state and shop_state.offers or {}
    local offer = offers[offer_index]
    local unit_def = resolve_unit_def(unit_defs, offer.def_id)

    local next_id_state = {
        next_instance_id = id_state and id_state.next_instance_id or 1,
        next_acquired_seq = id_state and id_state.next_acquired_seq or 1,
        next_enemy_id = id_state and id_state.next_enemy_id,
    }

    local cost = unit_cost(unit_def, 1)
    local next_gold = (tonumber(gold) or 0) - cost

    local instance = unit_factory.create_instance(
        unit_def,
        next_id_state.next_instance_id,
        next_id_state.next_acquired_seq
    )
    next_id_state.next_instance_id = next_id_state.next_instance_id + 1
    next_id_state.next_acquired_seq = next_id_state.next_acquired_seq + 1

    local next_snake = clone_snake_state(snake_state)
    table.insert(next_snake.segments, instance)

    local events = {}
    local combiner = get_combine_logic(combine_logic)
    if combiner then
        local combined_state, combine_events = combiner.apply_combines_until_stable(next_snake, unit_defs)
        next_snake = combined_state
        if combine_events then
            events = combine_events
        end
    end

    local next_shop = clone_shop_state(shop_state)
    next_shop.offers[offer_index] = { slot = offer_index, sold = true }

    return next_shop, next_snake, next_gold, next_id_state, events
end

function shop.sell(snake_state, gold, instance_id, unit_defs)
    local segments = snake_state and snake_state.segments or {}
    local refund = nil
    local next_segments = {}

    for _, segment in ipairs(segments) do
        if segment.instance_id == instance_id then
            local unit_def = resolve_unit_def(unit_defs, segment.def_id)
            refund = refund_for_unit(unit_def, segment.level or 1)
        else
            table.insert(next_segments, segment)
        end
    end

    if refund == nil then
        return snake_state, gold
    end

    local next_state = clone_snake_state(snake_state)
    next_state.segments = next_segments
    return next_state, (tonumber(gold) or 0) + refund
end

return shop
