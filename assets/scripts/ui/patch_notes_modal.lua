--[[
================================================================================
Patch Notes Modal
================================================================================
Displays patch notes in a modal overlay accessible from the main menu.
Players see a corner icon with a red notification dot for unread notes.

Features:
- Localized patch notes from JSON files
- Persistent read state in save file
- Dismissable via X button, click outside, or ESC key
- Scrollable content area
]]

local PatchNotesModal = {}

local json = require("external.json")
local signal = require("external.hump.signal")
local z_orders = require("core.z_orders")
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
local layer_order_system = _G.layer_order_system
local SaveManager = require("core.save_manager")

-- Module state
PatchNotesModal.isOpen = false
PatchNotesModal._data = nil
PatchNotesModal._backdrop = nil
PatchNotesModal._modalBox = nil
PatchNotesModal._closeButton = nil
PatchNotesModal._lastReadVersion = ""

-- Modal dimensions
local MODAL_WIDTH = 500
local MODAL_HEIGHT = 400
local BACKDROP_ALPHA = 180

--------------------------------------------------------------------------------
-- Save System Integration
--------------------------------------------------------------------------------

-- Register collector for save/load
SaveManager.register("patch_notes", {
    collect = function()
        return {
            last_read_version = PatchNotesModal._lastReadVersion
        }
    end,
    distribute = function(data)
        PatchNotesModal._lastReadVersion = data.last_read_version or ""
    end
})

--------------------------------------------------------------------------------
-- Patch Notes Data Loading
--------------------------------------------------------------------------------

--- Load patch notes JSON for current locale with English fallback
---@return table|nil
local function loadPatchNotes()
    local currentLang = localization.getCurrentLanguage() or "en_us"
    local relativePath = "localization/patch_notes_" .. currentLang .. ".json"
    local path = util.getRawAssetPathNoUUID(relativePath)
    
    local content = save_io.load_file(path)
    if not content then
        if currentLang ~= "en_us" then
            print("[PatchNotesModal] WARN: Missing patch notes for " .. currentLang .. ", falling back to en_us")
            relativePath = "localization/patch_notes_en_us.json"
            path = util.getRawAssetPathNoUUID(relativePath)
            content = save_io.load_file(path)
        end
    end
    
    if not content then
        print("[PatchNotesModal] ERROR: No patch notes found")
        return nil
    end
    
    local success, data = pcall(json.decode, content)
    if not success or type(data) ~= "table" then
        print("[PatchNotesModal] ERROR: Failed to parse patch notes JSON")
        return nil
    end
    
    return data
end

--- Check if there are unread patch notes
---@return boolean
function PatchNotesModal.hasUnread()
    if not PatchNotesModal._data then
        PatchNotesModal._data = loadPatchNotes()
    end
    
    if not PatchNotesModal._data then
        return false
    end
    
    return PatchNotesModal._data.version ~= PatchNotesModal._lastReadVersion
end

--- Mark patch notes as read
local function markAsRead()
    if PatchNotesModal._data then
        PatchNotesModal._lastReadVersion = PatchNotesModal._data.version
        SaveManager.save()
    end
end

--------------------------------------------------------------------------------
-- Screen Utilities
--------------------------------------------------------------------------------

local function resolveScreen()
    local screenW = (globals and globals.screenWidth and globals.screenWidth()) or 1920
    local screenH = (globals and globals.screenHeight and globals.screenHeight()) or 1080
    return screenW, screenH
end

--------------------------------------------------------------------------------
-- Modal UI
--------------------------------------------------------------------------------

--- Create the backdrop entity (click to dismiss)
local function createBackdrop()
    local screenW, screenH = resolveScreen()
    
    local backdropEntity = create_transform_entity()
    local t = component_cache.get(backdropEntity, Transform)
    if t then
        t.actualX = 0
        t.actualY = 0
        t.actualW = screenW
        t.actualH = screenH
        t.visualX = 0
        t.visualY = 0
        t.visualW = screenW
        t.visualH = screenH
    end
    
    local go = component_cache.get(backdropEntity, GameObject)
    if go then
        go.state.hoverEnabled = true
        go.state.clickEnabled = true
        go.state.collisionEnabled = true
        go.methods.onClick = function()
            PatchNotesModal.close()
        end
    end
    
    if layer_order_system and layer_order_system.assignZIndexToEntity then
        layer_order_system.assignZIndexToEntity(backdropEntity, (z_orders.ui_modal or 900) + 1)
    end
    
    return backdropEntity
end

--- Create the close button entity
local function createCloseButton(modalX, modalY)
    local buttonSize = 32
    local padding = 8
    
    local closeEntity = create_transform_entity()
    local t = component_cache.get(closeEntity, Transform)
    if t then
        t.actualX = modalX + MODAL_WIDTH - buttonSize - padding
        t.actualY = modalY + padding
        t.actualW = buttonSize
        t.actualH = buttonSize
        t.visualX = t.actualX
        t.visualY = t.actualY
        t.visualW = buttonSize
        t.visualH = buttonSize
    end
    
    local go = component_cache.get(closeEntity, GameObject)
    if go then
        go.state.hoverEnabled = true
        go.state.clickEnabled = true
        go.state.collisionEnabled = true
        go.methods.onClick = function()
            if playSoundEffect then
                playSoundEffect("effects", "button-click")
            end
            PatchNotesModal.close()
        end
    end
    
    if layer_order_system and layer_order_system.assignZIndexToEntity then
        layer_order_system.assignZIndexToEntity(closeEntity, (z_orders.ui_modal or 900) + 10)
    end
    
    return closeEntity
end

--- Build the modal UI using DSL
local function buildModalUI()
    local dsl = require("ui.ui_syntax_sugar")
    local data = PatchNotesModal._data
    
    if not data then return nil end
    
    local titleText = data.title or localization.get("ui.patch_notes_title") or "Patch Notes"
    local versionText = string.format(localization.get("ui.patch_notes_version") or "Version %s", data.version or "?")
    local dateText = string.format(localization.get("ui.patch_notes_date") or "%s", data.date or "")
    
    -- Split content into lines for display
    local contentLines = {}
    local content = data.content or ""
    for line in content:gmatch("[^\n]+") do
        table.insert(contentLines, line)
    end
    
    -- Build content nodes
    local contentNodes = {}
    for _, line in ipairs(contentLines) do
        table.insert(contentNodes, dsl.text(line, {
            fontSize = 14,
            color = "white",
            shadow = true
        }))
        table.insert(contentNodes, dsl.spacer(4))
    end
    
    local modalDef = dsl.root {
        config = {
            color = util.getColor("blackberry"),
            padding = 16,
            emboss = 3,
            minWidth = MODAL_WIDTH,
            minHeight = MODAL_HEIGHT,
        },
        children = {
            dsl.vbox {
                config = { spacing = 8 },
                children = {
                    -- Title
                    dsl.text(titleText, {
                        fontSize = 24,
                        color = "gold",
                        shadow = true
                    }),
                    -- Version
                    dsl.text(versionText, {
                        fontSize = 16,
                        color = "cyan",
                        shadow = true
                    }),
                    -- Date
                    dsl.text(dateText, {
                        fontSize = 14,
                        color = "gray",
                        shadow = true
                    }),
                    -- Divider
                    dsl.divider("horizontal", { color = "gray", thickness = 2, length = MODAL_WIDTH - 40 }),
                    dsl.spacer(8),
                    -- Content (in a vbox for scrolling)
                    dsl.vbox {
                        config = {
                            padding = 4,
                            spacing = 2,
                        },
                        children = contentNodes
                    }
                }
            }
        }
    }
    
    return modalDef
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Initialize the patch notes system
function PatchNotesModal.init()
    PatchNotesModal._data = loadPatchNotes()
end

--- Open the patch notes modal
function PatchNotesModal.open()
    if PatchNotesModal.isOpen then return end
    
    -- Load data if not already loaded
    if not PatchNotesModal._data then
        PatchNotesModal._data = loadPatchNotes()
    end
    
    if not PatchNotesModal._data then
        print("[PatchNotesModal] Cannot open: no patch notes data")
        return
    end
    
    PatchNotesModal.isOpen = true
    
    -- Mark as read immediately when opened
    markAsRead()
    
    -- Emit signal
    signal.emit("patch_notes_opened")
    
    -- Create backdrop
    PatchNotesModal._backdrop = createBackdrop()
    
    -- Calculate modal position (centered)
    local screenW, screenH = resolveScreen()
    local modalX = (screenW - MODAL_WIDTH) / 2
    local modalY = (screenH - MODAL_HEIGHT) / 2
    
    -- Create modal UI
    local dsl = require("ui.ui_syntax_sugar")
    local modalDef = buildModalUI()
    
    if modalDef then
        PatchNotesModal._modalBox = dsl.spawn(
            { x = modalX, y = modalY },
            modalDef,
            "ui",
            (z_orders.ui_modal or 900) + 5
        )
    end
    
    -- Create close button
    PatchNotesModal._closeButton = createCloseButton(modalX, modalY)
    
    if playSoundEffect then
        playSoundEffect("effects", "button-click")
    end
end

--- Close the patch notes modal
function PatchNotesModal.close()
    if not PatchNotesModal.isOpen then return end
    
    PatchNotesModal.isOpen = false
    
    -- Emit signal
    signal.emit("patch_notes_closed")
    
    -- Destroy backdrop
    if PatchNotesModal._backdrop and entity_cache.valid(PatchNotesModal._backdrop) then
        registry:destroy(PatchNotesModal._backdrop)
        PatchNotesModal._backdrop = nil
    end
    
    -- Destroy modal box
    if PatchNotesModal._modalBox then
        if ui and ui.box and ui.box.Remove then
            ui.box.Remove(registry, PatchNotesModal._modalBox)
        elseif entity_cache.valid(PatchNotesModal._modalBox) then
            registry:destroy(PatchNotesModal._modalBox)
        end
        PatchNotesModal._modalBox = nil
    end
    
    -- Destroy close button
    if PatchNotesModal._closeButton and entity_cache.valid(PatchNotesModal._closeButton) then
        registry:destroy(PatchNotesModal._closeButton)
        PatchNotesModal._closeButton = nil
    end
end

--- Toggle the modal open/closed
function PatchNotesModal.toggle()
    if PatchNotesModal.isOpen then
        PatchNotesModal.close()
    else
        PatchNotesModal.open()
    end
end

--- Update function (check for ESC key)
function PatchNotesModal.update(dt)
    if not PatchNotesModal.isOpen then return end
    
    -- Check for ESC key to close
    if input and input.action_pressed then
        if input.action_pressed("ui_cancel") or input.action_pressed("escape") then
            PatchNotesModal.close()
        end
    elseif IsKeyPressed and IsKeyPressed(KEY_ESCAPE) then
        PatchNotesModal.close()
    end
end

--- Draw function (render backdrop)
function PatchNotesModal.draw()
    if not PatchNotesModal.isOpen then return end
    
    local screenW, screenH = resolveScreen()
    local space = layer.DrawCommandSpace.Screen
    local baseZ = (z_orders.ui_modal or 900)
    
    -- Draw semi-transparent backdrop
    if command_buffer and command_buffer.queueDrawCenteredFilledRoundedRect then
        command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
            c.x = screenW * 0.5
            c.y = screenH * 0.5
            c.w = screenW
            c.h = screenH
            c.rx = 0
            c.ry = 0
            c.color = Col(0, 0, 0, BACKDROP_ALPHA)
        end, baseZ, space)
    end
    
    -- Draw close button (red X)
    if PatchNotesModal._closeButton and entity_cache.valid(PatchNotesModal._closeButton) then
        local t = component_cache.get(PatchNotesModal._closeButton, Transform)
        if t then
            local btnX = t.actualX + t.actualW / 2
            local btnY = t.actualY + t.actualH / 2
            local font = localization.getFont()
            
            -- Button background
            command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
                c.x = btnX
                c.y = btnY
                c.w = 28
                c.h = 28
                c.rx = 4
                c.ry = 4
                c.color = util.getColor("red")
            end, baseZ + 8, space)
            
            -- X text
            command_buffer.queueDrawText(layers.ui, function(c)
                c.text = "X"
                c.font = font
                c.x = btnX - 6
                c.y = btnY - 10
                c.color = Col(255, 255, 255, 255)
                c.fontSize = 20
            end, baseZ + 9, space)
        end
    end
end

--- Get the current patch notes version
function PatchNotesModal.getCurrentVersion()
    if not PatchNotesModal._data then
        PatchNotesModal._data = loadPatchNotes()
    end
    return PatchNotesModal._data and PatchNotesModal._data.version or nil
end

return PatchNotesModal
