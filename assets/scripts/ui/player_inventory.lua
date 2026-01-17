--[[
================================================================================
PLAYER INVENTORY - Grid-Based Card Management for Planning Mode
================================================================================

Replaces the world-space inventory board with a proper UI grid system.

USAGE:
------
local PlayerInventory = require("ui.player_inventory")

PlayerInventory.open()           -- Show inventory panel
PlayerInventory.close()          -- Hide inventory panel
PlayerInventory.toggle()         -- Toggle visibility
PlayerInventory.addCard(entity, "actions")   -- Add card to category
PlayerInventory.removeCard(entity)           -- Remove card from inventory

EVENTS (via hump.signal):
-------------------------
"player_inventory_opened"        -- Panel opened
"player_inventory_closed"        -- Panel closed
"card_equipped_to_board"         -- Card moved from inventory to board
"card_returned_to_inventory"     -- Card moved from board to inventory

================================================================================
]]

local PlayerInventory = {}

local dsl = require("ui.ui_syntax_sugar")
local grid = require("core.inventory_grid")
local signal = require("external.hump.signal")
local component_cache = require("core.component_cache")
local timer = require("core.timer")
local InventoryGridInit = require("ui.inventory_grid_init")
local itemRegistry = require("core.item_location_registry")
local shader_pipeline = _G.shader_pipeline
local QuickEquip = require("ui.inventory_quick_equip")
local z_orders = require("core.z_orders")
-- CardUIPolicy required to register signal handlers for planning card elevation
-- This ensures world-space planning cards render above the inventory grid
local CardUIPolicy = require("ui.card_ui_policy")

local TIMER_GROUP = "player_inventory"
local PANEL_ID = "player_inventory_panel"

local TAB_CONFIG = {
    equipment = {
        id = "inv_equipment",
        label = "Equipment",
        icon = "E",
        rows = 3,
        cols = 6,
    },
    wands = {
        id = "inv_wands",
        label = "Wands",
        icon = "W",
        rows = 3,
        cols = 6,
    },
    triggers = {
        id = "inv_triggers",
        label = "Triggers",
        icon = "T",
        rows = 3,
        cols = 6,
    },
    actions = {
        id = "inv_actions",
        label = "Actions",
        icon = "A",
        rows = 3,
        cols = 6,
    },
    modifiers = {
        id = "inv_modifiers",
        label = "Modifiers",
        icon = "M",
        rows = 3,
        cols = 6,
    },
}

local TAB_ORDER = { "equipment", "wands", "triggers", "actions", "modifiers" }

local SPRITE_BASE_W = 32
local SPRITE_BASE_H = 32
local SPRITE_SCALE = 2
local SLOT_WIDTH = SPRITE_BASE_W * SPRITE_SCALE
local SLOT_HEIGHT = SPRITE_BASE_H * SPRITE_SCALE
local SLOT_SPACING = 4
local GRID_ROWS = 3
local GRID_COLS = 6
local GRID_PADDING = 6
local TAB_MARKER_WIDTH = 64
local TAB_MARKER_HEIGHT = 64
local TAB_MARKER_OFFSET_Y = -66

local GRID_WIDTH = GRID_COLS * SLOT_WIDTH + (GRID_COLS - 1) * SLOT_SPACING + GRID_PADDING * 2
local GRID_HEIGHT = GRID_ROWS * SLOT_HEIGHT + (GRID_ROWS - 1) * SLOT_SPACING + GRID_PADDING * 2

local HEADER_HEIGHT = 32
local TABS_HEIGHT = 32
local FOOTER_HEIGHT = 36
local PANEL_PADDING = 10
local PANEL_WIDTH = GRID_WIDTH + PANEL_PADDING * 2
local PANEL_HEIGHT = HEADER_HEIGHT + TABS_HEIGHT + GRID_HEIGHT + FOOTER_HEIGHT + PANEL_PADDING * 2
local RENDER_LAYER = "ui"

local PANEL_Z = 800
local GRID_Z = 850
-- Cards must render ABOVE the panel (z=800) and grid slots (z=850).
-- Must match UI_CARD_Z in inventory_grid_init.lua to prevent z-order reset conflicts.
local CARD_Z = z_orders.ui_tooltips + 100  -- = 1000, above grid (850), below tooltips

local OFFSCREEN_Y_OFFSET = 600

local state = {
    initialized = false,
    isVisible = false,
    panelEntity = nil,
    closeButtonEntity = nil,
    gridContainerEntity = nil,
    activeGrid = nil,
    grids = {},
    tabButtons = {},
    activeTab = "equipment",
    searchFilter = "",
    sortField = nil,
    sortAsc = true,
    lockedCards = {},
    cardRegistry = {},
    signalHandlers = {},
    panelX = 0,
    panelY = 0,
    gridX = 0,
    gridY = 0,
    tabItems = {},
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

--------------------------------------------------------------------------------
-- Debug Helper: Log box and root bounds
--------------------------------------------------------------------------------

local function logBoxBounds(label, entity)
    if not (os.getenv and os.getenv("INVENTORY_BOUNDS_DEBUG") == "1") then
        return
    end

    if not entity or not registry:valid(entity) then
        return
    end

    local t = component_cache.get(entity, Transform)
    local boxComp = component_cache.get(entity, UIBoxComponent)
    local rt = (boxComp and boxComp.uiRoot and registry:valid(boxComp.uiRoot) and component_cache.get(boxComp.uiRoot, Transform)) or nil

    if t and rt then
        log_debug(string.format(
            "[INV-BNDS] %s box=(%.1f,%.1f,%.1f,%.1f) root=(%.1f,%.1f,%.1f,%.1f)",
            tostring(label),
            t.actualX or -1, t.actualY or -1, t.actualW or -1, t.actualH or -1,
            rt.actualX or -1, rt.actualY or -1, rt.actualW or -1, rt.actualH or -1
        ))
    end
end

-- Visibility Control with Y-coordinate Support
--------------------------------------------------------------------------------

local function setEntityVisible(entity, visible, onscreenX, onscreenY, dbgLabel)
    if not entity or not registry:valid(entity) then return end

    local targetX = onscreenX
    local targetY = visible and onscreenY or (GetScreenHeight())

    -- Update Transform for the main entity
    local t = component_cache.get(entity, Transform)
    if t then
        t.actualX = targetX
        t.actualY = targetY
    end

    -- Update InheritedProperties offset (used by layout system)
    local role = component_cache.get(entity, InheritedProperties)
    if role and role.offset then
        role.offset.x = targetX
        role.offset.y = targetY
    end

    -- For UIBox entities, also update the uiRoot
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

        -- Force layout recalculation
        if ui and ui.box and ui.box.RenewAlignment then
            ui.box.RenewAlignment(registry, entity)
        end
    end

    logBoxBounds(tostring(visible and "show" or "hide") .. ":" .. tostring(dbgLabel or ""), entity)
end

local function getTabMarkerPosition()
    if not state.panelX or not state.panelY then
        return nil, nil
    end
    local markerX = state.panelX + (PANEL_WIDTH - TAB_MARKER_WIDTH) / 2
    local markerY = state.panelY + TAB_MARKER_OFFSET_Y
    return markerX, markerY
end

local function positionTabMarker()
    if not state.tabMarkerEntity or not registry:valid(state.tabMarkerEntity) then
        return
    end
    local markerX, markerY = getTabMarkerPosition()
    if not markerX or not markerY then
        return
    end
    setEntityVisible(state.tabMarkerEntity, true, markerX, markerY, "tab_marker")
end

local function setCardEntityVisible(itemEntity, visible)
    if not itemEntity or not registry:valid(itemEntity) then return end
    if visible then
        if add_state_tag then
            add_state_tag(itemEntity, "default_state")
        end
    else
        if clear_state_tags then
            clear_state_tags(itemEntity)
        end
    end
end

local function setAllCardsVisible(visible)
    for itemEntity in pairs(state.cardRegistry) do
        setCardEntityVisible(itemEntity, visible)
    end
end

local function setGridItemsVisible(gridEntity, visible)
    if not gridEntity then return end
    local items = grid.getAllItems(gridEntity)
    for _, itemEntity in pairs(items) do
        setCardEntityVisible(itemEntity, visible)
    end
end

local function createSimpleCard(spriteName, x, y, cardData, gridEntity)
    local entity = animation_system.createAnimatedObjectWithTransform(
        spriteName, true, x or 0, y or 0, nil, true
    )

    if not entity or not registry:valid(entity) then
        log_warn("[PlayerInventory] Failed to create card entity for: " .. tostring(spriteName))
        return nil
    end

    -- NOTE: Do NOT add ObjectAttachedToUITag - it excludes entities from shader rendering pipeline!
    -- Cards need to render via the normal sprite pipeline to respect z-ordering properly.

    -- Set initial state tag for visibility
    if add_state_tag then
        add_state_tag(entity, "default_state")
    end

    -- Setup shader pipeline BEFORE resize (shader may affect rendering)
    if shader_pipeline and shader_pipeline.ShaderPipelineComponent then
        local shaderPipelineComp = registry:emplace(entity, shader_pipeline.ShaderPipelineComponent)
        shaderPipelineComp:addPass("3d_skew")

        local skewSeed = math.random() * 10000
        local passes = shaderPipelineComp.passes
        if passes and #passes >= 1 then
            local pass = passes[#passes]
            if pass and pass.shaderName and pass.shaderName:sub(1, 7) == "3d_skew" then
                pass.customPrePassFunction = function()
                    if globalShaderUniforms then
                        globalShaderUniforms:set(pass.shaderName, "rand_seed", skewSeed)
                    end
                end
            end
        end
    end

    -- Setup script data
    local scriptData = {
        entity = entity,
        id = cardData.id,
        name = cardData.name,
        element = cardData.element,
        stackId = cardData.stackId,
        category = "card",
        cardData = cardData,
        noVisualSnap = true,
    }

    if setScriptTableForEntityID then
        setScriptTableForEntityID(entity, scriptData)
    end

    state.cardRegistry[entity] = scriptData

    -- Use CardUIPolicy for screen-space setup AFTER all other setup is complete
    -- This handles: transform space, z-order, resize to inventory slot size, interaction states
    -- CRITICAL: Must happen AFTER shader pipeline is set up for correct uiRenderScale
    CardUIPolicy.setupForScreenSpace(entity)

    -- Setup drag-drop with proper z-order management via InventoryGridInit
    InventoryGridInit.makeItemDraggable(entity, gridEntity)

    return entity
end

-- Creates a grid definition (template node) WITHOUT spawning.
-- Returns the DSL definition that can be passed to ui.box.AddChild
local function createGridDefinition(tabId)
    local cfg = TAB_CONFIG[tabId]
    if not cfg then return nil end

    return dsl.strict.inventoryGrid {
        id = cfg.id,
        rows = GRID_ROWS,
        cols = GRID_COLS,
        slotSize = { w = SLOT_WIDTH, h = SLOT_HEIGHT },
        slotSpacing = SLOT_SPACING,

        config = {
            allowDragIn = true,
            allowDragOut = true,
            stackable = false,
            slotSprite = "test-inventory-square-single.png",
            padding = GRID_PADDING,
            backgroundColor = "blackberry",
            snapVisual = false,
        },

        onSlotChange = function(gridEntity, slotIndex, oldItem, newItem)
            log_debug("[PlayerInventory:" .. tabId .. "] Slot " .. slotIndex .. " changed")
        end,

        onSlotClick = function(gridEntity, slotIndex, button)
            if button == 2 then
                local item = grid.getItemAtIndex(gridEntity, slotIndex)
                if item and registry:valid(item) then
                    local isLocked = state.lockedCards[item]
                    state.lockedCards[item] = not isLocked
                    signal.emit(isLocked and "card_unlocked" or "card_locked", item)
                end
            end
        end,
    }
end

local function getTabSlotCount(tabId)
    local cfg = TAB_CONFIG[tabId]
    local rows = cfg and cfg.rows or GRID_ROWS
    local cols = cfg and cfg.cols or GRID_COLS
    return rows * cols
end

local function getTabItemStore(tabId)
    if not state.tabItems[tabId] then
        state.tabItems[tabId] = {}
    end
    return state.tabItems[tabId]
end

local function findEmptyStoredSlot(tabId)
    local store = getTabItemStore(tabId)
    local slotCount = getTabSlotCount(tabId)
    for i = 1, slotCount do
        if not store[i] then
            return i
        end
    end
    return nil
end

local function stashGridItems(tabId, gridEntity)
    if not gridEntity then return end
    local store = getTabItemStore(tabId)
    for k in pairs(store) do
        store[k] = nil
    end

    local items = grid.getAllItems(gridEntity)
    for slotIndex, itemEntity in pairs(items) do
        if itemEntity and registry:valid(itemEntity) then
            store[slotIndex] = itemEntity
            grid.removeItem(gridEntity, slotIndex)
            setCardEntityVisible(itemEntity, false)
        end
    end
end

local function restoreGridItems(tabId, gridEntity)
    if not gridEntity then return end
    local store = state.tabItems[tabId]
    if not store then return end

    for slotIndex, itemEntity in pairs(store) do
        if itemEntity and registry:valid(itemEntity) then
            InventoryGridInit.makeItemDraggable(itemEntity, gridEntity)
            local success, placedSlot = grid.addItem(gridEntity, itemEntity, slotIndex)
            if success then
                local slotEntity = grid.getSlotEntity(gridEntity, placedSlot or slotIndex)
                if slotEntity then
                    InventoryGridInit.centerItemOnSlot(itemEntity, slotEntity, false)
                end
                setCardEntityVisible(itemEntity, state.isVisible)
            else
                log_warn("[PlayerInventory] Failed to restore item to tab '" .. tostring(tabId) .. "' slot " .. tostring(slotIndex))
            end
        end
    end
end

local function cleanupGridEntity(gridEntity, tabId)
    if not gridEntity then return end

    InventoryGridInit.unregisterGridForDragFeedback(gridEntity)

    local cfg = TAB_CONFIG[tabId]
    if cfg then
        local slotCount = getTabSlotCount(tabId)
        for i = 1, slotCount do
            local slotEntity = grid.getSlotEntity(gridEntity, i)
            if slotEntity then
                InventoryGridInit.cleanupSlotMetadata(slotEntity)
            end
        end
        itemRegistry.clearGrid(gridEntity)
        grid.cleanup(gridEntity)
        dsl.cleanupGrid(cfg.id)
    end
end

local function injectGridForTab(tabId)
    if not state.gridContainerEntity or not registry:valid(state.gridContainerEntity) then
        log_warn("[PlayerInventory] Grid container not available for tab injection")
        return nil
    end

    local gridDef = createGridDefinition(tabId)
    if not gridDef then
        log_warn("[PlayerInventory] No grid definition for tab " .. tostring(tabId))
        return nil
    end

    local replaced = ui.box.ReplaceChildren(state.gridContainerEntity, gridDef)
    if not replaced then
        log_warn("[PlayerInventory] Failed to replace grid container children for tab " .. tostring(tabId))
        return nil
    end

    -- Reapply state tags so newly injected elements render
    if ui and ui.box and ui.box.AddStateTagToUIBox then
        ui.box.AddStateTagToUIBox(registry, state.panelEntity, "default_state")
    end

    local cfg = TAB_CONFIG[tabId]
    local gridEntity = cfg and ui.box.GetUIEByID(registry, state.gridContainerEntity, cfg.id) or nil
    if not gridEntity then
        log_warn("[PlayerInventory] Could not find injected grid entity for tab " .. tostring(tabId))
        return nil
    end

    local success = InventoryGridInit.initializeIfGrid(gridEntity, cfg.id)
    if success then
        log_debug("[PlayerInventory] Injected grid initialized for tab " .. tostring(tabId))
    else
        log_warn("[PlayerInventory] Injected grid init failed for tab " .. tostring(tabId))
    end

    return gridEntity
end



local function switchTab(tabId)
    if state.activeTab == tabId then return end

    local oldTab = state.activeTab
    local oldGrid = state.activeGrid

    if oldGrid then
        stashGridItems(oldTab, oldGrid)
        cleanupGridEntity(oldGrid, oldTab)
        state.grids[oldTab] = nil
    end

    state.activeTab = tabId
    state.activeGrid = injectGridForTab(tabId)
    state.grids[tabId] = state.activeGrid

    if state.activeGrid then
        restoreGridItems(tabId, state.activeGrid)
    end

    if state.isVisible then
        setAllCardsVisible(false)
        if state.activeGrid then
            setGridItemsVisible(state.activeGrid, true)
        end
    end

    -- Update tab button highlighting
    for id, btnEntity in pairs(state.tabButtons or {}) do
        if btnEntity and registry:valid(btnEntity) then
            local isActive = (id == tabId)
            local uiCfg = component_cache.get(btnEntity, UIConfig)
            if uiCfg and _G.util and _G.util.getColor then
                uiCfg.color = isActive and _G.util.getColor("steel_blue") or _G.util.getColor("gray")
            end
        end
    end

    log_debug("[PlayerInventory] Switched tab: " .. oldTab .. " -> " .. tabId)
end

local CLOSE_BUTTON_SIZE = 24

local function createHeader()
    -- Header width: panel content area = PANEL_WIDTH - 2*PANEL_PADDING
    -- But we need to account for the header's own padding
    local headerContentWidth = PANEL_WIDTH - 2 * PANEL_PADDING
    return dsl.hbox {
        config = {
            id = "inventory_header",
            color = "dark_lavender",
            -- emboss = 2,
            padding = 3
            -- minWidth = headerContentWidth,
            -- minHeight = HEADER_HEIGHT,
        },
        children = {
            dsl.strict.text("Inventory", {
                id = "header_title",
                fontSize = 14,
                color = "gold",
                shadow = true,
            }),
            dsl.filler(), -- Filler expands to push close button to the right edge
            dsl.strict.button("X", {
                id = "close_btn",
                fontSize = 12,
                color = "dark_red",
                onClick = function()
                    local PlayerInventory = require("ui.player_inventory")
                    PlayerInventory.close()
                end,
            }),
        },
    }
end

-- Legacy createCloseButton for backward compatibility (if called elsewhere)
local function createCloseButton(panelX, panelY, panelWidth)
    local closeButtonDef = dsl.strict.button("X", {
        id = "close_btn_legacy",
        minWidth = CLOSE_BUTTON_SIZE,
        minHeight = CLOSE_BUTTON_SIZE,
        fontSize = 12,
        color = "darkred",
        onClick = function()
            PlayerInventory.close()
        end,
    })

    -- Position button with consistent margins matching PANEL_PADDING
    -- Right margin: button right edge should be PANEL_PADDING from panel right edge
    -- Top margin: button top edge should be PANEL_PADDING from panel top edge
    local closeX = panelX + panelWidth - PANEL_PADDING - CLOSE_BUTTON_SIZE
    local closeY = panelY + PANEL_PADDING

    local closeEntity = dsl.spawn({ x = closeX, y = closeY }, closeButtonDef, RENDER_LAYER, CARD_Z + 10)
    -- Explicitly set to sprites layer so z-ordering works with planning cards
    if ui and ui.box and ui.box.set_draw_layer then
        ui.box.set_draw_layer(closeEntity, "sprites")
    end

    return closeEntity
end

local function createTabs()
    local tabChildren = {}

    for _, tabId in ipairs(TAB_ORDER) do
        local cfg = TAB_CONFIG[tabId]
        local isActive = (tabId == state.activeTab)

        table.insert(tabChildren, dsl.strict.button(cfg.label, {
            id = "tab_" .. tabId,
            fontSize = 10,
            color = isActive and "steel_blue" or "gray",
            onClick = function()
                switchTab(tabId)
            end,
        }))

        if tabId ~= TAB_ORDER[#TAB_ORDER] then
            table.insert(tabChildren, dsl.strict.spacer(2))
        end
    end

    return dsl.strict.hbox {
        config = {
            color = "blackberry",
            padding = { 4, 2 },
        },
        children = tabChildren,
    }
end

local function createFooter()
    return dsl.strict.hbox {
        config = {
            color = "dark_lavender",
            padding = { 6, 4 },
            minWidth = GRID_WIDTH,
            minHeight = FOOTER_HEIGHT,
        },
        children = {
            dsl.strict.button("Name", {
                id = "sort_name_btn",
                minWidth = 50,
                minHeight = 24,
                fontSize = 10,
                color = "purple_slate",
                onClick = function()
                    log_debug("[PlayerInventory] Sort by name clicked")
                end,
            }),
            -- dsl.strict.spacer(4),
            dsl.strict.button("Cost", {
                id = "sort_cost_btn",
                minWidth = 50,
                minHeight = 24,
                fontSize = 10,
                color = "purple_slate",
                onClick = function()
                    log_debug("[PlayerInventory] Sort by cost clicked")
                end,
            }),
            -- dsl.spacer(1),
            dsl.text("0 / 18", { id = "slot_count_text", fontSize = 10, color = "light_gray" }),
        },
    }
end

local function createGridContainer()
    return dsl.strict.vbox {
        config = {
            id = "inventory_grid_container",
            padding = 0,
            minWidth = GRID_WIDTH,
            minHeight = GRID_HEIGHT,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
        },
        children = {}
    }
end

local function createPanelDefinition()
    return dsl.strict.root {
        config = {
            id = PANEL_ID,
            color = "blackberry",
            padding = PANEL_PADDING,
            emboss = 3,
            -- Grid area is a child container; active grid is injected at runtime
            minHeight = HEADER_HEIGHT + TABS_HEIGHT + FOOTER_HEIGHT + PANEL_PADDING * 2,
        },
        children = {
            createHeader(),
            createTabs(),
            createGridContainer(),
            createFooter(),
        },
    }
end

local function snapItemsToSlots()
    local activeGrid = state.activeGrid
    if not activeGrid then return end

    local inputState = input and input.getState and input.getState()
    local draggedEntity = inputState and inputState.cursor_dragging_target

    local items = grid.getAllItems(activeGrid)
    for slotIndex, itemEntity in pairs(items) do
        if itemEntity and registry:valid(itemEntity) then
            if itemEntity ~= draggedEntity then
                local slotEntity = grid.getSlotEntity(activeGrid, slotIndex)
                if slotEntity then
                    InventoryGridInit.centerItemOnSlot(itemEntity, slotEntity, false)
                end
            end
        end
    end
end

local function isCardInActiveGrid(eid)
    local activeGrid = state.activeGrid
    if not activeGrid then return false end

    local location = itemRegistry.getLocation(eid)
    return location and location.grid == activeGrid
end

local function setupCardRenderTimer()
    local UI_CARD_Z = CARD_Z
    
    timer.run_every_render_frame(function()
        if not state.isVisible then return end

        snapItemsToSlots()
        
        local batchedCardBuckets = {}
        
        -- Use sprites layer so planning cards (also on sprites) can z-sort correctly
        if not (command_buffer and command_buffer.queueDrawBatchedEntities and layers and layers.sprites) then
            return
        end
        
        for eid, cardScript in pairs(state.cardRegistry) do
            if eid and registry:valid(eid) and isCardInActiveGrid(eid) then
                local hasPipeline = shader_pipeline and shader_pipeline.ShaderPipelineComponent
                    and registry:has(eid, shader_pipeline.ShaderPipelineComponent)
                local animComp = component_cache.get(eid, AnimationQueueComponent)

                if animComp then
                    animComp.drawWithLegacyPipeline = true
                end

                if hasPipeline and animComp and not animComp.noDraw then
                    -- Use entity's actual z-order (respects drag z-order changes)
                    -- This ensures dragged cards render above other cards
                    local zToUse = UI_CARD_Z
                    if layer_order_system and layer_order_system.getZIndex then
                        local entityZ = layer_order_system.getZIndex(eid)
                        if entityZ and entityZ > 0 then
                            zToUse = entityZ
                        end
                    end

                    local bucket = batchedCardBuckets[zToUse]
                    if not bucket then
                        bucket = {}
                        batchedCardBuckets[zToUse] = bucket
                    end
                    bucket[#bucket + 1] = eid
                    animComp.drawWithLegacyPipeline = false
                end
            end
        end
        
        if next(batchedCardBuckets) then
            local zKeys = {}
            for z, entityList in pairs(batchedCardBuckets) do
                if #entityList > 0 then
                    table.insert(zKeys, z)
                end
            end
            table.sort(zKeys)
            
            for _, z in ipairs(zKeys) do
                local entityList = batchedCardBuckets[z]
                if entityList and #entityList > 0 then
                    -- Render to sprites layer (not ui) so z-ordering works with planning cards
                    command_buffer.queueDrawBatchedEntities(layers.sprites, function(cmd)
                        cmd.registry = registry
                        cmd.entities = entityList
                        cmd.autoOptimize = true
                    end, z, layer.DrawCommandSpace.Screen)
                end
            end
        end
        
    end, nil, "inventory_card_render_timer", TIMER_GROUP)
end

local function setupSignalHandlers()
    local function registerHandler(eventName, handler)
        signal.register(eventName, handler)
        table.insert(state.signalHandlers, { event = eventName, handler = handler })
    end
    
    local function isOurGrid(gridEntity)
        return gridEntity == state.activeGrid
    end
    
    registerHandler("grid_item_added", function(gridEntity, slotIndex, itemEntity)
        if isOurGrid(gridEntity) then
            log_debug("[PlayerInventory] Item added to slot " .. slotIndex)
            if playSoundEffect then
                playSoundEffect("effects", "button-click")
            end
        end
    end)
    
    registerHandler("grid_item_removed", function(gridEntity, slotIndex, itemEntity)
        if isOurGrid(gridEntity) then
            log_debug("[PlayerInventory] Item removed from slot " .. slotIndex)
        end
    end)
    
    registerHandler("grid_item_moved", function(gridEntity, fromSlot, toSlot, itemEntity)
        if isOurGrid(gridEntity) then
            log_debug("[PlayerInventory] Item moved from slot " .. fromSlot .. " to " .. toSlot)
        end
    end)
    
    registerHandler("grid_items_swapped", function(gridEntity, slot1, slot2, item1, item2)
        if isOurGrid(gridEntity) then
            log_debug("[PlayerInventory] Items swapped between slots " .. slot1 .. " and " .. slot2)
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
    -- Reset input handler flag so it re-registers on next game
    state.inputHandlerInitialized = false
    -- Reset game state handler flag
    state.gameStateHandlerRegistered = false
end

-- Export for cleanup from gameplay.lua resetGameToStart()
PlayerInventory.cleanupSignalHandlers = cleanupSignalHandlers

--------------------------------------------------------------------------------
-- Input Handling: Tab Key Toggle
--------------------------------------------------------------------------------

local function setupInputHandler()
    if state.inputHandlerInitialized then return end
    state.inputHandlerInitialized = true

    log_debug("[PlayerInventory] Setting up input handler for Tab key")

    local callbackRunOnce = false
    timer.run_every_render_frame(function()
        -- One-time verification that callback runs
        if not callbackRunOnce then
            callbackRunOnce = true
            log_debug("[PlayerInventory] Input handler callback is running")
        end

        -- 'I' key to toggle inventory (standard keybind)
        -- Note: KEY_TAB not available in isKeyPressed enum
        local iPressed = isKeyPressed and isKeyPressed("KEY_I")

        if iPressed then
            log_debug("[PlayerInventory] Inventory key pressed - toggling")
            PlayerInventory.toggle()
        end

        -- ESC to close (if open)
        if state.isVisible and isKeyPressed and isKeyPressed("KEY_ESCAPE") then
            PlayerInventory.close()
        end
    end, nil, "player_inventory_input", TIMER_GROUP)
end

-- Also expose a way to manually trigger setup after game systems are ready
function PlayerInventory.ensureInputHandler()
    setupInputHandler()
end

local function calculatePositions()
    local screenW = globals.screenWidth()
    local screenH = globals.screenHeight()

    -- Guard against invalid screen dimensions
    if not screenW or not screenH or screenW <= 0 or screenH <= 0 then
        log_debug("[PlayerInventory] Skipping position calc - screen not ready: " ..
                  tostring(screenW) .. "x" .. tostring(screenH))
        return false
    end

    state.panelX = (screenW - PANEL_WIDTH) / 2
    state.panelY = screenH - PANEL_HEIGHT - 10
    state.gridX = state.panelX + PANEL_PADDING
    state.gridY = state.panelY + HEADER_HEIGHT + TABS_HEIGHT + PANEL_PADDING

    return true
end

local function initializeInventory()
    if state.initialized then return end

    if not calculatePositions() then
        log_warn("[PlayerInventory] Cannot initialize - screen dimensions not ready")
        return
    end
    
    -- make tab that sticks out the top
    -- local tabDef = dsl.hbox {
    --     config = {
    --     },
    --     children = {
    --         dsl.anim("inventory-tab-marker.png", { w = 64, h = 64 })
    --     }
    -- }
    
    local tabDef = dsl.hbox {
        config = {
            canCollide = true,
            hover = true,
            padding = 0,
            minWidth = TAB_MARKER_WIDTH,
            minHeight = TAB_MARKER_HEIGHT,
            buttonCallback = function()
                PlayerInventory.toggle()
            end
        },
        children = {
            dsl.anim("inventory-tab-marker.png", { w = TAB_MARKER_WIDTH, h = TAB_MARKER_HEIGHT })
        }
    }
    
    local markerX, markerY = getTabMarkerPosition()
    state.tabMarkerEntity = dsl.spawn(
        { x = markerX or state.panelX, y = markerY or state.panelY },
        tabDef,
        RENDER_LAYER,
        PANEL_Z - 1
    ) -- Just below panel

    local panelDef = createPanelDefinition()
    state.panelEntity = dsl.spawn({ x = state.panelX, y = state.panelY + OFFSCREEN_Y_OFFSET }, panelDef, RENDER_LAYER, PANEL_Z)
    -- Explicitly set to sprites layer so z-ordering works with planning cards
    if ui and ui.box and ui.box.set_draw_layer then
        ui.box.set_draw_layer(state.panelEntity, "sprites")
        ui.box.set_draw_layer(state.tabMarkerEntity, "sprites")
    end
    
    -- CRITICAL: Add state tags to UI boxes so they render
    -- This propagates the state tag to all UI elements including the wrapped animated sprite
    if ui and ui.box and ui.box.AddStateTagToUIBox then
        ui.box.AddStateTagToUIBox(registry, state.tabMarkerEntity, "default_state")
        ui.box.AddStateTagToUIBox(registry, state.panelEntity, "default_state")
    end

    
    positionTabMarker()
      
    -- ui.box.ClearStateTagsFromUIBox(state.tabMarkerEntity)
    -- ui.box.AssignStateTagsToUIBox(registry, state.tabMarkerEntity, PLANNING_STATE)

    -- Close button is now part of the header in the panel hierarchy
    state.closeButtonEntity = ui.box.GetUIEByID(registry, state.panelEntity, "close_btn")
    if not state.closeButtonEntity then
        log_debug("[PlayerInventory] WARNING: Could not find close_btn in panel hierarchy")
    end

    state.gridContainerEntity = ui.box.GetUIEByID(registry, state.panelEntity, "inventory_grid_container")
    if not state.gridContainerEntity then
        log_warn("[PlayerInventory] WARNING: Could not find inventory_grid_container in panel hierarchy")
    end

    state.tabButtons = {}
    for _, tabId in ipairs(TAB_ORDER) do
        local btnEntity = ui.box.GetUIEByID(registry, state.panelEntity, "tab_" .. tabId)
        if btnEntity then
            state.tabButtons[tabId] = btnEntity
        end
    end

    state.activeGrid = injectGridForTab(state.activeTab)
    if state.activeGrid then
        state.grids[state.activeTab] = state.activeGrid
        restoreGridItems(state.activeTab, state.activeGrid)
    end
    
    setupSignalHandlers()
    setupCardRenderTimer()

    QuickEquip.init()

    state.initialized = true
    log_debug("[PlayerInventory] Initialized (hidden)")
end

function PlayerInventory.open()
    if not state.initialized then
        initializeInventory()
    end

    if state.isVisible then return end

    -- Show the panel
    setEntityVisible(state.panelEntity, true, state.panelX, state.panelY, "panel")
    positionTabMarker()

    state.isVisible = true

    -- Ensure active grid exists for current tab
    if not state.activeGrid then
        state.activeGrid = injectGridForTab(state.activeTab)
        if state.activeGrid then
            state.grids[state.activeTab] = state.activeGrid
            restoreGridItems(state.activeTab, state.activeGrid)
        end
    end

    setAllCardsVisible(false)
    if state.activeGrid then
        setGridItemsVisible(state.activeGrid, true)
    end
    snapItemsToSlots()

    signal.emit("player_inventory_opened")

    -- Elevate planning cards above the inventory panel
    CardUIPolicy.elevatePlanningCards()

    if playSoundEffect then
        playSoundEffect("effects", "button-click")
    end

    log_debug("[PlayerInventory] Opened")
end

function PlayerInventory.close()
    if not state.isVisible then return end

    -- Hide the panel
    setEntityVisible(state.panelEntity, false, state.panelX, state.panelY, "panel")
    positionTabMarker()

    state.isVisible = false

    -- Keep cards aligned with the grid as it moves offscreen
    snapItemsToSlots()

    -- Hide all inventory cards (they are separate sprite entities)
    setAllCardsVisible(false)
    signal.emit("player_inventory_closed")

    -- Restore planning cards to normal z-order
    CardUIPolicy.resetPlanningCards()

    log_debug("[PlayerInventory] Closed (hidden)")
end

function PlayerInventory.toggle()
    if state.isVisible then
        PlayerInventory.close()
    else
        PlayerInventory.open()
    end
end

function PlayerInventory.isOpen()
    return state.isVisible
end

function PlayerInventory.destroy()
    if not state.initialized then return end

    log_debug("[PlayerInventory] Destroying...")

    -- Cleanup quick equip system
    QuickEquip.destroy()

    cleanupSignalHandlers()
    timer.kill_group(TIMER_GROUP)
    
    for _, cardEntity in pairs(state.cardRegistry) do
        if cardEntity and registry:valid(cardEntity) then
            registry:destroy(cardEntity)
        end
    end
    state.cardRegistry = {}
    
    if state.activeGrid then
        stashGridItems(state.activeTab, state.activeGrid)
        cleanupGridEntity(state.activeGrid, state.activeTab)
    end
    state.activeGrid = nil
    state.grids = {}
    state.tabItems = {}
    state.gridContainerEntity = nil

    -- Close button is part of panel hierarchy, cleaned up when panel is removed
    state.closeButtonEntity = nil

    if state.panelEntity and registry:valid(state.panelEntity) then
        if ui and ui.box and ui.box.Remove then
            ui.box.Remove(registry, state.panelEntity)
        end
    end
    state.panelEntity = nil
    state.tabButtons = {}
    if state.tabMarkerEntity and registry:valid(state.tabMarkerEntity) then
        if ui and ui.box and ui.box.Remove then
            ui.box.Remove(registry, state.tabMarkerEntity)
        else
            registry:destroy(state.tabMarkerEntity)
        end
    end
    state.tabMarkerEntity = nil
    
    state.initialized = false
    state.isVisible = false
    
    log_debug("[PlayerInventory] Destroyed")
end

function PlayerInventory.addCard(cardEntity, category, cardData)
    if not state.initialized then
        initializeInventory()
    end
    
    category = category or state.activeTab
    local cfg = TAB_CONFIG[category]
    if not cfg then
        log_warn("[PlayerInventory] Unknown category: " .. tostring(category))
        return false
    end
    local gridEntity = state.grids[category]
    if not gridEntity and category == state.activeTab then
        state.activeGrid = injectGridForTab(state.activeTab)
        state.grids[state.activeTab] = state.activeGrid
        gridEntity = state.activeGrid
        if gridEntity then
            restoreGridItems(state.activeTab, gridEntity)
        end
    end
    
    if cardData then
        state.cardRegistry[cardEntity] = cardData
    end

    -- NOTE: Do NOT add ObjectAttachedToUITag - it excludes entities from shader rendering pipeline!

    -- Use CardUIPolicy for proper screen-space setup INCLUDING RESIZE
    -- This handles: transform space, z-order, resize to inventory slot size, interaction states
    CardUIPolicy.setupForScreenSpace(cardEntity)
    local script = getScriptTableFromEntityID and getScriptTableFromEntityID(cardEntity)
    if script then
        script.noVisualSnap = true
    end

    if gridEntity then
        -- Setup drag-drop with proper z-order management via InventoryGridInit
        InventoryGridInit.makeItemDraggable(cardEntity, gridEntity)

        local success, slotIndex = grid.addItem(gridEntity, cardEntity)
        if success then
        local slotEntity = grid.getSlotEntity(gridEntity, slotIndex)
        if slotEntity then
            InventoryGridInit.centerItemOnSlot(cardEntity, slotEntity, false)
        end
            setCardEntityVisible(cardEntity, state.isVisible)
            log_debug("[PlayerInventory] Added card to " .. category .. " slot " .. slotIndex)
            return true
        end

        return false
    end

    -- Store for inactive tab; will be injected on demand
    local slotIndex = findEmptyStoredSlot(category)
    if not slotIndex then
        log_warn("[PlayerInventory] No free slots in stored tab: " .. tostring(category))
        return false
    end

    local store = getTabItemStore(category)
    store[slotIndex] = cardEntity
    InventoryGridInit.makeItemDraggable(cardEntity, nil)
    setCardEntityVisible(cardEntity, false)
    log_debug("[PlayerInventory] Queued card for tab " .. category .. " slot " .. slotIndex)
    return true
end

function PlayerInventory.removeCard(cardEntity)
    if state.activeGrid then
        local slotIndex = grid.findSlotContaining(state.activeGrid, cardEntity)
        if slotIndex then
            grid.removeItem(state.activeGrid, slotIndex)
            state.cardRegistry[cardEntity] = nil
            state.lockedCards[cardEntity] = nil
            setCardEntityVisible(cardEntity, false)
            log_debug("[PlayerInventory] Removed card from " .. state.activeTab .. " slot " .. slotIndex)
            return true
        end
    end

    for tabId, store in pairs(state.tabItems) do
        for slotIndex, itemEntity in pairs(store) do
            if itemEntity == cardEntity then
                store[slotIndex] = nil
                itemRegistry.unregister(cardEntity)
                state.cardRegistry[cardEntity] = nil
                state.lockedCards[cardEntity] = nil
                setCardEntityVisible(cardEntity, false)
                log_debug("[PlayerInventory] Removed card from stored tab " .. tabId .. " slot " .. slotIndex)
                return true
            end
        end
    end

    return false
end

function PlayerInventory.getActiveTab()
    return state.activeTab
end

function PlayerInventory.getGrids()
    return state.grids
end

--- Get the grid entity for a specific tab/category.
-- @param tabId string Tab identifier ("triggers", "actions", "modifiers", "equipment", "wands")
-- @return number|nil Grid entity or nil if not found
function PlayerInventory.getGridForTab(tabId)
    if not state.initialized then
        return nil
    end
    if tabId == state.activeTab then
        return state.activeGrid
    end
    return state.grids[tabId]
end

--- Get stored (inactive) tab items by slot index.
-- @param tabId string Tab identifier
-- @return table Map of slotIndex -> itemEntity (may be empty)
function PlayerInventory.getStoredItemsForTab(tabId)
    return state.tabItems[tabId] or {}
end

function PlayerInventory.getLockedCards()
    return state.lockedCards
end

--- Get the main panel entity for validation/testing.
-- @return number|nil Panel entity or nil if not initialized
function PlayerInventory.getPanelEntity()
    return state.panelEntity
end

--- Get the close button entity for validation/testing.
-- @return entity|nil Close button entity
function PlayerInventory.getCloseButtonEntity()
    return state.closeButtonEntity
end

--- Get the card registry for validation/testing.
-- @return table Map of cardEntity -> cardData
function PlayerInventory.getCardRegistry()
    return state.cardRegistry
end

function PlayerInventory.spawnDummyCards()
    if not state.initialized then
        initializeInventory()
    end

    if not state.activeGrid then
        state.activeGrid = injectGridForTab(state.activeTab)
        if state.activeGrid then
            state.grids[state.activeTab] = state.activeGrid
            restoreGridItems(state.activeTab, state.activeGrid)
        end
    end

    local cards = {
        { id = "fireball", name = "Fireball", sprite = "card-new-test-action.png", element = "Fire", stackId = "fireball" },
        { id = "ice_shard", name = "Ice Shard", sprite = "card-new-test-action.png", element = "Ice", stackId = "ice_shard" },
        { id = "trigger", name = "Trigger", sprite = "card-new-test-trigger.png", element = nil, stackId = "trigger" },
        { id = "modifier", name = "Modifier", sprite = "card-new-test-modifier.png", element = nil, stackId = "modifier" },
    }

    local activeGrid = state.activeGrid
    for i, cardDef in ipairs(cards) do
        -- Pass gridEntity to createSimpleCard for proper drag setup
        local entity = createSimpleCard(cardDef.sprite, -9999, -9999, cardDef, activeGrid)
        if entity and activeGrid then
            local success, slotIndex = grid.addItem(activeGrid, entity)
            if success then
                local slotEntity = grid.getSlotEntity(activeGrid, slotIndex)
                if slotEntity then
                    InventoryGridInit.centerItemOnSlot(entity, slotEntity, false)
                end
                setCardEntityVisible(entity, state.isVisible)
                log_debug("[PlayerInventory] Added dummy card " .. cardDef.name .. " to slot " .. slotIndex)
            end
        end
    end

    log_debug("[PlayerInventory] Spawned " .. #cards .. " dummy cards")
end

-- Setup input handler via signal after game systems are ready
-- Guarded to prevent handler accumulation on game restart
if not state.gameStateHandlerRegistered then
    state.gameStateHandlerRegistered = true
    local gameStateHandler = function(data)
        if not data or not data.current then
            return
        end
        if data.current == "PLANNING" and not state.initialized then
            initializeInventory()
        end
        if data.current == "PLANNING" or data.current == "ACTION" then
            setupInputHandler()
        end
    end
    signal.register("game_state_changed", gameStateHandler)
    table.insert(state.signalHandlers, { event = "game_state_changed", handler = gameStateHandler })
end

-- Also setup immediately in case we're already in a game phase
timer.after_opts({
    delay = 0.1,
    action = function()
        setupInputHandler()
        if not state.initialized and is_state_active and PLANNING_STATE and is_state_active(PLANNING_STATE) then
            initializeInventory()
        end
    end,
    tag = "player_inventory_input_setup"
})

log_debug("[PlayerInventory] Module loaded")

return PlayerInventory
