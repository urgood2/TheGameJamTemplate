--[[
================================================================================
TEST: dsl.strict.* Interactive Components
================================================================================
Verifies that interactive UI components (button, spriteButton, spritePanel)
validate their props correctly through the strict DSL API.

Tests cover:
- dsl.strict.button (onClick, children, disabled, hover states)
- dsl.strict.spriteButton (sprite, borders, onClick, states)
- dsl.strict.spritePanel (decorations array, borders)
- onClick validation (must be function when provided)
- Hover and disabled state validation

Run standalone: lua assets/scripts/tests/test_dsl_strict_interactive.lua
Run via runner: lua assets/scripts/tests/run_standalone.lua
]]

-- Setup package path for standalone execution
package.path = package.path .. ";./assets/scripts/?.lua"

-- Load mocks first if running standalone
local standalone = not _G.registry
if standalone then
    local ok, err = pcall(require, "tests.mocks.engine_mock")
    if not ok then
        print("Note: Running without engine mocks: " .. tostring(err))
    end
end

-- Additional mocks for DSL
_G.AlignmentFlag = _G.AlignmentFlag or { HORIZONTAL_CENTER = 1, VERTICAL_CENTER = 2, LEFT = 4 }
_G.bit = _G.bit or { bor = function(a, b) return (a or 0) + (b or 0) end }
_G.Color = _G.Color or { new = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
_G.util = _G.util or { getColor = function(c) return c end }
_G.ui = _G.ui or {
    definitions = {
        def = function(t) return t end,
        wrapEntityInsideObjectElement = function(e) return e end,
        getNewDynamicTextEntry = function(fn, sz, eff) return { config = {} } end,
        getTextFromString = function(txt, opts) return { type = "TEXT", config = opts } end,
    },
    box = {}
}
_G.animation_system = _G.animation_system or {
    createAnimatedObjectWithTransform = function() return {} end,
    resizeAnimationObjectsInEntityToFit = function() end
}
_G.layer_order_system = _G.layer_order_system or {}
_G.component_cache = _G.component_cache or { get = function() return nil end }
_G.timer = _G.timer or { every = function() end }
_G.log_debug = _G.log_debug or function() end
_G.log_warn = _G.log_warn or function() end

-- Load test runner
local t = require("tests.test_runner")

-- Load DSL module
local dsl_ok, dsl = pcall(require, "ui.ui_syntax_sugar")
if not dsl_ok then
    print("FATAL: Could not load DSL module: " .. tostring(dsl))
    os.exit(1)
end

-- Verify strict namespace exists
if not dsl.strict then
    print("FATAL: dsl.strict namespace missing")
    os.exit(1)
end

--------------------------------------------------------------------------------
-- dsl.strict.button Tests
--------------------------------------------------------------------------------

t.describe("dsl.strict.button", function()
    t.describe("valid props", function()
        t.it("accepts positional label", function()
            local result = dsl.strict.button("Click Me")
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts button with onClick callback", function()
            local result = dsl.strict.button("Submit", {
                onClick = function() print("clicked") end
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts button with disabled state", function()
            local result = dsl.strict.button("Disabled", { disabled = true })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts button with disabled = false", function()
            local result = dsl.strict.button("Enabled", { disabled = false })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts button with hover tooltip", function()
            local result = dsl.strict.button("Info", {
                hover = { title = "Information", body = "Click for more details" }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts button with styling options", function()
            local result = dsl.strict.button("Styled", {
                color = "blue",
                textColor = "white",
                fontSize = 18,
                shadow = true,
                emboss = 3
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts button with dimension constraints", function()
            local result = dsl.strict.button("Wide Button", {
                minWidth = 200,
                minHeight = 50
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts button with alignment", function()
            local align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER)
            local result = dsl.strict.button("Aligned", { align = align })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts button with all valid props combined", function()
            local result = dsl.strict.button("Full Button", {
                onClick = function() end,
                disabled = false,
                hover = { title = "Button", body = "Description" },
                tooltip = { text = "Tooltip" },
                color = "green",
                textColor = "black",
                fontSize = 16,
                shadow = true,
                emboss = 2,
                minWidth = 100,
                minHeight = 40,
                align = AlignmentFlag.HORIZONTAL_CENTER,
                id = "my_button"
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts empty options table", function()
            local result = dsl.strict.button("Simple", {})
            t.expect(result).to_be_truthy()
        end)
    end)

    t.describe("onClick validation", function()
        t.it("accepts onClick as function", function()
            local result = dsl.strict.button("Click", {
                onClick = function() return "clicked" end
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("rejects onClick as string", function()
            t.expect(function()
                dsl.strict.button("Click", { onClick = "handleClick" })
            end).to_throw()
        end)

        t.it("rejects onClick as number", function()
            t.expect(function()
                dsl.strict.button("Click", { onClick = 123 })
            end).to_throw()
        end)

        t.it("rejects onClick as table", function()
            t.expect(function()
                dsl.strict.button("Click", { onClick = { handler = true } })
            end).to_throw()
        end)

        t.it("rejects onClick as boolean", function()
            t.expect(function()
                dsl.strict.button("Click", { onClick = true })
            end).to_throw()
        end)
    end)

    t.describe("disabled state validation", function()
        t.it("accepts disabled as true", function()
            local result = dsl.strict.button("Btn", { disabled = true })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts disabled as false", function()
            local result = dsl.strict.button("Btn", { disabled = false })
            t.expect(result).to_be_truthy()
        end)

        t.it("rejects disabled as string", function()
            t.expect(function()
                dsl.strict.button("Btn", { disabled = "true" })
            end).to_throw()
        end)

        t.it("rejects disabled as number", function()
            t.expect(function()
                dsl.strict.button("Btn", { disabled = 1 })
            end).to_throw()
        end)
    end)

    t.describe("invalid props", function()
        t.it("rejects fontSize as string", function()
            t.expect(function()
                dsl.strict.button("Click", { fontSize = "large" })
            end).to_throw()
        end)

        t.it("rejects minWidth as string", function()
            t.expect(function()
                dsl.strict.button("Click", { minWidth = "100px" })
            end).to_throw()
        end)

        t.it("rejects minHeight as string", function()
            t.expect(function()
                dsl.strict.button("Click", { minHeight = "50%" })
            end).to_throw()
        end)

        t.it("rejects emboss as string", function()
            t.expect(function()
                dsl.strict.button("Click", { emboss = "medium" })
            end).to_throw()
        end)

        t.it("rejects shadow as string", function()
            t.expect(function()
                dsl.strict.button("Click", { shadow = "yes" })
            end).to_throw()
        end)

        t.it("rejects hover as string", function()
            t.expect(function()
                dsl.strict.button("Click", { hover = "Show tooltip" })
            end).to_throw()
        end)

        t.it("rejects tooltip as string", function()
            t.expect(function()
                dsl.strict.button("Click", { tooltip = "Tooltip text" })
            end).to_throw()
        end)

        t.it("rejects align as string", function()
            t.expect(function()
                dsl.strict.button("Click", { align = "center" })
            end).to_throw()
        end)
    end)

    t.describe("error messages", function()
        t.it("includes component name in error", function()
            local success, err = pcall(function()
                dsl.strict.button("Click", { onClick = "bad" })
            end)
            t.expect(success).to_be(false)
            t.expect(tostring(err)).to_contain("dsl.strict.button")
        end)

        t.it("includes property name in error", function()
            local success, err = pcall(function()
                dsl.strict.button("Click", { minWidth = "100px" })
            end)
            t.expect(success).to_be(false)
            t.expect(tostring(err)).to_contain("minWidth")
        end)

        t.it("includes type information in error", function()
            local success, err = pcall(function()
                dsl.strict.button("Click", { fontSize = {} })
            end)
            t.expect(success).to_be(false)
            t.expect(tostring(err)).to_contain("number")
        end)
    end)
end)

--------------------------------------------------------------------------------
-- dsl.strict.spriteButton Tests
--------------------------------------------------------------------------------

t.describe("dsl.strict.spriteButton", function()
    t.describe("valid props", function()
        t.it("accepts sprite base name", function()
            local result = dsl.strict.spriteButton({ sprite = "button" })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts sprite with borders array", function()
            local result = dsl.strict.spriteButton({
                sprite = "button",
                borders = { 4, 4, 4, 4 }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts onClick callback", function()
            local result = dsl.strict.spriteButton({
                sprite = "button",
                onClick = function() end
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts explicit state sprites", function()
            local result = dsl.strict.spriteButton({
                states = {
                    normal = "btn_normal.png",
                    hover = "btn_hover.png",
                    pressed = "btn_pressed.png",
                    disabled = "btn_disabled.png"
                }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts label/text content", function()
            local result = dsl.strict.spriteButton({
                sprite = "button",
                label = "Click Me"
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts text as alias for label", function()
            local result = dsl.strict.spriteButton({
                sprite = "button",
                text = "Submit"
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts children array", function()
            local result = dsl.strict.spriteButton({
                sprite = "button",
                children = { dsl.text("Child") }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts disabled state", function()
            local result = dsl.strict.spriteButton({
                sprite = "button",
                disabled = true
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts styling options", function()
            local result = dsl.strict.spriteButton({
                sprite = "button",
                textColor = "gold",
                fontSize = 20,
                shadow = true,
                padding = 8
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts dimension constraints", function()
            local result = dsl.strict.spriteButton({
                sprite = "button",
                minWidth = 150,
                minHeight = 40
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts alignment", function()
            local result = dsl.strict.spriteButton({
                sprite = "button",
                align = AlignmentFlag.HORIZONTAL_CENTER
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts all valid props combined", function()
            local result = dsl.strict.spriteButton({
                sprite = "fancy_button",
                borders = { 6, 6, 6, 6 },
                onClick = function() end,
                disabled = false,
                label = "Fancy Button",
                textColor = "white",
                fontSize = 18,
                shadow = true,
                padding = 10,
                minWidth = 200,
                minHeight = 50,
                align = AlignmentFlag.HORIZONTAL_CENTER,
                id = "fancy_btn"
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts empty options table", function()
            local result = dsl.strict.spriteButton({})
            t.expect(result).to_be_truthy()
        end)
    end)

    t.describe("borders validation", function()
        t.it("accepts borders as array of 4 numbers", function()
            local result = dsl.strict.spriteButton({
                sprite = "btn",
                borders = { 8, 8, 8, 8 }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts borders as table", function()
            local result = dsl.strict.spriteButton({
                sprite = "btn",
                borders = { left = 4, top = 4, right = 4, bottom = 4 }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("rejects borders as string", function()
            t.expect(function()
                dsl.strict.spriteButton({
                    sprite = "btn",
                    borders = "4px"
                })
            end).to_throw()
        end)

        t.it("rejects borders as number", function()
            t.expect(function()
                dsl.strict.spriteButton({
                    sprite = "btn",
                    borders = 4
                })
            end).to_throw()
        end)
    end)

    t.describe("onClick validation", function()
        t.it("accepts onClick as function", function()
            local result = dsl.strict.spriteButton({
                sprite = "btn",
                onClick = function() return true end
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("rejects onClick as string", function()
            t.expect(function()
                dsl.strict.spriteButton({
                    sprite = "btn",
                    onClick = "handleClick"
                })
            end).to_throw()
        end)

        t.it("rejects onClick as table", function()
            t.expect(function()
                dsl.strict.spriteButton({
                    sprite = "btn",
                    onClick = { callback = true }
                })
            end).to_throw()
        end)
    end)

    t.describe("disabled state validation", function()
        t.it("accepts disabled as boolean true", function()
            local result = dsl.strict.spriteButton({
                sprite = "btn",
                disabled = true
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts disabled as boolean false", function()
            local result = dsl.strict.spriteButton({
                sprite = "btn",
                disabled = false
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("rejects disabled as string", function()
            t.expect(function()
                dsl.strict.spriteButton({
                    sprite = "btn",
                    disabled = "yes"
                })
            end).to_throw()
        end)
    end)

    t.describe("invalid props", function()
        t.it("rejects sprite as number", function()
            t.expect(function()
                dsl.strict.spriteButton({ sprite = 123 })
            end).to_throw()
        end)

        t.it("rejects states as string", function()
            t.expect(function()
                dsl.strict.spriteButton({ states = "all_states.png" })
            end).to_throw()
        end)

        t.it("rejects fontSize as string", function()
            t.expect(function()
                dsl.strict.spriteButton({
                    sprite = "btn",
                    fontSize = "large"
                })
            end).to_throw()
        end)

        t.it("rejects minWidth as string", function()
            t.expect(function()
                dsl.strict.spriteButton({
                    sprite = "btn",
                    minWidth = "100%"
                })
            end).to_throw()
        end)

        t.it("rejects padding as string", function()
            t.expect(function()
                dsl.strict.spriteButton({
                    sprite = "btn",
                    padding = "10px"
                })
            end).to_throw()
        end)

        t.it("rejects shadow as string", function()
            t.expect(function()
                dsl.strict.spriteButton({
                    sprite = "btn",
                    shadow = "drop"
                })
            end).to_throw()
        end)

        t.it("rejects children as string", function()
            t.expect(function()
                dsl.strict.spriteButton({
                    sprite = "btn",
                    children = "text content"
                })
            end).to_throw()
        end)
    end)

    t.describe("error messages", function()
        t.it("includes component name in error", function()
            local success, err = pcall(function()
                dsl.strict.spriteButton({ onClick = "bad" })
            end)
            t.expect(success).to_be(false)
            t.expect(tostring(err)).to_contain("dsl.strict.spriteButton")
        end)

        t.it("includes property name in error", function()
            local success, err = pcall(function()
                dsl.strict.spriteButton({ sprite = 123 })
            end)
            t.expect(success).to_be(false)
            t.expect(tostring(err)).to_contain("sprite")
        end)
    end)
end)

--------------------------------------------------------------------------------
-- dsl.strict.spritePanel Tests
--------------------------------------------------------------------------------

t.describe("dsl.strict.spritePanel", function()
    t.describe("valid props", function()
        t.it("accepts sprite name", function()
            local result = dsl.strict.spritePanel({ sprite = "panel.png" })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts borders as array", function()
            local result = dsl.strict.spritePanel({
                sprite = "panel.png",
                borders = { 8, 8, 8, 8 }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts borders as named table", function()
            local result = dsl.strict.spritePanel({
                sprite = "panel.png",
                borders = { left = 10, top = 10, right = 10, bottom = 10 }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts sizing enum", function()
            local result = dsl.strict.spritePanel({
                sprite = "panel.png",
                sizing = "fit_content"
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts sizing as fixed", function()
            local result = dsl.strict.spritePanel({
                sprite = "panel.png",
                sizing = "fixed"
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts sizing as stretch", function()
            local result = dsl.strict.spritePanel({
                sprite = "panel.png",
                sizing = "stretch"
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts children array", function()
            local result = dsl.strict.spritePanel({
                sprite = "panel.png",
                children = {
                    dsl.text("Title"),
                    dsl.text("Content")
                }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts dimension constraints", function()
            local result = dsl.strict.spritePanel({
                sprite = "panel.png",
                minWidth = 200,
                minHeight = 150,
                maxWidth = 400,
                maxHeight = 300
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts interaction props", function()
            local result = dsl.strict.spritePanel({
                sprite = "panel.png",
                hover = true,
                canCollide = true
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts containerType enum", function()
            local result = dsl.strict.spritePanel({
                sprite = "panel.png",
                containerType = "HORIZONTAL_CONTAINER"
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts tint color", function()
            local result = dsl.strict.spritePanel({
                sprite = "panel.png",
                tint = "gold"
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts empty options", function()
            local result = dsl.strict.spritePanel({})
            t.expect(result).to_be_truthy()
        end)
    end)

    t.describe("decorations array", function()
        t.it("accepts empty decorations array", function()
            local result = dsl.strict.spritePanel({
                sprite = "panel.png",
                decorations = {}
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts single decoration", function()
            local result = dsl.strict.spritePanel({
                sprite = "panel.png",
                decorations = {
                    { sprite = "corner.png", position = "top_left" }
                }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts multiple decorations", function()
            local result = dsl.strict.spritePanel({
                sprite = "panel.png",
                decorations = {
                    { sprite = "corner_tl.png", position = "top_left" },
                    { sprite = "corner_tr.png", position = "top_right" },
                    { sprite = "corner_bl.png", position = "bottom_left" },
                    { sprite = "corner_br.png", position = "bottom_right" }
                }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts decoration with offset", function()
            local result = dsl.strict.spritePanel({
                sprite = "panel.png",
                decorations = {
                    { sprite = "gem.png", position = "top_center", offset = { -4, -4 } }
                }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts decoration with scale", function()
            local result = dsl.strict.spritePanel({
                sprite = "panel.png",
                decorations = {
                    { sprite = "emblem.png", position = "center", scale = { 0.5, 0.5 } }
                }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts decoration with rotation", function()
            local result = dsl.strict.spritePanel({
                sprite = "panel.png",
                decorations = {
                    { sprite = "arrow.png", position = "middle_right", rotation = 90 }
                }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts decoration with opacity", function()
            local result = dsl.strict.spritePanel({
                sprite = "panel.png",
                decorations = {
                    { sprite = "glow.png", position = "center", opacity = 0.5 }
                }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts decoration with flip", function()
            local result = dsl.strict.spritePanel({
                sprite = "panel.png",
                decorations = {
                    { sprite = "arrow.png", position = "middle_left", flip = "x" }
                }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts decoration with zOffset", function()
            local result = dsl.strict.spritePanel({
                sprite = "panel.png",
                decorations = {
                    { sprite = "overlay.png", position = "center", zOffset = 10 }
                }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts decoration with visible flag", function()
            local result = dsl.strict.spritePanel({
                sprite = "panel.png",
                decorations = {
                    { sprite = "hidden.png", position = "center", visible = false }
                }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts decoration with id", function()
            local result = dsl.strict.spritePanel({
                sprite = "panel.png",
                decorations = {
                    { sprite = "badge.png", position = "top_right", id = "badge_decor" }
                }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts decoration with all options", function()
            local result = dsl.strict.spritePanel({
                sprite = "panel.png",
                decorations = {
                    {
                        sprite = "fancy.png",
                        position = "top_center",
                        offset = { 0, -8 },
                        scale = { 0.8, 0.8 },
                        rotation = 0,
                        opacity = 1.0,
                        flip = "y",
                        zOffset = 5,
                        visible = true,
                        id = "fancy_decor"
                    }
                }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("rejects decorations as string", function()
            t.expect(function()
                dsl.strict.spritePanel({
                    sprite = "panel.png",
                    decorations = "corner.png"
                })
            end).to_throw()
        end)

        t.it("rejects decorations as number", function()
            t.expect(function()
                dsl.strict.spritePanel({
                    sprite = "panel.png",
                    decorations = 4
                })
            end).to_throw()
        end)
    end)

    t.describe("regions validation", function()
        t.it("accepts regions as table", function()
            local result = dsl.strict.spritePanel({
                sprite = "panel.png",
                regions = { header = { 0, 0, 100, 30 } }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("rejects regions as string", function()
            t.expect(function()
                dsl.strict.spritePanel({
                    sprite = "panel.png",
                    regions = "header"
                })
            end).to_throw()
        end)
    end)

    t.describe("invalid props", function()
        t.it("rejects sprite as number", function()
            t.expect(function()
                dsl.strict.spritePanel({ sprite = 123 })
            end).to_throw()
        end)

        t.it("rejects borders as string", function()
            t.expect(function()
                dsl.strict.spritePanel({
                    sprite = "panel.png",
                    borders = "8px"
                })
            end).to_throw()
        end)

        t.it("rejects borders as number", function()
            t.expect(function()
                dsl.strict.spritePanel({
                    sprite = "panel.png",
                    borders = 8
                })
            end).to_throw()
        end)

        t.it("rejects invalid sizing enum", function()
            t.expect(function()
                dsl.strict.spritePanel({
                    sprite = "panel.png",
                    sizing = "auto"
                })
            end).to_throw()
        end)

        t.it("rejects invalid containerType enum", function()
            t.expect(function()
                dsl.strict.spritePanel({
                    sprite = "panel.png",
                    containerType = "GRID"
                })
            end).to_throw()
        end)

        t.it("rejects minWidth as string", function()
            t.expect(function()
                dsl.strict.spritePanel({
                    sprite = "panel.png",
                    minWidth = "200px"
                })
            end).to_throw()
        end)

        t.it("rejects padding as string", function()
            t.expect(function()
                dsl.strict.spritePanel({
                    sprite = "panel.png",
                    padding = "10px"
                })
            end).to_throw()
        end)

        t.it("rejects hover as string", function()
            t.expect(function()
                dsl.strict.spritePanel({
                    sprite = "panel.png",
                    hover = "enabled"
                })
            end).to_throw()
        end)

        t.it("rejects canCollide as string", function()
            t.expect(function()
                dsl.strict.spritePanel({
                    sprite = "panel.png",
                    canCollide = "yes"
                })
            end).to_throw()
        end)

        t.it("rejects children as string", function()
            t.expect(function()
                dsl.strict.spritePanel({
                    sprite = "panel.png",
                    children = "content"
                })
            end).to_throw()
        end)
    end)

    t.describe("error messages", function()
        t.it("includes component name in error", function()
            local success, err = pcall(function()
                dsl.strict.spritePanel({ sprite = 123 })
            end)
            t.expect(success).to_be(false)
            t.expect(tostring(err)).to_contain("dsl.strict.spritePanel")
        end)

        t.it("includes property name in error", function()
            local success, err = pcall(function()
                dsl.strict.spritePanel({
                    sprite = "panel.png",
                    sizing = "invalid"
                })
            end)
            t.expect(success).to_be(false)
            t.expect(tostring(err)).to_contain("sizing")
        end)

        t.it("includes enum values in error for invalid enum", function()
            local success, err = pcall(function()
                dsl.strict.spritePanel({
                    sprite = "panel.png",
                    sizing = "auto"
                })
            end)
            t.expect(success).to_be(false)
            t.expect(tostring(err)).to_contain("fit_content")
        end)
    end)
end)

--------------------------------------------------------------------------------
-- Cross-cutting Hover State Tests
--------------------------------------------------------------------------------

t.describe("hover state validation", function()
    t.it("button accepts hover as table with title and body", function()
        local result = dsl.strict.button("Hover", {
            hover = { title = "Tooltip Title", body = "Tooltip body text" }
        })
        t.expect(result).to_be_truthy()
    end)

    t.it("button rejects hover as string", function()
        t.expect(function()
            dsl.strict.button("Hover", { hover = "Tooltip text" })
        end).to_throw()
    end)

    t.it("button rejects hover as number", function()
        t.expect(function()
            dsl.strict.button("Hover", { hover = 1 })
        end).to_throw()
    end)

    t.it("button rejects hover as boolean true", function()
        -- Note: button's hover is expected to be a table, not boolean
        -- This differs from spritePanel where hover can be boolean
        t.expect(function()
            dsl.strict.button("Hover", { hover = true })
        end).to_throw()
    end)

    t.it("spritePanel accepts hover as boolean true", function()
        local result = dsl.strict.spritePanel({
            sprite = "panel.png",
            hover = true
        })
        t.expect(result).to_be_truthy()
    end)

    t.it("spritePanel accepts hover as boolean false", function()
        local result = dsl.strict.spritePanel({
            sprite = "panel.png",
            hover = false
        })
        t.expect(result).to_be_truthy()
    end)
end)

--------------------------------------------------------------------------------
-- Cross-cutting Tests
--------------------------------------------------------------------------------

t.describe("interactive components general behavior", function()
    t.it("regular dsl.* functions do not validate (no breaking changes)", function()
        -- These should NOT throw even with wrong types
        local result1 = dsl.button("Click", { onClick = "bad_handler" })
        local result2 = dsl.spriteButton({ sprite = 123 })
        local result3 = dsl.spritePanel({ borders = "8px" })

        t.expect(result1).to_be_truthy()
        t.expect(result2).to_be_truthy()
        t.expect(result3).to_be_truthy()
    end)

    t.it("all strict interactive components return truthy values on success", function()
        local button = dsl.strict.button("Click", { onClick = function() end })
        local spriteButton = dsl.strict.spriteButton({ sprite = "btn", onClick = function() end })
        local spritePanel = dsl.strict.spritePanel({ sprite = "panel.png" })

        t.expect(button).to_be_truthy()
        t.expect(spriteButton).to_be_truthy()
        t.expect(spritePanel).to_be_truthy()
    end)

    t.it("onClick must be function when provided across all components", function()
        -- button
        t.expect(function()
            dsl.strict.button("Click", { onClick = "string" })
        end).to_throw()

        -- spriteButton
        t.expect(function()
            dsl.strict.spriteButton({ sprite = "btn", onClick = 123 })
        end).to_throw()
    end)
end)

--------------------------------------------------------------------------------
-- Run tests
--------------------------------------------------------------------------------

if standalone or os.getenv("RUN_TESTS") then
    t.run()
end

return t
