# UI Strict Mode Migration Plan

**Date:** 2026-01-15
**Status:** Draft
**Author:** Claude + Joshua

## Executive Summary

Migrate all production UI code from `dsl.*` to `dsl.strict.*` to gain compile-time validation, typo detection, and type safety. This is a **low-risk, high-reward** migration because:

- `dsl.strict.*` wraps the existing API (no behavioral changes)
- Migration is purely mechanical (find-replace + fix errors)
- Errors surface at definition time, not runtime
- Can be done file-by-file with immediate feedback

---

## Scope Analysis

### Files to Migrate (15 Production Files)

| Priority | File | DSL Calls | Complexity | Risk |
|----------|------|-----------|------------|------|
| P0 | `ui/tooltip_v2.lua` | 19 | Medium | Low |
| P0 | `ui/patch_notes_modal.lua` | 15 | Low | Low |
| P0 | `core/modal.lua` | 15 | Low | Low |
| P1 | `ui/stats_panel.lua` | 55 | High | Medium |
| P1 | `ui/stats_panel_v2.lua` | 46 | High | Medium |
| P1 | `ui/card_inventory_panel.lua` | 24 | Medium | Medium |
| P1 | `ui/player_inventory.lua` | 20 | Medium | Medium |
| P1 | `ui/wand_loadout_ui.lua` | 21 | Medium | Medium |
| P2 | `ui/cast_execution_graph_ui.lua` | 16 | Medium | Low |
| P2 | `ui/tag_synergy_panel.lua` | 7 | Low | Low |
| P2 | `ui/sprite_ui_showcase.lua` | 62 | High | Low (showcase) |
| P3 | `core/main.lua` | 37 | Medium | High |
| P3 | `core/gameplay.lua` | 24 | Medium | High |
| P3 | `ui/showcase/gallery_viewer.lua` | 35 | Medium | Low |
| P3 | `examples/inventory_grid_demo.lua` | 39 | Medium | Low (demo) |

**Total: ~435 DSL calls to migrate across 15 files**

### Already Using Strict (10 Test Files)

These files already use `dsl.strict.*` and serve as reference implementations:
- `tests/test_dsl_strict.lua`
- `tests/test_dsl_strict_primitives.lua`
- `tests/test_dsl_strict_layouts.lua`
- `tests/test_dsl_strict_interactive.lua`
- Plus 6 additional test/showcase test files

---

## Migration Strategy

### Approach: Incremental File-by-File

```
For each file:
1. Create backup branch
2. Replace `dsl.` with `dsl.strict.` (mechanical)
3. Run file to surface validation errors
4. Fix each error (guided by error messages)
5. Test UI functionality in-game
6. Commit with "refactor(ui): migrate X to dsl.strict"
```

### Why Not Bulk Migration?

- **Debugging difficulty**: Bulk changes make it hard to isolate issues
- **Risk**: Core files (main.lua, gameplay.lua) could break the game
- **Learning**: Each file teaches patterns for the next

### Tooling Support

#### 1. Migration Helper Script

Create `scripts/migrate_to_strict.lua`:

```lua
-- Usage: lua scripts/migrate_to_strict.lua assets/scripts/ui/tooltip_v2.lua
-- Performs mechanical replacement and reports potential issues

local function migrate_file(path)
    local content = io.open(path):read("*a")

    -- Replace dsl. with dsl.strict. (except dsl.strict. and dsl.spawn)
    local migrated = content:gsub("dsl%.(%w+)", function(fn)
        if fn == "strict" or fn == "spawn" or fn == "remove" then
            return "dsl." .. fn  -- Keep as-is
        end
        return "dsl.strict." .. fn
    end)

    -- Write migrated file
    io.open(path, "w"):write(migrated)

    -- Report
    print("Migrated: " .. path)
    print("Run the file to see validation errors")
end
```

#### 2. Validation Dry-Run

Before migrating, run validation in "warning mode" to preview errors:

```lua
-- In game console or test:
local schema = require("core.schema")
schema.STRICT_MODE = "warn"  -- Log errors but don't throw
require("ui.tooltip_v2")     -- Load file, see warnings
```

---

## Phase 1: Low-Risk Files (Week 1)

### Target: 3 files, ~49 DSL calls

These files have simple structures and limited game-critical dependencies:

#### 1.1 `ui/tooltip_v2.lua` (19 calls)

**Why first:**
- Self-contained module
- Clear 3-box structure
- Good test of nested vbox/hbox patterns

**Expected issues:**
- Possible typos in fontSize, padding props
- Color strings need validation

**Migration steps:**
```bash
git checkout -b migrate/tooltip-v2-strict
# Edit file: replace dsl. → dsl.strict.
# Run: lua -e "require('ui.tooltip_v2')"
# Fix errors
git commit -m "refactor(ui): migrate tooltip_v2 to dsl.strict"
```

#### 1.2 `ui/patch_notes_modal.lua` (15 calls)

**Why second:**
- Uses modal pattern (good for modal.lua next)
- Simple text + button structure

#### 1.3 `core/modal.lua` (15 calls)

**Why third:**
- Generic modal template
- Once migrated, all modals benefit

---

## Phase 2: Inventory/Panel Files (Week 2)

### Target: 5 files, ~166 DSL calls

These files use complex patterns (tabs, grids) that benefit most from validation:

#### 2.1 `ui/stats_panel_v2.lua` (46 calls)

**Why before stats_panel.lua:**
- Newer, cleaner code
- Lessons learned apply to v1

**Expected issues:**
- Dynamic content generation (stat rows)
- Tab configuration objects

#### 2.2 `ui/stats_panel.lua` (55 calls)

**Expected issues:**
- Heavy nesting (5+ levels)
- Collapsible section logic

#### 2.3 `ui/card_inventory_panel.lua` (24 calls)

**Expected issues:**
- inventoryGrid validation
- Dynamic tab content

#### 2.4 `ui/player_inventory.lua` (20 calls)

#### 2.5 `ui/wand_loadout_ui.lua` (21 calls)

---

## Phase 3: Secondary UI Files (Week 3)

### Target: 4 files, ~92 DSL calls

#### 3.1 `ui/cast_execution_graph_ui.lua` (16 calls)
#### 3.2 `ui/tag_synergy_panel.lua` (7 calls)
#### 3.3 `ui/sprite_ui_showcase.lua` (62 calls) - Showcase file, low risk
#### 3.4 `ui/showcase/gallery_viewer.lua` (35 calls)

---

## Phase 4: Core Files (Week 4)

### Target: 3 files, ~100 DSL calls

**Highest risk - require careful testing:**

#### 4.1 `examples/inventory_grid_demo.lua` (39 calls)

**Why first in Phase 4:**
- Example file, safe to break
- Tests patterns used in core files

#### 4.2 `core/gameplay.lua` (24 calls)

**Risk mitigation:**
- Create comprehensive test save
- Test all game states after migration
- Have rollback plan ready

#### 4.3 `core/main.lua` (37 calls)

**Risk mitigation:**
- Final migration
- Full regression test suite

---

## Common Migration Patterns

### Pattern 1: Simple Replacement

```lua
-- Before
local ui = dsl.vbox {
    children = {
        dsl.text("Hello", { fontSize = 16 }),
    }
}

-- After (mechanical replacement)
local ui = dsl.strict.vbox {
    children = {
        dsl.strict.text("Hello", { fontSize = 16 }),
    }
}
```

### Pattern 2: Dynamic Content Generation

```lua
-- Before
local function makeStatRow(stat)
    return dsl.hbox {
        children = {
            dsl.text(stat.label),
            dsl.text(tostring(stat.value)),
        }
    }
end

-- After (same pattern, just strict)
local function makeStatRow(stat)
    return dsl.strict.hbox {
        children = {
            dsl.strict.text(stat.label),
            dsl.strict.text(tostring(stat.value)),
        }
    }
end
```

### Pattern 3: Conditional Components

```lua
-- Before
local function makeUI(showExtra)
    return dsl.vbox {
        children = {
            dsl.text("Always"),
            showExtra and dsl.text("Sometimes") or nil,
        }
    }
end

-- After (filter nils from children)
local function makeUI(showExtra)
    local children = {
        dsl.strict.text("Always"),
    }
    if showExtra then
        table.insert(children, dsl.strict.text("Sometimes"))
    end
    return dsl.strict.vbox { children = children }
end
```

### Pattern 4: Spread Config Objects

```lua
-- Before (if someone spreads a config object)
local baseStyle = { fontSize = 14, color = "white" }
dsl.text("Hello", baseStyle)

-- After (works the same, strict validates the merged result)
dsl.strict.text("Hello", baseStyle)
```

---

## Error Resolution Guide

### Error: "unknown field 'X' - did you mean 'Y'?"

**Cause:** Typo in property name
**Fix:** Use the suggested property name

```lua
-- Error: unknown field 'fontsize' - did you mean 'fontSize'?
dsl.strict.text("Hi", { fontsize = 16 })
--                      ^^^^^^^^ Fix to fontSize
```

### Error: "field 'X' expected Y, got Z"

**Cause:** Wrong type for property
**Fix:** Convert to correct type

```lua
-- Error: field 'fontSize' expected number, got string
dsl.strict.text("Hi", { fontSize = "16" })
--                                 ^^^^ Fix to 16 (number)
```

### Error: "missing required field: X"

**Cause:** Required property not provided
**Fix:** Add the required property

```lua
-- Error: missing required field: children
dsl.strict.vbox {}
--              ^^ Fix to { children = {...} }
```

### Error: "field 'X' must be one of: A, B, C"

**Cause:** Invalid enum value
**Fix:** Use one of the allowed values

```lua
-- Error: field 'align' must be one of: left, center, right
dsl.strict.text("Hi", { align = "middle" })
--                              ^^^^^^^^ Fix to "center"
```

---

## Testing Strategy

### For Each Migrated File:

1. **Compile-time test:**
   ```bash
   lua -e "require('ui.tooltip_v2')"  # Should load without errors
   ```

2. **Visual test:**
   - Launch game
   - Navigate to UI that uses the file
   - Verify appearance matches pre-migration

3. **Interaction test:**
   - Click buttons, hover elements
   - Tab through tabs
   - Drag-drop (for inventory files)

4. **Edge case test:**
   - Empty states
   - Maximum content
   - Rapid interactions

### Regression Test Checklist

After migrating core files (Phase 4):

- [ ] Game launches successfully
- [ ] Main menu renders correctly
- [ ] Stats panel opens and displays data
- [ ] Inventory panel opens, tabs work
- [ ] Tooltips appear on hover
- [ ] Modals open and close
- [ ] Wand loadout UI functions
- [ ] Combat UI displays correctly
- [ ] No Lua errors in console

---

## Success Criteria

### Quantitative

- [ ] 100% of production UI files migrated (15/15)
- [ ] 0 validation errors at load time
- [ ] All existing tests still pass
- [ ] No new bugs introduced

### Qualitative

- [ ] Error messages are actionable
- [ ] New UI code uses `dsl.strict.*` by default
- [ ] Team understands when to use strict vs non-strict

---

## Rollback Plan

If migration causes critical issues:

1. **Per-file rollback:**
   ```bash
   git checkout HEAD~1 -- path/to/file.lua
   ```

2. **Phase rollback:**
   ```bash
   git revert --no-commit HEAD~N..HEAD
   ```

3. **Full rollback:**
   ```bash
   git checkout pre-strict-migration
   ```

---

## Post-Migration Tasks

### 1. Update Coding Standards

Add to CLAUDE.md or CONTRIBUTING.md:

```markdown
## UI DSL Usage

Always use `dsl.strict.*` for new UI code:

```lua
-- Required for new code
local ui = dsl.strict.vbox { ... }

-- Legacy (allowed for backwards compat)
local ui = dsl.vbox { ... }
```
```

### 2. Add CI Validation

```yaml
# .github/workflows/ui-validation.yml
- name: Validate UI Files
  run: |
    for file in assets/scripts/ui/*.lua; do
      lua -e "require('${file%.lua}')" || exit 1
    done
```

### 3. Consider Deprecation Timeline

After migration is complete and stable (2-4 weeks):
- Add deprecation warnings to non-strict functions
- Plan eventual removal of non-strict API

---

## Appendix: Full File List with Line Counts

```
Production Files (15 total, ~435 DSL calls):
├── ui/stats_panel.lua          (55 calls, 600+ lines)
├── ui/stats_panel_v2.lua       (46 calls, 500+ lines)
├── ui/sprite_ui_showcase.lua   (62 calls, 400+ lines)
├── ui/card_inventory_panel.lua (24 calls, 350+ lines)
├── ui/wand_loadout_ui.lua      (21 calls, 300+ lines)
├── ui/player_inventory.lua     (20 calls, 280+ lines)
├── ui/tooltip_v2.lua           (19 calls, 400+ lines)
├── ui/cast_execution_graph_ui.lua (16 calls, 250+ lines)
├── ui/patch_notes_modal.lua    (15 calls, 200+ lines)
├── core/modal.lua              (15 calls, 180+ lines)
├── ui/tag_synergy_panel.lua    (7 calls, 150+ lines)
├── core/main.lua               (37 calls, 800+ lines)
├── core/gameplay.lua           (24 calls, 1000+ lines)
├── ui/showcase/gallery_viewer.lua (35 calls, 500+ lines)
└── examples/inventory_grid_demo.lua (39 calls, 350+ lines)
```

---

## Timeline Summary

| Phase | Duration | Files | DSL Calls | Risk Level |
|-------|----------|-------|-----------|------------|
| Phase 1 | 2-3 days | 3 | 49 | Low |
| Phase 2 | 3-4 days | 5 | 166 | Medium |
| Phase 3 | 2-3 days | 4 | 92 | Low |
| Phase 4 | 2-3 days | 3 | 100 | High |
| **Total** | **~2 weeks** | **15** | **~435** | - |

---

## Next Steps

1. Review and approve this plan
2. Create migration helper script
3. Start with Phase 1, file 1 (`tooltip_v2.lua`)
4. Document any issues encountered for future files
