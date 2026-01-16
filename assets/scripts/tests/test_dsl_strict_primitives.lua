--[[
================================================================================
TEST: dsl.strict.* Primitive Components
================================================================================
Verifies that all primitive UI components (text, anim, spacer) validate their
props correctly through the strict DSL API.

Tests cover:
- dsl.strict.text (content, fontSize, color, align)
- dsl.strict.anim (sprite/id, size w/h, isAnimation)
- dsl.strict.spacer (width, height)

Each test validates both valid and invalid prop combinations.

Run standalone: lua assets/scripts/tests/test_dsl_strict_primitives.lua
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
-- dsl.strict.text Tests
--------------------------------------------------------------------------------

t.describe("dsl.strict.text", function()
    t.describe("valid props", function()
        t.it("accepts positional text content", function()
            local result = dsl.strict.text("Hello World")
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts text with fontSize as number", function()
            local result = dsl.strict.text("Hello", { fontSize = 24 })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts text with color as string", function()
            local result = dsl.strict.text("Hello", { color = "white" })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts text with align as number (bitmask)", function()
            local align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER)
            local result = dsl.strict.text("Hello", { align = align })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts text with all valid styling props", function()
            local result = dsl.strict.text("Hello", {
                fontSize = 16,
                fontName = "default",
                color = "blue",
                shadow = true,
                align = AlignmentFlag.LEFT,
                id = "my_text"
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts text with interaction props", function()
            local result = dsl.strict.text("Clickable", {
                onClick = function() end,
                hover = { title = "Title", body = "Description" },
                tooltip = { text = "Tooltip" }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts empty options table", function()
            local result = dsl.strict.text("Hello", {})
            t.expect(result).to_be_truthy()
        end)
    end)

    t.describe("invalid props", function()
        t.it("rejects fontSize as string", function()
            t.expect(function()
                dsl.strict.text("Hello", { fontSize = "sixteen" })
            end).to_throw()
        end)

        t.it("rejects fontSize as table", function()
            t.expect(function()
                dsl.strict.text("Hello", { fontSize = { size = 16 } })
            end).to_throw()
        end)

        t.it("rejects align as string", function()
            t.expect(function()
                dsl.strict.text("Hello", { align = "center" })
            end).to_throw()
        end)

        t.it("rejects shadow as string", function()
            t.expect(function()
                dsl.strict.text("Hello", { shadow = "yes" })
            end).to_throw()
        end)

        t.it("rejects onClick as string", function()
            t.expect(function()
                dsl.strict.text("Hello", { onClick = "handleClick" })
            end).to_throw()
        end)

        t.it("rejects hover as string", function()
            t.expect(function()
                dsl.strict.text("Hello", { hover = "tooltip text" })
            end).to_throw()
        end)
    end)

    t.describe("error messages", function()
        t.it("includes component name in error", function()
            local success, err = pcall(function()
                dsl.strict.text("Hello", { fontSize = "bad" })
            end)
            t.expect(success).to_be(false)
            t.expect(tostring(err)).to_contain("dsl.strict.text")
        end)

        t.it("includes property name in error", function()
            local success, err = pcall(function()
                dsl.strict.text("Hello", { fontSize = "bad" })
            end)
            t.expect(success).to_be(false)
            t.expect(tostring(err)).to_contain("fontSize")
        end)
    end)
end)

--------------------------------------------------------------------------------
-- dsl.strict.anim Tests (sprite/image component)
--------------------------------------------------------------------------------

t.describe("dsl.strict.anim", function()
    t.describe("valid props", function()
        t.it("accepts positional sprite id", function()
            local result = dsl.strict.anim("player_sprite.png")
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts sprite with dimensions", function()
            local result = dsl.strict.anim("icon.png", { w = 64, h = 64 })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts sprite with shadow option", function()
            local result = dsl.strict.anim("icon.png", { shadow = false })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts sprite with isAnimation flag", function()
            local result = dsl.strict.anim("walk_animation", { isAnimation = true })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts all valid props together", function()
            local result = dsl.strict.anim("character.png", {
                w = 48,
                h = 48,
                shadow = true,
                isAnimation = false
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts empty options table", function()
            local result = dsl.strict.anim("sprite.png", {})
            t.expect(result).to_be_truthy()
        end)
    end)

    t.describe("invalid props", function()
        t.it("rejects w as string", function()
            t.expect(function()
                dsl.strict.anim("icon.png", { w = "64px" })
            end).to_throw()
        end)

        t.it("rejects h as string", function()
            t.expect(function()
                dsl.strict.anim("icon.png", { h = "64" })
            end).to_throw()
        end)

        t.it("rejects shadow as string", function()
            t.expect(function()
                dsl.strict.anim("icon.png", { shadow = "true" })
            end).to_throw()
        end)

        t.it("rejects isAnimation as string", function()
            t.expect(function()
                dsl.strict.anim("anim_id", { isAnimation = "yes" })
            end).to_throw()
        end)

        t.it("rejects dimensions as table", function()
            t.expect(function()
                dsl.strict.anim("icon.png", { w = { value = 64 } })
            end).to_throw()
        end)
    end)

    t.describe("error messages", function()
        t.it("includes component name in error", function()
            local success, err = pcall(function()
                dsl.strict.anim("icon.png", { w = "bad" })
            end)
            t.expect(success).to_be(false)
            t.expect(tostring(err)).to_contain("dsl.strict.anim")
        end)

        t.it("includes property name in error", function()
            local success, err = pcall(function()
                dsl.strict.anim("icon.png", { h = {} })
            end)
            t.expect(success).to_be(false)
            t.expect(tostring(err)).to_contain("h")
        end)
    end)
end)

--------------------------------------------------------------------------------
-- dsl.strict.spacer Tests
--------------------------------------------------------------------------------

t.describe("dsl.strict.spacer", function()
    t.describe("valid props", function()
        t.it("accepts width only (positional)", function()
            local result = dsl.strict.spacer(20)
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts width and height (positional)", function()
            local result = dsl.strict.spacer(20, 10)
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts zero dimensions", function()
            local result = dsl.strict.spacer(0, 0)
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts decimal dimensions", function()
            local result = dsl.strict.spacer(10.5, 20.5)
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts nil width (uses default)", function()
            -- When w is nil, dsl.spacer uses default of 10
            local result = dsl.strict.spacer(nil, 20)
            t.expect(result).to_be_truthy()
        end)
    end)

    t.describe("invalid props", function()
        t.it("rejects w as string", function()
            t.expect(function()
                dsl.strict.spacer("20px")
            end).to_throw()
        end)

        t.it("rejects h as string", function()
            t.expect(function()
                dsl.strict.spacer(20, "10px")
            end).to_throw()
        end)

        t.it("rejects w as table", function()
            t.expect(function()
                dsl.strict.spacer({ width = 20 })
            end).to_throw()
        end)
    end)

    t.describe("error messages", function()
        t.it("includes component name in error", function()
            local success, err = pcall(function()
                dsl.strict.spacer("bad")
            end)
            t.expect(success).to_be(false)
            t.expect(tostring(err)).to_contain("dsl.strict.spacer")
        end)

        t.it("includes property name in error", function()
            local success, err = pcall(function()
                dsl.strict.spacer(nil, nil, { w = "bad" })
            end)
            t.expect(success).to_be(false)
            t.expect(tostring(err)).to_contain("w")
        end)
    end)
end)

--------------------------------------------------------------------------------
-- dsl.strict.divider Tests (bonus primitive)
--------------------------------------------------------------------------------

t.describe("dsl.strict.divider", function()
    t.describe("valid props", function()
        t.it("accepts horizontal direction", function()
            local result = dsl.strict.divider("horizontal")
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts vertical direction", function()
            local result = dsl.strict.divider("vertical")
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts direction with styling", function()
            local result = dsl.strict.divider("horizontal", {
                color = "gray",
                thickness = 2,
                length = 100
            })
            t.expect(result).to_be_truthy()
        end)
    end)

    t.describe("invalid props", function()
        t.it("rejects invalid direction enum", function()
            t.expect(function()
                dsl.strict.divider("diagonal")
            end).to_throw()
        end)

        t.it("rejects thickness as string", function()
            t.expect(function()
                dsl.strict.divider("horizontal", { thickness = "2px" })
            end).to_throw()
        end)

        t.it("rejects length as string", function()
            t.expect(function()
                dsl.strict.divider("horizontal", { length = "100%" })
            end).to_throw()
        end)
    end)
end)

--------------------------------------------------------------------------------
-- dsl.strict.iconLabel Tests (bonus primitive)
--------------------------------------------------------------------------------

t.describe("dsl.strict.iconLabel", function()
    t.describe("valid props", function()
        t.it("accepts positional icon and label", function()
            local result = dsl.strict.iconLabel("coin.png", "100 Gold")
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts with styling options", function()
            local result = dsl.strict.iconLabel("heart.png", "Health", {
                iconSize = 24,
                fontSize = 16,
                textColor = "white",
                shadow = true,
                padding = 4
            })
            t.expect(result).to_be_truthy()
        end)
    end)

    t.describe("invalid props", function()
        t.it("rejects iconSize as string", function()
            t.expect(function()
                dsl.strict.iconLabel("icon.png", "Label", { iconSize = "24px" })
            end).to_throw()
        end)

        t.it("rejects fontSize as string", function()
            t.expect(function()
                dsl.strict.iconLabel("icon.png", "Label", { fontSize = "medium" })
            end).to_throw()
        end)

        t.it("rejects padding as string", function()
            t.expect(function()
                dsl.strict.iconLabel("icon.png", "Label", { padding = "4px" })
            end).to_throw()
        end)
    end)
end)

--------------------------------------------------------------------------------
-- Cross-cutting Tests
--------------------------------------------------------------------------------

t.describe("primitive components general behavior", function()
    t.it("regular dsl.* functions do not validate (no breaking changes)", function()
        -- These should NOT throw even with wrong types
        local result1 = dsl.text("Hello", { fontSize = "sixteen" })
        local result2 = dsl.anim("icon.png", { w = "big" })
        local result3 = dsl.spacer("20px")

        t.expect(result1).to_be_truthy()
        t.expect(result2).to_be_truthy()
        t.expect(result3).to_be_truthy()
    end)

    t.it("all strict primitives return truthy values on success", function()
        local text = dsl.strict.text("Hello", { fontSize = 16 })
        local anim = dsl.strict.anim("icon.png", { w = 32, h = 32 })
        local spacer = dsl.strict.spacer(10, 10)

        -- All should return truthy values (actual structure depends on mocks)
        t.expect(text).to_be_truthy()
        t.expect(anim).to_be_truthy()
        t.expect(spacer).to_be_truthy()
    end)
end)

--------------------------------------------------------------------------------
-- Run tests
--------------------------------------------------------------------------------

if standalone or os.getenv("RUN_TESTS") then
    t.run()
end

return t
