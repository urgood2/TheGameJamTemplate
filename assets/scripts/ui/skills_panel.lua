--[[
================================================================================
SKILLS PANEL - Left-Aligned Skills Selection Panel
================================================================================

A slide-out panel on the left edge of the screen displaying all available
skills organized by element (Fire, Ice, Lightning, Void).

USAGE:
------
local SkillsPanel = require("ui.skills_panel")

SkillsPanel.open()           -- Show panel
SkillsPanel.close()          -- Hide panel
SkillsPanel.toggle()         -- Toggle visibility
SkillsPanel.isOpen()         -- Check if visible

EVENTS (via hump.signal):
-------------------------
"skills_panel_opened"        -- Panel opened
"skills_panel_closed"        -- Panel closed
"skill_button_clicked"       -- Skill button clicked (for modal)

================================================================================
]]

local SkillsPanel = {}

--------------------------------------------------------------------------------
-- DEPENDENCIES (safe requires for unit testing)
--------------------------------------------------------------------------------

local function safeRequire(module)
    local ok, result = pcall(require, module)
    return ok and result or nil
end

local Skills = safeRequire("data.skills")
local SkillSystem = safeRequire("core.skill_system")
local signal = safeRequire("external.hump.signal")
local timer = safeRequire("core.timer")
local ui_scale = safeRequire("ui.ui_scale")
local z_orders = safeRequire("core.z_orders")
local dsl = safeRequire("ui.ui_syntax_sugar")
local component_cache = _G.component_cache or { get = function() return nil end }

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------

local CONFIG = {
    -- Element columns
    columns = 4,
    rows = 8,

    -- Unlocked/locked elements for demo
    unlocked_elements = { "fire", "ice", "lightning" },
    locked_elements = { "void" },

    -- Element column order
    element_order = { "fire", "ice", "lightning", "void" },

    -- Sprites
    locked_sprite = "skill-locked",
    learned_overlay = "skill-checkmark",
    panel_background = "skills-panel-background",

    -- Hotkey
    toggle_key = "K",
}

-- Build locked lookup table
local LOCKED_ELEMENTS = {}
for _, elem in ipairs(CONFIG.locked_elements) do
    LOCKED_ELEMENTS[elem] = true
end

--------------------------------------------------------------------------------
-- UI DIMENSIONS
--------------------------------------------------------------------------------

local UI = ui_scale and ui_scale.ui or function(x) return x end
local SPRITE_SCALE = ui_scale and ui_scale.SPRITE_SCALE or 1

local SLOT_BASE_SIZE = 48
local SLOT_SIZE = UI(SLOT_BASE_SIZE)
local SLOT_SPACING = UI(4)
local GRID_PADDING = UI(8)
local HEADER_HEIGHT = UI(40)
local PANEL_PADDING = UI(12)

-- Grid dimensions (4 columns × 8 rows)
local GRID_WIDTH = CONFIG.columns * SLOT_SIZE + (CONFIG.columns - 1) * SLOT_SPACING + GRID_PADDING * 2
local GRID_HEIGHT = CONFIG.rows * SLOT_SIZE + (CONFIG.rows - 1) * SLOT_SPACING + GRID_PADDING * 2

-- Panel dimensions
local PANEL_WIDTH = GRID_WIDTH + PANEL_PADDING * 2
local PANEL_HEIGHT = HEADER_HEIGHT + GRID_HEIGHT + PANEL_PADDING * 2

local RENDER_LAYER = "ui"
local PANEL_Z = 800
local TIMER_GROUP = "skills_panel"

--------------------------------------------------------------------------------
-- MODULE STATE
--------------------------------------------------------------------------------

local state = {
    initialized = false,
    isVisible = false,
    panelEntity = nil,
    gridEntity = nil,
    skillButtons = {},       -- skillId -> buttonEntity
    headerTextEntity = nil,
    panelX = 0,
    panelY = 0,
    player = nil,            -- Reference to player for skill point queries
}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

local function getLocalizedText(key, fallback)
    if localization and localization.get then
        local text = localization.get(key)
        if text and text ~= key then
            return text
        end
    end
    return fallback or key
end

local function isElementLocked(element)
    return LOCKED_ELEMENTS[element] == true
end

--------------------------------------------------------------------------------
-- SKILL BUTTON STATE
--------------------------------------------------------------------------------

--- Determine the visual state of a skill button
--- @param player table Player object with skill_points and skill_state
--- @param skillId string Skill ID
--- @return string "locked", "learned", "available", or "insufficient"
function SkillsPanel.getSkillButtonState(player, skillId)
    if not Skills or not SkillSystem then return "locked" end

    local skill = Skills.get(skillId)
    if not skill then return "locked" end

    -- Check if element is locked for demo
    if isElementLocked(skill.element) then
        return "locked"
    end

    -- Check if already learned
    if SkillSystem.has_skill(player, skillId) then
        return "learned"
    end

    -- Check if can afford
    if SkillSystem.can_learn_skill(player, skillId) then
        return "available"
    end

    return "insufficient"
end

--------------------------------------------------------------------------------
-- GRID DATA
--------------------------------------------------------------------------------

--- Get skills organized by element for the grid
--- @return table { fire = {...}, ice = {...}, lightning = {...}, void = {...} }
function SkillsPanel.getGridData()
    if not Skills then return {} end

    local gridData = {}
    for _, element in ipairs(CONFIG.element_order) do
        gridData[element] = Skills.getOrderedByElement(element)
    end
    return gridData
end

--------------------------------------------------------------------------------
-- SKILL POINTS DISPLAY
--------------------------------------------------------------------------------

--- Get formatted skill points display string
--- @param player table Player object
--- @return string "Skill Points: X/Y"
function SkillsPanel.getSkillPointsDisplay(player)
    if not SkillSystem then return "Skill Points: 0/0" end

    local remaining = SkillSystem.get_skill_points_remaining(player)
    local total = player and player.skill_points or 0

    return string.format("Skill Points: %d/%d", remaining, total)
end

--------------------------------------------------------------------------------
-- CONFIGURATION ACCESS
--------------------------------------------------------------------------------

--- Get panel configuration
--- @return table Configuration table
function SkillsPanel.getConfig()
    return CONFIG
end

--- Get panel dimensions for tab marker positioning
--- @return number width Panel width in pixels
--- @return number height Panel height in pixels
function SkillsPanel.getPanelDimensions()
    return PANEL_WIDTH, PANEL_HEIGHT
end

--------------------------------------------------------------------------------
-- POSITION CALCULATION
--------------------------------------------------------------------------------

local function calculatePositions()
    local screenWidth = GetScreenWidth and GetScreenWidth() or 1920
    local screenHeight = GetScreenHeight and GetScreenHeight() or 1080

    -- Panel on left edge, vertically centered
    state.panelX = PANEL_PADDING
    state.panelY = (screenHeight - PANEL_HEIGHT) / 2

    return true
end

--------------------------------------------------------------------------------
-- VISIBILITY CONTROL
--------------------------------------------------------------------------------

local function setEntityVisible(entity, visible, onscreenX, onscreenY)
    if not entity then return end
    if not _G.registry or not _G.registry.valid or not _G.registry:valid(entity) then return end

    local targetX = onscreenX
    local targetY = visible and onscreenY or (GetScreenHeight and GetScreenHeight() or 2000)

    -- Update Transform
    local t = component_cache.get(entity, Transform)
    if t then
        t.actualX = targetX
        t.actualY = targetY
    end

    -- Update InheritedProperties offset
    local role = component_cache.get(entity, InheritedProperties)
    if role and role.offset then
        role.offset.x = targetX
        role.offset.y = targetY
    end

    -- For UIBox entities, also update uiRoot
    local boxComp = component_cache.get(entity, UIBoxComponent)
    if boxComp and boxComp.uiRoot and _G.registry:valid(boxComp.uiRoot) then
        local rt = component_cache.get(boxComp.uiRoot, Transform)
        if rt then
            rt.actualX = targetX
            rt.actualY = targetY
        end
        local rootRole = component_cache.get(boxComp.uiRoot, InheritedProperties)
        if rootRole and rootRole.offset then
            rootRole.offset.x = targetX
            rootRole.offset.y = targetY
        end

        -- Force layout recalculation
        if ui and ui.box and ui.box.RenewAlignment then
            ui.box.RenewAlignment(_G.registry, entity)
        end
    end
end

--------------------------------------------------------------------------------
-- UI BUILDING (Requires game engine)
--------------------------------------------------------------------------------
-- NOTE: Signal handling (skill_learned, skill_unlearned, player_level_up)
-- is consolidated in skills_panel_input.lua to avoid duplicate handlers.

local function buildPanelDef()
    -- This would be the DSL definition for the panel
    -- For now, return a placeholder that will be fleshed out when integrating
    return {
        id = "skills_panel",
        type = "box",
        -- ... DSL definition would go here
    }
end

local function initializePanel()
    if state.initialized then return end

    if not calculatePositions() then
        return
    end

    -- Check if we have the required game engine globals
    if not dsl or not _G.registry then
        -- Running in test mode without game engine
        state.initialized = true
        return
    end

    -- Build and spawn the panel (implementation depends on DSL)
    -- TODO: Implement full panel spawning when integrating

    state.initialized = true
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Check if panel is initialized
--- @return boolean
function SkillsPanel.isInitialized()
    return state.initialized
end

--- Check if panel is open
--- @return boolean
function SkillsPanel.isOpen()
    return state.isVisible
end

--- Open the skills panel
function SkillsPanel.open()
    if not state.initialized then
        initializePanel()
    end

    if state.isVisible then return end

    setEntityVisible(state.panelEntity, true, state.panelX, state.panelY)
    state.isVisible = true

    if signal then
        signal.emit("skills_panel_opened")
    end
end

--- Close the skills panel
function SkillsPanel.close()
    if not state.isVisible then return end

    setEntityVisible(state.panelEntity, false, state.panelX, state.panelY)
    state.isVisible = false

    if signal then
        signal.emit("skills_panel_closed")
    end
end

--- Toggle the skills panel
function SkillsPanel.toggle()
    if state.isVisible then
        SkillsPanel.close()
    else
        SkillsPanel.open()
    end
end

--- Set player reference for skill point queries
--- @param player table Player object
function SkillsPanel.setPlayer(player)
    state.player = player
end

--- Get current player reference
--- @return table|nil
function SkillsPanel.getPlayer()
    return state.player
end

--- Refresh skill button visual states
function SkillsPanel.refreshButtonStates()
    -- TODO: Implement when UI is built
    -- Iterate state.skillButtons and update visuals based on getSkillButtonState()
end

--- Refresh header text (skill points display)
function SkillsPanel.refreshHeader()
    -- TODO: Implement when UI is built
    -- Update state.headerTextEntity with getSkillPointsDisplay()
end

--- Destroy the panel and cleanup
function SkillsPanel.destroy()
    if not state.initialized then return end

    if timer then
        timer.kill_group(TIMER_GROUP)
    end

    -- Destroy panel entity
    if state.panelEntity and _G.registry and _G.registry.valid and _G.registry:valid(state.panelEntity) then
        if ui and ui.box and ui.box.Remove then
            ui.box.Remove(_G.registry, state.panelEntity)
        end
    end

    -- Reset state
    state.initialized = false
    state.isVisible = false
    state.panelEntity = nil
    state.gridEntity = nil
    state.skillButtons = {}
    state.headerTextEntity = nil
    state.player = nil
end

--- Reset module state (for testing)
function SkillsPanel._reset()
    SkillsPanel.destroy()
end

return SkillsPanel
