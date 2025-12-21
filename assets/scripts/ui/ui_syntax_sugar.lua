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
                    dsl.hbox {
                        children = {
                            dsl.anim("sprite_id", { w = 40, h = 40 }),
                            dsl.text("Subtitle", { fontSize = 16 })
                        }
                    }
                }
            }
        }
    }

    local boxID = dsl.spawn({ x = 200, y = 200 }, myUI)

CONTAINERS:
    dsl.root { config, children }    -- Root container (required at top)
    dsl.vbox { config, children }    -- Vertical layout
    dsl.hbox { config, children }    -- Horizontal layout

ELEMENTS:
    dsl.text(text, opts)             -- Text element
        opts: { fontSize, color, align, onClick, hover }

    dsl.anim(id, opts)               -- Animated sprite
        opts: { w, h, shadow, isAnimation }

    dsl.dynamicText(fn, fontSize, effect, opts)  -- Auto-updating text
        fn: function returning string

HOVER/TOOLTIP:
    dsl.text("Button", {
        hover = { title = "Button Title", body = "Description" },
        onClick = function() print("clicked") end
    })

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
-- Return DSL module
------------------------------------------------------------
return dsl
