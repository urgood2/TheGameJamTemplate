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
    -- Using inventory panel sprite temporarily (TODO: create dedicated modal sprite)
    background_sprite = "inventory-back-panel.png",
    -- Buttons are text-based with colors, not sprites
    button_width = UI(80),
    button_height = UI(30),
    padding = UI(16),
}

local MODAL_Z = 900  -- Above panel and tab marker

-- Element colors - must be string color names for dsl.strict compatibility
local ELEMENT_COLORS = {
    fire = "gold",
    ice = "cyan",
    lightning = "amber",
    void = "purple_slate",
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
-- MODAL ENTITY CREATION
--------------------------------------------------------------------------------

--- Build the modal DSL definition
local function buildModalDef()
    if not dsl or not state.modalData then return nil end

    local data = state.modalData
    local elementColor = ELEMENT_COLORS[data.skillElement] or "white"
    local canAffordColor = data.canAfford and "green" or "red"

    return dsl.strict.spritePanel {
        sprite = CONFIG.background_sprite,
        borders = { 8, 8, 8, 8 },
        sizing = "stretch",
        config = {
            id = "skill_modal",
            padding = CONFIG.padding,
            minWidth = CONFIG.width,
            minHeight = CONFIG.height,
            align = "center",
        },
        children = {
            -- Skill name (align defaults to centered)
            dsl.strict.text(data.skillName or "Unknown Skill", {
                id = "modal_skill_name",
                fontSize = UI(18),
                color = elementColor,
            }),

            dsl.strict.spacer(UI(8)),

            -- Skill description (align defaults to centered)
            dsl.strict.text(data.skillDescription or "", {
                id = "modal_skill_desc",
                fontSize = UI(11),
                color = "white",
                maxWidth = CONFIG.width - CONFIG.padding * 2,
            }),

            dsl.strict.spacer(UI(12)),

            -- Cost info
            dsl.strict.hbox {
                config = { align = "center", padding = 0 },
                children = {
                    dsl.strict.text("Cost: ", {
                        fontSize = UI(12),
                        color = "gray",
                    }),
                    dsl.strict.text(tostring(data.skillCost or 0), {
                        fontSize = UI(12),
                        color = canAffordColor,
                    }),
                    dsl.strict.text(" / Points: ", {
                        fontSize = UI(12),
                        color = "gray",
                    }),
                    dsl.strict.text(tostring(data.remainingPoints or 0), {
                        fontSize = UI(12),
                        color = "yellow",
                    }),
                },
            },

            dsl.strict.spacer(UI(16)),

            -- Buttons row
            dsl.strict.hbox {
                config = {
                    id = "modal_buttons",
                    padding = 0,
                    align = "center",
                },
                children = {
                    -- Confirm button
                    dsl.strict.button("Learn", {
                        id = "modal_confirm_btn",
                        fontSize = UI(12),
                        color = data.canAfford and "green" or "gray",
                        minWidth = CONFIG.button_width,
                        minHeight = CONFIG.button_height,
                        onClick = function()
                            SkillConfirmationModal.confirm()
                        end,
                    }),

                    dsl.strict.spacer(UI(16)),

                    -- Cancel button
                    dsl.strict.button("Cancel", {
                        id = "modal_cancel_btn",
                        fontSize = UI(12),
                        color = "red",
                        minWidth = CONFIG.button_width,
                        minHeight = CONFIG.button_height,
                        onClick = function()
                            SkillConfirmationModal.cancel()
                        end,
                    }),
                },
            },
        },
    }
end

--- Create and spawn the modal entity
local function createModalEntity()
    if not dsl or not _G.registry then return nil end

    local modalDef = buildModalDef()
    if not modalDef then return nil end

    -- Calculate centered position
    local screenWidth = GetScreenWidth and GetScreenWidth() or 1920
    local screenHeight = GetScreenHeight and GetScreenHeight() or 1080
    local x = (screenWidth - CONFIG.width) / 2
    local y = (screenHeight - CONFIG.height) / 2

    -- Spawn the modal
    local modalEntity = dsl.spawn(
        { x = x, y = y },
        modalDef,
        "ui",
        MODAL_Z
    )

    if not modalEntity then
        print("[SkillConfirmationModal] Failed to spawn modal entity")
        return nil
    end

    -- Set draw layer
    if _G.ui and _G.ui.box and _G.ui.box.set_draw_layer then
        _G.ui.box.set_draw_layer(modalEntity, "sprites")
    end

    -- Add state tags for rendering
    if _G.ui and _G.ui.box and _G.ui.box.AddStateTagToUIBox then
        _G.ui.box.AddStateTagToUIBox(_G.registry, modalEntity, "default_state")
    end

    return modalEntity
end

--- Destroy the modal entity if it exists
local function destroyModalEntity()
    if state.modalEntity and _G.registry and _G.registry.valid and _G.registry:valid(state.modalEntity) then
        if _G.ui and _G.ui.box and _G.ui.box.Remove then
            _G.ui.box.Remove(_G.registry, state.modalEntity)
        else
            _G.registry:destroy(state.modalEntity)
        end
    end
    state.modalEntity = nil
end

--------------------------------------------------------------------------------
-- SHOW/HIDE
--------------------------------------------------------------------------------

--- Show the modal for a skill
--- @param player table Player object
--- @param skillId string Skill ID to show
function SkillConfirmationModal.show(player, skillId)
    if not skillId then return end

    -- Hide any existing modal first
    if state.visible then
        destroyModalEntity()
    end

    state.player = player
    state.skillId = skillId
    state.modalData = generateModalData(player, skillId)
    state.visible = true

    -- Create the modal entity if we have DSL
    if dsl and _G.registry then
        state.modalEntity = createModalEntity()
    end
end

--- Hide the modal
function SkillConfirmationModal.hide()
    -- Destroy the modal entity
    destroyModalEntity()

    state.visible = false
    state.player = nil
    state.skillId = nil
    state.modalData = nil

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
    -- hide() already handles destroying the modal entity
    SkillConfirmationModal.hide()
end

--- Reset module state (for testing)
function SkillConfirmationModal._reset()
    SkillConfirmationModal.destroy()
end

return SkillConfirmationModal
