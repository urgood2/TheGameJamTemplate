--[[
================================================================================
TOOLTIP V2 SYSTEM - 3-Box Vertical Stack Design
================================================================================
Complete replacement of the existing tooltip system with new 3-box architecture.

STRUCTURE:
    ┌─────────────────────────┐
    │       CARD NAME         │  ← Box 1: Name (title only, larger font + pop entrance)
    └─────────────────────────┘
               4px gap
    ┌─────────────────────────┐
    │   Effect description    │  ← Box 2: Description (supports [text](color) markup)
    │   text goes here...     │
    └─────────────────────────┘
               4px gap
    ┌─────────────────────────┐
    │ Damage: 25    Mana: 12  │  ← Box 3: Info (stats grid + tag pills)
    │ [Fire] [Projectile]     │
    └─────────────────────────┘

USAGE:
    local TooltipV2 = require("ui.tooltip_v2")
    
    -- Show tooltip for any entity
    TooltipV2.show(anchorEntity, {
        name = "Fireball",
        nameEffects = "pop=0.2,0.04,in;rainbow=40,8,0",  -- Optional: C++ text effects
        description = "Deal [25](color=red) fire damage to target enemy",
        info = {
            stats = {
                { label = "Damage", value = 25 },
                { label = "Mana", value = 12 },
            },
            tags = { "Fire", "Projectile", "AoE" }
        }
    })
    
    -- Hide tooltip
    TooltipV2.hide(anchorEntity)
    
    -- Card-specific helper (auto-applies rarity-based effects)
    TooltipV2.showCard(anchorEntity, cardDef)

POSITIONING:
    Priority order: RIGHT → LEFT → ABOVE → BELOW
    - Never covers anchor entity
    - Top-aligns with anchor, shifts down if clipping
    - 12px minimum edge gap

================================================================================
]]

local dsl = require("ui.ui_syntax_sugar")
local component_cache = require("core.component_cache")
local z_orders = require("core.z_orders")
local entity_cache = require("core.entity_cache")
local Q = require("core.Q")
local ui_scale = require("ui.ui_scale")

-- Safe require for optional dependencies
local CardsData = nil
local CardRarityTags = nil
pcall(function() CardsData = require("data.cards") end)
pcall(function() CardRarityTags = require("data.card_rarity_tags") end)

--------------------------------------------------------------------------------
-- STYLE CONFIGURATION
--------------------------------------------------------------------------------
local Style = {
    -- Fixed dimensions (per spec)
    BOX_WIDTH = ui_scale.ui(280),            -- Fixed width for all 3 boxes
    BOX_GAP = ui_scale.ui(4),                -- Gap between boxes
    EDGE_GAP = ui_scale.ui(12),              -- Minimum screen edge margin
    ANCHOR_GAP = 0,             -- Gap between tooltip and anchor entity (0 = flush)
    OUTLINE_THICKNESS = ui_scale.ui(2),      -- Outline thickness for all boxes
    
    -- Box padding
    namePadding = ui_scale.ui(6),
    descPadding = ui_scale.ui(8),
    infoPadding = ui_scale.ui(6),
    
    -- Font sizes (standardized for visual consistency)
    nameFontSize = ui_scale.ui(16),          -- Title - larger but not too large
    descFontSize = ui_scale.ui(12),          -- Description text
    statLabelFontSize = ui_scale.ui(11),     -- Stat labels
    statValueFontSize = ui_scale.ui(12),     -- Stat values (same as desc for consistency)
    tagFontSize = ui_scale.ui(10),           -- Tag pills (slightly smaller)
    
    -- Colors (matched from existing tooltipStyle in gameplay.lua)
    bgColor = nil,              -- Will be set from util.getColor or fallback
    innerColor = nil,
    outlineColor = nil,
    nameColor = "apricot_cream",
    descColor = "white",
    labelColor = "apricot_cream",
    valueColor = "white",
    
    -- Tag colors (reused from existing system)
    tagColors = {
        -- Elements
        Fire = "orange",
        Ice = "cyan",
        Lightning = "yellow",
        Poison = "green",
        Arcane = "purple",
        Holy = "gold",
        Void = "dark_purple",
        
        -- Mechanics
        Projectile = "blue",
        AoE = "red",
        Hazard = "brown",
        Summon = "teal",
        Buff = "lime",
        Debuff = "maroon",
        
        -- Playstyle
        Mobility = "orange",
        Defense = "green",
        Brute = "red",
    },
    
    -- Default tag color
    defaultTagColor = "dim_gray",
    
    -- Text effects (for name box - entrance + subtle continuous animation)
    -- All card names get a gentle highlight sweep effect for visual polish
    nameEntranceEffect = "pop=0.2,0.04,in;highlight=4,0.2,0.25,right",
    
    -- Available C++ text effects (for reference when using dynamic effects)
    -- Each effect can take parameters via effect=arg1,arg2,... syntax
    -- Multiple effects can be combined with semicolons: "effect1;effect2=args"
    AVAILABLE_EFFECTS = {
        -- Entrance/Exit effects (one-time animations)
        "pop",        -- pop=duration,stagger,mode(in/out) - Scale pop in/out
        "slide",      -- slide=duration,stagger,mode(in/out),dir(l/r/t/b) - Slide from direction
        "bounce",     -- bounce=gravity,height,duration,stagger - Drop with bounce
        "scramble",   -- scramble=duration,stagger,rate - Random character scramble before reveal
        
        -- Continuous effects (animated loops)
        "shake",      -- shake=x,y - Shake offset per character
        "pulse",      -- pulse=min,max,speed,stagger - Scale pulsing
        "float",      -- float=speed,amplitude,stagger - Vertical floating
        "bump",       -- bump=speed,amplitude,threshold,stagger - Jump/bump effect
        "wiggle",     -- wiggle=speed,angle,stagger - Rotation wiggle
        "rotate",     -- rotate=speed,angle - Continuous rotation
        "spin",       -- spin=speed,stagger - Full 360 spin
        "fade",       -- fade=speed,minAlpha,maxAlpha,stagger - Alpha pulsing
        "rainbow",    -- rainbow=speed,stagger,thresholdStep - Hue cycling
        "highlight",  -- highlight=speed,brightness,stagger,dir,mode - Color highlight wave
        "expand",     -- expand=min,max,speed,stagger,axis(x/y/both) - Scale on axis
        
        -- Static effects
        "color",      -- color=colorName - Set text color
        "fan",        -- fan=maxAngle - Fan characters out from center
    },
    
    -- Font name (uses named font from fonts.json if available)
    fontName = "tooltip",
    
    -- Minimum box heights when empty
    minNameHeight = ui_scale.ui(24),
    minDescHeight = ui_scale.ui(20),
    minInfoHeight = ui_scale.ui(20),
}

-- Initialize colors from util (or use fallback)
local function initColors()
    if util and util.getColor then
        Style.bgColor = Col(18, 22, 32, 255)          -- Dark background
        Style.innerColor = Col(28, 32, 44, 255)       -- Slightly lighter
        Style.outlineColor = util.getColor("apricot_cream") or Col(255, 214, 170, 255)
    else
        Style.bgColor = Col(18, 22, 32, 255)
        Style.innerColor = Col(28, 32, 44, 255)
        Style.outlineColor = Col(255, 214, 170, 255)
    end
end

--------------------------------------------------------------------------------
-- STATE MANAGEMENT
--------------------------------------------------------------------------------
local State = {
    -- Active tooltips: anchorEntity → { nameBox, descBox, infoBox }
    active = {},
    
    -- Cache: cacheKey → { boxes = {...}, version = N }
    cache = {},
    
    -- Version for cache invalidation (increment on language change, font reload)
    version = 1,
}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

-- Safely destroy an entity (guards against nil, missing registry, invalid entity)
local function safe_destroy(entity)
    if entity and registry and registry:valid(entity) then
        registry:destroy(entity)
        return true
    end
    return false
end

-- Get color safely
local function getColor(name)
    if type(name) == "string" then
        return (util and util.getColor and util.getColor(name)) or name
    end
    return name
end

-- Localization helper with fallback
local function L(key, fallback)
    if localization and localization.get then
        local result = localization.get(key)
        if result and result ~= key then return result end
    end
    return fallback
end

-- Check if font is available
local function hasFont(fontName)
    return localization and localization.hasNamedFont and localization.hasNamedFont(fontName)
end

-- Get font name or nil for fallback
local function getFontName()
    if hasFont(Style.fontName) then
        return Style.fontName
    end
    return nil
end

-- Simple string hash for long descriptions (prevents truncation collisions)
local function hashString(str)
    local hash = 0
    for i = 1, #str do
        hash = (hash * 31 + str:byte(i)) % 2147483647
    end
    return hash
end

-- Generate cache key from tooltip data
local function generateCacheKey(data)
    local parts = { "tooltipV2" }

    if data.name then
        table.insert(parts, tostring(data.name))
    end

    if data.nameEffects then
        table.insert(parts, "fx=" .. tostring(data.nameEffects))
    end

    if data.nameColor then
        table.insert(parts, "nc=" .. tostring(data.nameColor))
    end

    -- Use hash for long descriptions to prevent collision from truncation
    if data.description then
        local desc = tostring(data.description)
        if #desc > 50 then
            table.insert(parts, "desc_h=" .. tostring(hashString(desc)))
        else
            table.insert(parts, desc)
        end
    end

    if data.info then
        if data.info.stats then
            for _, s in ipairs(data.info.stats) do
                table.insert(parts, tostring(s.label) .. "=" .. tostring(s.value))
            end
        end
        if data.info.tags then
            table.insert(parts, table.concat(data.info.tags, ","))
        end
    end

    if data.status then
        table.insert(parts, "status=" .. tostring(data.status))
    end

    return table.concat(parts, "|")
end

-- Snap tooltip visual position to prevent size animation from 0
local function snapBoxVisual(boxId)
    if not boxId then return end
    
    ui.box.RenewAlignment(registry, boxId)
    
    local t = component_cache.get(boxId, Transform)
    if t then
        t.visualX = t.actualX
        t.visualY = t.actualY
        t.visualW = t.actualW
        t.visualH = t.actualH
    end
end

--------------------------------------------------------------------------------
-- BOX BUILDERS
--------------------------------------------------------------------------------

local function buildNameBox(name, opts)
    opts = opts or {}

    local displayName = name or "???"
    local effects = opts.effects or Style.nameEntranceEffect
    local nameColor = opts.nameColor or Style.nameColor

    local textNode
    if effects and effects ~= "" and ui.definitions.getNewDynamicTextEntry then
        local dynamicText = "[" .. displayName .. "](color=" .. nameColor .. ")"
        -- getNewDynamicTextEntry expects a function that returns text, not a string directly
        textNode = ui.definitions.getNewDynamicTextEntry(
            function() return dynamicText end,
            Style.nameFontSize,
            effects
        )
    else
        local styledName = "[" .. displayName .. "](color=" .. nameColor .. ")"
        textNode = ui.definitions.getTextFromString(styledName, {
            fontSize = Style.nameFontSize,
            fontName = getFontName(),
            shadow = true,
        })
    end

    return dsl.strict.root {
        config = {
            color = Style.bgColor,
            minWidth = Style.BOX_WIDTH,
            maxWidth = Style.BOX_WIDTH,
            minHeight = Style.minNameHeight,
            padding = Style.namePadding,
            outlineThickness = Style.OUTLINE_THICKNESS,
            outlineColor = Style.outlineColor,
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
            shadow = true,
        },
        children = { textNode }
    }
end

-- Build Description Box (Box 2)
-- Contains: effect text with [text](color=X) markup support
local function buildDescriptionBox(description, opts)
    opts = opts or {}
    
    local children = {}
    
    -- Calculate text area width (box width minus padding on both sides)
    local textAreaWidth = Style.BOX_WIDTH - (Style.descPadding * 2)
    
    if description and description ~= "" then
        -- Use rich text for markup support
        local textNode = ui.definitions.getTextFromString(description, {
            fontSize = Style.descFontSize,
            fontName = getFontName(),
            color = getColor(Style.descColor),
            shadow = false,
        })
        
        -- Wrap text in a container with maxWidth to enable word wrapping
        local textWrapper = dsl.strict.vbox {
            config = {
                maxWidth = textAreaWidth,
                align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
            },
            children = { textNode }
        }
        table.insert(children, textWrapper)
    else
        -- Empty placeholder (spacer)
        table.insert(children, dsl.strict.spacer(textAreaWidth, Style.minDescHeight))
    end

    return dsl.strict.root {
        config = {
            color = Style.bgColor,
            minWidth = Style.BOX_WIDTH,
            maxWidth = Style.BOX_WIDTH,
            minHeight = Style.minDescHeight,
            padding = Style.descPadding,
            outlineThickness = Style.OUTLINE_THICKNESS,
            outlineColor = Style.outlineColor,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
            shadow = true,
        },
        children = children
    }
end

-- Build a single stat row (label: value)
local function buildStatRow(label, value)
    local labelNode = dsl.strict.text(tostring(label) .. ":", {
        fontSize = Style.statLabelFontSize,
        color = Style.labelColor,
        fontName = getFontName(),
        shadow = false,
    })

    local valueNode = dsl.strict.text(tostring(value), {
        fontSize = Style.statValueFontSize,
        color = Style.valueColor,
        fontName = getFontName(),
        shadow = false,
    })

    return dsl.strict.hbox {
        config = {
            padding = ui_scale.ui(2),
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
        },
        children = { labelNode, dsl.strict.spacer(ui_scale.ui(4)), valueNode }
    }
end

-- Build a tag pill
local function buildTagPill(tag)
    local tagColor = Style.tagColors[tag] or Style.defaultTagColor

    -- Calculate pill height based on font size + padding for proper centering
    local pillHeight = Style.tagFontSize + ui_scale.ui(6)  -- font size + vertical padding

    return dsl.strict.hbox {
        config = {
            color = getColor(tagColor),
            padding = ui_scale.ui(3),
            minHeight = pillHeight,
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
        },
        children = {
            dsl.strict.text(tostring(tag), {
                fontSize = Style.tagFontSize,
                color = "white",
                fontName = getFontName(),
                shadow = false,
                align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
            })
        }
    }
end

-- Build Info Box (Box 3)
-- Contains: stats grid + tag pills
local function buildInfoBox(info, opts)
    opts = opts or {}
    
    local children = {}
    
    -- Stats grid
    if info and info.stats and #info.stats > 0 then
        local statRows = {}
        for _, stat in ipairs(info.stats) do
            if stat.value and stat.value ~= 0 and stat.value ~= -1 then
                table.insert(statRows, buildStatRow(stat.label, stat.value))
            end
        end
        
        if #statRows > 0 then
            -- Wrap stats in a vbox
            table.insert(children, dsl.strict.vbox {
                config = {
                    padding = ui_scale.ui(2),
                    align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_TOP),
                },
                children = statRows
            })
        end
    end

    -- Tag pills
    if info and info.tags and #info.tags > 0 then
        local pillNodes = {}
        for _, tag in ipairs(info.tags) do
            table.insert(pillNodes, buildTagPill(tag))
            table.insert(pillNodes, dsl.strict.spacer(ui_scale.ui(4), ui_scale.ui(1)))  -- Small gap between pills
        end
            table.remove(pillNodes)

        table.insert(children, dsl.strict.hbox {
            config = {
                padding = ui_scale.ui(2),
                align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
            },
            children = pillNodes
        })
    end

    -- If no content, add spacer
    if #children == 0 then
        table.insert(children, dsl.strict.spacer(Style.BOX_WIDTH - Style.infoPadding * 2, Style.minInfoHeight))
    end

    return dsl.strict.root {
        config = {
            color = Style.bgColor,
            minWidth = Style.BOX_WIDTH,
            maxWidth = Style.BOX_WIDTH,
            minHeight = Style.minInfoHeight,
            padding = Style.infoPadding,
            outlineThickness = Style.OUTLINE_THICKNESS,
            outlineColor = Style.outlineColor,
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_TOP),
            shadow = true,
        },
        children = {
            dsl.strict.vbox {
                config = {
                    padding = ui_scale.ui(2),
                    align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_TOP),
                },
                children = children
            }
        }
    }
end

--------------------------------------------------------------------------------
-- SPAWN & POSITIONING
--------------------------------------------------------------------------------

-- Spawn all 3 boxes
local function spawnTooltipAssembly(nameDef, descDef, infoDef)
    local zOrder = z_orders.ui_tooltips or 900
    
    -- Spawn at offscreen position initially
    local offscreen = { x = -2000, y = -2000 }
    
    local nameBox = dsl.spawn(offscreen, nameDef, "ui", zOrder)
    local descBox = dsl.spawn(offscreen, descDef, "ui", zOrder)
    local infoBox = dsl.spawn(offscreen, infoDef, "ui", zOrder)
    
    -- Set draw layer for each
    if ui and ui.box and ui.box.set_draw_layer then
        ui.box.set_draw_layer(nameBox, "ui")
        ui.box.set_draw_layer(descBox, "ui")
        ui.box.set_draw_layer(infoBox, "ui")
    end
    
    -- Snap visuals
    snapBoxVisual(nameBox)
    snapBoxVisual(descBox)
    snapBoxVisual(infoBox)
    
    return { nameBox = nameBox, descBox = descBox, infoBox = infoBox }
end

-- Get box dimensions
local function getBoxSize(boxId)
    if not boxId then return 0, 0 end
    local t = component_cache.get(boxId, Transform)
    if not t then return 0, 0 end
    return t.actualW or 0, t.actualH or 0
end

-- Measure total height of tooltip stack
local function measureTooltipStack(boxes)
    local _, nameH = getBoxSize(boxes.nameBox)
    local _, descH = getBoxSize(boxes.descBox)
    local _, infoH = getBoxSize(boxes.infoBox)
    
    local totalHeight = nameH + Style.BOX_GAP + descH + Style.BOX_GAP + infoH
    return Style.BOX_WIDTH, totalHeight, nameH, descH, infoH
end

-- Check if two rectangles overlap
local function rectsOverlap(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and x1 + w1 > x2 and y1 < y2 + h2 and y1 + h1 > y2
end

-- Try positioning tooltip on a specific side
-- Returns { x, y, fits } where fits is true if tooltip doesn't overlap anchor or go offscreen
-- Now performs overlap check AFTER clamping to catch edge cases
local function tryPosition(totalW, totalH, anchorX, anchorY, anchorW, anchorH, side, screenW, screenH)
    local edgeGap = Style.EDGE_GAP      -- Screen edge margin
    local anchorGap = Style.ANCHOR_GAP  -- Gap between tooltip and anchor
    local tooltipX, tooltipY
    local fitsInitial = false

    if side == "right" then
        tooltipX = anchorX + anchorW + anchorGap
        -- Center tooltip vertically relative to anchor
        local anchorCenterY = anchorY + anchorH * 0.5
        tooltipY = anchorCenterY - totalH * 0.5

        -- Check if fits horizontally (before clamping)
        fitsInitial = tooltipX + totalW <= screenW - edgeGap

        -- Clamp vertically within screen bounds
        if tooltipY < edgeGap then
            tooltipY = edgeGap
        end
        if tooltipY + totalH > screenH - edgeGap then
            tooltipY = math.max(edgeGap, screenH - totalH - edgeGap)
        end

    elseif side == "left" then
        tooltipX = anchorX - totalW - anchorGap
        -- Center tooltip vertically relative to anchor
        local anchorCenterY = anchorY + anchorH * 0.5
        tooltipY = anchorCenterY - totalH * 0.5

        fitsInitial = tooltipX >= edgeGap

        -- Clamp vertically within screen bounds
        if tooltipY < edgeGap then tooltipY = edgeGap end
        if tooltipY + totalH > screenH - edgeGap then
            tooltipY = math.max(edgeGap, screenH - totalH - edgeGap)
        end

    elseif side == "above" then
        -- Center horizontally relative to anchor
        tooltipX = anchorX + anchorW * 0.5 - totalW * 0.5
        tooltipY = anchorY - totalH - anchorGap

        fitsInitial = tooltipY >= edgeGap

        -- Clamp horizontally within screen bounds
        if tooltipX < edgeGap then tooltipX = edgeGap end
        if tooltipX + totalW > screenW - edgeGap then
            tooltipX = math.max(edgeGap, screenW - totalW - edgeGap)
        end

    elseif side == "below" then
        -- Center horizontally relative to anchor
        tooltipX = anchorX + anchorW * 0.5 - totalW * 0.5
        tooltipY = anchorY + anchorH + anchorGap

        fitsInitial = tooltipY + totalH <= screenH - edgeGap

        -- Clamp horizontally within screen bounds
        if tooltipX < edgeGap then tooltipX = edgeGap end
        if tooltipX + totalW > screenW - edgeGap then
            tooltipX = math.max(edgeGap, screenW - totalW - edgeGap)
        end
    end

    -- CRITICAL: Check for overlap AFTER clamping
    -- This catches edge cases where clamping pushes tooltip back onto anchor
    local overlapsAnchor = rectsOverlap(
        tooltipX, tooltipY, totalW, totalH,
        anchorX, anchorY, anchorW, anchorH
    )

    local fits = fitsInitial and not overlapsAnchor

    return tooltipX, tooltipY, fits
end

-- Default anchor size when dimensions are missing or zero
-- Based on typical card sizes in the UI (see trigger_strip_ui, wand_cooldown_ui)
local DEFAULT_ANCHOR_W = ui_scale.ui(80)
local DEFAULT_ANCHOR_H = ui_scale.ui(112)

-- Convert world-space position to screen-space using camera
-- Returns screenX, screenY
local function worldToScreen(worldX, worldY, cam)
    if not cam then return worldX, worldY end

    local target = cam:GetVisualTarget()
    local offset = cam:GetVisualOffset()
    local zoom = cam:GetVisualZoom() or 1

    local screenX = (worldX - target.x) * zoom + offset.x
    local screenY = (worldY - target.y) * zoom + offset.y

    return screenX, screenY
end

-- Position tooltip relative to anchor entity
local function positionTooltipV2(boxes, anchorEntity)
    if not anchorEntity then return end

    -- Prefer visual bounds (accounts for animations) over actual bounds
    local anchorX, anchorY, anchorW, anchorH = Q.visualBounds(anchorEntity)

    -- Fallback to actual bounds if visual not available
    if not anchorX then
        anchorX, anchorY, anchorW, anchorH = Q.bounds(anchorEntity)
    end

    -- Final fallback if entity has no transform
    if not anchorX then return end

    -- Use sensible defaults for missing/zero dimensions
    -- (UI boxes sometimes have 0 size on first frame before layout)
    if not anchorW or anchorW <= 0 then anchorW = DEFAULT_ANCHOR_W end
    if not anchorH or anchorH <= 0 then anchorH = DEFAULT_ANCHOR_H end

    -- Get camera for coordinate conversion
    local cam = camera and camera.Get and camera.Get("world_camera")
    local zoom = (cam and cam.GetVisualZoom and cam:GetVisualZoom()) or 1

    -- Convert world-space anchor position to screen-space
    if cam then
        anchorX, anchorY = worldToScreen(anchorX, anchorY, cam)
        -- Scale dimensions by zoom (world units → screen pixels)
        anchorW = anchorW * zoom
        anchorH = anchorH * zoom
    end

    -- Get screen size
    local screenW = globals.screenWidth and globals.screenWidth() or 1920
    local screenH = globals.screenHeight and globals.screenHeight() or 1080
    
    -- Measure tooltip stack
    local totalW, totalH, nameH, descH, infoH = measureTooltipStack(boxes)
    
    -- Try positions in priority order: RIGHT → LEFT → ABOVE → BELOW
    local sides = { "right", "left", "above", "below" }
    local finalX, finalY
    
    for _, side in ipairs(sides) do
        local x, y, fits = tryPosition(totalW, totalH, anchorX, anchorY, anchorW, anchorH, side, screenW, screenH)
        if fits then
            finalX, finalY = x, y
            break
        end
        -- Keep last attempted position as fallback
        finalX, finalY = x, y
    end
    
    -- Safety clamp
    local gap = Style.EDGE_GAP
    finalX = math.max(gap, math.min(finalX, screenW - totalW - gap))
    finalY = math.max(gap, math.min(finalY, screenH - totalH - gap))
    
    -- Position each box in vertical stack
    local nameT = component_cache.get(boxes.nameBox, Transform)
    local descT = component_cache.get(boxes.descBox, Transform)
    local infoT = component_cache.get(boxes.infoBox, Transform)
    
    if nameT then
        nameT.actualX = finalX
        nameT.actualY = finalY
        nameT.visualX = finalX
        nameT.visualY = finalY
    end
    
    if descT then
        descT.actualX = finalX
        descT.actualY = finalY + nameH + Style.BOX_GAP
        descT.visualX = descT.actualX
        descT.visualY = descT.actualY
    end
    
    if infoT then
        infoT.actualX = finalX
        infoT.actualY = finalY + nameH + Style.BOX_GAP + descH + Style.BOX_GAP
        infoT.visualX = infoT.actualX
        infoT.visualY = infoT.actualY
    end
end

-- Add state tags to tooltip boxes
local function addStateTags(boxes)
    local states = { PLANNING_STATE, ACTION_STATE, SHOP_STATE, CARD_TOOLTIP_STATE }
    
    for _, boxId in pairs(boxes) do
        if boxId and entity_cache.valid(boxId) then
            if ui and ui.box and ui.box.ClearStateTagsFromUIBox then
                ui.box.ClearStateTagsFromUIBox(boxId)
            end
            for _, state in ipairs(states) do
                if state then
                    if ui and ui.box and ui.box.AddStateTagToUIBox then
                        ui.box.AddStateTagToUIBox(boxId, state)
                    end
                    if add_state_tag then
                        add_state_tag(boxId, state)
                    end
                end
            end
        end
    end
end

-- Clear state tags from tooltip boxes
local function clearStateTags(boxes)
    for _, boxId in pairs(boxes) do
        if boxId and entity_cache.valid(boxId) then
            if clear_state_tags then
                clear_state_tags(boxId)
            end
            if ui and ui.box and ui.box.ClearStateTagsFromUIBox then
                ui.box.ClearStateTagsFromUIBox(boxId)
            end
        end
    end
end

-- Move boxes offscreen (for hiding while keeping cached)
local function moveOffscreen(boxes)
    for _, boxId in pairs(boxes) do
        if boxId and entity_cache.valid(boxId) then
            local t = component_cache.get(boxId, Transform)
            if t then
                t.actualX = -2000
                t.actualY = -2000
                t.visualX = -2000
                t.visualY = -2000
            end
        end
    end
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

local TooltipV2 = {}

--- Show tooltip for an entity
--- @param anchorEntity number Entity ID to anchor tooltip to
--- @param data table { name, description, info = { stats, tags } }
function TooltipV2.show(anchorEntity, data)
    if not anchorEntity then return nil end
    if not entity_cache.valid(anchorEntity) then return nil end
    
    -- Initialize colors on first use
    if not Style.bgColor then
        initColors()
    end
    
    data = data or {}
    
    -- Generate cache key
    local cacheKey = generateCacheKey(data)
    
    -- Check if already showing for this anchor
    local existing = State.active[anchorEntity]
    if existing then
        -- Just reposition
        positionTooltipV2(existing, anchorEntity)
        addStateTags(existing)
        return existing
    end
    
    -- Check cache
    local cached = State.cache[cacheKey]
    if cached and cached.version == State.version then
        -- Validate all boxes still exist
        local valid = true
        for _, boxId in pairs(cached.boxes) do
            if not entity_cache.valid(boxId) then
                valid = false
                break
            end
        end
        
        if valid then
            -- Reuse cached boxes
            State.active[anchorEntity] = cached.boxes
            positionTooltipV2(cached.boxes, anchorEntity)
            addStateTags(cached.boxes)
            return cached.boxes
        end
    end
    
    -- Build new tooltip
    local nameDef = buildNameBox(data.name, {
        effects = data.nameEffects,
        nameColor = data.nameColor,
    })
    local descDef = buildDescriptionBox(data.description)
    local infoDef = buildInfoBox(data.info)
    
    local boxes = spawnTooltipAssembly(nameDef, descDef, infoDef)
    
    -- Cache it
    State.cache[cacheKey] = {
        boxes = boxes,
        version = State.version,
    }
    
    -- Track as active
    State.active[anchorEntity] = boxes
    
    -- Position and show
    positionTooltipV2(boxes, anchorEntity)
    addStateTags(boxes)
    
    return boxes
end

--- Hide tooltip for an entity
--- @param anchorEntity number Entity ID
function TooltipV2.hide(anchorEntity)
    if not anchorEntity then return end
    
    local boxes = State.active[anchorEntity]
    if not boxes then return end
    
    -- Clear state tags and move offscreen
    clearStateTags(boxes)
    moveOffscreen(boxes)
    State.active[anchorEntity] = nil
end

--- Show card tooltip (builds data from card definition)
--- @param anchorEntity number Entity ID to anchor tooltip to
--- @param cardDef table Card definition from cards.lua
--- @param opts table? Optional { status, statusColor, nameEffects }
function TooltipV2.showCard(anchorEntity, cardDef, opts)
    if not anchorEntity or not cardDef then return nil end
    
    opts = opts or {}
    local cardId = cardDef.id or cardDef.cardID or "unknown"
    
    local name = L("card.name." .. cardId, cardId)
    
    -- Build description with status prefix if disabled
    local description = cardDef.description or ""
    if opts.status then
        local statusColor = opts.statusColor or "red"
        description = "[" .. tostring(opts.status):upper() .. "](color=" .. statusColor .. ")\n" .. description
    end
    
    -- Build stats list
    local stats = {}
    
    local function addStat(label, value, locKey)
        if value and value ~= 0 and value ~= -1 and value ~= "N/A" then
            local localizedLabel = L("card.label." .. locKey, label)
            table.insert(stats, { label = localizedLabel, value = value })
        end
    end
    
    addStat("Type", L("card.type." .. (cardDef.type or "action"), cardDef.type), "type")
    addStat("Damage", cardDef.damage, "damage")
    addStat("Mana", cardDef.mana_cost, "mana_cost")
    addStat("Lifetime", cardDef.lifetime, "lifetime")
    addStat("Cast Delay", cardDef.cast_delay, "cast_delay")
    addStat("Speed", cardDef.projectile_speed, "projectile_speed")
    addStat("Spread", cardDef.spread_angle, "spread_angle")
    addStat("Radius", cardDef.radius_of_effect, "radius_of_effect")
    addStat("Uses", cardDef.max_uses, "max_uses")
    
    -- Modifier-specific stats
    addStat("Damage Mod", cardDef.damage_modifier, "damage_modifier")
    addStat("Speed Mod", cardDef.speed_modifier, "speed_modifier")
    addStat("Spread Mod", cardDef.spread_modifier, "spread_modifier")
    addStat("Crit Mod", cardDef.critical_hit_chance_modifier, "crit_modifier")
    addStat("Multicast", cardDef.multicast_count, "multicast_count")
    
    -- Build tags list
    local tags = {}
    
    -- Get from card definition
    if cardDef.tags then
        for _, tag in ipairs(cardDef.tags) do
            table.insert(tags, tag)
        end
    end
    
    -- Get from CardRarityTags if available
    if CardRarityTags then
        local assignment = nil
        if CardRarityTags.cardAssignments then
            assignment = CardRarityTags.cardAssignments[cardId]
        end
        if not assignment and CardRarityTags.triggerAssignments then
            assignment = CardRarityTags.triggerAssignments[cardId]
        end
        
        if assignment then
            if assignment.rarity then
                -- Add rarity as first tag
                table.insert(tags, 1, L("card.rarity." .. assignment.rarity, assignment.rarity))
            end
            if assignment.tags then
                for _, tag in ipairs(assignment.tags) do
                    -- Avoid duplicates
                    local found = false
                    for _, existing in ipairs(tags) do
                        if existing == tag then found = true; break end
                    end
                    if not found then
                        table.insert(tags, tag)
                    end
                end
            end
        end
    end
    
    -- Get rarity-based effects and color for card name
    local nameEffects = opts.nameEffects
    local nameColor = opts.nameColor
    local cardRarity = nil

    if CardRarityTags then
        local assignment = CardRarityTags.cardAssignments and CardRarityTags.cardAssignments[cardId]
            or CardRarityTags.triggerAssignments and CardRarityTags.triggerAssignments[cardId]
        if assignment and assignment.rarity then
            cardRarity = assignment.rarity:lower()
        end
    end

    -- Apply rarity-based effects and color if not overridden
    if cardRarity then
        local TooltipEffects = nil
        pcall(function() TooltipEffects = require("core.tooltip_effects") end)
        if TooltipEffects then
            if not nameEffects and TooltipEffects.get then
                nameEffects = TooltipEffects.get(cardRarity)
            end
            if not nameColor and TooltipEffects.getColor then
                nameColor = TooltipEffects.getColor(cardRarity)
            end
        end
    end

    return TooltipV2.show(anchorEntity, {
        name = name,
        nameEffects = nameEffects,
        nameColor = nameColor,
        description = description,
        info = {
            stats = stats,
            tags = tags,
        },
        status = opts.status,
    })
end

--- Clear all tooltip cache and destroy all cached boxes
function TooltipV2.clearCache()
    -- Destroy all cached boxes
    for _, cached in pairs(State.cache) do
        if cached.boxes then
            for _, boxId in pairs(cached.boxes) do
                safe_destroy(boxId)
            end
        end
    end

    -- Clear active tooltips
    for anchorEntity, boxes in pairs(State.active) do
        for _, boxId in pairs(boxes) do
            safe_destroy(boxId)
        end
    end

    State.cache = {}
    State.active = {}
end

--- Invalidate cache (bump version, old entries will be rebuilt on next use)
function TooltipV2.invalidateCache()
    State.version = State.version + 1
end

--- Hide all active tooltips
function TooltipV2.hideAll()
    for anchorEntity, _ in pairs(State.active) do
        TooltipV2.hide(anchorEntity)
    end
end

--- Get currently active tooltip boxes for an entity
--- @param anchorEntity number Entity ID
--- @return table? boxes { nameBox, descBox, infoBox } or nil
function TooltipV2.getActive(anchorEntity)
    return State.active[anchorEntity]
end

--------------------------------------------------------------------------------
-- LEGACY API COMPATIBILITY
--------------------------------------------------------------------------------

-- These functions allow gradual migration from old tooltip system

--- Show tooltip V2 (alias for show)
TooltipV2.showTooltipV2 = TooltipV2.show

--- Hide tooltip V2 (alias for hide)
TooltipV2.hideTooltipV2 = TooltipV2.hide

--- Show card tooltip V2 (alias for showCard)
TooltipV2.showCardTooltipV2 = TooltipV2.showCard

--------------------------------------------------------------------------------
-- MODULE EXPORT
--------------------------------------------------------------------------------

return TooltipV2
