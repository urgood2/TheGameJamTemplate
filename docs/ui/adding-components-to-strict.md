# Adding New Components to the Strict System

This guide explains how to extend `dsl.strict` with validation for new UI components.

## Table of Contents
1. [Overview](#overview)
2. [Step-by-Step Process](#step-by-step-process)
3. [Schema Field Types](#schema-field-types)
4. [Adding Strict Mappings](#adding-strict-mappings)
5. [Testing Your Changes](#testing-your-changes)
6. [Complete Example](#complete-example)

---

## Overview

The strict validation system has three parts:

1. **Schema Definitions** (`core/schema.lua`) - Define what props are valid
2. **Strict Mappings** (`ui/ui_syntax_sugar.lua`) - Connect schemas to DSL functions
3. **DSL Functions** - The actual component implementations

When adding a new component with strict validation:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Schema         │────▶│  Strict Mapping │────▶│  DSL Function   │
│  (Defines props)│     │  (Connects them)│     │  (Creates UI)   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

---

## Step-by-Step Process

### Step 1: Define the Schema

Open `assets/scripts/core/schema.lua` and add a schema for your component.

```lua
Schema.UI_MY_COMPONENT = {
    _name = "UI_MY_COMPONENT",
    _fields = {
        -- Required props
        label       = { type = "string",   required = true },

        -- Optional props with types
        size        = { type = "number",   required = false },
        color       = { type = "string",   required = false },
        enabled     = { type = "boolean",  required = false },
        onClick     = { type = "function", required = false },

        -- Props with enum constraints
        variant     = { type = "string",   required = false, enum = { "primary", "secondary", "danger" } },

        -- Standard props
        id          = { type = "string",   required = false },
        children    = { type = "table",    required = false },
        config      = { type = "table",    required = false },
    }
}
```

### Step 2: Add the DSL Function

Open `assets/scripts/ui/ui_syntax_sugar.lua` and add the component function:

```lua
---@class MyComponentOpts
---@field label string Required label text
---@field size? number Size in pixels (default: 24)
---@field color? string|Color Color name or object
---@field enabled? boolean Enable/disable (default: true)
---@field onClick? function Click callback
---@field variant? "primary"|"secondary"|"danger" Visual variant
---@field id? string Unique identifier

--- Create my custom component.
---
--- **Example:**
--- ```lua
--- dsl.myComponent("Click Me", {
---     variant = "primary",
---     onClick = function() print("Clicked!") end
--- })
--- ```
---@param label string The label text
---@param opts? MyComponentOpts Optional configuration
---@return table UIDefinition node
function dsl.myComponent(label, opts)
    opts = opts or {}

    return def{
        type = "HORIZONTAL_CONTAINER",
        config = {
            id = opts.id,
            color = color(opts.color or "gray"),
            -- ... other config
        },
        children = {
            dsl.text(label, { fontSize = opts.size or 24 })
        }
    }
end
```

### Step 3: Add the Strict Mapping

In the same file, find the `STRICT_MAPPINGS` table and add your mapping:

```lua
local STRICT_MAPPINGS = {
    -- ... existing mappings ...

    -- Add your component
    { name = "myComponent", fn = dsl.myComponent, schema = Schema.UI_MY_COMPONENT, positional = { "label" } },
}
```

The `positional` array defines which arguments are positional (not in the opts table):

| Positional | Function Signature | Example Call |
|------------|-------------------|--------------|
| `{}` | `fn(opts)` | `dsl.strict.tabs({ tabs = ... })` |
| `{ "label" }` | `fn(label, opts)` | `dsl.strict.button("Click", { color = "blue" })` |
| `{ "iconId", "label" }` | `fn(icon, label, opts)` | `dsl.strict.iconLabel("coin.png", "100 Gold", { fontSize = 14 })` |

### Step 4: Test Your Component

Create a test file to verify validation works:

```lua
local t = require("tests.test_runner")
local dsl = require("ui.ui_syntax_sugar")

t.describe("dsl.strict.myComponent", function()
    t.it("accepts valid props", function()
        local ok = pcall(function()
            dsl.strict.myComponent("Hello", {
                variant = "primary",
                size = 24
            })
        end)
        t.expect(ok).to_be(true)
    end)

    t.it("catches invalid variant", function()
        local ok, err = pcall(function()
            dsl.strict.myComponent("Hello", { variant = "invalid" })
        end)
        t.expect(ok).to_be(false)
        t.expect(err:find("must be one of")).to_be_truthy()
    end)

    t.it("catches typos with suggestions", function()
        local ok, err = pcall(function()
            dsl.strict.myComponent("Hello", { onclick = function() end })
        end)
        t.expect(ok).to_be(false)
        t.expect(err:find("did you mean 'onClick'")).to_be_truthy()
    end)
end)
```

---

## Schema Field Types

### Basic Types

| Type | Lua Type | Example |
|------|----------|---------|
| `"string"` | string | `"hello"`, `""` |
| `"number"` | number | `42`, `3.14`, `-1` |
| `"boolean"` | boolean | `true`, `false` |
| `"function"` | function | `function() end` |
| `"table"` | table | `{}`, `{ a = 1 }` |

### Field Specification

```lua
fieldName = {
    type = "string",       -- Required: expected Lua type
    required = true,       -- Optional: must be present (default: false)
    enum = { "a", "b" },   -- Optional: allowed string values
}
```

### Common Field Patterns

```lua
_fields = {
    -- Required string
    id = { type = "string", required = true },

    -- Optional number with no constraints
    size = { type = "number", required = false },

    -- String with enum constraint
    direction = {
        type = "string",
        required = false,
        enum = { "horizontal", "vertical" }
    },

    -- Callback function
    onClick = { type = "function", required = false },

    -- Nested table (not deeply validated)
    config = { type = "table", required = false },

    -- Children array
    children = { type = "table", required = false },

    -- Boolean flag
    disabled = { type = "boolean", required = false },
}
```

---

## Adding Strict Mappings

### Mapping Structure

```lua
{
    name = "functionName",      -- Name in dsl.strict namespace
    fn = dsl.functionName,      -- Reference to actual function
    schema = Schema.UI_SCHEMA,  -- Schema to validate against
    positional = { "arg1" },    -- Positional argument names
}
```

### Positional Arguments Explained

The `positional` array tells the strict wrapper how to convert positional arguments to a props table for validation.

**Example: `dsl.text(text, opts)`**

```lua
{ name = "text", fn = dsl.text, schema = Schema.UI_TEXT, positional = { "text" } }
```

When you call:
```lua
dsl.strict.text("Hello", { fontSize = 16 })
```

The wrapper converts this to:
```lua
{ text = "Hello", fontSize = 16 }
```

Then validates against `Schema.UI_TEXT`.

**Example: `dsl.iconLabel(iconId, label, opts)`**

```lua
{ name = "iconLabel", fn = dsl.iconLabel, schema = Schema.UI_ICON_LABEL, positional = { "iconId", "label" } }
```

When you call:
```lua
dsl.strict.iconLabel("coin.png", "100 Gold", { fontSize = 14 })
```

The wrapper converts this to:
```lua
{ iconId = "coin.png", label = "100 Gold", fontSize = 14 }
```

### Handling Complex Signatures

For functions with unusual signatures, you may need to adjust the schema or positional mapping:

```lua
-- Function: dsl.grid(rows, cols, generator)
{
    name = "grid",
    fn = dsl.grid,
    schema = Schema.UI_GRID,
    positional = { "rows", "cols", "gen" }
}

-- Schema includes all positional args
Schema.UI_GRID = {
    _name = "UI_GRID",
    _fields = {
        rows = { type = "number", required = false },
        cols = { type = "number", required = false },
        gen = { type = "function", required = false },
    }
}
```

---

## Testing Your Changes

### Unit Tests

Create `test_my_component.lua`:

```lua
local t = require("tests.test_runner")
local Schema = require("core.schema")
local dsl = require("ui.ui_syntax_sugar")

t.describe("Schema.UI_MY_COMPONENT", function()
    t.it("exists", function()
        t.expect(Schema.UI_MY_COMPONENT).to_be_truthy()
        t.expect(Schema.UI_MY_COMPONENT._fields).to_be_truthy()
    end)

    t.it("has required fields defined", function()
        local fields = Schema.UI_MY_COMPONENT._fields
        t.expect(fields.label).to_be_truthy()
        t.expect(fields.label.type).to_be("string")
    end)
end)

t.describe("dsl.myComponent", function()
    t.it("creates component", function()
        local result = dsl.myComponent("Test")
        t.expect(result).to_be_truthy()
    end)
end)

t.describe("dsl.strict.myComponent", function()
    t.it("accepts valid props", function()
        local ok = pcall(dsl.strict.myComponent, "Test", { size = 24 })
        t.expect(ok).to_be(true)
    end)

    t.it("rejects invalid type", function()
        local ok = pcall(dsl.strict.myComponent, "Test", { size = "large" })
        t.expect(ok).to_be(false)
    end)

    t.it("catches typos", function()
        local ok, err = pcall(dsl.strict.myComponent, "Test", { onClick = function() end, onclick = nil })
        -- Both should work - onclick would be caught if present
    end)
end)

t.run()
```

### Integration Tests

Test that the component works in a real UI tree:

```lua
t.describe("Integration", function()
    t.it("works in vbox", function()
        local ui = dsl.strict.vbox {
            children = {
                dsl.strict.myComponent("Item 1"),
                dsl.strict.myComponent("Item 2", { variant = "primary" }),
            }
        }
        t.expect(ui).to_be_truthy()
        t.expect(#ui.children).to_be(2)
    end)
end)
```

---

## Complete Example

Here's a complete example adding a new `badge` component:

### 1. Schema Definition (schema.lua)

```lua
Schema.UI_BADGE = {
    _name = "UI_BADGE",
    _fields = {
        -- Content
        text        = { type = "string",   required = false },
        count       = { type = "number",   required = false },

        -- Styling
        color       = { type = "string",   required = false },
        textColor   = { type = "string",   required = false },
        fontSize    = { type = "number",   required = false },
        shape       = { type = "string",   required = false, enum = { "circle", "pill", "square" } },

        -- Dimensions
        minWidth    = { type = "number",   required = false },
        minHeight   = { type = "number",   required = false },

        -- Identity
        id          = { type = "string",   required = false },
    }
}
```

### 2. DSL Function (ui_syntax_sugar.lua)

```lua
---@class BadgeOpts
---@field text? string Badge text content
---@field count? number Numeric count (renders as text)
---@field color? string|Color Background color (default: "red")
---@field textColor? string|Color Text color (default: "white")
---@field fontSize? number Font size in pixels (default: 12)
---@field shape? "circle"|"pill"|"square" Badge shape (default: "circle")
---@field minWidth? number Minimum width
---@field minHeight? number Minimum height
---@field id? string Unique identifier

--- Create a badge element for notifications, counts, or status indicators.
---
--- **Example:**
--- ```lua
--- -- Notification count
--- dsl.badge({ count = 5 })
---
--- -- Status badge
--- dsl.badge({ text = "NEW", color = "green", shape = "pill" })
--- ```
---@param opts BadgeOpts Configuration options
---@return table UIDefinition node
function dsl.badge(opts)
    opts = opts or {}

    local displayText = opts.text or (opts.count and tostring(opts.count)) or ""

    return def{
        type = "HORIZONTAL_CONTAINER",
        config = {
            id = opts.id,
            color = color(opts.color or "red"),
            minWidth = opts.minWidth or 20,
            minHeight = opts.minHeight or 20,
            padding = 4,
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
            _badgeShape = opts.shape or "circle",
        },
        children = {
            dsl.text(displayText, {
                fontSize = opts.fontSize or 12,
                color = opts.textColor or "white",
            })
        }
    }
end
```

### 3. Strict Mapping (ui_syntax_sugar.lua)

```lua
local STRICT_MAPPINGS = {
    -- ... existing mappings ...

    { name = "badge", fn = dsl.badge, schema = Schema.UI_BADGE, positional = {} },
}
```

### 4. Test File

```lua
-- test_badge.lua
local t = require("tests.test_runner")
local dsl = require("ui.ui_syntax_sugar")

t.describe("dsl.badge", function()
    t.it("creates with count", function()
        local result = dsl.badge({ count = 5 })
        t.expect(result).to_be_truthy()
    end)

    t.it("creates with text", function()
        local result = dsl.badge({ text = "NEW" })
        t.expect(result).to_be_truthy()
    end)
end)

t.describe("dsl.strict.badge", function()
    t.it("validates count type", function()
        local ok = pcall(dsl.strict.badge, { count = 5 })
        t.expect(ok).to_be(true)

        ok = pcall(dsl.strict.badge, { count = "five" })
        t.expect(ok).to_be(false)
    end)

    t.it("validates shape enum", function()
        local ok = pcall(dsl.strict.badge, { shape = "circle" })
        t.expect(ok).to_be(true)

        ok = pcall(dsl.strict.badge, { shape = "triangle" })
        t.expect(ok).to_be(false)
    end)
end)

t.run()
```

### 5. Add Showcase

```lua
-- In showcase_registry.lua
ShowcaseRegistry._showcases.patterns.badge_basic = {
    name = "Badge (Basic)",
    description = "Notification badge for counts and status",
    source = [[
dsl.badge({ count = 5 })
dsl.badge({ text = "NEW", color = "green", shape = "pill" })]],
    create = function()
        return dsl.hbox {
            config = { spacing = 8 },
            children = {
                dsl.badge({ count = 5 }),
                dsl.badge({ text = "NEW", color = "green", shape = "pill" }),
            }
        }
    end,
}
```

---

## Checklist

When adding a new strict component:

- [ ] Define schema in `core/schema.lua`
- [ ] Add DSL function with LuaDoc comments in `ui_syntax_sugar.lua`
- [ ] Add strict mapping to `STRICT_MAPPINGS` table
- [ ] Write unit tests for validation
- [ ] Add showcase to demonstrate usage
- [ ] Update this guide if adding new patterns

---

## Related Documentation

- [Getting Started with dsl.strict](./getting-started-with-strict.md) - Learn to use strict mode
- [Writing UI Tests](./writing-ui-tests.md) - Test your components
- [Using the Showcase Gallery](./using-showcase-gallery.md) - Add working examples
- [UI DSL Reference](../api/ui-dsl-reference.md) - Full API documentation
