--[[
Tag Synergy Panel
Displays deck tag progress on the right side of the screen with small
pill indicators for each breakpoint so partially-filled synergies stay visible.
]]

local TagSynergyPanel = {}

local z_orders = require("core.z_orders")
local component_cache = require("core.component_cache")
local dsl = require("ui.ui_syntax_sugar")
local HoverRegistry = require("ui.hover_registry")
-- local bit = require("bit")

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

local function resolveScreenSize()
    local screenW = 1920
    local screenH = 1080
    if globals then
        screenW = (globals.screenWidth and globals.screenWidth()) or (globals.getScreenWidth and globals.getScreenWidth()) or screenW
        screenH = (globals.screenHeight and globals.screenHeight()) or (globals.getScreenHeight and globals.getScreenHeight()) or screenH
    end
    return screenW, screenH
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

local tooltipStyle = {
    bg = Col(16, 18, 26, 240),
    inner = Col(24, 26, 36, 235),
    outline = safeColor("apricot_cream", "white"),
    title = safeColor("apricot", "white"),
    text = safeColor("white"),
    muted = safeColor("gray", "light_gray"),
    label = safeColor("apricot_cream", "white"),
    value = safeColor("white", "white"),
    fontName = "tooltip",
    padding = 12,
    outlineThickness = 2,
    maxWidth = 400,
    labelColumnMinWidth = 160,
    valueColumnMinWidth = 200,
    rowPadding = 6,
    innerPadding = 10,
    fontSize = 16,
    titleFontSize = 20,
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
TagSynergyPanel.breakpointDetails = {}
TagSynergyPanel.displayedCounts = {}
TagSynergyPanel._pulses = {}
TagSynergyPanel._hoverKey = nil
TagSynergyPanel._activeTooltip = nil
TagSynergyPanel._tooltips = {}
TagSynergyPanel._layoutCache = nil
TagSynergyPanel.isActive = false
TagSynergyPanel.layout = {
    marginX = 22,
    marginTop = 120,
    panelWidth = 420
}

-- Slide animation state
TagSynergyPanel._slideState = "hidden"  -- "hidden", "entering", "visible", "exiting"
TagSynergyPanel._slideProgress = 0       -- 0 = fully hidden, 1 = fully visible
TagSynergyPanel._slideSpeed = 4.0        -- Animation speed multiplier

local Easing = require("util.easing")

-- NOTE: Tooltip font is now loaded in gameplay.lua with language-specific selection
-- at the correct size (22px to match tooltipStyle.fontSize). Removed duplicate load
-- that was causing font size conflicts.

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
    local thresholdsOnly = {}
    local details = {}
    if not raw then return thresholdsOnly, details end

    for tag, thresholds in pairs(raw) do
        local sorted = {}
        thresholdsOnly[tag] = sorted
        details[tag] = {}
        for threshold, bonus in pairs(thresholds or {}) do
            table.insert(sorted, threshold)
            details[tag][threshold] = bonus
        end
        table.sort(sorted)
    end

    return thresholdsOnly, details
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

local function getMousePosition()
    if input then
        -- Prefer raw mouse input so we stay in screen-space even if the cursor
        -- entity isn't keeping up (e.g., controller focus).
        if input.getMousePos then
            local m = input.getMousePos()
            if m and m.x and m.y then
                return { x = m.x, y = m.y }
            end
        end
        if input.getMousePosition then
            local m = input.getMousePosition()
            if m and m.x and m.y then
                return { x = m.x, y = m.y }
            end
        end
    end

    if globals and globals.cursor and component_cache then
        local cursor = globals.cursor()
        if cursor then
            local t = component_cache.get(cursor, Transform)
            if t then
                local x = t.actualX or t.visualX
                local y = t.actualY or t.visualY
                if x and y then
                    return { x = x, y = y }
                end
            end
        end
    end
    return nil
end

local function pointInRect(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

local function wrapTextToWidth(text, maxWidth, fontSize)
    if not text then return {} end
    local plain = tostring(text)
    if not (localization and localization.getTextWidthWithCurrentFont) then
        return { plain }
    end
    local words = {}
    for w in plain:gmatch("%S+") do
        words[#words + 1] = w
    end
    if #words == 0 then return { plain } end

    local lines = {}
    local current = words[1]
    local function width(str)
        return localization.getTextWidthWithCurrentFont(str, fontSize or 12, 1)
    end

    for i = 2, #words do
        local candidate = current .. " " .. words[i]
        if width(candidate) <= maxWidth then
            current = candidate
        else
            lines[#lines + 1] = current
            current = words[i]
        end
    end
    lines[#lines + 1] = current
    return lines
end

local function makeLabelNode(text, color, fontSize)
    if not text or text == "" then return nil end
    return dsl.hbox {
        config = {
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
            padding = 0,
            minWidth = tooltipStyle.labelColumnMinWidth
        },
        children = {
            dsl.text(text, {
                color = color or tooltipStyle.label,
                fontSize = fontSize or tooltipStyle.fontSize or 16,
                fontName = tooltipStyle.fontName,
                align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER)
            })
        }
    }
end

local function makeValueNode(text, color, fontSize)
    if not text or text == "" then return nil end
    local effectiveFontSize = fontSize or tooltipStyle.fontSize or 16
    local maxWidth = (tooltipStyle.maxWidth or 400)
        - (tooltipStyle.labelColumnMinWidth or 0)
        - (tooltipStyle.padding or 0) * 2
        - (tooltipStyle.innerPadding or 0) * 2
    local lines = wrapTextToWidth(text, maxWidth, effectiveFontSize)
    local children = {}
    for _, line in ipairs(lines) do
        children[#children + 1] = dsl.text(line, {
            color = color or tooltipStyle.value,
            fontSize = effectiveFontSize,
            fontName = tooltipStyle.fontName,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER)
        })
    end
    return dsl.vbox {
        config = {
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
            padding = 0,
            minWidth = tooltipStyle.valueColumnMinWidth
        },
        children = children
    }
end

local function buildTooltipDef(title, rows, accent)
    local children = {}

    local titleNode = makeLabelNode(title, accent or tooltipStyle.title, tooltipStyle.titleFontSize or 20)
    if titleNode then
        children[#children + 1] = titleNode
    end

    for _, row in ipairs(rows or {}) do
        local labelNode = makeLabelNode(row.label, row.labelColor or tooltipStyle.label, row.fontSize)
        local valueNode = makeValueNode(row.value, row.valueColor or tooltipStyle.value, row.fontSize)
        if not labelNode then
            labelNode = dsl.hbox {
                config = {
                    align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
                    padding = 0,
                    minWidth = tooltipStyle.labelColumnMinWidth
                },
                children = {}
            }
        end
        if not valueNode then
            valueNode = dsl.hbox {
                config = {
                    align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
                    padding = 0,
                    minWidth = tooltipStyle.valueColumnMinWidth
                },
                children = {}
            }
        end

        children[#children + 1] = dsl.hbox {
            config = {
                align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
                padding = tooltipStyle.rowPadding or 0
            },
            children = { labelNode, valueNode }
        }
    end

    return dsl.root {
        config = {
            color = tooltipStyle.bg,
            padding = tooltipStyle.padding,
            outlineThickness = tooltipStyle.outlineThickness,
            outlineColor = tooltipStyle.outline,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
            shadow = true,
        },
        children = {
            dsl.vbox {
                config = {
                    color = tooltipStyle.inner,
                    padding = tooltipStyle.innerPadding,
                    align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
                },
                children = children
            }
        }
    }
end

local function destroyTooltip(key)
    local cached = TagSynergyPanel._tooltips[key]
    if not cached then return end
    if cached.entity and registry and registry.valid and registry:valid(cached.entity) then
        registry:destroy(cached.entity)
    end
    TagSynergyPanel._tooltips[key] = nil
end

local function resetTooltipCache()
    for key in pairs(TagSynergyPanel._tooltips) do
        destroyTooltip(key)
    end
    TagSynergyPanel._tooltips = {}
    TagSynergyPanel._activeTooltip = nil
end

local function getOrBuildTooltip(target)
    if not target or not target.key then return nil end
    local cached = TagSynergyPanel._tooltips[target.key]
    if cached and cached.signature == target.signature and cached.entity then
        return cached.entity
    end

    destroyTooltip(target.key)
    local def = buildTooltipDef(target.title or "Synergy", target.rows or {}, colorForTag(target.entry and target.entry.tag))
    local tooltipZ = (z_orders.ui_tooltips or 0) + 50
    local entity = dsl.spawn({ x = -2000, y = -2000 }, def, "ui", tooltipZ)
    
    if transform and transform.set_space then
        transform.set_space(entity, "screen")
    end
    
    if layer_order_system and layer_order_system.assignZIndexToEntity then
        layer_order_system.assignZIndexToEntity(entity, tooltipZ)
    end
    
    if ui and ui.box and ui.box.RenewAlignment then
        ui.box.RenewAlignment(registry, entity)
    end
    -- Snap visual dimensions to prevent tween-from-zero animation
    local t = component_cache.get(entity, Transform)
    if t then
        t.visualW = t.actualW or t.visualW
        t.visualH = t.actualH or t.visualH
    end
    if ui and ui.box and ui.box.AssignStateTagsToUIBox and PLANNING_STATE then
        ui.box.AssignStateTagsToUIBox(entity, PLANNING_STATE)
    end
    if remove_default_state_tag then
        remove_default_state_tag(entity)
    end
    TagSynergyPanel._tooltips[target.key] = {
        entity = entity,
        signature = target.signature
    }
    return entity
end

local function positionTooltip(entity, mouse)
    if not entity then return end
    if ui and ui.box and ui.box.RenewAlignment then
        ui.box.RenewAlignment(registry, entity)
    end
    local t = component_cache.get(entity, Transform)
    if not t then return end

    local screenW, screenH = resolveScreenSize()
    local w = t.actualW or 0
    local h = t.actualH or 0
    local margin = 12
    local offsetX = 16
    local offsetY = 16
    local x = (mouse and mouse.x + offsetX) or (screenW - w - margin)
    local y = (mouse and mouse.y + offsetY) or margin
    if tooltipStyle.maxWidth and tooltipStyle.maxWidth > 0 and w > tooltipStyle.maxWidth + tooltipStyle.padding * 2 then
        w = tooltipStyle.maxWidth + tooltipStyle.padding * 2
        t.actualW = w
        t.visualW = w
    end
    if x < margin then x = margin end
    if x + w > screenW - margin then x = math.max(margin, screenW - w - margin) end
    if y < margin then y = margin end
    if y + h > screenH - margin then y = math.max(margin, screenH - h - margin) end

    t.actualX = x
    t.visualX = x
    t.actualY = y
    t.visualY = y
end

local function hideActiveTooltip()
    if TagSynergyPanel._activeTooltip then
        local t = component_cache.get(TagSynergyPanel._activeTooltip, Transform)
        if t then
            t.actualX = -2000
            t.actualY = -2000
            t.visualX = t.actualX
            t.visualY = t.actualY
        end
    end
    TagSynergyPanel._activeTooltip = nil
    TagSynergyPanel._hoverKey = nil
end

local function clearHover()
    hideActiveTooltip()
    HoverRegistry.clear()
end

local statDescriptions = {
    burn_damage_pct = "Burn damage +%d%%",
    burn_tick_rate_pct = "Burn tick rate +%d%%",
    slow_potency_pct = "Slow potency +%d%%",
    damage_vs_frozen_pct = "Damage vs frozen +%d%%",
    buff_duration_pct = "Buff duration +%d%%",
    buff_effect_pct = "Buff potency +%d%%",
    chain_targets = function(v)
        local suffix = (v or 0) == 1 and "target" or "targets"
        return string.format("+%d chain %s", v or 0, suffix)
    end,
    on_move_proc_frequency_pct = "Move procs trigger %d%% faster",
    move_speed_pct = "Move speed +%d%%",
    damage_taken_reduction_pct = "Damage taken -%d%%",
    hazard_radius_pct = "Hazard radius +%d%%",
    hazard_damage_pct = "Hazard damage +%d%%",
    hazard_duration = "Hazard duration +%ds",
    max_poison_stacks_pct = "Max poison stacks +%d%%",
    summon_hp_pct = "Summon health +%d%%",
    summon_damage_pct = "Summon damage +%d%%",
    summon_persistence = "Summon persistence +%d",
    barrier_refresh_rate_pct = "Barrier refresh rate +%d%%",
    health_pct = "Max health +%d%%",
    melee_damage_pct = "Melee damage +%d%%",
    melee_crit_chance_pct = "Melee crit chance +%d%%",
}

local procDescriptions = {
    burn_explosion_on_kill = "Burn kills trigger an explosion",
    burn_spread = "Burn spreads to nearby enemies",
    bonus_damage_on_chilled = "Bonus damage against chilled targets",
    shatter_on_kill = "Frozen enemies shatter on death",
    buffs_apply_to_allies = "Buffs also apply to allies",
    chain_restores_cooldown = "Chain hits restore cooldown",
    chain_ricochets = "Chains ricochet to new targets",
    chain_nova = "Chain nova at the end of the bounce",
    move_proc_spray = "Move procs spray extra projectiles",
    move_evade_buff = "Gain an evade buff while moving",
    barrier_on_block = "Blocking grants a barrier",
    thorns_on_block = "Blocks retaliate with thorns",
    poison_ramp_damage = "Poison ramps damage over time",
    poison_spore_on_kill = "Poison kills release spores",
    poison_spread_on_death = "Poison spreads when enemies die",
    empower_minion_periodic = "Periodically empower your minions",
    hazard_chain_ignite = "Hazards chain-ignite nearby foes",
    melee_cleave = "Melee attacks cleave in an arc",
    regen_when_low = "Regenerate when low on health",
    survive_lethal = "Survive a lethal hit with a sliver",
    ally_hp_buff = "Allies gain a max health buff",
}

local function describeStat(stat, value)
    if not stat then return "Unknown bonus" end
    local formatter = statDescriptions[stat]
    if type(formatter) == "function" then
        return formatter(value or 0)
    elseif formatter then
        return string.format(formatter, value or 0)
    end

    local label = stat:gsub("_", " ")
    label = label:sub(1, 1):upper() .. label:sub(2)
    if value then
        if stat:find("_pct") then
            return string.format("%s +%d%%", label, value)
        end
        return string.format("%s +%s", label, tostring(value))
    end
    return label
end

local function describeProc(procId)
    if not procId then return "Unlocks a new effect" end
    if procDescriptions[procId] then
        return procDescriptions[procId]
    end
    local label = procId:gsub("_", " ")
    return label:sub(1, 1):upper() .. label:sub(2)
end

local function describeBonus(tag, threshold)
    local detail = TagSynergyPanel.breakpointDetails[tag]
    if detail then
        detail = detail[threshold]
    end
    if not detail then
        return "Unknown bonus"
    end

    if detail.type == "stat" then
        return describeStat(detail.stat, detail.value)
    elseif detail.type == "proc" then
        return describeProc(detail.proc_id)
    end
    return "Unknown bonus"
end

local function formatThresholdStatus(entry, threshold)
    local count = entry.count or 0
    if count >= threshold then
        return string.format("Active (%d/%d %s tags)", count, threshold, entry.tag)
    end
    local remaining = threshold - count
    local noun = remaining == 1 and "tag" or "tags"
    return string.format("%d/%d %s tags — %d more %s", count, threshold, entry.tag, remaining, noun)
end

local function computeLayoutCache()
    local screenW, screenH = resolveScreenSize()
    local totalRows = math.min(#TagSynergyPanel.entries, MAX_ROWS)
    local layout = TagSynergyPanel.layout
    local marginX = math.max(12, layout.marginX or 18)
    local baseMarginTop = math.max(12, layout.marginTop or 60)
    
    local buttonBounds = TagSynergyPanel._toggleButtonBounds
    local marginTop = baseMarginTop
    if buttonBounds then
        local buttonBottom = (buttonBounds.y or 0) + (buttonBounds.h or 40) + 12
        marginTop = math.max(baseMarginTop, buttonBottom)
    end
    
    local panelW = math.max(240, math.min(layout.panelWidth or 360, screenW - marginX * 2))
    local paddingX = 14
    local paddingY = 14
    local rowH = 56
    local rowSpacing = 8
    local headerH = 26
    local indicatorWidth = 160
    local indicatorHeight = 14
    local panelRadius = 16
    local outlineWidth = 2

    local totalHeight = paddingY * 2 + headerH + (rowH * totalRows) + (rowSpacing * math.max(0, totalRows - 1))
    local panelLeft = math.max(marginX, screenW - panelW - marginX)
    local maxTop = math.max(12, screenH - totalHeight - 12)
    local panelTop = math.max(12, math.min(marginTop, maxTop))
    local panelCenterX = panelLeft + panelW * 0.5
    local panelCenterY = panelTop + totalHeight * 0.5

    local rowLeft = panelLeft + paddingX
    local rowWidth = panelW - paddingX * 2
    local rowStartY = panelTop + paddingY + headerH
    local rows = {}

    for index = 1, totalRows do
        local entry = TagSynergyPanel.entries[index]
        local rowTop = rowStartY + (index - 1) * (rowH + rowSpacing)
        local rowCenterY = rowTop + rowH * 0.5
        local indicatorLeft = rowLeft + rowWidth - indicatorWidth - 14
        local indicatorTop = rowCenterY - indicatorHeight * 0.5 + 8
        local spacing = 8
        local availableWidth = indicatorWidth - spacing * (math.max(1, #entry.thresholds) - 1)
        local segWidth = availableWidth / math.max(1, #entry.thresholds)
        local segments = {}
        for i, threshold in ipairs(entry.thresholds) do
            local left = indicatorLeft + (segWidth + spacing) * (i - 1)
            segments[#segments + 1] = {
                left = left,
                top = indicatorTop,
                width = segWidth,
                height = indicatorHeight,
                threshold = threshold
            }
        end

        -- Calculate the max width for text before it overlaps with indicators
        local textMaxWidth = indicatorLeft - rowLeft - 24  -- 12px left margin + 12px gap

        rows[#rows + 1] = {
            entry = entry,
            top = rowTop,
            centerY = rowCenterY,
            rowLeft = rowLeft,
            rowWidth = rowWidth,
            rowHeight = rowH,
            segments = segments,
            textMaxWidth = textMaxWidth
        }
    end

    return {
        screenW = screenW,
        screenH = screenH,
        totalRows = totalRows,
        marginX = marginX,
        marginTop = marginTop,
        panelW = panelW,
        paddingX = paddingX,
        paddingY = paddingY,
        rowH = rowH,
        rowSpacing = rowSpacing,
        headerH = headerH,
        indicatorWidth = indicatorWidth,
        indicatorHeight = indicatorHeight,
        panelRadius = panelRadius,
        outlineWidth = outlineWidth,
        totalHeight = totalHeight,
        panelLeft = panelLeft,
        panelTop = panelTop,
        panelCenterX = panelCenterX,
        panelCenterY = panelCenterY,
        rowLeft = rowLeft,
        rowWidth = rowWidth,
        rowStartY = rowStartY,
        rows = rows
    }
end

local hoverPadX = 6
local hoverPadY = 12

local function buildTooltipLines(entry, focusThreshold)
    local lines = {}
    lines[#lines + 1] = {
        label = "cards in deck",
        value = tostring(entry.count or 0),
        labelColor = tooltipStyle.label,
        valueColor = tooltipStyle.value,
        fontSize = 12
    }
    for _, threshold in ipairs(entry.thresholds) do
        local focus = (threshold == focusThreshold)
        local bonus = describeBonus(entry.tag, threshold)
        local status = formatThresholdStatus(entry, threshold)
        local color = focus and colorForTag(entry.tag) or tooltipStyle.text
        lines[#lines + 1] = {
            label = string.format("threshold %d", threshold),
            value = string.format("%s (%s)", bonus, status),
            labelColor = color,
            valueColor = color,
            fontSize = focus and 13 or 12
        }
    end
    return lines
end

local function buildHoverTarget(entry, focusThreshold)
    local lines = buildTooltipLines(entry, focusThreshold)
    local sigParts = {}
    for _, l in ipairs(lines) do
        sigParts[#sigParts + 1] = (l.label or "") .. ":" .. (l.value or "")
    end
    local signature = table.concat(sigParts, "|")
    return {
        key = entry.tag .. ":" .. (focusThreshold or "row"),
        title = string.format("%s Synergy", entry.tag),
        rows = lines,
        signature = signature,
        entry = entry,
        threshold = focusThreshold
    }
end

local function updateHoverTooltip(target, mouse)
    if not target then
        hideActiveTooltip()
        return
    end

    local tooltip = getOrBuildTooltip(target)
    if not tooltip then
        hideActiveTooltip()
        return
    end

    TagSynergyPanel._activeTooltip = tooltip
    TagSynergyPanel._hoverKey = target.key
    positionTooltip(tooltip, mouse)
end

function TagSynergyPanel.init(opts)
    TagSynergyPanel.breakpoints, TagSynergyPanel.breakpointDetails =
        normalizeBreakpoints(opts and opts.breakpoints or TagSynergyPanel.breakpointDetails)
    TagSynergyPanel.entries = {}
    TagSynergyPanel.displayedCounts = {}
    TagSynergyPanel._pulses = {}
    TagSynergyPanel._hoverKey = nil
    TagSynergyPanel._activeTooltip = nil
    resetTooltipCache()
    TagSynergyPanel._layoutCache = nil
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

--- Show the synergy panel with slide-up animation
function TagSynergyPanel.show()
    if TagSynergyPanel._slideState == "visible" or TagSynergyPanel._slideState == "entering" then
        return
    end
    TagSynergyPanel._slideState = "entering"
end

--- Hide the synergy panel with slide-down animation
function TagSynergyPanel.hide()
    if TagSynergyPanel._slideState == "hidden" or TagSynergyPanel._slideState == "exiting" then
        return
    end
    TagSynergyPanel._slideState = "exiting"
    hideActiveTooltip()
end

--- Toggle the synergy panel visibility
function TagSynergyPanel.toggle()
    if TagSynergyPanel._slideState == "visible" or TagSynergyPanel._slideState == "entering" then
        TagSynergyPanel.hide()
    else
        TagSynergyPanel.show()
    end
end

--- Check if the panel is currently visible (or animating in)
function TagSynergyPanel.isVisible()
    return TagSynergyPanel._slideState == "visible" or TagSynergyPanel._slideState == "entering"
end

--- Get the current panel bounds for hit-testing (includes slide offset)
function TagSynergyPanel.getPanelBounds()
    local cache = TagSynergyPanel._layoutCache
    if not cache then return nil end
    local slideOffset = TagSynergyPanel._currentSlideOffset or 0
    return {
        x = cache.panelLeft,
        y = cache.panelTop + slideOffset,
        w = cache.panelW,
        h = cache.totalHeight
    }
end

--- Check if a point is inside the panel
function TagSynergyPanel.containsPoint(px, py)
    local bounds = TagSynergyPanel.getPanelBounds()
    if not bounds then return false end
    return px >= bounds.x and px <= bounds.x + bounds.w
       and py >= bounds.y and py <= bounds.y + bounds.h
end

--- Handle click-outside to dismiss
function TagSynergyPanel.handleClickOutside(mx, my)
    if TagSynergyPanel._slideState ~= "visible" then return end
    if not TagSynergyPanel.containsPoint(mx, my) then
        TagSynergyPanel.hide()
    end
end

--- Set the toggle button bounds for click-outside exclusion
function TagSynergyPanel.setToggleButtonBounds(bounds)
    TagSynergyPanel._toggleButtonBounds = bounds
end

function TagSynergyPanel.setData(tagCounts, breakpoints)
    if breakpoints then
        TagSynergyPanel.breakpoints, TagSynergyPanel.breakpointDetails = normalizeBreakpoints(breakpoints)
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
    resetTooltipCache()
    TagSynergyPanel._layoutCache = nil
end

function TagSynergyPanel.update(dt)
    if not TagSynergyPanel.isActive then
        clearHover()
        TagSynergyPanel._layoutCache = nil
        return
    end
    if not dt then dt = GetFrameTime() end

    -- Update slide animation state machine
    local state = TagSynergyPanel._slideState
    local progress = TagSynergyPanel._slideProgress
    local speed = TagSynergyPanel._slideSpeed

    if state == "entering" then
        progress = math.min(1, progress + dt * speed)
        TagSynergyPanel._slideProgress = progress
        if progress >= 1 then
            TagSynergyPanel._slideState = "visible"
            TagSynergyPanel._slideProgress = 1
        end
    elseif state == "exiting" then
        progress = math.max(0, progress - dt * speed)
        TagSynergyPanel._slideProgress = progress
        if progress <= 0 then
            TagSynergyPanel._slideState = "hidden"
            TagSynergyPanel._slideProgress = 0
            clearHover()
        end
    end

    -- Skip further updates if fully hidden
    if TagSynergyPanel._slideState == "hidden" then
        clearHover()
        TagSynergyPanel._layoutCache = nil
        return
    end

    TagSynergyPanel._pulses = TagSynergyPanel._pulses or {}
    TagSynergyPanel._layoutCache = computeLayoutCache()

    -- Check for click-outside-to-dismiss when fully visible
    if TagSynergyPanel._slideState == "visible" and input and input.action_down then
        local clickedOutside = input.action_down("mouse_click")
        if clickedOutside then
            local mouse = getMousePosition()
            if mouse then
                -- Check if click is inside synergy toggle button (don't dismiss if clicking the button)
                local buttonBounds = TagSynergyPanel._toggleButtonBounds
                local insideButton = buttonBounds and
                    mouse.x >= buttonBounds.x and mouse.x <= buttonBounds.x + buttonBounds.w and
                    mouse.y >= buttonBounds.y and mouse.y <= buttonBounds.y + buttonBounds.h

                if not insideButton and not TagSynergyPanel.containsPoint(mouse.x, mouse.y) then
                    TagSynergyPanel.hide()
                end
            end
        end
    end

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
        local fontSize = 13
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
    if not TagSynergyPanel.isActive then
        clearHover()
        return
    end
    if not globals or not layers or not command_buffer then
        clearHover()
        return
    end

    -- Skip drawing if fully hidden
    if TagSynergyPanel._slideState == "hidden" then
        clearHover()
        return
    end

    TagSynergyPanel._layoutCache = computeLayoutCache()
    local layoutCache = TagSynergyPanel._layoutCache
    local screenW = layoutCache.screenW
    local screenH = layoutCache.screenH
    local font = localization.getFont()
    local totalRows = layoutCache.totalRows

    -- Calculate slide offset (panel slides up from bottom)
    local slideProgress = TagSynergyPanel._slideProgress
    local easedProgress
    if TagSynergyPanel._slideState == "entering" then
        easedProgress = Easing.outQuad.f(slideProgress)
    elseif TagSynergyPanel._slideState == "exiting" then
        easedProgress = Easing.outQuad.f(slideProgress)
    else
        easedProgress = 1
    end
    local slideOffset = (1 - easedProgress) * (layoutCache.totalHeight + 40)

    -- If nothing to show, render a small hint and exit.
    if totalRows == 0 then
        local hint = "Add tagged cards to start a synergy"
        local fontSize = 15
        local w = localization.getTextWidthWithCurrentFont(hint, fontSize, 1)
        local x = screenW - w - math.max(14, layoutCache.marginX or 0)
        local y = math.max(24, layoutCache.marginTop - 56) + slideOffset
        command_buffer.queueDrawText(layers.ui, function(c)
            c.text = hint
            c.font = font
            c.x = x
            c.y = y
            c.color = colors.muted
            c.fontSize = fontSize
        end, (z_orders.ui_tooltips or 0) + 3, layer.DrawCommandSpace.Screen)
        clearHover()
        return
    end

    local space = layer.DrawCommandSpace.Screen
    local baseZ = 100  -- Lower z so other UI can draw above

    -- Apply slide offset to panel position
    local panelCenterY = layoutCache.panelCenterY + slideOffset
    local panelTop = layoutCache.panelTop + slideOffset

    command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
        c.x = layoutCache.panelCenterX
        c.y = panelCenterY
        c.w = layoutCache.panelW + layoutCache.outlineWidth * 2
        c.h = layoutCache.totalHeight + layoutCache.outlineWidth * 2
        c.rx = layoutCache.panelRadius + layoutCache.outlineWidth
        c.ry = layoutCache.panelRadius + layoutCache.outlineWidth
        c.color = colors.outline
    end, baseZ - 1, space)

    command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
        c.x = layoutCache.panelCenterX
        c.y = panelCenterY
        c.w = layoutCache.panelW
        c.h = layoutCache.totalHeight
        c.rx = layoutCache.panelRadius
        c.ry = layoutCache.panelRadius
        c.color = colors.panel
    end, baseZ, space)

    command_buffer.queueDrawText(layers.ui, function(c)
        c.text = localization and localization.get and localization.get("ui.tag_synergies_title") or "Tag Synergies"
        c.font = font
        c.x = layoutCache.panelLeft + layoutCache.paddingX
        c.y = panelTop + layoutCache.paddingY - 2
        c.color = colors.header
        c.fontSize = 22
    end, baseZ + 2, space)

    -- Store slideOffset for use in row rendering
    TagSynergyPanel._currentSlideOffset = slideOffset

    for _, row in ipairs(layoutCache.rows or {}) do
        local entry = row.entry
        local rowCenterY = row.centerY + slideOffset
        local rowTop = row.top + slideOffset
        local accent = colorForTag(entry.tag)
        local pulse = TagSynergyPanel._pulses[entry.tag] or 0
        local nameSize = 20 * (1 + pulse * 0.08)
        local subtitleSize = 14

        command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
            c.x = row.rowLeft + row.rowWidth * 0.5
            c.y = rowCenterY
            c.w = row.rowWidth
            c.h = row.rowHeight
            c.rx = 12
            c.ry = 12
            c.color = colors.row
        end, baseZ + 1, space)

        -- Title
        command_buffer.queueDrawText(layers.ui, function(c)
            c.text = entry.tag
            c.font = font
            c.x = row.rowLeft + 12
            c.y = rowCenterY - 16
            c.color = accent
            c.fontSize = nameSize
        end, baseZ + 2, space)

        for _, seg in ipairs(row.segments or {}) do
            local fill = entry.count / seg.threshold
            local segTop = seg.top + slideOffset
            drawSegment(seg.left, segTop, seg.width, seg.height, fill, accent, entry.tag, seg.threshold, baseZ + 2, space, font)
        end
    end

    -- Don't register hover regions while animating
    if TagSynergyPanel._slideState ~= "visible" then
        return
    end

    -- Register hover regions with HoverRegistry
    for _, row in ipairs(layoutCache.rows or {}) do
        -- Register row region (lower z)
        HoverRegistry.region({
            id = "synergy_" .. row.entry.tag,
            x = row.rowLeft,
            y = row.top + slideOffset,
            w = row.rowWidth,
            h = row.rowHeight,
            z = 100,
            onHover = function()
                local target = buildHoverTarget(row.entry)
                local mouse = getMousePosition()
                if mouse then
                    updateHoverTooltip(target, mouse)
                end
            end,
            onUnhover = function()
                hideActiveTooltip()
            end,
        })

        -- Register segment regions (higher z)
        for _, seg in ipairs(row.segments or {}) do
            HoverRegistry.region({
                id = "synergy_" .. row.entry.tag .. "_" .. seg.threshold,
                x = seg.left - hoverPadX,
                y = seg.top + slideOffset - hoverPadY,
                w = seg.width + hoverPadX * 2,
                h = seg.height + hoverPadY * 2,
                z = 101,
                onHover = function()
                    local target = buildHoverTarget(row.entry, seg.threshold)
                    local mouse = getMousePosition()
                    if mouse then
                        updateHoverTooltip(target, mouse)
                    end
                end,
                onUnhover = function()
                    hideActiveTooltip()
                end,
            })
        end
    end
end

return TagSynergyPanel
