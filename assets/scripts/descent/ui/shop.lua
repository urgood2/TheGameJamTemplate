-- assets/scripts/descent/ui/shop.lua
--[[
================================================================================
DESCENT SHOP UI MODULE
================================================================================
Shop interface for Descent roguelike mode.

Features:
- Stock display with prices
- Player gold display
- Buy/sell/reroll buttons
- Cancel/back navigation

Usage:
    local shop_ui = require("descent.ui.shop")
    shop_ui.init(shop, player)
    shop_ui.open()
    shop_ui.update(dt)
    shop_ui.draw()
================================================================================
]]

local M = {}

-- Dependencies
local shop_module = require("descent.shop")
local items = require("descent.items")
local spec = require("descent.spec")

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local state = {
    open = false,
    shop = nil,
    player = nil,
    selected_idx = 1,
    scroll_offset = 0,
    visible_count = 8,
    mode = "browse",  -- "browse", "confirm_buy", "confirm_reroll"
    message = nil,
    message_timer = 0,
    on_close = nil,
}

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local config = {
    x = 100,
    y = 50,
    width = 400,
    height = 450,
    item_height = 32,
    padding = 10,
    
    colors = {
        background = { 25, 20, 15, 240 },
        border = { 150, 120, 80, 255 },
        text = { 200, 200, 200, 255 },
        selected = { 80, 60, 40, 255 },
        gold = { 255, 215, 0, 255 },
        sold = { 100, 100, 100, 200 },
        header = { 180, 150, 100, 255 },
        affordable = { 100, 200, 100, 255 },
        unaffordable = { 200, 100, 100, 255 },
        button = { 60, 50, 40, 255 },
        button_hover = { 90, 75, 55, 255 },
        message = { 255, 255, 200, 255 },
    },
}

--------------------------------------------------------------------------------
-- Input Bindings
--------------------------------------------------------------------------------

local bindings = {
    close = { "Escape", "X" },
    up = { "W", "Up", "K" },
    down = { "S", "Down", "J" },
    buy = { "B", "Enter", "Space" },
    reroll = { "R" },
    confirm = { "Y", "Enter" },
    cancel = { "N", "Escape" },
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function key_in_binding(key, binding_name)
    local keys = bindings[binding_name]
    if not keys then return false end
    for _, k in ipairs(keys) do
        if k == key then return true end
    end
    return false
end

local function get_stock()
    if not state.shop then return {} end
    return shop_module.get_stock() or {}
end

local function get_player_gold()
    if not state.player then return 0 end
    return state.player.gold or 0
end

local function can_afford(price)
    return get_player_gold() >= price
end

local function show_message(msg, duration)
    state.message = msg
    state.message_timer = duration or 2
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------

local function do_purchase()
    if not state.shop then return end
    
    local stock = get_stock()
    local item_entry = stock[state.selected_idx]
    if not item_entry then
        show_message("No item selected")
        return
    end
    
    if item_entry.sold then
        show_message("Already sold!")
        return
    end
    
    local result = shop_module.purchase(state.player, state.selected_idx)
    
    if result == shop_module.RESULT.SUCCESS then
        show_message("Purchased!")
    elseif result == shop_module.RESULT.INSUFFICIENT_GOLD then
        show_message("Not enough gold!")
    elseif result == shop_module.RESULT.ALREADY_SOLD then
        show_message("Already sold!")
    else
        show_message("Cannot purchase")
    end
    
    state.mode = "browse"
end

local function do_reroll()
    if not state.shop then return end
    
    local cost = shop_module.get_reroll_cost()
    if not can_afford(cost) then
        show_message("Cannot afford reroll (" .. cost .. " gold)")
        return
    end
    
    local result = shop_module.reroll(state.player)
    
    if result == shop_module.RESULT.SUCCESS then
        show_message("Stock refreshed!")
        state.selected_idx = 1
    else
        show_message("Cannot reroll")
    end
    
    state.mode = "browse"
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Initialize shop UI
--- @param shop table Shop module reference (optional, uses require)
--- @param player table Player state
function M.init(shop, player)
    state.shop = shop or shop_module
    state.player = player
end

--- Open shop UI
--- @param on_close function|nil Callback when shop closes
function M.open(on_close)
    state.open = true
    state.selected_idx = 1
    state.scroll_offset = 0
    state.mode = "browse"
    state.message = nil
    state.on_close = on_close
end

--- Close shop UI
function M.close()
    state.open = false
    state.mode = "browse"
    if state.on_close then
        state.on_close()
    end
end

--- Check if shop is open
--- @return boolean
function M.is_open()
    return state.open
end

--- Update shop UI
--- @param dt number Delta time
function M.update(dt)
    if not state.open then return end
    
    -- Update message timer
    if state.message_timer > 0 then
        state.message_timer = state.message_timer - dt
        if state.message_timer <= 0 then
            state.message = nil
        end
    end
end

--- Handle input for shop UI
--- @param key string Key pressed
--- @return boolean True if input was consumed
function M.handle_input(key)
    if not state.open then return false end
    
    -- Confirmation modes
    if state.mode == "confirm_buy" then
        if key_in_binding(key, "confirm") then
            do_purchase()
            return true
        elseif key_in_binding(key, "cancel") then
            state.mode = "browse"
            return true
        end
        return true  -- Consume all input in confirm mode
    end
    
    if state.mode == "confirm_reroll" then
        if key_in_binding(key, "confirm") then
            do_reroll()
            return true
        elseif key_in_binding(key, "cancel") then
            state.mode = "browse"
            return true
        end
        return true
    end
    
    -- Browse mode
    if key_in_binding(key, "close") then
        M.close()
        return true
    end
    
    local stock = get_stock()
    
    if key_in_binding(key, "up") then
        state.selected_idx = state.selected_idx - 1
        if state.selected_idx < 1 then
            state.selected_idx = #stock
        end
        return true
    end
    
    if key_in_binding(key, "down") then
        state.selected_idx = state.selected_idx + 1
        if state.selected_idx > #stock then
            state.selected_idx = 1
        end
        return true
    end
    
    if key_in_binding(key, "buy") then
        local item = stock[state.selected_idx]
        if item and not item.sold then
            if can_afford(item.price) then
                state.mode = "confirm_buy"
            else
                show_message("Not enough gold!")
            end
        elseif item and item.sold then
            show_message("Already sold!")
        end
        return true
    end
    
    if key_in_binding(key, "reroll") then
        local cost = shop_module.get_reroll_cost()
        if can_afford(cost) then
            state.mode = "confirm_reroll"
        else
            show_message("Cannot afford reroll (" .. cost .. " gold)")
        end
        return true
    end
    
    return false
end

--- Get render data for ImGui integration
--- @return table Render data with lines and components
function M.get_render_data()
    if not state.open then
        return { visible = false }
    end
    
    local data = {
        visible = true,
        title = "SHOP",
        config = config,
        player_gold = get_player_gold(),
        reroll_cost = shop_module.get_reroll_cost and shop_module.get_reroll_cost() or 50,
        mode = state.mode,
        message = state.message,
        items = {},
        selected_idx = state.selected_idx,
    }
    
    local stock = get_stock()
    for i, entry in ipairs(stock) do
        local item_data = {
            index = i,
            name = entry.item and entry.item.name or "Unknown Item",
            price = entry.price or 0,
            sold = entry.sold or false,
            selected = (i == state.selected_idx),
            affordable = can_afford(entry.price),
        }
        table.insert(data.items, item_data)
    end
    
    -- Footer controls
    data.controls = {
        { key = "B", label = "Buy" },
        { key = "R", label = "Reroll (" .. data.reroll_cost .. "g)" },
        { key = "Esc", label = "Close" },
    }
    
    if state.mode == "confirm_buy" then
        data.confirm_prompt = "Buy for " .. stock[state.selected_idx].price .. " gold? [Y/N]"
    elseif state.mode == "confirm_reroll" then
        data.confirm_prompt = "Reroll for " .. data.reroll_cost .. " gold? [Y/N]"
    end
    
    return data
end

--- Draw shop UI (placeholder for direct rendering)
--- In practice, use get_render_data() for ImGui integration
function M.draw()
    -- This would be called by a rendering system
    -- ImGui integration should use get_render_data() instead
    local data = M.get_render_data()
    if not data.visible then return end
    
    -- Placeholder: actual rendering done by engine's ImGui layer
    print("[Shop UI] Open with " .. #data.items .. " items")
end

--- Get current selection
--- @return number, table|nil Index and item entry
function M.get_selection()
    local stock = get_stock()
    return state.selected_idx, stock[state.selected_idx]
end

--- Set player reference
--- @param player table Player state
function M.set_player(player)
    state.player = player
end

--- Reset UI state
function M.reset()
    state.open = false
    state.selected_idx = 1
    state.scroll_offset = 0
    state.mode = "browse"
    state.message = nil
    state.message_timer = 0
end

return M
