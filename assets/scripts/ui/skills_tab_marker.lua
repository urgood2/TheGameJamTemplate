--[[
================================================================================
SKILLS TAB MARKER - Persistent Tab for Skills Panel Toggle
================================================================================

A clickable tab marker that:
- Stays visible on the left edge when the skills panel is closed
- Moves to attach to the right edge of the panel when open
- Clicking toggles the skills panel

USAGE:
------
local SkillsTabMarker = require("ui.skills_tab_marker")

SkillsTabMarker.initialize()           -- Create the tab marker
SkillsTabMarker.updatePosition(isOpen, panelWidth)  -- Update position
SkillsTabMarker.destroy()              -- Cleanup

================================================================================
]]

local SkillsTabMarker = {}

--------------------------------------------------------------------------------
-- DEPENDENCIES
--------------------------------------------------------------------------------

local function safeRequire(module)
    local ok, result = pcall(require, module)
    return ok and result or nil
end

local ui_scale = safeRequire("ui.ui_scale")
local dsl = safeRequire("ui.ui_syntax_sugar")
local component_cache = _G.component_cache or { get = function() return nil end }

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------

local UI = ui_scale and ui_scale.ui or function(x) return x end

local CONFIG = {
    -- Using same dimensions as inventory tab marker for consistency
    sprite = "inventory-tab-marker",
    width = UI(48),
    height = UI(32),  -- Match inventory tab marker height
    edge_offset = UI(0),      -- Distance from left edge when closed
    panel_overlap = UI(0),    -- Flush with panel edge when open
}

--------------------------------------------------------------------------------
-- MODULE STATE
--------------------------------------------------------------------------------

local state = {
    initialized = false,
    markerEntity = nil,
    currentX = 0,
    currentY = 0,
}

--------------------------------------------------------------------------------
-- POSITION CALCULATION
--------------------------------------------------------------------------------

--- Get panel Y position (vertically centered)
--- @return number panelY, number panelHeight
local function getPanelYPosition()
    local screenHeight = GetScreenHeight and GetScreenHeight() or 1080
    -- Match skills_panel.lua calculatePositions() logic
    local ok, SkillsPanel = pcall(require, "ui.skills_panel")
    local panelHeight = 400  -- fallback
    if ok and SkillsPanel and SkillsPanel.getPanelDimensions then
        local w, h = SkillsPanel.getPanelDimensions()
        panelHeight = h or panelHeight
    end
    local panelY = (screenHeight - panelHeight) / 2
    return panelY, panelHeight
end

--- Get position when panel is closed (flush with left edge, only tab shows)
--- @return number x, number y
function SkillsTabMarker.getClosedPosition()
    local panelY, panelHeight = getPanelYPosition()
    -- Tab sits at left edge, vertically aligned with top of panel
    local x = CONFIG.edge_offset
    local y = panelY
    return x, y
end

--- Get position when panel is open (attached to panel right edge)
--- @param panelWidth number Width of the skills panel
--- @return number x, number y
function SkillsTabMarker.getOpenPosition(panelWidth)
    local panelY, panelHeight = getPanelYPosition()
    local panelX = UI(4)  -- Panel padding from left edge (matches skills_panel.lua)
    -- Tab attaches to right edge of panel
    local x = panelX + panelWidth - CONFIG.panel_overlap
    local y = panelY
    return x, y
end

--------------------------------------------------------------------------------
-- CONFIGURATION ACCESS
--------------------------------------------------------------------------------

--- Get tab marker configuration
--- @return table Configuration table
function SkillsTabMarker.getConfig()
    return CONFIG
end

--------------------------------------------------------------------------------
-- STATE QUERIES
--------------------------------------------------------------------------------

--- Check if tab marker is initialized
--- @return boolean
function SkillsTabMarker.isInitialized()
    return state.initialized
end

--------------------------------------------------------------------------------
-- VISIBILITY/POSITION UPDATES
--------------------------------------------------------------------------------

local function setMarkerPosition(x, y)
    if not state.markerEntity then return end
    if not _G.registry or not _G.registry.valid or not _G.registry:valid(state.markerEntity) then return end

    local t = component_cache.get(state.markerEntity, Transform)
    if t then
        t.actualX = x
        t.actualY = y
    end

    local role = component_cache.get(state.markerEntity, InheritedProperties)
    if role and role.offset then
        role.offset.x = x
        role.offset.y = y
    end

    state.currentX = x
    state.currentY = y
end

--- Update tab marker position based on panel state
--- @param isOpen boolean Whether the skills panel is open
--- @param panelWidth number Width of the skills panel (optional, defaults to 0)
function SkillsTabMarker.updatePosition(isOpen, panelWidth)
    local x, y
    if isOpen then
        x, y = SkillsTabMarker.getOpenPosition(panelWidth or 0)
    else
        x, y = SkillsTabMarker.getClosedPosition()
    end
    setMarkerPosition(x, y)
end

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

local MARKER_Z = 850  -- Above panel but below modals

local function createMarkerEntity()
    if not dsl or not _G.registry then
        -- Running in test mode
        return nil
    end

    -- Create tab marker definition
    local markerDef = dsl.strict.hbox {
        config = {
            id = "skills_tab_marker",
            canCollide = true,
            hover = true,
            padding = 0,
            minWidth = CONFIG.width,
            minHeight = CONFIG.height,
            buttonCallback = function()
                -- Toggle the skills panel
                local ok, SkillsPanel = pcall(require, "ui.skills_panel")
                if ok and SkillsPanel and SkillsPanel.toggle then
                    SkillsPanel.toggle()
                end
            end,
        },
        children = {
            dsl.strict.anim(CONFIG.sprite .. ".png", {
                w = CONFIG.width,
                h = CONFIG.height,
                shadow = false,
            }),
        },
    }

    -- Get initial position
    local x, y = SkillsTabMarker.getClosedPosition()

    -- Spawn the marker
    local markerEntity = dsl.spawn(
        { x = x, y = y },
        markerDef,
        "ui",
        MARKER_Z
    )

    if not markerEntity then
        print("[SkillsTabMarker] Failed to spawn marker entity")
        return nil
    end

    -- Set draw layer
    if _G.ui and _G.ui.box and _G.ui.box.set_draw_layer then
        _G.ui.box.set_draw_layer(markerEntity, "sprites")
    end

    -- Add state tags for rendering
    if _G.ui and _G.ui.box and _G.ui.box.AddStateTagToUIBox then
        _G.ui.box.AddStateTagToUIBox(_G.registry, markerEntity, "default_state")
    end

    return markerEntity
end

--- Initialize the tab marker
function SkillsTabMarker.initialize()
    if state.initialized then return end

    state.markerEntity = createMarkerEntity()

    -- Set initial position (closed state)
    local x, y = SkillsTabMarker.getClosedPosition()
    state.currentX = x
    state.currentY = y

    if state.markerEntity then
        setMarkerPosition(x, y)
    end

    state.initialized = true
end

--- Destroy the tab marker and cleanup
function SkillsTabMarker.destroy()
    if not state.initialized then return end

    if state.markerEntity and _G.registry and _G.registry.valid and _G.registry:valid(state.markerEntity) then
        -- Use ui.box.Remove for proper UIBox cleanup (per UI Panel Implementation Guide)
        if _G.ui and _G.ui.box and _G.ui.box.Remove then
            _G.ui.box.Remove(_G.registry, state.markerEntity)
        else
            _G.registry:destroy(state.markerEntity)
        end
    end

    state.initialized = false
    state.markerEntity = nil
    state.currentX = 0
    state.currentY = 0
end

--- Reset module state (for testing)
function SkillsTabMarker._reset()
    SkillsTabMarker.destroy()
end

return SkillsTabMarker
