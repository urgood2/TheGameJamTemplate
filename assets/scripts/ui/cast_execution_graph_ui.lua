--[[
================================================================================
CAST EXECUTION GRAPH UI
================================================================================
Visualizes wand cast blocks as nested horizontal rows:
- Each cast block becomes a row.
- Applied modifiers render as red `M` pills.
- Actions render as labeled boxes.
- Nested blocks sit inline after the triggering action.
]]--

local CastExecutionGraphUI = {}

local dsl = require("ui.ui_syntax_sugar")
local component_cache = require("core.component_cache")
local z_ok, z_orders = pcall(require, "core.z_orders")
if not z_ok then z_orders = { ui_tooltips = 0 } end

-- Lazy-load toggle state to avoid circular dependencies
local function isVisible()
    local ok, toggles = pcall(require, "ui.ui_overlay_toggles")
    if ok and toggles and toggles.isCastExecutionGraphVisible then
        return toggles.isCastExecutionGraphVisible()
    end
    return true -- Default to visible if toggles module not available
end
local STYLING_ROUNDED = UIStylingType and UIStylingType.RoundedRectangle or nil

local function defaultPosition()
    local h = nil
    if globals then
        if globals.screenHeight then h = globals.screenHeight() end
        if not h and globals.getScreenHeight then h = globals.getScreenHeight() end
    end
    local y = h and (h - 200) or 540
    return { x = 32, y = y }
end

local DEFAULT_POS = defaultPosition()
local MAX_DEPTH = 6

CastExecutionGraphUI.position = { x = DEFAULT_POS.x, y = DEFAULT_POS.y }
CastExecutionGraphUI.currentBox = nil
CastExecutionGraphUI._lastFingerprint = nil
CastExecutionGraphUI._activeTooltip = nil
CastExecutionGraphUI._activeTooltipOwner = nil
CastExecutionGraphUI._fallbackTooltipActive = false
CastExecutionGraphUI._fallbackTooltipKey = nil

-- Pending hover handlers to apply after spawn (workaround for initFunc not being called)
local pendingTooltips = {}
local tooltipCounter = 0

local function resolveColor(name, fallback)
    local ok, c = pcall(util.getColor, name)
    if ok and c then return c end
    if fallback then
        local ok2, c2 = pcall(util.getColor, fallback)
        if ok2 and c2 then return c2 end
    end
    return util.getColor("white")
end

local colors = {
    backdrop = resolveColor("apricot_cream", "light_gray"),
    row = resolveColor("pale_mint", "white"),
    nested = resolveColor("baby_blue", "light_gray"),
    mod = resolveColor("red"),
    modText = resolveColor("white"),
    action = resolveColor("apricot", "white"),
    text = resolveColor("black"),
    outline = resolveColor("black"),
}

local function cleanLabel(str)
    str = tostring(str or "?")
    str = str:gsub("\n", " / ")
    return str
end
local function tooltipCardId(card)
    if not card then return nil end
    return card.cardID or card.card_id or card.id
end

local function showCardTooltip(card, anchorEntity, fallbackLabel, fallbackBody)
    if not card then return nil end
    local cardId = tooltipCardId(card)
    if not cardId then return nil end

    -- Try to get or create the tooltip using ensureCardTooltip (creates if not cached)
    local tooltip = nil
    if ensureCardTooltip then
        tooltip = ensureCardTooltip(card)
    elseif card_tooltip_cache then
        tooltip = card_tooltip_cache[cardId]
    end
    if not tooltip then return nil end

    if centerTooltipAboveEntity then
        centerTooltipAboveEntity(tooltip, anchorEntity, 12)
    end

    if ui and ui.box and ui.box.ClearStateTagsFromUIBox then
        for _, tooltipEntity in pairs(card_tooltip_cache) do
            if tooltipEntity ~= tooltip then
                ui.box.ClearStateTagsFromUIBox(tooltipEntity)
            end
        end
    end

    -- Add state tags so the tooltip is visible in the current game state
    if ui and ui.box and ui.box.AddStateTagToUIBox then
        ui.box.ClearStateTagsFromUIBox(tooltip)
        if PLANNING_STATE then ui.box.AddStateTagToUIBox(tooltip, PLANNING_STATE) end
        if ACTION_STATE then ui.box.AddStateTagToUIBox(tooltip, ACTION_STATE) end
        if SHOP_STATE then ui.box.AddStateTagToUIBox(tooltip, SHOP_STATE) end
        if CARD_TOOLTIP_STATE then ui.box.AddStateTagToUIBox(tooltip, CARD_TOOLTIP_STATE) end
    end
    if add_state_tag and CARD_TOOLTIP_STATE then add_state_tag(tooltip, CARD_TOOLTIP_STATE) end
    if activate_state and CARD_TOOLTIP_STATE then activate_state(CARD_TOOLTIP_STATE) end

    previously_hovered_tooltip = tooltip
    CastExecutionGraphUI._activeTooltip = tooltip
    CastExecutionGraphUI._activeTooltipOwner = anchorEntity

    return tooltip
end

local function hideActiveTooltip(sourceEntity)
    if sourceEntity and CastExecutionGraphUI._activeTooltipOwner
        and CastExecutionGraphUI._activeTooltipOwner ~= sourceEntity then
        return
    end

    local tooltip = CastExecutionGraphUI._activeTooltip
    if tooltip then
        if clear_state_tags then clear_state_tags(tooltip) end
        if ui and ui.box and ui.box.ClearStateTagsFromUIBox then
            ui.box.ClearStateTagsFromUIBox(tooltip)
        end
        if previously_hovered_tooltip == tooltip then
            previously_hovered_tooltip = nil
        end
    end

    if CastExecutionGraphUI._fallbackTooltipActive and CastExecutionGraphUI._fallbackTooltipKey then
        if hideSimpleTooltip then
            hideSimpleTooltip(CastExecutionGraphUI._fallbackTooltipKey)
        end
    end

    CastExecutionGraphUI._activeTooltip = nil
    CastExecutionGraphUI._activeTooltipOwner = nil
    CastExecutionGraphUI._fallbackTooltipActive = false
    CastExecutionGraphUI._fallbackTooltipKey = nil
end

local function attachTooltip(config, tooltipData)
    if not tooltipData then return config end

    local card = tooltipData.card
    local label = tooltipData.label
    local body = tooltipData.body or ""

    config.hover = true
    config.canCollide = true
    config.collideable = true

    -- Generate a unique tooltip ID and store data for post-spawn application
    tooltipCounter = tooltipCounter + 1
    local tooltipId = "cast_graph_tooltip_" .. tooltipCounter
    config.id = tooltipId  -- Mark this config with an ID we can find later

    pendingTooltips[tooltipId] = {
        card = card,
        label = label,
        body = body
    }

    log_debug("[ExecGraph] attachTooltip: id=" .. tooltipId .. ", label=" .. tostring(label))

    return config
end

-- Apply hover handlers to an entity based on stored tooltip data
local function applyHoverToEntity(entity, tooltipData)
    if not entity or not registry:valid(entity) then return end

    local go = component_cache.get(entity, GameObject)
    if not go then return end

    local card = tooltipData.card
    local label = tooltipData.label
    local body = tooltipData.body

    go.state.hoverEnabled = true
    go.state.collisionEnabled = true
    go.state.triggerOnReleaseEnabled = true
    go.state.clickEnabled = true

    go.methods.onHover = function()
        log_debug("[ExecGraph] onHover triggered for entity=" .. tostring(entity) .. ", label=" .. tostring(label))
        local shown = showCardTooltip(card, entity, label, body)
        if not shown and label then
            local tooltipKey = "cast_graph_" .. tostring(entity)
            log_debug("[ExecGraph] Card tooltip not shown, falling back to simple tooltip key=" .. tooltipKey)
            if showSimpleTooltipAbove then
                showSimpleTooltipAbove(tooltipKey, cleanLabel(label), cleanLabel(body), entity)
                CastExecutionGraphUI._activeTooltipOwner = entity
                CastExecutionGraphUI._fallbackTooltipKey = tooltipKey
                CastExecutionGraphUI._fallbackTooltipActive = true
            end
        elseif shown then
            log_debug("[ExecGraph] Card tooltip shown successfully")
            CastExecutionGraphUI._activeTooltipOwner = entity
        end
    end

    go.methods.onStopHover = function()
        log_debug("[ExecGraph] onStopHover for entity=" .. tostring(entity))
        hideActiveTooltip(entity)
    end
end

-- Recursively apply pending hover handlers to all entities in the UI tree
local function applyPendingHovers(entity, depth)
    depth = depth or 0
    if not entity or not registry:valid(entity) then return end

    -- Check if this entity has a UIElementCore with a tooltip ID
    local uiCore = component_cache.get(entity, UIElementCore)
    local foundId = uiCore and uiCore.id or "(no UIElementCore or no id)"
    if uiCore and uiCore.id and uiCore.id ~= "" then
        local tooltipData = pendingTooltips[uiCore.id]
        if tooltipData then
            log_debug("[ExecGraph] applyPendingHovers: MATCH found id=" .. uiCore.id)
            applyHoverToEntity(entity, tooltipData)
            -- Log dimensions to check if hover will work
            local t = component_cache.get(entity, Transform)
            if t then
                log_debug("[ExecGraph] Entity " .. tostring(entity) .. " dims: actualW=" .. tostring(t.actualW) .. ", actualH=" .. tostring(t.actualH))
            end
        else
            log_debug("[ExecGraph] applyPendingHovers: id=" .. uiCore.id .. " not in pendingTooltips")
        end
    end

    -- Traverse children (orderedChildren is a vector, children is a map)
    local go = component_cache.get(entity, GameObject)
    if go and go.orderedChildren then
        for _, child in ipairs(go.orderedChildren) do
            applyPendingHovers(child, depth + 1)
        end
    end
end

-- Snap visual dimensions to prevent tween-from-zero animation
local function snapVisualToActual(entity)
    if not entity or not registry:valid(entity) then return end

    local t = component_cache.get(entity, Transform)
    if t then
        t.visualW = t.actualW or t.visualW
        t.visualH = t.actualH or t.visualH
    end

    local go = component_cache.get(entity, GameObject)
    if go and go.orderedChildren then
        for _, child in ipairs(go.orderedChildren) do
            snapVisualToActual(child)
        end
    end
end

local function abbreviateLabel(label)
    if not label or label == "" then return "?" end
    label = cleanLabel(label)
    if #label <= 6 then return label end

    local words = {}
    for token in label:gmatch("%w+") do
        table.insert(words, token)
    end

    local abbrev = ""
    if #words > 1 then
        for _, w in ipairs(words) do
            abbrev = abbrev .. string.sub(w, 1, 1):upper()
            if #abbrev >= 4 then break end
        end
    end

    if #abbrev < 3 then
        local compact = label:gsub("[%s%p]+", "")
        abbrev = string.sub(compact, 1, 6)
    end

    return abbrev
end

local function destroyBox()
    if not CastExecutionGraphUI.currentBox then return end

    local box = CastExecutionGraphUI.currentBox
    local hasRegistry = registry and registry.valid
    local boxValid = hasRegistry and registry:valid(box)

    
    if boxValid then
        registry:destroy(box)
    end

    hideActiveTooltip()

    CastExecutionGraphUI.currentBox = nil
end

local function cardLabel(card)
    if not card then return "?" end
    if card.test_label and card.test_label ~= "" then
        return cleanLabel(card.test_label)
    end
    return cleanLabel(card.card_id or card.cardID or card.id or "?")
end

-- Default icon placeholders
local DEFAULT_ACTION_ICON = "b3888.png"
local DEFAULT_MODIFIER_ICON = "b3770.png"
local ICON_SIZE = 24

local function pill(text, opts)
    opts = opts or {}
    local outline = opts.outline
    if outline == nil then outline = 1 end
    local label = tostring(text or "")

    local config = {
        color = opts.bg or colors.row,
        padding = opts.padding or 6,
        outlineThickness = outline,
        outlineColor = opts.outlineColor or colors.outline,
        stylingType = STYLING_ROUNDED,
        align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
        minWidth = opts.minWidth,
        minHeight = opts.minHeight or 28,
        shadow = opts.shadow,
        initFunc = opts.initFunc,
    }

    config = attachTooltip(config, opts.tooltip)

    return dsl.hbox{
        config = config,
        children = {
            dsl.text(label, { color = opts.textColor or colors.text, fontSize = opts.fontSize or 13 })
        }
    }
end

-- Icon-based pill for actions and modifiers
local function iconPill(iconId, opts)
    opts = opts or {}
    local outline = opts.outline
    if outline == nil then outline = 1 end

    local config = {
        color = opts.bg or colors.row,
        padding = opts.padding or 6,
        outlineThickness = outline,
        outlineColor = opts.outlineColor or colors.outline,
        stylingType = STYLING_ROUNDED,
        align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
        minWidth = opts.minWidth or (ICON_SIZE + 12),
        minHeight = opts.minHeight or (ICON_SIZE + 12),
        shadow = opts.shadow,
    }

    config = attachTooltip(config, opts.tooltip)

    return dsl.hbox{
        config = config,
        children = {
            dsl.anim(iconId, { w = ICON_SIZE, h = ICON_SIZE, shadow = false })
        }
    }
end

local function modBox(modInfo)
    local card = modInfo and modInfo.card
    local label = cardLabel(card)
    local icon = (card and card.smallIcon) or DEFAULT_MODIFIER_ICON
    return iconPill(icon, {
        bg = colors.mod,
        padding = 6,
        shadow = true,
        tooltip = { card = card, label = label, body = localization.get("ui.modifier_label") },
    })
end

local function actionBox(card)
    local fullLabel = cardLabel(card)
    local icon = (card and card.smallIcon) or DEFAULT_ACTION_ICON
    return iconPill(icon, {
        bg = colors.action,
        padding = 6,
        tooltip = { card = card, label = fullLabel, body = localization.get("ui.action_label") },
    })
end

local function wrapNested(row)
    return dsl.hbox{
        config = {
            color = colors.nested,
            padding = 6,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
            outlineThickness = 1,
            outlineColor = colors.outline,
        },
        children = { row }
    }
end

local function fingerprintBlock(block, depth)
    depth = depth or 1
    if not block or depth > MAX_DEPTH then return "x" end

    local childMap = {}
    for _, child in ipairs(block.children or {}) do
        if child.trigger then
            childMap[child.trigger] = child
        end
    end

    local parts = {}

    for _, modInfo in ipairs(block.applied_modifiers or {}) do
        table.insert(parts, "M:" .. cardLabel(modInfo.card))
    end

    for _, action in ipairs(block.cards or {}) do
        local part = "A:" .. cardLabel(action)
        local child = childMap[action]
        if child then
            part = part .. "->(" .. fingerprintBlock(child.block, depth + 1) .. ")"
        end
        table.insert(parts, part)
    end

    return table.concat(parts, "|")
end

local function fingerprint(blocks)
    if not blocks or #blocks == 0 then return nil end
    local parts = {}
    for i, block in ipairs(blocks) do
        parts[i] = fingerprintBlock(block, 1)
    end
    return table.concat(parts, "||")
end

local function buildBlockRow(block, depth, label)
    depth = depth or 1
    if not block then
        return pill("(no block)", { bg = colors.row })
    end

    if depth > MAX_DEPTH then
        return pill("...depth limit...", { bg = colors.row })
    end

    local childMap = {}
    for _, child in ipairs(block.children or {}) do
        if child.trigger then
            childMap[child.trigger] = child
        end
    end

    local rowChildren = {}

    if label then
        table.insert(rowChildren, pill(label, {
            bg = colors.backdrop,
            textColor = colors.text,
            fontSize = 12,
            padding = 6,
        }))
    end

    for _, modInfo in ipairs(block.applied_modifiers or {}) do
        table.insert(rowChildren, modBox(modInfo))
    end

    local cards = block.cards or {}
    for idx, actionCard in ipairs(cards) do
        table.insert(rowChildren, actionBox(actionCard))

        local child = childMap[actionCard]
        if child and child.block then
            table.insert(rowChildren, wrapNested(buildBlockRow(child.block, depth + 1, "Sub")))
        end
    end

    if #rowChildren == 0 then
        table.insert(rowChildren, pill("(empty block)", { bg = colors.row, fontSize = 12 }))
    end

    local bg = depth == 1 and colors.row or colors.nested

    return dsl.hbox{
        config = {
            color = bg,
            padding = 8,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
            outlineThickness = 1,
            outlineColor = colors.outline,
            shadow = true,
        },
        children = rowChildren
    }
end

local function buildRoot(blocks, opts)
    local rows = {}
    for i, block in ipairs(blocks or {}) do
        local blockLabel = localization and localization.get and localization.get("ui.block_number", { num = i }) or string.format("Block %d", i)
        table.insert(rows, buildBlockRow(block, 1, blockLabel))
    end

    local defaultTitle = localization and localization.get and localization.get("ui.execution_graph_title") or "Execution Graph"
    local wandPrefix = localization and localization.get and localization.get("ui.wand_prefix") or "Wand: "
    local headerText = opts and opts.title or defaultTitle
    local subtitle = opts and opts.wandId and (wandPrefix .. tostring(opts.wandId)) or nil

    local headerChildren = { dsl.text(headerText, { fontSize = 16, color = colors.text }) }
    if subtitle then
        table.insert(headerChildren, dsl.text(subtitle, { fontSize = 12, color = colors.text }))
    end

    local headerRow = dsl.vbox{
        config = {
            color = colors.backdrop,
            padding = 8,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
        },
        children = headerChildren
    }

    local column = dsl.vbox{
        config = {
            color = colors.backdrop,
            padding = 10,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
        },
        children = rows
    }

    return dsl.root{
        config = {
            color = colors.backdrop,
            padding = 12,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
            outlineThickness = 2,
            outlineColor = colors.outline,
            shadow = true,
        },
        children = { headerRow, column }
    }
end

function CastExecutionGraphUI.setPosition(pos)
    if not pos then return end
    CastExecutionGraphUI.position = { x = pos.x or DEFAULT_POS.x, y = pos.y or DEFAULT_POS.y }
    if CastExecutionGraphUI.currentBox and component_cache and component_cache.get then
        local t = component_cache.get(CastExecutionGraphUI.currentBox, Transform)
        if t then
            t.actualX = CastExecutionGraphUI.position.x
            t.actualY = CastExecutionGraphUI.position.y
        end
    end
end

function CastExecutionGraphUI.clear()
    CastExecutionGraphUI._lastFingerprint = nil
    pendingTooltips = {}
    tooltipCounter = 0
    destroyBox()
end

local function planningActive()
    return PLANNING_STATE and is_state_active and is_state_active(PLANNING_STATE)
end

function CastExecutionGraphUI.render(blocks, opts)
    if not ui or not ui.box or not registry then return nil end
    if not planningActive() then
        CastExecutionGraphUI.clear()
        return nil
    end
    if not isVisible() then
        CastExecutionGraphUI.clear()
        return nil
    end
    if not blocks or #blocks == 0 then
        CastExecutionGraphUI.clear()
        return nil
    end

    local fp = fingerprint(blocks)
    if fp and fp == CastExecutionGraphUI._lastFingerprint then
        return CastExecutionGraphUI.currentBox
    end
    CastExecutionGraphUI._lastFingerprint = fp

    destroyBox()

    -- Clear pending tooltips before building new UI
    pendingTooltips = {}
    tooltipCounter = 0

    local root = buildRoot(blocks, opts or {})

    CastExecutionGraphUI.currentBox = dsl.spawn(CastExecutionGraphUI.position, root, "ui",
        (z_orders.ui_tooltips or 0) + 5)

    -- Apply hover handlers after spawn (workaround for initFunc not being called via makeConfigFromTable)
    local pendingCount = 0
    for _ in pairs(pendingTooltips) do pendingCount = pendingCount + 1 end
    log_debug("[ExecGraph] render: pendingTooltips count=" .. pendingCount)

    if CastExecutionGraphUI.currentBox and registry:valid(CastExecutionGraphUI.currentBox) then
        local uiBoxComp = component_cache.get(CastExecutionGraphUI.currentBox, UIBoxComponent)
        if uiBoxComp and uiBoxComp.uiRoot then
            log_debug("[ExecGraph] render: calling applyPendingHovers on uiRoot=" .. tostring(uiBoxComp.uiRoot))
            applyPendingHovers(uiBoxComp.uiRoot)
        else
            log_debug("[ExecGraph] render: No uiBoxComp or uiRoot!")
        end
    end

    if ui.box.set_draw_layer then
        ui.box.set_draw_layer(CastExecutionGraphUI.currentBox, "ui")
    end

    if ui.box.ClearStateTagsFromUIBox then
        ui.box.ClearStateTagsFromUIBox(CastExecutionGraphUI.currentBox)
    end

    if ui.box.AssignStateTagsToUIBox then
        if PLANNING_STATE then ui.box.AssignStateTagsToUIBox(CastExecutionGraphUI.currentBox, PLANNING_STATE) end
    end

    if layer_order_system and layer_order_system.assignZIndexToEntity then
        layer_order_system.assignZIndexToEntity(CastExecutionGraphUI.currentBox,
            (z_orders.ui_tooltips or 0) + 5)
    end

    if ui.box.RenewAlignment then
        ui.box.RenewAlignment(registry, CastExecutionGraphUI.currentBox)
    end

    -- Snap visual dimensions to prevent tween-from-zero animation
    local uiBoxComp = registry:get(CastExecutionGraphUI.currentBox, UIBoxComponent)
    if uiBoxComp and uiBoxComp.uiRoot then
        snapVisualToActual(uiBoxComp.uiRoot)
        snapVisualToActual(CastExecutionGraphUI.currentBox)
    end

    return CastExecutionGraphUI.currentBox
end

return CastExecutionGraphUI
