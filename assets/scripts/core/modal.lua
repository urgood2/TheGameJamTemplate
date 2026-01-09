--[[
================================================================================
core/modal.lua - Generic Modal System
================================================================================
Simple, reusable modal dialogs for alerts, confirmations, and custom content.

Usage:
    local modal = require("core.modal")

    -- Simple alert (one OK button)
    modal.alert("Something happened!")
    modal.alert("Error!", { title = "Warning", color = "red" })

    -- Confirm dialog (two buttons)
    modal.confirm("Are you sure?", {
        onConfirm = function() doThing() end,
        onCancel = function() print("cancelled") end,
        confirmText = "Yes",
        cancelText = "No"
    })

    -- Custom content modal
    modal.show({
        title = "Custom Modal",
        width = 600,
        height = 400,
        content = function(dsl)
            return dsl.vbox {
                children = {
                    dsl.text("Line 1"),
                    dsl.text("Line 2")
                }
            }
        end,
        buttons = {
            { text = "Action", color = "blue", action = function() end },
            { text = "Close" }
        }
    })

    -- Close current modal
    modal.close()

    -- Check if modal is open
    if modal.isOpen() then ... end

Features:
    - Simple presets: alert(), confirm() for common cases
    - Custom content: show() for complex modals
    - Consistent behavior: ESC to close, backdrop click, slide animation
    - Single modal at a time: opening new modal closes previous
    - Callbacks: onClose, onConfirm, onCancel
]]

local modal = {}

-- Lazy-loaded dependencies
local _dsl, _signal, _z_orders, _component_cache

local function get_dsl()
    if not _dsl then _dsl = require("ui.ui_syntax_sugar") end
    return _dsl
end

local function get_signal()
    if not _signal then _signal = require("external.hump.signal") end
    return _signal
end

local function get_z_orders()
    if not _z_orders then _z_orders = require("core.z_orders") end
    return _z_orders
end

local function get_component_cache()
    if not _component_cache then _component_cache = require("core.component_cache") end
    return _component_cache
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local _state = {
    isOpen = false,
    backdrop = nil,
    modalBox = nil,
    currentConfig = nil,
    onCloseCallback = nil,
}

-- Default dimensions
local DEFAULT_WIDTH = 400
local DEFAULT_HEIGHT = 250
local BACKDROP_ALPHA = 180

--------------------------------------------------------------------------------
-- Internal Helpers
--------------------------------------------------------------------------------

local function resolveScreen()
    local screenW = (globals and globals.screenWidth and globals.screenWidth()) or 1920
    local screenH = (globals and globals.screenHeight and globals.screenHeight()) or 1080
    return screenW, screenH
end

local function getModalZ()
    local z_orders = get_z_orders()
    return (z_orders.ui_modal or 900)
end

local function snapBoxVisual(boxId)
    if not boxId then return end
    local component_cache = get_component_cache()

    if ui and ui.box and ui.box.RenewAlignment then
        ui.box.RenewAlignment(registry, boxId)
    end

    local t = component_cache.get(boxId, Transform)
    if t then
        t.visualX = t.actualX
        t.visualY = t.actualY
        t.visualW = t.actualW
        t.visualH = t.actualH
    end
end

local function playOpenSound()
    if playSoundEffect then
        playSoundEffect("effects", "button-click")
    end
end

local function destroyUI()
    -- Destroy backdrop
    if _state.backdrop and registry and registry:valid(_state.backdrop) then
        registry:destroy(_state.backdrop)
    end
    _state.backdrop = nil

    -- Destroy modal box
    if _state.modalBox then
        if ui and ui.box and ui.box.Remove then
            ui.box.Remove(registry, _state.modalBox)
        elseif registry and registry:valid(_state.modalBox) then
            registry:destroy(_state.modalBox)
        end
    end
    _state.modalBox = nil
end

local function createBackdrop(dismissOnClick)
    local screenW, screenH = resolveScreen()
    local component_cache = get_component_cache()

    local backdropEntity = create_transform_entity and create_transform_entity() or registry:create()

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
        go.state.clickEnabled = dismissOnClick
        go.state.collisionEnabled = true
        if dismissOnClick then
            go.methods.onClick = function()
                modal.close()
            end
        end
    end

    if layer_order_system and layer_order_system.assignZIndexToEntity then
        layer_order_system.assignZIndexToEntity(backdropEntity, getModalZ() + 1)
    end

    return backdropEntity
end

local function buildButton(text, opts)
    local dsl = get_dsl()
    opts = opts or {}

    local buttonColor = opts.color and util.getColor(opts.color) or util.getColor("gray")

    return dsl.root {
        config = {
            color = buttonColor,
            emboss = 2,
            padding = { 12, 8 },
            minWidth = 80,
            hover = true,
            canCollide = true,
            buttonCallback = function()
                if playSoundEffect then
                    playSoundEffect("effects", "button-click")
                end
                if opts.action then
                    opts.action()
                end
                if opts.closeOnClick ~= false then
                    modal.close()
                end
            end,
        },
        children = {
            dsl.text(text, {
                fontSize = 16,
                color = "white",
                shadow = true
            })
        }
    }
end

local function buildModalUI(config)
    local dsl = get_dsl()

    local width = config.width or DEFAULT_WIDTH
    local height = config.height or DEFAULT_HEIGHT
    local title = config.title or ""
    local color = config.color and util.getColor(config.color) or util.getColor("blackberry")

    -- Build content
    local contentNode
    if config.content then
        if type(config.content) == "function" then
            contentNode = config.content(dsl)
        else
            contentNode = config.content
        end
    else
        contentNode = dsl.spacer(10)
    end

    -- Build buttons
    local buttonNodes = {}
    local buttons = config.buttons or { { text = "OK" } }
    for _, btn in ipairs(buttons) do
        table.insert(buttonNodes, buildButton(btn.text, {
            color = btn.color,
            action = btn.action,
            closeOnClick = btn.closeOnClick
        }))
    end

    local buttonRow = dsl.hbox {
        config = { spacing = 10, align = "center" },
        children = buttonNodes
    }

    -- Build modal structure
    local children = {}

    if title and title ~= "" then
        table.insert(children, dsl.text(title, {
            fontSize = 24,
            color = "gold",
            shadow = true
        }))
        table.insert(children, dsl.spacer(8))
        table.insert(children, dsl.divider("horizontal", { color = "gray", thickness = 2, length = width - 50 }))
        table.insert(children, dsl.spacer(12))
    end

    table.insert(children, contentNode)
    table.insert(children, dsl.spacer(16))
    table.insert(children, buttonRow)

    local modalDef = dsl.root {
        config = {
            color = color,
            padding = 20,
            emboss = 3,
            minWidth = width,
            minHeight = height,
        },
        children = {
            dsl.vbox {
                config = { spacing = 4 },
                children = children
            }
        }
    }

    return modalDef
end

local function createModalUI(config)
    local dsl = get_dsl()
    local screenW, screenH = resolveScreen()
    local width = config.width or DEFAULT_WIDTH
    local height = config.height or DEFAULT_HEIGHT

    local modalX = (screenW - width) / 2
    local modalY = (screenH - height) / 2
    local offscreenY = screenH + 100 -- For slide-in animation

    -- Create backdrop (dismiss on click for alerts, not for confirms)
    local dismissOnClick = config._type ~= "confirm"
    _state.backdrop = createBackdrop(dismissOnClick)

    -- Build and spawn modal
    local modalDef = buildModalUI(config)

    _state.modalBox = dsl.spawn(
        { x = modalX, y = offscreenY }, -- Start offscreen for animation
        modalDef,
        "ui",
        getModalZ() + 5
    )

    if ui and ui.box and ui.box.set_draw_layer then
        ui.box.set_draw_layer(_state.modalBox, "ui")
    end

    -- Snap visual to avoid grow animation
    snapBoxVisual(_state.modalBox)

    -- Animate to final position
    local component_cache = get_component_cache()
    local t = component_cache.get(_state.modalBox, Transform)
    if t then
        t.actualY = modalY -- Will animate via visual interpolation
    end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Check if a modal is currently open
--- @return boolean
function modal.isOpen()
    return _state.isOpen
end

--- Close the current modal
function modal.close()
    if not _state.isOpen then return end

    _state.isOpen = false

    -- Invoke close callback
    if _state.onCloseCallback then
        local cb = _state.onCloseCallback
        _state.onCloseCallback = nil
        pcall(cb)
    end

    -- Destroy UI
    destroyUI()

    -- Emit signal
    local signal = get_signal()
    signal.emit("modal_closed")

    _state.currentConfig = nil
end

--- Show a custom modal with full configuration
--- @param config {title?: string, width?: number, height?: number, color?: string, content?: function|table, buttons?: table[], onClose?: function}
function modal.show(config)
    config = config or {}

    -- Close any existing modal
    if _state.isOpen then
        destroyUI()
    end

    _state.isOpen = true
    _state.currentConfig = config
    _state.onCloseCallback = config.onClose

    -- Create UI
    createModalUI(config)

    -- Emit signal
    local signal = get_signal()
    signal.emit("modal_opened")

    playOpenSound()
end

--- Show a simple alert modal with one OK button
--- @param message string The message to display
--- @param opts? {title?: string, color?: string, onClose?: function}
function modal.alert(message, opts)
    opts = opts or {}
    local dsl = get_dsl()

    modal.show({
        _type = "alert",
        title = opts.title,
        color = opts.color,
        width = opts.width or DEFAULT_WIDTH,
        height = opts.height,
        content = function(d)
            return d.text(message, {
                fontSize = 18,
                color = "white",
                shadow = true
            })
        end,
        buttons = {
            { text = "OK" }
        },
        onClose = opts.onClose
    })
end

--- Show a confirmation modal with Confirm/Cancel buttons
--- @param message string The message to display
--- @param opts {onConfirm: function, onCancel?: function, title?: string, color?: string, confirmText?: string, cancelText?: string}
function modal.confirm(message, opts)
    opts = opts or {}
    local dsl = get_dsl()

    local confirmText = opts.confirmText or "OK"
    local cancelText = opts.cancelText or "Cancel"

    modal.show({
        _type = "confirm",
        title = opts.title or "Confirm",
        color = opts.color,
        width = opts.width or DEFAULT_WIDTH,
        height = opts.height,
        content = function(d)
            return d.text(message, {
                fontSize = 18,
                color = "white",
                shadow = true
            })
        end,
        buttons = {
            {
                text = confirmText,
                color = "green",
                action = opts.onConfirm
            },
            {
                text = cancelText,
                color = "red",
                action = opts.onCancel
            }
        },
        onClose = opts.onCancel -- Closing via ESC counts as cancel
    })
end

--- Update function (call from game loop for ESC handling)
--- @param dt number Delta time
function modal.update(dt)
    if not _state.isOpen then return end

    -- ESC key to close
    if IsKeyPressed and IsKeyPressed(KEY_ESCAPE) then
        modal.close()
        return
    end

    -- Also check input system if available
    if input and input.action_pressed then
        if input.action_pressed("ui_cancel") or input.action_pressed("escape") then
            modal.close()
            return
        end
    end
end

--- Draw function (call from game loop for backdrop rendering)
--- @param dt number Delta time (optional)
function modal.draw(dt)
    if not _state.isOpen then return end

    local screenW, screenH = resolveScreen()
    local space = layer.DrawCommandSpace.Screen
    local baseZ = getModalZ()

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
end

return modal
