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
local z_ok, z_orders = pcall(require, "core.z_orders")
if not z_ok then z_orders = { ui_tooltips = 0 } end
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

    CastExecutionGraphUI.currentBox = nil
end

local function cardLabel(card)
    if not card then return "?" end
    if card.test_label and card.test_label ~= "" then
        return cleanLabel(card.test_label)
    end
    return cleanLabel(card.card_id or card.cardID or card.id or "?")
end

local function pill(text, opts)
    opts = opts or {}
    local outline = opts.outline
    if outline == nil then outline = 1 end
    local label = tostring(text or "")

    return dsl.hbox{
        config = {
            color = opts.bg or colors.row,
            padding = opts.padding or 4,
            outlineThickness = outline,
            outlineColor = opts.outlineColor or colors.outline,
            stylingType = STYLING_ROUNDED,
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
            minWidth = opts.minWidth,
            minHeight = opts.minHeight or 20,
            shadow = opts.shadow,
        },
        children = {
            dsl.text(label, { color = opts.textColor or colors.text, fontSize = opts.fontSize or 13 })
        }
    }
end

local function modBox(modInfo)
    return pill("M", {
        bg = colors.mod,
        textColor = colors.modText,
        fontSize = 12,
        padding = 4,
        minWidth = 22,
        minHeight = 20,
        shadow = true,
    })
end

local function actionBox(card)
    local label = abbreviateLabel(cardLabel(card))
    return pill(label, {
        bg = colors.action,
        textColor = colors.outline,
        fontSize = 12,
        padding = 4,
    })
end

local function wrapNested(row)
    return dsl.hbox{
        config = {
            color = colors.nested,
            padding = 3,
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
            padding = 3,
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
            padding = 4,
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
        table.insert(rows, buildBlockRow(block, 1, string.format("Block %d", i)))
    end

    local headerText = opts and opts.title or "Execution Graph"
    local subtitle = opts and opts.wandId and ("Wand: " .. tostring(opts.wandId)) or nil

    local headerChildren = { dsl.text(headerText, { fontSize = 16, color = colors.text }) }
    if subtitle then
        table.insert(headerChildren, dsl.text(subtitle, { fontSize = 12, color = colors.text }))
    end

    local headerRow = dsl.vbox{
        config = {
            color = colors.backdrop,
            padding = 4,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
        },
        children = headerChildren
    }

    local column = dsl.vbox{
        config = {
            color = colors.backdrop,
            padding = 6,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
        },
        children = rows
    }

    return dsl.root{
        config = {
            color = colors.backdrop,
            padding = 6,
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

    local root = buildRoot(blocks, opts or {})

    CastExecutionGraphUI.currentBox = dsl.spawn(CastExecutionGraphUI.position, root, "ui",
        (z_orders.ui_tooltips or 0) + 5)

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

    return CastExecutionGraphUI.currentBox
end

return CastExecutionGraphUI
