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
local timer = require("core.timer")
local z_orders = require("core.z_orders")
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
local layer_order_system = _G.layer_order_system
local SaveManager = require("core.save_manager")

PatchNotesModal.isOpen = false
PatchNotesModal._data = nil
PatchNotesModal._backdrop = nil
PatchNotesModal._modalBox = nil
PatchNotesModal._closeButton = nil
PatchNotesModal._lastReadVersion = ""

local MODAL_WIDTH = 500
local MODAL_HEIGHT = 400
local BACKDROP_ALPHA = 180

--------------------------------------------------------------------------------
-- Snap Box Visual Helper
-- Prevents UI from animating from 0 size - snaps to full size immediately
--------------------------------------------------------------------------------
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

--- Create the close button as a separate entity at the top-right corner
---@param modalX number Modal X position
---@param initialY number Initial Y position (offscreen for slide animation)
---@return number closeButtonEntity
local function createCloseButton(modalX, initialY)
    local dsl = require("ui.ui_syntax_sugar")

    -- Position at top-right corner of modal (with small offset for padding)
    local buttonSize = 28
    local buttonX = modalX + MODAL_WIDTH - buttonSize - 12
    local buttonY = initialY + 12

    local closeButtonDef = dsl.root {
        config = {
            color = util.getColor("red"),
            emboss = 2,
            padding = 4,
            minWidth = buttonSize,
            minHeight = buttonSize,
            hover = true,
            canCollide = true,
            buttonCallback = function()
                if playSoundEffect then
                    playSoundEffect("effects", "button-click")
                end
                PatchNotesModal.close()
            end,
        },
        children = {
            dsl.text("X", {
                fontSize = 16,
                color = "white",
                shadow = true
            })
        }
    }

    local closeEntity = dsl.spawn(
        { x = buttonX, y = buttonY },
        closeButtonDef,
        "ui",
        (z_orders.ui_modal or 900) + 10
    )
    ui.box.set_draw_layer(closeEntity, "ui")

    -- Snap close button to full size immediately
    snapBoxVisual(closeEntity)

    return closeEntity
end

local function buildModalUI()
    local dsl = require("ui.ui_syntax_sugar")
    local data = PatchNotesModal._data

    if not data then return nil end

    local titleText = data.title or localization.get("ui.patch_notes_title") or "Patch Notes"
    local versionText = string.format(localization.get("ui.patch_notes_version") or "Version %s", data.version or "?")
    local dateText = string.format(localization.get("ui.patch_notes_date") or "%s", data.date or "")

    local contentLines = {}
    local content = data.content or ""
    for line in content:gmatch("[^\n]+") do
        table.insert(contentLines, line)
    end

    local contentNodes = {}
    for _, line in ipairs(contentLines) do
        table.insert(contentNodes, dsl.text(line, {
            fontSize = 16,
            color = "white",
            shadow = true
        }))
        table.insert(contentNodes, dsl.spacer(6))
    end

    -- Header with title/version (X button is positioned separately)
    local headerRow = dsl.vbox {
        config = { padding = 0, spacing = 4 },
        children = {
            dsl.text(titleText, {
                fontSize = 28,
                color = "gold",
                shadow = true
            }),
            dsl.text(versionText, {
                fontSize = 18,
                color = "cyan",
                shadow = true
            }),
            dsl.text(dateText, {
                fontSize = 14,
                color = "lightgray",
                shadow = true
            }),
        }
    }

    local modalDef = dsl.root {
        config = {
            color = util.getColor("blackberry"),
            padding = 20,
            emboss = 3,
            minWidth = MODAL_WIDTH,
            minHeight = MODAL_HEIGHT,
        },
        children = {
            dsl.vbox {
                config = { spacing = 10 },
                children = {
                    headerRow,
                    dsl.divider("horizontal", { color = "gray", thickness = 2, length = MODAL_WIDTH - 50 }),
                    dsl.spacer(8),
                    dsl.vbox {
                        config = {
                            padding = 8,
                            spacing = 4,
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

function PatchNotesModal.init()
    PatchNotesModal._data = loadPatchNotes()
end

local function ensureModalCreated()
    if PatchNotesModal._modalBox and registry:valid(PatchNotesModal._modalBox) then
        return true
    end

    if not PatchNotesModal._data then
        PatchNotesModal._data = loadPatchNotes()
    end

    if not PatchNotesModal._data then
        print("[PatchNotesModal] Cannot create: no patch notes data")
        return false
    end

    local screenW, screenH = resolveScreen()
    local modalX = (screenW - MODAL_WIDTH) / 2
    local modalY = (screenH - MODAL_HEIGHT) / 2
    local offscreenY = screenH + 100  -- Start below screen for slide-in animation

    PatchNotesModal._backdrop = createBackdrop()

    local dsl = require("ui.ui_syntax_sugar")
    local modalDef = buildModalUI()

    if modalDef then
        -- Create at offscreen position for slide-in animation
        PatchNotesModal._modalBox = dsl.spawn(
            { x = modalX, y = offscreenY },
            modalDef,
            "ui",
            (z_orders.ui_modal or 900) + 5
        )
        ui.box.set_draw_layer(PatchNotesModal._modalBox, "ui")

        -- Snap to full size immediately (no grow animation from 0)
        snapBoxVisual(PatchNotesModal._modalBox)
    end

    -- Create close button at offscreen position (will animate with modal)
    PatchNotesModal._closeButton = createCloseButton(modalX, offscreenY)

    -- Store positions for visibility toggling
    PatchNotesModal._modalX = modalX
    PatchNotesModal._modalY = modalY

    return true
end

local function setModalVisible(visible)
    local screenW, screenH = resolveScreen()
    local offscreenY = screenH + 1000
    local onscreenY = PatchNotesModal._modalY or ((screenH - MODAL_HEIGHT) / 2)

    -- Snap backdrop position immediately
    if PatchNotesModal._backdrop and registry:valid(PatchNotesModal._backdrop) then
        local t = component_cache.get(PatchNotesModal._backdrop, Transform)
        if t then
            t.actualY = visible and 0 or offscreenY
        end
    end

    -- Move modal (visual interpolation creates slide animation)
    local modalEntity = PatchNotesModal._modalBox
    if modalEntity and registry:valid(modalEntity) then
        local t = component_cache.get(modalEntity, Transform)
        if t then
            t.actualY = visible and onscreenY or offscreenY
            -- Don't snap visualY - let it animate (slide in from bottom)
        end
    end

    -- Move close button with modal
    local closeButton = PatchNotesModal._closeButton
    if closeButton and registry:valid(closeButton) then
        local buttonSize = 28
        local buttonY = (visible and onscreenY or offscreenY) + 12
        local t = component_cache.get(closeButton, Transform)
        if t then
            t.actualY = buttonY
            -- Don't snap visualY - let it animate with modal
        end
    end
end

function PatchNotesModal.open()
    if PatchNotesModal.isOpen then return end
    
    if not ensureModalCreated() then return end
    
    PatchNotesModal.isOpen = true
    markAsRead()
    signal.emit("patch_notes_opened")
    
    setModalVisible(true)
    
    if playSoundEffect then
        playSoundEffect("effects", "button-click")
    end
end

function PatchNotesModal.close()
    if not PatchNotesModal.isOpen then return end
    
    PatchNotesModal.isOpen = false
    signal.emit("patch_notes_closed")
    
    setModalVisible(false)
end

function PatchNotesModal.destroy()
    PatchNotesModal.close()

    if PatchNotesModal._backdrop and registry:valid(PatchNotesModal._backdrop) then
        registry:destroy(PatchNotesModal._backdrop)
    end
    PatchNotesModal._backdrop = nil

    if PatchNotesModal._modalBox then
        if ui and ui.box and ui.box.Remove then
            ui.box.Remove(registry, PatchNotesModal._modalBox)
        elseif registry:valid(PatchNotesModal._modalBox) then
            registry:destroy(PatchNotesModal._modalBox)
        end
    end
    PatchNotesModal._modalBox = nil

    -- Clean up close button
    if PatchNotesModal._closeButton then
        if ui and ui.box and ui.box.Remove then
            ui.box.Remove(registry, PatchNotesModal._closeButton)
        elseif registry:valid(PatchNotesModal._closeButton) then
            registry:destroy(PatchNotesModal._closeButton)
        end
    end
    PatchNotesModal._closeButton = nil
end

function PatchNotesModal.toggle()
    if PatchNotesModal.isOpen then
        PatchNotesModal.close()
    else
        PatchNotesModal.open()
    end
end

function PatchNotesModal.update(dt)
    if not PatchNotesModal.isOpen then return end
    
    if input and input.action_pressed then
        if input.action_pressed("ui_cancel") or input.action_pressed("escape") then
            PatchNotesModal.close()
        end
    elseif IsKeyPressed and IsKeyPressed(KEY_ESCAPE) then
        PatchNotesModal.close()
    end
end

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
    -- Close button is now part of the modal UI, no manual drawing needed
end

--- Get the current patch notes version
function PatchNotesModal.getCurrentVersion()
    if not PatchNotesModal._data then
        PatchNotesModal._data = loadPatchNotes()
    end
    return PatchNotesModal._data and PatchNotesModal._data.version or nil
end

return PatchNotesModal
