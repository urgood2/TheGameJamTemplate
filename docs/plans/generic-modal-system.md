# Generic Modal System Design

## Goal
Create a **dead-simple** API for showing modals anywhere in the codebase.

## API Design

```lua
local modal = require("core.modal")

-- Simple alert (one button)
modal.alert("Content validation failed!", {
    title = "Error",
    color = "red",
    onClose = function() print("closed") end
})

-- Confirm dialog (two buttons)
modal.confirm("Are you sure you want to delete this?", {
    title = "Confirm Delete",
    onConfirm = function() deleteItem() end,
    onCancel = function() print("cancelled") end,
    confirmText = "Delete",  -- default: "OK"
    cancelText = "Cancel",   -- default: "Cancel"
})

-- Custom content modal
modal.show({
    title = "Validation Errors",
    width = 600,
    height = 400,
    color = "dark_red",
    content = function(dsl)
        return dsl.vbox {
            children = {
                dsl.text("3 errors found:", { color = "red" }),
                dsl.text("- Card FIREBALL: missing damage", { color = "white" }),
                dsl.text("- Joker LUCKY: missing calculate", { color = "white" }),
            }
        }
    end,
    buttons = {
        { text = "Continue Anyway", color = "orange", action = function() end },
        { text = "Exit", color = "red", action = function() os.exit(1) end },
    }
})

-- Close current modal
modal.close()

-- Check if modal is open
if modal.isOpen() then ... end
```

## Features

1. **Simple presets** - `alert()` and `confirm()` cover 80% of use cases
2. **Custom content** - `show()` with content function for complex modals
3. **Consistent styling** - All modals use same animation, backdrop, ESC handling
4. **Single modal at a time** - Opening a new modal closes the previous
5. **Buttons array** - Flexible button configuration

## Implementation Approach

Extract common patterns from PatchNotesModal:
- Backdrop with click-to-dismiss
- Slide-in animation from bottom
- ESC key to close
- Z-order management
- Cleanup on close

## Usage Examples

### Validation errors at startup
```lua
local modal = require("core.modal")
local ContentValidator = require("tools.content_validator")

local result = ContentValidator.validate_all()
if #result.errors > 0 then
    local errorLines = {}
    for _, err in ipairs(result.errors) do
        table.insert(errorLines, string.format("[%s] %s: %s", err.type, err.id, err.message))
    end

    modal.show({
        title = "Content Validation Failed",
        color = "dark_red",
        content = function(dsl)
            local nodes = {}
            for _, line in ipairs(errorLines) do
                table.insert(nodes, dsl.text(line, { fontSize = 14, color = "red" }))
            end
            return dsl.vbox { children = nodes }
        end,
        buttons = {
            { text = "Continue Anyway", color = "orange" },
            { text = "Exit", color = "red", action = function() os.exit(1) end },
        }
    })
end
```

### Confirm before destructive action
```lua
modal.confirm("Delete all saved games?", {
    title = "Warning",
    onConfirm = function()
        SaveManager.deleteAll()
        modal.alert("All saves deleted.")
    end
})
```

### Settings/info modal
```lua
modal.show({
    title = "Game Info",
    content = function(dsl)
        return dsl.vbox {
            children = {
                dsl.text("Version: 1.0.0", { color = "white" }),
                dsl.text("Build: 2026-01-08", { color = "gray" }),
            }
        }
    end
})
```

## Test Cases

1. `modal.alert("test")` - shows modal with OK button
2. `modal.alert("test", { title = "Title" })` - shows with custom title
3. `modal.confirm("sure?", { onConfirm = fn })` - confirm calls fn, cancel does not
4. `modal.show({ content = ... })` - shows custom content
5. `modal.close()` - closes any open modal
6. ESC key closes modal
7. Clicking backdrop closes modal (for alert/info, not confirm)
8. Opening new modal closes previous
9. `modal.isOpen()` returns correct state
