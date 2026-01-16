--[[
================================================================================
TEST: dsl.strict.* Layout Components
================================================================================
Verifies that layout UI components (vbox, hbox, root) validate their props
correctly through the strict DSL API, including nested layout compositions.

Tests cover:
- dsl.strict.vbox (children, spacing, align)
- dsl.strict.hbox (children, spacing, align)
- dsl.strict.root (config, children)
- Nested layouts (vbox inside hbox, hbox inside vbox)
- Children validation (required array type)

Run standalone: lua assets/scripts/tests/test_dsl_strict_layouts.lua
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
_G.AlignmentFlag = _G.AlignmentFlag or {
    HORIZONTAL_CENTER = 1,
    VERTICAL_CENTER = 2,
    LEFT = 4,
    RIGHT = 8,
    TOP = 16,
    BOTTOM = 32
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
-- dsl.strict.vbox Tests
--------------------------------------------------------------------------------

t.describe("dsl.strict.vbox", function()
    t.describe("valid props", function()
        t.it("accepts empty children array", function()
            local result = dsl.strict.vbox({ children = {} })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts children with single element", function()
            local result = dsl.strict.vbox({
                children = { dsl.strict.text("Hello") }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts children with multiple elements", function()
            local result = dsl.strict.vbox({
                children = {
                    dsl.strict.text("Line 1"),
                    dsl.strict.text("Line 2"),
                    dsl.strict.text("Line 3")
                }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts spacing as number", function()
            local result = dsl.strict.vbox({
                children = {},
                config = { spacing = 10 }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts align as number (bitmask)", function()
            local align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.TOP)
            local result = dsl.strict.vbox({
                children = {},
                config = { align = align }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts padding as number", function()
            local result = dsl.strict.vbox({
                children = {},
                config = { padding = 8 }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts color as string", function()
            local result = dsl.strict.vbox({
                children = {},
                config = { color = "gray" }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts id as string", function()
            local result = dsl.strict.vbox({
                children = {},
                config = { id = "my_vbox" }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts all valid props together", function()
            local result = dsl.strict.vbox({
                children = { dsl.strict.text("Content") },
                config = {
                    spacing = 6,
                    padding = 10,
                    align = AlignmentFlag.HORIZONTAL_CENTER,
                    color = "darkgray",
                    id = "main_vbox"
                }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts config at top level (not nested in config)", function()
            local result = dsl.strict.vbox({
                children = {},
                spacing = 5,
                padding = 10,
                color = "blue"
            })
            t.expect(result).to_be_truthy()
        end)
    end)

    t.describe("invalid props", function()
        t.it("rejects spacing as string", function()
            t.expect(function()
                dsl.strict.vbox({ children = {}, spacing = "10px" })
            end).to_throw()
        end)

        t.it("rejects padding as string", function()
            t.expect(function()
                dsl.strict.vbox({ children = {}, padding = "large" })
            end).to_throw()
        end)

        t.it("rejects align as string", function()
            t.expect(function()
                dsl.strict.vbox({ children = {}, align = "center" })
            end).to_throw()
        end)

        t.it("rejects id as number", function()
            t.expect(function()
                dsl.strict.vbox({ children = {}, id = 123 })
            end).to_throw()
        end)
    end)

    t.describe("error messages", function()
        t.it("includes component name in error", function()
            local success, err = pcall(function()
                dsl.strict.vbox({ children = {}, spacing = "bad" })
            end)
            t.expect(success).to_be(false)
            t.expect(tostring(err)).to_contain("dsl.strict.vbox")
        end)

        t.it("includes property name in error", function()
            local success, err = pcall(function()
                dsl.strict.vbox({ children = {}, padding = {} })
            end)
            t.expect(success).to_be(false)
            t.expect(tostring(err)).to_contain("padding")
        end)
    end)
end)

--------------------------------------------------------------------------------
-- dsl.strict.hbox Tests
--------------------------------------------------------------------------------

t.describe("dsl.strict.hbox", function()
    t.describe("valid props", function()
        t.it("accepts empty children array", function()
            local result = dsl.strict.hbox({ children = {} })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts children with single element", function()
            local result = dsl.strict.hbox({
                children = { dsl.strict.text("Hello") }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts children with multiple elements", function()
            local result = dsl.strict.hbox({
                children = {
                    dsl.strict.text("Left"),
                    dsl.strict.spacer(20),
                    dsl.strict.text("Right")
                }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts spacing as number", function()
            local result = dsl.strict.hbox({
                children = {},
                config = { spacing = 15 }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts align as number (bitmask)", function()
            local align = bit.bor(AlignmentFlag.LEFT, AlignmentFlag.VERTICAL_CENTER)
            local result = dsl.strict.hbox({
                children = {},
                config = { align = align }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts padding as number", function()
            local result = dsl.strict.hbox({
                children = {},
                config = { padding = 12 }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts color as string", function()
            local result = dsl.strict.hbox({
                children = {},
                config = { color = "navy" }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts id as string", function()
            local result = dsl.strict.hbox({
                children = {},
                config = { id = "toolbar_hbox" }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts all valid props together", function()
            local result = dsl.strict.hbox({
                children = {
                    dsl.strict.text("Item 1"),
                    dsl.strict.text("Item 2")
                },
                config = {
                    spacing = 8,
                    padding = 4,
                    align = AlignmentFlag.VERTICAL_CENTER,
                    color = "transparent",
                    id = "action_bar"
                }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts config at top level (not nested in config)", function()
            local result = dsl.strict.hbox({
                children = {},
                spacing = 10,
                padding = 5,
                color = "red"
            })
            t.expect(result).to_be_truthy()
        end)
    end)

    t.describe("invalid props", function()
        t.it("rejects spacing as string", function()
            t.expect(function()
                dsl.strict.hbox({ children = {}, spacing = "wide" })
            end).to_throw()
        end)

        t.it("rejects padding as string", function()
            t.expect(function()
                dsl.strict.hbox({ children = {}, padding = "8px" })
            end).to_throw()
        end)

        t.it("rejects align as string", function()
            t.expect(function()
                dsl.strict.hbox({ children = {}, align = "left" })
            end).to_throw()
        end)

        t.it("rejects id as boolean", function()
            t.expect(function()
                dsl.strict.hbox({ children = {}, id = true })
            end).to_throw()
        end)
    end)

    t.describe("error messages", function()
        t.it("includes component name in error", function()
            local success, err = pcall(function()
                dsl.strict.hbox({ children = {}, spacing = false })
            end)
            t.expect(success).to_be(false)
            t.expect(tostring(err)).to_contain("dsl.strict.hbox")
        end)

        t.it("includes property name in error", function()
            local success, err = pcall(function()
                dsl.strict.hbox({ children = {}, align = "middle" })
            end)
            t.expect(success).to_be(false)
            t.expect(tostring(err)).to_contain("align")
        end)
    end)
end)

--------------------------------------------------------------------------------
-- dsl.strict.root Tests
--------------------------------------------------------------------------------

t.describe("dsl.strict.root", function()
    t.describe("valid props", function()
        t.it("accepts empty children array", function()
            local result = dsl.strict.root({ children = {} })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts children with elements", function()
            local result = dsl.strict.root({
                children = {
                    dsl.strict.vbox({
                        children = { dsl.strict.text("Hello") }
                    })
                }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts config table", function()
            local result = dsl.strict.root({
                config = { padding = 10, color = "blackberry" },
                children = {}
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts config with padding", function()
            local result = dsl.strict.root({
                config = { padding = 16 },
                children = {}
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts config with color", function()
            local result = dsl.strict.root({
                config = { color = "darkgray" },
                children = {}
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts config with align", function()
            local result = dsl.strict.root({
                config = { align = AlignmentFlag.HORIZONTAL_CENTER },
                children = {}
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts id as string", function()
            local result = dsl.strict.root({
                children = {},
                config = { id = "main_root" }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts all valid props together", function()
            local result = dsl.strict.root({
                config = {
                    padding = 20,
                    color = "navy",
                    align = AlignmentFlag.HORIZONTAL_CENTER,
                    id = "app_root"
                },
                children = {
                    dsl.strict.vbox({
                        children = {
                            dsl.strict.text("Title", { fontSize = 24 }),
                            dsl.strict.text("Subtitle", { fontSize = 16 })
                        }
                    })
                }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts config at top level (not nested in config)", function()
            local result = dsl.strict.root({
                children = {},
                padding = 10,
                color = "blue"
            })
            t.expect(result).to_be_truthy()
        end)
    end)

    t.describe("invalid props", function()
        t.it("rejects padding as string", function()
            t.expect(function()
                dsl.strict.root({ children = {}, padding = "20px" })
            end).to_throw()
        end)

        t.it("rejects align as string", function()
            t.expect(function()
                dsl.strict.root({ children = {}, align = "center" })
            end).to_throw()
        end)

        t.it("rejects id as number", function()
            t.expect(function()
                dsl.strict.root({ children = {}, id = 42 })
            end).to_throw()
        end)
    end)

    t.describe("error messages", function()
        t.it("includes component name in error", function()
            local success, err = pcall(function()
                dsl.strict.root({ children = {}, padding = "bad" })
            end)
            t.expect(success).to_be(false)
            t.expect(tostring(err)).to_contain("dsl.strict.root")
        end)

        t.it("includes property name in error", function()
            local success, err = pcall(function()
                dsl.strict.root({ children = {}, align = {} })
            end)
            t.expect(success).to_be(false)
            t.expect(tostring(err)).to_contain("align")
        end)
    end)
end)

--------------------------------------------------------------------------------
-- Nested Layouts Tests
--------------------------------------------------------------------------------

t.describe("nested layouts", function()
    t.describe("vbox inside hbox", function()
        t.it("accepts vbox as child of hbox", function()
            local result = dsl.strict.hbox({
                children = {
                    dsl.strict.vbox({
                        children = {
                            dsl.strict.text("Line 1"),
                            dsl.strict.text("Line 2")
                        }
                    }),
                    dsl.strict.vbox({
                        children = {
                            dsl.strict.text("Line A"),
                            dsl.strict.text("Line B")
                        }
                    })
                }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts styled vbox inside styled hbox", function()
            local result = dsl.strict.hbox({
                children = {
                    dsl.strict.vbox({
                        children = { dsl.strict.text("Content") },
                        config = { spacing = 4, padding = 8, color = "gray" }
                    })
                },
                config = { spacing = 10, padding = 12, color = "navy" }
            })
            t.expect(result).to_be_truthy()
        end)
    end)

    t.describe("hbox inside vbox", function()
        t.it("accepts hbox as child of vbox", function()
            local result = dsl.strict.vbox({
                children = {
                    dsl.strict.hbox({
                        children = {
                            dsl.strict.text("Left"),
                            dsl.strict.text("Right")
                        }
                    }),
                    dsl.strict.hbox({
                        children = {
                            dsl.strict.text("A"),
                            dsl.strict.text("B"),
                            dsl.strict.text("C")
                        }
                    })
                }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts styled hbox inside styled vbox", function()
            local result = dsl.strict.vbox({
                children = {
                    dsl.strict.hbox({
                        children = { dsl.strict.text("Item") },
                        config = { spacing = 6, align = AlignmentFlag.LEFT }
                    })
                },
                config = { padding = 10, color = "darkgray" }
            })
            t.expect(result).to_be_truthy()
        end)
    end)

    t.describe("deeply nested layouts", function()
        t.it("accepts three levels of nesting", function()
            local result = dsl.strict.root({
                children = {
                    dsl.strict.vbox({
                        children = {
                            dsl.strict.hbox({
                                children = {
                                    dsl.strict.text("Deep content")
                                }
                            })
                        }
                    })
                }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts complex nested structure", function()
            local result = dsl.strict.root({
                config = { padding = 20 },
                children = {
                    dsl.strict.vbox({
                        config = { spacing = 10 },
                        children = {
                            dsl.strict.text("Header", { fontSize = 24 }),
                            dsl.strict.hbox({
                                config = { spacing = 8 },
                                children = {
                                    dsl.strict.vbox({
                                        children = {
                                            dsl.strict.text("Sidebar Item 1"),
                                            dsl.strict.text("Sidebar Item 2")
                                        }
                                    }),
                                    dsl.strict.vbox({
                                        children = {
                                            dsl.strict.text("Main Content"),
                                            dsl.strict.hbox({
                                                children = {
                                                    dsl.strict.text("Button 1"),
                                                    dsl.strict.text("Button 2")
                                                }
                                            })
                                        }
                                    })
                                }
                            })
                        }
                    })
                }
            })
            t.expect(result).to_be_truthy()
        end)
    end)

    t.describe("nested validation", function()
        t.it("validates props at each nesting level", function()
            -- Outer level valid, inner level invalid
            t.expect(function()
                dsl.strict.vbox({
                    children = {
                        dsl.strict.hbox({
                            children = {},
                            spacing = "invalid"  -- This should fail
                        })
                    }
                })
            end).to_throw()
        end)

        t.it("error messages identify correct component", function()
            local success, err = pcall(function()
                dsl.strict.vbox({
                    children = {
                        dsl.strict.hbox({
                            children = {},
                            padding = "bad_value"
                        })
                    }
                })
            end)
            t.expect(success).to_be(false)
            t.expect(tostring(err)).to_contain("hbox")
        end)
    end)
end)

--------------------------------------------------------------------------------
-- Children Validation Tests
--------------------------------------------------------------------------------

t.describe("children validation", function()
    t.describe("children type validation", function()
        t.it("rejects children as string", function()
            t.expect(function()
                dsl.strict.vbox({ children = "not an array" })
            end).to_throw()
        end)

        t.it("rejects children as number", function()
            t.expect(function()
                dsl.strict.hbox({ children = 42 })
            end).to_throw()
        end)

        t.it("rejects children as function", function()
            t.expect(function()
                dsl.strict.root({ children = function() return {} end })
            end).to_throw()
        end)

        t.it("rejects children as boolean", function()
            t.expect(function()
                dsl.strict.vbox({ children = true })
            end).to_throw()
        end)
    end)

    t.describe("children array contents", function()
        t.it("accepts array with mixed valid component types", function()
            local result = dsl.strict.vbox({
                children = {
                    dsl.strict.text("Text element"),
                    dsl.strict.spacer(10),
                    dsl.strict.hbox({ children = {} }),
                    dsl.strict.divider("horizontal")
                }
            })
            t.expect(result).to_be_truthy()
        end)

        t.it("accepts array with nil values (filtered out)", function()
            -- Some DSL patterns use conditional rendering that returns nil
            local result = dsl.strict.vbox({
                children = {
                    dsl.strict.text("Always shown"),
                    nil,  -- Conditional that evaluated to false
                    dsl.strict.text("Also shown")
                }
            })
            t.expect(result).to_be_truthy()
        end)
    end)

    t.describe("error messages for children", function()
        t.it("includes 'children' in error for wrong type", function()
            local success, err = pcall(function()
                dsl.strict.vbox({ children = "wrong" })
            end)
            t.expect(success).to_be(false)
            t.expect(tostring(err)).to_contain("children")
        end)

        t.it("includes expected type in error", function()
            local success, err = pcall(function()
                dsl.strict.hbox({ children = 123 })
            end)
            t.expect(success).to_be(false)
            t.expect(tostring(err)).to_contain("table")
        end)
    end)
end)

--------------------------------------------------------------------------------
-- Cross-cutting Tests
--------------------------------------------------------------------------------

t.describe("layout components general behavior", function()
    t.it("regular dsl.* layout functions do not validate (no breaking changes)", function()
        -- These should NOT throw even with wrong types
        local result1 = dsl.vbox({ children = "not_array", spacing = "bad" })
        local result2 = dsl.hbox({ children = 123, padding = {} })
        local result3 = dsl.root({ children = nil, color = 42 })

        t.expect(result1).to_be_truthy()
        t.expect(result2).to_be_truthy()
        t.expect(result3).to_be_truthy()
    end)

    t.it("all strict layout functions return truthy values on success", function()
        local vbox = dsl.strict.vbox({ children = {} })
        local hbox = dsl.strict.hbox({ children = {} })
        local root = dsl.strict.root({ children = {} })

        t.expect(vbox).to_be_truthy()
        t.expect(hbox).to_be_truthy()
        t.expect(root).to_be_truthy()
    end)

    t.it("layout components return proper type field", function()
        local vbox = dsl.strict.vbox({ children = {} })
        local hbox = dsl.strict.hbox({ children = {} })
        local root = dsl.strict.root({ children = {} })

        t.expect(vbox.type).to_be("VERTICAL_CONTAINER")
        t.expect(hbox.type).to_be("HORIZONTAL_CONTAINER")
        t.expect(root.type).to_be("ROOT")
    end)
end)

--------------------------------------------------------------------------------
-- Run tests
--------------------------------------------------------------------------------

if standalone or os.getenv("RUN_TESTS") then
    t.run()
end

return t
