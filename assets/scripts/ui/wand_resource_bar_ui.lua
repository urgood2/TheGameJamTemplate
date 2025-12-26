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

    -- Calculate overuse penalty
    if totalMana > state.maxMana then
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

return M
