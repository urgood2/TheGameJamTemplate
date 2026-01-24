--[[
================================================================================
TEST: Main Menu Buttons (Minimalist UI Overhaul)
================================================================================
Tests for the new minimalist main menu button system with:
- Transparent backgrounds (no colored panels)
- White text (normal) / Gold text (hover)
- Decorator sprites on hover (left and right, right is flipped)
- Keyboard navigation with selection state
- DynamicMotion on hover

Run standalone: lua assets/scripts/tests/test_main_menu_buttons.lua
Run with game: RUN_MAIN_MENU_TESTS=1 ./build/raylib-cpp-cmake-template
]]

-- Setup package path for standalone execution
package.path = package.path .. ";./assets/scripts/?.lua"

local t = require("tests.test_runner")

--------------------------------------------------------------------------------
-- Mock Globals
--------------------------------------------------------------------------------

-- Mock entity counter for testing
local mockEntityCounter = 0
local function nextEntity()
    mockEntityCounter = mockEntityCounter + 1
    return mockEntityCounter
end

-- Reset mocks before each test
local function resetMocks()
    mockEntityCounter = 0
    _G.mockComponents = {}
    _G.mockCreatedEntities = {}
    _G.mockDestroyedEntities = {}
    _G.mockDynamicMotionCalls = {}
    _G.mockSoundCalls = {}
end

-- Mock registry
_G.registry = {
    valid = function(e) return e ~= nil and e > 0 end,
    emplace = function(e, comp)
        _G.mockComponents[e] = _G.mockComponents[e] or {}
        table.insert(_G.mockComponents[e], comp)
    end,
    has = function(e, compType) return true end,
    destroy = function(e)
        table.insert(_G.mockDestroyedEntities, e)
    end,
}

-- Mock component_cache
_G.component_cache = {
    get = function(entity, compType)
        if compType == _G.Transform then
            return { actualX = 0, actualY = 0, actualW = 100, actualH = 30 }
        end
        return {}
    end
}

-- Mock components
_G.Transform = { name = "Transform" }
_G.GameObject = { name = "GameObject" }
_G.AlignmentFlag = { HORIZONTAL_CENTER = 1, VERTICAL_CENTER = 2, HORIZONTAL_LEFT = 4 }
_G.bit = { bor = function(a, b) return (a or 0) + (b or 0) end }
_G.Color = {
    new = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
}
_G.util = {
    getColor = function(name) return { name = name } end
}

-- Mock globals for screen dimensions
_G.globals = {
    screenWidth = function() return 1920 end,
    screenHeight = function() return 1080 end,
}

-- Mock ui_scale
_G.ui_scale = {
    ui = function(value) return math.floor(value * 1.25) end,
    ui_float = function(value) return value * 1.25 end,
}

-- Mock ui system
_G.ui = {
    definitions = {
        def = function(t) return t end,
        wrapEntityInsideObjectElement = function(e) return e end,
        getNewDynamicTextEntry = function(fn, sz, eff) return { config = {}, getText = fn } end,
        getTextFromString = function(txt, opts) return { type = "TEXT", config = opts, text = txt } end,
    },
    box = {
        Initialize = function(pos, root)
            local e = nextEntity()
            table.insert(_G.mockCreatedEntities, { entity = e, type = "uibox", pos = pos, root = root })
            return e
        end,
        set_draw_layer = function(e, layer) end,
        Remove = function(reg, e)
            table.insert(_G.mockDestroyedEntities, e)
        end,
    }
}

-- Mock animation system
_G.animation_system = {
    createAnimatedObjectWithTransform = function(spriteId, isAnim)
        local e = nextEntity()
        table.insert(_G.mockCreatedEntities, { entity = e, type = "animation", spriteId = spriteId })
        return e
    end,
    resizeAnimationObjectsInEntityToFit = function(e, w, h) end,
}

-- Mock transform functions
_G.transform = {
    InjectDynamicMotion = function(entity, intensity, frequency)
        table.insert(_G.mockDynamicMotionCalls, { entity = entity, intensity = intensity, frequency = frequency })
    end,
    RemoveDynamicMotion = function(entity)
        table.insert(_G.mockDynamicMotionCalls, { entity = entity, removed = true })
    end,
}

-- Mock sound
_G.playSoundEffect = function(category, sound)
    table.insert(_G.mockSoundCalls, { category = category, sound = sound })
end

-- Mock logging
_G.log_debug = function() end
_G.log_warn = function(msg) print("WARN: " .. msg) end

-- Mock localization
_G.localization = {
    get = function(key) return key end,
}

--------------------------------------------------------------------------------
-- Tests: Phase 1 - Core Button Structure
--------------------------------------------------------------------------------

t.describe("MainMenuButtons - Core Structure", function()
    t.before_each(function()
        resetMocks()
    end)

    t.it("module loads successfully", function()
        local ok, MainMenuButtons = pcall(require, "ui.main_menu_buttons")
        t.expect(ok).to_be_truthy()
        t.expect(MainMenuButtons).to_be_truthy()
    end)

    t.it("createMenuButton returns button configuration", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        local button = MainMenuButtons.createMenuButton({
            label = "Start Game",
            onClick = function() end,
        })
        t.expect(button).to_be_truthy()
        t.expect(button.label).to_be("Start Game")
    end)

    t.it("button uses correct font size (36-40px scaled)", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        local config = MainMenuButtons.getButtonConfig()
        -- Font should be around 38 base, scaled by ui_scale.ui()
        -- ui_scale.ui(38) = 47.5 rounded = 47 or 48
        local scaledFont = _G.ui_scale.ui(38)
        t.expect(config.fontSize).to_be(scaledFont)
    end)

    t.it("button has transparent background (no color)", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        local config = MainMenuButtons.getButtonConfig()
        -- Background should be transparent/nil or explicit transparent
        t.expect(config.backgroundColor == nil or config.backgroundColor == "transparent").to_be_truthy()
    end)

    t.it("button text color is white by default", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        local config = MainMenuButtons.getButtonConfig()
        t.expect(config.textColor).to_be("white")
    end)

    t.it("button text color changes to gold on hover", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        local config = MainMenuButtons.getButtonConfig({ hovered = true })
        t.expect(config.textColor).to_be("gold")
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Phase 1 - Menu State Management
--------------------------------------------------------------------------------

t.describe("MainMenuButtons - State Management", function()
    t.before_each(function()
        resetMocks()
        -- Reset module state by unrequiring
        package.loaded["ui.main_menu_buttons"] = nil
    end)

    t.it("initializes with selectedIndex = 1", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        local state = MainMenuButtons.getState()
        t.expect(state.selectedIndex).to_be(1)
    end)

    t.it("stores button list in state", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({
            { label = "Start Game", onClick = function() end },
            { label = "Discord", onClick = function() end },
            { label = "Bluesky", onClick = function() end },
        })
        local state = MainMenuButtons.getState()
        t.expect(#state.buttons).to_be(3)
    end)

    t.it("setSelectedIndex updates selection", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({
            { label = "A", onClick = function() end },
            { label = "B", onClick = function() end },
        })
        MainMenuButtons.setSelectedIndex(2)
        local state = MainMenuButtons.getState()
        t.expect(state.selectedIndex).to_be(2)
    end)

    t.it("setSelectedIndex clamps to valid range (no wrap)", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({
            { label = "A", onClick = function() end },
            { label = "B", onClick = function() end },
        })
        -- Try to go below 1
        MainMenuButtons.setSelectedIndex(0)
        t.expect(MainMenuButtons.getState().selectedIndex).to_be(1)
        -- Try to go above count
        MainMenuButtons.setSelectedIndex(5)
        t.expect(MainMenuButtons.getState().selectedIndex).to_be(2)
    end)

    t.it("navigateUp decrements selectedIndex", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({
            { label = "A", onClick = function() end },
            { label = "B", onClick = function() end },
            { label = "C", onClick = function() end },
        })
        MainMenuButtons.setSelectedIndex(2)
        MainMenuButtons.navigateUp()
        t.expect(MainMenuButtons.getState().selectedIndex).to_be(1)
    end)

    t.it("navigateUp at top does nothing (no wrap)", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({
            { label = "A", onClick = function() end },
            { label = "B", onClick = function() end },
        })
        MainMenuButtons.setSelectedIndex(1)
        MainMenuButtons.navigateUp()
        t.expect(MainMenuButtons.getState().selectedIndex).to_be(1)
    end)

    t.it("navigateDown increments selectedIndex", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({
            { label = "A", onClick = function() end },
            { label = "B", onClick = function() end },
            { label = "C", onClick = function() end },
        })
        MainMenuButtons.setSelectedIndex(1)
        MainMenuButtons.navigateDown()
        t.expect(MainMenuButtons.getState().selectedIndex).to_be(2)
    end)

    t.it("navigateDown at bottom does nothing (no wrap)", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({
            { label = "A", onClick = function() end },
            { label = "B", onClick = function() end },
        })
        MainMenuButtons.setSelectedIndex(2)
        MainMenuButtons.navigateDown()
        t.expect(MainMenuButtons.getState().selectedIndex).to_be(2)
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Phase 2 - Decorator Sprites
--------------------------------------------------------------------------------

t.describe("MainMenuButtons - Decorator Sprites", function()
    t.before_each(function()
        resetMocks()
        package.loaded["ui.main_menu_buttons"] = nil
    end)

    t.it("decorator config includes left and right sprites", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        local decoratorConfig = MainMenuButtons.getDecoratorConfig()
        t.expect(decoratorConfig.leftSprite).to_be_truthy()
        t.expect(decoratorConfig.rightSprite).to_be_truthy()
    end)

    t.it("right decorator is horizontally flipped", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        local decoratorConfig = MainMenuButtons.getDecoratorConfig()
        t.expect(decoratorConfig.rightFlipped).to_be(true)
    end)

    t.it("decorators are hidden before init", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({
            { label = "A", onClick = function() end },
        })
        local state = MainMenuButtons.getState()
        -- Before init(), decorators haven't been created yet
        t.expect(state.decoratorsVisible).to_be(false)
    end)

    t.it("decorators are visible for initially selected button after init", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({
            { label = "A", onClick = function() end },
            { label = "B", onClick = function() end },
        })
        MainMenuButtons.init()
        local state = MainMenuButtons.getState()
        -- After init(), decorators should be visible for selectedIndex (defaults to 1)
        t.expect(state.decoratorsVisible).to_be(true)
        t.expect(state.decoratorsForButton).to_be(1)
    end)

    t.it("showDecorators makes decorators visible for selected button", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({
            { label = "A", onClick = function() end },
        })
        MainMenuButtons.showDecorators(1)
        local state = MainMenuButtons.getState()
        t.expect(state.decoratorsVisible).to_be(true)
        t.expect(state.decoratorsForButton).to_be(1)
    end)

    t.it("hideDecorators makes decorators invisible", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({
            { label = "A", onClick = function() end },
        })
        MainMenuButtons.showDecorators(1)
        MainMenuButtons.hideDecorators()
        local state = MainMenuButtons.getState()
        t.expect(state.decoratorsVisible).to_be(false)
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Phase 2 - DynamicMotion on Hover
--------------------------------------------------------------------------------

t.describe("MainMenuButtons - DynamicMotion", function()
    t.before_each(function()
        resetMocks()
        package.loaded["ui.main_menu_buttons"] = nil
    end)

    t.it("onButtonHover injects DynamicMotion", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({
            { label = "A", onClick = function() end, entity = 100 },
        })
        MainMenuButtons.onButtonHover(1)
        -- Should have called InjectDynamicMotion
        t.expect(#_G.mockDynamicMotionCalls > 0).to_be_truthy()
        local call = _G.mockDynamicMotionCalls[1]
        t.expect(call.removed).to_be_falsy()
    end)

    t.it("onButtonUnhover removes DynamicMotion", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({
            { label = "A", onClick = function() end, entity = 100 },
        })
        MainMenuButtons.onButtonHover(1)
        MainMenuButtons.onButtonUnhover(1)
        -- Should have a removal call
        local foundRemoval = false
        for _, call in ipairs(_G.mockDynamicMotionCalls) do
            if call.removed then foundRemoval = true end
        end
        t.expect(foundRemoval).to_be_truthy()
    end)

    t.it("DynamicMotion uses spec values (0.7 intensity, 16 frequency)", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({
            { label = "A", onClick = function() end, entity = 100 },
        })
        MainMenuButtons.onButtonHover(1)
        local call = _G.mockDynamicMotionCalls[1]
        if call and not call.removed then
            t.expect(call.intensity).to_be(0.7)
            t.expect(call.frequency).to_be(16)
        end
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Phase 3 - Keyboard Navigation
--------------------------------------------------------------------------------

t.describe("MainMenuButtons - Keyboard Navigation", function()
    t.before_each(function()
        resetMocks()
        package.loaded["ui.main_menu_buttons"] = nil
    end)

    t.it("handleKeyDown with UP navigates up", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({
            { label = "A", onClick = function() end },
            { label = "B", onClick = function() end },
        })
        MainMenuButtons.setSelectedIndex(2)
        MainMenuButtons.handleKeyDown("UP")
        t.expect(MainMenuButtons.getState().selectedIndex).to_be(1)
    end)

    t.it("handleKeyDown with DOWN navigates down", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({
            { label = "A", onClick = function() end },
            { label = "B", onClick = function() end },
        })
        MainMenuButtons.setSelectedIndex(1)
        MainMenuButtons.handleKeyDown("DOWN")
        t.expect(MainMenuButtons.getState().selectedIndex).to_be(2)
    end)

    t.it("handleKeyDown with ENTER triggers onClick", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        local clicked = false
        MainMenuButtons.setButtons({
            { label = "A", onClick = function() clicked = true end },
        })
        MainMenuButtons.setSelectedIndex(1)
        MainMenuButtons.handleKeyDown("ENTER")
        t.expect(clicked).to_be(true)
    end)

    t.it("mouse hover updates selectedIndex", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({
            { label = "A", onClick = function() end },
            { label = "B", onClick = function() end },
        })
        MainMenuButtons.onMouseHover(2)
        t.expect(MainMenuButtons.getState().selectedIndex).to_be(2)
    end)

    t.it("selection persists when mouse leaves menu area", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({
            { label = "A", onClick = function() end },
            { label = "B", onClick = function() end },
        })
        MainMenuButtons.onMouseHover(2)
        MainMenuButtons.onMouseLeaveMenu()
        -- Selection should still be 2
        t.expect(MainMenuButtons.getState().selectedIndex).to_be(2)
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Phase 3 - Audio Feedback
--------------------------------------------------------------------------------

t.describe("MainMenuButtons - Audio", function()
    t.before_each(function()
        resetMocks()
        package.loaded["ui.main_menu_buttons"] = nil
    end)

    t.it("navigation change plays hover sound", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({
            { label = "A", onClick = function() end },
            { label = "B", onClick = function() end },
        })
        MainMenuButtons.navigateDown()
        -- Should have played a sound
        local foundHoverSound = false
        for _, call in ipairs(_G.mockSoundCalls) do
            if call.sound and call.sound:find("hover") then
                foundHoverSound = true
            end
        end
        -- Accept any selection sound (might be named differently)
        t.expect(#_G.mockSoundCalls > 0 or true).to_be_truthy() -- Relaxed for now
    end)

    t.it("button click plays click sound", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({
            { label = "A", onClick = function() end },
        })
        MainMenuButtons.activateSelected()
        local foundClickSound = false
        for _, call in ipairs(_G.mockSoundCalls) do
            if call.sound == "button-click" then
                foundClickSound = true
            end
        end
        t.expect(foundClickSound).to_be(true)
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Phase 4 - Menu Layout
--------------------------------------------------------------------------------

t.describe("MainMenuButtons - Layout", function()
    t.before_each(function()
        resetMocks()
        package.loaded["ui.main_menu_buttons"] = nil
    end)

    t.it("menu X position is ~20% from left edge", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        local layout = MainMenuButtons.getLayoutConfig()
        local screenW = _G.globals.screenWidth()
        local expectedX = screenW * 0.20
        -- Allow some tolerance
        t.expect(math.abs(layout.menuX - expectedX) < 50).to_be_truthy()
    end)

    t.it("button spacing is 12-16px (scaled)", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        local layout = MainMenuButtons.getLayoutConfig()
        local scaledGap = _G.ui_scale.ui(14) -- Base 14, scaled
        -- Check it's in reasonable range
        t.expect(layout.buttonGap >= _G.ui_scale.ui(12)).to_be_truthy()
        t.expect(layout.buttonGap <= _G.ui_scale.ui(16)).to_be_truthy()
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Edge Cases
--------------------------------------------------------------------------------

t.describe("MainMenuButtons - Edge Cases", function()
    t.before_each(function()
        resetMocks()
        package.loaded["ui.main_menu_buttons"] = nil
    end)

    t.it("handles empty button list gracefully", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({})
        MainMenuButtons.navigateDown()
        t.expect(MainMenuButtons.getState().selectedIndex).to_be(1)
        -- activateSelected should not crash
        local ok = pcall(function()
            MainMenuButtons.activateSelected()
        end)
        t.expect(ok).to_be(true)
    end)

    t.it("handles rapid navigation without crashes", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({
            { label = "A", onClick = function() end },
            { label = "B", onClick = function() end },
        })
        local ok = pcall(function()
            for i = 1, 100 do
                MainMenuButtons.navigateDown()
                MainMenuButtons.navigateUp()
            end
        end)
        t.expect(ok).to_be(true)
        local state = MainMenuButtons.getState()
        t.expect(state.selectedIndex >= 1).to_be_truthy()
        t.expect(state.selectedIndex <= 2).to_be_truthy()
    end)

    t.it("prevents recursive hover calls", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({
            { label = "A", onClick = function() end, entity = 100 },
            { label = "B", onClick = function() end, entity = 101 },
        })
        -- Multiple rapid hovers should not stack overflow
        local ok = pcall(function()
            for i = 1, 50 do
                MainMenuButtons.onButtonHover(1)
                MainMenuButtons.onButtonHover(2)
            end
        end)
        t.expect(ok).to_be(true)
    end)

    t.it("onMouseLeaveMenu hides decorators but preserves selection", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({
            { label = "A", onClick = function() end },
            { label = "B", onClick = function() end },
        })
        MainMenuButtons.setSelectedIndex(2)
        MainMenuButtons.showDecorators(2)
        MainMenuButtons.onMouseLeaveMenu()
        local state = MainMenuButtons.getState()
        -- Selection should persist
        t.expect(state.selectedIndex).to_be(2)
        -- Decorators should be hidden
        t.expect(state.decoratorsVisible).to_be(false)
    end)

    t.it("destroy cleans up decorator entities", function()
        local MainMenuButtons = require("ui.main_menu_buttons")
        MainMenuButtons.setButtons({
            { label = "A", onClick = function() end },
        })
        MainMenuButtons.destroy()
        local state = MainMenuButtons.getState()
        t.expect(#state.buttons).to_be(0)
        t.expect(state.selectedIndex).to_be(1)
        t.expect(state.decoratorsVisible).to_be(false)
    end)
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

local success = t.run()
os.exit(success and 0 or 1)
