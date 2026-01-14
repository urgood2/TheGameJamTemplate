--[[
================================================================================
TEST: Layout Showcase Registration (US-013)
================================================================================
Verifies that all layout showcases are properly registered in the showcase
registry and have required fields.

Acceptance Criteria:
- [x] Showcase for vbox with various spacing and alignment
- [x] Showcase for hbox with various spacing and alignment
- [x] Showcase for nested layouts (complex compositions)
- [x] Showcase for root with different config options
- [x] Each showcase demonstrates common patterns

Run standalone: lua assets/scripts/tests/test_layout_showcases.lua
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

-- Load test runner
local t = require("tests.test_runner")

-- Load showcase registry
local ShowcaseRegistry = require("ui.showcase.showcase_registry")

--------------------------------------------------------------------------------
-- Layout Category Tests
--------------------------------------------------------------------------------

t.describe("layouts category", function()
    t.it("exists in showcase registry", function()
        local categories = ShowcaseRegistry.getCategories()
        local hasLayouts = false
        for _, cat in ipairs(categories) do
            if cat == "layouts" then
                hasLayouts = true
                break
            end
        end
        t.expect(hasLayouts).to_be(true)
    end)

    t.it("returns showcases from getShowcases", function()
        local showcases = ShowcaseRegistry.getShowcases("layouts")
        t.expect(#showcases > 0).to_be(true)
    end)

    t.it("has category display name", function()
        local name = ShowcaseRegistry.getCategoryName("layouts")
        t.expect(name).to_equal("Layouts")
    end)
end)

--------------------------------------------------------------------------------
-- VBox Showcases Tests
--------------------------------------------------------------------------------

t.describe("vbox showcases", function()
    t.describe("vbox_basic", function()
        t.it("exists in registry", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "vbox_basic")
            t.expect(showcase).to_be_truthy()
        end)

        t.it("has required name field", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "vbox_basic")
            t.expect(showcase.name).to_be_truthy()
        end)

        t.it("has required description field", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "vbox_basic")
            t.expect(showcase.description).to_be_truthy()
        end)

        t.it("has required source field", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "vbox_basic")
            t.expect(showcase.source).to_be_truthy()
        end)

        t.it("has required create function", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "vbox_basic")
            t.expect(type(showcase.create)).to_be("function")
        end)
    end)

    t.describe("vbox_spacing", function()
        t.it("exists in registry", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "vbox_spacing")
            t.expect(showcase).to_be_truthy()
        end)

        t.it("demonstrates various spacing values", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "vbox_spacing")
            -- Source should mention multiple spacing values
            t.expect(showcase.source).to_contain("spacing = 0")
            t.expect(showcase.source).to_contain("spacing = 4")
            t.expect(showcase.source).to_contain("spacing = 8")
            t.expect(showcase.source).to_contain("spacing = 16")
        end)

        t.it("has create function that returns truthy value", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "vbox_spacing")
            local result = showcase.create()
            t.expect(result).to_be_truthy()
        end)
    end)

    t.describe("vbox_align_horizontal", function()
        t.it("exists in registry", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "vbox_align_horizontal")
            t.expect(showcase).to_be_truthy()
        end)

        t.it("demonstrates horizontal alignment flags", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "vbox_align_horizontal")
            t.expect(showcase.source).to_contain("HORIZONTAL_LEFT")
            t.expect(showcase.source).to_contain("HORIZONTAL_CENTER")
            t.expect(showcase.source).to_contain("HORIZONTAL_RIGHT")
        end)
    end)

    t.describe("vbox_align_vertical", function()
        t.it("exists in registry", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "vbox_align_vertical")
            t.expect(showcase).to_be_truthy()
        end)

        t.it("demonstrates vertical alignment flags", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "vbox_align_vertical")
            t.expect(showcase.source).to_contain("VERTICAL_TOP")
            t.expect(showcase.source).to_contain("VERTICAL_CENTER")
            t.expect(showcase.source).to_contain("VERTICAL_BOTTOM")
        end)
    end)

    t.describe("vbox_full_config", function()
        t.it("exists in registry", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "vbox_full_config")
            t.expect(showcase).to_be_truthy()
        end)

        t.it("demonstrates all config options", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "vbox_full_config")
            t.expect(showcase.source).to_contain("spacing")
            t.expect(showcase.source).to_contain("padding")
            t.expect(showcase.source).to_contain("color")
            t.expect(showcase.source).to_contain("align")
            t.expect(showcase.source).to_contain("minWidth")
            t.expect(showcase.source).to_contain("id")
        end)
    end)
end)

--------------------------------------------------------------------------------
-- HBox Showcases Tests
--------------------------------------------------------------------------------

t.describe("hbox showcases", function()
    t.describe("hbox_basic", function()
        t.it("exists in registry", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "hbox_basic")
            t.expect(showcase).to_be_truthy()
        end)

        t.it("has all required fields", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "hbox_basic")
            t.expect(showcase.name).to_be_truthy()
            t.expect(showcase.description).to_be_truthy()
            t.expect(showcase.source).to_be_truthy()
            t.expect(type(showcase.create)).to_be("function")
        end)
    end)

    t.describe("hbox_spacing", function()
        t.it("exists in registry", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "hbox_spacing")
            t.expect(showcase).to_be_truthy()
        end)

        t.it("demonstrates various spacing values", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "hbox_spacing")
            t.expect(showcase.source).to_contain("spacing = 0")
            t.expect(showcase.source).to_contain("spacing = 8")
            t.expect(showcase.source).to_contain("spacing = 16")
            t.expect(showcase.source).to_contain("spacing = 24")
        end)
    end)

    t.describe("hbox_align_horizontal", function()
        t.it("exists in registry", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "hbox_align_horizontal")
            t.expect(showcase).to_be_truthy()
        end)

        t.it("demonstrates horizontal alignment flags", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "hbox_align_horizontal")
            t.expect(showcase.source).to_contain("HORIZONTAL_LEFT")
            t.expect(showcase.source).to_contain("HORIZONTAL_CENTER")
            t.expect(showcase.source).to_contain("HORIZONTAL_RIGHT")
        end)
    end)

    t.describe("hbox_align_vertical", function()
        t.it("exists in registry", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "hbox_align_vertical")
            t.expect(showcase).to_be_truthy()
        end)

        t.it("demonstrates vertical alignment flags", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "hbox_align_vertical")
            t.expect(showcase.source).to_contain("VERTICAL_TOP")
            t.expect(showcase.source).to_contain("VERTICAL_CENTER")
            t.expect(showcase.source).to_contain("VERTICAL_BOTTOM")
        end)
    end)

    t.describe("hbox_full_config", function()
        t.it("exists in registry", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "hbox_full_config")
            t.expect(showcase).to_be_truthy()
        end)

        t.it("demonstrates all config options", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "hbox_full_config")
            t.expect(showcase.source).to_contain("spacing")
            t.expect(showcase.source).to_contain("padding")
            t.expect(showcase.source).to_contain("color")
            t.expect(showcase.source).to_contain("align")
            t.expect(showcase.source).to_contain("minHeight")
            t.expect(showcase.source).to_contain("id")
        end)
    end)
end)

--------------------------------------------------------------------------------
-- Nested Layout Showcases Tests
--------------------------------------------------------------------------------

t.describe("nested layout showcases", function()
    t.describe("nested_columns", function()
        t.it("exists in registry", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "nested_columns")
            t.expect(showcase).to_be_truthy()
        end)

        t.it("demonstrates hbox containing vbox pattern", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "nested_columns")
            t.expect(showcase.source).to_contain("dsl.hbox")
            t.expect(showcase.source).to_contain("dsl.vbox")
        end)

        t.it("has all required fields", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "nested_columns")
            t.expect(showcase.name).to_be_truthy()
            t.expect(showcase.description).to_be_truthy()
            t.expect(showcase.source).to_be_truthy()
            t.expect(type(showcase.create)).to_be("function")
        end)
    end)

    t.describe("nested_rows", function()
        t.it("exists in registry", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "nested_rows")
            t.expect(showcase).to_be_truthy()
        end)

        t.it("demonstrates vbox containing hbox pattern", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "nested_rows")
            t.expect(showcase.source).to_contain("dsl.vbox")
            t.expect(showcase.source).to_contain("dsl.hbox")
        end)
    end)

    t.describe("nested_complex", function()
        t.it("exists in registry", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "nested_complex")
            t.expect(showcase).to_be_truthy()
        end)

        t.it("demonstrates sidebar + main content pattern", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "nested_complex")
            t.expect(showcase.source).to_contain("Sidebar")
            t.expect(showcase.source).to_contain("Main")
        end)

        t.it("shows multiple nesting levels", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "nested_complex")
            -- Should have nested hbox inside vbox
            t.expect(showcase.source).to_contain("dsl.hbox")
            t.expect(showcase.source).to_contain("dsl.vbox")
            t.expect(showcase.source).to_contain("dsl.button")
        end)
    end)

    t.describe("nested_deep", function()
        t.it("exists in registry", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "nested_deep")
            t.expect(showcase).to_be_truthy()
        end)

        t.it("demonstrates 4+ levels of nesting", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "nested_deep")
            t.expect(showcase.source).to_contain("dsl.root")
            t.expect(showcase.source).to_contain("dsl.vbox")
            t.expect(showcase.source).to_contain("dsl.hbox")
            -- Description mentions levels
            t.expect(showcase.description).to_contain("levels")
        end)
    end)
end)

--------------------------------------------------------------------------------
-- Root Showcases Tests
--------------------------------------------------------------------------------

t.describe("root showcases", function()
    t.describe("root_basic", function()
        t.it("exists in registry", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "root_basic")
            t.expect(showcase).to_be_truthy()
        end)

        t.it("demonstrates minimal root usage", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "root_basic")
            t.expect(showcase.source).to_contain("dsl.root")
            t.expect(showcase.source).to_contain("children")
        end)
    end)

    t.describe("root_padding", function()
        t.it("exists in registry", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "root_padding")
            t.expect(showcase).to_be_truthy()
        end)

        t.it("demonstrates various padding values", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "root_padding")
            t.expect(showcase.source).to_contain("padding = 0")
            t.expect(showcase.source).to_contain("padding = 8")
            t.expect(showcase.source).to_contain("padding = 16")
        end)
    end)

    t.describe("root_alignment", function()
        t.it("exists in registry", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "root_alignment")
            t.expect(showcase).to_be_truthy()
        end)

        t.it("demonstrates alignment options", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "root_alignment")
            t.expect(showcase.source).to_contain("align")
            t.expect(showcase.source).to_contain("HORIZONTAL")
            t.expect(showcase.source).to_contain("VERTICAL")
        end)
    end)

    t.describe("root_full_config", function()
        t.it("exists in registry", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "root_full_config")
            t.expect(showcase).to_be_truthy()
        end)

        t.it("demonstrates all config options", function()
            local showcase = ShowcaseRegistry.getShowcase("layouts", "root_full_config")
            t.expect(showcase.source).to_contain("padding")
            t.expect(showcase.source).to_contain("color")
            t.expect(showcase.source).to_contain("align")
            t.expect(showcase.source).to_contain("minWidth")
            t.expect(showcase.source).to_contain("id")
        end)
    end)
end)

--------------------------------------------------------------------------------
-- Showcase Quality Tests
--------------------------------------------------------------------------------

t.describe("showcase quality", function()
    t.it("all layout showcases have create functions that return values", function()
        local showcases = ShowcaseRegistry.getShowcases("layouts")
        for _, showcase in ipairs(showcases) do
            t.expect(type(showcase.create)).to_be("function")
            local result = showcase.create()
            t.expect(result).to_be_truthy()
        end
    end)

    t.it("all layout showcases have non-empty source code", function()
        local showcases = ShowcaseRegistry.getShowcases("layouts")
        for _, showcase in ipairs(showcases) do
            t.expect(#showcase.source > 10).to_be(true)
        end
    end)

    t.it("all layout showcases have descriptions", function()
        local showcases = ShowcaseRegistry.getShowcases("layouts")
        for _, showcase in ipairs(showcases) do
            t.expect(showcase.description).to_be_truthy()
            t.expect(#showcase.description > 5).to_be(true)
        end
    end)

    t.it("layout category has at least 15 showcases", function()
        local showcases = ShowcaseRegistry.getShowcases("layouts")
        t.expect(#showcases >= 15).to_be(true)
    end)
end)

--------------------------------------------------------------------------------
-- Acceptance Criteria Verification
--------------------------------------------------------------------------------

t.describe("acceptance criteria verification", function()
    t.it("AC1: vbox showcases demonstrate various spacing", function()
        local showcase = ShowcaseRegistry.getShowcase("layouts", "vbox_spacing")
        t.expect(showcase).to_be_truthy()
        t.expect(showcase.description).to_contain("spacing")
    end)

    t.it("AC1: vbox showcases demonstrate various alignment", function()
        local hAlign = ShowcaseRegistry.getShowcase("layouts", "vbox_align_horizontal")
        local vAlign = ShowcaseRegistry.getShowcase("layouts", "vbox_align_vertical")
        t.expect(hAlign).to_be_truthy()
        t.expect(vAlign).to_be_truthy()
    end)

    t.it("AC2: hbox showcases demonstrate various spacing", function()
        local showcase = ShowcaseRegistry.getShowcase("layouts", "hbox_spacing")
        t.expect(showcase).to_be_truthy()
        t.expect(showcase.description).to_contain("spacing")
    end)

    t.it("AC2: hbox showcases demonstrate various alignment", function()
        local hAlign = ShowcaseRegistry.getShowcase("layouts", "hbox_align_horizontal")
        local vAlign = ShowcaseRegistry.getShowcase("layouts", "hbox_align_vertical")
        t.expect(hAlign).to_be_truthy()
        t.expect(vAlign).to_be_truthy()
    end)

    t.it("AC3: nested layout showcases exist", function()
        local columns = ShowcaseRegistry.getShowcase("layouts", "nested_columns")
        local rows = ShowcaseRegistry.getShowcase("layouts", "nested_rows")
        local complex = ShowcaseRegistry.getShowcase("layouts", "nested_complex")
        local deep = ShowcaseRegistry.getShowcase("layouts", "nested_deep")
        t.expect(columns).to_be_truthy()
        t.expect(rows).to_be_truthy()
        t.expect(complex).to_be_truthy()
        t.expect(deep).to_be_truthy()
    end)

    t.it("AC4: root showcases with different config options exist", function()
        local basic = ShowcaseRegistry.getShowcase("layouts", "root_basic")
        local padding = ShowcaseRegistry.getShowcase("layouts", "root_padding")
        local alignment = ShowcaseRegistry.getShowcase("layouts", "root_alignment")
        local full = ShowcaseRegistry.getShowcase("layouts", "root_full_config")
        t.expect(basic).to_be_truthy()
        t.expect(padding).to_be_truthy()
        t.expect(alignment).to_be_truthy()
        t.expect(full).to_be_truthy()
    end)

    t.it("AC5: showcases demonstrate common patterns", function()
        -- Check that showcases include real-world patterns
        local complex = ShowcaseRegistry.getShowcase("layouts", "nested_complex")
        -- Sidebar + main content is a common app structure
        t.expect(complex.description).to_contain("common")
    end)
end)

--------------------------------------------------------------------------------
-- Run tests
--------------------------------------------------------------------------------

if standalone or os.getenv("RUN_TESTS") then
    t.run()
end

return t
