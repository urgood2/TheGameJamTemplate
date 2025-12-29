--[[
================================================================================
SUBCAST DEBUG UI
================================================================================
Lightweight overlay that shows sub-cast lifecycle events (scheduled/enqueued/
executed) so you can tell whether timers/collision triggers are firing.
Listens to the "debug_subcast" signal emitted by wand_executor.
]]--

local SubcastDebugUI = {}

local z_orders = require("core.z_orders")
local signal = require("external.hump.signal")
local timer = require("core.timer")

-- Lazy-load toggle state to avoid circular dependencies
local function isVisible()
    local ok, toggles = pcall(require, "ui.ui_overlay_toggles")
    if ok and toggles and toggles.isSubcastDebugVisible then
        return toggles.isSubcastDebugVisible()
    end
    return true -- Default to visible if toggles module not available
end

-- Layout / styling
local LEFT_MARGIN = 24
local TOP_MARGIN = 120
local ROW_HEIGHT = 24
local ROW_SPACING = 6
local ROW_WIDTH = 420
local CORNER_RADIUS = 12
local FONT_SIZE = 14
local MAX_ROWS = 8
local LIFETIME_PENDING = 8.0
local LIFETIME_AFTER_EXEC = 5.0

local Z_BASE = z_orders.ui_tooltips + 11
local SPACE = layer.DrawCommandSpace.Screen

SubcastDebugUI.enabled = rawget(_G, "DEBUG_SUBCAST") ~= nil and rawget(_G, "DEBUG_SUBCAST") or true
SubcastDebugUI.isActive = false
SubcastDebugUI.items = {}
SubcastDebugUI.itemsById = {}
SubcastDebugUI._subscribed = false

local function clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function stageColor(stage, pendingAge)
    if stage == "executed" then
        return util.getColor("green") or { r = 80, g = 200, b = 120, a = 255 }
    elseif stage == "enqueued" then
        return util.getColor("cyan") or { r = 90, g = 210, b = 255, a = 255 }
    elseif stage == "scheduled_timer" or stage == "registered_collision" or stage == "registered_death" then
        return util.getColor("yellow") or { r = 255, g = 210, b = 60, a = 255 }
    else
        return util.getColor("white") or { r = 230, g = 230, b = 230, a = 255 }
    end
end

local function ensureItem(payload)
    local traceId = payload.traceId or (payload.wandId or "?") .. ":" .. tostring(payload.timestamp or os.clock())
    local item = SubcastDebugUI.itemsById[traceId]
    if not item then
        item = {
            traceId = traceId,
            createdAt = os.clock(),
            updatedAt = os.clock(),
            stage = payload.stage,
            trigger = payload.trigger or payload.triggerType,
            wandId = payload.wandId,
            blockIndex = payload.blockIndex,
            cardIndex = payload.cardIndex,
            delay = payload.delay or payload.delaySeconds,
        }
        table.insert(SubcastDebugUI.items, item)
        SubcastDebugUI.itemsById[traceId] = item
    end
    return item
end

local function fmtNum(n)
    if n == nil then return "?" end
    return tostring(n)
end

local function buildText(item, now)
    local parts = {}
    table.insert(parts, string.format("[%s]", item.trigger or "?"))
    table.insert(parts, "wand=" .. tostring(item.wandId or "?"))
    table.insert(parts, string.format("b%s:c%s", fmtNum(item.blockIndex), fmtNum(item.cardIndex)))
    if item.delay then
        table.insert(parts, string.format("+%.2fs", tonumber(item.delay) or 0))
    end

    if item.stage == "executed" and item.executedAt and item.createdAt then
        table.insert(parts, string.format("executed %.2fs", item.executedAt - item.createdAt))
    elseif item.stage then
        table.insert(parts, item.stage)
    end

    if item.stage ~= "executed" then
        table.insert(parts, string.format("pending %.1fs", now - item.createdAt))
    end

    return table.concat(parts, "  ")
end

local function pruneOld(now)
    for i = #SubcastDebugUI.items, 1, -1 do
        local item = SubcastDebugUI.items[i]
        local lifetime = item.stage == "executed" and LIFETIME_AFTER_EXEC or LIFETIME_PENDING
        if (now - item.updatedAt) >= lifetime then
            SubcastDebugUI.itemsById[item.traceId] = nil
            table.remove(SubcastDebugUI.items, i)
        end
    end

    -- Cap list length
    while #SubcastDebugUI.items > MAX_ROWS do
        local oldest = table.remove(SubcastDebugUI.items, 1)
        if oldest then
            SubcastDebugUI.itemsById[oldest.traceId] = nil
        end
    end
end

function SubcastDebugUI.onEvent(payload)
    if not SubcastDebugUI.isActive then return end
    if not SubcastDebugUI.enabled then return end
    if not payload then return end

    local item = ensureItem(payload)
    item.stage = payload.stage or item.stage
    item.trigger = payload.trigger or payload.triggerType or item.trigger
    item.wandId = payload.wandId or item.wandId
    item.blockIndex = payload.blockIndex or (payload.parent and payload.parent.blockIndex) or item.blockIndex
    item.cardIndex = payload.cardIndex or (payload.parent and payload.parent.cardIndex) or item.cardIndex
    item.delay = payload.delay or payload.delaySeconds or item.delay
    item.updatedAt = os.clock()

    if payload.stage == "executed" then
        item.executedAt = os.clock()
    end
end

function SubcastDebugUI.init()
    if SubcastDebugUI.isActive then return end
    SubcastDebugUI.items = {}
    SubcastDebugUI.itemsById = {}
    SubcastDebugUI.isActive = true
    SubcastDebugUI.enabled = rawget(_G, "DEBUG_SUBCAST") ~= nil and rawget(_G, "DEBUG_SUBCAST") or true

    if not SubcastDebugUI._subscribed then
        signal.register("debug_subcast", SubcastDebugUI.onEvent)
        SubcastDebugUI._subscribed = true
    end

    -- Keep pruning stale entries
    timer.every(1.0, function()
        SubcastDebugUI.update(0)
    end, 0, true, nil, "subcast_debug_ui_prune", "subcast_debug_ui")

    print("[SubcastDebugUI] Initialized (toggle with global DEBUG_SUBCAST)")
end

function SubcastDebugUI.clear()
    SubcastDebugUI.items = {}
    SubcastDebugUI.itemsById = {}
    SubcastDebugUI.isActive = false
    timer.cancel("subcast_debug_ui_prune")
end

function SubcastDebugUI.update(dt)
    if not SubcastDebugUI.enabled or not SubcastDebugUI.isActive then return end
    pruneOld(os.clock())
end

function SubcastDebugUI.draw()
    if not SubcastDebugUI.enabled or not SubcastDebugUI.isActive then return end
    if not isVisible() then return end
    if not layers or not command_buffer or not localization or not globals then return end

    local now = os.clock()
    local startX = LEFT_MARGIN
    local startY = TOP_MARGIN

    for idx, item in ipairs(SubcastDebugUI.items) do
        local y = startY + (idx - 1) * (ROW_HEIGHT + ROW_SPACING)
        local text = buildText(item, now)
        local color = stageColor(item.stage, now - item.createdAt)
        local col = Col(color.r, color.g, color.b, color.a or 255)

        local textWidth = localization.getTextWidthWithCurrentFont and
            localization.getTextWidthWithCurrentFont(text, FONT_SIZE, 1) or (#text * (FONT_SIZE * 0.55))
        local boxWidth = math.max(ROW_WIDTH, textWidth + 16)

        -- Background
        command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
            c.x = startX + boxWidth * 0.5
            c.y = y + ROW_HEIGHT * 0.5
            c.w = boxWidth
            c.h = ROW_HEIGHT
            c.rx = CORNER_RADIUS
            c.ry = CORNER_RADIUS
            c.color = Col(16, 16, 22, 190)
        end, Z_BASE, SPACE)

        -- Accent strip (left edge)
        command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
            c.x = startX + 4
            c.y = y + ROW_HEIGHT * 0.5
            c.w = 6
            c.h = ROW_HEIGHT
            c.rx = 2
            c.ry = 2
            c.color = col
        end, Z_BASE + 1, SPACE)

        -- Text
        command_buffer.queueDrawText(layers.ui, function(c)
            c.text = text
            c.font = localization.getFont()
            c.x = startX + 14
            c.y = y + 4
            c.color = col
            c.fontSize = FONT_SIZE
        end, Z_BASE + 2, SPACE)
    end
end

return SubcastDebugUI
