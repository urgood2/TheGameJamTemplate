--[[
Tag Synergy Panel
Displays deck tag progress on the right side of the screen with small
pill indicators for each breakpoint so partially-filled synergies stay visible.
]]

local TagSynergyPanel = {}

local z_orders = require("core.z_orders")

local DEFAULT_THRESHOLDS = { 3, 5, 7, 9 }
local MAX_ROWS = 6

local function safeColor(name, fallback)
    local ok, c = pcall(util.getColor, name)
    if ok and c then return c end
    if fallback then
        local ok2, c2 = pcall(util.getColor, fallback)
        if ok2 and c2 then return c2 end
    end
    return Col(255, 255, 255, 255)
end

local colors = {
    panel = Col(12, 14, 20, 218),
    outline = safeColor("apricot_cream", "white"),
    header = safeColor("apricot", "white"),
    row = Col(20, 22, 30, 232),
    text = safeColor("white"),
    muted = safeColor("gray", "light_gray"),
    track = Col(36, 40, 52, 245),
}

local tag_palette = {
    Fire = safeColor("fiery_red", "red"),
    Ice = safeColor("baby_blue", "cyan"),
    Buff = safeColor("mint_green", "green"),
    Arcane = safeColor("purple", "plum"),
    Mobility = safeColor("teal_blue", "cyan"),
    Defense = safeColor("plum", "purple"),
    Poison = safeColor("moss_green", "green"),
    Summon = safeColor("apricot", "gold"),
    Hazard = safeColor("orange", "gold"),
    Brute = safeColor("fiery_red", "red"),
    Fatty = safeColor("marigold", "gold"),
}

TagSynergyPanel.entries = {}
TagSynergyPanel.breakpoints = {}
TagSynergyPanel.displayedCounts = {}
TagSynergyPanel._pulses = {}
TagSynergyPanel.isActive = false
TagSynergyPanel.layout = {
    marginX = 22,
    marginTop = 120,
    panelWidth = 360
}

local function clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function copyThresholds(list)
    local out = {}
    if list then
        for _, t in ipairs(list) do
            out[#out + 1] = t
        end
    end
    table.sort(out)
    return out
end

local function normalizeBreakpoints(raw)
    local result = {}
    if not raw then return result end

    for tag, thresholds in pairs(raw) do
        local sorted = {}
        for threshold, _ in pairs(thresholds or {}) do
            table.insert(sorted, threshold)
        end
        table.sort(sorted)
        result[tag] = sorted
    end

    return result
end

local function colorForTag(tag)
    return tag_palette[tag] or safeColor("light_gray", "white")
end

local function thresholdsFor(tag, breakpoints)
    local thresholds = breakpoints[tag]
    if thresholds and #thresholds > 0 then
        return thresholds
    end
    return DEFAULT_THRESHOLDS
end

function TagSynergyPanel.init(opts)
    TagSynergyPanel.breakpoints = normalizeBreakpoints(opts and opts.breakpoints or TagSynergyPanel.breakpoints)
    TagSynergyPanel.entries = {}
    TagSynergyPanel.displayedCounts = {}
    TagSynergyPanel._pulses = {}
    if opts and opts.layout then
        TagSynergyPanel.setLayout(opts.layout)
    end
    TagSynergyPanel.isActive = true
end

function TagSynergyPanel.setLayout(layout)
    if not layout then return end
    TagSynergyPanel.layout = {
        marginX = layout.marginX or TagSynergyPanel.layout.marginX,
        marginTop = layout.marginTop or TagSynergyPanel.layout.marginTop,
        panelWidth = layout.panelWidth or TagSynergyPanel.layout.panelWidth
    }
end

function TagSynergyPanel.setData(tagCounts, breakpoints)
    if breakpoints then
        TagSynergyPanel.breakpoints = normalizeBreakpoints(breakpoints)
    end

    local entries = {}
    for tag, count in pairs(tagCounts or {}) do
        if count and count > 0 then
            table.insert(entries, {
                tag = tag,
                count = count,
                thresholds = copyThresholds(thresholdsFor(tag, TagSynergyPanel.breakpoints)),
            })
        end
    end

    local seen = {}
    for _, entry in ipairs(entries) do
        seen[entry.tag] = true
    end

    table.sort(entries, function(a, b)
        if a.count == b.count then
            return a.tag < b.tag
        end
        return a.count > b.count
    end)

    for tag, _ in pairs(TagSynergyPanel.displayedCounts) do
        if not seen[tag] then
            TagSynergyPanel.displayedCounts[tag] = nil
            TagSynergyPanel._pulses[tag] = nil
        end
    end

    TagSynergyPanel.entries = entries
end

function TagSynergyPanel.update(dt)
    if not TagSynergyPanel.isActive then return end
    if not dt then dt = GetFrameTime() end

    TagSynergyPanel._pulses = TagSynergyPanel._pulses or {}

    for _, entry in ipairs(TagSynergyPanel.entries) do
        local previous = TagSynergyPanel.displayedCounts[entry.tag]
        if previous and previous ~= entry.count then
            TagSynergyPanel._pulses[entry.tag] = 1.0
        end
        TagSynergyPanel.displayedCounts[entry.tag] = entry.count
    end

    for tag, pulse in pairs(TagSynergyPanel._pulses) do
        TagSynergyPanel._pulses[tag] = math.max(0, pulse - dt * 2.4)
    end
end

local function drawSegment(left, top, width, height, fill, accent, tag, threshold, z, space, font)
    local centerX = left + width * 0.5
    local centerY = top + height * 0.5
    local radius = height * 0.45
    local partialColor = Col(accent.r, accent.g, accent.b, 180)
    local trackColor = colors.track

    command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
        c.x = centerX
        c.y = centerY
        c.w = width
        c.h = height
        c.rx = radius
        c.ry = radius
        c.color = trackColor
    end, z, space)

    if fill > 0 then
        local fillWidth = math.max(math.min(width, width * clamp01(fill)), math.min(width, 6))
        local fillCenter = left + fillWidth * 0.5
        command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
            c.x = fillCenter
            c.y = centerY
            c.w = fillWidth
            c.h = height
            c.rx = radius
            c.ry = radius
            c.color = (fill >= 1) and accent or partialColor
        end, z + 1, space)
    end

    if threshold then
        local label = tostring(threshold)
        local fontSize = 11
        local w = localization.getTextWidthWithCurrentFont(label, fontSize, 1)
        command_buffer.queueDrawText(layers.ui, function(c)
            c.text = label
            c.font = font
            c.x = centerX - w * 0.5
            c.y = top - fontSize - 2
            c.color = colors.muted
            c.fontSize = fontSize
        end, z + 2, space)
    end
end

function TagSynergyPanel.draw()
    if not TagSynergyPanel.isActive then return end
    if not globals or not layers or not command_buffer then return end

    local screenW = (globals.screenWidth and globals.screenWidth()) or (globals.getScreenWidth and globals.getScreenWidth()) or 1920
    local screenH = (globals.screenHeight and globals.screenHeight()) or (globals.getScreenHeight and globals.getScreenHeight()) or 1080
    local font = localization.getFont()
    local totalRows = math.min(#TagSynergyPanel.entries, MAX_ROWS)
    local layout = TagSynergyPanel.layout

    -- If nothing to show, render a small hint and exit.
    if totalRows == 0 then
        local hint = "Add tagged cards to start a synergy"
        local fontSize = 15
        local w = localization.getTextWidthWithCurrentFont(hint, fontSize, 1)
        local x = screenW - w - math.max(14, layout.marginX)
        local y = math.max(24, layout.marginTop - 56)
        command_buffer.queueDrawText(layers.ui, function(c)
            c.text = hint
            c.font = font
            c.x = x
            c.y = y
            c.color = colors.muted
            c.fontSize = fontSize
        end, (z_orders.ui_tooltips or 0) + 3, layer.DrawCommandSpace.Screen)
        return
    end

    local marginX = math.max(12, layout.marginX or 18)
    local marginTop = math.max(12, layout.marginTop or 60)
    local panelW = math.max(240, math.min(layout.panelWidth or 360, screenW - marginX * 2))
    local paddingX = 14
    local paddingY = 14
    local rowH = 56
    local rowSpacing = 8
    local headerH = 26
    local indicatorWidth = 160
    local indicatorHeight = 14

    local totalHeight = paddingY * 2 + headerH + (rowH * totalRows) + (rowSpacing * math.max(0, totalRows - 1))
    local panelLeft = math.max(marginX, screenW - panelW - marginX)
    local maxTop = math.max(12, screenH - totalHeight - 12)
    local panelTop = math.max(12, math.min(marginTop, maxTop))
    local panelCenterX = panelLeft + panelW * 0.5
    local panelCenterY = panelTop + totalHeight * 0.5
    local space = layer.DrawCommandSpace.Screen
    local baseZ = (z_orders.ui_tooltips or 0) + 3

    command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
        c.x = panelCenterX
        c.y = panelCenterY
        c.w = panelW
        c.h = totalHeight
        c.rx = 16
        c.ry = 16
        c.color = colors.panel
    end, baseZ, space)

    command_buffer.queueDrawRectangle(layers.ui, function(c)
        c.x = panelLeft
        c.y = panelTop
        c.width = panelW
        c.height = totalHeight
        c.color = colors.outline
        c.lineWidth = 2
    end, baseZ + 1, space)

    command_buffer.queueDrawText(layers.ui, function(c)
        c.text = "Tag Synergies"
        c.font = font
        c.x = panelLeft + paddingX
        c.y = panelTop + paddingY - 2
        c.color = colors.header
        c.fontSize = 18
    end, baseZ + 2, space)

    local rowLeft = panelLeft + paddingX
    local rowWidth = panelW - paddingX * 2
    local rowStartY = panelTop + paddingY + headerH

    for index = 1, totalRows do
        local entry = TagSynergyPanel.entries[index]
        local rowTop = rowStartY + (index - 1) * (rowH + rowSpacing)
        local rowCenterY = rowTop + rowH * 0.5
        local accent = colorForTag(entry.tag)
        local pulse = TagSynergyPanel._pulses[entry.tag] or 0
        local nameSize = 18 * (1 + pulse * 0.08)
        local subtitleSize = 12

        command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
            c.x = rowLeft + rowWidth * 0.5
            c.y = rowCenterY
            c.w = rowWidth
            c.h = rowH
            c.rx = 12
            c.ry = 12
            c.color = colors.row
        end, baseZ + 1, space)

        -- Title
        command_buffer.queueDrawText(layers.ui, function(c)
            c.text = entry.tag
            c.font = font
            c.x = rowLeft + 12
            c.y = rowCenterY - 16
            c.color = accent
            c.fontSize = nameSize
        end, baseZ + 2, space)

        -- Subtitle: count + next threshold hint
        local nextThreshold = nil
        for _, threshold in ipairs(entry.thresholds) do
            if entry.count < threshold then
                nextThreshold = threshold
                break
            end
        end
        local subtitle = nil
        if nextThreshold then
            subtitle = string.format("%d cards · %d to next", entry.count, math.max(0, nextThreshold - entry.count))
        else
            subtitle = string.format("%d cards · fully online", entry.count)
        end

        command_buffer.queueDrawText(layers.ui, function(c)
            c.text = subtitle
            c.font = font
            c.x = rowLeft + 12
            c.y = rowCenterY + 6
            c.color = colors.text
            c.fontSize = subtitleSize
        end, baseZ + 2, space)

        -- Segment indicator
        local indicatorLeft = rowLeft + rowWidth - indicatorWidth - 14
        local indicatorTop = rowCenterY - indicatorHeight * 0.5 + 8
        local spacing = 8
        local availableWidth = indicatorWidth - spacing * (math.max(1, #entry.thresholds) - 1)
        local segWidth = availableWidth / math.max(1, #entry.thresholds)

        for i, threshold in ipairs(entry.thresholds) do
            local left = indicatorLeft + (segWidth + spacing) * (i - 1)
            local fill = entry.count / threshold
            drawSegment(left, indicatorTop, segWidth, indicatorHeight, fill, accent, entry.tag, threshold, baseZ + 2, space, font)
        end
    end
end

return TagSynergyPanel
