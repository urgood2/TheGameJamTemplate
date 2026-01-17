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

SPAWNING & DESTRUCTION:
    dsl.spawn(pos, defNode, layerName?, zIndex?, opts?)
        pos: { x = number, y = number }
        Returns: boxID (entity)

    dsl.remove(boxEntity)
        Properly destroys a UI box with cleanup of all registries
        (tabs, grids, decorations, backgrounds, tooltips).
        Returns: boolean success

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

-- Cache a transparent color at module load time (used by dsl.spacer)
-- NOTE: We keep a fallback path to "blank" to avoid handler defaults (white fills)
local TRANSPARENT_COLOR = Color and Color.new and Color.new(0, 0, 0, 0) or nil

local function resolveSpacerColor()
    if TRANSPARENT_COLOR and type(TRANSPARENT_COLOR) == "userdata" then
        return TRANSPARENT_COLOR
    end

    if util and util.getColor then
        local ok, colorValue = pcall(util.getColor, "blank")
        if ok and type(colorValue) == "userdata" then
            TRANSPARENT_COLOR = colorValue
            return TRANSPARENT_COLOR
        end
    end

    return "blank"
end

------------------------------------------------------------
-- 1️⃣ Base container constructors
------------------------------------------------------------

---@class HBoxConfig
---@field children? table[] Array of child UI nodes
---@field config? table Container configuration options
---@field spacing? number Gap between children in pixels (default: 0)
---@field padding? number Inner padding in pixels (default: 0)
---@field align? number AlignmentFlag bitmask for child alignment (default: HORIZONTAL_CENTER | VERTICAL_CENTER)
---@field color? string|Color Background color name or Color object
---@field id? string Unique identifier for lookups

--- Create a horizontal container that arranges children in a row.
--- Children are laid out left-to-right with centered alignment by default.
---
--- **Example:**
--- ```lua
--- dsl.hbox {
---     config = { spacing = 10, padding = 5 },
---     children = {
---         dsl.text("Left"),
---         dsl.text("Right"),
---     }
--- }
--- ```
---@param tbl HBoxConfig Container configuration
---@return table UIDefinition node for the horizontal container
function dsl.hbox(tbl)
    tbl.type = "HORIZONTAL_CONTAINER"
    -- Default to centered alignment so padding is applied to children
    tbl.config = tbl.config or {}
    if not tbl.config.align then
        tbl.config.align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER)
    end
    return def(tbl)
end

---@class VBoxConfig
---@field children? table[] Array of child UI nodes
---@field config? table Container configuration options
---@field spacing? number Gap between children in pixels (default: 0)
---@field padding? number Inner padding in pixels (default: 0)
---@field align? number AlignmentFlag bitmask for child alignment (default: HORIZONTAL_CENTER | VERTICAL_CENTER)
---@field color? string|Color Background color name or Color object
---@field id? string Unique identifier for lookups

--- Create a vertical container that arranges children in a column.
--- Children are laid out top-to-bottom with centered alignment by default.
---
--- **Example:**
--- ```lua
--- dsl.vbox {
---     config = { spacing = 6 },
---     children = {
---         dsl.text("Title", { fontSize = 24 }),
---         dsl.text("Subtitle"),
---     }
--- }
--- ```
---@param tbl VBoxConfig Container configuration
---@return table UIDefinition node for the vertical container
function dsl.vbox(tbl)
    tbl.type = "VERTICAL_CONTAINER"
    -- Default to centered alignment so padding is applied to children
    tbl.config = tbl.config or {}
    if not tbl.config.align then
        tbl.config.align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER)
    end
    return def(tbl)
end

---@class RootConfig
---@field children? table[] Array of child UI nodes (required for meaningful UI)
---@field config? table Root container configuration
---@field color? string|Color Background color name or Color object
---@field padding? number Inner padding in pixels (default: 0)
---@field align? number AlignmentFlag bitmask for content alignment (default: HORIZONTAL_CENTER | VERTICAL_CENTER)
---@field id? string Unique identifier for lookups

--- Create a root container for a UI hierarchy.
--- This must be the top-level node passed to `dsl.spawn()`.
--- Children are centered by default.
---
--- **Example:**
--- ```lua
--- local myUI = dsl.root {
---     config = { color = "blackberry", padding = 10 },
---     children = {
---         dsl.vbox { ... }
---     }
--- }
--- dsl.spawn({ x = 100, y = 100 }, myUI)
--- ```
---@param tbl RootConfig Root container configuration
---@return table UIDefinition node for the root container
function dsl.root(tbl)
    tbl.type = "ROOT"
    -- Default to centered alignment so padding is applied to children
    tbl.config = tbl.config or {}
    if not tbl.config.align then
        tbl.config.align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER)
    end
    return def(tbl)
end

------------------------------------------------------------
-- 2️⃣ Text Element
------------------------------------------------------------

---@class TextHover
---@field title string Tooltip title text (supports localization keys)
---@field body string Tooltip body text (supports localization keys)

---@class TextOpts
---@field fontSize? number Font size in pixels (default: system default)
---@field fontName? string Font asset name (default: system font)
---@field color? string|Color Text color name or Color object (default: "blackberry")
---@field shadow? boolean Enable text shadow (default: false)
---@field align? number AlignmentFlag bitmask (default: centered)
---@field onClick? function Callback when text is clicked
---@field hover? TextHover Tooltip configuration table
---@field tooltip? table Additional tooltip data
---@field id? string Unique identifier for lookups

--- Create a static text element.
---
--- **Example:**
--- ```lua
--- -- Simple text
--- dsl.text("Hello World")
---
--- -- Styled text
--- dsl.text("Warning!", { fontSize = 20, color = "red", shadow = true })
---
--- -- Clickable text with tooltip
--- dsl.text("Help", {
---     onClick = function() showHelp() end,
---     hover = { title = "Help", body = "Click for more info" }
--- })
--- ```
---@param text string The text content to display
---@param opts? TextOpts Optional styling and interaction options
---@return table UIDefinition node for the text element
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

---@class DynamicTextOpts
---@field id? string Unique identifier for lookups
---@field color? string|Color Text color name or Color object
---@field autoAlign? boolean Enable automatic realignment when width changes (default: false)
---@field alignRate? number Realignment check interval in seconds (default: 0.5)

--- Create a text element that updates its content dynamically.
--- The text is fetched from a callback function each frame.
---
--- **Example:**
--- ```lua
--- -- Simple dynamic text
--- dsl.dynamicText(function() return "HP: " .. player.health end, 20)
---
--- -- With text effect
--- dsl.dynamicText(
---     function() return tostring(score) end,
---     30,
---     "bounce",
---     { color = "gold" }
--- )
---
--- -- Auto-realigning (for changing text widths)
--- dsl.dynamicText(
---     function() return formatTime(elapsed) end,
---     16,
---     "",
---     { autoAlign = true, alignRate = 0.2 }
--- )
--- ```
---@param fn function Callback that returns the text string to display
---@param fontSize? number Font size in pixels (default: 30)
---@param effect? string Text effect name (default: "")
---@param opts? DynamicTextOpts Optional configuration
---@return table UIDefinition node for the dynamic text element
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

---@class AnimOpts
---@field w? number Width in pixels (default: 40)
---@field h? number Height in pixels (default: 40)
---@field shadow? boolean Enable drop shadow (default: true)
---@field isAnimation? boolean If true, `id` is an existing animation ID; if false/nil, `id` is a sprite to create animation from (default: false)

--- Create an animated sprite or static image element.
---
--- When `isAnimation` is false (default), the `id` is treated as a sprite name
--- and a new animation is created from it. When true, `id` references an
--- existing animation in the animation system.
---
--- **Example:**
--- ```lua
--- -- Static sprite image
--- dsl.anim("coin.png", { w = 32, h = 32 })
---
--- -- Animated sprite (from sprite sheet)
--- dsl.anim("walk_cycle", { w = 64, h = 64, isAnimation = true })
---
--- -- No shadow
--- dsl.anim("icon.png", { w = 24, h = 24, shadow = false })
--- ```
---@param id string Sprite filename or animation ID
---@param opts? AnimOpts Optional display configuration
---@return table UIDefinition node wrapping the animated entity
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

    -- Generate unique tooltip name for this entity
    local tooltipName = "dsl_hover_" .. tostring(eid)

    -- Try to use tooltip_registry if available
    local tooltip_registry_ok, tooltip_registry = pcall(require, "core.tooltip_registry")

    if tooltip_registry_ok and tooltip_registry then
        -- Register and attach via registry
        tooltip_registry.register(tooltipName, {
            title = localization.get(hover.title),
            body = localization.get(hover.body)
        })
        tooltip_registry.attachToEntity(eid, tooltipName, {})
    else
        -- Fallback to old behavior
        go.methods.onHover = function(_, hoveredOn, hovered)
            if showSimpleTooltipAbove then
                showSimpleTooltipAbove(
                    tooltipName,
                    localization.get(hover.title),
                    localization.get(hover.body),
                    eid
                )
            end
            go._tooltipKey = tooltipName
        end

        go.methods.onStopHover = function()
            if hideSimpleTooltip and go._tooltipKey then
                hideSimpleTooltip(go._tooltipKey)
            end
        end
    end
end

------------------------------------------------------------
-- Recursively attach hover handlers to entities
-- Uses std::vector<entt::entity> orderedChildren
------------------------------------------------------------

--- Recursively attach hover handlers to an entity and all its children.
--- Processes the UI tree and sets up tooltip callbacks for any elements
--- that have `hover` configuration defined.
---
--- **Note:** This is typically called internally after spawning a UI tree.
--- You only need to call it manually if you're dynamically adding hover
--- configuration to existing entities.
---
--- **Example:**
--- ```lua
--- -- Apply hover handlers to existing UI tree
--- local box = dsl.spawn({ x = 100, y = 100 }, myUI)
--- dsl.applyHoverRecursive(box)
---
--- -- Usually not needed - spawn handles this automatically
--- ```
---@param entity entity The root entity to process
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

---@class SpawnPosition
---@field x number X coordinate in pixels
---@field y number Y coordinate in pixels

---@class SpawnOpts
---@field onBoxResize? function Callback when box resizes: `function(entity, newWidth, newHeight)`

--- Instantiate a UI definition into the world as an entity.
--- This is the final step after building a UI tree with DSL functions.
---
--- **Example:**
--- ```lua
--- -- Basic spawn
--- local myUI = dsl.root { children = { dsl.text("Hello") } }
--- local boxEntity = dsl.spawn({ x = 100, y = 50 }, myUI)
---
--- -- Spawn with layer and z-index
--- local hud = dsl.spawn({ x = 0, y = 0 }, hudUI, "ui", z_orders.ui_tooltips)
---
--- -- Spawn with resize callback
--- local panel = dsl.spawn(
---     { x = 200, y = 200 },
---     panelUI,
---     "ui",
---     100,
---     { onBoxResize = function(entity, w, h)
---         print("Panel resized to " .. w .. "x" .. h)
---     end }
--- )
--- ```
---@param pos SpawnPosition World position { x, y }
---@param defNode table UI definition tree (from dsl.root or similar)
---@param layerName? string Layer name for rendering
---@param zIndex? number Z-order index (default: 0)
---@param opts? SpawnOpts Additional spawn options
---@return entity UIBox entity ID
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
-- 6b. Remove a UIBox with proper cleanup
-- Cleans all registries (tabs, grids, decorations, etc.)
-- then destroys the UI tree via ui.box.Remove.
------------------------------------------------------------
-- Example:
-- local boxID = dsl.spawn({ x = 100, y = 100 }, myUI)
-- -- later...
-- dsl.remove(boxID)
------------------------------------------------------------
function dsl.remove(boxEntity)
    -- Lazy-load UICleanup to avoid circular dependency
    local UICleanup = require("ui.ui_cleanup")
    return UICleanup.remove(boxEntity)
end

------------------------------------------------------------
-- 7️⃣ Grid Builder
-- Generates a uniform grid of horizontal rows.
------------------------------------------------------------

--- Generate a uniform grid of UI elements.
--- Creates rows × cols cells, calling a generator function for each cell.
---
--- **Example:**
--- ```lua
--- -- 3x4 grid of icons
--- local grid = dsl.grid(3, 4, function(row, col)
---     return dsl.anim("icon_" .. row .. "_" .. col .. ".png", { w = 48, h = 48 })
--- end)
---
--- -- Inventory slots grid
--- local slots = dsl.grid(4, 8, function(r, c)
---     local index = (r - 1) * 8 + c
---     return dsl.button(tostring(index), {
---         onClick = function() selectSlot(index) end,
---         minWidth = 50, minHeight = 50
---     })
--- end)
---
--- -- Use in a container (grid returns array of row nodes)
--- dsl.vbox {
---     children = dsl.grid(3, 3, function(r, c)
---         return dsl.text(r .. "," .. c)
---     end)
--- }
--- ```
---@param rows number Number of rows in the grid
---@param cols number Number of columns per row
---@param gen function Generator function: `function(row, col) -> UIDefinition`. Called for each cell (1-indexed)
---@return table[] Array of row UIDefinition nodes (each row is an hbox)
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

---@class ButtonOpts
---@field onClick? function Callback when button is clicked
---@field color? string|Color Button background color (default: "gray")
---@field textColor? string|Color Button label text color (default: "white")
---@field fontSize? number Label font size in pixels (default: 16)
---@field shadow? boolean Enable text shadow (default: true)
---@field hover? TextHover|boolean Tooltip config or false to disable hover effect
---@field tooltip? table Additional tooltip data
---@field disabled? boolean Disable button interaction (default: false)
---@field emboss? number 3D emboss depth in pixels (default: 2)
---@field minWidth? number Minimum button width in pixels
---@field minHeight? number Minimum button height in pixels
---@field align? number AlignmentFlag bitmask for label alignment
---@field id? string Unique identifier for lookups

--- Create a clickable button element.
---
--- **Example:**
--- ```lua
--- -- Simple button
--- dsl.button("Click Me", {
---     onClick = function() print("Clicked!") end
--- })
---
--- -- Styled button
--- dsl.button("Confirm", {
---     onClick = confirmAction,
---     color = "green",
---     textColor = "white",
---     minWidth = 100
--- })
---
--- -- Button with tooltip
--- dsl.button("Help", {
---     onClick = showHelp,
---     hover = { title = "Help", body = "Get assistance" }
--- })
---
--- -- Disabled button
--- dsl.button("Submit", {
---     onClick = submit,
---     disabled = not formValid
--- })
--- ```
---@param label string Button text
---@param opts? ButtonOpts Optional configuration
---@return table UIDefinition node for the button
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
            hover          = opts.hover ~= false,
            canCollide     = true,
            buttonCallback = opts.onClick,
            tooltip        = opts.tooltip,
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

---@class ProgressBarOpts
---@field getValue? function Callback returning current value (0.0 to maxValue)
---@field maxValue? number Maximum value for the bar (default: 1.0)
---@field color? string|Color Bar background/border color (default: "gray")
---@field emptyColor? string|Color Empty portion color (default: "gray")
---@field fullColor? string|Color Filled portion color (default: "green")
---@field minWidth? number Minimum bar width in pixels (default: 200)
---@field minHeight? number Minimum bar height in pixels (default: 20)
---@field align? number AlignmentFlag bitmask for content alignment
---@field children? table[] Optional child elements overlaid on bar
---@field id? string Unique identifier for lookups

--- Create an animated progress bar that updates from a callback.
---
--- **Example:**
--- ```lua
--- -- Health bar (0-1 range)
--- dsl.progressBar({
---     getValue = function() return player.health / player.maxHealth end,
---     emptyColor = "darkred",
---     fullColor = "green"
--- })
---
--- -- Experience bar with custom max
--- dsl.progressBar({
---     getValue = function() return player.xp end,
---     maxValue = player.xpToNextLevel,
---     fullColor = "gold",
---     minWidth = 300
--- })
---
--- -- Progress bar with label overlay
--- dsl.progressBar({
---     getValue = function() return downloadProgress end,
---     fullColor = "blue",
---     children = {
---         dsl.text("Downloading...", { fontSize = 12, color = "white" })
---     }
--- })
--- ```
---@param opts ProgressBarOpts Configuration options
---@return table UIDefinition node for the progress bar
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
            progressBarEmptyColor = color(opts.emptyColor or "gray"),
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

--- Create an invisible spacing element for layout purposes.
--- Useful for adding gaps between UI elements without visible content.
---
--- **Example:**
--- ```lua
--- -- Square spacer (20x20)
--- dsl.spacer(20)
---
--- -- Rectangular spacer (width x height)
--- dsl.spacer(100, 20)  -- horizontal gap
--- dsl.spacer(20, 50)   -- vertical gap
---
--- -- In a vbox, add vertical space between items
--- dsl.vbox {
---     children = {
---         dsl.text("Above"),
---         dsl.spacer(10, 30),  -- 30px vertical gap
---         dsl.text("Below"),
---     }
--- }
--- ```
---@param w? number Width in pixels (default: 10)
---@param h? number Height in pixels (default: same as width)
---@return table UIDefinition node for the transparent spacer
function dsl.spacer(w, h)
    return def{
        type = "RECT_SHAPE",
        config = {
            color = resolveSpacerColor(),
            minWidth = w or 10,
            minHeight = h or w or 10,
            instanceType = "spacer",
        }
    }
end

------------------------------------------------------------
-- 1️⃣1️⃣ Divider Element
-- Horizontal or vertical divider line.
------------------------------------------------------------

---@class DividerOpts
---@field color? string|Color Line color (default: "white")
---@field thickness? number Line thickness in pixels (default: 1)
---@field length? number Line length in pixels (default: 100 for horizontal, 20 for vertical)

--- Create a divider line element for visual separation.
---
--- **Example:**
--- ```lua
--- -- Horizontal divider (default)
--- dsl.divider("horizontal")
---
--- -- Styled horizontal divider
--- dsl.divider("horizontal", { color = "gray", thickness = 2, length = 200 })
---
--- -- Vertical divider between columns
--- dsl.divider("vertical", { color = "white", length = 50 })
---
--- -- Usage in a vbox
--- dsl.vbox {
---     children = {
---         dsl.text("Section 1"),
---         dsl.divider("horizontal", { color = "gray" }),
---         dsl.text("Section 2"),
---     }
--- }
--- ```
---@param direction "horizontal"|"vertical" Divider orientation
---@param opts? DividerOpts Optional styling configuration
---@return table UIDefinition node for the divider line
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
                padding   = 0,
                shadow    = false,
                emboss    = 0,
                line_emboss = false,
            }
        }
    else
        return def{
            type = "RECT_SHAPE",
            config = {
                color     = color(opts.color or "white"),
                minWidth  = opts.length or 100,
                minHeight = thickness,
                padding   = 0,
                shadow    = false,
                emboss    = 0,
                line_emboss = false,
            }
        }
    end
end

------------------------------------------------------------
-- 1️⃣2️⃣ Icon with Label
-- Common pattern: icon + text side by side.
------------------------------------------------------------

---@class IconLabelOpts
---@field iconSize? number Icon width and height in pixels (default: 24)
---@field fontSize? number Label font size in pixels (default: 16)
---@field textColor? string|Color Label text color (default: "white")
---@field shadow? boolean Enable text shadow (default: from theme)
---@field padding? number Gap between icon and label (default: 2)
---@field align? number AlignmentFlag bitmask for content alignment
---@field id? string Unique identifier for lookups

--- Create an icon with adjacent label text.
--- A common pattern for stats, currency, inventory items, etc.
---
--- **Example:**
--- ```lua
--- -- Currency display
--- dsl.iconLabel("coin.png", "100 Gold")
---
--- -- Stat with custom styling
--- dsl.iconLabel("heart.png", "HP: 50", {
---     iconSize = 20,
---     fontSize = 14,
---     textColor = "red"
--- })
---
--- -- Item with larger icon
--- dsl.iconLabel("sword.png", "Steel Sword", { iconSize = 32, fontSize = 18 })
--- ```
---@param iconId string Sprite filename for the icon
---@param label string Text to display next to the icon
---@param opts? IconLabelOpts Optional styling configuration
---@return table UIDefinition node for the icon+label combo
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

---@class RichTextOpts
---@field fontSize? number Default font size in pixels
---@field fontName? string Default font asset name
---@field color? string|Color Default text color
---@field shadow? boolean Enable text shadow (default: false)

--- Create styled text with inline markup.
--- Supports markdown-like syntax for colors and effects.
---
--- **Markup syntax:**
--- - `[text](color=red)` - Apply color to text
--- - `[text](pop=0.2)` - Apply pop effect with intensity
--- - `[text](color=gold;pop=0.1)` - Multiple styles
---
--- **Example:**
--- ```lua
--- -- Colored text segments
--- dsl.richText("[Health](color=red): 100")
---
--- -- Multiple styled segments
--- dsl.richText("Deal [25](color=red) [Fire](color=orange) damage")
---
--- -- With default styling
--- dsl.richText("[Critical Hit!](color=gold;pop=0.3)", {
---     fontSize = 24,
---     shadow = true
--- })
--- ```
---@param text string Text content with markup tags
---@param opts? RichTextOpts Optional default styling
---@return table UIDefinition node for the rich text
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

---@class SectionOpts
---@field children? table[] Array of child UI nodes for the content area
---@field titleSize? number Title font size in pixels (default: 18)
---@field titleColor? string|Color Title text color (default: "white")
---@field titleBg? string|Color Title bar background color (default: "black")
---@field titlePadding? number Title bar padding in pixels (default: 4)
---@field color? string|Color Content area background color (default: "gray")
---@field padding? number Content area padding in pixels (default: 6)
---@field emboss? number 3D emboss depth in pixels (default: 2)
---@field id? string Unique identifier for lookups

--- Create a titled section with a header bar and content area.
--- Useful for grouping related UI elements under a labeled header.
---
--- **Example:**
--- ```lua
--- -- Basic section
--- dsl.section("Inventory", {
---     children = {
---         dsl.text("Item 1"),
---         dsl.text("Item 2"),
---     }
--- })
---
--- -- Styled section
--- dsl.section("Stats", {
---     titleColor = "gold",
---     titleBg = "darkblue",
---     color = "navy",
---     padding = 10,
---     children = {
---         dsl.iconLabel("heart.png", "HP: 100"),
---         dsl.iconLabel("sword.png", "ATK: 25"),
---     }
--- })
--- ```
---@param title string Section header text
---@param opts? SectionOpts Optional styling and content configuration
---@return table UIDefinition node for the titled section
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

--- Conditionally include a UI node based on a boolean condition.
--- Returns the node if condition is truthy, or nil (which is filtered out).
---
--- **Example:**
--- ```lua
--- -- Show debug text only when enabled
--- dsl.vbox {
---     children = {
---         dsl.text("Always visible"),
---         dsl.when(debugMode, dsl.text("Debug: ON", { color = "yellow" })),
---         dsl.when(player.health < 20, dsl.text("LOW HEALTH!", { color = "red" })),
---     }
--- }
---
--- -- Conditional button
--- dsl.hbox {
---     children = {
---         dsl.button("Save", { onClick = save }),
---         dsl.when(canUndo, dsl.button("Undo", { onClick = undo })),
---     }
--- }
--- ```
---@param condition any Condition to evaluate (truthy = include, falsy = exclude)
---@param node table UI definition node to conditionally include
---@return table|nil The node if condition is truthy, nil otherwise
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

--- Generate UI nodes from a data array using a mapper function.
--- Similar to JavaScript's `array.map()` but filters out nil results.
---
--- **Example:**
--- ```lua
--- -- Inventory list
--- local items = { { icon = "sword.png", name = "Sword" }, { icon = "shield.png", name = "Shield" } }
--- dsl.vbox {
---     children = dsl.list(items, function(item, index)
---         return dsl.iconLabel(item.icon, item.name)
---     end)
--- }
---
--- -- Numbered list
--- local scores = { 100, 85, 92, 78 }
--- dsl.vbox {
---     children = dsl.list(scores, function(score, i)
---         return dsl.text(i .. ". Score: " .. score)
---     end)
--- }
---
--- -- Filtered list (return nil to skip)
--- dsl.list(enemies, function(enemy, i)
---     if enemy.isVisible then
---         return dsl.text(enemy.name)
---     end
---     return nil  -- Skip invisible enemies
--- end)
--- ```
---@param data table Array of data items to map
---@param mapper function Mapper: `function(item, index) -> UIDefinition|nil`. Return nil to skip item
---@return table[] Array of UI definition nodes (nil results filtered out)
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
-- 1️⃣7️⃣ Sprite Box (9-patch or fixed sprite background)
------------------------------------------------------------

---@class SpriteBoxSpriteConfig
---@field sprite string Sprite filename
---@field fixed? boolean If true, use sprite's native size (no stretching)

---@class SpriteBoxOpts
---@field sprite? SpriteBoxSpriteConfig Sprite configuration with filename and sizing mode
---@field children? table[] Array of child UI nodes
---@field vertical? boolean If true, use vertical container; otherwise horizontal (default: false)
---@field padding? number Inner padding in pixels (default: 0)
---@field id? string Unique identifier for lookups

--- Create a container with a sprite background.
--- Supports fixed-size sprites that maintain their native dimensions.
---
--- **Example:**
--- ```lua
--- -- Fixed-size sprite background
--- dsl.spriteBox({
---     sprite = { sprite = "panel.png", fixed = true },
---     children = { dsl.text("Content") }
--- })
---
--- -- Vertical container with sprite
--- dsl.spriteBox({
---     sprite = { sprite = "frame.png" },
---     vertical = true,
---     padding = 10,
---     children = { ... }
--- })
--- ```
---@param opts SpriteBoxOpts Configuration options
---@return table UIDefinition node for the sprite box
function dsl.spriteBox(opts)
    opts = opts or {}
    local config = {
        id = opts.id,
        padding = opts.padding or 0,
    }
    
    if opts.sprite then
        if opts.sprite.fixed then
            local frame = init and init.getSpriteFrame and init.getSpriteFrame(opts.sprite.sprite, globals.g_ctx)
            if frame then
                config.minWidth = frame.frame.width
                config.minHeight = frame.frame.height
                config.maxWidth = frame.frame.width
                config.maxHeight = frame.frame.height
            end
        end
        config.spriteBorder = opts.sprite
    end
    
    return def{
        type = opts.vertical and "VERTICAL_CONTAINER" or "HORIZONTAL_CONTAINER",
        config = config,
        children = opts.children or {},
    }
end

------------------------------------------------------------
-- TAB SYSTEM
-- Stores tab definitions in Lua closures, no C++ tab components needed
------------------------------------------------------------

--- Module-level storage for tab definitions
--- Key: container ID (string), Value: { tabs = {...}, activeId = "..." }
local _tabRegistry = {}

---@class TabDefinition
---@field id string Unique tab identifier (used for switching)
---@field label string Tab button display text
---@field content function Content generator: `function() -> UIDefinition`. Called when tab is activated

---@class TabsOpts
---@field tabs TabDefinition[] Array of tab definitions (required, at least 1)
---@field activeTab? string ID of initially active tab (default: first tab's id)
---@field tabBarPadding? number Padding inside tab bar in pixels (default: 2)
---@field tabBarAlign? number AlignmentFlag bitmask for tab bar alignment
---@field buttonColor? string|Color Inactive tab button color (default: "gray")
---@field activeButtonColor? string|Color Active tab button color (default: "blue")
---@field buttonPadding? number Tab button padding in pixels (default: 4)
---@field buttonMinWidth? number Minimum tab button width in pixels
---@field buttonMinHeight? number Minimum tab button height in pixels
---@field contentPadding? number Content area padding in pixels (default: 6)
---@field contentColor? string|Color Content area background color
---@field contentMinWidth? number Minimum content area width in pixels
---@field contentMinHeight? number Minimum content area height in pixels
---@field containerPadding? number Outer container padding in pixels (default: 0)
---@field containerColor? string|Color Outer container background color
---@field fontSize? number Tab label font size in pixels (default: 14)
---@field textColor? string|Color Tab label text color (default: "white")
---@field emboss? number Tab button emboss depth (default: 2)
---@field id? string Unique container identifier for programmatic switching

--- Create a tabbed container with switchable content panels.
--- Content is lazily generated when tabs are activated.
---
--- **Related functions:**
--- - `dsl.switchTab(containerId, tabId)` - Switch to a different tab
--- - `dsl.getActiveTab(containerId)` - Get currently active tab ID
--- - `dsl.getTabIds(containerId)` - Get all tab IDs
--- - `dsl.cleanupTabs(containerId)` - Clean up when destroying container
---
--- **Example:**
--- ```lua
--- -- Basic tabs
--- dsl.tabs({
---     tabs = {
---         { id = "info", label = "Info", content = function()
---             return dsl.text("Information content")
---         end },
---         { id = "stats", label = "Stats", content = function()
---             return dsl.vbox { children = { ... } }
---         end },
---     }
--- })
---
--- -- Styled tabs with explicit sizing
--- dsl.tabs({
---     id = "main_tabs",
---     activeTab = "inventory",
---     buttonColor = "darkgray",
---     activeButtonColor = "gold",
---     contentMinWidth = 300,
---     contentMinHeight = 200,
---     tabs = {
---         { id = "inventory", label = "Inventory", content = buildInventoryUI },
---         { id = "equipment", label = "Equipment", content = buildEquipmentUI },
---         { id = "skills", label = "Skills", content = buildSkillsUI },
---     }
--- })
---
--- -- Programmatic tab switching
--- dsl.switchTab("main_tabs", "equipment")
--- ```
---@param opts TabsOpts Configuration options
---@return table UIDefinition node for the tabbed container
function dsl.tabs(opts)
    opts = opts or {}
    local tabs = opts.tabs or {}
    
    -- Validate tabs
    if #tabs == 0 then
        log_warn("dsl.tabs: No tabs provided")
        return dsl.vbox{ children = {} }
    end
    
    -- Generate container ID
    local containerId = opts.id or ("tabs_" .. tostring(math.random(100000, 999999)))
    local activeTab = opts.activeTab or tabs[1].id
    
    -- Validate activeTab exists
    local activeFound = false
    for _, tab in ipairs(tabs) do
        if tab.id == activeTab then
            activeFound = true
            break
        end
    end
    if not activeFound then
        log_warn("dsl.tabs: activeTab '" .. tostring(activeTab) .. "' not found, using first tab")
        activeTab = tabs[1].id
    end
    
    -- Store tab definitions for later lookup
    _tabRegistry[containerId] = {
        tabs = tabs,
        activeId = activeTab,
        buttonColor = color(opts.buttonColor or "gray"),
        activeButtonColor = color(opts.activeButtonColor or "blue"),
    }
    
    -- Build tab buttons
    local tabButtons = {}
    for i, tab in ipairs(tabs) do
        local isActive = (tab.id == activeTab)
        local buttonId = "tab_btn_" .. tab.id
        
        table.insert(tabButtons, def{
            type = "HORIZONTAL_CONTAINER",
            config = {
                id = buttonId,
                color = color(isActive and (opts.activeButtonColor or "blue") or (opts.buttonColor or "gray")),
                hover = true,
                choice = true,
                chosen = isActive,
                group = containerId,
                emboss = opts.emboss or 2,
                padding = opts.buttonPadding or 4,
                minWidth = opts.buttonMinWidth,
                minHeight = opts.buttonMinHeight,
                buttonCallback = function()
                    dsl.switchTab(containerId, tab.id)
                end,
            },
            children = {
                dsl.text(tab.label, {
                    fontSize = opts.fontSize or 14,
                    color = opts.textColor or "white",
                    shadow = true
                })
            }
        })
    end
    
    -- Get initial content
    local initialContent = nil
    for _, tab in ipairs(tabs) do
        if tab.id == activeTab then
            local success, result = pcall(tab.content)
            if success then
                initialContent = result
            else
                log_error("dsl.tabs: Error generating content for tab '" .. tab.id .. "': " .. tostring(result))
                initialContent = dsl.text("Error loading tab", { color = "red" })
            end
            break
        end
    end
    
    -- Build container
    return def{
        type = "VERTICAL_CONTAINER",
        config = {
            id = containerId,
            padding = opts.containerPadding or 0,
            color = color(opts.containerColor),
        },
        children = {
            -- Tab bar
            def{
                type = "HORIZONTAL_CONTAINER",
                config = {
                    id = containerId .. "_bar",
                    padding = opts.tabBarPadding or 2,
                    align = opts.tabBarAlign or bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
                },
                children = tabButtons
            },
            -- Content area
            def{
                type = "VERTICAL_CONTAINER",
                config = {
                    id = containerId .. "_content",
                    padding = opts.contentPadding or 6,
                    minWidth = opts.contentMinWidth,
                    minHeight = opts.contentMinHeight,
                    color = color(opts.contentColor),
                },
                children = initialContent and { initialContent } or {}
            }
        }
    }
end

--- Programmatically switch to a different tab in a tab container.
---
--- **Example:**
--- ```lua
--- -- Switch to equipment tab
--- dsl.switchTab("main_tabs", "equipment")
---
--- -- Conditional tab switching
--- if hasUnreadMessages then
---     dsl.switchTab("menu_tabs", "messages")
--- end
--- ```
---@param containerId string The tab container's ID (from dsl.tabs opts.id)
---@param newTabId string The ID of the tab to switch to
---@return boolean true if switch succeeded, false if container/tab not found
function dsl.switchTab(containerId, newTabId)
    -- Get stored tab data
    local tabData = _tabRegistry[containerId]
    if not tabData then
        log_warn("dsl.switchTab: Unknown container '" .. tostring(containerId) .. "'")
        return false
    end
    
    -- Already on this tab?
    if tabData.activeId == newTabId then
        log_debug("dsl.switchTab: Already on tab '" .. newTabId .. "'")
        return true
    end
    
    -- Find the container entity
    local container = ui.box.GetUIEByID(registry, containerId)
    if not container then
        log_warn("dsl.switchTab: Container entity not found: " .. containerId)
        return false
    end
    
    -- Find the new tab definition
    local newTabDef = nil
    for _, tab in ipairs(tabData.tabs) do
        if tab.id == newTabId then
            newTabDef = tab
            break
        end
    end
    
    if not newTabDef then
        log_warn("dsl.switchTab: Tab not found: " .. newTabId)
        return false
    end
    
    -- Generate new content (with error handling)
    local newContent
    local success, result = pcall(newTabDef.content)
    if success then
        newContent = result
    else
        log_error("dsl.switchTab: Error generating content for tab '" .. newTabId .. "': " .. tostring(result))
        newContent = dsl.text("Error loading tab", { color = "red" })
    end
    
    local oldTabId = tabData.activeId
    for _, tab in ipairs(tabData.tabs) do
        local btnId = "tab_btn_" .. tab.id
        local btn = ui.box.GetUIEByID(registry, container, btnId)
        if btn then
            local btnConfig = component_cache.get(btn, UIConfig)
            if btnConfig then
                local isNowActive = (tab.id == newTabId)
                btnConfig.chosen = isNowActive
                btnConfig.color = isNowActive and tabData.activeButtonColor or tabData.buttonColor
            end
        end
    end
    
    -- Replace content
    local contentSlot = ui.box.GetUIEByID(registry, container, containerId .. "_content")
    if not contentSlot then
        log_warn("dsl.switchTab: Content slot not found: " .. containerId .. "_content")
        return false
    end
    
    local replaceSuccess = ui.box.ReplaceChildren(contentSlot, newContent)
    if not replaceSuccess then
        log_error("dsl.switchTab: Failed to replace content")
        return false
    end
    
    -- Update stored state
    tabData.activeId = newTabId
    
    log_debug("dsl.switchTab: Switched from '" .. oldTabId .. "' to '" .. newTabId .. "'")
    return true
end

--- Get the currently active tab ID for a tab container.
---
--- **Example:**
--- ```lua
--- local activeTab = dsl.getActiveTab("main_tabs")
--- if activeTab == "inventory" then
---     refreshInventory()
--- end
--- ```
---@param containerId string The tab container's ID
---@return string|nil Active tab ID, or nil if container not found
function dsl.getActiveTab(containerId)
    local tabData = _tabRegistry[containerId]
    return tabData and tabData.activeId or nil
end

--- Clean up tab registry entry when destroying a tab container.
--- Call this to prevent memory leaks when removing tab UI.
---
--- **Example:**
--- ```lua
--- -- When destroying the UI
--- registry:destroy(tabBoxEntity)
--- dsl.cleanupTabs("main_tabs")
--- ```
---@param containerId string The tab container's ID
function dsl.cleanupTabs(containerId)
    _tabRegistry[containerId] = nil
end

--- Get all registered tab IDs for a container.
---
--- **Example:**
--- ```lua
--- local tabs = dsl.getTabIds("main_tabs")
--- -- tabs = { "inventory", "equipment", "skills" }
--- for _, tabId in ipairs(tabs) do
---     print("Available tab: " .. tabId)
--- end
--- ```
---@param containerId string The tab container's ID
---@return string[]|nil Array of tab IDs, or nil if container not found
function dsl.getTabIds(containerId)
    local tabData = _tabRegistry[containerId]
    if not tabData then return nil end
    
    local ids = {}
    for _, tab in ipairs(tabData.tabs) do
        table.insert(ids, tab.id)
    end
    return ids
end


------------------------------------------------------------
-- INVENTORY GRID
-- Draggable item grid with slots, stacking, and filtering
------------------------------------------------------------

local _gridRegistry = {}

---@class SlotSize
---@field w number Slot width in pixels
---@field h number Slot height in pixels

---@class SlotConfig
---@field color? string|Color Slot background color (overrides grid default)
---@field sprite? string Slot sprite filename (overrides grid default)

---@class InventoryGridConfig
---@field backgroundColor? string|Color Grid background color
---@field slotColor? string|Color Default slot background color
---@field slotSprite? string Default slot sprite filename
---@field slotEmboss? number Slot emboss depth (default: 1)
---@field padding? number Outer padding in pixels (default: 4)

---@class InventoryGridOpts
---@field rows? number Number of rows (default: 3)
---@field cols? number Number of columns (default: 3)
---@field slotSize? SlotSize Slot dimensions as { w, h } (default: { w = 64, h = 64 })
---@field slotSpacing? number Gap between slots in pixels (default: 4)
---@field onSlotChange? function Callback when slot content changes: `function(gridId, slotIndex, oldItem, newItem)`
---@field onSlotClick? function Callback when slot is clicked: `function(gridId, slotIndex)`
---@field onItemStack? function Callback when items are stacked: `function(gridId, slotIndex, item, quantity)`
---@field slots? table<number, SlotConfig> Per-slot configuration (1-indexed by slot number)
---@field config? InventoryGridConfig Grid-wide configuration
---@field id? string Unique identifier for lookups and callbacks

--- Create an inventory grid with interactive slots.
--- Supports drag-and-drop, item stacking, and per-slot customization.
---
--- **Slot numbering:** Slots are numbered 1 to (rows × cols), left-to-right, top-to-bottom.
---
--- **Related functions:**
--- - `dsl.getGridConfig(gridId)` - Get grid configuration
--- - `dsl.cleanupGrid(gridId)` - Clean up when destroying grid
---
--- **Example:**
--- ```lua
--- -- Basic 3x3 inventory
--- dsl.inventoryGrid({
---     rows = 3,
---     cols = 3,
---     onSlotClick = function(gridId, slot)
---         print("Clicked slot " .. slot)
---     end
--- })
---
--- -- Styled inventory with custom slots
--- dsl.inventoryGrid({
---     id = "player_inventory",
---     rows = 4,
---     cols = 8,
---     slotSize = { w = 50, h = 50 },
---     slotSpacing = 2,
---     config = {
---         backgroundColor = "darkgray",
---         slotColor = "gray",
---         slotEmboss = 2
---     },
---     slots = {
---         [1] = { color = "gold" },  -- Special slot
---         [2] = { sprite = "locked_slot.png" }
---     },
---     onSlotChange = function(gridId, slot, old, new)
---         updateInventory(slot, new)
---     end
--- })
--- ```
---@param opts InventoryGridOpts Configuration options
---@return table UIDefinition node for the inventory grid
function dsl.inventoryGrid(opts)
    opts = opts or {}
    local rows = opts.rows or 3
    local cols = opts.cols or 3
    local slotW = opts.slotSize and opts.slotSize.w or 64
    local slotH = opts.slotSize and opts.slotSize.h or 64
    local spacing = opts.slotSpacing or 4
    local gridId = opts.id or ("grid_" .. tostring(math.random(100000, 999999)))
    local gridConfig = opts.config or {}
    local slotsConfig = opts.slots or {}
    local outerPadding = gridConfig.padding or 4

    -- Calculate total grid dimensions for explicit sizing
    local contentW = (cols * slotW) + ((cols - 1) * spacing)
    local contentH = (rows * slotH) + ((rows - 1) * spacing)
    local totalW = contentW + (outerPadding * 2)
    local totalH = contentH + (outerPadding * 2)

    _gridRegistry[gridId] = {
        rows = rows,
        cols = cols,
        config = gridConfig,
        slotsConfig = slotsConfig,
        onSlotChange = opts.onSlotChange,
        onSlotClick = opts.onSlotClick,
        onItemStack = opts.onItemStack,
    }
    
    local gridRows = {}
    local slotIndex = 0
    
    for r = 1, rows do
        local rowChildren = {}
        
        for c = 1, cols do
            slotIndex = slotIndex + 1
            local slotId = gridId .. "_slot_" .. slotIndex
            local slotConfig = slotsConfig[slotIndex] or {}
            local defaultSlotColor = gridConfig.slotColor and color(gridConfig.slotColor) or color("gray")
            local slotColor = slotConfig.color or defaultSlotColor
            local slotSprite = slotConfig.sprite or gridConfig.slotSprite
            
            local slotNodeConfig = {
                id = slotId,
                color = slotColor,
                minWidth = slotW,
                minHeight = slotH,
                maxWidth = slotW,
                maxHeight = slotH,
                hover = true,
                canCollide = true,
                emboss = gridConfig.slotEmboss or 1,
                align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
                _slotIndex = slotIndex,
                _gridId = gridId,
                _isInventorySlot = true,
            }
            
            if slotSprite then
                slotNodeConfig._isSpritePanel = true
                slotNodeConfig._spriteName = slotSprite
                slotNodeConfig._sizing = "fixed"
                slotNodeConfig._borders = { left = 0, top = 0, right = 0, bottom = 0 }
                slotNodeConfig.color = nil
                slotNodeConfig.emboss = nil
            end
            
            local slotNode = def{
                type = "HORIZONTAL_CONTAINER",
                config = slotNodeConfig,
                children = {}
            }
            
            table.insert(rowChildren, slotNode)
            if c < cols then
                table.insert(rowChildren, dsl.spacer(spacing, slotH))
            end
        end
        
        local rowNode = def{
            type = "HORIZONTAL_CONTAINER",
            config = {
                align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
                padding = 0,  -- No padding to prevent overlap
            },
            children = rowChildren
        }
        
        table.insert(gridRows, rowNode)
        if r < rows then
            table.insert(gridRows, dsl.spacer(slotW * cols + spacing * (cols - 1), spacing))
        end
    end
    
    return def{
        type = "VERTICAL_CONTAINER",
        config = {
            id = gridId,
            color = gridConfig.backgroundColor and color(gridConfig.backgroundColor) or nil,
            padding = outerPadding,
            minWidth = totalW,    -- Explicit sizing to prevent overlap
            maxWidth = totalW,
            minHeight = totalH,
            maxHeight = totalH,
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
            _isInventoryGrid = true,
            _gridConfig = gridConfig,
            _slotsConfig = slotsConfig,
            _gridRows = rows,
            _gridCols = cols,
        },
        children = gridRows
    }
end

--- Get the stored configuration for an inventory grid.
---
--- **Example:**
--- ```lua
--- local config = dsl.getGridConfig("player_inventory")
--- if config then
---     print("Grid has " .. config.rows .. " rows")
--- end
--- ```
---@param gridId string The grid's ID
---@return table|nil Grid configuration, or nil if not found
function dsl.getGridConfig(gridId)
    return _gridRegistry[gridId]
end

--- Clean up grid registry entry when destroying an inventory grid.
--- Call this to prevent memory leaks when removing grid UI.
---
--- **Example:**
--- ```lua
--- -- When destroying the inventory UI
--- registry:destroy(gridBoxEntity)
--- dsl.cleanupGrid("player_inventory")
--- ```
---@param gridId string The grid's ID
function dsl.cleanupGrid(gridId)
    _gridRegistry[gridId] = nil
end

------------------------------------------------------------
-- CUSTOM PANEL
-- Custom-rendered UI element that participates in layout
------------------------------------------------------------

---@class CustomPanelConfig
---@field color? string|Color Panel background color
---@field hover? boolean Enable hover detection
---@field canCollide? boolean Enable collision detection

---@class CustomPanelOpts
---@field onDraw? function Custom draw callback: function(entity, x, y, w, h)
---@field onUpdate? function Custom update callback: function(entity, dt)
---@field onInput? function Custom input callback: function(entity, inputEvent)
---@field minWidth? number Minimum panel width in pixels (default: 100)
---@field minHeight? number Minimum panel height in pixels (default: 100)
---@field preferredWidth? number Preferred/maximum width in pixels
---@field preferredHeight? number Preferred/maximum height in pixels
---@field focusable? boolean Can receive keyboard focus (default: false)
---@field config? CustomPanelConfig Additional panel configuration
---@field id? string Unique identifier for lookups

--- Create a custom-rendered panel with manual draw/update callbacks.
--- Useful for complex rendering that can't be expressed with standard DSL elements.
---
--- **Example:**
--- ```lua
--- -- Custom graph panel
--- dsl.customPanel({
---     minWidth = 200,
---     minHeight = 150,
---     onDraw = function(entity, x, y, w, h)
---         drawGraph(x, y, w, h, dataPoints)
---     end,
---     onUpdate = function(entity, dt)
---         updateGraphAnimation(dt)
---     end
--- })
---
--- -- Focusable input panel
--- dsl.customPanel({
---     minWidth = 100,
---     minHeight = 30,
---     focusable = true,
---     onInput = function(entity, event)
---         handleKeypress(event)
---     end,
---     config = { hover = true, canCollide = true }
--- })
--- ```
---@param opts CustomPanelOpts Configuration options
---@return table UIDefinition node for the custom panel
function dsl.customPanel(opts)
    opts = opts or {}
    local panelId = opts.id or ("custom_panel_" .. tostring(math.random(100000, 999999)))
    local panelConfig = opts.config or {}
    
    return def{
        type = "HORIZONTAL_CONTAINER",
        config = {
            id = panelId,
            minWidth = opts.minWidth or 100,
            minHeight = opts.minHeight or 100,
            maxWidth = opts.preferredWidth,
            maxHeight = opts.preferredHeight,
            color = panelConfig.color and color(panelConfig.color) or nil,
            hover = panelConfig.hover,
            canCollide = panelConfig.canCollide,
            _isCustomPanel = true,
            _onDraw = opts.onDraw,
            _onUpdate = opts.onUpdate,
            _onInput = opts.onInput,
            _focusable = opts.focusable,
        },
        children = {}
    }
end

------------------------------------------------------------
-- SPRITE PANEL
-- Nine-patch sprite panel with inline definition (no JSON)
------------------------------------------------------------

---@class DecorationConfig
---@field sprite string Decoration sprite filename
---@field position? "top_left"|"top_center"|"top_right"|"middle_left"|"center"|"middle_right"|"bottom_left"|"bottom_center"|"bottom_right" Anchor position (default: "top_left")
---@field offset? number[] Offset from anchor as { x, y } (default: { 0, 0 })
---@field opacity? number Opacity from 0.0 to 1.0 (default: 1.0)
---@field flip? "x"|"y"|"both"|nil Flip direction
---@field rotation? number Rotation in radians (default: 0)
---@field zOffset? number Z-order offset relative to panel (default: 0)
---@field visible? boolean Visibility flag (default: true)
---@field id? string Identifier for runtime updates

---@class SpritePanelOpts
---@field sprite? string Nine-patch sprite filename
---@field borders? number[]|{left:number,top:number,right:number,bottom:number} Nine-patch border sizes as [left, top, right, bottom] or named table (default: { 8, 8, 8, 8 })
---@field sizing? "fit_content"|"fixed"|"stretch" How the panel sizes relative to content (default: "fit_content")
---@field tint? string|Color Color tint applied to sprite
---@field children? table[] Array of child UI nodes
---@field containerType? "VERTICAL_CONTAINER"|"HORIZONTAL_CONTAINER" Internal layout direction (default: "VERTICAL_CONTAINER")
---@field padding? number Inner padding in pixels
---@field align? number AlignmentFlag bitmask for content alignment
---@field minWidth? number Minimum panel width in pixels
---@field minHeight? number Minimum panel height in pixels
---@field maxWidth? number Maximum panel width in pixels
---@field maxHeight? number Maximum panel height in pixels
---@field decorations? DecorationConfig[] Array of decoration overlays
---@field regions? table Named regions for complex layouts
---@field hover? boolean Enable hover detection
---@field canCollide? boolean Enable collision detection
---@field id? string Unique identifier for lookups

--- Create a nine-patch sprite panel with optional decorations.
--- Nine-patch sprites stretch their center while preserving corner/edge regions.
---
--- **Decoration positions:**
--- `top_left`, `top_center`, `top_right`, `middle_left`, `center`,
--- `middle_right`, `bottom_left`, `bottom_center`, `bottom_right`
---
--- **Example:**
--- ```lua
--- -- Basic nine-patch panel
--- dsl.spritePanel({
---     sprite = "ui-panel-frame.png",
---     borders = { 8, 8, 8, 8 },
---     padding = 10,
---     children = { dsl.text("Panel Content") }
--- })
---
--- -- Panel with corner decorations
--- dsl.spritePanel({
---     sprite = "fancy-frame.png",
---     borders = { 12, 12, 12, 12 },
---     decorations = {
---         { sprite = "corner-gem.png", position = "top_left", offset = { -4, -4 } },
---         { sprite = "corner-gem.png", position = "top_right", offset = { 4, -4 }, flip = "x" },
---     },
---     children = { ... }
--- })
---
--- -- Fixed-size panel
--- dsl.spritePanel({
---     sprite = "card-slot.png",
---     sizing = "fixed",
---     borders = { 4, 4, 4, 4 }
--- })
--- ```
---@param opts SpritePanelOpts Configuration options
---@return table UIDefinition node for the sprite panel
function dsl.spritePanel(opts)
    opts = opts or {}
    local panelId = opts.id or ("sprite_panel_" .. tostring(math.random(100000, 999999)))
    
    local borders = opts.borders or { 8, 8, 8, 8 }
    if type(borders) == "table" and #borders == 4 then
        borders = { left = borders[1], top = borders[2], right = borders[3], bottom = borders[4] }
    end
    
    local decorations = {}
    if opts.decorations then
        for _, decor in ipairs(opts.decorations) do
            table.insert(decorations, {
                sprite = decor.sprite,
                position = decor.position or "top_left",
                offset = decor.offset or { 0, 0 },
                opacity = decor.opacity or 1.0,
                flip = decor.flip,
                rotation = decor.rotation or 0,
                zOffset = decor.zOffset or 0,
                visible = decor.visible ~= false,
                id = decor.id
            })
        end
    end
    
    return def{
        type = opts.containerType or "VERTICAL_CONTAINER",
        config = {
            id = panelId,
            minWidth = opts.minWidth,
            minHeight = opts.minHeight,
            maxWidth = opts.maxWidth,
            maxHeight = opts.maxHeight,
            padding = opts.padding,
            hover = opts.hover,
            canCollide = opts.canCollide,
            align = opts.align or bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
            _isSpritePanel = true,
            _spriteName = opts.sprite,
            _borders = borders,
            _sizing = opts.sizing or "fit_content",
            _decorations = decorations,
            _regions = opts.regions,
            _tint = opts.tint and color(opts.tint) or nil,
        },
        children = opts.children or {}
    }
end

------------------------------------------------------------
-- SPRITE BUTTON
-- Button with different sprites for each state
------------------------------------------------------------

---@class SpriteButtonStates
---@field normal string Sprite for default state
---@field hover string Sprite for mouse hover state
---@field pressed string Sprite for pressed/active state
---@field disabled string Sprite for disabled state

---@class SpriteButtonOpts
---@field sprite? string Base sprite name (auto-generates state variants: sprite_normal.png, sprite_hover.png, etc.)
---@field states? SpriteButtonStates Explicit sprite filenames for each state
---@field borders? number[]|{left:number,top:number,right:number,bottom:number} Nine-patch border sizes (default: { 4, 4, 4, 4 })
---@field label? string Button text label
---@field text? string Alias for label
---@field children? table[] Child elements (used if no label)
---@field onClick? function Callback when button is clicked
---@field disabled? boolean Disable button interaction (default: false)
---@field textColor? string|Color Label text color (default: "white")
---@field fontSize? number Label font size in pixels (default: 16)
---@field shadow? boolean Enable text shadow (default: true)
---@field padding? number Inner padding in pixels (default: 4)
---@field align? number AlignmentFlag bitmask for content alignment
---@field minWidth? number Minimum button width in pixels
---@field minHeight? number Minimum button height in pixels
---@field id? string Unique identifier for lookups

--- Create a button with different sprites for each interaction state.
--- Automatically swaps sprites based on hover/press/disabled state.
---
--- **State sprite conventions:**
--- When providing `sprite = "mybutton"`, the system looks for:
--- - `mybutton_normal.png` - Default state
--- - `mybutton_hover.png` - Mouse hover
--- - `mybutton_pressed.png` - Click/active
--- - `mybutton_disabled.png` - Disabled
---
--- **Example:**
--- ```lua
--- -- Auto-discovered states from base name
--- dsl.spriteButton({
---     sprite = "wooden_button",  -- Uses wooden_button_normal.png, etc.
---     label = "Click Me",
---     onClick = function() print("Clicked!") end
--- })
---
--- -- Explicit state sprites
--- dsl.spriteButton({
---     states = {
---         normal = "btn-blue.png",
---         hover = "btn-blue-lit.png",
---         pressed = "btn-blue-dark.png",
---         disabled = "btn-gray.png"
---     },
---     label = "Submit",
---     onClick = submitForm
--- })
---
--- -- Custom children instead of label
--- dsl.spriteButton({
---     sprite = "icon_button",
---     children = { dsl.anim("star.png", { w = 24, h = 24 }) },
---     onClick = toggleFavorite
--- })
--- ```
---@param opts SpriteButtonOpts Configuration options
---@return table UIDefinition node for the sprite button
function dsl.spriteButton(opts)
    opts = opts or {}
    local buttonId = opts.id or ("sprite_btn_" .. tostring(math.random(100000, 999999)))
    
    local borders = opts.borders or { 4, 4, 4, 4 }
    if type(borders) == "table" and #borders == 4 then
        borders = { left = borders[1], top = borders[2], right = borders[3], bottom = borders[4] }
    end
    
    local states = opts.states
    local baseSprite = nil
    
    if not states and opts.sprite then
        baseSprite = opts.sprite
        states = {
            normal = opts.sprite .. "_normal.png",
            hover = opts.sprite .. "_hover.png",
            pressed = opts.sprite .. "_pressed.png",
            disabled = opts.sprite .. "_disabled.png"
        }
    end
    
    local textNode = nil
    if opts.label or opts.text then
        textNode = dsl.text(opts.label or opts.text, {
            fontSize = opts.fontSize or 16,
            color = opts.textColor or "white",
            shadow = opts.shadow ~= false
        })
    end
    
    return def{
        type = "HORIZONTAL_CONTAINER",
        config = {
            id = buttonId,
            minWidth = opts.minWidth,
            minHeight = opts.minHeight,
            padding = opts.padding or 4,
            hover = true,
            canCollide = true,
            buttonCallback = opts.onClick,
            disableButton = opts.disabled,
            align = opts.align or bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
            _isSpriteButton = true,
            _states = states,
            _baseSprite = baseSprite,
            _borders = borders,
            _currentState = "normal",
        },
        children = textNode and { textNode } or (opts.children or {})
    }
end

------------------------------------------------------------
-- STRICT VALIDATION API
-- Usage: dsl.strict.vbox, dsl.strict.text, etc.
-- Validates props before delegating to regular DSL functions.
------------------------------------------------------------

local Schema = require("core.schema")

-- Helper: Get caller file location for error messages
local function getCallerLocation(level)
    level = level or 3  -- Caller of the strict function
    local info = debug.getinfo(level, "Sl")
    if info then
        local source = info.source or "?"
        -- Clean up source path (remove @, show just filename)
        if source:sub(1, 1) == "@" then
            source = source:sub(2)
        end
        return string.format("%s:%d", source, info.currentline or 0)
    end
    return "unknown:0"
end

-- Helper: Format validation errors with file location
local function formatValidationError(componentName, errors, warnings, location)
    local parts = {}
    table.insert(parts, string.format("[dsl.strict.%s] Validation failed at %s:", componentName, location))

    for _, err in ipairs(errors) do
        table.insert(parts, "  ERROR: " .. err)
    end

    for _, warn in ipairs(warnings) do
        table.insert(parts, "  WARNING: " .. warn)
    end

    return table.concat(parts, "\n")
end

-- Create strict namespace
dsl.strict = {}

-- Map DSL functions to their schemas
local STRICT_MAPPINGS = {
    -- Containers
    { name = "root",     fn = dsl.root,         schema = Schema.UI_ROOT,         positional = {} },
    { name = "vbox",     fn = dsl.vbox,         schema = Schema.UI_VBOX,         positional = {} },
    { name = "hbox",     fn = dsl.hbox,         schema = Schema.UI_HBOX,         positional = {} },
    { name = "section",  fn = dsl.section,      schema = Schema.UI_SECTION,      positional = { "title" } },
    { name = "grid",     fn = dsl.grid,         schema = Schema.UI_GRID,         positional = { "rows", "cols", "gen" } },

    -- Primitives
    { name = "text",     fn = dsl.text,         schema = Schema.UI_TEXT,         positional = { "text" } },
    { name = "richText", fn = dsl.richText,     schema = Schema.UI_RICH_TEXT,    positional = { "text" } },
    { name = "dynamicText", fn = dsl.dynamicText, schema = Schema.UI_DYNAMIC_TEXT, positional = { "fn", "fontSize", "effect" } },
    { name = "anim",     fn = dsl.anim,         schema = Schema.UI_ANIM,         positional = { "id" } },
    { name = "spacer",   fn = dsl.spacer,       schema = Schema.UI_SPACER,       positional = { "w", "h" } },
    { name = "divider",  fn = dsl.divider,      schema = Schema.UI_DIVIDER,      positional = { "direction" } },
    { name = "iconLabel", fn = dsl.iconLabel,   schema = Schema.UI_ICON_LABEL,   positional = { "iconId", "label" } },

    -- Interactive
    { name = "button",   fn = dsl.button,       schema = Schema.UI_BUTTON,       positional = { "label" } },
    { name = "spriteButton", fn = dsl.spriteButton, schema = Schema.UI_SPRITE_BUTTON, positional = {} },
    { name = "progressBar", fn = dsl.progressBar, schema = Schema.UI_PROGRESS_BAR, positional = {} },

    -- Panels
    { name = "spritePanel", fn = dsl.spritePanel, schema = Schema.UI_SPRITE_PANEL, positional = {} },
    { name = "spriteBox", fn = dsl.spriteBox,   schema = Schema.UI_SPRITE_BOX,   positional = {} },
    { name = "customPanel", fn = dsl.customPanel, schema = Schema.UI_CUSTOM_PANEL, positional = {} },

    -- Complex
    { name = "tabs",     fn = dsl.tabs,         schema = Schema.UI_TABS,         positional = {} },
    { name = "inventoryGrid", fn = dsl.inventoryGrid, schema = Schema.UI_INVENTORY_GRID, positional = {} },
}

-- Create strict wrapper for each DSL function
for _, mapping in ipairs(STRICT_MAPPINGS) do
    local name = mapping.name
    local originalFn = mapping.fn
    local schema = mapping.schema
    local positional = mapping.positional

    dsl.strict[name] = function(...)
        local args = { ... }
        local opts = {}

        -- Handle positional arguments by mapping them to opts
        if #positional > 0 then
            for i, argName in ipairs(positional) do
                if args[i] ~= nil then
                    opts[argName] = args[i]
                end
            end
            -- Last arg might be an opts table
            local lastArg = args[#positional + 1]
            if type(lastArg) == "table" then
                for k, v in pairs(lastArg) do
                    opts[k] = v
                end
            end
        else
            -- Functions that take a single table argument
            if type(args[1]) == "table" then
                opts = args[1]
            end
        end

        -- Validate against schema
        local ok, errors, warnings = Schema.check(opts, schema)

        -- Get caller location
        local location = getCallerLocation(3)

        -- Always log warnings
        if warnings and #warnings > 0 then
            local warnMsg = formatValidationError(name, {}, warnings, location)
            if rawget(_G, "log_warn") then
                log_warn(warnMsg)
            else
                print("WARN: " .. warnMsg)
            end
        end

        -- Throw on errors
        if not ok then
            local errMsg = formatValidationError(name, errors, warnings or {}, location)
            error(errMsg, 2)
        end

        -- Delegate to original function
        return originalFn(...)
    end
end

------------------------------------------------------------
-- Return DSL module
------------------------------------------------------------
return dsl
