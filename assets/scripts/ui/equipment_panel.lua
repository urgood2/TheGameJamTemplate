--[[
================================================================================
EQUIPMENT PANEL - Equipment Slot Management UI
================================================================================

Manages character equipment slots with support for enabled/disabled slots.

USAGE:
------
local EquipmentPanel = require("ui.equipment_panel")

EquipmentPanel.create()         -- Create and initialize panel
EquipmentPanel.show()           -- Show the panel
EquipmentPanel.hide()           -- Hide the panel
EquipmentPanel.isVisible()      -- Check visibility
EquipmentPanel.destroy()        -- Cleanup and destroy

STRUCTURE:
----------
6 equipment slots arranged in 3 rows:
- Row 1: helm (disabled)
- Row 2: gloves (enabled), chest (enabled), ring (disabled)
- Row 3: boots (enabled), trinket (disabled)

================================================================================
]]

local EquipmentPanel = {}

local dsl = require("ui.ui_syntax_sugar")
local component_cache = require("core.component_cache")
local signal = require("external.hump.signal")
local timer = require("core.timer")
local ui_scale = require("ui.ui_scale")

local UI = ui_scale.ui

-- Configuration
local SLOT_CONFIG = {
    helm    = { enabled = false, row = 1, col = 2 },
    gloves  = { enabled = true,  row = 2, col = 1 },
    chest   = { enabled = true,  row = 2, col = 2 },
    ring    = { enabled = false, row = 2, col = 3 },
    boots   = { enabled = true,  row = 3, col = 1 },
    trinket = { enabled = false, row = 3, col = 3 },
}

-- Panel dimensions
local SLOT_SIZE = UI(48)
local SLOT_SPACING = UI(4)
local PANEL_PADDING = UI(10)
local PANEL_WIDTH = UI(180)
local PANEL_HEIGHT = UI(240)
local HEADER_HEIGHT = UI(32)
local FOOTER_HEIGHT = UI(36)

local PANEL_Z = 800
local RENDER_LAYER = "ui"
local TIMER_GROUP = "equipment_panel"

-- State
local state = {
    initialized = false,
    isVisible = false,
    panelEntity = nil,
    slotEntities = {},
    equippedItems = {},
    panelX = 0,
    panelY = 0,
    signalHandlers = {},
}

local function getLocalizedText(key, fallback)
    if localization and localization.get then
        local text = localization.get(key)
        if text and text ~= key then
            return text
        end
    end
    return fallback or key
end

-- Visibility Control
local function setEntityVisible(entity, visible, onscreenX, onscreenY)
    if not entity or not registry:valid(entity) then return end

    local targetX = onscreenX
    local targetY = visible and onscreenY or (GetScreenHeight())

    local t = component_cache.get(entity, Transform)
    if t then
        t.actualX = targetX
        t.actualY = targetY
    end

    local role = component_cache.get(entity, InheritedProperties)
    if role and role.offset then
        role.offset.x = targetX
        role.offset.y = targetY
    end

    local boxComp = component_cache.get(entity, UIBoxComponent)
    if boxComp and boxComp.uiRoot and registry:valid(boxComp.uiRoot) then
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

        if ui and ui.box and ui.box.RenewAlignment then
            ui.box.RenewAlignment(registry, entity)
        end
    end
end

local function createSlot(slotName)
    local cfg = SLOT_CONFIG[slotName]
    if not cfg then return nil end

    local isEnabled = cfg.enabled
    local slotColor = isEnabled and "green" or "gray"
    
    return dsl.strict.button(slotName:sub(1, 1):upper() .. slotName:sub(2), {
        id = "slot_" .. slotName,
        fontSize = UI(10),
        minWidth = SLOT_SIZE,
        minHeight = SLOT_SIZE,
        color = slotColor,
        enabled = isEnabled,
        onClick = function()
            if isEnabled then
                signal.emit("equipment_slot_clicked", slotName)
            end
        end,
    })
end

local function createHeader()
    return dsl.hbox {
        config = {
            id = "equipment_header",
            padding = UI(8),
            minWidth = PANEL_WIDTH - 2 * PANEL_PADDING,
        },
        children = {
            dsl.strict.text("Equipment", {
                id = "header_title",
                fontSize = UI(14),
                color = "gold",
                shadow = true,
                padding = UI(4)
            }),
            dsl.filler(),
            dsl.strict.button("X", {
                id = "close_btn",
                fontSize = UI(12),
                color = "red",
                minWidth = UI(24),
                minHeight = UI(24),
                onClick = function()
                    EquipmentPanel.hide()
                end,
            }),
        },
    }
end

local function createSlotRows()
    local rows = {}
    
    for rowNum = 1, 3 do
        local rowChildren = {}
        
        for _, slotName in ipairs({ "helm", "gloves", "chest", "ring", "boots", "trinket" }) do
            local cfg = SLOT_CONFIG[slotName]
            if cfg and cfg.row == rowNum then
                table.insert(rowChildren, createSlot(slotName))
            end
        end
        
        if #rowChildren > 0 then
            table.insert(rows, dsl.strict.hbox {
                config = {
                    padding = SLOT_SPACING,
                    align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_TOP),
                },
                children = rowChildren,
            })
        end
    end
    
    return dsl.strict.vbox {
        config = {
            id = "equipment_slots_container",
            padding = PANEL_PADDING,
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_TOP),
        },
        children = rows,
    }
end

local function createFooter()
    return dsl.strict.hbox {
        config = {
            padding = UI(4),
        },
        children = {
            dsl.text("3 / 6 slots enabled", {
                id = "slot_count_text",
                fontSize = UI(10),
                color = "white"
            }),
        },
    }
end

local function createPanelDefinition()
    return dsl.strict.spritePanel {
        sprite = "inventory-back-panel.png",
        borders = { 0, 0, 0, 0 },
        sizing = "stretch",
        config = {
            id = "equipment_panel",
            padding = PANEL_PADDING,
            minWidth = PANEL_WIDTH,
            minHeight = PANEL_HEIGHT,
        },
        children = {
            createHeader(),
            createSlotRows(),
            createFooter(),
        },
    }
end

local function setupSignalHandlers()
    local function registerHandler(eventName, handler)
        signal.register(eventName, handler)
        table.insert(state.signalHandlers, { event = eventName, handler = handler })
    end

    registerHandler("equipment_slot_clicked", function(slotName)
        log_debug("[EquipmentPanel] Slot clicked: " .. slotName)
        if playSoundEffect then
            playSoundEffect("effects", "button-click")
        end
    end)
end

local function cleanupSignalHandlers()
    for _, entry in ipairs(state.signalHandlers) do
        if entry.event and entry.handler then
            signal.remove(entry.event, entry.handler)
        end
    end
    state.signalHandlers = {}
end

local function calculatePositions()
    local screenW = globals.screenWidth()
    local screenH = globals.screenHeight()

    if not screenW or not screenH or screenW <= 0 or screenH <= 0 then
        log_debug("[EquipmentPanel] Skipping position calc - screen not ready: " ..
                  tostring(screenW) .. "x" .. tostring(screenH))
        return false
    end

    state.panelX = screenW - PANEL_WIDTH - PANEL_PADDING
    state.panelY = PANEL_PADDING

    return true
end

local function initializePanel()
    if state.initialized then return end

    if not calculatePositions() then
        log_warn("[EquipmentPanel] Cannot initialize - screen dimensions not ready")
        return
    end

    local panelDef = createPanelDefinition()
    state.panelEntity = dsl.spawn(
        { x = state.panelX, y = state.panelY },
        panelDef,
        RENDER_LAYER,
        PANEL_Z
    )

    if ui and ui.box and ui.box.set_draw_layer then
        ui.box.set_draw_layer(state.panelEntity, "sprites")
    end

    if ui and ui.box and ui.box.AddStateTagToUIBox then
        ui.box.AddStateTagToUIBox(registry, state.panelEntity, "default_state")
    end

    -- Cache slot entities
    for slotName in pairs(SLOT_CONFIG) do
        local slotEntity = ui.box.GetUIEByID(registry, state.panelEntity, "slot_" .. slotName)
        if slotEntity then
            state.slotEntities[slotName] = slotEntity
        end
    end

    setupSignalHandlers()

    state.initialized = true
    log_debug("[EquipmentPanel] Initialized")
end

function EquipmentPanel.create()
    if not state.initialized then
        initializePanel()
    end
    log_debug("[EquipmentPanel] Created")
end

function EquipmentPanel.show()
    if not state.initialized then
        initializePanel()
    end

    if state.isVisible then return end

    setEntityVisible(state.panelEntity, true, state.panelX, state.panelY)
    state.isVisible = true

    if playSoundEffect then
        playSoundEffect("effects", "button-click")
    end

    signal.emit("equipment_panel_opened")
    log_debug("[EquipmentPanel] Shown")
end

function EquipmentPanel.hide()
    if not state.isVisible then return end

    setEntityVisible(state.panelEntity, false, state.panelX, state.panelY)
    state.isVisible = false

    signal.emit("equipment_panel_closed")
    log_debug("[EquipmentPanel] Hidden")
end

function EquipmentPanel.isVisible()
    return state.isVisible
end

function EquipmentPanel.toggle()
    if state.isVisible then
        EquipmentPanel.hide()
    else
        EquipmentPanel.show()
    end
end

function EquipmentPanel.destroy()
    if not state.initialized then return end

    log_debug("[EquipmentPanel] Destroying...")

    cleanupSignalHandlers()
    timer.kill_group(TIMER_GROUP)

    if state.panelEntity and registry:valid(state.panelEntity) then
        if ui and ui.box and ui.box.Remove then
            ui.box.Remove(registry, state.panelEntity)
        end
    end

    state.panelEntity = nil
    state.slotEntities = {}
    state.equippedItems = {}
    state.initialized = false
    state.isVisible = false

    log_debug("[EquipmentPanel] Destroyed")
end

function EquipmentPanel.equipItem(slotName, itemEntity, itemData)
    if not SLOT_CONFIG[slotName] then
        log_warn("[EquipmentPanel] Invalid slot: " .. tostring(slotName))
        return false
    end

    if not SLOT_CONFIG[slotName].enabled then
        log_warn("[EquipmentPanel] Slot is disabled: " .. tostring(slotName))
        return false
    end

    state.equippedItems[slotName] = {
        entity = itemEntity,
        data = itemData,
    }

    signal.emit("equipment_item_equipped", slotName, itemEntity, itemData)
    log_debug("[EquipmentPanel] Equipped " .. (itemData and itemData.name or "item") .. " to " .. slotName)
    return true
end

function EquipmentPanel.unequipItem(slotName)
    if not SLOT_CONFIG[slotName] then
        log_warn("[EquipmentPanel] Invalid slot: " .. tostring(slotName))
        return false
    end

    local oldItem = state.equippedItems[slotName]
    state.equippedItems[slotName] = nil

    if oldItem then
        signal.emit("equipment_item_unequipped", slotName, oldItem.entity, oldItem.data)
        log_debug("[EquipmentPanel] Unequipped item from " .. slotName)
    end

    return true
end

function EquipmentPanel.getEquippedItem(slotName)
    if not SLOT_CONFIG[slotName] then
        return nil
    end
    return state.equippedItems[slotName]
end

function EquipmentPanel.getEquippedItems()
    return state.equippedItems
end

function EquipmentPanel.getPanelEntity()
    return state.panelEntity
end

function EquipmentPanel.getSlotEntity(slotName)
    if not SLOT_CONFIG[slotName] then
        return nil
    end
    return state.slotEntities[slotName]
end

log_debug("[EquipmentPanel] Module loaded")

return EquipmentPanel
