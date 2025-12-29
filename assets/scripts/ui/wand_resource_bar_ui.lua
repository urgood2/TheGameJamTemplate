-- wand_resource_bar_ui.lua
-- Planning phase UI showing mana cost prediction and overuse penalty
-- Uses direct command_buffer rendering (no DSL)

local cardEval = require("core.card_eval_order_test")
local z_orders = require("core.z_orders")

local M = {}

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------

-- Match C++ util::getCornerSizeForRect: max(max(w,h)/60, 12)
local function getCornerRadius(w, h)
    return math.max(math.max(w, h) / 60, 12)
end

local function getBarRadius(h)
    return math.max(h * 0.5, 4)
end

local CONFIG = {
    barWidth = 220,
    barHeight = 16,
    overflowMaxWidth = 110,
    x = 20,
    y = 500,
    textFontSize = 14,
    padding = 8,
    gap = 6,
}

-- Z-ordering (below cards at z_orders.card=101, below board at z_orders.board=100)
local Z_BASE = z_orders.board - 10
local SPACE = layer.DrawCommandSpace.Screen

-- Colors
local COLOR_FILL_NORMAL = util.getColor("cyan")
local COLOR_FILL_WARNING = util.getColor("yellow")
local COLOR_FILL_DANGER = util.getColor("orange")
local COLOR_OVERFLOW = util.getColor("red")
local COLOR_EMPTY = Col(40, 40, 50, 200)
local COLOR_BG = Col(20, 20, 28, 220)
local COLOR_TEXT = util.getColor("white")
local COLOR_CAPACITY_MARKER = Col(255, 255, 255, 180)

local function measureText(text, size)
    if localization and localization.getTextWidthWithCurrentFont then
        return localization.getTextWidthWithCurrentFont(text, size, 1)
    end
    return (#tostring(text)) * size * 0.55
end

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local state = {
    visible = false,
    -- Cached simulation results
    totalManaCost = 0,
    maxMana = 100,
    castBlockCount = 0,
    overusePenaltySeconds = 0,
}

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

function M.init(x, y)
    CONFIG.x = x or CONFIG.x
    CONFIG.y = y or CONFIG.y
end

function M.show()
    state.visible = true
end

function M.hide()
    state.visible = false
end

function M.refresh()
    -- No-op: draw() handles rendering each frame
    -- Kept for API compatibility
end

function M.update(wandDef, cardPool)
    if not wandDef then return end
    if not cardPool or #cardPool == 0 then return end

    local validPool = {}
    local skipped = 0
    for _, card in ipairs(cardPool) do
        if card and type(card.handle) == "function" then
            table.insert(validPool, card)
        else
            skipped = skipped + 1
        end
    end

    print(string.format("[MANABAR] pool: total=%d valid=%d skipped=%d", 
        #cardPool, #validPool, skipped))

    if #validPool == 0 then return end

    for i, card in ipairs(validPool) do
        print(string.format("[MANABAR] simInput[%d]: %s mana=%s", 
            i, card.card_id or "?", tostring(card.mana_cost)))
    end

    local ok, simResult = pcall(cardEval.simulate_wand, wandDef, validPool)
    if not ok or not simResult then 
        print("[MANABAR] sim FAILED")
        return 
    end

    local totalMana = 0
    for _, block in ipairs(simResult.blocks or {}) do
        for _, card in ipairs(block.cards or {}) do
            totalMana = totalMana + (card.mana_cost or 0)
        end
        for _, mod in ipairs(block.applied_modifiers or {}) do
            if mod.card then
                totalMana = totalMana + (mod.card.mana_cost or 0)
            end
        end
    end

    local newMaxMana = wandDef.mana_max or 100
    local blockCount = #(simResult.blocks or {})
    
    print(string.format("[MANABAR] result: mana=%d/%d blocks=%d wand=%s",
        totalMana, newMaxMana, blockCount, tostring(wandDef.id)))

    state.totalManaCost = totalMana
    state.maxMana = newMaxMana
    state.castBlockCount = blockCount

    -- Calculate overuse penalty (guard against division by zero)
    if state.maxMana <= 0 then
        state.overusePenaltySeconds = 0
    elseif totalMana > state.maxMana then
        local deficit = totalMana - state.maxMana
        local ratio = deficit / state.maxMana
        local penaltyFactor = wandDef.overheat_penalty_factor or 5.0
        local penaltyMult = 1.0 + (ratio * penaltyFactor)

        -- Estimate base cooldown (cast delay + recharge)
        local baseCooldown = (simResult.total_cast_delay or 0) + (simResult.total_recharge_time or 0)
        baseCooldown = baseCooldown / 1000 -- Convert ms to seconds

        state.overusePenaltySeconds = baseCooldown * (penaltyMult - 1.0)
    else
        state.overusePenaltySeconds = 0
    end
end

--------------------------------------------------------------------------------
-- DRAW (called each frame from gameplay.lua)
--------------------------------------------------------------------------------

function M.draw()
    -- Guard: only draw when visible and in PLANNING_STATE
    if not state.visible then return end
    if not is_state_active or not is_state_active(PLANNING_STATE) then return end

    -- Calculate layout values
    local barX = CONFIG.x + CONFIG.padding
    local barY = CONFIG.y + CONFIG.padding
    local totalWidth = CONFIG.barWidth
    local totalHeight = CONFIG.barHeight

    -- Calculate fill ratios
    local fillRatio = 0
    if state.maxMana > 0 then
        fillRatio = math.min(state.totalManaCost / state.maxMana, 1.0)
    end

    local overflowRatio = 0
    if state.maxMana > 0 and state.totalManaCost > state.maxMana then
        local overflow = state.totalManaCost - state.maxMana
        overflowRatio = math.min(overflow / state.maxMana, 1.0)
    end

    -- Determine fill color based on capacity
    local fillColor = COLOR_FILL_NORMAL
    if state.totalManaCost > state.maxMana then
        fillColor = COLOR_FILL_DANGER
    elseif state.totalManaCost >= state.maxMana * 0.9 then
        fillColor = COLOR_FILL_WARNING
    end

    -- Calculate widths
    local fillWidth = math.max(0, math.floor(totalWidth * fillRatio))
    local overflowWidth = math.max(0, math.floor(CONFIG.overflowMaxWidth * overflowRatio))

    -- 1. Background container - size based on bar + overflow + text
    local statsText = string.format("%d/%d mana  |  %d cast blocks",
        state.totalManaCost, state.maxMana, state.castBlockCount)
    if state.overusePenaltySeconds > 0 then
        statsText = statsText .. string.format("  |  +%.1fs Overuse Penalty", state.overusePenaltySeconds)
    end
    local textWidth = measureText(statsText, CONFIG.textFontSize)
    
    local barTotalWidth = totalWidth + (overflowWidth > 0 and (overflowWidth + 4) or 0)
    local contentWidth = math.max(barTotalWidth, textWidth)
    local containerWidth = contentWidth + CONFIG.padding * 2
    local containerHeight = totalHeight + CONFIG.textFontSize + CONFIG.gap + CONFIG.padding * 2
    local containerCenterX = CONFIG.x + containerWidth / 2
    local containerCenterY = CONFIG.y + containerHeight / 2

    local containerRadius = getCornerRadius(containerWidth, containerHeight)
    command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
        c.x = containerCenterX
        c.y = containerCenterY
        c.w = containerWidth
        c.h = containerHeight
        c.rx = containerRadius
        c.ry = containerRadius
        c.color = COLOR_BG
    end, Z_BASE, SPACE)

    -- 2. Empty bar background
    local barCenterX = barX + totalWidth / 2
    local barCenterY = barY + totalHeight / 2

    local barRadius = getBarRadius(totalHeight)
    command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
        c.x = barCenterX
        c.y = barCenterY
        c.w = totalWidth
        c.h = totalHeight
        c.rx = barRadius
        c.ry = barRadius
        c.color = COLOR_EMPTY
    end, Z_BASE + 1, SPACE)

    -- 3. Fill bar (mana used, clamped to capacity)
    if fillWidth > 0 then
        local fillCenterX = barX + fillWidth / 2
        command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
            c.x = fillCenterX
            c.y = barCenterY
            c.w = fillWidth
            c.h = totalHeight
            c.rx = barRadius
            c.ry = barRadius
            c.color = Col(fillColor.r or 0, fillColor.g or 0, fillColor.b or 0, 255)
        end, Z_BASE + 2, SPACE)
    end

    -- 4. Capacity marker (vertical tick at 100% capacity, aligned with bar bottom)
    local capacityX = barX + totalWidth
    local tickHeight = 8
    command_buffer.queueDrawRectangle(layers.ui, function(c)
        c.x = capacityX - 1
        c.y = barY + totalHeight - tickHeight
        c.width = 2
        c.height = tickHeight
        c.color = COLOR_CAPACITY_MARKER
    end, Z_BASE + 3, SPACE)

    -- 5. Overflow zone (past capacity, rendered in red)
    if overflowWidth > 0 then
        local overflowStartX = capacityX + 3
        local overflowCenterX = overflowStartX + overflowWidth / 2
        command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
            c.x = overflowCenterX
            c.y = barCenterY
            c.w = overflowWidth
            c.h = totalHeight
            c.rx = barRadius
            c.ry = barRadius
            c.color = Col(COLOR_OVERFLOW.r or 0, COLOR_OVERFLOW.g or 0, COLOR_OVERFLOW.b or 0, 255)
        end, Z_BASE + 2, SPACE)
    end

    -- 6. Stats text
    local textY = barY + totalHeight + CONFIG.gap
    command_buffer.queueDrawText(layers.ui, function(c)
        c.text = statsText
        c.font = localization.getFont()
        c.fontSize = CONFIG.textFontSize
        c.x = barX
        c.y = textY
        c.color = COLOR_TEXT
    end, Z_BASE + 4, SPACE)
end

--------------------------------------------------------------------------------
-- GETTERS
--------------------------------------------------------------------------------

function M.getManaCost() return state.totalManaCost end

function M.getMaxMana() return state.maxMana end

function M.getCastBlockCount() return state.castBlockCount end

function M.getOverusePenalty() return state.overusePenaltySeconds end

function M.isOverusing() return state.totalManaCost > state.maxMana end

--------------------------------------------------------------------------------
-- LIFECYCLE
--------------------------------------------------------------------------------

function M.cleanup()
    M.hide()
end

return M
