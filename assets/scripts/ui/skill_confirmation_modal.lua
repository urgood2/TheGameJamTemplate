--[[
================================================================================
SKILL CONFIRMATION MODAL - Centered Modal for Skill Learning
================================================================================

A centered modal popup that appears when clicking a skill in the panel:
- Shows skill name, description, cost, and current points
- Has Confirm and Cancel buttons
- Requires explicit button click to dismiss (no click-outside)

USAGE:
------
local SkillConfirmationModal = require("ui.skill_confirmation_modal")

SkillConfirmationModal.show(player, skillId)  -- Show modal for skill
SkillConfirmationModal.hide()                  -- Hide modal
SkillConfirmationModal.confirm()               -- Attempt to learn skill
SkillConfirmationModal.cancel()                -- Cancel without learning

EVENTS (via hump.signal):
-------------------------
"skill_learn_requested"      -- Confirm button clicked
"skill_modal_closed"         -- Modal closed (confirm or cancel)

================================================================================
]]

local SkillConfirmationModal = {}

--------------------------------------------------------------------------------
-- DEPENDENCIES
--------------------------------------------------------------------------------

local function safeRequire(module)
    local ok, result = pcall(require, module)
    return ok and result or nil
end

local Skills = safeRequire("data.skills")
local SkillSystem = safeRequire("core.skill_system")
local signal = safeRequire("external.hump.signal")
local ui_scale = safeRequire("ui.ui_scale")
local dsl = safeRequire("ui.ui_syntax_sugar")
local component_cache = _G.component_cache or { get = function() return nil end }

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------

local UI = ui_scale and ui_scale.ui or function(x) return x end

local CONFIG = {
    width = UI(300),
    height = UI(200),
    background_sprite = "modal-background",
    confirm_button_sprite = "button-confirm",
    cancel_button_sprite = "button-cancel",
}

--------------------------------------------------------------------------------
-- MODULE STATE
--------------------------------------------------------------------------------

local state = {
    visible = false,
    modalEntity = nil,
    player = nil,
    skillId = nil,
    modalData = nil,
}

--------------------------------------------------------------------------------
-- MODAL DATA GENERATION
--------------------------------------------------------------------------------

local function generateModalData(player, skillId)
    if not Skills or not SkillSystem then return nil end

    local skill = Skills.get(skillId)
    if not skill then return nil end

    local currentPoints = player and player.skill_points or 0
    local remainingPoints = SkillSystem.get_skill_points_remaining(player)
    local cost = skill.cost or 0
    local canAfford = remainingPoints >= cost

    return {
        player = player,
        skillId = skillId,
        skillName = skill.name,
        skillDescription = skill.description,
        skillCost = cost,
        skillIcon = skill.icon,
        skillElement = skill.element,
        currentPoints = currentPoints,
        remainingPoints = remainingPoints,
        canAfford = canAfford,
    }
end

--------------------------------------------------------------------------------
-- STATE QUERIES
--------------------------------------------------------------------------------

--- Check if modal is visible
--- @return boolean
function SkillConfirmationModal.isVisible()
    return state.visible
end

--- Get current modal data
--- @return table|nil Modal data or nil if not showing
function SkillConfirmationModal.getModalData()
    return state.modalData
end

--------------------------------------------------------------------------------
-- SHOW/HIDE
--------------------------------------------------------------------------------

--- Show the modal for a skill
--- @param player table Player object
--- @param skillId string Skill ID to show
function SkillConfirmationModal.show(player, skillId)
    if not skillId then return end

    state.player = player
    state.skillId = skillId
    state.modalData = generateModalData(player, skillId)
    state.visible = true

    -- TODO: Create/show actual modal entity when integrating UI
end

--- Hide the modal
function SkillConfirmationModal.hide()
    state.visible = false
    state.player = nil
    state.skillId = nil
    state.modalData = nil

    -- TODO: Hide/destroy actual modal entity

    if signal then
        signal.emit("skill_modal_closed")
    end
end

--------------------------------------------------------------------------------
-- ACTIONS
--------------------------------------------------------------------------------

--- Confirm learning the skill
--- @return boolean success True if skill was learned
function SkillConfirmationModal.confirm()
    if not state.visible or not state.player or not state.skillId then
        return false
    end

    -- Check if can afford
    if not SkillSystem or not SkillSystem.can_learn_skill(state.player, state.skillId) then
        -- Update modal data to reflect error
        state.modalData = generateModalData(state.player, state.skillId)
        return false
    end

    -- Emit signal before learning
    if signal then
        signal.emit("skill_learn_requested", {
            player = state.player,
            skill_id = state.skillId
        })
    end

    -- Learn the skill
    local success = SkillSystem.learn_skill(state.player, state.skillId)

    if success then
        SkillConfirmationModal.hide()
    else
        -- Update modal data to show error state
        state.modalData = generateModalData(state.player, state.skillId)
    end

    return success
end

--- Cancel and close the modal
function SkillConfirmationModal.cancel()
    SkillConfirmationModal.hide()
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

--- Destroy the modal and cleanup
function SkillConfirmationModal.destroy()
    SkillConfirmationModal.hide()

    if state.modalEntity and _G.registry and _G.registry.valid and _G.registry:valid(state.modalEntity) then
        -- Use ui.box.Remove for proper UIBox cleanup (per UI Panel Implementation Guide)
        if _G.ui and _G.ui.box and _G.ui.box.Remove then
            _G.ui.box.Remove(_G.registry, state.modalEntity)
        else
            _G.registry:destroy(state.modalEntity)
        end
    end

    state.modalEntity = nil
end

--- Reset module state (for testing)
function SkillConfirmationModal._reset()
    SkillConfirmationModal.destroy()
end

return SkillConfirmationModal
