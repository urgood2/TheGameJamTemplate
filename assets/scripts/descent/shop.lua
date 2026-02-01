-- assets/scripts/descent/shop.lua
--[[
================================================================================
DESCENT SHOP MODULE
================================================================================
Shop system for Descent roguelike mode.

Key features (per spec):
- Shop on floor 1
- Stock deterministic per seed+floor
- Purchase atomic (all or nothing)
- Insufficient gold shows message, consumes 0 turns
- Reroll cost enforced, deterministic

Usage:
    local shop = require("descent.shop")
    shop.init(rng_module)
    shop.generate(floor, seed)  -- Generate stock
    local result = shop.purchase(player, item_index)
================================================================================
]]

local M = {}

-- Dependencies
local spec = require("descent.spec")
local items_module = nil
local rng_module = nil

-- Shop configuration
local CONFIG = {
    -- Floors with shops (from spec)
    shop_floors = { 1 },  -- Floor 1 only in MVP
    
    -- Stock configuration
    items_min = 4,
    items_max = 6,
    
    -- Reroll configuration
    reroll_base_cost = 50,
    reroll_cost_multiplier = 2,  -- Each reroll doubles cost
    
    -- Price modifiers
    price_variance = 0.2,  -- +/- 20% from base value
    
    -- Shop stock item pool weights
    item_pool = {
        { id = "short_sword", weight = 10 },
        { id = "long_sword", weight = 5 },
        { id = "dagger", weight = 10 },
        { id = "leather_armor", weight = 10 },
        { id = "chain_mail", weight = 5 },
        { id = "health_potion", weight = 20 },
        { id = "mana_potion", weight = 15 },
    },
}

-- Shop state
local state = {
    floor = 0,
    seed = 0,
    stock = {},  -- Array of { item, price, sold }
    reroll_count = 0,
    open = false,
}

--------------------------------------------------------------------------------
-- Result Types
--------------------------------------------------------------------------------

M.RESULT = {
    SUCCESS = "success",
    INSUFFICIENT_GOLD = "insufficient_gold",
    ITEM_NOT_FOUND = "item_not_found",
    ALREADY_SOLD = "already_sold",
    NO_SHOP = "no_shop",
    CANNOT_REROLL = "cannot_reroll",
}

--------------------------------------------------------------------------------
-- Internal Helpers
--------------------------------------------------------------------------------

--- Check if floor has a shop
--- @param floor number Floor number
--- @return boolean
local function floor_has_shop(floor)
    for _, f in ipairs(CONFIG.shop_floors) do
        if f == floor then
            return true
        end
    end
    -- Also check spec
    local floor_spec = spec.floors.floors[floor]
    return floor_spec and floor_spec.shop == true
end

--- Select weighted random item from pool
--- @return string Item template ID
local function select_weighted_item()
    local total_weight = 0
    for _, entry in ipairs(CONFIG.item_pool) do
        total_weight = total_weight + entry.weight
    end
    
    local roll = rng_module.random_int(1, total_weight)
    local cumulative = 0
    
    for _, entry in ipairs(CONFIG.item_pool) do
        cumulative = cumulative + entry.weight
        if roll <= cumulative then
            return entry.id
        end
    end
    
    -- Fallback
    return CONFIG.item_pool[1].id
end

--- Calculate price for item with variance
--- @param item table Item instance
--- @return number Price
local function calculate_price(item)
    local base_value = item.value or 0
    
    -- Apply variance using RNG for determinism
    local variance_range = math.floor(base_value * CONFIG.price_variance)
    local variance = 0
    if variance_range > 0 then
        variance = rng_module.random_int(-variance_range, variance_range)
    end
    
    return math.max(1, base_value + variance)
end

--- Generate shop stock for current floor/seed
local function generate_stock()
    state.stock = {}
    
    local num_items = rng_module.random_int(CONFIG.items_min, CONFIG.items_max)
    
    for i = 1, num_items do
        local template_id = select_weighted_item()
        local item = items_module.create_item(template_id, 1)
        
        if item then
            local price = calculate_price(item)
            table.insert(state.stock, {
                item = item,
                price = price,
                sold = false,
                index = i,
            })
        end
    end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Initialize shop module
--- @param rng_ref table|nil RNG module (optional, will load)
--- @param items_ref table|nil Items module (optional, will load)
function M.init(rng_ref, items_ref)
    rng_module = rng_ref
    items_module = items_ref
    
    if not rng_module then
        rng_module = require("descent.rng")
    end
    
    if not items_module then
        items_module = require("descent.items")
    end
    
    -- Reset state
    state.floor = 0
    state.seed = 0
    state.stock = {}
    state.reroll_count = 0
    state.open = false
end

--- Generate shop for a floor
--- @param floor number Floor number
--- @param seed number|nil Optional seed (uses current if nil)
function M.generate(floor, seed)
    state.floor = floor
    state.reroll_count = 0
    state.open = floor_has_shop(floor)
    
    if not state.open then
        state.stock = {}
        return
    end
    
    -- Seed RNG for deterministic generation
    if seed then
        state.seed = seed
        -- Create deterministic subseed for shop on this floor
        local shop_seed = seed + (floor * 1000) + 42  -- Magic offset
        rng_module.init(shop_seed)
    end
    
    generate_stock()
end

--- Check if shop exists on current floor
--- @return boolean
function M.is_open()
    return state.open
end

--- Check if floor has a shop
--- @param floor number Floor number
--- @return boolean
function M.has_shop(floor)
    return floor_has_shop(floor)
end

--- Get current shop stock
--- @return table Array of { item, price, sold, index }
function M.get_stock()
    local stock = {}
    for _, entry in ipairs(state.stock) do
        table.insert(stock, {
            item = entry.item,
            price = entry.price,
            sold = entry.sold,
            index = entry.index,
        })
    end
    return stock
end

--- Get available (unsold) items
--- @return table Array of stock entries
function M.get_available()
    local available = {}
    for _, entry in ipairs(state.stock) do
        if not entry.sold then
            table.insert(available, {
                item = entry.item,
                price = entry.price,
                index = entry.index,
            })
        end
    end
    return available
end

--- Attempt to purchase an item
--- @param player table Player with gold field
--- @param item_index number Stock index (1-based)
--- @return string Result code
--- @return table|nil Purchased item
--- @return number Turn cost
function M.purchase(player, item_index)
    if not state.open then
        return M.RESULT.NO_SHOP, nil, 0
    end
    
    local stock_entry = state.stock[item_index]
    if not stock_entry then
        return M.RESULT.ITEM_NOT_FOUND, nil, 0
    end
    
    if stock_entry.sold then
        return M.RESULT.ALREADY_SOLD, nil, 0
    end
    
    -- Check gold
    local player_gold = player.gold or (player.inventory and player.inventory.gold) or 0
    if player_gold < stock_entry.price then
        return M.RESULT.INSUFFICIENT_GOLD, nil, 0
    end
    
    -- Atomic purchase: deduct gold and mark sold
    if player.gold then
        player.gold = player.gold - stock_entry.price
    elseif player.inventory then
        player.inventory.gold = player.inventory.gold - stock_entry.price
    end
    
    stock_entry.sold = true
    
    -- Return copy of item (shop keeps reference for display)
    local purchased = items_module.copy_table(stock_entry.item)
    purchased.instance_id = items_module.create_item(stock_entry.item.template_id).instance_id
    
    return M.RESULT.SUCCESS, purchased, spec.inventory.use.cost
end

--- Get reroll cost
--- @return number Cost to reroll
function M.get_reroll_cost()
    return CONFIG.reroll_base_cost * math.pow(CONFIG.reroll_cost_multiplier, state.reroll_count)
end

--- Attempt to reroll shop stock
--- @param player table Player with gold
--- @return string Result code
--- @return number Turn cost
function M.reroll(player)
    if not state.open then
        return M.RESULT.NO_SHOP, 0
    end
    
    local cost = M.get_reroll_cost()
    local player_gold = player.gold or (player.inventory and player.inventory.gold) or 0
    
    if player_gold < cost then
        return M.RESULT.INSUFFICIENT_GOLD, 0
    end
    
    -- Deduct cost
    if player.gold then
        player.gold = player.gold - cost
    elseif player.inventory then
        player.inventory.gold = player.inventory.gold - cost
    end
    
    -- Increment reroll count (affects next reroll cost)
    state.reroll_count = state.reroll_count + 1
    
    -- Regenerate stock (uses incremented seed for determinism)
    local reroll_seed = state.seed + (state.floor * 1000) + 42 + (state.reroll_count * 7)
    rng_module.init(reroll_seed)
    generate_stock()
    
    return M.RESULT.SUCCESS, 0
end

--- Get shop state (for saving/debugging)
--- @return table State snapshot
function M.get_state()
    return {
        floor = state.floor,
        seed = state.seed,
        open = state.open,
        reroll_count = state.reroll_count,
        stock_count = #state.stock,
        sold_count = #M.get_available() - #state.stock,
    }
end

--- Close shop (when leaving floor)
function M.close()
    state.open = false
end

--- Check if all items are sold
--- @return boolean
function M.is_sold_out()
    for _, entry in ipairs(state.stock) do
        if not entry.sold then
            return false
        end
    end
    return true
end

return M
