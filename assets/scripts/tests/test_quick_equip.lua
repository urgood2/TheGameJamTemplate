-- assets/scripts/tests/test_quick_equip.lua
--[[
================================================================================
TEST: Inventory Quick Equip - Input Detection Logic
================================================================================
Tests the input detection patterns for right-click equip functionality,
including Mac Ctrl+Click support.

Run with:
    RUN_QUICK_EQUIP_TEST=1 ./build/raylib-cpp-cmake-template
================================================================================
]]

-- Setup package path for standalone execution
package.path = package.path .. ";./assets/scripts/?.lua"

local t = require("tests.test_runner")

-- Reset to clear any previous state
t.reset()

--------------------------------------------------------------------------------
-- Mock Input State for Testing
--------------------------------------------------------------------------------

local MockInput = {}
MockInput.__index = MockInput

function MockInput.new()
    local self = setmetatable({}, MockInput)
    self.keysDown = {}
    self.mousePressed = {}
    return self
end

function MockInput:setKeyDown(key, down)
    self.keysDown[key] = down
end

function MockInput:setMousePressed(button, pressed)
    self.mousePressed[button] = pressed
end

function MockInput:isKeyDown(key)
    return self.keysDown[key] or false
end

function MockInput:isMousePressed(button)
    return self.mousePressed[button] or false
end

--------------------------------------------------------------------------------
-- Input Detection Logic (extracted for testability)
--------------------------------------------------------------------------------

-- This mirrors the logic in inventory_quick_equip.lua checkRightClick()
-- We extract it here to test the detection patterns in isolation.

local function detectQuickEquipInput(mockInput)
    -- Check for right-click
    local rightClick = mockInput:isMousePressed("MOUSE_BUTTON_RIGHT")

    -- Alt+Left-click alternative
    local altHeld = mockInput:isKeyDown("KEY_LEFT_ALT") or mockInput:isKeyDown("KEY_RIGHT_ALT")
    local altClick = altHeld and mockInput:isMousePressed("MOUSE_BUTTON_LEFT")

    -- Ctrl+Left-click or Cmd+Left-click (Mac support)
    local modifierHeld = mockInput:isKeyDown("KEY_LEFT_CONTROL") or mockInput:isKeyDown("KEY_RIGHT_CONTROL") or
                         mockInput:isKeyDown("KEY_LEFT_SUPER") or mockInput:isKeyDown("KEY_RIGHT_SUPER")
    local modifierClick = modifierHeld and mockInput:isMousePressed("MOUSE_BUTTON_LEFT")

    return rightClick or altClick or modifierClick
end

--------------------------------------------------------------------------------
-- Tests
--------------------------------------------------------------------------------

t.describe("InventoryQuickEquip", function()

    t.describe("Input Detection", function()

        t.it("detects right-click", function()
            local input = MockInput.new()
            input:setMousePressed("MOUSE_BUTTON_RIGHT", true)

            local detected = detectQuickEquipInput(input)
            t.expect(detected).to_be(true)
        end)

        t.it("detects Alt+Left-click (existing behavior)", function()
            local input = MockInput.new()
            input:setKeyDown("KEY_LEFT_ALT", true)
            input:setMousePressed("MOUSE_BUTTON_LEFT", true)

            local detected = detectQuickEquipInput(input)
            t.expect(detected).to_be(true)
        end)

        t.it("detects Right-Alt+Left-click", function()
            local input = MockInput.new()
            input:setKeyDown("KEY_RIGHT_ALT", true)
            input:setMousePressed("MOUSE_BUTTON_LEFT", true)

            local detected = detectQuickEquipInput(input)
            t.expect(detected).to_be(true)
        end)

        t.it("detects Ctrl+Left-click (Mac support)", function()
            local input = MockInput.new()
            input:setKeyDown("KEY_LEFT_CONTROL", true)
            input:setMousePressed("MOUSE_BUTTON_LEFT", true)

            local detected = detectQuickEquipInput(input)
            t.expect(detected).to_be(true)
        end)

        t.it("detects Right-Ctrl+Left-click", function()
            local input = MockInput.new()
            input:setKeyDown("KEY_RIGHT_CONTROL", true)
            input:setMousePressed("MOUSE_BUTTON_LEFT", true)

            local detected = detectQuickEquipInput(input)
            t.expect(detected).to_be(true)
        end)

        t.it("detects Cmd+Left-click (Mac native)", function()
            local input = MockInput.new()
            input:setKeyDown("KEY_LEFT_SUPER", true)
            input:setMousePressed("MOUSE_BUTTON_LEFT", true)

            local detected = detectQuickEquipInput(input)
            t.expect(detected).to_be(true)
        end)

        t.it("detects Right-Cmd+Left-click", function()
            local input = MockInput.new()
            input:setKeyDown("KEY_RIGHT_SUPER", true)
            input:setMousePressed("MOUSE_BUTTON_LEFT", true)

            local detected = detectQuickEquipInput(input)
            t.expect(detected).to_be(true)
        end)

        t.it("does NOT trigger on plain left-click", function()
            local input = MockInput.new()
            input:setMousePressed("MOUSE_BUTTON_LEFT", true)

            local detected = detectQuickEquipInput(input)
            t.expect(detected).to_be(false)
        end)

        t.it("does NOT trigger on Ctrl alone (no click)", function()
            local input = MockInput.new()
            input:setKeyDown("KEY_LEFT_CONTROL", true)

            local detected = detectQuickEquipInput(input)
            t.expect(detected).to_be(false)
        end)

        t.it("does NOT trigger when no input", function()
            local input = MockInput.new()

            local detected = detectQuickEquipInput(input)
            t.expect(detected).to_be(false)
        end)

    end)

end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

if os.getenv("RUN_QUICK_EQUIP_TEST") == "1" or arg and arg[0] and arg[0]:match("test_quick_equip") then
    local success = t.run()
    if not success then
        os.exit(1)
    end
end

return t
