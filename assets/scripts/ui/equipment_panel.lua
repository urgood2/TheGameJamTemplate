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
local combat_system = require("combat.combat_system")
local shader_pipeline = _G.shader_pipeline

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

-- Forward declarations for functions used before their definition
local setupSlotInteractions
local setupRenderTimer

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
                    -- Close entire inventory (which will also hide equipment panel)
                    local PlayerInventory = require("ui.player_inventory")
                    PlayerInventory.close()
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

local function getCardData(entity)
    if not entity or not registry:valid(entity) then return nil end
    local script = getScriptTableFromEntityID and getScriptTableFromEntityID(entity)
    return script and (script.equipmentDef or script.cardData)
end

local function normalizeEquipmentDef(equipDef)
    if not equipDef or equipDef._normalized_for_item_system then
        return equipDef
    end

    -- Shallow copy to avoid mutating shared data tables
    local normalized = {}
    for k, v in pairs(equipDef) do
        normalized[k] = v
    end

    -- Convert stats map -> ItemSystem mods array if needed
    if normalized.stats and not normalized.mods then
        normalized.mods = {}
        for stat, value in pairs(normalized.stats) do
            if value ~= nil and value ~= 0 then
                local mod = { stat = stat }
                if type(value) == "table" then
                    if value.base then mod.base = value.base end
                    if value.add_pct then mod.add_pct = value.add_pct end
                    if value.mul_pct then mod.mul_pct = value.mul_pct end
                else
                    mod.base = value
                end
                table.insert(normalized.mods, mod)
            end
        end
    end

    -- Convert proc.effect -> proc.effects with event preservation
    if normalized.procs then
        for _, proc in ipairs(normalized.procs) do
            if proc.effect and not proc.effects then
                local effectFn = proc.effect
                proc.effects = function(ctx, src, _tgt, ev)
                    return effectFn(ctx, src, ev)
                end
            end
        end
    end

    normalized._normalized_for_item_system = true
    return normalized
end

local function highlightCompatibleSlot(slotId)
    local slotEntity = state.slotEntities[slotId]
    if slotEntity and registry:valid(slotEntity) then
        local slotCfg = SLOT_CONFIG[slotId]
        if not slotCfg or not slotCfg.enabled then
            return  -- Don't highlight disabled slots
        end
        
        local uiCfg = component_cache.get(slotEntity, UIConfig)
        if uiCfg and _G.util then
            uiCfg.color = _G.util.getColor("jade_green")
        end
    end
end

local function clearAllSlotHighlights()
    for slotId, slotEntity in pairs(state.slotEntities) do
        if slotEntity and registry:valid(slotEntity) then
            local slotCfg = SLOT_CONFIG[slotId]
            local uiCfg = component_cache.get(slotEntity, UIConfig)
            if uiCfg and _G.util then
                local defaultColor = (slotCfg and slotCfg.enabled) and "purple_slate" or "gray"
                uiCfg.color = _G.util.getColor(defaultColor)
            end
        end
    end
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

local function setupDragFeedback()
    local function registerHandler(eventName, handler)
        signal.register(eventName, handler)
        table.insert(state.signalHandlers, { event = eventName, handler = handler })
    end
    
    registerHandler("drag_started", function(itemEntity)
        local cardData = getCardData(itemEntity)
        if cardData and cardData.equipmentDef then
            local targetSlot = cardData.equipmentDef.slot
            highlightCompatibleSlot(targetSlot)
        end
    end)
    
    registerHandler("drag_ended", function(itemEntity)
        clearAllSlotHighlights()
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
     
     setupSlotInteractions()
     setupRenderTimer()
     setupDragFeedback()
     
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

function EquipmentPanel.setPosition(x, y)
    if type(x) == "number" then
        state.panelX = x
    end
    if type(y) == "number" then
        state.panelY = y
    end

    if state.panelEntity and registry:valid(state.panelEntity) then
        setEntityVisible(state.panelEntity, state.isVisible, state.panelX, state.panelY)
    end
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

local function getPlayerEntity()
    if globals and globals.playerScript then
        return globals.playerScript.e
    end
    
    if globals and globals.playerEntity then
        return globals.playerEntity
    end
    
    if registry and type(registry.valid) == "function" then
        local survivorEntity = globals.survivorEntity
        if survivorEntity and registry:valid(survivorEntity) then
            return survivorEntity
        end
    end
    
    log_warn("[EquipmentPanel] Could not get player entity")
    return nil
end

local function getCombatContext()
    if globals and globals.combat_context then
        return globals.combat_context
    end
    
    if combat_system and combat_system.Game then
        return { game = combat_system.Game }
    end
    
    log_warn("[EquipmentPanel] Could not get combat context")
    return nil
end

local function centerItemOnSlot(itemEntity, slotEntity)
     if not registry:valid(itemEntity) or not registry:valid(slotEntity) then
         log_warn("[EquipmentPanel] Invalid entity in centerItemOnSlot")
         return false
     end

     local slotTransform = component_cache.get(slotEntity, Transform)
     local itemTransform = component_cache.get(itemEntity, Transform)

     if not slotTransform or not itemTransform then
         log_warn("[EquipmentPanel] Missing Transform components")
         return false
     end

     local slotX, slotY
     if slotTransform.visualX ~= nil and slotTransform.visualY ~= nil then
         slotX = slotTransform.visualX
         slotY = slotTransform.visualY
     else
         local slotRole = component_cache.get(slotEntity, InheritedProperties)
         local slotOffsetX = slotRole and slotRole.offset and slotRole.offset.x or 0
         local slotOffsetY = slotRole and slotRole.offset and slotRole.offset.y or 0

         local gridEntity = slotRole and slotRole.master
         local gridTransform = gridEntity and component_cache.get(gridEntity, Transform)

         if gridTransform then
             slotX = (gridTransform.actualX or 0) + slotOffsetX
             slotY = (gridTransform.actualY or 0) + slotOffsetY
         else
             slotX = slotTransform.actualX or 0
             slotY = slotTransform.actualY or 0
         end
     end

     local slotW = slotTransform.actualW or 48
     local slotH = slotTransform.actualH or 48
     local itemW = itemTransform.actualW or 48
     local itemH = itemTransform.actualH or 48

     local centerX = slotX + (slotW - itemW) / 2
     local centerY = slotY + (slotH - itemH) / 2

     itemTransform.actualX = centerX
     itemTransform.actualY = centerY
     itemTransform.visualX = centerX
     itemTransform.visualY = centerY

     log_debug(string.format("[EquipmentPanel] Centered item at (%.1f, %.1f) in slot", centerX, centerY))
     return true
 end

local function returnEquippedItemFromSlot(slotName)
    local equippedItem = state.equippedItems[slotName]
    if not equippedItem then
        return false
    end

    local itemEntity = equippedItem.entity
    local itemDef = equippedItem.equipDef

    EquipmentPanel.unequipSlot(slotName)

    if itemEntity and registry:valid(itemEntity) then
        signal.emit("equipment_item_returned_to_inventory", slotName, itemEntity, itemDef)
        log_debug("[EquipmentPanel] Emitted item return signal for " .. slotName)
        return true
    end

    return false
end

setupSlotInteractions = function()
    for slotName, slotEntity in pairs(state.slotEntities) do
        if not registry:valid(slotEntity) then
            goto continue
        end
        
        local slotConfig = SLOT_CONFIG[slotName]
        if not slotConfig or not slotConfig.enabled then
            goto continue
        end
        
        local go = component_cache.get(slotEntity, GameObject)
        if not go then
            goto continue
        end

        go.state.rightClickEnabled = true

        go.methods.onClick = function(reg, entity)
            returnEquippedItemFromSlot(slotName)
        end

        go.methods.onRightClick = function(reg, entity)
            returnEquippedItemFromSlot(slotName)
        end
        
        go.methods.onHover = function(reg, hoveredOn, hovered)
            local uiCfg = component_cache.get(hoveredOn, UIConfig)
            if uiCfg and _G.util then
                uiCfg.color = _G.util.getColor("steel_blue")
            end
        end

        go.methods.onStopHover = function()
            local uiCfg = component_cache.get(slotEntity, UIConfig)
            if uiCfg and _G.util then
                uiCfg.color = _G.util.getColor("purple_slate")
            end
        end
        
        ::continue::
    end
    
    log_debug("[EquipmentPanel] Slot interactions setup complete")
end

setupRenderTimer = function()
    local ITEM_Z = 1000
    
    timer.run_every_render_frame(function()
        if not state.isVisible then return end
        
        -- Center each equipped item in its slot
        for slotName, item in pairs(state.equippedItems) do
            if item and item.entity and registry:valid(item.entity) then
                local slotEntity = state.slotEntities[slotName]
                if slotEntity and registry:valid(slotEntity) then
                    centerItemOnSlot(item.entity, slotEntity)
                end
            end
        end
        
        -- Batch render equipped items
        if not (command_buffer and command_buffer.queueDrawBatchedEntities and layers and layers.sprites) then
            return
        end
        
        local equippedItemsList = {}
        for slotName, item in pairs(state.equippedItems) do
            if item and item.entity and registry:valid(item.entity) then
                local animComp = component_cache.get(item.entity, AnimationQueueComponent)
                if animComp then
                    animComp.drawWithLegacyPipeline = true
                end
                local hasPipeline = shader_pipeline and shader_pipeline.ShaderPipelineComponent
                    and registry:has(item.entity, shader_pipeline.ShaderPipelineComponent)
                if hasPipeline and animComp and not animComp.noDraw then
                    table.insert(equippedItemsList, item.entity)
                    animComp.drawWithLegacyPipeline = false
                end
            end
        end
        
        if #equippedItemsList > 0 then
            command_buffer.queueDrawBatchedEntities(layers.sprites, function(cmd)
                cmd.registry = registry
                cmd.entities = equippedItemsList
                cmd.autoOptimize = true
            end, ITEM_Z, layer.DrawCommandSpace.Screen)
        end
    end, nil, "equipment_render_timer", TIMER_GROUP)
    
    log_debug("[EquipmentPanel] Render timer setup complete")
end

function EquipmentPanel.canSlotAccept(slotId, equipmentDef)
    if not SLOT_CONFIG[slotId] then
        return false, "Invalid slot: " .. tostring(slotId)
    end

    if not SLOT_CONFIG[slotId].enabled then
        return false, "Slot is disabled"
    end

    if not equipmentDef then
        return false, "No equipment definition provided"
    end

    if equipmentDef.slot ~= slotId then
        return false, string.format("Equipment slot mismatch: expected %s, got %s", slotId, equipmentDef.slot or "none")
    end

    return true, nil
end

function EquipmentPanel.equipItem(entity, equipDef)
    local slotId = equipDef and equipDef.slot
    
    if not slotId then
        log_warn("[EquipmentPanel] No slot specified in equipment definition")
        return false
    end

    local canAccept, reason = EquipmentPanel.canSlotAccept(slotId, equipDef)
    if not canAccept then
        log_warn("[EquipmentPanel] Cannot equip to " .. slotId .. ": " .. (reason or "unknown reason"))
        return false
    end

    local playerEntity = getPlayerEntity()
    local ctx = getCombatContext()
    
    if not playerEntity then
        log_warn("[EquipmentPanel] Cannot equip - no player entity found")
        return false
    end

    if not ctx then
        log_warn("[EquipmentPanel] Cannot equip - no combat context found")
        return false
    end

    local existingItem = state.equippedItems[slotId]
    if existingItem then
        EquipmentPanel.unequipSlot(slotId)
    end

    local playerScript = getScriptTableFromEntityID and getScriptTableFromEntityID(playerEntity)
    local playerCombatTable = playerScript and playerScript.combatTable
    
    if playerCombatTable then
        local normalizedDef = normalizeEquipmentDef(equipDef)
        local ok, err = combat_system.Game.ItemSystem.equip(ctx, playerCombatTable, normalizedDef)
        if not ok then
            log_warn("[EquipmentPanel] ItemSystem.equip failed: " .. (err or "unknown error"))
            return false
        end
    else
        log_warn("[EquipmentPanel] No combat table found on player")
        return false
    end

    state.equippedItems[slotId] = {
        entity = entity,
        equipDef = equipDef,
    }

    local slotEntity = state.slotEntities[slotId]
    if slotEntity and entity and registry:valid(entity) then
        centerItemOnSlot(entity, slotEntity)
    end

    if add_state_tag then
        add_state_tag(entity, "default_state")
    end

    local go = component_cache.get(entity, GameObject)
    if go then
        go.state.rightClickEnabled = true
        go.methods.onRightClick = function(reg, clickedEntity)
            if state.equippedItems[slotId] and state.equippedItems[slotId].entity == clickedEntity then
                returnEquippedItemFromSlot(slotId)
            end
        end
    end

    signal.emit("equipment_equipped", slotId, equipDef, entity)
    log_debug("[EquipmentPanel] Equipped " .. (equipDef.id or "item") .. " to " .. slotId)
    return true
end

function EquipmentPanel.unequipSlot(slotId)
    if not SLOT_CONFIG[slotId] then
        log_warn("[EquipmentPanel] Invalid slot: " .. tostring(slotId))
        return nil, nil
    end

    local oldItem = state.equippedItems[slotId]
    if not oldItem then
        return nil, nil
    end

    state.equippedItems[slotId] = nil

    local playerEntity = getPlayerEntity()
    local ctx = getCombatContext()
    
    if playerEntity and ctx then
        local playerScript = getScriptTableFromEntityID and getScriptTableFromEntityID(playerEntity)
        local playerCombatTable = playerScript and playerScript.combatTable
        
        if playerCombatTable and oldItem.equipDef then
            local ok, err = combat_system.Game.ItemSystem.unequip(ctx, playerCombatTable, slotId)
            if not ok then
                log_warn("[EquipmentPanel] ItemSystem.unequip failed: " .. (err or "unknown error"))
            end
        end
    end

    signal.emit("equipment_unequipped", slotId, oldItem.equipDef, oldItem.entity)
    log_debug("[EquipmentPanel] Unequipped item from " .. slotId)

    return oldItem.entity, oldItem.equipDef
end

function EquipmentPanel.getEquipped(slotId)
    if not SLOT_CONFIG[slotId] then
        return nil
    end
    return state.equippedItems[slotId]
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
