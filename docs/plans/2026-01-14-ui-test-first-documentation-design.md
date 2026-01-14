# UI System Test-First Documentation Design

**Date:** 2026-01-14
**Status:** Approved
**Author:** Claude + Joshua

## Vision Statement

**Every UI feature is documented through working tests that prove it works.** Developers gain confidence through:
1. **Automated tests** that verify correctness before runtime
2. **Comprehensive showcases** that serve as copy-paste examples
3. **Stricter API** that catches mistakes at call time with clear messages

## Requirements Summary

| Dimension | Decision |
|-----------|----------|
| **Core Problems** | Confidence, Usage inconsistency, Positioning drift, Dynamic content issues |
| **Solutions** | Automated tests, Comprehensive examples, Stricter API |
| **API Changes** | Prefer stability — add new patterns, deprecate gradually |
| **Scope** | Full system (layouts, interactive, tabs, grids, drag-drop, etc.) |
| **Test Depth** | Structure + Layout + Interaction tests (no visual snapshots) |

---

## Architecture Overview

```
assets/scripts/ui/
├── ui_syntax_sugar.lua          # Core DSL (existing) + strict wrappers
├── tests/
│   ├── _framework/
│   │   ├── ui_test_runner.lua   # Test harness & assertions
│   │   ├── ui_test_assertions.lua
│   │   └── ui_test_helpers.lua
│   ├── layout/                  # Layout tests
│   │   ├── test_hbox.lua
│   │   ├── test_vbox.lua
│   │   ├── test_spacing.lua
│   │   ├── test_sizing.lua
│   │   └── test_nesting.lua
│   ├── elements/                # Element sizing tests
│   │   ├── test_text_sizing.lua
│   │   ├── test_button.lua
│   │   ├── test_anim_sizing.lua
│   │   └── test_sprite_panel.lua
│   ├── objects/                 # Objects in UI
│   │   ├── test_entity_in_ui.lua
│   │   └── test_custom_panel.lua
│   ├── measurement/             # Bounds & overlap detection
│   │   ├── test_bounds.lua
│   │   ├── test_overlap.lua
│   │   ├── test_corner_alignment.lua
│   │   └── test_containment.lua
│   ├── interactive/             # Click, hover, drag
│   │   ├── test_click.lua
│   │   ├── test_hover.lua
│   │   └── test_drag_drop.lua
│   ├── complex/                 # Tabs, grids, dynamic
│   │   ├── test_tabs.lua
│   │   ├── test_inventory_grid.lua
│   │   └── test_dynamic_content.lua
│   ├── validation/              # Strict API tests
│   │   └── test_strict_api.lua
│   └── run_all_tests.lua        # Master runner
├── showcases/
│   ├── showcase_runner.lua      # Showcase menu
│   ├── layout_showcase.lua      # All layout patterns
│   ├── text_showcase.lua        # All text variations
│   ├── sprite_showcase.lua      # Sprites & animations
│   ├── entity_showcase.lua      # Entities in UI
│   ├── interactive_showcase.lua # Buttons, hover, click
│   ├── tabs_showcase.lua        # Tab system
│   ├── grid_showcase.lua        # Inventory grids
│   ├── panel_showcase.lua       # Nine-patch panels
│   ├── corner_showcase.lua      # Corner alignment patterns
│   ├── dynamic_showcase.lua     # Dynamic content
│   └── edge_cases_showcase.lua  # Edge cases
└── validation/
    └── validation_rules.lua     # Strict mode validators
```

---

## Test Framework Design

### Test File Format

Each test file follows a consistent pattern that makes it both runnable AND readable as documentation:

```lua
-- test_hbox.lua
-- FEATURE: Horizontal Box Layout (dsl.hbox)
-- Arranges children in a horizontal row with configurable spacing.

local UITest = require("ui.tests._framework.ui_test_runner")
local dsl = require("ui.ui_syntax_sugar")

local tests = UITest.suite("hbox")

-----------------------------------------------------------------------
-- EXAMPLE 1: Basic horizontal layout
-- Three boxes arranged left-to-right
-----------------------------------------------------------------------
tests:add("basic_horizontal_layout", function(t)
    local ui = dsl.root {
        children = {
            dsl.hbox {
                children = {
                    dsl.text("A", { w = 50, h = 30 }),
                    dsl.text("B", { w = 50, h = 30 }),
                    dsl.text("C", { w = 50, h = 30 }),
                }
            }
        }
    }

    local entity = dsl.spawn({ x = 0, y = 0 }, ui)

    -- Structure assertions
    t:assertChildCount(entity, 1)              -- root has 1 child (hbox)
    t:assertChildCount(t:child(entity, 1), 3)  -- hbox has 3 children

    -- Layout assertions
    t:assertPositions(t:child(entity, 1), {
        { x = 0,   y = 0 },   -- A
        { x = 50,  y = 0 },   -- B
        { x = 100, y = 0 },   -- C
    })

    t:cleanup(entity)
end)

return tests
```

### Assertion Types

| Category | Assertions |
|----------|------------|
| **Basic** | `assertEqual`, `assertTrue`, `assertFalse`, `assertNoError`, `assertError`, `assertErrorContains` |
| **Structure** | `assertEntityExists`, `assertChildCount`, `assertHasComponent` |
| **Layout** | `assertPosition`, `assertPositions`, `assertSize`, `assertSizeInRange`, `assertSizeGreaterThan` |
| **Bounds** | `getAbsoluteBounds`, `measureAll` |
| **Overlap** | `assertNoSiblingOverlap`, `assertNoOverlapInTree`, `boundsOverlap` |
| **Anchor** | `assertAnchorCorrect` (all 9 positions) |
| **Containment** | `assertChildrenWithinBounds`, `detectOverflow` |
| **Interaction** | `simulateClick`, `simulateHover`, `triggerLayoutUpdate` |

---

## Test Coverage Matrix

| Category | What's Tested | Test Count (Est.) |
|----------|---------------|-------------------|
| **Layout: hbox** | basic, gap, padding, gap+padding, alignment, empty, single child | 8-10 |
| **Layout: vbox** | basic, gap, padding, alignment, mixed heights | 6-8 |
| **Layout: nesting** | hbox-in-vbox, vbox-in-hbox, 3 levels deep | 5-7 |
| **Text sizing** | explicit, auto-from-content, empty, long, wrapped, multiline | 8-10 |
| **Button sizing** | explicit, auto-from-label, padding, icon+label | 5-6 |
| **Sprite sizing** | explicit, auto-from-asset, scaled, animation-stable, missing | 6-8 |
| **Entity in UI** | card sizing, auto-from-transform, destroyed, nil, grid | 6-8 |
| **Custom panel** | explicit required, layout integration, render bounds | 4-5 |
| **Sprite panel** | border minimums, clamp, auto-from-children | 4-5 |
| **Bounds measurement** | absolute bounds, recursive measure | 3-4 |
| **Overlap detection** | siblings, tree, intentional allowed | 4-5 |
| **Corner alignment** | all 9 anchors, anchor+offset, close button, badge, footer | 10-12 |
| **Containment** | children within parent, overflow detection | 4-5 |
| **Interaction** | click, hover enter/exit, callbacks fire | 6-8 |
| **Tabs** | switch, active tab, cleanup, nested | 5-7 |
| **Inventory grid** | sizing, slot positions, drag-drop, entity slots | 6-8 |
| **Dynamic content** | size change triggers relayout, add/remove children | 4-6 |
| **Validation** | typos, wrong types, negative values, missing required | 10-12 |
| **Showcase validation** | all showcases load without error | 10-12 |

**Total: ~120-150 tests**

---

## Element Sizing Tests

Every element type must have verified sizing behavior. Layout correctness depends on elements reporting accurate dimensions.

### Element Sizing Matrix

| Element | Size Tests Required |
|---------|---------------------|
| **text** | explicit, auto-from-content, empty, long, wrapped, multiline, fontSize variations |
| **richText** | same as text + markup doesn't break sizing |
| **dynamicText** | size updates when content changes |
| **button** | explicit, auto-from-label, padding affects size, icon+label combo |
| **spriteButton** | explicit, auto-from-sprite-dimensions, all 4 states same size |
| **anim** | explicit, auto-from-sprite-sheet, frame changes don't affect size |
| **spritePanel** | explicit, nine-patch borders affect minimum size |
| **spacer** | explicit only (no auto-size) |
| **progressBar** | explicit, default size if omitted |
| **iconLabel** | combined size of icon + gap + label |

### Edge Cases for ALL Elements

- `nil` size uses sensible defaults
- Zero size is valid
- Negative size clamped to zero
- Fractional sizes handled consistently

---

## Object Content in UI

### Sprites & Animations

```lua
tests:add("sprite_in_hbox_layout", function(t)
    local ui = dsl.hbox {
        children = {
            dsl.anim("kobold", { w = 64, h = 64 }),
            dsl.text("Label"),
        }
    }
    local entity = dsl.spawn({ x = 0, y = 0 }, ui)

    local labelPos = t:getPosition(t:child(entity, 2))
    t:assertEqual(labelPos.x, 64, "label should start after 64px sprite")
    t:cleanup(entity)
end)
```

### Game Entities in UI

```lua
tests:add("entity_destroyed_graceful", function(t)
    local item = EntityBuilder.simple("potion", 0, 0, 32, 32)

    local ui = dsl.hbox {
        children = {
            dsl.entitySlot({ entity = item, w = 32, h = 32 }),
            dsl.text("After"),
        }
    }
    local container = dsl.spawn({ x = 0, y = 0 }, ui)

    -- Destroy the entity
    registry:destroy(item)

    -- UI should handle gracefully (not crash, maintain layout)
    t:assertNoError(function()
        t:triggerLayoutUpdate(container)
    end)

    t:cleanup(container)
end)
```

### Custom Panels

```lua
tests:add("custom_panel_receives_correct_bounds", function(t)
    local receivedBounds = nil

    local ui = dsl.hbox {
        children = {
            dsl.spacer(50, 0),
            dsl.customPanel {
                w = 100, h = 60,
                render = function(self)
                    receivedBounds = { x = self.x, y = self.y, w = self.w, h = self.h }
                end
            },
        }
    }
    local container = dsl.spawn({ x = 10, y = 20 }, ui)

    t:triggerRender(container)

    t:assertEqual(receivedBounds, { x = 60, y = 20, w = 100, h = 60 })
    t:cleanup(container)
end)
```

---

## Layout Measurement & Overlap Detection

### Bounds Measurement

Every element's bounds must be precisely measurable:

```lua
tests:add("absolute_bounds_calculation", function(t)
    local ui = dsl.root {
        config = { padding = 10 },
        children = {
            dsl.hbox {
                config = { gap = 5 },
                children = {
                    dsl.text("A", { w = 50, h = 30 }),
                    dsl.text("B", { w = 60, h = 30 }),
                }
            }
        }
    }
    local entity = dsl.spawn({ x = 100, y = 200 }, ui)

    local rootBounds = t:getAbsoluteBounds(entity)
    t:assertEqual(rootBounds, {
        x = 100, y = 200,
        w = 135, h = 50,
        right = 235, bottom = 250,
    })

    t:cleanup(entity)
end)
```

### Overlap Detection

```lua
tests:add("hbox_siblings_no_overlap", function(t)
    local ui = dsl.hbox {
        children = {
            dsl.text("A", { w = 50, h = 30 }),
            dsl.text("B", { w = 50, h = 30 }),
            dsl.text("C", { w = 50, h = 30 }),
        }
    }
    local entity = dsl.spawn({ x = 0, y = 0 }, ui)

    t:assertNoSiblingOverlap(entity)
    t:cleanup(entity)
end)
```

### Corner & Edge Alignment

All 9 anchor positions tested:
- `top_left`, `top_center`, `top_right`
- `middle_left`, `center`, `middle_right`
- `bottom_left`, `bottom_center`, `bottom_right`

Common patterns tested:
- Close button (top-right X)
- Badge (top-left notification)
- Footer (bottom-anchored buttons)
- Anchor + offset combinations

---

## Reference Implementations (Showcases)

### Purpose

Every test category has a corresponding working showcase that:
1. Demonstrates all features in a running UI
2. Serves as the "golden" implementation tests validate against
3. Acts as copy-paste source for developers

### Showcase List

| Showcase | Demonstrates |
|----------|--------------|
| `layout_showcase.lua` | hbox, vbox, nesting, gap, padding, alignment |
| `text_showcase.lua` | text, richText, dynamicText, all sizing modes |
| `sprite_showcase.lua` | anim, scaling, animation stability |
| `entity_showcase.lua` | entities in UI, entitySlot, destroyed handling |
| `interactive_showcase.lua` | buttons, hover states, click handlers |
| `tabs_showcase.lua` | tab switching, tab content |
| `grid_showcase.lua` | inventoryGrid, slot positions, drag-drop |
| `panel_showcase.lua` | spritePanel, nine-patch, decorations |
| `corner_showcase.lua` | all 9 anchors, close buttons, badges, footers |
| `dynamic_showcase.lua` | content changes, add/remove children |
| `edge_cases_showcase.lua` | empty containers, zero sizes, many children |

### Showcase Runner

```lua
-- Console command to show any showcase
console.register("ui_showcase", function(args)
    local ShowcaseRunner = require("ui.showcases.showcase_runner")
    if args[1] then
        ShowcaseRunner.show(args[1])
    else
        ShowcaseRunner.showMenu()
    end
end)
```

---

## Stricter API Layer

### Strategy

Add validation that catches mistakes **at call time** with clear, actionable error messages — without breaking existing code. Developers opt-in by using validated versions.

```lua
-- Original (lenient): dsl.hbox { ... }
-- Validated (strict): dsl.strict.hbox { ... }
```

### Validation Rules by Element

| Element | Validations |
|---------|-------------|
| **hbox/vbox** | children is table, gap/padding non-negative, typo detection (`child` vs `children`) |
| **text** | content required, w/h non-negative, fontSize positive and reasonable |
| **button** | label required, onClick is function, typo detection (`onclick` vs `onClick`) |
| **anim** | spriteId required and string, scale positive |
| **spritePanel** | sprite required, borders exactly 4 non-negative numbers |
| **tabs** | tabs array non-empty, unique ids, each tab has label or icon |
| **inventoryGrid** | cols/rows positive integers, items count ≤ total slots |

### Error Message Format

```
UI DSL Error in dsl.button
  Property: onClick
  Problem: must be a function
  Got: number
  Example: onClick = function() print('clicked') end
```

### Global Toggle

```lua
-- Enable strict mode during development
UI_STRICT_MODE = true

-- Or per-file opt-in
local dsl = require("ui.ui_syntax_sugar").strict
```

---

## Test Runner & CI Integration

### Console Commands

| Command | Purpose |
|---------|---------|
| `ui_test` | Run all UI tests in game |
| `ui_test_quick` | Run tests with less output |
| `ui_test_suite <path>` | Run single test suite |
| `ui_showcase` | Show showcase picker menu |
| `ui_showcase <name>` | Show specific showcase |

### Justfile Targets

```makefile
ui-test:
    ./build/raylib-cpp-cmake-template --run-lua "require('ui.tests.run_all_tests').runAll()"

ui-test-filter PATTERN:
    ./build/raylib-cpp-cmake-template --run-lua "require('ui.tests.run_all_tests').runAll({filter='{{PATTERN}}'})"

ui-test-ci:
    ./build/raylib-cpp-cmake-template --headless --run-lua "require('ci.run_ui_tests')()"

ui-showcase:
    ./build/raylib-cpp-cmake-template --run-lua "require('ui.showcases.showcase_runner').showMenu()"
```

### CI Output

JUnit XML format for CI integration:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="UI Tests" tests="120" failures="0" time="0.096">
  <testcase name="hbox.basic_horizontal_layout" time="0.012"/>
  ...
</testsuite>
```

---

## Deliverables Checklist

| # | Deliverable | Description |
|---|-------------|-------------|
| 1 | **Test Framework** | `ui_test_runner.lua` with all assertion types |
| 2 | **Layout Tests** | hbox, vbox, nesting, spacing, sizing |
| 3 | **Element Sizing Tests** | text, button, anim, spritePanel |
| 4 | **Object Tests** | entities in UI, custom panels |
| 5 | **Measurement Tests** | bounds, overlap, anchor, containment |
| 6 | **Interactive Tests** | click, hover, drag-drop |
| 7 | **Complex Tests** | tabs, grids, dynamic content |
| 8 | **Showcases** | 10+ working showcases covering all features |
| 9 | **Showcase Validation** | Tests that verify showcases work |
| 10 | **Validation Rules** | Strict API wrappers for all elements |
| 11 | **Validation Tests** | Tests that verify strict mode catches errors |
| 12 | **Test Runner** | Master runner + CI integration |
| 13 | **Console Commands** | `ui_test`, `ui_showcase` commands |
| 14 | **Justfile Targets** | `ui-test`, `ui-test-ci`, `ui-showcase` |

---

## Implementation Phases

| Phase | Focus | Effort |
|-------|-------|--------|
| **Phase 1** | Test framework + basic layout tests (hbox, vbox) | 2-3 days |
| **Phase 2** | Element sizing tests + layout showcase | 2-3 days |
| **Phase 3** | Measurement tests (bounds, overlap, anchors) | 2-3 days |
| **Phase 4** | Strict API validation layer | 1-2 days |
| **Phase 5** | Interactive + complex tests (tabs, grids) | 2-3 days |
| **Phase 6** | All showcases + showcase validation | 2-3 days |
| **Phase 7** | CI integration + polish | 1 day |

**Total estimate: 12-18 days**

---

## Success Criteria

When this is complete, you will be able to:

1. **Run `just ui-test`** and see all 120+ tests pass
2. **Open any showcase** and see working examples of every feature
3. **Use `dsl.strict.*`** and get clear errors for any mistakes
4. **Copy-paste from tests** directly into your UI code
5. **Trust that layouts work** because tests verify positions and sizes
6. **Catch regressions** when any UI change breaks existing behavior
