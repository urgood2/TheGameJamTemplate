-- wand_resource_bar_ui.lua
-- Planning phase UI showing mana cost prediction and overuse penalty

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

local function createBarUI()
    -- Destroy existing if present
    if state.uiBoxId then
        ui.box.DestroyUIBox(state.uiBoxId)
        state.uiBoxId = nil
    end

    local function getFillRatio()
        if state.maxMana <= 0 then return 0 end
        return math.min(state.totalManaCost / state.maxMana, 1.0)
    end

    local function getOverflowRatio()
        if state.maxMana <= 0 then return 0 end
        local overflow = math.max(0, state.totalManaCost - state.maxMana)
        return math.min(overflow / state.maxMana, 1.0)  -- Cap at 100% overflow
    end

    local function getBarColor()
        if state.totalManaCost > state.maxMana then
            return "orange"
        elseif state.totalManaCost >= state.maxMana * 0.9 then
            return "yellow"
        else
            return "cyan"
        end
    end

    local function getStatsText()
        local text = string.format("%d/%d mana  ·  %d cast blocks",
            state.totalManaCost, state.maxMana, state.castBlockCount)

        if state.overusePenaltySeconds > 0 then
            text = text .. string.format("  ·  +%.1fs Overuse Penalty", state.overusePenaltySeconds)
        end

        return text
    end

    local barUI = dsl.root {
        config = { padding = 4, background = "dark_panel" },
        children = {
            dsl.vbox {
                config = { gap = 4 },
                children = {
                    -- Main mana bar
                    dsl.hbox {
                        config = { gap = 0 },
                        children = {
                            -- Fill portion
                            dsl.box {
                                config = {
                                    minWidth = function()
                                        return CONFIG.barWidth * getFillRatio()
                                    end,
                                    minHeight = CONFIG.barHeight,
                                    background = getBarColor,
                                },
                            },
                            -- Empty portion (up to capacity)
                            dsl.box {
                                config = {
                                    minWidth = function()
                                        return CONFIG.barWidth * (1.0 - getFillRatio())
                                    end,
                                    minHeight = CONFIG.barHeight,
                                    background = "dark_gray",
                                },
                            },
                            -- Capacity marker
                            dsl.box {
                                config = {
                                    minWidth = 2,
                                    minHeight = CONFIG.barHeight + 4,
                                    background = "white",
                                },
                            },
                            -- Overflow zone
                            dsl.box {
                                config = {
                                    minWidth = function()
                                        return CONFIG.barWidth * 0.5 * getOverflowRatio()
                                    end,
                                    minHeight = CONFIG.barHeight,
                                    background = function()
                                        return getOverflowRatio() > 0 and "red" or "transparent"
                                    end,
                                },
                            },
                        },
                    },
                    -- Stats text
                    dsl.text(getStatsText, { fontSize = 12, color = "white" }),
                },
            },
        },
    }

    state.uiBoxId = dsl.spawn({ x = CONFIG.x, y = CONFIG.y }, barUI)
    ui.box.AssignStateTagsToUIBox(state.uiBoxId, PLANNING_STATE)

    return state.uiBoxId
end

function M.init(x, y)
    CONFIG.x = x or CONFIG.x
    CONFIG.y = y or CONFIG.y
end

function M.show()
    state.visible = true
    if not state.uiBoxId then
        createBarUI()
    end
end

function M.hide()
    state.visible = false
    if state.uiBoxId then
        ui.box.DestroyUIBox(state.uiBoxId)
        state.uiBoxId = nil
    end
end

function M.refresh()
    if state.visible and state.uiBoxId then
        -- UI DSL handles dynamic updates via functions
        -- Force redraw by destroying and recreating
        createBarUI()
    end
end

function M.update(wandDef, cardPool)
    if not wandDef or not cardPool then
        state.totalManaCost = 0
        state.castBlockCount = 0
        state.overusePenaltySeconds = 0
        return
    end

    -- Run simulation
    local simResult = cardEval.simulate_wand(wandDef, cardPool)
    if not simResult then return end

    -- Calculate total mana cost from all cards in all blocks
    local totalMana = 0
    for _, block in ipairs(simResult.blocks or {}) do
        for _, card in ipairs(block.cards or {}) do
            totalMana = totalMana + (card.mana_cost or 0)
        end
        -- Also count modifier costs
        for _, mod in ipairs(block.applied_modifiers or {}) do
            if mod.card then
                totalMana = totalMana + (mod.card.mana_cost or 0)
            end
        end
    end

    -- Store results
    state.totalManaCost = totalMana
    state.maxMana = wandDef.mana_max or 100
    state.castBlockCount = #(simResult.blocks or {})

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
        baseCooldown = baseCooldown / 1000  -- Convert ms to seconds

        state.overusePenaltySeconds = baseCooldown * (penaltyMult - 1.0)
    else
        state.overusePenaltySeconds = 0
    end
end

-- Getters for UI
function M.getManaCost() return state.totalManaCost end
function M.getMaxMana() return state.maxMana end
function M.getCastBlockCount() return state.castBlockCount end
function M.getOverusePenalty() return state.overusePenaltySeconds end
function M.isOverusing() return state.totalManaCost > state.maxMana end

-- Lifecycle cleanup
function M.cleanup()
    M.hide()
end

return M
