-- wand_resource_bar_ui.lua
-- Planning phase UI showing mana cost prediction and overuse penalty

local signal = require("external.hump.signal")
local dsl = require("ui.ui_syntax_sugar")
local cardEval = require("core.card_eval_order_test")

local M = {}

-- State
local state = {
    uiBoxId = nil,
    visible = false,
    -- Cached simulation results
    totalManaCost = 0,
    maxMana = 100,
    castBlockCount = 0,
    overusePenaltySeconds = 0,
}

-- Configuration
local CONFIG = {
    barWidth = 220,
    barHeight = 16,
    x = 20,  -- Fixed position (will be set during init)
    y = 500,
}

function M.init(x, y)
    CONFIG.x = x or CONFIG.x
    CONFIG.y = y or CONFIG.y
end

function M.show()
    state.visible = true
    -- TODO: Create/show UI
end

function M.hide()
    state.visible = false
    -- TODO: Hide UI
end

function M.update(wandDef, cardPool)
    -- TODO: Run simulation and update display
end

return M
