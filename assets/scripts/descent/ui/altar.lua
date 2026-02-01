-- assets/scripts/descent/ui/altar.lua
--[[
================================================================================
DESCENT ALTAR UI MODULE
================================================================================
Altar interaction UI for Descent roguelike mode.

Features:
- Shows god info (name, title, description)
- Worship confirmation dialog
- Cancel/back always available
- Displays abilities and restrictions

Usage:
    local altar_ui = require("descent.ui.altar")
    altar_ui.open(altar_data, player)
    altar_ui.update(dt)
    altar_ui.draw()
]]

local M = {}

-- Dependencies
local god = require("descent.god")

-- State
local state = {
    open = false,
    altar = nil,
    player = nil,
    mode = "info",  -- "info", "confirm", "result"
    selected_option = 1,
    result_message = nil,
    result_success = false,
}

-- Configuration
local config = {
    x = 100,
    y = 80,
    width = 440,
    height = 320,
    padding = 20,

    colors = {
        background = { 25, 20, 35, 240 },
        border = { 120, 80, 140, 255 },
        title = { 220, 180, 255, 255 },
        subtitle = { 180, 140, 200, 255 },
        text = { 200, 200, 200, 255 },
        description = { 170, 170, 190, 255 },
        warning = { 255, 200, 100, 255 },
        selected = { 80, 60, 120, 255 },
        button = { 100, 80, 130, 255 },
        button_text = { 230, 230, 230, 255 },
        success = { 100, 200, 100, 255 },
        error = { 200, 100, 100, 255 },
    },
}

-- Input bindings
local bindings = {
    close = { "Escape" },
    up = { "W", "Up", "K" },
    down = { "S", "Down", "J" },
    confirm = { "Enter", "Space" },
    cancel = { "Escape", "Q" },
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function key_matches(key, binding_list)
    for _, k in ipairs(binding_list) do
        if key == k then
            return true
        end
    end
    return false
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Open altar UI
--- @param altar table Altar data from god.create_altar()
--- @param player table Player state
function M.open(altar, player)
    if not altar or not altar.god_id then
        return false, "Invalid altar data"
    end

    state.open = true
    state.altar = altar
    state.player = player
    state.mode = "info"
    state.selected_option = 1
    state.result_message = nil
    state.result_success = false

    return true
end

--- Close altar UI
function M.close()
    state.open = false
    state.altar = nil
    state.mode = "info"
end

--- Check if altar UI is open
--- @return boolean
function M.is_open()
    return state.open
end

--- Handle key input
--- @param key string Key pressed
--- @return boolean True if input was consumed
function M.handle_input(key)
    if not state.open then
        return false
    end

    -- Cancel/close always available
    if key_matches(key, bindings.close) or key_matches(key, bindings.cancel) then
        if state.mode == "result" then
            M.close()
            return true
        elseif state.mode == "confirm" then
            state.mode = "info"
            return true
        else
            M.close()
            return true
        end
    end

    if state.mode == "info" then
        -- Navigate options
        if key_matches(key, bindings.up) then
            state.selected_option = math.max(1, state.selected_option - 1)
            return true
        elseif key_matches(key, bindings.down) then
            state.selected_option = math.min(2, state.selected_option + 1)
            return true
        elseif key_matches(key, bindings.confirm) then
            if state.selected_option == 1 then
                -- Worship option
                if god.is_worshipping(state.player) then
                    state.result_message = "You are already worshipping a god."
                    state.result_success = false
                    state.mode = "result"
                else
                    state.mode = "confirm"
                end
            else
                -- Leave option
                M.close()
            end
            return true
        end

    elseif state.mode == "confirm" then
        if key_matches(key, bindings.up) or key_matches(key, bindings.down) then
            state.selected_option = state.selected_option == 1 and 2 or 1
            return true
        elseif key_matches(key, bindings.confirm) then
            if state.selected_option == 1 then
                -- Confirm worship
                local success, msg = god.worship(state.player, state.altar.god_id)
                state.result_message = msg
                state.result_success = success
                state.mode = "result"
            else
                -- Cancel
                state.mode = "info"
                state.selected_option = 1
            end
            return true
        end

    elseif state.mode == "result" then
        -- Any key closes result
        M.close()
        return true
    end

    return false
end

--- Update (for animations, etc)
--- @param dt number Delta time
function M.update(dt)
    -- No animations currently
end

--- Draw altar UI
function M.draw()
    if not state.open or not state.altar then
        return
    end

    local c = config.colors
    local x, y = config.x, config.y
    local w, h = config.width, config.height
    local pad = config.padding

    -- Background
    if love and love.graphics then
        love.graphics.setColor(c.background)
        love.graphics.rectangle("fill", x, y, w, h)
        love.graphics.setColor(c.border)
        love.graphics.rectangle("line", x, y, w, h)
    end

    local cy = y + pad

    -- Title: God name
    if love and love.graphics then
        love.graphics.setColor(c.title)
        love.graphics.print("Altar of " .. state.altar.god_name, x + pad, cy)
    end
    cy = cy + 28

    -- Subtitle: God title
    if love and love.graphics then
        love.graphics.setColor(c.subtitle)
        love.graphics.print(state.altar.god_title or "", x + pad, cy)
    end
    cy = cy + 24

    -- Separator
    cy = cy + 10

    -- Description
    if love and love.graphics then
        love.graphics.setColor(c.description)
        love.graphics.printf(
            state.altar.description or "",
            x + pad,
            cy,
            w - pad * 2,
            "left"
        )
    end
    cy = cy + 50

    -- Mode-specific content
    if state.mode == "info" then
        -- Current worship status
        if god.is_worshipping(state.player) then
            local info = god.get_worship_info(state.player)
            if love and love.graphics then
                love.graphics.setColor(c.warning)
                love.graphics.print("You worship " .. (info.god_name or "a god"), x + pad, cy)
            end
            cy = cy + 24
        end

        cy = cy + 20

        -- Options
        local options = { "Worship " .. state.altar.god_name, "Leave altar" }
        for i, opt in ipairs(options) do
            local is_sel = state.selected_option == i
            if love and love.graphics then
                if is_sel then
                    love.graphics.setColor(c.selected)
                    love.graphics.rectangle("fill", x + pad - 5, cy - 2, w - pad * 2 + 10, 22)
                end
                love.graphics.setColor(is_sel and c.button_text or c.text)
                love.graphics.print((is_sel and "> " or "  ") .. opt, x + pad, cy)
            end
            cy = cy + 24
        end

        -- Hint
        cy = y + h - 30
        if love and love.graphics then
            love.graphics.setColor(c.description)
            love.graphics.print("[Enter] Select  [Esc] Close", x + pad, cy)
        end

    elseif state.mode == "confirm" then
        -- Confirmation prompt
        if love and love.graphics then
            love.graphics.setColor(c.warning)
            love.graphics.printf(
                "Are you sure you want to worship " .. state.altar.god_name .. "?",
                x + pad,
                cy,
                w - pad * 2,
                "center"
            )
        end
        cy = cy + 40

        -- Warning about restrictions
        local god_data = god.get(state.altar.god_id)
        if god_data and god_data.restrictions and god_data.restrictions.no_spells then
            if love and love.graphics then
                love.graphics.setColor(c.error)
                love.graphics.printf(
                    "WARNING: " .. state.altar.god_name .. " forbids all magic!",
                    x + pad,
                    cy,
                    w - pad * 2,
                    "center"
                )
            end
            cy = cy + 30
        end

        cy = cy + 20

        -- Confirm options
        local options = { "Yes, worship", "No, go back" }
        for i, opt in ipairs(options) do
            local is_sel = state.selected_option == i
            if love and love.graphics then
                if is_sel then
                    love.graphics.setColor(c.selected)
                    love.graphics.rectangle("fill", x + w/2 - 60, cy - 2, 120, 22)
                end
                love.graphics.setColor(is_sel and c.button_text or c.text)
                love.graphics.printf(
                    (is_sel and "> " or "  ") .. opt,
                    x + pad,
                    cy,
                    w - pad * 2,
                    "center"
                )
            end
            cy = cy + 24
        end

    elseif state.mode == "result" then
        -- Result message
        if love and love.graphics then
            love.graphics.setColor(state.result_success and c.success or c.error)
            love.graphics.printf(
                state.result_message or "",
                x + pad,
                cy + 30,
                w - pad * 2,
                "center"
            )
        end

        cy = y + h - 30
        if love and love.graphics then
            love.graphics.setColor(c.description)
            love.graphics.printf("[Any key] Continue", x + pad, cy, w - pad * 2, "center")
        end
    end
end

--- Get altar state for testing
--- @return table
function M.get_state()
    return {
        open = state.open,
        mode = state.mode,
        selected_option = state.selected_option,
        god_id = state.altar and state.altar.god_id,
    }
end

return M
