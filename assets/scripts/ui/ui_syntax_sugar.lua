--[[
================================================================================
UI DSL (ui_syntax_sugar) - Declarative UI Tree Builder
================================================================================
Build UI hierarchies with readable, declarative syntax.

BASIC USAGE:
    local dsl = require("ui.ui_syntax_sugar")

    local myUI = dsl.root {
        config = { color = "blackberry", padding = 10 },
        children = {
            dsl.vbox {
                config = { spacing = 6 },
                children = {
                    dsl.text("Title", { fontSize = 24, color = "white" }),
                    dsl.button("Click Me", { onClick = fn, color = "blue" }),
                    dsl.progressBar({ getValue = fn, fullColor = "green" }),
                }
            }
        }
    }

    local boxID = dsl.spawn({ x = 200, y = 200 }, myUI)

CONTAINERS:
    dsl.root { config, children }    -- Root container (required at top)
    dsl.vbox { config, children }    -- Vertical layout
    dsl.hbox { config, children }    -- Horizontal layout
    dsl.section(title, opts)         -- Titled section with content area

ELEMENTS:
    dsl.text(text, opts)             -- Static text
        opts: { fontSize, color, align, onClick, hover }

    dsl.richText(text, opts)         -- Styled text with markup
        Example: "[Health](color=red): 100"

    dsl.dynamicText(fn, fontSize, effect, opts)  -- Auto-updating text

    dsl.anim(id, opts)               -- Animated sprite
        opts: { w, h, shadow, isAnimation }

INTERACTIVE:
    dsl.button(label, opts)          -- Clickable button
        opts: { onClick, color, hover, disabled, minWidth, minHeight }

    dsl.progressBar(opts)            -- Animated progress bar
        opts: { getValue, emptyColor, fullColor, minWidth, minHeight }

LAYOUT HELPERS:
    dsl.spacer(w, h?)                -- Empty spacing element
    dsl.divider(direction, opts)     -- Horizontal/vertical line
    dsl.iconLabel(icon, text, opts)  -- Icon + text pattern
    dsl.grid(rows, cols, genFn)      -- Uniform grid layout

DATA-DRIVEN:
    dsl.list(data, mapperFn)         -- Generate nodes from array
    dsl.when(condition, node)        -- Conditional rendering

SPAWNING:
    dsl.spawn(pos, defNode, layerName?, zIndex?, opts?)
        pos: { x = number, y = number }
        Returns: boxID (entity)

Dependencies: ui.definitions, ui.box, layer_order_system, animation_system
]]
------------------------------------------------------------
-- local bit = require("bit") -- LuaJIT's bit library

local dsl = {}

-- Local aliases
local component_cache = require("core.component_cache")
local def    = ui.definitions.def
local wrap   = ui.definitions.wrapEntityInsideObjectElement
local getDyn = ui.definitions.getNewDynamicTextEntry

------------------------------------------------------------
-- Utility: Color resolver
------------------------------------------------------------
local function color(c)
    return type(c) == "string" and util.getColor(c) or c
end

------------------------------------------------------------
-- 1️⃣ Base container constructors
------------------------------------------------------------
function dsl.hbox(tbl)
    tbl.type = "HORIZONTAL_CONTAINER"
    return def(tbl)
end

function dsl.vbox(tbl)
    tbl.type = "VERTICAL_CONTAINER"
    return def(tbl)
end

function dsl.root(tbl)
    tbl.type = "ROOT"
    return def(tbl)
end

------------------------------------------------------------
-- 2️⃣ Text Element
------------------------------------------------------------
function dsl.text(text, opts)
    opts = opts or {}
    return def{
        type = "TEXT",
        config = {
            id              = opts.id,
            text            = text,
            color           = color(opts.color or "blackberry"),
            align           = opts.align or (bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER)),
            buttonCallback  = opts.onClick,
            tooltip         = opts.tooltip,
            hover           = opts.hover,
            fontSize        = opts.fontSize,
            fontName        = opts.fontName,
            shadow          = opts.shadow,
        }
    }
end

------------------------------------------------------------
-- 3️⃣ Dynamic Text
-- Re-aligns automatically when width changes (optional)
------------------------------------------------------------
function dsl.dynamicText(fn, fontSize, effect, opts)
    opts = opts or {}
    local entry = getDyn(fn, fontSize or 30.0, effect or "")

    if opts.id    then entry.config.id    = opts.id end
    if opts.color then entry.config.color = color(opts.color) end

    -- Optional: auto alignment refresh
    if opts.autoAlign then
        local prevW = -1
        timer.every(opts.alignRate or 0.5, function()
            if not entry.config or not entry.config.object then return end
            local t = component_cache.get(entry.config.object, Transform)
            if math.abs(t.actualW - prevW) > 1 then
                ui.box.RenewAlignment(registry, entry.config.object)
                prevW = t.actualW
            end
        end)
    end

    return entry
end

------------------------------------------------------------
-- 4️⃣ Animated Sprite / Entity Wrapper
------------------------------------------------------------
------------------------------------------------------------
-- 4️⃣ Animated Sprite / Entity Wrapper (Final)
-- Usage:
--   dsl.anim("sprite.png",  { sprite = true,  w = 40, h = 40, shadow = false })
--   dsl.anim("walk_anim",   { sprite = false, w = 64, h = 64 })
------------------------------------------------------------
function dsl.anim(id, opts)
    opts = opts or {}

    -- When isAnimation=true, treat `id` as an existing animation id; otherwise treat it as a sprite id.
    local generateNewAnimFromSprite = not opts.isAnimation
    local width      = opts.w or 40
    local height     = opts.h or 40
    local enableShadow = (opts.shadow ~= false)  -- default true unless explicitly false

    -- Pass shadow flag explicitly
    local ent = animation_system.createAnimatedObjectWithTransform(
        id,
        generateNewAnimFromSprite,
        0, 0,
        nil,
        enableShadow
    )

    animation_system.resizeAnimationObjectsInEntityToFit(ent, width, height)

    return wrap(ent)
end

------------------------------------------------------------
-- 5️⃣ Declarative Hover Support
------------------------------------------------------------
-- hover = { title = "Shop", body = "Opens the store" }
------------------------------------------------------------
local function attachHover(eid, hover)
    local go = component_cache.get(eid, GameObject)
    if not go then return end

    go.state.hoverEnabled = true
    go.state.collisionEnabled = true

    go.methods.onHover = function(_, hoveredOn, hovered)
        local tooltipKey = "dsl_hover_" .. tostring(eid)
        if showSimpleTooltipAbove then
            showSimpleTooltipAbove(
                tooltipKey,
                localization.get(hover.title),
                localization.get(hover.body),
                eid
            )
        end
        -- Store key for cleanup
        go._tooltipKey = tooltipKey
    end

    go.methods.onStopHover = function()
        if hideSimpleTooltip and go._tooltipKey then
            hideSimpleTooltip(go._tooltipKey)
        end
    end
end

------------------------------------------------------------
-- Recursively attach hover handlers to entities
-- Uses std::vector<entt::entity> orderedChildren
------------------------------------------------------------
function dsl.applyHoverRecursive(entity)
    local go = component_cache.get(entity, GameObject)
    if not go then return end

    if go.config and go.config.hover then
        attachHover(entity, go.config.hover)
    end

    if go.orderedChildren then
        for _, child in ipairs(go.orderedChildren) do
            dsl.applyHoverRecursive(child)
        end
    end
end

------------------------------------------------------------
-- 6️⃣ Spawn a UIBox with optional layer & resize callback
------------------------------------------------------------
function dsl.spawn(pos, defNode, layerName, zIndex, opts)
    log_debug("DSL: Spawning UIBox at ("..pos.x..","..pos.y..")")
    local box = ui.box.Initialize(pos, defNode)

    -- Assign the UIBox zIndex *before* propagating to children/owned objects,
    -- otherwise collisions can be sorted using stale LayerOrderComponent values.
    if layerName and layer_order_system and layer_order_system.assignZIndexToEntity then
        layer_order_system.assignZIndexToEntity(box, zIndex or 0)
    end

    if ui and ui.box and ui.box.AssignLayerOrderComponents then
        ui.box.AssignLayerOrderComponents(registry, box)
    end

    if opts and opts.onBoxResize then
        local boxComp = component_cache.get(box, UIBoxComponent)
        if boxComp then
            boxComp.onBoxResize = opts.onBoxResize
        end
    end

    return box
end

------------------------------------------------------------
-- 7️⃣ Grid Builder
-- Generates a uniform grid of horizontal rows.
------------------------------------------------------------
-- Example:
-- local grid = dsl.grid(3, 4, function(r, c)
--     return dsl.anim("icon_"..(r*c), { w = 48, h = 48 })
-- end)
------------------------------------------------------------
function dsl.grid(rows, cols, gen)
    local grid = {}
    for r = 1, rows do
        local row = {
            type     = "HORIZONTAL_CONTAINER",
            config   = { align = AlignmentFlag.HORIZONTAL_CENTER },
            children = {}
        }

        for c = 1, cols do
            table.insert(row.children, gen(r, c))
        end

        table.insert(grid, def(row))
    end
    return grid
end

------------------------------------------------------------
-- 8️⃣ Button Element
-- Composable button with hover, click, and optional tooltip.
------------------------------------------------------------
-- Example:
-- dsl.button("Click Me", {
--     onClick = function() print("clicked!") end,
--     color = "red",
--     hover = { title = "Button", body = "Click to confirm" },
--     disabled = false,
--     minWidth = 100,
--     minHeight = 40
-- })
------------------------------------------------------------
function dsl.button(label, opts)
    opts = opts or {}

    local textNode = dsl.text(label, {
        fontSize = opts.fontSize or 16,
        color = opts.textColor or "white",
        shadow = opts.shadow ~= false
    })

    return def{
        type = "HORIZONTAL_CONTAINER",
        config = {
            id             = opts.id,
            color          = color(opts.color or "gray"),
            hover          = true,
            buttonCallback = opts.onClick,
            tooltip        = opts.tooltip,
            hover          = opts.hover,
            emboss         = opts.emboss or 2,
            minWidth       = opts.minWidth,
            minHeight      = opts.minHeight,
            disableButton  = opts.disabled,
            align          = opts.align or (bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER)),
        },
        children = { textNode }
    }
end

------------------------------------------------------------
-- 9️⃣ Progress Bar Element
-- Animated progress bar with value callback.
------------------------------------------------------------
-- Example:
-- dsl.progressBar({
--     getValue = function() return playerHealth / maxHealth end,
--     emptyColor = "gray",
--     fullColor = "green",
--     minWidth = 200,
--     minHeight = 20
-- })
------------------------------------------------------------
function dsl.progressBar(opts)
    opts = opts or {}

    return def{
        type = "HORIZONTAL_CONTAINER",
        config = {
            id                    = opts.id,
            color                 = color(opts.color or "gray"),
            minWidth              = opts.minWidth or 200,
            minHeight             = opts.minHeight or 20,
            progressBar           = true,
            progressBarMaxValue   = opts.maxValue or 1.0,
            progressBarEmptyColor = color(opts.emptyColor or "darkgray"),
            progressBarFullColor  = color(opts.fullColor or "green"),
            progressBarFetchValueLambda = opts.getValue,
            align                 = opts.align or (bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER)),
        },
        children = opts.children or {}
    }
end

------------------------------------------------------------
-- 🔟 Spacer Element
-- Empty element for layout spacing.
------------------------------------------------------------
-- Example:
-- dsl.spacer(20)  -- 20px vertical spacer
-- dsl.spacer(20, 40)  -- 20w x 40h spacer
------------------------------------------------------------
function dsl.spacer(w, h)
    return def{
        type = "RECT_SHAPE",
        config = {
            color    = { 0, 0, 0, 0 }, -- transparent
            minWidth = w or 10,
            minHeight = h or w or 10,
        }
    }
end

------------------------------------------------------------
-- 1️⃣1️⃣ Divider Element
-- Horizontal or vertical divider line.
------------------------------------------------------------
-- Example:
-- dsl.divider("horizontal", { color = "white", thickness = 2 })
------------------------------------------------------------
function dsl.divider(direction, opts)
    opts = opts or {}
    local thickness = opts.thickness or 1

    if direction == "vertical" then
        return def{
            type = "RECT_SHAPE",
            config = {
                color     = color(opts.color or "white"),
                minWidth  = thickness,
                minHeight = opts.length or 20,
            }
        }
    else
        return def{
            type = "RECT_SHAPE",
            config = {
                color     = color(opts.color or "white"),
                minWidth  = opts.length or 100,
                minHeight = thickness,
            }
        }
    end
end

------------------------------------------------------------
-- 1️⃣2️⃣ Icon with Label
-- Common pattern: icon + text side by side.
------------------------------------------------------------
-- Example:
-- dsl.iconLabel("coin.png", "100 Gold", { iconSize = 24, fontSize = 16 })
------------------------------------------------------------
function dsl.iconLabel(iconId, label, opts)
    opts = opts or {}
    local iconSize = opts.iconSize or 24

    return def{
        type = "HORIZONTAL_CONTAINER",
        config = {
            id      = opts.id,
            padding = opts.padding or 2,
            align   = opts.align or (bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER)),
        },
        children = {
            dsl.anim(iconId, { w = iconSize, h = iconSize, shadow = opts.shadow }),
            dsl.text(label, { fontSize = opts.fontSize or 16, color = opts.textColor or "white" })
        }
    }
end

------------------------------------------------------------
-- 1️⃣3️⃣ Rich Text (styled text with markup)
-- Uses C++ getTextFromString for parsing.
------------------------------------------------------------
-- Example:
-- dsl.richText("[Health](color=red): 100", { fontSize = 16 })
------------------------------------------------------------
function dsl.richText(text, opts)
    opts = opts or {}
    local defaults = {
        fontSize = opts.fontSize,
        fontName = opts.fontName,
        color    = opts.color,
        shadow   = opts.shadow
    }
    return ui.definitions.getTextFromString(text, defaults)
end

------------------------------------------------------------
-- 1️⃣4️⃣ Titled Section
-- Container with a title bar and content area.
------------------------------------------------------------
-- Example:
-- dsl.section("Inventory", {
--     color = "darkgray",
--     children = { ... }
-- })
------------------------------------------------------------
function dsl.section(title, opts)
    opts = opts or {}

    local titleNode = dsl.text(title, {
        fontSize = opts.titleSize or 18,
        color = opts.titleColor or "white",
        shadow = true
    })

    local titleBar = def{
        type = "HORIZONTAL_CONTAINER",
        config = {
            color   = color(opts.titleBg or "black"),
            padding = opts.titlePadding or 4,
            align   = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
        },
        children = { titleNode }
    }

    local contentBox = def{
        type = "VERTICAL_CONTAINER",
        config = {
            color   = color(opts.color or "gray"),
            padding = opts.padding or 6,
        },
        children = opts.children or {}
    }

    return def{
        type = "VERTICAL_CONTAINER",
        config = {
            id      = opts.id,
            padding = 0,
            emboss  = opts.emboss or 2,
        },
        children = { titleBar, contentBox }
    }
end

------------------------------------------------------------
-- 1️⃣5️⃣ Conditional Rendering
-- Only include children if condition is true.
------------------------------------------------------------
-- Example:
-- dsl.when(showDebug, dsl.text("Debug: ON"))
------------------------------------------------------------
function dsl.when(condition, node)
    if condition then
        return node
    else
        return nil  -- Will be filtered out
    end
end

------------------------------------------------------------
-- 1️⃣6️⃣ List from Data
-- Generate UI nodes from a data array.
------------------------------------------------------------
-- Example:
-- dsl.list(inventory, function(item, i)
--     return dsl.iconLabel(item.icon, item.name)
-- end)
------------------------------------------------------------
function dsl.list(data, mapper)
    local nodes = {}
    for i, item in ipairs(data) do
        local node = mapper(item, i)
        if node then
            table.insert(nodes, node)
        end
    end
    return nodes
end

------------------------------------------------------------
-- Return DSL module
------------------------------------------------------------
return dsl
