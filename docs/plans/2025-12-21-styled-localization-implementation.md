# Styled Localization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add `localization.getStyled()` function that parses `{param|color}` syntax in localization strings and outputs `[value](color=X)` markup for colored tooltip text.

**Architecture:** Lua wrapper module that extends the existing `localization` global. Parses template strings with gsub, handles both simple values and table-form `{value, color}` overrides, outputs markup compatible with `ui.definitions.getTextFromString()`.

**Tech Stack:** Lua, existing localization C++ bindings, existing text effects system

---

## Task 1: Create Core Module

**Files:**
- Create: `assets/scripts/core/localization_styled.lua`

**Step 1: Create the module file with getStyled function**

```lua
--- localization_styled.lua
--- Extends localization global with getStyled() for color-coded text
---
--- Usage:
---   local text = localization.getStyled("tooltip.attack", { damage = 25 })
---   -- With JSON: "Deal {damage|red} damage"
---   -- Returns: "Deal [25](color=red) damage"

local M = {}

--- Parse {param|color} patterns and substitute with colored markup
--- @param key string Localization key (e.g., "tooltip.attack_desc")
--- @param params table|nil Parameter values, either simple or {value=X, color="Y"}
--- @return string Processed string with [value](color=X) markup
function M.getStyled(key, params)
    -- Get raw template without fmt substitution
    local template = localization.getRaw(key)
    if not template then
        return "[MISSING: " .. tostring(key) .. "]"
    end

    -- Parse {param|color} patterns
    local result = template:gsub("{([^}]+)}", function(match)
        -- Split on pipe: "damage|red" -> name="damage", defaultColor="red"
        local name, defaultColor = match:match("^([^|]+)|?(.*)$")

        -- Look up parameter
        local param = params and params[name]

        -- If no param provided, keep original placeholder
        if param == nil then
            return "{" .. match .. "}"
        end

        -- Handle table form: {value=X, color="Y"} or simple value
        local value, color
        if type(param) == "table" then
            value = param.value
            color = param.color or (defaultColor ~= "" and defaultColor) or nil
        else
            value = param
            color = (defaultColor ~= "" and defaultColor) or nil
        end

        -- Wrap in color markup if color specified
        if color then
            return "[" .. tostring(value) .. "](color=" .. color .. ")"
        else
            return tostring(value)
        end
    end)

    return result
end

-- Register on localization global
if localization then
    localization.getStyled = M.getStyled
end

return M
```

**Step 2: Verify file created**

Run: `cat assets/scripts/core/localization_styled.lua | head -20`
Expected: Shows the module header and function signature

**Step 3: Commit**

```bash
git add assets/scripts/core/localization_styled.lua
git commit -m "feat(localization): add getStyled() for color-coded text

New function parses {param|color} syntax in localization strings
and outputs [value](color=X) markup for tooltip rendering.

Supports:
- JSON default colors: {damage|red}
- Lua runtime override: {damage = {value=25, color='gold'}}
- Mixed with manual markup passthrough"
```

---

## Task 2: Load Module at Startup

**Files:**
- Modify: `assets/scripts/core/globals.lua` (find require block)

**Step 1: Find where core modules are loaded**

Run: `grep -n "require.*core" assets/scripts/core/globals.lua | head -20`
Expected: Shows existing require statements for core modules

**Step 2: Add require for localization_styled**

Add after other core requires (near the end of the require block):

```lua
require("core.localization_styled")
```

**Step 3: Verify the require was added**

Run: `grep -n "localization_styled" assets/scripts/core/globals.lua`
Expected: Shows the new require line

**Step 4: Commit**

```bash
git add assets/scripts/core/globals.lua
git commit -m "feat(localization): load localization_styled at startup"
```

---

## Task 3: Add Test Localization Strings

**Files:**
- Modify: `assets/localization/en_us.json`

**Step 1: Check current structure of localization file**

Run: `head -30 assets/localization/en_us.json`
Expected: Shows JSON structure with nested keys

**Step 2: Add test entries for styled localization**

Add a new "test" section (or find appropriate location):

```json
  "test": {
    "styled_damage": "Deal {damage|red} damage",
    "styled_element": "Cast {element|fire} spell for {cost|blue} mana",
    "styled_mixed": "A [powerful](color=gold) attack dealing {damage|red} damage",
    "styled_no_color": "You have {count} items",
    "styled_heal": "Restore {amount|green} HP to target"
  },
```

**Step 3: Verify entries added**

Run: `grep -A 6 '"test":' assets/localization/en_us.json`
Expected: Shows the test section with styled entries

**Step 4: Commit**

```bash
git add assets/localization/en_us.json
git commit -m "test(localization): add test strings for styled localization"
```

---

## Task 4: Add Tooltip Helper Function

**Files:**
- Modify: `assets/scripts/core/gameplay.lua` (near makeSimpleTooltip)

**Step 1: Find makeSimpleTooltip location**

Run: `grep -n "local function makeSimpleTooltip" assets/scripts/core/gameplay.lua`
Expected: Shows line number of makeSimpleTooltip

**Step 2: Add makeLocalizedTooltip helper after makeSimpleTooltip**

Add after the `makeSimpleTooltip` function ends (after its closing `end`):

```lua
--- Create a tooltip with localized, color-coded text
--- @param key string Localization key
--- @param params table|nil Parameters for substitution (supports {value=X, color="Y"})
--- @param opts table|nil Options: title, maxWidth, titleColor
--- @return number|nil boxID The tooltip entity ID
local function makeLocalizedTooltip(key, params, opts)
    opts = opts or {}

    -- Use styled localization for color markup
    local text = localization.getStyled(key, params)

    return makeSimpleTooltip(
        opts.title or "",
        text,
        {
            bodyCoded = true,  -- Enable [text](effects) parsing
            maxWidth = opts.maxWidth or 320,
            bodyColor = opts.bodyColor,
            bodyFont = opts.bodyFont,
            bodyFontSize = opts.bodyFontSize
        }
    )
end
```

**Step 3: Verify function added**

Run: `grep -n "makeLocalizedTooltip" assets/scripts/core/gameplay.lua`
Expected: Shows the new function definition

**Step 4: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(ui): add makeLocalizedTooltip helper for styled tooltips"
```

---

## Task 5: Create Manual Test

**Files:**
- Create: `assets/scripts/test/test_styled_localization.lua`

**Step 1: Create test directory if needed**

Run: `mkdir -p assets/scripts/test`

**Step 2: Create manual test script**

```lua
--- test_styled_localization.lua
--- Manual test for localization.getStyled()
--- Run from Lua console or require during development

local function test_styled_localization()
    print("=== Testing localization.getStyled() ===\n")

    local tests = {
        {
            name = "Basic color substitution",
            key = "test.styled_damage",
            params = { damage = 25 },
            expected = "Deal [25](color=red) damage"
        },
        {
            name = "Multiple params with colors",
            key = "test.styled_element",
            params = { element = "Fire", cost = 10 },
            expected = "Cast [Fire](color=fire) spell for [10](color=blue) mana"
        },
        {
            name = "Override color at runtime",
            key = "test.styled_damage",
            params = { damage = { value = 50, color = "gold" } },
            expected = "Deal [50](color=gold) damage"
        },
        {
            name = "No color specified",
            key = "test.styled_no_color",
            params = { count = 5 },
            expected = "You have 5 items"
        },
        {
            name = "Missing param stays as placeholder",
            key = "test.styled_damage",
            params = {},
            expected = "Deal {damage|red} damage"
        },
        {
            name = "Mixed manual markup and styled",
            key = "test.styled_mixed",
            params = { damage = 100 },
            expected = "A [powerful](color=gold) attack dealing [100](color=red) damage"
        }
    }

    local passed = 0
    local failed = 0

    for _, t in ipairs(tests) do
        local result = localization.getStyled(t.key, t.params)
        if result == t.expected then
            print("[PASS] " .. t.name)
            passed = passed + 1
        else
            print("[FAIL] " .. t.name)
            print("  Expected: " .. t.expected)
            print("  Got:      " .. result)
            failed = failed + 1
        end
    end

    print("\n=== Results: " .. passed .. " passed, " .. failed .. " failed ===")
    return failed == 0
end

return test_styled_localization
```

**Step 3: Verify test file created**

Run: `cat assets/scripts/test/test_styled_localization.lua | head -10`
Expected: Shows test file header

**Step 4: Commit**

```bash
git add assets/scripts/test/test_styled_localization.lua
git commit -m "test(localization): add manual test for getStyled()"
```

---

## Task 6: Build and Run Tests

**Files:**
- None (verification only)

**Step 1: Build the project**

Run: `just build-debug`
Expected: Build succeeds with no errors

**Step 2: Document how to run manual test**

The test can be run in-game via Lua console:
```lua
local test = require("test.test_styled_localization")
test()
```

Or add to a debug menu if available.

**Step 3: Commit build verification**

No commit needed - this is verification only.

---

## Task 7: Update CLAUDE.md Documentation

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Find localization section or add new section**

Run: `grep -n -i "localization" CLAUDE.md | head -10`
Expected: Shows if localization section exists

**Step 2: Add styled localization documentation**

Add near other API documentation:

```markdown
---

## Styled Localization

For color-coded text in tooltips, use `localization.getStyled()`:

### JSON Syntax
```json
{
  "tooltip": {
    "attack_desc": "Deal {damage|red} {element|fire} damage"
  }
}
```

### Lua Usage
```lua
-- Uses JSON default colors
local text = localization.getStyled("tooltip.attack_desc", {
  damage = 25,
  element = "Fire"
})
-- Result: "Deal [25](color=red) [Fire](color=fire) damage"

-- Override color at runtime
local text = localization.getStyled("tooltip.attack_desc", {
  damage = { value = 25, color = "gold" }
})
-- Result: "Deal [25](color=gold) [Fire](color=fire) damage"
```

### Tooltip Helper
```lua
local tooltip = makeLocalizedTooltip("tooltip.attack_desc", {
  damage = card.damage,
  element = card.element
}, { title = card.name })
```

**Named Colors:** `red`, `gold`, `green`, `blue`, `cyan`, `purple`, `fire`, `ice`, `poison`, `holy`, `void`, `electric`
```

**Step 3: Verify documentation added**

Run: `grep -n "getStyled" CLAUDE.md`
Expected: Shows the new documentation

**Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add styled localization API documentation"
```

---

## Task 8: Final Integration Verification

**Files:**
- None (verification only)

**Step 1: Verify all files exist**

Run: `ls -la assets/scripts/core/localization_styled.lua assets/scripts/test/test_styled_localization.lua`
Expected: Both files exist

**Step 2: Verify module loads**

Run: `grep "localization_styled" assets/scripts/core/globals.lua`
Expected: Shows require statement

**Step 3: Verify localization strings**

Run: `grep "styled_damage" assets/localization/en_us.json`
Expected: Shows test string

**Step 4: Run full build**

Run: `just build-debug`
Expected: Clean build with no errors

**Step 5: Final commit (if any uncommitted changes)**

```bash
git status
# If clean: done
# If changes: commit appropriately
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Create core module | `localization_styled.lua` |
| 2 | Load at startup | `globals.lua` |
| 3 | Add test strings | `en_us.json` |
| 4 | Add tooltip helper | `gameplay.lua` |
| 5 | Create manual test | `test_styled_localization.lua` |
| 6 | Build verification | - |
| 7 | Update docs | `CLAUDE.md` |
| 8 | Final verification | - |

**Total estimated time:** 20-30 minutes

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
