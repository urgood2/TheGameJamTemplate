# Getting Started with dsl.strict

This guide introduces `dsl.strict`, the validated variant of the UI DSL that catches errors at definition time rather than at runtime.

## Table of Contents
1. [What is dsl.strict?](#what-is-dslstrict)
2. [Why Use Strict Mode?](#why-use-strict-mode)
3. [Quick Start](#quick-start)
4. [Migration Guide](#migration-guide)
5. [Error Messages](#error-messages)
6. [Best Practices](#best-practices)

---

## What is dsl.strict?

`dsl.strict` is a validated wrapper around the standard UI DSL functions. It validates all props against schemas defined in `core/schema.lua` before passing them to the underlying DSL functions.

```lua
local dsl = require("ui.ui_syntax_sugar")

-- Standard DSL (no validation)
local ui = dsl.text("Hello", { fontsize = 16 })  -- Typo goes unnoticed!

-- Strict DSL (with validation)
local ui = dsl.strict.text("Hello", { fontsize = 16 })
-- ERROR: unknown field 'fontsize' - did you mean 'fontSize'?
```

### Available Strict Functions

All standard DSL functions have strict equivalents:

| Category | Functions |
|----------|-----------|
| **Containers** | `root`, `vbox`, `hbox`, `section`, `grid` |
| **Primitives** | `text`, `richText`, `dynamicText`, `anim`, `spacer`, `divider`, `iconLabel` |
| **Interactive** | `button`, `spriteButton`, `progressBar` |
| **Panels** | `spritePanel`, `spriteBox`, `customPanel` |
| **Complex** | `tabs`, `inventoryGrid` |

---

## Why Use Strict Mode?

### 1. Catch Typos Immediately

The most common UI bugs come from typos in prop names. Strict mode catches these with helpful suggestions:

```lua
-- Common mistakes caught by strict mode:
dsl.strict.text("Hello", { fontsize = 16 })
-- ERROR: unknown field 'fontsize' - did you mean 'fontSize'?

dsl.strict.button("Click", { onclick = fn })
-- ERROR: unknown field 'onclick' - did you mean 'onClick'?

dsl.strict.vbox { childern = {...} }
-- ERROR: unknown field 'childern' - did you mean 'children'?
```

### 2. Type Safety

Strict mode validates that props have the correct types:

```lua
dsl.strict.text("Hello", { fontSize = "16" })
-- ERROR: field 'fontSize' expected number, got string

dsl.strict.button("Click", { onClick = "handleClick" })
-- ERROR: field 'onClick' expected function, got string
```

### 3. Enum Validation

For fields with restricted values, strict mode validates against allowed options:

```lua
dsl.strict.divider("diagonal")
-- ERROR: field 'direction' must be one of: horizontal, vertical (got 'diagonal')

dsl.strict.spritePanel({ sizing = "auto" })
-- ERROR: field 'sizing' must be one of: fit_content, fixed, stretch (got 'auto')
```

### 4. File Location in Errors

Errors include the exact file and line number where the problem occurred:

```
[dsl.strict.text] Validation failed at scripts/ui/my_panel.lua:42:
  ERROR: field 'fontSize' expected number, got string
```

---

## Quick Start

### Basic Usage

Simply replace `dsl.` with `dsl.strict.` in your UI code:

```lua
local dsl = require("ui.ui_syntax_sugar")

-- Before (unvalidated)
local myUI = dsl.root {
    config = { padding = 10, color = "darkgray" },
    children = {
        dsl.vbox {
            children = {
                dsl.text("Hello World", { fontSize = 24, color = "white" }),
                dsl.button("Click Me", { onClick = function() print("Clicked!") end }),
            }
        }
    }
}

-- After (validated)
local myUI = dsl.strict.root {
    config = { padding = 10, color = "darkgray" },
    children = {
        dsl.strict.vbox {
            children = {
                dsl.strict.text("Hello World", { fontSize = 24, color = "white" }),
                dsl.strict.button("Click Me", { onClick = function() print("Clicked!") end }),
            }
        }
    }
}
```

### Creating a Strict-Only Alias

For new files, you can alias the strict namespace to make code cleaner:

```lua
local dsl = require("ui.ui_syntax_sugar")
local strict = dsl.strict  -- Alias for cleaner code

local myUI = strict.root {
    children = {
        strict.vbox {
            config = { spacing = 6 },
            children = {
                strict.text("Title", { fontSize = 18, color = "gold" }),
                strict.divider("horizontal", { color = "gray" }),
                strict.text("Content", { fontSize = 14, color = "white" }),
            }
        }
    }
}
```

---

## Migration Guide

### Step 1: Add Strict to New Code

Start by using `dsl.strict` for all new UI code. This prevents new bugs from being introduced.

### Step 2: Gradually Migrate Existing Code

For existing files, migrate incrementally:

```lua
-- Original
local panel = dsl.vbox {
    children = {
        dsl.text("Label"),
        dsl.button("Click")
    }
}

-- Migrated (outer containers first)
local panel = dsl.strict.vbox {
    children = {
        dsl.text("Label"),        -- Still unvalidated (migrate later)
        dsl.button("Click")       -- Still unvalidated
    }
}

-- Fully migrated
local panel = dsl.strict.vbox {
    children = {
        dsl.strict.text("Label"),
        dsl.strict.button("Click")
    }
}
```

### Step 3: Fix Errors

When you encounter validation errors, fix them:

```lua
-- Error: unknown field 'fontsize'
dsl.strict.text("Label", { fontsize = 16 })

-- Fixed: correct capitalization
dsl.strict.text("Label", { fontSize = 16 })
```

---

## Error Messages

### Understanding Error Format

Strict validation errors follow this format:

```
[dsl.strict.<component>] Validation failed at <file>:<line>:
  ERROR: <error message>
  WARNING: <warning message>
```

### Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `missing required field 'X'` | Required prop not provided | Add the missing prop |
| `field 'X' expected Y, got Z` | Wrong type | Use correct type |
| `field 'X' must be one of: A, B, C` | Invalid enum value | Use an allowed value |
| `unknown field 'X'` | Unrecognized prop name | Check spelling/remove |
| `unknown field 'X' - did you mean 'Y'?` | Likely typo | Use suggested name |

### Warnings vs Errors

- **Errors** halt execution and must be fixed
- **Warnings** (unknown fields) are logged but don't halt execution

To treat warnings as errors (stricter mode), check the Schema module:

```lua
local Schema = require("core.schema")
-- Schema.ENABLED = true  -- Enable/disable validation globally
```

---

## Best Practices

### 1. Use Strict Mode in Development

Always use `dsl.strict` during development to catch errors early:

```lua
-- Development alias
local ui = dsl.strict

-- Your code uses strict validation
local panel = ui.vbox { ... }
```

### 2. Validate Data-Driven UI

When building UI from data (like config files or API responses), strict mode is especially valuable:

```lua
-- Data from external source
local buttonConfig = loadConfig("buttons.json")

-- Validate before use
for _, btn in ipairs(buttonConfig.buttons) do
    panels[#panels+1] = dsl.strict.button(btn.label, {
        onClick = handlers[btn.action],
        color = btn.color,
    })
end
```

### 3. Document Custom Props

If you need props not in the schema, document why and consider extending the schema:

```lua
-- If you need a custom prop, use the unvalidated version with a comment:
local panel = dsl.vbox {
    config = {
        myCustomProp = "value"  -- CUSTOM: Used by my_system.lua for X
    },
    children = { ... }
}
```

### 4. Run Tests with Strict Mode

Ensure your UI tests use strict mode to catch issues in CI:

```lua
-- test_my_ui.lua
local dsl = require("ui.ui_syntax_sugar")
local strict = dsl.strict

t.describe("My UI Component", function()
    t.it("creates valid panel", function()
        -- Using strict ensures any prop errors fail the test
        local panel = strict.spritePanel({
            sprite = "panel.png",
            borders = { 8, 8, 8, 8 },
            children = { strict.text("Content") }
        })
        t.expect(panel).to_be_truthy()
    end)
end)
```

---

## Related Documentation

- [Writing UI Tests](./writing-ui-tests.md) - How to test UI components
- [Using the Showcase Gallery](./using-showcase-gallery.md) - Browse working examples
- [Adding Components to Strict](./adding-components-to-strict.md) - Extend the validation system
- [UI DSL Reference](../api/ui-dsl-reference.md) - Full DSL API documentation

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
