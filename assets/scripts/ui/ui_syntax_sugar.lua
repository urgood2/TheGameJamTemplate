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

-- Cache a transparent color at module load time (used by dsl.spacer)
-- CRITICAL: Must use Color.new() to create proper userdata, not Lua table
local TRANSPARENT_COLOR = Color and Color.new and Color.new(0, 0, 0, 0) or nil

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
-- Example:
-- dsl.spacer(20)  -- 20px vertical spacer
-- dsl.spacer(20, 40)  -- 20w x 40h spacer
------------------------------------------------------------
function dsl.spacer(w, h)
    return def{
        type = "RECT_SHAPE",
        config = {
            color    = TRANSPARENT_COLOR, -- Cached at module load, nil triggers skip in ui_definition_helper
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
-- TAB SYSTEM
-- Stores tab definitions in Lua closures, no C++ tab components needed
------------------------------------------------------------

--- Module-level storage for tab definitions
--- Key: container ID (string), Value: { tabs = {...}, activeId = "..." }
local _tabRegistry = {}

--- Create a tabbed UI container
--- @param opts table Configuration options
--- @param opts.id string Unique container ID (auto-generated if nil)
--- @param opts.tabs table Array of {id, label, content} tab definitions
--- @param opts.activeTab string ID of initially active tab (defaults to first)
--- @param opts.tabBarPadding number Padding in tab bar (default 2)
--- @param opts.contentPadding number Padding in content area (default 6)
--- @param opts.buttonColor string Tab button color (default "gray")
--- @param opts.activeButtonColor string Active tab button color (default "blue")
--- @param opts.contentColor string Content area background color
--- @param opts.contentMinWidth number Minimum content area width
--- @param opts.contentMinHeight number Minimum content area height
--- @return table UI definition node
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

--- Switch to a different tab
--- @param containerId string The tab container's ID
--- @param newTabId string The ID of the tab to switch to
--- @return boolean true if switch succeeded
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

--- Get the currently active tab ID
--- @param containerId string The tab container's ID
--- @return string|nil Active tab ID, or nil if container not found
function dsl.getActiveTab(containerId)
    local tabData = _tabRegistry[containerId]
    return tabData and tabData.activeId or nil
end

--- Clean up tab registry entry (call when destroying tab container)
--- @param containerId string The tab container's ID
function dsl.cleanupTabs(containerId)
    _tabRegistry[containerId] = nil
end

--- Get all registered tab IDs for a container
--- @param containerId string The tab container's ID
--- @return table|nil Array of tab IDs, or nil if container not found
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
            -- Convert gridConfig.slotColor string to actual color, fall back to gray
            local defaultSlotColor = gridConfig.slotColor and color(gridConfig.slotColor) or color("gray")
            local slotColor = slotConfig.color or defaultSlotColor
            
            local slotNode = def{
                type = "HORIZONTAL_CONTAINER",
                config = {
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
                },
                children = {}
            }
            
            table.insert(rowChildren, slotNode)
            if c < cols then
                table.insert(rowChildren, dsl.spacer(spacing, slotH))
            end
        end
        
        local rowNode = def{
            type = "HORIZONTAL_CONTAINER",
            config = { align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER) },
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
            padding = gridConfig.padding or 4,
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

function dsl.getGridConfig(gridId)
    return _gridRegistry[gridId]
end

function dsl.cleanupGrid(gridId)
    _gridRegistry[gridId] = nil
end

------------------------------------------------------------
-- CUSTOM PANEL
-- Custom-rendered UI element that participates in layout
------------------------------------------------------------

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
-- Return DSL module
------------------------------------------------------------
return dsl
