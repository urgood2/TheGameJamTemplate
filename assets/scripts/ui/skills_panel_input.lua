--[[
================================================================================
SKILLS PANEL INPUT - Keyboard and Signal Handlers
================================================================================

Handles keyboard input and signal integration for the skills panel system:
- K key toggles the skills panel
- ESC closes the panel (if no modal open)
- Signal handlers for skill_learned, skill_unlearned, player_level_up

USAGE:
------
local SkillsPanelInput = require("ui.skills_panel_input")

SkillsPanelInput.initialize(player)   -- Start input handling
SkillsPanelInput.shutdown()           -- Stop input handling

================================================================================
]]

local SkillsPanelInput = {}

--------------------------------------------------------------------------------
-- DEPENDENCIES
--------------------------------------------------------------------------------

local function safeRequire(module)
    local ok, result = pcall(require, module)
    return ok and result or nil
end

local SkillsPanel = safeRequire("ui.skills_panel")
local SkillsTabMarker = safeRequire("ui.skills_tab_marker")
local SkillConfirmationModal = safeRequire("ui.skill_confirmation_modal")
local timer = safeRequire("core.timer")
local signal = safeRequire("external.hump.signal")

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------

local TIMER_GROUP = "skills_panel_input"
local KEY_TOGGLE = "KEY_K"
local KEY_CLOSE = "KEY_ESCAPE"

--------------------------------------------------------------------------------
-- MODULE STATE
--------------------------------------------------------------------------------

local state = {
    initialized = false,
    player = nil,
    signalHandlers = {},
}

--------------------------------------------------------------------------------
-- KEYBOARD HANDLING
--------------------------------------------------------------------------------

local function setupKeyboardHandler()
    if not timer then return end

    timer.every_opts({
        delay = 0.05,
        tag = "skills_panel_keyboard",
        group = TIMER_GROUP,
        action = function()
            -- K key toggles panel (only if modal is not open)
            if isKeyPressed and isKeyPressed(KEY_TOGGLE) then
                if SkillConfirmationModal and SkillConfirmationModal.isVisible() then
                    -- Modal is open, don't toggle panel
                    return
                end
                if SkillsPanel then
                    SkillsPanel.toggle()
                    -- Update tab marker position
                    if SkillsTabMarker then
                        local config = SkillsPanel.getConfig()
                        local panelWidth = config and config.columns * 52 or 200  -- Approximate
                        SkillsTabMarker.updatePosition(SkillsPanel.isOpen(), panelWidth)
                    end
                end
            end

            -- ESC closes panel or modal
            if isKeyPressed and isKeyPressed(KEY_CLOSE) then
                -- First close modal if open
                if SkillConfirmationModal and SkillConfirmationModal.isVisible() then
                    SkillConfirmationModal.cancel()
                    return
                end
                -- Then close panel if open
                if SkillsPanel and SkillsPanel.isOpen() then
                    SkillsPanel.close()
                    if SkillsTabMarker then
                        SkillsTabMarker.updatePosition(false, 0)
                    end
                end
            end
        end,
    })
end

--------------------------------------------------------------------------------
-- SIGNAL HANDLING
--------------------------------------------------------------------------------

local function setupSignalHandlers()
    if not signal then return end

    -- When a skill is learned, refresh the panel
    state.signalHandlers.skill_learned = function(data)
        if SkillsPanel then
            SkillsPanel.refreshButtonStates()
            SkillsPanel.refreshHeader()
        end
    end

    -- When a skill is unlearned, refresh the panel
    state.signalHandlers.skill_unlearned = function(data)
        if SkillsPanel then
            SkillsPanel.refreshButtonStates()
            SkillsPanel.refreshHeader()
        end
    end

    -- When player levels up, refresh skill points display
    state.signalHandlers.player_level_up = function(data)
        if SkillsPanel then
            SkillsPanel.refreshHeader()
        end
    end

    -- When panel opens, update tab marker
    state.signalHandlers.skills_panel_opened = function()
        if SkillsTabMarker and SkillsPanel then
            local config = SkillsPanel.getConfig()
            local panelWidth = config and config.columns * 52 or 200
            SkillsTabMarker.updatePosition(true, panelWidth)
        end
    end

    -- When panel closes, update tab marker
    state.signalHandlers.skills_panel_closed = function()
        if SkillsTabMarker then
            SkillsTabMarker.updatePosition(false, 0)
        end
    end

    for event, handler in pairs(state.signalHandlers) do
        signal.register(event, handler)
    end
end

local function cleanupSignalHandlers()
    if not signal then return end

    for event, handler in pairs(state.signalHandlers) do
        signal.remove(event, handler)
    end
    state.signalHandlers = {}
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Check if input handling is initialized
--- @return boolean
function SkillsPanelInput.isInitialized()
    return state.initialized
end

--- Initialize input handling for the skills panel system
--- @param player table Player object for skill point queries
function SkillsPanelInput.initialize(player)
    if state.initialized then return end

    state.player = player

    -- Set player on skills panel
    if SkillsPanel then
        SkillsPanel.setPlayer(player)
    end

    -- Initialize tab marker
    if SkillsTabMarker then
        SkillsTabMarker.initialize()
    end

    -- Setup input handlers
    setupKeyboardHandler()
    setupSignalHandlers()

    state.initialized = true
end

--- Shutdown input handling and cleanup
function SkillsPanelInput.shutdown()
    if not state.initialized then return end

    -- Kill keyboard timer
    if timer then
        timer.kill_group(TIMER_GROUP)
    end

    -- Cleanup signal handlers
    cleanupSignalHandlers()

    -- Destroy UI components
    if SkillsPanel then
        SkillsPanel.destroy()
    end
    if SkillsTabMarker then
        SkillsTabMarker.destroy()
    end
    if SkillConfirmationModal then
        SkillConfirmationModal.destroy()
    end

    state.initialized = false
    state.player = nil
end

--- Get the current player
--- @return table|nil
function SkillsPanelInput.getPlayer()
    return state.player
end

--- Open panel and show skill modal (convenience method for skill button clicks)
--- @param skillId string Skill ID to show in modal
function SkillsPanelInput.onSkillButtonClicked(skillId)
    if not state.player or not skillId then return end

    if SkillConfirmationModal then
        SkillConfirmationModal.show(state.player, skillId)
    end
end

--- Reset module state (for testing)
function SkillsPanelInput._reset()
    SkillsPanelInput.shutdown()
end

return SkillsPanelInput
