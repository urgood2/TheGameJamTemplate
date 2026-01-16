# Writing UI Tests

This guide covers how to write comprehensive tests for UI components using the test framework and `dsl.strict` validation.

## Table of Contents
1. [Test Framework Overview](#test-framework-overview)
2. [Setting Up Test Files](#setting-up-test-files)
3. [Testing DSL Components](#testing-dsl-components)
4. [Testing Showcases](#testing-showcases)
5. [Mocking Engine Dependencies](#mocking-engine-dependencies)
6. [Running Tests](#running-tests)
7. [Best Practices](#best-practices)

---

## Test Framework Overview

UI tests use the lightweight test runner at `tests/test_runner.lua`. It provides BDD-style test organization with `describe`, `it`, and `expect`.

```lua
local t = require("tests.test_runner")

t.describe("My Component", function()
    t.it("does something", function()
        t.expect(1 + 1).to_be(2)
    end)
end)

t.run()  -- Execute all tests
```

### Available Assertions

| Assertion | Description |
|-----------|-------------|
| `.to_be(value)` | Strict equality check |
| `.to_be_truthy()` | Value is not nil/false |
| `.to_be_falsy()` | Value is nil/false |
| `.to_be_nil()` | Value is nil |
| `.to_contain(substring)` | String contains substring |
| `.to_match(pattern)` | String matches Lua pattern |

---

## Setting Up Test Files

### File Structure

Place test files in `assets/scripts/tests/`:

```
assets/scripts/tests/
├── test_runner.lua          # Framework
├── mocks/
│   └── engine_mock.lua      # Engine mocks
├── test_my_component.lua    # Your tests
├── test_showcase_gallery.lua
├── test_primitive_showcases.lua
└── ...
```

### Test File Template

```lua
--[[
================================================================================
TEST: My Component
================================================================================
Validates that [component name] meets acceptance criteria:
- [x] Criterion 1
- [x] Criterion 2

Run standalone: lua assets/scripts/tests/test_my_component.lua
================================================================================
]]

-- Setup package path for standalone execution
package.path = package.path .. ";./assets/scripts/?.lua"

-- Load mocks for standalone execution
local standalone = not _G.registry
if standalone then
    pcall(require, "tests.mocks.engine_mock")
end

-- Mock engine globals that aren't covered by engine_mock
_G.AlignmentFlag = _G.AlignmentFlag or {
    HORIZONTAL_CENTER = 1,
    VERTICAL_CENTER = 2,
}
_G.bit = _G.bit or {
    bor = function(a, b) return (a or 0) + (b or 0) end,
}

-- Load test runner
local t = require("tests.test_runner")

--------------------------------------------------------------------------------
-- Tests
--------------------------------------------------------------------------------

t.describe("My Component", function()
    t.it("exists", function()
        t.expect(true).to_be_truthy()
    end)
end)

-- Run tests if executed directly
if standalone then
    t.run()
end

return t
```

---

## Testing DSL Components

### Testing Component Creation

Test that DSL functions return valid definition tables:

```lua
local dsl = require("ui.ui_syntax_sugar")

t.describe("dsl.text", function()
    t.it("creates a text definition", function()
        local result = dsl.text("Hello World")
        t.expect(result).to_be_truthy()
        t.expect(result.type).to_be("TEXT")
    end)

    t.it("accepts fontSize option", function()
        local result = dsl.text("Hello", { fontSize = 24 })
        t.expect(result.config.fontSize).to_be(24)
    end)

    t.it("accepts color option", function()
        local result = dsl.text("Hello", { color = "gold" })
        t.expect(result.config.color).to_be_truthy()
    end)
end)
```

### Testing Strict Validation

Test that `dsl.strict` catches invalid props:

```lua
t.describe("dsl.strict.text", function()
    t.it("validates fontSize type", function()
        local ok, err = pcall(function()
            dsl.strict.text("Hello", { fontSize = "large" })  -- Should fail
        end)
        t.expect(ok).to_be(false)
        t.expect(err:find("expected number")).to_be_truthy()
    end)

    t.it("catches typos with suggestions", function()
        local ok, err = pcall(function()
            dsl.strict.text("Hello", { fontsize = 16 })  -- Wrong case
        end)
        t.expect(ok).to_be(false)
        t.expect(err:find("did you mean 'fontSize'")).to_be_truthy()
    end)

    t.it("accepts valid props without error", function()
        local ok = pcall(function()
            dsl.strict.text("Hello", {
                fontSize = 16,
                color = "white",
                shadow = true
            })
        end)
        t.expect(ok).to_be(true)
    end)
end)
```

### Testing Container Layouts

Test that containers properly organize children:

```lua
t.describe("dsl.vbox", function()
    t.it("creates vertical container", function()
        local result = dsl.vbox {
            children = {
                dsl.text("First"),
                dsl.text("Second"),
            }
        }
        t.expect(result.type).to_be("VERTICAL_CONTAINER")
        t.expect(#result.children).to_be(2)
    end)

    t.it("applies config options", function()
        local result = dsl.vbox {
            config = { spacing = 10, padding = 5 },
            children = {}
        }
        t.expect(result.config.spacing).to_be(10)
        t.expect(result.config.padding).to_be(5)
    end)
end)
```

---

## Testing Showcases

Showcases in `ui/showcase/showcase_registry.lua` should be tested to ensure they remain valid examples.

### Testing Showcase Structure

```lua
local ShowcaseRegistry = require("ui.showcase.showcase_registry")

t.describe("Showcase Registry", function()
    t.it("has primitives category", function()
        local categories = ShowcaseRegistry.getCategories()
        t.expect(categories).to_be_truthy()

        local hasPrimitives = false
        for _, cat in ipairs(categories) do
            if cat == "primitives" then hasPrimitives = true end
        end
        t.expect(hasPrimitives).to_be(true)
    end)
end)

t.describe("Primitive Showcases", function()
    local primitives = ShowcaseRegistry._showcases.primitives

    t.it("has text_basic showcase", function()
        t.expect(primitives.text_basic).to_be_truthy()
        t.expect(primitives.text_basic.name).to_be_truthy()
        t.expect(primitives.text_basic.description).to_be_truthy()
        t.expect(primitives.text_basic.source).to_be_truthy()
        t.expect(type(primitives.text_basic.create)).to_be("function")
    end)

    t.it("text_basic creates without error", function()
        local ok, result = pcall(primitives.text_basic.create)
        t.expect(ok).to_be(true)
        t.expect(result).to_be_truthy()
    end)
end)
```

### Testing Source Code Examples

Verify that source code in showcases contains expected patterns:

```lua
t.describe("Text Showcases Documentation", function()
    local primitives = ShowcaseRegistry._showcases.primitives

    t.it("text_sizes shows multiple font sizes", function()
        local source = primitives.text_sizes.source
        t.expect(source:find("fontSize = 12")).to_be_truthy()
        t.expect(source:find("fontSize = 16")).to_be_truthy()
        t.expect(source:find("fontSize = 24")).to_be_truthy()
    end)

    t.it("text_colors demonstrates named colors", function()
        local source = primitives.text_colors.source
        t.expect(source:find('color = "white"')).to_be_truthy()
        t.expect(source:find('color = "gold"')).to_be_truthy()
        t.expect(source:find('color = "red"')).to_be_truthy()
    end)
end)
```

### Testing Create Functions

Ensure showcase create functions produce valid output:

```lua
t.describe("Showcase Creation", function()
    local layouts = ShowcaseRegistry._showcases.layouts

    t.it("all layout showcases create without error", function()
        for id, showcase in pairs(layouts) do
            if type(showcase) == "table" and showcase.create then
                local ok, err = pcall(showcase.create)
                t.expect(ok).to_be(true)
            end
        end
    end)
end)
```

---

## Mocking Engine Dependencies

### Essential Mocks

UI tests often run standalone (outside the engine). Mock these globals:

```lua
-- Mock alignment flags
_G.AlignmentFlag = {
    HORIZONTAL_LEFT = 1,
    HORIZONTAL_CENTER = 2,
    HORIZONTAL_RIGHT = 4,
    VERTICAL_TOP = 8,
    VERTICAL_CENTER = 16,
    VERTICAL_BOTTOM = 32,
}

-- Mock bit operations
_G.bit = {
    bor = function(a, b) return (a or 0) + (b or 0) end,
    band = function(a, b) return math.min(a or 0, b or 0) end,
}

-- Mock Color constructor
_G.Color = {
    new = function(r, g, b, a)
        return { r = r, g = g, b = b, a = a }
    end
}

-- Mock util functions
_G.util = {
    getColor = function(colorName)
        return colorName  -- Pass through for testing
    end
}
```

### Mocking UI System

```lua
_G.ui = {
    definitions = {
        def = function(tbl) return tbl end,
        wrapEntityInsideObjectElement = function(e) return e end,
        getNewDynamicTextEntry = function(fn, size, effect)
            return { config = { fn = fn, fontSize = size, effect = effect } }
        end,
        getTextFromString = function(text, opts)
            return { type = "TEXT", config = opts, text = text }
        end,
    },
    box = {
        Initialize = function() return {} end,
        GetUIEByID = function() return nil end,
    },
}
```

### Mocking Animation System

```lua
_G.animation_system = {
    createAnimatedObjectWithTransform = function(id, generateNew, x, y, opts, shadow)
        return { _mockEntity = true, sprite = id }
    end,
    resizeAnimationObjectsInEntityToFit = function(entity, w, h)
        entity.width = w
        entity.height = h
    end,
    setSpeed = function() end,
    play = function() end,
    pause = function() end,
}
```

---

## Running Tests

### Standalone Execution

Run a test file directly with Lua:

```bash
# From project root
lua assets/scripts/tests/test_primitive_showcases.lua
```

### In-Engine Execution

Tests can also run inside the game engine:

```lua
-- In a debug script or console
local test = require("tests.test_primitive_showcases")
test.run()
```

### CI Integration

For continuous integration, create a test runner script:

```bash
#!/bin/bash
# run_ui_tests.sh

set -e  # Exit on first failure

echo "Running UI tests..."

lua assets/scripts/tests/test_showcase_gallery.lua
lua assets/scripts/tests/test_primitive_showcases.lua
lua assets/scripts/tests/test_layout_showcases.lua
lua assets/scripts/tests/test_pattern_showcases.lua

echo "All UI tests passed!"
```

---

## Best Practices

### 1. Test Both Valid and Invalid Cases

```lua
t.describe("dsl.strict.button", function()
    -- Test valid usage
    t.it("accepts valid props", function()
        local ok = pcall(function()
            dsl.strict.button("Click", { onClick = function() end })
        end)
        t.expect(ok).to_be(true)
    end)

    -- Test invalid usage
    t.it("rejects invalid onClick type", function()
        local ok = pcall(function()
            dsl.strict.button("Click", { onClick = "not a function" })
        end)
        t.expect(ok).to_be(false)
    end)
end)
```

### 2. Test Edge Cases

```lua
t.describe("dsl.spacer", function()
    t.it("handles zero size", function()
        local result = dsl.spacer(0)
        t.expect(result).to_be_truthy()
    end)

    t.it("handles single dimension", function()
        local result = dsl.spacer(10)  -- Height defaults to width
        t.expect(result).to_be_truthy()
    end)

    t.it("handles both dimensions", function()
        local result = dsl.spacer(10, 20)
        t.expect(result).to_be_truthy()
    end)
end)
```

### 3. Use Descriptive Test Names

```lua
-- Bad
t.it("works", function() ... end)

-- Good
t.it("creates button with gold color when color='gold'", function() ... end)
```

### 4. Group Related Tests

```lua
t.describe("Button Component", function()
    t.describe("styling", function()
        t.it("applies color", function() ... end)
        t.it("applies textColor", function() ... end)
    end)

    t.describe("interaction", function()
        t.it("calls onClick when clicked", function() ... end)
        t.it("respects disabled state", function() ... end)
    end)
end)
```

### 5. Test Schema Coverage

Ensure all props in a schema are tested:

```lua
local Schema = require("core.schema")

t.describe("UI_TEXT schema coverage", function()
    local fields = Schema.UI_TEXT._fields

    for fieldName, spec in pairs(fields) do
        t.it("validates " .. fieldName .. " prop", function()
            -- Test this specific field
            t.expect(spec.type).to_be_truthy()
        end)
    end
end)
```

---

## Related Documentation

- [Getting Started with dsl.strict](./getting-started-with-strict.md) - Learn about validation
- [Using the Showcase Gallery](./using-showcase-gallery.md) - Browse working examples
- [Adding Components to Strict](./adding-components-to-strict.md) - Extend the system
- [Testing Guide](../guides/TESTING_GUIDE.md) - General testing practices
