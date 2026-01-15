--[[
================================================================================
TEST: Pattern Showcase Registration (US-014)
================================================================================
Verifies that all pattern showcases are properly registered in the showcase
registry and have required fields.

Acceptance Criteria:
- [x] Showcase for tooltip pattern
- [x] Showcase for modal/dialog pattern
- [x] Showcase for inventory grid pattern
- [x] Showcase for button with icon and label
- [x] Showcase for panel with decorations

Run standalone: lua assets/scripts/tests/test_pattern_showcases.lua
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

-- Additional mocks needed for DSL
_G.AlignmentFlag = _G.AlignmentFlag or {
    HORIZONTAL_LEFT = 1,
    HORIZONTAL_CENTER = 2,
    HORIZONTAL_RIGHT = 4,
    VERTICAL_TOP = 8,
    VERTICAL_CENTER = 16,
    VERTICAL_BOTTOM = 32,
}
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
_G.log_error = _G.log_error or function() end
_G.init = _G.init or { getSpriteFrame = function() return nil end }
_G.globals = _G.globals or { g_ctx = {} }

-- Load test runner
local t = require("tests.test_runner")

-- Load showcase registry
local ShowcaseRegistry = require("ui.showcase.showcase_registry")

--------------------------------------------------------------------------------
-- Pattern Category Tests
--------------------------------------------------------------------------------

t.describe("patterns category", function()
    t.it("exists in showcase registry", function()
        local categories = ShowcaseRegistry.getCategories()
        local hasPatterns = false
        for _, cat in ipairs(categories) do
            if cat == "patterns" then
                hasPatterns = true
                break
            end
        end
        t.expect(hasPatterns).to_be(true)
    end)

    t.it("returns showcases from getShowcases", function()
        local showcases = ShowcaseRegistry.getShowcases("patterns")
        t.expect(#showcases > 0).to_be(true)
    end)

    t.it("has category display name", function()
        local name = ShowcaseRegistry.getCategoryName("patterns")
        t.expect(name).to_equal("Patterns")
    end)
end)

--------------------------------------------------------------------------------
-- Tooltip Pattern Tests (AC: Showcase for tooltip pattern)
--------------------------------------------------------------------------------

t.describe("tooltip pattern showcase", function()
    t.it("exists in registry", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "tooltip_pattern")
        t.expect(showcase).to_be_truthy()
    end)

    t.it("has required fields", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "tooltip_pattern")
        t.expect(showcase.name).to_be_truthy()
        t.expect(showcase.description).to_be_truthy()
        t.expect(showcase.source).to_be_truthy()
        t.expect(type(showcase.create)).to_equal("function")
    end)

    t.it("has meaningful name", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "tooltip_pattern")
        t.expect(showcase.name:lower()).to_contain("tooltip")
    end)

    t.it("source mentions tooltip structure elements", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "tooltip_pattern")
        -- Tooltip should have title, description
        t.expect(showcase.source).to_contain("Title")
        t.expect(showcase.source).to_contain("Description")
    end)

    t.it("create function returns valid definition", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "tooltip_pattern")
        local def = showcase.create()
        t.expect(def).to_be_truthy()
    end)
end)

--------------------------------------------------------------------------------
-- Modal/Dialog Pattern Tests (AC: Showcase for modal/dialog pattern)
--------------------------------------------------------------------------------

t.describe("modal dialog pattern showcase", function()
    t.it("exists in registry", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "modal_dialog")
        t.expect(showcase).to_be_truthy()
    end)

    t.it("has required fields", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "modal_dialog")
        t.expect(showcase.name).to_be_truthy()
        t.expect(showcase.description).to_be_truthy()
        t.expect(showcase.source).to_be_truthy()
        t.expect(type(showcase.create)).to_equal("function")
    end)

    t.it("has meaningful name", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "modal_dialog")
        local nameLower = showcase.name:lower()
        local hasModal = nameLower:find("modal") ~= nil
        local hasDialog = nameLower:find("dialog") ~= nil
        t.expect(hasModal or hasDialog).to_be(true)
    end)

    t.it("source mentions modal structure elements", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "modal_dialog")
        -- Modal should have header/Header or content/Content
        local hasHeader = showcase.source:find("Header") or showcase.source:find("header")
        local hasContent = showcase.source:find("Content") or showcase.source:find("content")
        t.expect(hasHeader ~= nil).to_be(true)
        t.expect(hasContent ~= nil).to_be(true)
    end)

    t.it("source mentions close button", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "modal_dialog")
        local hasClose = showcase.source:find("Close") or showcase.source:find("close")
        t.expect(hasClose ~= nil).to_be(true)
    end)

    t.it("create function returns valid definition", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "modal_dialog")
        local def = showcase.create()
        t.expect(def).to_be_truthy()
    end)
end)

--------------------------------------------------------------------------------
-- Inventory Grid Pattern Tests (AC: Showcase for inventory grid pattern)
--------------------------------------------------------------------------------

t.describe("inventory grid pattern showcase", function()
    t.it("exists in registry", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "inventory_grid")
        t.expect(showcase).to_be_truthy()
    end)

    t.it("has required fields", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "inventory_grid")
        t.expect(showcase.name).to_be_truthy()
        t.expect(showcase.description).to_be_truthy()
        t.expect(showcase.source).to_be_truthy()
        t.expect(type(showcase.create)).to_equal("function")
    end)

    t.it("has meaningful name", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "inventory_grid")
        local nameLower = showcase.name:lower()
        local hasInventory = nameLower:find("inventory") ~= nil
        local hasGrid = nameLower:find("grid") ~= nil
        t.expect(hasInventory or hasGrid).to_be(true)
    end)

    t.it("source demonstrates grid/slot pattern", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "inventory_grid")
        -- Grid should show slots
        local hasSlot = showcase.source:find("slot") or showcase.source:find("Slot")
        t.expect(hasSlot ~= nil).to_be(true)
    end)

    t.it("source mentions grid rows/cols", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "inventory_grid")
        -- Should show grid structure (hboxes for rows)
        local hasHbox = showcase.source:find("hbox")
        local hasGrid = showcase.source:find("grid")
        t.expect(hasHbox ~= nil or hasGrid ~= nil).to_be(true)
    end)

    t.it("create function returns valid definition", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "inventory_grid")
        local def = showcase.create()
        t.expect(def).to_be_truthy()
    end)
end)

--------------------------------------------------------------------------------
-- Button with Icon and Label Tests (AC: Showcase for button with icon and label)
--------------------------------------------------------------------------------

t.describe("button with icon and label showcase", function()
    t.it("exists in registry", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "button_icon_label")
        t.expect(showcase).to_be_truthy()
    end)

    t.it("has required fields", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "button_icon_label")
        t.expect(showcase.name).to_be_truthy()
        t.expect(showcase.description).to_be_truthy()
        t.expect(showcase.source).to_be_truthy()
        t.expect(type(showcase.create)).to_equal("function")
    end)

    t.it("has meaningful name", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "button_icon_label")
        local nameLower = showcase.name:lower()
        local hasIcon = nameLower:find("icon") ~= nil
        local hasButton = nameLower:find("button") ~= nil
        t.expect(hasIcon or hasButton).to_be(true)
    end)

    t.it("source mentions both icon and text", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "button_icon_label")
        -- Should combine icon (anim/image) with text
        local hasAnim = showcase.source:find("anim") ~= nil
        local hasText = showcase.source:find("text") or showcase.source:find("Text")
        t.expect(hasAnim).to_be(true)
        t.expect(hasText ~= nil).to_be(true)
    end)

    t.it("source shows button callback pattern", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "button_icon_label")
        local hasCallback = showcase.source:find("buttonCallback") or showcase.source:find("onClick")
        t.expect(hasCallback ~= nil).to_be(true)
    end)

    t.it("create function returns valid definition", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "button_icon_label")
        local def = showcase.create()
        t.expect(def).to_be_truthy()
    end)
end)

--------------------------------------------------------------------------------
-- Panel with Decorations Tests (AC: Showcase for panel with decorations)
--------------------------------------------------------------------------------

t.describe("panel with decorations showcase", function()
    t.it("exists in registry", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "panel_with_decorations")
        t.expect(showcase).to_be_truthy()
    end)

    t.it("has required fields", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "panel_with_decorations")
        t.expect(showcase.name).to_be_truthy()
        t.expect(showcase.description).to_be_truthy()
        t.expect(showcase.source).to_be_truthy()
        t.expect(type(showcase.create)).to_equal("function")
    end)

    t.it("has meaningful name", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "panel_with_decorations")
        local nameLower = showcase.name:lower()
        local hasPanel = nameLower:find("panel") ~= nil
        local hasDecoration = nameLower:find("decoration") ~= nil
        t.expect(hasPanel or hasDecoration).to_be(true)
    end)

    t.it("source mentions decorations", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "panel_with_decorations")
        local hasDecoration = showcase.source:find("decoration") or showcase.source:find("Decoration")
        t.expect(hasDecoration ~= nil).to_be(true)
    end)

    t.it("source shows position options", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "panel_with_decorations")
        -- Decorations have position attribute
        t.expect(showcase.source).to_contain("position")
    end)

    t.it("create function returns valid definition", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "panel_with_decorations")
        local def = showcase.create()
        t.expect(def).to_be_truthy()
    end)
end)

--------------------------------------------------------------------------------
-- Pattern Showcase Structure Tests
--------------------------------------------------------------------------------

t.describe("all pattern showcases", function()
    t.it("are in the order array", function()
        local showcases = ShowcaseRegistry.getShowcases("patterns")
        local expectedPatterns = {
            "tooltip_pattern",
            "modal_dialog",
            "inventory_grid",
            "button_icon_label",
            "panel_with_decorations",
        }

        for _, expected in ipairs(expectedPatterns) do
            local found = false
            for _, sc in ipairs(showcases) do
                if sc.id == expected then
                    found = true
                    break
                end
            end
            t.expect(found).to_be(true)
        end
    end)

    t.it("all have non-empty source code", function()
        local showcases = ShowcaseRegistry.getShowcases("patterns")
        for _, sc in ipairs(showcases) do
            t.expect(#sc.source > 0).to_be(true)
        end
    end)

    t.it("all have descriptions", function()
        local showcases = ShowcaseRegistry.getShowcases("patterns")
        for _, sc in ipairs(showcases) do
            t.expect(sc.description).to_be_truthy()
            t.expect(#sc.description > 0).to_be(true)
        end
    end)

    t.it("all create functions execute without error", function()
        local showcases = ShowcaseRegistry.getShowcases("patterns")
        for _, sc in ipairs(showcases) do
            local success, result = pcall(sc.create)
            t.expect(success).to_be(true)
        end
    end)
end)

--------------------------------------------------------------------------------
-- Existing Patterns (verify they still exist)
--------------------------------------------------------------------------------

t.describe("existing pattern showcases preserved", function()
    t.it("button_basic exists", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "button_basic")
        t.expect(showcase).to_be_truthy()
    end)

    t.it("sprite_panel exists", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "sprite_panel")
        t.expect(showcase).to_be_truthy()
    end)

    t.it("sprite_button exists", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "sprite_button")
        t.expect(showcase).to_be_truthy()
    end)

    t.it("form_layout exists", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "form_layout")
        t.expect(showcase).to_be_truthy()
    end)

    t.it("card_layout exists", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "card_layout")
        t.expect(showcase).to_be_truthy()
    end)
end)

--------------------------------------------------------------------------------
-- Acceptance Criteria Verification
--------------------------------------------------------------------------------

t.describe("acceptance criteria verification", function()
    t.it("AC1: tooltip pattern showcase exists with structure", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "tooltip_pattern")
        t.expect(showcase).to_be_truthy()
        -- Should be about contextual info, descriptions, stats
        local desc = showcase.description:lower()
        local hasInfo = desc:find("info") or desc:find("description") or desc:find("stats")
        t.expect(hasInfo ~= nil).to_be(true)
    end)

    t.it("AC2: modal/dialog pattern showcase exists with structure", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "modal_dialog")
        t.expect(showcase).to_be_truthy()
        local desc = showcase.description:lower()
        local hasModal = desc:find("modal") or desc:find("dialog")
        t.expect(hasModal ~= nil).to_be(true)
    end)

    t.it("AC3: inventory grid pattern showcase exists with structure", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "inventory_grid")
        t.expect(showcase).to_be_truthy()
        local desc = showcase.description:lower()
        local hasGrid = desc:find("grid") or desc:find("slot")
        t.expect(hasGrid ~= nil).to_be(true)
    end)

    t.it("AC4: button with icon and label showcase exists", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "button_icon_label")
        t.expect(showcase).to_be_truthy()
        -- Should have both icon and label in description or name
        local nameLower = showcase.name:lower()
        t.expect(nameLower:find("icon") ~= nil or nameLower:find("button") ~= nil).to_be(true)
    end)

    t.it("AC5: panel with decorations showcase exists", function()
        local showcase = ShowcaseRegistry.getShowcase("patterns", "panel_with_decorations")
        t.expect(showcase).to_be_truthy()
        -- Should mention decorations or decorative elements
        local desc = showcase.description:lower()
        local hasDecor = desc:find("decor") or desc:find("badge") or desc:find("overlay")
        t.expect(hasDecor ~= nil).to_be(true)
    end)
end)

--------------------------------------------------------------------------------
-- Run tests
--------------------------------------------------------------------------------

if standalone or os.getenv("RUN_TESTS") then
    t.run()
end

return t
