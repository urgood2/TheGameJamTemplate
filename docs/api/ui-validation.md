# UI Validation API

Rule-based UI validation to catch layout bugs before they become visual issues.

## Basic Usage

```lua
local UIValidator = require("core.ui_validator")
local dsl = require("ui.ui_syntax_sugar")

-- 1. Create UI
local myPanel = dsl.root {
    config = { padding = 10, minWidth = 200, minHeight = 150 },
    children = { dsl.text("Hello") }
}
local entity = dsl.spawn({ x = 100, y = 100 }, myPanel)

-- 2. Validate after spawn
local violations = UIValidator.validate(entity)
local errors = UIValidator.getErrors(violations)

if #errors > 0 then
    print("[UI ERROR] Found " .. #errors .. " validation errors:")
    for _, e in ipairs(errors) do
        print("  " .. e.type .. ": " .. e.message)
    end
end
```

## Validation Options

```lua
-- Skip hidden elements (for tab-based UIs)
local violations = UIValidator.validate(entity, nil, { skipHidden = true })

-- Validate specific rules only
local violations = UIValidator.validate(entity, { "containment", "window_bounds" })

-- Cross-hierarchy overlap check
local globalViolations = UIValidator.checkGlobalOverlap({ panelEntity, gridEntity })

-- Z-order assertions
local pairs = { { front = cardEntity, behind = gridEntity } }
local zViolations = UIValidator.checkZOrderOcclusion(pairs)
```

## Violation Types

| Violation | Severity | Cause | Fix |
|-----------|----------|-------|-----|
| `containment` | error | Child escapes parent bounds | Increase parent `minWidth`/`minHeight`, add padding, or set `allowEscape = true` |
| `window_bounds` | error | UI outside screen | Clamp spawn position |
| `sibling_overlap` | warning | Same-parent siblings overlap | Increase `spacing` or set `allowOverlap = true` |
| `z_order_hierarchy` | warning | Child z-order ≤ parent | Use `layer_order_system.assignZIndexToEntity(child, parentZ + 10)` |
| `global_overlap` | warning | Cross-hierarchy overlap | Adjust layout or increase z-order |
| `z_order_occlusion` | error | Front entity has lower z-order | Increase z-order of "front" entity |
| `layer_consistency` | error | Parent/child on different layers | Render all to same layer |
| `space_consistency` | error | Mixed Screen/World space | Use consistent DrawCommandSpace |
| `text_zero_offset` | warning | Text has no padding | Add padding to parent |

## Opt-Out Flags

```lua
-- Child intentionally escapes parent (tooltips, dropdowns)
dsl.box {
    config = { allowEscape = true },
    children = { ... }
}

-- Siblings intentionally overlap (stacked cards)
dsl.box {
    config = { allowOverlap = true },
    children = { ... }
}
```

## UITestUtils

```lua
local UITestUtils = require("tests.ui_test_utils")

-- Spawn and wait for layout
local entity = UITestUtils.spawnAndWait(myUIDef, { x = 100, y = 100 })

-- Assert no errors (throws on failure)
UITestUtils.assertNoErrors(entity)

-- Cleanup
UITestUtils.cleanup(entity)
```

## Running UI Tests

```bash
# Run test and auto-exit
AUTO_START_MAIN_GAME=1 RUN_REAL_INVENTORY_TEST=1 AUTO_EXIT_AFTER_TEST=1 ./build/raylib-cpp-cmake-template

# With output capture
(AUTO_START_MAIN_GAME=1 RUN_REAL_INVENTORY_TEST=1 AUTO_EXIT_AFTER_TEST=1 ./build/raylib-cpp-cmake-template 2>&1 & sleep 15; kill $!) | grep -E "(VALIDATION|PASS|FAIL)"
```

| Variable | Purpose |
|----------|---------|
| `AUTO_START_MAIN_GAME=1` | Skip main menu |
| `RUN_REAL_INVENTORY_TEST=1` | Run inventory test |
| `AUTO_EXIT_AFTER_TEST=1` | Exit after test |
