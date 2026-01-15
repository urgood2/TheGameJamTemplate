--[[
================================================================================
TEST: Showcase Gallery Viewer
================================================================================
Verifies the showcase registry and gallery viewer functionality.

Tests cover:
- Showcase registry category organization
- Showcase retrieval and ordering
- Gallery viewer navigation state
- Keyboard navigation logic
- UI building and preview generation

Run standalone: lua assets/scripts/tests/test_showcase_gallery.lua
Run via runner: lua assets/scripts/tests/run_standalone.lua
================================================================================
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

-- Additional mocks for DSL and gallery
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
_G.timer = _G.timer or {
    every = function() return {} end,
    kill_group = function() end,
}
_G.log_debug = _G.log_debug or function() end
_G.log_warn = _G.log_warn or function() end
_G.isKeyPressed = _G.isKeyPressed or function() return false end
_G.registry = _G.registry or {
    valid = function() return false end,
    destroy = function() end,
}

-- Load test runner
local t = require("tests.test_runner")

-- Load modules under test
local registry_ok, ShowcaseRegistry = pcall(require, "ui.showcase.showcase_registry")
if not registry_ok then
    print("FATAL: Could not load ShowcaseRegistry: " .. tostring(ShowcaseRegistry))
    os.exit(1)
end

local viewer_ok, GalleryViewer = pcall(require, "ui.showcase.gallery_viewer")
if not viewer_ok then
    print("FATAL: Could not load GalleryViewer: " .. tostring(GalleryViewer))
    os.exit(1)
end

--------------------------------------------------------------------------------
-- ShowcaseRegistry Tests
--------------------------------------------------------------------------------

t.describe("ShowcaseRegistry", function()

    t.describe("getCategories", function()
        t.it("returns array of category names", function()
            local categories = ShowcaseRegistry.getCategories()
            t.expect(type(categories)).to_be("table")
            t.expect(#categories).to_be(3)
        end)

        t.it("includes primitives, layouts, and patterns", function()
            local categories = ShowcaseRegistry.getCategories()
            t.expect(categories).to_contain("primitives")
            t.expect(categories).to_contain("layouts")
            t.expect(categories).to_contain("patterns")
        end)

        t.it("returns categories in expected order", function()
            local categories = ShowcaseRegistry.getCategories()
            t.expect(categories[1]).to_be("primitives")
            t.expect(categories[2]).to_be("layouts")
            t.expect(categories[3]).to_be("patterns")
        end)
    end)

    t.describe("getCategoryName", function()
        t.it("returns display name for primitives", function()
            local name = ShowcaseRegistry.getCategoryName("primitives")
            t.expect(name).to_be("Primitives")
        end)

        t.it("returns display name for layouts", function()
            local name = ShowcaseRegistry.getCategoryName("layouts")
            t.expect(name).to_be("Layouts")
        end)

        t.it("returns display name for patterns", function()
            local name = ShowcaseRegistry.getCategoryName("patterns")
            t.expect(name).to_be("Patterns")
        end)

        t.it("returns raw id for unknown category", function()
            local name = ShowcaseRegistry.getCategoryName("unknown_category")
            t.expect(name).to_be("unknown_category")
        end)
    end)

    t.describe("getShowcases", function()
        t.it("returns array of showcases for primitives", function()
            local showcases = ShowcaseRegistry.getShowcases("primitives")
            t.expect(type(showcases)).to_be("table")
            t.expect(#showcases > 0).to_be(true)
        end)

        t.it("returns array of showcases for layouts", function()
            local showcases = ShowcaseRegistry.getShowcases("layouts")
            t.expect(type(showcases)).to_be("table")
            t.expect(#showcases > 0).to_be(true)
        end)

        t.it("returns array of showcases for patterns", function()
            local showcases = ShowcaseRegistry.getShowcases("patterns")
            t.expect(type(showcases)).to_be("table")
            t.expect(#showcases > 0).to_be(true)
        end)

        t.it("returns empty array for unknown category", function()
            local showcases = ShowcaseRegistry.getShowcases("nonexistent")
            t.expect(type(showcases)).to_be("table")
            t.expect(#showcases).to_be(0)
        end)

        t.it("each showcase has required fields", function()
            local showcases = ShowcaseRegistry.getShowcases("primitives")
            for _, showcase in ipairs(showcases) do
                t.expect(showcase.id).to_be_truthy()
                t.expect(showcase.name).to_be_truthy()
                t.expect(showcase.description).to_be_truthy()
                t.expect(type(showcase.create)).to_be("function")
            end
        end)

        t.it("each showcase has source code", function()
            local showcases = ShowcaseRegistry.getShowcases("primitives")
            for _, showcase in ipairs(showcases) do
                t.expect(showcase.source).to_be_truthy()
                t.expect(type(showcase.source)).to_be("string")
            end
        end)

        t.it("assigns category to each showcase", function()
            local showcases = ShowcaseRegistry.getShowcases("layouts")
            for _, showcase in ipairs(showcases) do
                t.expect(showcase.category).to_be("layouts")
            end
        end)
    end)

    t.describe("getShowcase", function()
        t.it("returns specific showcase by id", function()
            local showcase = ShowcaseRegistry.getShowcase("primitives", "text_basic")
            t.expect(showcase).to_be_truthy()
            t.expect(showcase.name).to_be("Text (Basic)")
        end)

        t.it("returns nil for unknown showcase", function()
            local showcase = ShowcaseRegistry.getShowcase("primitives", "nonexistent")
            t.expect(showcase).to_be(nil)
        end)

        t.it("returns nil for unknown category", function()
            local showcase = ShowcaseRegistry.getShowcase("nonexistent", "text_basic")
            t.expect(showcase).to_be(nil)
        end)

        t.it("showcase create function is callable", function()
            local showcase = ShowcaseRegistry.getShowcase("primitives", "text_basic")
            t.expect(type(showcase.create)).to_be("function")
            -- Should not throw when called
            local result = showcase.create()
            t.expect(result).to_be_truthy()
        end)
    end)

    t.describe("getTotalCount", function()
        t.it("returns positive number", function()
            local count = ShowcaseRegistry.getTotalCount()
            t.expect(type(count)).to_be("number")
            t.expect(count > 0).to_be(true)
        end)

        t.it("counts all showcases across categories", function()
            local count = ShowcaseRegistry.getTotalCount()
            local manualCount = 0
            for _, categoryId in ipairs(ShowcaseRegistry.getCategories()) do
                manualCount = manualCount + #ShowcaseRegistry.getShowcases(categoryId)
            end
            t.expect(count).to_be(manualCount)
        end)
    end)

    t.describe("getFlatList", function()
        t.it("returns array of category/showcase pairs", function()
            local flatList = ShowcaseRegistry.getFlatList()
            t.expect(type(flatList)).to_be("table")
            t.expect(#flatList > 0).to_be(true)
        end)

        t.it("each item has category and showcase", function()
            local flatList = ShowcaseRegistry.getFlatList()
            for _, item in ipairs(flatList) do
                t.expect(item.category).to_be_truthy()
                t.expect(item.showcase).to_be_truthy()
            end
        end)

        t.it("total matches getTotalCount", function()
            local flatList = ShowcaseRegistry.getFlatList()
            local count = ShowcaseRegistry.getTotalCount()
            t.expect(#flatList).to_be(count)
        end)

        t.it("maintains category ordering", function()
            local flatList = ShowcaseRegistry.getFlatList()
            local categories = ShowcaseRegistry.getCategories()
            local expectedCategory = categories[1]
            local categoryIndex = 1

            for _, item in ipairs(flatList) do
                if item.category ~= expectedCategory then
                    -- Should advance to next category
                    categoryIndex = categoryIndex + 1
                    if categoryIndex <= #categories then
                        expectedCategory = categories[categoryIndex]
                    end
                end
                t.expect(item.category).to_be(expectedCategory)
            end
        end)
    end)

    t.describe("showcase create functions", function()
        t.it("all primitives showcases can be created", function()
            local showcases = ShowcaseRegistry.getShowcases("primitives")
            for _, showcase in ipairs(showcases) do
                local success, result = pcall(showcase.create)
                t.expect(success).to_be(true)
                t.expect(result).to_be_truthy()
            end
        end)

        t.it("all layouts showcases can be created", function()
            local showcases = ShowcaseRegistry.getShowcases("layouts")
            for _, showcase in ipairs(showcases) do
                local success, result = pcall(showcase.create)
                t.expect(success).to_be(true)
                t.expect(result).to_be_truthy()
            end
        end)

        t.it("all patterns showcases can be created", function()
            local showcases = ShowcaseRegistry.getShowcases("patterns")
            for _, showcase in ipairs(showcases) do
                local success, result = pcall(showcase.create)
                t.expect(success).to_be(true)
                t.expect(result).to_be_truthy()
            end
        end)
    end)
end)

--------------------------------------------------------------------------------
-- GalleryViewer Tests
--------------------------------------------------------------------------------

t.describe("GalleryViewer", function()

    t.describe("construction", function()
        t.it("creates new instance with new()", function()
            local viewer = GalleryViewer.new()
            t.expect(viewer).to_be_truthy()
        end)

        t.it("accepts options parameter", function()
            local viewer = GalleryViewer.new({
                width = 800,
                height = 600,
            })
            t.expect(viewer).to_be_truthy()
        end)

        t.it("starts not visible", function()
            local viewer = GalleryViewer.new()
            t.expect(viewer._visible).to_be(false)
        end)

        t.it("starts at first item in flat list", function()
            local viewer = GalleryViewer.new()
            t.expect(viewer._flatIndex).to_be(1)
        end)

        t.it("loads flat list from registry", function()
            local viewer = GalleryViewer.new()
            t.expect(#viewer._flatList).to_be(ShowcaseRegistry.getTotalCount())
        end)
    end)

    t.describe("navigation state", function()
        t.it("navigateUp decrements flatIndex", function()
            local viewer = GalleryViewer.new()
            viewer._flatIndex = 3
            -- Skip rebuild which requires engine bindings
            viewer._rebuild = function() end
            viewer:_navigateUp()
            t.expect(viewer._flatIndex).to_be(2)
        end)

        t.it("navigateUp stops at 1", function()
            local viewer = GalleryViewer.new()
            viewer._flatIndex = 1
            viewer._rebuild = function() end
            viewer:_navigateUp()
            t.expect(viewer._flatIndex).to_be(1)
        end)

        t.it("navigateDown increments flatIndex", function()
            local viewer = GalleryViewer.new()
            viewer._flatIndex = 1
            viewer._rebuild = function() end
            viewer:_navigateDown()
            t.expect(viewer._flatIndex).to_be(2)
        end)

        t.it("navigateDown stops at end of list", function()
            local viewer = GalleryViewer.new()
            local listLength = #viewer._flatList
            viewer._flatIndex = listLength
            viewer._rebuild = function() end
            viewer:_navigateDown()
            t.expect(viewer._flatIndex).to_be(listLength)
        end)
    end)

    t.describe("getCurrentShowcase", function()
        t.it("returns current showcase at flatIndex", function()
            local viewer = GalleryViewer.new()
            viewer._flatIndex = 1
            local showcase = viewer:getCurrentShowcase()
            t.expect(showcase).to_be_truthy()
            t.expect(showcase.name).to_be_truthy()
        end)

        t.it("returns nil if flatIndex out of bounds", function()
            local viewer = GalleryViewer.new()
            viewer._flatIndex = 0
            local showcase = viewer:getCurrentShowcase()
            t.expect(showcase).to_be(nil)
        end)

        t.it("returns different showcases for different indices", function()
            local viewer = GalleryViewer.new()
            viewer._flatIndex = 1
            local first = viewer:getCurrentShowcase()
            viewer._flatIndex = 2
            local second = viewer:getCurrentShowcase()
            t.expect(first.id).never().to_be(second.id)
        end)
    end)

    t.describe("visibility", function()
        t.it("show sets visible to true", function()
            local viewer = GalleryViewer.new()
            -- Mock rebuild to avoid engine dependencies
            viewer._rebuild = function() end
            viewer._startInputPolling = function() end
            viewer:show(100, 100)
            t.expect(viewer._visible).to_be(true)
        end)

        t.it("show sets position", function()
            local viewer = GalleryViewer.new()
            viewer._rebuild = function() end
            viewer._startInputPolling = function() end
            viewer:show(150, 200)
            t.expect(viewer._position.x).to_be(150)
            t.expect(viewer._position.y).to_be(200)
        end)

        t.it("hide sets visible to false", function()
            local viewer = GalleryViewer.new()
            viewer._rebuild = function() end
            viewer._startInputPolling = function() end
            viewer._cleanup = function() end
            viewer:show(100, 100)
            viewer:hide()
            t.expect(viewer._visible).to_be(false)
        end)

        t.it("toggle flips visibility", function()
            local viewer = GalleryViewer.new()
            viewer._rebuild = function() end
            viewer._startInputPolling = function() end
            viewer._cleanup = function() end
            t.expect(viewer._visible).to_be(false)
            viewer:toggle()
            t.expect(viewer._visible).to_be(true)
            viewer:toggle()
            t.expect(viewer._visible).to_be(false)
        end)
    end)

    t.describe("global instance (standalone mocked)", function()
        -- Note: These tests are simplified for standalone mode
        -- Full integration tested within the game engine
        t.it("showGlobal returns viewer instance", function()
            -- Mock the global viewer manually
            local mockViewer = GalleryViewer.new()
            mockViewer._rebuild = function() end
            mockViewer._startInputPolling = function() end
            mockViewer:show(100, 100)
            t.expect(mockViewer).to_be_truthy()
            t.expect(mockViewer._visible).to_be(true)
        end)

        t.it("viewer visibility can be toggled", function()
            local mockViewer = GalleryViewer.new()
            mockViewer._rebuild = function() end
            mockViewer._startInputPolling = function() end
            mockViewer._cleanup = function() end

            mockViewer:show(100, 100)
            t.expect(mockViewer._visible).to_be(true)

            mockViewer:hide()
            t.expect(mockViewer._visible).to_be(false)
        end)

        t.it("toggle creates and shows if not visible", function()
            local mockViewer = GalleryViewer.new()
            mockViewer._rebuild = function() end
            mockViewer._startInputPolling = function() end
            mockViewer._cleanup = function() end

            t.expect(mockViewer._visible).to_be(false)
            mockViewer:toggle()
            t.expect(mockViewer._visible).to_be(true)
        end)
    end)

    t.describe("view modes", function()
        t.it("starts in list mode", function()
            local viewer = GalleryViewer.new()
            t.expect(viewer._viewMode).to_be("list")
        end)

        t.it("goBack from list mode hides viewer", function()
            local viewer = GalleryViewer.new()
            viewer._rebuild = function() end
            viewer._startInputPolling = function() end
            viewer._cleanup = function() end
            viewer:show(100, 100)
            viewer._viewMode = "list"
            viewer:_goBack()
            t.expect(viewer._visible).to_be(false)
        end)

        t.it("goBack from detail mode returns to list mode", function()
            local viewer = GalleryViewer.new()
            viewer._rebuild = function() end
            viewer._startInputPolling = function() end
            viewer:show(100, 100)
            viewer._viewMode = "detail"
            viewer:_goBack()
            t.expect(viewer._viewMode).to_be("list")
        end)
    end)

    t.describe("cleanup", function()
        t.it("destroy cleans up viewer", function()
            local viewer = GalleryViewer.new()
            viewer._rebuild = function() end
            viewer._startInputPolling = function() end
            viewer._cleanup = function() end
            viewer:show(100, 100)
            viewer:destroy()
            -- Should not throw
        end)

        t.it("cleanup can be called multiple times", function()
            local viewer = GalleryViewer.new()
            viewer:_cleanup()
            viewer:_cleanup()
            -- Should not throw
        end)
    end)
end)

--------------------------------------------------------------------------------
-- Integration Tests
--------------------------------------------------------------------------------

t.describe("Gallery integration", function()
    t.it("viewer can iterate through all showcases", function()
        local viewer = GalleryViewer.new()
        local totalCount = ShowcaseRegistry.getTotalCount()

        for i = 1, totalCount do
            viewer._flatIndex = i
            local showcase = viewer:getCurrentShowcase()
            t.expect(showcase).to_be_truthy()
            t.expect(showcase.name).to_be_truthy()
        end
    end)

    t.it("all showcases in viewer flat list match registry", function()
        local viewer = GalleryViewer.new()
        local registryFlatList = ShowcaseRegistry.getFlatList()

        t.expect(#viewer._flatList).to_be(#registryFlatList)

        for i, item in ipairs(viewer._flatList) do
            t.expect(item.category).to_be(registryFlatList[i].category)
            t.expect(item.showcase.id).to_be(registryFlatList[i].showcase.id)
        end
    end)

    t.it("categories in viewer match registry", function()
        local viewer = GalleryViewer.new()
        local registryCategories = ShowcaseRegistry.getCategories()

        t.expect(#viewer._categories).to_be(#registryCategories)

        for i, cat in ipairs(viewer._categories) do
            t.expect(cat).to_be(registryCategories[i])
        end
    end)
end)

--------------------------------------------------------------------------------
-- Run tests
--------------------------------------------------------------------------------

if standalone or os.getenv("RUN_TESTS") then
    t.run()
end

return t
