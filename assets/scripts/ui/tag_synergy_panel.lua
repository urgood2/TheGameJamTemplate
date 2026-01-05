--[[
Tag Synergy Panel - Icon Grid Layout
Displays deck tag progress as a compact 3×4 icon grid with tier dots and animations.
]]

local TagSynergyPanel = {}

local z_orders = require("core.z_orders")
local component_cache = require("core.component_cache")
local dsl = require("ui.ui_syntax_sugar")
local HoverRegistry = require("ui.hover_registry")
local SynergyIcons = require("data.synergy_icons")
local timer = require("core.timer")
local Easing = require("util.easing")

local DEFAULT_THRESHOLDS = { 3, 5, 7, 9 }
local GRID_COLS = 3
local GRID_ROWS = 4
local CELL_SIZE = 48
local ICON_SIZE = 32
local DOT_RADIUS = 3
local DOT_SPACING = 8
local BADGE_RADIUS = 10
local PANEL_PADDING = 12
local CELL_SPACING = 4

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
    panel = Col(12, 14, 20, 230),
    outline = safeColor("apricot_cream", "white"),
    dotEmpty = Col(60, 65, 80, 200),
    dotFilled = Col(255, 255, 255, 255),
    badgeBg = Col(30, 32, 42, 240),
    badgeText = Col(255, 255, 255, 255),
    inactive = Col(80, 85, 100, 180),
    glowBase = Col(255, 255, 255, 60),
}

local tooltipStyle = {
    bg = Col(16, 18, 26, 245),
    inner = Col(24, 26, 36, 240),
    outline = safeColor("apricot_cream", "white"),
    title = safeColor("apricot", "white"),
    text = safeColor("white"),
    muted = safeColor("gray", "light_gray"),
    active = safeColor("mint_green", "green"),
    fontName = "tooltip",
    padding = 10,
    outlineThickness = 2,
    fontSize = 14,
    titleFontSize = 18,
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
TagSynergyPanel._thresholdAnimations = {}
TagSynergyPanel._hoverTag = nil
TagSynergyPanel._hoverScale = {}
TagSynergyPanel._activeTooltip = nil
TagSynergyPanel._tooltips = {}
TagSynergyPanel._layoutCache = nil
TagSynergyPanel.isActive = false
TagSynergyPanel.layout = {
    marginX = 22,
    marginTop = 120,
}

TagSynergyPanel._slideState = "hidden"
TagSynergyPanel._slideProgress = 0
TagSynergyPanel._slideSpeed = 4.0

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

local function countThresholdsReached(count, thresholds)
    local reached = 0
    for _, t in ipairs(thresholds) do
        if count >= t then
            reached = reached + 1
        end
    end
    return reached
end

local function getNextThreshold(count, thresholds)
    for _, t in ipairs(thresholds) do
        if count < t then
            return t
        end
    end
    return nil
end

local function makeGrayscaleColor(c)
    local gray = math.floor(0.299 * c.r + 0.587 * c.g + 0.114 * c.b)
    gray = math.floor(gray * 0.5)
    return Col(gray, gray, gray, 180)
end

local function computeGridLayout()
    local screenW, screenH = resolveScreenSize()
    local gridOrder = SynergyIcons.getGridOrder()
    
    local panelW = GRID_COLS * CELL_SIZE + (GRID_COLS - 1) * CELL_SPACING + PANEL_PADDING * 2
    local panelH = GRID_ROWS * CELL_SIZE + (GRID_ROWS - 1) * CELL_SPACING + PANEL_PADDING * 2
    
    local buttonBounds = TagSynergyPanel._toggleButtonBounds
    local marginTop = TagSynergyPanel.layout.marginTop
    if buttonBounds then
        local buttonBottom = (buttonBounds.y or 0) + (buttonBounds.h or 40) + 12
        marginTop = math.max(marginTop, buttonBottom)
    end
    
    local panelLeft = screenW - panelW - TagSynergyPanel.layout.marginX
    local panelTop = marginTop
    
    local cells = {}
    for i, tag in ipairs(gridOrder) do
        if tag then
            local col = ((i - 1) % GRID_COLS)
            local row = math.floor((i - 1) / GRID_COLS)
            
            local cellX = panelLeft + PANEL_PADDING + col * (CELL_SIZE + CELL_SPACING)
            local cellY = panelTop + PANEL_PADDING + row * (CELL_SIZE + CELL_SPACING)
            
            cells[tag] = {
                tag = tag,
                index = i,
                col = col,
                row = row,
                x = cellX,
                y = cellY,
                centerX = cellX + CELL_SIZE / 2,
                centerY = cellY + CELL_SIZE / 2,
            }
        end
    end
    
    return {
        screenW = screenW,
        screenH = screenH,
        panelW = panelW,
        panelH = panelH,
        panelLeft = panelLeft,
        panelTop = panelTop,
        panelCenterX = panelLeft + panelW / 2,
        panelCenterY = panelTop + panelH / 2,
        cells = cells,
        gridOrder = gridOrder,
    }
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

local function buildTooltipDef(tag, count, thresholds, accent)
    local reached = countThresholdsReached(count, thresholds)
    local nextThreshold = getNextThreshold(count, thresholds)
    
    local children = {}
    
    children[#children + 1] = dsl.text(tag .. " Synergy", {
        color = accent,
        fontSize = tooltipStyle.titleFontSize,
        fontName = tooltipStyle.fontName,
        align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER)
    })
    
    children[#children + 1] = dsl.text("Cards in deck: " .. tostring(count), {
        color = tooltipStyle.muted,
        fontSize = tooltipStyle.fontSize,
        fontName = tooltipStyle.fontName,
        align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER)
    })
    
    for i, threshold in ipairs(thresholds) do
        local isActive = count >= threshold
        local indicator = isActive and "●" or "○"
        local bonus = describeBonus(tag, threshold)
        local tierText = string.format("%s Tier %d (%d+): %s", indicator, i, threshold, bonus)
        
        children[#children + 1] = dsl.text(tierText, {
            color = isActive and tooltipStyle.active or tooltipStyle.muted,
            fontSize = tooltipStyle.fontSize,
            fontName = tooltipStyle.fontName,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER)
        })
    end
    
    if nextThreshold then
        local needed = nextThreshold - count
        local hintText = string.format("%d more card%s for Tier %d", needed, needed == 1 and "" or "s", countThresholdsReached(count, thresholds) + 1)
        children[#children + 1] = dsl.text(hintText, {
            color = accent,
            fontSize = tooltipStyle.fontSize,
            fontName = tooltipStyle.fontName,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER)
        })
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
                    padding = 8,
                    align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
                },
                children = children
            }
        }
    }
end

local function getOrBuildTooltip(tag, count, thresholds)
    local key = tag
    local signature = tag .. ":" .. tostring(count)
    local cached = TagSynergyPanel._tooltips[key]
    
    if cached and cached.signature == signature and cached.entity then
        return cached.entity
    end
    
    destroyTooltip(key)
    
    local accent = colorForTag(tag)
    local def = buildTooltipDef(tag, count, thresholds, accent)
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
    
    TagSynergyPanel._tooltips[key] = {
        entity = entity,
        signature = signature
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
    TagSynergyPanel._hoverTag = nil
end

local function clearHover()
    hideActiveTooltip()
    HoverRegistry.clear()
end

local function spawnThresholdParticles(x, y, color)
    if not particle then return end
    
    local particleCount = 6 + math.random(3)
    for i = 1, particleCount do
        local angle = (i / particleCount) * math.pi * 2 + math.random() * 0.5
        local speed = 80 + math.random() * 40
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed
        
        local opts = {
            renderType = particle.ParticleRenderType and particle.ParticleRenderType.CIRCLE_FILLED or 4,
            velocity = Vec2(vx, vy),
            lifespan = 0.4 + math.random() * 0.2,
            startColor = color,
            endColor = Col(color.r, color.g, color.b, 0),
            gravity = 50,
        }
        
        local size = 3 + math.random() * 2
        particle.CreateParticle(Vec2(x, y), Vec2(size, size), opts)
    end
end

function TagSynergyPanel.init(opts)
    TagSynergyPanel.breakpoints, TagSynergyPanel.breakpointDetails =
        normalizeBreakpoints(opts and opts.breakpoints or TagSynergyPanel.breakpointDetails)
    TagSynergyPanel.entries = {}
    TagSynergyPanel.displayedCounts = {}
    TagSynergyPanel._pulses = {}
    TagSynergyPanel._thresholdAnimations = {}
    TagSynergyPanel._hoverTag = nil
    TagSynergyPanel._hoverScale = {}
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
    }
end

function TagSynergyPanel.show()
    if TagSynergyPanel._slideState == "visible" or TagSynergyPanel._slideState == "entering" then
        return
    end
    TagSynergyPanel._slideState = "entering"
end

function TagSynergyPanel.hide()
    if TagSynergyPanel._slideState == "hidden" or TagSynergyPanel._slideState == "exiting" then
        return
    end
    TagSynergyPanel._slideState = "exiting"
    hideActiveTooltip()
end

function TagSynergyPanel.toggle()
    if TagSynergyPanel._slideState == "visible" or TagSynergyPanel._slideState == "entering" then
        TagSynergyPanel.hide()
    else
        TagSynergyPanel.show()
    end
end

function TagSynergyPanel.isVisible()
    return TagSynergyPanel._slideState == "visible" or TagSynergyPanel._slideState == "entering"
end

function TagSynergyPanel.getPanelBounds()
    local cache = TagSynergyPanel._layoutCache
    if not cache then return nil end
    local slideOffset = TagSynergyPanel._currentSlideOffset or 0
    return {
        x = cache.panelLeft,
        y = cache.panelTop + slideOffset,
        w = cache.panelW,
        h = cache.panelH
    }
end

function TagSynergyPanel.containsPoint(px, py)
    local bounds = TagSynergyPanel.getPanelBounds()
    if not bounds then return false end
    return px >= bounds.x and px <= bounds.x + bounds.w
       and py >= bounds.y and py <= bounds.y + bounds.h
end

function TagSynergyPanel.handleClickOutside(mx, my)
    if TagSynergyPanel._slideState ~= "visible" then return end
    if not TagSynergyPanel.containsPoint(mx, my) then
        TagSynergyPanel.hide()
    end
end

function TagSynergyPanel.setToggleButtonBounds(bounds)
    TagSynergyPanel._toggleButtonBounds = bounds
end

function TagSynergyPanel.setData(tagCounts, breakpoints)
    if breakpoints then
        TagSynergyPanel.breakpoints, TagSynergyPanel.breakpointDetails = normalizeBreakpoints(breakpoints)
    end

    local entriesByTag = {}
    for tag, count in pairs(tagCounts or {}) do
        entriesByTag[tag] = {
            tag = tag,
            count = count,
            thresholds = copyThresholds(thresholdsFor(tag, TagSynergyPanel.breakpoints)),
        }
    end
    
    TagSynergyPanel.entries = entriesByTag
    
    for tag, entry in pairs(entriesByTag) do
        local previous = TagSynergyPanel.displayedCounts[tag]
        local previousReached = previous and countThresholdsReached(previous, entry.thresholds) or 0
        local currentReached = countThresholdsReached(entry.count, entry.thresholds)
        
        if currentReached > previousReached then
            TagSynergyPanel._thresholdAnimations[tag] = {
                scale = 1.0,
                glow = 1.0,
                startTime = 0,
            }
            
            local cache = TagSynergyPanel._layoutCache
            if cache and cache.cells[tag] then
                local cell = cache.cells[tag]
                spawnThresholdParticles(cell.centerX, cell.centerY, colorForTag(tag))
            end
        end
        
        if previous and previous ~= entry.count then
            TagSynergyPanel._pulses[tag] = 1.0
        end
        
        TagSynergyPanel.displayedCounts[tag] = entry.count
    end
    
    for tag, _ in pairs(TagSynergyPanel.displayedCounts) do
        if not entriesByTag[tag] then
            TagSynergyPanel.displayedCounts[tag] = nil
            TagSynergyPanel._pulses[tag] = nil
            TagSynergyPanel._thresholdAnimations[tag] = nil
        end
    end
    
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

    if TagSynergyPanel._slideState == "hidden" then
        clearHover()
        TagSynergyPanel._layoutCache = nil
        return
    end

    TagSynergyPanel._layoutCache = computeGridLayout()

    if TagSynergyPanel._slideState == "visible" and input and input.action_down then
        local clickedOutside = input.action_down("mouse_click")
        if clickedOutside then
            local mouse = getMousePosition()
            if mouse then
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

    for tag, pulse in pairs(TagSynergyPanel._pulses) do
        TagSynergyPanel._pulses[tag] = math.max(0, pulse - dt * 3.0)
    end
    
    for tag, anim in pairs(TagSynergyPanel._thresholdAnimations) do
        anim.startTime = anim.startTime + dt
        
        local t = anim.startTime
        if t < 0.3 then
            local p = t / 0.3
            anim.scale = 1.0 + 0.15 * math.sin(p * math.pi)
        else
            anim.scale = 1.0
        end
        
        anim.glow = math.max(0, 1.0 - anim.startTime * 2.5)
        
        if anim.startTime > 0.5 then
            TagSynergyPanel._thresholdAnimations[tag] = nil
        end
    end
    
    for tag, scale in pairs(TagSynergyPanel._hoverScale) do
        local targetScale = (tag == TagSynergyPanel._hoverTag) and 1.08 or 1.0
        TagSynergyPanel._hoverScale[tag] = scale + (targetScale - scale) * math.min(1, dt * 12)
    end
end

local function drawIcon(cellX, cellY, tag, count, thresholds, scale, glowAlpha, slideOffset, baseZ, space, font)
    local accent = colorForTag(tag)
    local isActive = count > 0
    local iconColor = isActive and accent or makeGrayscaleColor(accent)
    
    local cx = cellX + CELL_SIZE / 2
    local cy = cellY + CELL_SIZE / 2 + slideOffset
    local iconHalfSize = (ICON_SIZE / 2) * scale
    
    if glowAlpha > 0 then
        local glowSize = iconHalfSize * 1.4
        command_buffer.queueDrawCircleFilled(layers.ui, function(c)
            c.x = cx
            c.y = cy
            c.radius = glowSize
            c.color = Col(accent.r, accent.g, accent.b, math.floor(60 * glowAlpha))
        end, baseZ, space)
    end
    
    local iconConfig = SynergyIcons.getConfig(tag)
    local shouldTint = iconConfig and iconConfig.tint ~= false
    local tintColor = shouldTint and iconColor or Col(255, 255, 255, isActive and 255 or 180)
    
    if not isActive then
        tintColor = Col(80, 85, 100, 180)
    end
    
    local iconSize = ICON_SIZE * scale
    local iconLeft = cx - iconSize / 2
    local iconTop = cy - iconSize / 2 - 6
    
    command_buffer.queueDrawSteppedRoundedRect(layers.ui, function(c)
        c.x = cx
        c.y = iconTop + iconSize / 2
        c.w = iconSize
        c.h = iconSize
        c.fillColor = tintColor
        c.borderColor = Col(0, 0, 0, 100)
        c.borderWidth = 1
        c.numSteps = 3
    end, baseZ + 1, space)
    
    local dotsY = cy + ICON_SIZE / 2 - 4
    local dotsTotalWidth = 4 * (DOT_RADIUS * 2) + 3 * (DOT_SPACING - DOT_RADIUS * 2)
    local dotsStartX = cx - dotsTotalWidth / 2
    
    local reachedCount = countThresholdsReached(count, thresholds)
    
    for i = 1, 4 do
        local dotX = dotsStartX + (i - 1) * DOT_SPACING + DOT_RADIUS
        local isFilled = i <= reachedCount
        local dotColor = isFilled and accent or colors.dotEmpty
        
        command_buffer.queueDrawCircleFilled(layers.ui, function(c)
            c.x = dotX
            c.y = dotsY
            c.radius = DOT_RADIUS
            c.color = dotColor
        end, baseZ + 2, space)
    end
    
    if isActive then
        local badgeX = cellX + CELL_SIZE - BADGE_RADIUS - 2
        local badgeY = cellY + slideOffset + BADGE_RADIUS + 2
        
        local pulse = TagSynergyPanel._pulses[tag] or 0
        local badgeScale = 1.0 + pulse * 0.15
        local badgeR = BADGE_RADIUS * badgeScale
        
        command_buffer.queueDrawCircleFilled(layers.ui, function(c)
            c.x = badgeX
            c.y = badgeY
            c.radius = badgeR
            c.color = colors.badgeBg
        end, baseZ + 3, space)
        
        command_buffer.queueDrawCircleFilled(layers.ui, function(c)
            c.x = badgeX
            c.y = badgeY
            c.radius = badgeR - 1
            c.color = Col(accent.r, accent.g, accent.b, 200)
        end, baseZ + 4, space)
        
        local countStr = tostring(count)
        local fontSize = count >= 10 and 10 or 12
        local textW = localization.getTextWidthWithCurrentFont(countStr, fontSize, 1)
        command_buffer.queueDrawText(layers.ui, function(c)
            c.text = countStr
            c.font = font
            c.x = badgeX - textW / 2
            c.y = badgeY - fontSize / 2 - 1
            c.color = colors.badgeText
            c.fontSize = fontSize
        end, baseZ + 5, space)
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

    if TagSynergyPanel._slideState == "hidden" then
        clearHover()
        return
    end

    TagSynergyPanel._layoutCache = computeGridLayout()
    local cache = TagSynergyPanel._layoutCache
    local font = localization.getFont()

    local slideProgress = TagSynergyPanel._slideProgress
    local easedProgress
    if TagSynergyPanel._slideState == "entering" then
        easedProgress = Easing.outQuad.f(slideProgress)
    elseif TagSynergyPanel._slideState == "exiting" then
        easedProgress = Easing.outQuad.f(slideProgress)
    else
        easedProgress = 1
    end
    local slideOffset = (1 - easedProgress) * (cache.panelH + 40)
    TagSynergyPanel._currentSlideOffset = slideOffset

    local space = layer.DrawCommandSpace.Screen
    local baseZ = 100

    local panelCenterY = cache.panelCenterY + slideOffset

    command_buffer.queueDrawSteppedRoundedRect(layers.ui, function(c)
        c.x = cache.panelCenterX
        c.y = panelCenterY
        c.w = cache.panelW
        c.h = cache.panelH
        c.fillColor = colors.panel
        c.borderColor = colors.outline
        c.borderWidth = 2
        c.numSteps = 4
    end, baseZ, space)

    local gridOrder = cache.gridOrder
    for _, tag in ipairs(gridOrder) do
        if tag and cache.cells[tag] then
            local cell = cache.cells[tag]
            local entry = TagSynergyPanel.entries[tag]
            local count = entry and entry.count or 0
            local thresholds = entry and entry.thresholds or DEFAULT_THRESHOLDS
            
            local hoverScale = TagSynergyPanel._hoverScale[tag] or 1.0
            local anim = TagSynergyPanel._thresholdAnimations[tag]
            local animScale = anim and anim.scale or 1.0
            local glowAlpha = anim and anim.glow or 0
            
            local finalScale = hoverScale * animScale
            
            if tag == TagSynergyPanel._hoverTag then
                glowAlpha = math.max(glowAlpha, 0.3)
            end
            
            drawIcon(cell.x, cell.y, tag, count, thresholds, finalScale, glowAlpha, slideOffset, baseZ + 10, space, font)
        end
    end

    if TagSynergyPanel._slideState ~= "visible" then
        return
    end

    for _, tag in ipairs(gridOrder) do
        if tag and cache.cells[tag] then
            local cell = cache.cells[tag]
            local entry = TagSynergyPanel.entries[tag]
            local count = entry and entry.count or 0
            local thresholds = entry and entry.thresholds or DEFAULT_THRESHOLDS
            
            HoverRegistry.region({
                id = "synergy_grid_" .. tag,
                x = cell.x,
                y = cell.y + slideOffset,
                w = CELL_SIZE,
                h = CELL_SIZE,
                z = 101,
                onHover = function()
                    TagSynergyPanel._hoverTag = tag
                    TagSynergyPanel._hoverScale[tag] = TagSynergyPanel._hoverScale[tag] or 1.0
                    
                    local tooltip = getOrBuildTooltip(tag, count, thresholds)
                    local mouse = getMousePosition()
                    if mouse and tooltip then
                        TagSynergyPanel._activeTooltip = tooltip
                        positionTooltip(tooltip, mouse)
                    end
                end,
                onUnhover = function()
                    if TagSynergyPanel._hoverTag == tag then
                        TagSynergyPanel._hoverTag = nil
                        hideActiveTooltip()
                    end
                end,
            })
        end
    end
end

return TagSynergyPanel
