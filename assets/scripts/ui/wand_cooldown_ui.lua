--[[
================================================================================
WAND COOLDOWN UI
================================================================================
Shows each loaded wand along the left edge in Action state with a rounded
container and a pie-style cooldown indicator.
]] --

local WandCooldownUI = {}

-- Dependencies
local WandExecutor = require("wand.wand_executor")
local z_orders = require("core.z_orders")

-- Layout configuration
local LEFT_MARGIN = 28
local TOP_MARGIN = 140
local CARD_WIDTH = 220
local CARD_HEIGHT = 68
local CARD_SPACING = 10
local CARD_RADIUS = 12

local PIE_RADIUS = 18
local PIE_THICKNESS = 6

local LABEL_FONT_SIZE = 20
local STATUS_FONT_SIZE = 14

local Z_BASE = z_orders.ui_tooltips + 7
local SPACE = layer.DrawCommandSpace.Screen

-- Colors
local COLOR_READY = util.getColor("green")
local COLOR_COOLDOWN = util.getColor("gray")
local COLOR_BG = Col(12, 12, 16, 210)
local COLOR_ACCENT = util.getColor("cyan")
local COLOR_RING_BG = Col(60, 60, 70, 180)
local COLOR_TEXT = util.getColor("white")

-- State
WandCooldownUI.isActive = false
WandCooldownUI.entries = {} -- wandId -> { label, cooldownMax, cooldownRemaining }

local function clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function ensureEntry(wandId, wandDef)
    local entry = WandCooldownUI.entries[wandId]
    if not entry then
        entry = {
            label = (wandDef and wandDef.id) or tostring(wandId),
            cooldownMax = 0,
            cooldownRemaining = 0,
        }
        WandCooldownUI.entries[wandId] = entry
    end
    return entry
end

local function computeProgress(entry)
    local remain = entry.cooldownRemaining or 0
    if remain <= 0 then
        return 1.0
    end

    local maxCooldown = entry.cooldownMax or 0
    if maxCooldown <= 0 then
        return 0.0
    end

    return clamp01(1.0 - (remain / maxCooldown))
end

function WandCooldownUI.init()
    WandCooldownUI.entries = {}
    WandCooldownUI.isActive = true
end

function WandCooldownUI.clear()
    WandCooldownUI.entries = {}
end

--- Update entries from WandExecutor state
function WandCooldownUI.update(dt)
    if not WandCooldownUI.isActive then return end
    if not is_state_active or not is_state_active(ACTION_STATE) then return end

    local active = WandExecutor.activeWands or {}
    local seen = {}

    for wandId, wandData in pairs(active) do
        local entry = ensureEntry(wandId, wandData.definition)
        local state = WandExecutor.getWandState(wandId)
        if state then
            local currentCooldown = state.cooldownRemaining or 0
            entry.cooldownRemaining = currentCooldown
            entry.currentMana = state.currentMana or 0
            entry.maxMana = state.maxMana or 0
            local lastExec = state.lastExecutionState or {}
            local overheatMult = lastExec.overheatPenaltyMult or 1.0
            entry.overheatMult = overheatMult
            entry.castProgress = state.currentCastProgress

            -- Track the last known max cooldown to compute progress.
            if currentCooldown > (entry.cooldownMax or 0) + 0.01 then
                entry.cooldownMax = currentCooldown
            end
        end
        seen[wandId] = true
    end

    -- Remove entries for wands that are no longer active
    for wandId, _ in pairs(WandCooldownUI.entries) do
        if not seen[wandId] then
            WandCooldownUI.entries[wandId] = nil
        end
    end
end

--- Draw UI cards on the left edge with cooldown pie indicators
function WandCooldownUI.draw()
    if not WandCooldownUI.isActive then return end
    if not is_state_active or not is_state_active(ACTION_STATE) then return end

    local wandIds = {}
    for wandId, _ in pairs(WandCooldownUI.entries) do
        table.insert(wandIds, wandId)
    end
    table.sort(wandIds)

    local anchorX = LEFT_MARGIN + CARD_WIDTH * 0.5
    local startY = TOP_MARGIN

    for idx, wandId in ipairs(wandIds) do
        local entry = WandCooldownUI.entries[wandId]
        if entry then
            local centerY = startY + (idx - 1) * (CARD_HEIGHT + CARD_SPACING) + CARD_HEIGHT * 0.5
            local isReady = (entry.cooldownRemaining or 0) <= 0
            local progress = computeProgress(entry)
            local castProgress = entry.castProgress

            local rectColor = isReady and COLOR_READY or COLOR_COOLDOWN
            local rectColorCol = Col(rectColor.r, rectColor.g, rectColor.b, 200)

            -- Card background
            command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
                c.x = anchorX
                c.y = centerY
                c.w = CARD_WIDTH
                c.h = CARD_HEIGHT
                c.rx = CARD_RADIUS
                c.ry = CARD_RADIUS
                c.color = COLOR_BG
            end, Z_BASE, SPACE)

            -- Status highlight overlay
            command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
                c.x = anchorX
                c.y = centerY
                c.w = CARD_WIDTH
                c.h = CARD_HEIGHT
                c.rx = CARD_RADIUS
                c.ry = CARD_RADIUS
                c.color = rectColorCol
            end, Z_BASE + 1, SPACE)

            -- Cooldown ring background
            local pieX = anchorX - (CARD_WIDTH * 0.5) + PIE_RADIUS + 12
            local pieY = centerY
            command_buffer.queueDrawCircleLine(layers.ui, function(c)
                c.x = pieX
                c.y = pieY
                c.innerRadius = PIE_RADIUS - PIE_THICKNESS
                c.outerRadius = PIE_RADIUS
                c.startAngle = -90
                c.endAngle = 270
                c.segments = 48
                c.color = COLOR_RING_BG
            end, Z_BASE + 2, SPACE)

            -- Cooldown progress arc
            if progress > 0 then
                local arcColor = isReady and COLOR_READY or COLOR_ACCENT
                command_buffer.queueDrawCircleLine(layers.ui, function(c)
                    c.x = pieX
                    c.y = pieY
                    c.innerRadius = PIE_RADIUS - PIE_THICKNESS
                    c.outerRadius = PIE_RADIUS
                    c.startAngle = -90
                    c.endAngle = -90 + (360 * progress)
                    c.segments = 64
                    c.color = Col(arcColor.r, arcColor.g, arcColor.b, 255)
                end, Z_BASE + 3, SPACE)
            end

            -- Text labels
            local textX = pieX + PIE_RADIUS + 14
            local labelY = centerY - 10
            local statusY = centerY + 4
            local manaY = centerY + 20

            command_buffer.queueDrawText(layers.ui, function(c)
                c.text = string.upper(entry.label or tostring(wandId))
                c.font = localization.getFont()
                c.fontSize = LABEL_FONT_SIZE
                c.x = textX
                c.y = labelY
                c.color = COLOR_TEXT
            end, Z_BASE + 4, SPACE)

            local statusText = isReady and "READY" or string.format("%.1fs", entry.cooldownRemaining or 0)
            if castProgress and castProgress.total and castProgress.total > 0 then
                local executed = math.min(castProgress.executed or 0, castProgress.total)
                statusText = string.format("CASTING %d/%d", executed, castProgress.total)
            elseif not isReady and entry.overheatMult and entry.overheatMult > 1.01 then
                statusText = string.format("%s (x%.2f OH)", statusText, entry.overheatMult)
            end
            command_buffer.queueDrawText(layers.ui, function(c)
                c.text = statusText
                c.font = localization.getFont()
                c.fontSize = STATUS_FONT_SIZE
                c.x = textX
                c.y = statusY
                c.color = COLOR_TEXT
            end, Z_BASE + 4, SPACE)

            -- Mana readout (for debugging/verification)
            local manaText = string.format("Mana: %.1f / %.1f", entry.currentMana or 0, entry.maxMana or 0)
            command_buffer.queueDrawText(layers.ui, function(c)
                c.text = manaText
                c.font = localization.getFont()
                c.fontSize = STATUS_FONT_SIZE
                c.x = textX
                c.y = manaY
                c.color = COLOR_TEXT
            end, Z_BASE + 4, SPACE)
        end
    end
end

return WandCooldownUI
