------------------------------------------------------------
-- ui_dsl.lua
-- Declarative DSL for creating UI trees with readable syntax.
-- Depends on: ui.definitions.def, ui.box, layer_order_system,
-- animation_system, timer, util, registry, etc.
------------------------------------------------------------
local bit = require("bit") -- LuaJIT's bit library

local dsl = {}

-- Local aliases
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
            local t = registry:get(entry.config.object, Transform)
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

    local generateNewAnimFromSprite   = not opts.isAnimation or true
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
    local go = registry:get(eid, GameObject)
    if not go then return end

    go.state.hoverEnabled = true
    go.state.collisionEnabled = true

    go.methods.onHover = function(_, hoveredOn, hovered)
        showTooltip(localization.get(hover.title), localization.get(hover.body))
    end

    go.methods.onStopHover = function()
        hideTooltip()
    end
end

------------------------------------------------------------
-- Recursively attach hover handlers to entities
-- Uses std::vector<entt::entity> orderedChildren
------------------------------------------------------------
function dsl.applyHoverRecursive(entity)
    local go = registry:get(entity, GameObject)
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
    ui.box.AssignLayerOrderComponents(registry, box)

    if layerName then
        layer_order_system.assignZIndexToEntity(box, zIndex or 0)
    end

    if opts and opts.onBoxResize then
        local boxComp = registry:get(box, UIBoxComponent)
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
