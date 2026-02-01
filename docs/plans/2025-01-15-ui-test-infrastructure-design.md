# UI Testing Infrastructure Design

## Problem

AI agents creating UI frequently produce bugs:
- **Layout overlap** - Text/elements escaping container bounds
- **Z-order errors** - Elements layered incorrectly (cards behind slots, tooltips hidden)
- **Layer/space inconsistency** - Manual renders using different layer or DrawCommandSpace than parent UI

## Solution

A comprehensive validation system with:
1. Rule-based validation engine
2. Runtime visual overlays for immediate feedback
3. Automated test suite for CI
4. Tracked render wrappers for manual draw commands

## Components

| Module | Purpose |
|--------|---------|
| `core/ui_validator.lua` | Validation engine + tracked render wrappers |
| `core/ui_debug_overlay.lua` | Visual overlays (outlines, labels, panel) |
| `tests/ui_test_utils.lua` | Test helpers (spawn, wait, assert) |
| `tests/test_ui_validation.lua` | Automated tests using inventory as test case |

## Validation Rules

| Rule | Severity | Description |
|------|----------|-------------|
| `containment` | error | Children fully inside parent bounds |
| `window_bounds` | error | All UI inside game window |
| `sibling_overlap` | warning | Same z-order siblings don't overlap |
| `z_order_hierarchy` | warning | Z-order respects parent/child/sibling order |
| `collision_alignment` | error | Collision bounds ⊆ visual bounds |
| `layer_consistency` | error | All elements render to same layer |
| `space_consistency` | error | All elements use same DrawCommandSpace |

## Opt-out Flags

Elements can declare intentional violations:

```lua
dsl.text("Tooltip text", {
    allowEscape = true,    -- Can escape parent bounds
    allowOverlap = true,   -- Can overlap siblings
})
```

## API

### Validation Engine

```lua
local UIValidator = require("core.ui_validator")

-- Enable/disable auto-validation
UIValidator.enable()
UIValidator.disable()

-- Manual validation (returns list of violations)
local violations = UIValidator.validate(uiEntity)

-- Check specific rule
local overlaps = UIValidator.checkOverlap(uiEntity)

-- Configure severity
UIValidator.setSeverity("sibling_overlap", "error")
```

### Tracked Render Wrappers

For entities rendered manually (not via UI hierarchy):

```lua
-- Instead of direct command_buffer calls
UIValidator.queueDrawEntities(
    parentUI,       -- UI entity for association
    layers.ui,      -- Render layer
    cardEntities,   -- Entities to render
    z,              -- Z-order
    layer.DrawCommandSpace.Screen  -- Draw space
)
```

This records render configuration for validation.

### Debug Overlay

```lua
local UIDebugOverlay = require("core.ui_debug_overlay")

UIDebugOverlay.enable()   -- Show overlays
UIDebugOverlay.disable()  -- Hide overlays
UIDebugOverlay.toggle()   -- Toggle (or press F3)

-- Customize colors
UIDebugOverlay.setColors({
    escapes_parent = "orange",
    escapes_window = "red",
    overlap = "yellow",
    z_order = "purple",
    collision_mismatch = "cyan",
})
```

### Test Utilities

```lua
local UITestUtils = require("tests.ui_test_utils")

-- Spawn UI and wait for layout
local entity = UITestUtils.spawnAndWait(uiDef, { x = 100, y = 100 })

-- Assert no violations
UITestUtils.assertNoErrors(entity)

-- Assert specific violation (for testing validator itself)
UITestUtils.assertHasViolation(entity, "escapes_parent", "text_1")

-- Get computed bounds
local bounds = UITestUtils.getAllBounds(entity)
```

## Visual Overlays

Three visualization layers (all toggleable):

### Colored Outlines

| Violation Type | Color |
|----------------|-------|
| Escapes parent | Orange |
| Escapes window | Red |
| Sibling overlap | Yellow |
| Z-order wrong | Purple |
| Collision mismatch | Cyan |

### Floating Labels

Small text above violating elements:
- `"ESCAPES PARENT"`
- `"OVERLAPS: button_2"`
- `"Z-ORDER: behind parent"`

### Debug Panel (F3)

```
┌─ UI Violations (3 errors, 2 warnings) ─────────┐
│ ❌ ERROR: text_14 escapes parent (vbox_3)      │
│ ❌ ERROR: button_5 outside window bounds       │
│ ❌ ERROR: slot_2 collision > visual bounds     │
│ ⚠️  WARN: icon_7 overlaps icon_8               │
│ ⚠️  WARN: card_1 z-order behind slot_1         │
└────────────────────────────────────────────────┘
```

Clicking an entry highlights that element.

## Auto-Validation

`dsl.spawn()` automatically validates after layout completes:

```lua
-- Auto-validates by default when UIValidator.isEnabled()
local entity = dsl.spawn(pos, definition)

-- Skip validation for specific spawn
local entity = dsl.spawn(pos, def, nil, nil, { skipValidation = true })
```

## Test Case: Planning Mode Inventory

The primary test target is `card_inventory_panel.lua` in planning mode. Tests verify:

1. **Containment** - Slots stay within panel bounds
2. **Cards in slots** - Cards have correct z-order relative to slots
3. **Dragged cards** - Dragged card z-order > all slots
4. **Layer consistency** - Cards render to same layer as inventory
5. **Space consistency** - Cards use same DrawCommandSpace as inventory
6. **Collision alignment** - Card collision bounds match visual bounds

Example test:

```lua
TestRunner.describe("Inventory UI Validation", function()

    TestRunner.it("slots stay within panel bounds", function()
        local inv = spawnInventoryPanel()
        UITestUtils.assertNoErrors(inv, {"containment"})
        dsl.remove(inv)
    end)

    TestRunner.it("cards render to same layer as inventory", function()
        local inv = spawnInventoryPanel()
        local card = addCardToSlot(inv, 0, testCard)
        UITestUtils.assertNoErrors(inv, {"layer_consistency"})
        dsl.remove(inv)
    end)

    TestRunner.it("dragged card renders above slots", function()
        local inv = spawnInventoryPanel()
        local card = addCardToSlot(inv, 0, testCard)
        simulateDragStart(card)

        local cardZ = layer_order_system.getZIndex(card)
        local slotZ = layer_order_system.getZIndex(getSlot(inv, 0))
        TestRunner.assert_true(cardZ > slotZ, "dragged card above slot")

        dsl.remove(inv)
    end)
end)
```

## Implementation Order

1. **Core validator** - Rule checks on computed layout data
2. **Test utilities** - Spawn, wait, assert helpers
3. **Inventory tests** - Validate planning mode inventory
4. **Tracked wrappers** - Render tracking for manual draws
5. **Debug overlay** - Visual feedback (outlines, labels, panel)
6. **Auto-validation** - Hook into dsl.spawn()

## Files to Create

- `assets/scripts/core/ui_validator.lua`
- `assets/scripts/core/ui_debug_overlay.lua`
- `assets/scripts/tests/ui_test_utils.lua`
- `assets/scripts/tests/test_ui_validation.lua`

## Files to Modify

- `assets/scripts/ui/ui_syntax_sugar.lua` - Add auto-validation hook
- `assets/scripts/ui/card_inventory_panel.lua` - Use tracked render wrappers

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
