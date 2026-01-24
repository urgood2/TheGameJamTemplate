--[[
================================================================================
MAIN MENU BUTTONS: Minimalist UI System
================================================================================
A new minimalist menu button system for the main menu with:
- Transparent backgrounds (no colored panels)
- White text (normal) / Gold text (hover/selected)
- Decorator sprites on both sides when hovered/selected
- Keyboard/gamepad navigation with selection state
- DynamicMotion effect on hover

Usage:
    local MainMenuButtons = require("ui.main_menu_buttons")

    MainMenuButtons.setButtons({
        { label = "Start Game", onClick = function() ... end },
        { label = "Discord", onClick = function() ... end },
        { label = "Bluesky", onClick = function() ... end },
        { label = "Language", onClick = function() ... end },
    })

    MainMenuButtons.init()  -- Creates the UI
    MainMenuButtons.destroy()  -- Cleanup
]]

local MainMenuButtons = {}

--------------------------------------------------------------------------------
-- Configuration Constants
--------------------------------------------------------------------------------

local ui_scale = _G.ui_scale or { ui = function(v) return math.floor(v * 1.25) end }

local CONFIG = {
    -- Font settings
    BASE_FONT_SIZE = 38,  -- Spec says 36-40px, we use 38 as middle ground

    -- Colors
    TEXT_COLOR_NORMAL = "white",
    TEXT_COLOR_HOVER = "gold",
    BACKGROUND_COLOR = nil,  -- Transparent

    -- DynamicMotion settings (from spec)
    DYNAMIC_MOTION_INTENSITY = 0.7,
    DYNAMIC_MOTION_FREQUENCY = 16,

    -- Layout
    MENU_X_PERCENT = 0.03,  -- 3% from left edge (almost flush per spec)
    BASE_BUTTON_GAP = 14,   -- 12-16px range, we use 14
    BASE_DECORATOR_OFFSET = 16,

    -- Decorator sprite (using existing sprite)
    DECORATOR_SPRITE = "frame0012.png",
}

--------------------------------------------------------------------------------
-- Module State
--------------------------------------------------------------------------------

local state = {
    selectedIndex = 1,
    buttons = {},
    decoratorsVisible = false,
    decoratorsForButton = nil,
    entities = {},  -- Created UI entities
    decoratorEntities = { left = nil, right = nil },  -- Decorator sprites
    _processingHover = false,  -- Guard against recursive hover calls
    _initialized = false,  -- Prevent double initialization
}

--------------------------------------------------------------------------------
-- Public API: Configuration
--------------------------------------------------------------------------------

--- Get button visual configuration
--- @param opts table? Optional {hovered: boolean}
--- @return table Configuration with fontSize, textColor, backgroundColor
function MainMenuButtons.getButtonConfig(opts)
    opts = opts or {}
    local scaledFontSize = ui_scale.ui(CONFIG.BASE_FONT_SIZE)

    return {
        fontSize = scaledFontSize,
        textColor = opts.hovered and CONFIG.TEXT_COLOR_HOVER or CONFIG.TEXT_COLOR_NORMAL,
        backgroundColor = CONFIG.BACKGROUND_COLOR,
    }
end

--- Get decorator sprite configuration
--- @return table {leftSprite, rightSprite, rightFlipped}
function MainMenuButtons.getDecoratorConfig()
    return {
        leftSprite = CONFIG.DECORATOR_SPRITE,
        rightSprite = CONFIG.DECORATOR_SPRITE,
        rightFlipped = true,
        offset = ui_scale.ui(CONFIG.BASE_DECORATOR_OFFSET),
    }
end

--- Get layout configuration
--- @return table {menuX, menuY, buttonGap}
function MainMenuButtons.getLayoutConfig()
    local screenW = _G.globals and _G.globals.screenWidth() or 1920
    local screenH = _G.globals and _G.globals.screenHeight() or 1080

    return {
        menuX = screenW * CONFIG.MENU_X_PERCENT,
        menuY = screenH * 0.50,
        buttonGap = ui_scale.ui(CONFIG.BASE_BUTTON_GAP),
    }
end

--------------------------------------------------------------------------------
-- Public API: Button Creation
--------------------------------------------------------------------------------

--- Create a menu button configuration
--- @param opts table {label: string, onClick: function}
--- @return table Button configuration
function MainMenuButtons.createMenuButton(opts)
    assert(opts.label, "Button must have a label")
    assert(opts.onClick, "Button must have an onClick handler")

    return {
        label = opts.label,
        onClick = opts.onClick,
        entity = opts.entity,
    }
end

--------------------------------------------------------------------------------
-- Public API: State Management
--------------------------------------------------------------------------------

--- Get current menu state
--- @return table {selectedIndex, buttons, decoratorsVisible, decoratorsForButton}
function MainMenuButtons.getState()
    return {
        selectedIndex = state.selectedIndex,
        buttons = state.buttons,
        decoratorsVisible = state.decoratorsVisible,
        decoratorsForButton = state.decoratorsForButton,
    }
end

--- Set the button list
--- @param buttons table Array of {label, onClick, entity?}
function MainMenuButtons.setButtons(buttons)
    state.buttons = buttons
    state.selectedIndex = 1
    state.decoratorsVisible = false
    state.decoratorsForButton = nil
end

--- Set selected index (clamped to valid range, no wrap)
--- @param index number Target index
function MainMenuButtons.setSelectedIndex(index)
    local count = #state.buttons
    if count == 0 then return end

    -- Clamp to valid range (no wrap)
    if index < 1 then
        index = 1
    elseif index > count then
        index = count
    end

    local oldIndex = state.selectedIndex
    state.selectedIndex = index

    -- Update decorators and effects when selection changes
    if oldIndex ~= index then
        MainMenuButtons._onSelectionChanged(oldIndex, index)
    end
end

--- Navigate up (decrease selected index)
function MainMenuButtons.navigateUp()
    local oldIndex = state.selectedIndex
    MainMenuButtons.setSelectedIndex(state.selectedIndex - 1)

    -- Play hover sound if selection changed
    if state.selectedIndex ~= oldIndex then
        MainMenuButtons._playHoverSound()
    end
end

--- Navigate down (increase selected index)
function MainMenuButtons.navigateDown()
    local oldIndex = state.selectedIndex
    MainMenuButtons.setSelectedIndex(state.selectedIndex + 1)

    -- Play hover sound if selection changed
    if state.selectedIndex ~= oldIndex then
        MainMenuButtons._playHoverSound()
    end
end

--------------------------------------------------------------------------------
-- Public API: Decorator Management
--------------------------------------------------------------------------------

--- Show decorators for a specific button
--- @param buttonIndex number Button index (1-based)
function MainMenuButtons.showDecorators(buttonIndex)
    -- Update old button text to normal color if different
    if state.decoratorsForButton and state.decoratorsForButton ~= buttonIndex then
        MainMenuButtons._updateButtonTextColor(state.decoratorsForButton, false)
    end

    state.decoratorsVisible = true
    state.decoratorsForButton = buttonIndex

    -- Update new button text to hover color
    MainMenuButtons._updateButtonTextColor(buttonIndex, true)

    -- Update visual state
    MainMenuButtons._setDecoratorsVisible(true)
    MainMenuButtons._updateDecoratorPositions()
end

--- Hide all decorators
function MainMenuButtons.hideDecorators()
    -- Reset text color of current button
    if state.decoratorsForButton then
        MainMenuButtons._updateButtonTextColor(state.decoratorsForButton, false)
    end

    state.decoratorsVisible = false
    state.decoratorsForButton = nil

    -- Update visual state
    MainMenuButtons._setDecoratorsVisible(false)
end

--------------------------------------------------------------------------------
-- Public API: Hover/Selection Effects
--------------------------------------------------------------------------------

--- Called when a button starts being hovered
--- @param buttonIndex number Button index (1-based)
function MainMenuButtons.onButtonHover(buttonIndex)
    -- Guard against recursive calls
    if state._processingHover then return end

    local button = state.buttons[buttonIndex]
    if not button then return end

    -- Skip if already hovering this button
    if state.selectedIndex == buttonIndex and state.decoratorsVisible then
        return
    end

    state._processingHover = true

    -- Inject DynamicMotion
    if button.entity and _G.transform and _G.transform.InjectDynamicMotion then
        _G.transform.InjectDynamicMotion(
            button.entity,
            CONFIG.DYNAMIC_MOTION_INTENSITY,
            CONFIG.DYNAMIC_MOTION_FREQUENCY
        )
    end

    -- Show decorators
    MainMenuButtons.showDecorators(buttonIndex)

    -- Update selection state directly (avoid recursive _onSelectionChanged)
    local oldIndex = state.selectedIndex
    state.selectedIndex = buttonIndex

    -- Unhover old button if different
    if oldIndex ~= buttonIndex then
        MainMenuButtons.onButtonUnhover(oldIndex)
    end

    state._processingHover = false
end

--- Called when a button stops being hovered
--- @param buttonIndex number Button index (1-based)
function MainMenuButtons.onButtonUnhover(buttonIndex)
    local button = state.buttons[buttonIndex]
    if not button then return end

    -- Remove DynamicMotion
    if button.entity and _G.transform and _G.transform.RemoveDynamicMotion then
        _G.transform.RemoveDynamicMotion(button.entity)
    end
end

--- Called when mouse hovers over a button
--- @param buttonIndex number Button index (1-based)
function MainMenuButtons.onMouseHover(buttonIndex)
    MainMenuButtons.setSelectedIndex(buttonIndex)
    MainMenuButtons.onButtonHover(buttonIndex)
end

--- Called when mouse leaves the menu area
--- Selection persists per spec, but visual effects are removed
function MainMenuButtons.onMouseLeaveMenu()
    -- Selection persists per spec - do NOT change selectedIndex
    -- Remove visual effects but keep selection state for keyboard navigation
    local button = state.buttons[state.selectedIndex]
    if button then
        MainMenuButtons.onButtonUnhover(state.selectedIndex)
    end
    MainMenuButtons.hideDecorators()
end

--------------------------------------------------------------------------------
-- Public API: Keyboard/Gamepad Input
--------------------------------------------------------------------------------

--- Handle key down events
--- @param key string "UP", "DOWN", "ENTER"
function MainMenuButtons.handleKeyDown(key)
    if key == "UP" then
        MainMenuButtons.navigateUp()
    elseif key == "DOWN" then
        MainMenuButtons.navigateDown()
    elseif key == "ENTER" then
        MainMenuButtons.activateSelected()
    end
end

--- Activate (click) the currently selected button
function MainMenuButtons.activateSelected()
    -- Validate selected index
    if #state.buttons == 0 then return end
    if state.selectedIndex < 1 or state.selectedIndex > #state.buttons then
        return
    end

    local button = state.buttons[state.selectedIndex]
    if not button then return end

    -- Play click sound
    if _G.playSoundEffect then
        _G.playSoundEffect("effects", "button-click")
    end

    -- Call onClick handler
    if button.onClick then
        button.onClick()
    end
end

--------------------------------------------------------------------------------
-- Private: Selection Change Handler
--------------------------------------------------------------------------------

function MainMenuButtons._onSelectionChanged(oldIndex, newIndex)
    -- Guard against recursive calls
    if state._processingHover then return end

    state._processingHover = true

    -- Unhover old button
    if oldIndex and oldIndex >= 1 and oldIndex <= #state.buttons then
        MainMenuButtons.onButtonUnhover(oldIndex)
    end

    -- Apply hover effects to new button (without calling onButtonHover to avoid recursion)
    if newIndex and newIndex >= 1 and newIndex <= #state.buttons then
        local button = state.buttons[newIndex]
        if button then
            -- Inject DynamicMotion
            if button.entity and _G.transform and _G.transform.InjectDynamicMotion then
                _G.transform.InjectDynamicMotion(
                    button.entity,
                    CONFIG.DYNAMIC_MOTION_INTENSITY,
                    CONFIG.DYNAMIC_MOTION_FREQUENCY
                )
            end
            -- Show decorators
            MainMenuButtons.showDecorators(newIndex)
        end
    end

    state._processingHover = false
end

--------------------------------------------------------------------------------
-- Private: Audio
--------------------------------------------------------------------------------

function MainMenuButtons._playHoverSound()
    if _G.playSoundEffect then
        -- Use button-click as selection feedback (no dedicated ui-hover sound exists)
        _G.playSoundEffect("effects", "button-click")
    end
end

--------------------------------------------------------------------------------
-- Private: Text Color Updates
--------------------------------------------------------------------------------

--- Update a button's text color based on hover state
--- @param buttonIndex number Button index (1-based)
--- @param isHovered boolean Whether the button is hovered
function MainMenuButtons._updateButtonTextColor(buttonIndex, isHovered)
    if not state.entities.menuBox then return end

    local colorName = isHovered and CONFIG.TEXT_COLOR_HOVER or CONFIG.TEXT_COLOR_NORMAL

    -- Retrieve text entity by ID using ui.box.GetUIEByID (matches wand_panel pattern)
    if _G.ui and _G.ui.box and _G.ui.box.GetUIEByID and _G.registry then
        local textId = "menu_btn_" .. buttonIndex
        local textEntity = _G.ui.box.GetUIEByID(_G.registry, state.entities.menuBox, textId)

        if textEntity and _G.component_cache then
            -- Use UITextComponent (DSL text nodes use this, not TextComponent)
            local uiText = _G.component_cache.get(textEntity, _G.UITextComponent)
            if uiText then
                local colorValue = _G.util and _G.util.getColor(colorName) or colorName
                uiText.color = colorValue
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Private: Decorator Position Updates
--------------------------------------------------------------------------------

--- Update decorator positions to be next to the selected button
function MainMenuButtons._updateDecoratorPositions()
    if not state.decoratorsVisible or not state.decoratorsForButton then
        return
    end

    local button = state.buttons[state.decoratorsForButton]
    if not button or not button.entity then return end

    local decoratorConfig = MainMenuButtons.getDecoratorConfig()
    local offset = decoratorConfig.offset

    -- Get button position and size
    if not _G.component_cache or not _G.component_cache.get then return end
    local buttonTransform = _G.component_cache.get(button.entity, _G.Transform)
    if not buttonTransform then return end

    local buttonX = buttonTransform.actualX
    local buttonY = buttonTransform.actualY
    local buttonW = buttonTransform.actualW or 100
    local buttonH = buttonTransform.actualH or 40

    -- Position left decorator
    if state.decoratorEntities.left and _G.component_cache then
        local leftTransform = _G.component_cache.get(state.decoratorEntities.left, _G.Transform)
        if leftTransform then
            local decorW = leftTransform.actualW or 24
            leftTransform.actualX = buttonX - decorW - offset
            leftTransform.actualY = buttonY + (buttonH - (leftTransform.actualH or 24)) / 2
        end
    end

    -- Position right decorator (flipped)
    if state.decoratorEntities.right and _G.component_cache then
        local rightTransform = _G.component_cache.get(state.decoratorEntities.right, _G.Transform)
        if rightTransform then
            rightTransform.actualX = buttonX + buttonW + offset
            rightTransform.actualY = buttonY + (buttonH - (rightTransform.actualH or 24)) / 2
        end
    end
end

--- Set decorator visibility by moving off-screen (standard pattern in this codebase)
--- @param visible boolean
function MainMenuButtons._setDecoratorsVisible(visible)
    local function setEntityVisible(entity, vis)
        if not entity then return end
        if _G.component_cache and _G.component_cache.get then
            local t = _G.component_cache.get(entity, _G.Transform)
            if t then
                -- Move off-screen for invisible, position is restored by _updateDecoratorPositions
                if not vis then
                    t.actualX = -9999
                end
            end
        end
    end

    setEntityVisible(state.decoratorEntities.left, visible)
    setEntityVisible(state.decoratorEntities.right, visible)

    -- If making visible, update positions to put them in the correct place
    if visible and state.decoratorsForButton then
        MainMenuButtons._updateDecoratorPositions(state.decoratorsForButton)
    end
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

--- Initialize the menu (create UI entities)
--- Call this after setButtons() to create the visual UI
function MainMenuButtons.init()
    if state._initialized then
        if _G.log_warn then _G.log_warn("[MainMenuButtons] Already initialized, call destroy() first") end
        return
    end

    if #state.buttons == 0 then
        if _G.log_warn then _G.log_warn("[MainMenuButtons] No buttons set, call setButtons() first") end
        return
    end

    local dsl = require("ui.ui_syntax_sugar")
    local layout = MainMenuButtons.getLayoutConfig()
    local config = MainMenuButtons.getButtonConfig()

    -- Build button children for vertical layout
    local children = {}
    for i, buttonData in ipairs(state.buttons) do
        local buttonIndex = i

        -- Create text-only button (no background)
        local textNode = dsl.strict.text(buttonData.label, {
            id = "menu_btn_" .. i,
            fontSize = config.fontSize,
            color = config.textColor,
            shadow = true,
        })

        -- Wrap in a clickable container with transparent background
        local buttonNode = dsl.strict.hbox {
            config = {
                color = "transparent",
                padding = ui_scale.ui(4),
                hover = true,
                buttonCallback = function()
                    if _G.playSoundEffect then
                        _G.playSoundEffect("effects", "button-click")
                    end
                    if buttonData.onClick then
                        buttonData.onClick()
                    end
                end,
                initFunc = function(reg, entity)
                    -- Store entity reference for DynamicMotion
                    state.buttons[buttonIndex].entity = entity

                    -- Attach hover handlers via GameObject
                    local go = _G.component_cache and _G.component_cache.get(entity, _G.GameObject)
                    if go and go.methods then
                        go.methods.onHover = function()
                            MainMenuButtons.onButtonHover(buttonIndex)
                        end
                        go.methods.onStopHover = function()
                            -- Selection persists, but we could update visuals here
                        end
                    end
                end,
                align = _G.AlignmentFlag and _G.bit and
                    _G.bit.bor(_G.AlignmentFlag.HORIZONTAL_LEFT, _G.AlignmentFlag.VERTICAL_CENTER) or 4,
            },
            children = { textNode }
        }

        table.insert(children, buttonNode)

        -- Add spacer between buttons (not after last)
        if i < #state.buttons then
            table.insert(children, dsl.strict.spacer(layout.buttonGap))
        end
    end

    -- Create main menu container
    local menuDef = dsl.strict.root {
        config = {
            color = "transparent",
            padding = ui_scale.ui(8),
        },
        children = {
            dsl.strict.vbox {
                config = {
                    color = "transparent",
                    padding = 0,
                    align = _G.AlignmentFlag and _G.bit and
                        _G.bit.bor(_G.AlignmentFlag.HORIZONTAL_LEFT, _G.AlignmentFlag.VERTICAL_TOP) or 4,
                },
                children = children
            }
        }
    }

    -- Spawn the menu
    state.entities.menuBox = dsl.spawn(
        { x = layout.menuX, y = layout.menuY },
        menuDef,
        "ui",
        100
    )

    -- Create decorator sprites
    MainMenuButtons._createDecoratorSprites()

    -- Show decorators for the initially selected button
    -- (selectedIndex defaults to 1)
    MainMenuButtons.showDecorators(state.selectedIndex)

    state._initialized = true

    if _G.log_debug then
        _G.log_debug("[MainMenuButtons] Initialized with " .. #state.buttons .. " buttons")
    end
end

--- Create the decorator sprite entities
function MainMenuButtons._createDecoratorSprites()
    local decoratorConfig = MainMenuButtons.getDecoratorConfig()
    local spriteSize = ui_scale.ui(24)
    local DECORATOR_Z_ORDER = 105  -- Above buttons (100) but below tooltips

    -- Helper to set up decorator entity with layer, screen space, and collision marker
    local function setupDecoratorEntity(entity)
        if not entity then return end

        -- CRITICAL: Set entity to screen space to match DSL text buttons
        -- Without this, decorators render in world space and appear offset
        if _G.transform and _G.transform.set_space then
            _G.transform.set_space(entity, "screen")
        end

        -- NOTE: Do NOT add ObjectAttachedToUITag - it excludes entities from shader rendering pipeline!
        -- (See player_inventory.lua:328, trigger_strip_ui.lua:168)

        -- Add to UI layer with appropriate z-order
        if _G.layer_order_system and _G.layer_order_system.attachEntityToLayer then
            local uiLayer = _G.layers and _G.layers.ui
            if uiLayer then
                _G.layer_order_system.attachEntityToLayer(entity, uiLayer, DECORATOR_Z_ORDER)
            end
        end

        -- ScreenSpaceCollisionMarker is already set by transform.set_space("screen")
    end

    -- Create left decorator
    if _G.animation_system and _G.animation_system.createAnimatedObjectWithTransform then
        state.decoratorEntities.left = _G.animation_system.createAnimatedObjectWithTransform(
            decoratorConfig.leftSprite,
            true  -- Generate from sprite
        )
        if state.decoratorEntities.left then
            if _G.animation_system.resizeAnimationObjectsInEntityToFit then
                _G.animation_system.resizeAnimationObjectsInEntityToFit(
                    state.decoratorEntities.left,
                    spriteSize,
                    spriteSize
                )
            end
            setupDecoratorEntity(state.decoratorEntities.left)
        end

        -- Create right decorator (will be flipped horizontally)
        state.decoratorEntities.right = _G.animation_system.createAnimatedObjectWithTransform(
            decoratorConfig.rightSprite,
            true  -- Generate from sprite
        )
        if state.decoratorEntities.right then
            if _G.animation_system.resizeAnimationObjectsInEntityToFit then
                _G.animation_system.resizeAnimationObjectsInEntityToFit(
                    state.decoratorEntities.right,
                    spriteSize,
                    spriteSize
                )
            end

            -- Flip horizontally using animation_system (correct method for animated sprites)
            if _G.animation_system.set_horizontal_flip then
                _G.animation_system.set_horizontal_flip(state.decoratorEntities.right, true)
            end

            setupDecoratorEntity(state.decoratorEntities.right)
        end
    end

    -- Set initial visibility to hidden
    MainMenuButtons._setDecoratorsVisible(false)
end

--- Destroy the menu (cleanup UI entities)
function MainMenuButtons.destroy()
    -- Destroy decorator entities
    for key, entity in pairs(state.decoratorEntities) do
        if entity then
            if _G.registry and _G.registry.valid and _G.registry:valid(entity) then
                _G.registry:destroy(entity)
            end
        end
    end
    state.decoratorEntities = { left = nil, right = nil }

    -- Destroy menu box using DSL remove if available
    if state.entities.menuBox then
        local ok, dsl = pcall(require, "ui.ui_syntax_sugar")
        if ok and dsl and dsl.remove then
            dsl.remove(state.entities.menuBox)
        elseif _G.ui and _G.ui.box and _G.ui.box.Remove and _G.registry then
            _G.ui.box.Remove(_G.registry, state.entities.menuBox)
        elseif _G.registry and _G.registry.valid and _G.registry:valid(state.entities.menuBox) then
            _G.registry:destroy(state.entities.menuBox)
        end
        state.entities.menuBox = nil
    end

    -- Destroy other entities
    for key, entity in pairs(state.entities) do
        if entity and _G.registry and _G.registry.valid and _G.registry:valid(entity) then
            _G.registry:destroy(entity)
        end
    end

    state.entities = {}
    state.buttons = {}
    state.selectedIndex = 1
    state.decoratorsVisible = false
    state.decoratorsForButton = nil
    state._processingHover = false
    state._initialized = false

    if _G.log_debug then
        _G.log_debug("[MainMenuButtons] Destroyed")
    end
end

return MainMenuButtons
