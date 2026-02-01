-- assets/scripts/descent/ui/inventory.lua
--[[
================================================================================
DESCENT INVENTORY UI MODULE
================================================================================
Inventory list UI for Descent roguelike mode.
Simple list-based UX per spec (no grid/tetris).

Features:
- List view of inventory items
- Equipment display
- Selection and actions (use/equip/drop)
- Capacity indicator

Usage:
    local inv_ui = require("descent.ui.inventory")
    inv_ui.init(inventory, player)
    inv_ui.open()
    inv_ui.update(dt)
    inv_ui.draw()
]]

local M = {}

-- Dependencies
local items = require("descent.items")
local spec = require("descent.spec")

-- State
local state = {
    open = false,
    inventory = nil,
    player = nil,
    selected_idx = 1,
    scroll_offset = 0,
    visible_count = 10,
    action_mode = false,  -- True when showing action menu
}

-- Configuration
local config = {
    x = 50,
    y = 50,
    width = 300,
    height = 400,
    item_height = 24,
    padding = 10,
    
    colors = {
        background = { 20, 20, 30, 230 },
        border = { 100, 100, 120, 255 },
        text = { 200, 200, 200, 255 },
        selected = { 60, 60, 100, 255 },
        equipped = { 80, 120, 80, 255 },
        gold = { 255, 215, 0, 255 },
        header = { 150, 150, 180, 255 },
    },
}

-- Input bindings
local bindings = {
    close = { "Escape", "I" },
    up = { "W", "Up", "K" },
    down = { "S", "Down", "J" },
    use = { "U", "Enter" },
    equip = { "E" },
    drop = { "D" },
    examine = { "X" },
}

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

--- Initialize inventory UI
--- @param inventory table Player inventory
--- @param player table|nil Player state (for applying effects)
function M.init(inventory, player)
    state.inventory = inventory
    state.player = player
    state.selected_idx = 1
    state.scroll_offset = 0
    state.open = false
end

--- Set inventory reference (if changed)
--- @param inventory table
function M.set_inventory(inventory)
    state.inventory = inventory
end

--------------------------------------------------------------------------------
-- Open / Close
--------------------------------------------------------------------------------

--- Open inventory UI
function M.open()
    state.open = true
    state.selected_idx = 1
    state.scroll_offset = 0
    state.action_mode = false
end

--- Close inventory UI
function M.close()
    state.open = false
    state.action_mode = false
end

--- Toggle inventory UI
function M.toggle()
    if state.open then
        M.close()
    else
        M.open()
    end
end

--- Check if inventory is open
--- @return boolean
function M.is_open()
    return state.open
end

--------------------------------------------------------------------------------
-- Input Handling
--------------------------------------------------------------------------------

--- Check if key matches binding
--- @param key string Key pressed
--- @param binding_name string Binding to check
--- @return boolean
local function key_matches(key, binding_name)
    local keys = bindings[binding_name]
    if not keys then return false end
    for _, k in ipairs(keys) do
        if k == key then return true end
    end
    return false
end

--- Handle key input
--- @param key string Key pressed
--- @return boolean True if input was consumed
--- @return string|nil Action performed
--- @return any|nil Action result
function M.handle_input(key)
    if not state.open then
        return false, nil, nil
    end
    
    -- Close
    if key_matches(key, "close") then
        M.close()
        return true, "close", nil
    end
    
    -- Navigation
    if key_matches(key, "up") then
        M.select_prev()
        return true, "navigate", nil
    end
    
    if key_matches(key, "down") then
        M.select_next()
        return true, "navigate", nil
    end
    
    -- Actions on selected item
    local selected = M.get_selected()
    if not selected then
        return true, nil, nil
    end
    
    if key_matches(key, "use") then
        return true, M.use_selected()
    end
    
    if key_matches(key, "equip") then
        return true, M.equip_selected()
    end
    
    if key_matches(key, "drop") then
        return true, M.drop_selected()
    end
    
    return true, nil, nil  -- Consume input but no action
end

--------------------------------------------------------------------------------
-- Selection
--------------------------------------------------------------------------------

--- Select next item
function M.select_next()
    if not state.inventory then return end
    local count = #state.inventory.items
    if count == 0 then return end
    
    state.selected_idx = state.selected_idx + 1
    if state.selected_idx > count then
        state.selected_idx = 1
    end
    
    M.ensure_visible()
end

--- Select previous item
function M.select_prev()
    if not state.inventory then return end
    local count = #state.inventory.items
    if count == 0 then return end
    
    state.selected_idx = state.selected_idx - 1
    if state.selected_idx < 1 then
        state.selected_idx = count
    end
    
    M.ensure_visible()
end

--- Ensure selected item is visible
function M.ensure_visible()
    if state.selected_idx <= state.scroll_offset then
        state.scroll_offset = state.selected_idx - 1
    elseif state.selected_idx > state.scroll_offset + state.visible_count then
        state.scroll_offset = state.selected_idx - state.visible_count
    end
end

--- Get selected item
--- @return table|nil
function M.get_selected()
    if not state.inventory or #state.inventory.items == 0 then
        return nil
    end
    return state.inventory.items[state.selected_idx]
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------

--- Use selected item
--- @return string Action name
--- @return any Result
function M.use_selected()
    local selected = M.get_selected()
    if not selected then
        return "use", { result = items.RESULT.NOT_FOUND }
    end
    
    local result, effect, cost = items.use(state.inventory, selected.instance_id, state.player)
    
    -- Adjust selection if item was consumed
    if result == items.RESULT.SUCCESS then
        local count = #state.inventory.items
        if state.selected_idx > count then
            state.selected_idx = math.max(1, count)
        end
    end
    
    return "use", { result = result, effect = effect, cost = cost }
end

--- Equip selected item
--- @return string Action name
--- @return any Result
function M.equip_selected()
    local selected = M.get_selected()
    if not selected then
        return "equip", { result = items.RESULT.NOT_FOUND }
    end
    
    local result, old_item, cost = items.equip(state.inventory, selected.instance_id)
    
    return "equip", { result = result, old_item = old_item, cost = cost }
end

--- Drop selected item
--- @return string Action name
--- @return any Result
function M.drop_selected()
    local selected = M.get_selected()
    if not selected then
        return "drop", { result = items.RESULT.NOT_FOUND }
    end
    
    local result, dropped, cost = items.drop(state.inventory, selected.instance_id)
    
    -- Adjust selection
    if result == items.RESULT.SUCCESS then
        local count = #state.inventory.items
        if state.selected_idx > count then
            state.selected_idx = math.max(1, count)
        end
    end
    
    return "drop", { result = result, dropped = dropped, cost = cost }
end

--------------------------------------------------------------------------------
-- Update / Draw
--------------------------------------------------------------------------------

--- Update inventory UI
--- @param dt number Delta time
function M.update(dt)
    -- Currently no time-based updates needed
end

--- Draw inventory UI
function M.draw()
    if not state.open or not state.inventory then
        return
    end
    
    -- Draw using global DrawRectangle/DrawText if available
    -- This is a placeholder for the actual rendering
    M.draw_gui()
end

--- Draw inventory using GUI primitives
function M.draw_gui()
    -- Placeholder: actual rendering depends on engine
    -- The structure is here for when drawing functions are available
    
    local inv = state.inventory
    local x, y = config.x, config.y
    local w, h = config.width, config.height
    
    -- Would draw: background, border, header
    -- Header: "Inventory (count/capacity)"
    -- Gold display
    -- Equipped items section
    -- Item list with scrolling
    -- Selected item highlight
    -- Action hints at bottom
    
    -- For now, this is a structural placeholder
end

--- Get formatted inventory info for debug/console
--- @return string
function M.format()
    if not state.inventory then
        return "No inventory"
    end
    
    local inv = state.inventory
    local lines = {
        string.format("=== Inventory (%d/%d) ===", #inv.items, inv.capacity),
        string.format("Gold: %d", inv.gold),
        "",
        "Equipped:",
    }
    
    for slot, item in pairs(inv.equipped) do
        if item then
            table.insert(lines, string.format("  [%s] %s", slot, item.name))
        else
            table.insert(lines, string.format("  [%s] (empty)", slot))
        end
    end
    
    table.insert(lines, "")
    table.insert(lines, "Items:")
    
    for i, item in ipairs(inv.items) do
        local prefix = i == state.selected_idx and "> " or "  "
        local qty = item.quantity > 1 and string.format(" x%d", item.quantity) or ""
        table.insert(lines, string.format("%s%s%s", prefix, item.name, qty))
    end
    
    return table.concat(lines, "\n")
end

--- Get/set configuration
--- @param key string|nil
--- @param value any|nil
--- @return any
function M.config(key, value)
    if key == nil then
        return config
    end
    if value ~= nil then
        config[key] = value
    end
    return config[key]
end

return M
