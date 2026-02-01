# Tooltip Unification Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Unify all tooltips to use DSL-based pattern from card/player stat tooltips, fix spacing, ensure JetBrains font everywhere.

**Architecture:** Add `makeSimpleTooltip()` helper to gameplay.lua reusing existing DSL infrastructure. Migrate all `showTooltip()` callers to use new system. Delete legacy tooltip code.

**Tech Stack:** Lua, DSL UI system, localization system

---

## Task 1: Update tooltipStyle Spacing Constants

**Files:**
- Modify: `assets/scripts/core/gameplay.lua:251-269`

**Step 1: Update tooltipStyle table**

In `gameplay.lua`, find the `tooltipStyle` table at line 251 and update spacing values:

```lua
local tooltipStyle = {
    fontSize = 18,
    labelBg = "black",
    idBg = "gold",
    idTextColor = "black",
    labelColor = "apricot_cream",
    valueColor = "white",
    innerPadding = 2,
    rowPadding = 0,
    textPadding = 1,
    pillPadding = 2,  -- CHANGED: was 4, tighter pills
    outerPadding = 6, -- NEW: breathing room at edges
    labelColumnMinWidth = 120,
    valueColumnMinWidth = 52,
    bgColor = Col(18, 22, 32, 235),
    innerColor = Col(28, 32, 44, 230),
    outlineColor = (util.getColor and util.getColor("apricot_cream")) or Col(255, 214, 170, 255),
    fontName = "tooltip"
}
```

**Step 2: Verify the game still runs**

Run: `just build-debug && ./build/raylib-cpp-cmake-template`
Expected: Game launches without errors

**Step 3: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "style(tooltips): adjust spacing - tighter pills, more outer padding"
```

---

## Task 2: Add coded Text Option to makeTooltipTextDef

**Files:**
- Modify: `assets/scripts/core/gameplay.lua:300-313`

**Step 1: Update makeTooltipTextDef to support coded text**

Find `makeTooltipTextDef` at line 300 and update:

```lua
local function makeTooltipTextDef(text, opts)
    opts = opts or {}

    -- If coded option is set, use getTextFromString for rich text parsing
    if opts.coded and ui and ui.definitions and ui.definitions.getTextFromString then
        return ui.definitions.getTextFromString(tostring(text), {
            fontSize = opts.fontSize or tooltipStyle.fontSize,
            fontName = opts.fontName or tooltipStyle.fontName
        })
    end

    return ui.definitions.def {
        type = "TEXT",
        config = {
            text = tostring(text),
            color = opts.color or tooltipStyle.valueColor,
            fontSize = opts.fontSize or tooltipStyle.fontSize,
            fontName = opts.fontName or tooltipStyle.fontName,
            align = opts.align or bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
            shadow = opts.shadow or false
        }
    }
end
```

**Step 2: Verify the game still runs**

Run: `just build-debug && ./build/raylib-cpp-cmake-template`
Expected: Game launches, existing tooltips unchanged

**Step 3: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(tooltips): add coded text option for rich text parsing"
```

---

## Task 3: Update makeTooltipPill to Support coded and font Options

**Files:**
- Modify: `assets/scripts/core/gameplay.lua:315-334`

**Step 1: Update makeTooltipPill function**

Find `makeTooltipPill` at line 315 and update:

```lua
local function makeTooltipPill(text, opts)
    opts = opts or {}
    local cfg = {
        color = opts.background or tooltipStyle.labelBg,
        padding = opts.padding or tooltipStyle.pillPadding,
        align = opts.align or bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER)
    }
    if opts.minWidth then cfg.minWidth = opts.minWidth end
    local textOpts = {
        color = opts.color or tooltipStyle.labelColor,
        fontSize = opts.fontSize or tooltipStyle.fontSize,
        align = opts.textAlign,
        fontName = opts.fontName or tooltipStyle.fontName,
        shadow = opts.shadow,
        coded = opts.coded  -- NEW: pass through coded option
    }
    return dsl.hbox {
        config = cfg,
        children = { makeTooltipTextDef(text, textOpts) }
    }
end
```

**Step 2: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(tooltips): add coded/font options to makeTooltipPill"
```

---

## Task 4: Update makeTooltipValueBox to Support coded, font, and maxWidth Options

**Files:**
- Modify: `assets/scripts/core/gameplay.lua:336-354`

**Step 1: Update makeTooltipValueBox function**

Find `makeTooltipValueBox` at line 336 and update:

```lua
local function makeTooltipValueBox(text, opts)
    opts = opts or {}
    local cfg = {
        align = opts.align or bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
        padding = opts.padding or tooltipStyle.textPadding
    }
    if opts.minWidth then cfg.minWidth = opts.minWidth end
    if opts.maxWidth then cfg.maxWidth = opts.maxWidth end  -- NEW: support text wrapping
    local textOpts = {
        color = opts.color or tooltipStyle.valueColor,
        fontSize = opts.fontSize or tooltipStyle.fontSize,
        align = opts.textAlign or opts.align,
        fontName = opts.fontName or tooltipStyle.fontName,
        shadow = opts.shadow,
        coded = opts.coded  -- NEW: pass through coded option
    }
    return dsl.hbox {
        config = cfg,
        children = { makeTooltipTextDef(text, textOpts) }
    }
end
```

**Step 2: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(tooltips): add coded/font/maxWidth options to makeTooltipValueBox"
```

---

## Task 5: Add makeSimpleTooltip Function

**Files:**
- Modify: `assets/scripts/core/gameplay.lua` (add after makeTooltipRow, around line 370)

**Step 1: Add makeSimpleTooltip function**

After `destroyTooltipEntity` function (around line 375), add:

```lua
-- Simple tooltip for title + description (jokers, avatars, relics, buttons)
local function makeSimpleTooltip(title, body, opts)
    opts = opts or {}
    local outerPadding = opts.outerPadding or tooltipStyle.outerPadding or 6
    local rows = {}

    -- Title pill (styled like card ID pill)
    if title and title ~= "" then
        table.insert(rows, makeTooltipPill(title, {
            background = opts.titleBg or tooltipStyle.labelBg,
            color = opts.titleColor or tooltipStyle.labelColor,
            fontName = opts.titleFont or tooltipStyle.fontName,
            fontSize = opts.titleFontSize or tooltipStyle.fontSize,
            coded = opts.titleCoded
        }))
    end

    -- Body text (wrapped, no pill background)
    if body and body ~= "" then
        table.insert(rows, makeTooltipValueBox(body, {
            color = opts.bodyColor or tooltipStyle.valueColor,
            fontName = opts.bodyFont or tooltipStyle.fontName,
            fontSize = opts.bodyFontSize or tooltipStyle.fontSize,
            coded = opts.bodyCoded,
            maxWidth = opts.maxWidth or 250,
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER)
        }))
    end

    -- Build with DSL (single column)
    local v = dsl.vbox {
        config = {
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_TOP),
            color = tooltipStyle.innerColor,
            padding = outerPadding
        },
        children = rows
    }

    local root = dsl.root {
        config = {
            color = tooltipStyle.bgColor,
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
            padding = outerPadding,
            outlineThickness = 2,
            outlineColor = tooltipStyle.outlineColor,
            shadow = true
        },
        children = { v }
    }

    local boxID = dsl.spawn({ x = 200, y = 200 }, root)

    ui.box.set_draw_layer(boxID, "ui")
    ui.box.RenewAlignment(registry, boxID)
    snapTooltipVisual(boxID)
    ui.box.ClearStateTagsFromUIBox(boxID)

    return boxID
end
```

**Step 2: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(tooltips): add makeSimpleTooltip for title+description tooltips"
```

---

## Task 6: Add Simple Tooltip Cache and ensureSimpleTooltip

**Files:**
- Modify: `assets/scripts/core/gameplay.lua` (add after makeSimpleTooltip)

**Step 1: Add cache and ensure function**

After `makeSimpleTooltip`, add:

```lua
-- Cache for simple tooltips (keyed by string key)
local simple_tooltip_cache = {}

-- Ensure a simple tooltip exists (lazy init with caching)
local function ensureSimpleTooltip(key, title, body, opts)
    if not key then return nil end

    local cached = cacheFetch(simple_tooltip_cache, key)
    if cached then return cached end

    local tooltip = makeSimpleTooltip(title, body, opts)
    cacheStore(simple_tooltip_cache, key, tooltip)

    layer_order_system.assignZIndexToEntity(
        tooltip,
        z_orders.ui_tooltips or 1000
    )

    return tooltip
end

-- Show a simple tooltip positioned above an entity
local function showSimpleTooltipAbove(key, title, body, anchorEntity, opts)
    local tooltip = ensureSimpleTooltip(key, title, body, opts)
    if not tooltip then return nil end

    centerTooltipAboveEntity(tooltip, anchorEntity)
    return tooltip
end

-- Hide a simple tooltip (move offscreen, keep cached)
local function hideSimpleTooltip(key)
    local cached = simple_tooltip_cache[key]
    if not cached then return end
    local eid = cached.eid or cached
    if eid and entity_cache.valid(eid) then
        local t = component_cache.get(eid, Transform)
        if t then
            t.actualY = globals.screenHeight() + 100
            t.visualY = t.actualY
        end
    end
end

-- Destroy all cached simple tooltips (for cleanup)
local function destroyAllSimpleTooltips()
    for key, entry in pairs(simple_tooltip_cache) do
        local eid = entry.eid or entry
        destroyTooltipEntity(eid)
    end
    simple_tooltip_cache = {}
end
```

**Step 2: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(tooltips): add simple tooltip cache and lifecycle functions"
```

---

## Task 7: Export New Tooltip Functions

**Files:**
- Modify: `assets/scripts/core/gameplay.lua` (find where functions are exported/made global)

**Step 1: Find where tooltip functions are exported**

Search for where `centerTooltipAboveEntity` or similar are made available. These functions need to be accessible from other files. Look for patterns like:
- `_G.functionName = functionName`
- `return { functionName = functionName }`
- Functions defined without `local`

**Step 2: Export new functions**

Add exports for the new functions (exact location depends on how other functions are exported):

```lua
-- Make new tooltip functions globally accessible
_G.makeSimpleTooltip = makeSimpleTooltip
_G.ensureSimpleTooltip = ensureSimpleTooltip
_G.showSimpleTooltipAbove = showSimpleTooltipAbove
_G.hideSimpleTooltip = hideSimpleTooltip
_G.destroyAllSimpleTooltips = destroyAllSimpleTooltips
```

**Step 3: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(tooltips): export new simple tooltip functions globally"
```

---

## Task 8: Migrate avatar_joker_strip.lua Tooltips

**Files:**
- Modify: `assets/scripts/ui/avatar_joker_strip.lua:81-126` (applyTooltip function)
- Modify: `assets/scripts/ui/avatar_joker_strip.lua:581-639` (fallback drawing code)

**Step 1: Update applyTooltip function**

Replace the `applyTooltip` function at line 81:

```lua
local function applyTooltip(entity, title, body)
    if not entity or not component_cache then return end
    local go = component_cache.get(entity, GameObject)
    if not go then return end

    local state = go.state
    local methods = go.methods
    if not state or not methods then return end

    state.hoverEnabled = true
    state.collisionEnabled = true
    state.triggerOnReleaseEnabled = true
    state.clickEnabled = true

    -- Generate a unique key for this tooltip
    local tooltipKey = "avatar_joker_" .. tostring(entity)

    methods.onHover = function()
        if showSimpleTooltipAbove then
            showSimpleTooltipAbove(tooltipKey, title or "Unknown", body or "", entity)
            AvatarJokerStrip._activeTooltipOwner = entity
            AvatarJokerStrip._activeTooltipKey = tooltipKey
        end
    end

    methods.onStopHover = function()
        if AvatarJokerStrip._activeTooltipOwner and AvatarJokerStrip._activeTooltipOwner ~= entity then
            return
        end
        if hideSimpleTooltip and AvatarJokerStrip._activeTooltipKey then
            hideSimpleTooltip(AvatarJokerStrip._activeTooltipKey)
        end
        AvatarJokerStrip._activeTooltipOwner = nil
        AvatarJokerStrip._activeTooltipKey = nil
    end
end
```

**Step 2: Remove fallback tooltip drawing code**

Delete or comment out lines 581-639 (the fallback tooltip drawing code that uses command_buffer). The code starts with:
```lua
-- Fallback tooltip (only when shared tooltip UI isn't available)
if AvatarJokerStrip._fallbackHover and AvatarJokerStrip._fallbackHover.entity then
```

Replace with:
```lua
-- Fallback tooltip removed - now using DSL-based simple tooltips
```

**Step 3: Remove _fallbackHover references**

Search for and remove any remaining `_fallbackHover` references in the file.

**Step 4: Test avatar/joker tooltips**

Run: `just build-debug && ./build/raylib-cpp-cmake-template`
Expected: Hover over avatars/jokers shows styled tooltips

**Step 5: Commit**

```bash
git add assets/scripts/ui/avatar_joker_strip.lua
git commit -m "refactor(tooltips): migrate avatar_joker_strip to DSL tooltips"
```

---

## Task 9: Migrate ui_defs.lua Creature Button Tooltips

**Files:**
- Modify: `assets/scripts/ui/ui_defs.lua:645-676` (creature button hover handlers)

**Step 1: Update gold digger button hover**

Find line 649-655 and replace:

```lua
    goldDiggerButtonGameObject.methods.onHover = function(registry, hoveredOn, hovered)
        if showSimpleTooltipAbove then
            showSimpleTooltipAbove(
                "gold_digger_button",
                localization.get("ui.gold_digger_button"),
                localization.get("ui.gold_digger_tooltip_body"),
                globals.ui.goldDiggerButtonElement
            )
        end
    end
    goldDiggerButtonGameObject.methods.onStopHover = function()
        if hideSimpleTooltip then hideSimpleTooltip("gold_digger_button") end
    end
```

**Step 2: Update healer button hover**

Find line 660-665 and replace:

```lua
    healerButtonGameObject.methods.onHover = function(registry, hoveredOn, hovered)
        if showSimpleTooltipAbove then
            showSimpleTooltipAbove(
                "healer_button",
                localization.get("ui.healer_button"),
                localization.get("ui.healer_tooltip_body"),
                globals.ui.healerButtonElement
            )
        end
    end
    healerButtonGameObject.methods.onStopHover = function()
        if hideSimpleTooltip then hideSimpleTooltip("healer_button") end
    end
```

**Step 3: Update damage cushion button hover**

Find line 670-675 and replace:

```lua
    damageCushionButtonGameObject.methods.onHover = function(registry, hoveredOn, hovered)
        if showSimpleTooltipAbove then
            showSimpleTooltipAbove(
                "damage_cushion_button",
                localization.get("ui.damage_cushion_button"),
                localization.get("ui.damage_cushion_tooltip_body"),
                globals.ui.damageCushionButtonElement
            )
        end
    end
    damageCushionButtonGameObject.methods.onStopHover = function()
        if hideSimpleTooltip then hideSimpleTooltip("damage_cushion_button") end
    end
```

**Step 4: Commit**

```bash
git add assets/scripts/ui/ui_defs.lua
git commit -m "refactor(tooltips): migrate creature buttons to DSL tooltips"
```

---

## Task 10: Migrate ui_defs.lua Colonist Home Tooltip

**Files:**
- Modify: `assets/scripts/ui/ui_defs.lua:996-998`

**Step 1: Find and update colonist home tooltip**

Search for "colonist_home_tooltip" around line 996 and update the hover handler similarly:

```lua
-- Update onHover to use new system
gameObject.methods.onHover = function()
    if showSimpleTooltipAbove then
        showSimpleTooltipAbove(
            "colonist_home",
            localization.get("ui.colonist_home_tooltip_title"),
            localization.get("ui.colonist_home_tooltip_body"),
            entity  -- the element being hovered
        )
    end
end
gameObject.methods.onStopHover = function()
    if hideSimpleTooltip then hideSimpleTooltip("colonist_home") end
end
```

**Step 2: Commit**

```bash
git add assets/scripts/ui/ui_defs.lua
git commit -m "refactor(tooltips): migrate colonist home to DSL tooltips"
```

---

## Task 11: Migrate util.lua Relic Tooltips

**Files:**
- Modify: `assets/scripts/util/util.lua:2244-2252` (relic hover)
- Modify: `assets/scripts/util/util.lua:2367-2375` (relic shop 1)
- Modify: `assets/scripts/util/util.lua:2413-2421` (relic shop 2)
- Modify: `assets/scripts/util/util.lua:2458-2466` (relic shop 3)

**Step 1: Update buyRelicFromSlot relic hover (line 2246-2252)**

```lua
  local gameObject = component_cache.get(relicAnimationEntity, GameObject)
  gameObject.methods.onHover = function()
    log_debug("Relic hovered: ", relicDef.id)
    if showSimpleTooltipAbove then
      showSimpleTooltipAbove(
        "relic_" .. relicDef.id,
        localization.get(relicDef.localizationKeyName),
        localization.get(relicDef.localizationKeyDesc),
        relicAnimationEntity
      )
    end
  end
  gameObject.methods.onStopHover = function()
    if hideSimpleTooltip then hideSimpleTooltip("relic_" .. relicDef.id) end
  end
```

**Step 2: Update shop relic 1 hover (line 2369-2375)**

```lua
  local relicDef1 = relicDef
  gameObject1.methods.onHover = function()
    log_debug("Relic 1 hovered!")
    if showSimpleTooltipAbove then
      showSimpleTooltipAbove(
        "shop_relic_1",
        localization.get(relicDef1.localizationKeyName),
        localization.get(relicDef1.localizationKeyDesc),
        uiElement1
      )
    end
  end
  gameObject1.methods.onStopHover = function()
    if hideSimpleTooltip then hideSimpleTooltip("shop_relic_1") end
  end
```

**Step 3: Update shop relic 2 hover (line 2415-2421)**

```lua
  local relicDef2 = relicDef
  gameObject2.methods.onHover = function()
    log_debug("Relic 2 hovered!")
    if showSimpleTooltipAbove then
      showSimpleTooltipAbove(
        "shop_relic_2",
        localization.get(relicDef2.localizationKeyName),
        localization.get(relicDef2.localizationKeyDesc),
        uiElement2
      )
    end
  end
  gameObject2.methods.onStopHover = function()
    if hideSimpleTooltip then hideSimpleTooltip("shop_relic_2") end
  end
```

**Step 4: Update shop relic 3 hover (line 2460-2466)**

```lua
  local relicDef3 = relicDef
  gameObject3.methods.onHover = function()
    log_debug("Relic 3 hovered!")
    if showSimpleTooltipAbove then
      showSimpleTooltipAbove(
        "shop_relic_3",
        localization.get(relicDef3.localizationKeyName),
        localization.get(relicDef3.localizationKeyDesc),
        uiElement3
      )
    end
  end
  gameObject3.methods.onStopHover = function()
    if hideSimpleTooltip then hideSimpleTooltip("shop_relic_3") end
  end
```

**Step 5: Commit**

```bash
git add assets/scripts/util/util.lua
git commit -m "refactor(tooltips): migrate relic tooltips to DSL system"
```

---

## Task 12: Migrate entity_factory.lua Tooltips

**Files:**
- Modify: `assets/scripts/core/entity_factory.lua`

**Step 1: Search and update all showTooltip calls**

Find all `showTooltip` calls in entity_factory.lua (lines 71, 224, 356, 497, 955, 1169) and convert them to use `showSimpleTooltipAbove`. Each one follows the pattern:

```lua
-- Before:
showTooltip(titleText, bodyText)

-- After:
if showSimpleTooltipAbove then
    showSimpleTooltipAbove(
        "unique_key_for_this_entity",
        titleText,
        bodyText,
        entity  -- the entity being hovered
    )
end
```

Add corresponding `onStopHover` handlers:

```lua
gameObject.methods.onStopHover = function()
    if hideSimpleTooltip then hideSimpleTooltip("unique_key") end
end
```

**Step 2: Commit**

```bash
git add assets/scripts/core/entity_factory.lua
git commit -m "refactor(tooltips): migrate entity_factory tooltips to DSL system"
```

---

## Task 13: Migrate cast_execution_graph_ui.lua Tooltips

**Files:**
- Modify: `assets/scripts/ui/cast_execution_graph_ui.lua:120-122, 154-157`

**Step 1: Update hideActiveTooltip function (around line 120)**

Replace the hideTooltip call:

```lua
    if CastExecutionGraphUI._fallbackTooltipActive and CastExecutionGraphUI._fallbackTooltipKey then
        if hideSimpleTooltip then
            hideSimpleTooltip(CastExecutionGraphUI._fallbackTooltipKey)
        end
    end
```

**Step 2: Update attachTooltip fallback (around line 154-157)**

Replace the showTooltip fallback:

```lua
        go.methods.onHover = function()
            local shown = showCardTooltip(card, entity, label, body)
            if not shown and label then
                local tooltipKey = "cast_graph_" .. tostring(entity)
                if showSimpleTooltipAbove then
                    showSimpleTooltipAbove(tooltipKey, cleanLabel(label), cleanLabel(body), entity)
                    CastExecutionGraphUI._activeTooltipOwner = entity
                    CastExecutionGraphUI._fallbackTooltipKey = tooltipKey
                    CastExecutionGraphUI._fallbackTooltipActive = true
                end
            elseif shown then
                CastExecutionGraphUI._activeTooltipOwner = entity
            end
        end
```

**Step 3: Commit**

```bash
git add assets/scripts/ui/cast_execution_graph_ui.lua
git commit -m "refactor(tooltips): migrate cast_execution_graph_ui to DSL system"
```

---

## Task 14: Migrate ui_syntax_sugar.lua Tooltips

**Files:**
- Modify: `assets/scripts/ui/ui_syntax_sugar.lua:133-139`

**Step 1: Update dsl.applyHoverFromConfig function**

Find the hover handler around line 133-139 and replace:

```lua
    go.methods.onHover = function(_, hoveredOn, hovered)
        local tooltipKey = "dsl_hover_" .. tostring(entity)
        if showSimpleTooltipAbove then
            showSimpleTooltipAbove(
                tooltipKey,
                localization.get(hover.title),
                localization.get(hover.body),
                entity
            )
        end
        -- Store key for cleanup
        go._tooltipKey = tooltipKey
    end

    go.methods.onStopHover = function()
        if hideSimpleTooltip and go._tooltipKey then
            hideSimpleTooltip(go._tooltipKey)
        end
    end
```

**Step 2: Commit**

```bash
git add assets/scripts/ui/ui_syntax_sugar.lua
git commit -m "refactor(tooltips): migrate ui_syntax_sugar to DSL system"
```

---

## Task 15: Update main.lua Tooltip Hide Timer

**Files:**
- Modify: `assets/scripts/core/main.lua:604-615`

**Step 1: Update the tooltip hide timer**

The timer at line 604-615 calls `hideTooltip()`. This needs to be updated to work with the new system. Since we're now using entity-relative tooltips that hide on stopHover, we may be able to simplify or remove this timer. For now, make it a no-op or remove it:

```lua
    -- Legacy tooltip hide timer - no longer needed with DSL tooltips
    -- Tooltips now hide via onStopHover handlers
    timer.every(0.2, function()
        -- Kept for backwards compatibility but may be removed
        -- hideTooltip was used for mouse-following tooltips
    end,
    0,
    true,
    nil,
    "tooltip_hide_timer"
    )
```

**Step 2: Commit**

```bash
git add assets/scripts/core/main.lua
git commit -m "refactor(tooltips): disable legacy tooltip hide timer"
```

---

## Task 16: Delete Legacy Tooltip Functions from util.lua

**Files:**
- Modify: `assets/scripts/util/util.lua:2673-2748` (ensureTooltipFont, showTooltip)
- Modify: `assets/scripts/util/util.lua:2903-2911` (hideTooltip)

**Step 1: Delete ensureTooltipFont function**

Remove lines 2673-2689 (the TOOLTIP_FONT constants and ensureTooltipFont function).

**Step 2: Delete showTooltip function**

Remove lines 2691-2748 (the showTooltip function).

**Step 3: Delete hideTooltip function**

Remove lines 2903-2911 (the hideTooltip function).

**Step 4: Verify no remaining direct calls**

Run: `grep -r "showTooltip\|hideTooltip" assets/scripts/ --include="*.lua" | grep -v "_archived" | grep -v "Simple"`

Expected: No results (all calls should be migrated or commented out)

**Step 5: Commit**

```bash
git add assets/scripts/util/util.lua
git commit -m "refactor(tooltips): delete legacy showTooltip/hideTooltip functions"
```

---

## Task 17: Delete generateTooltipUI from ui_defs.lua

**Files:**
- Modify: `assets/scripts/ui/ui_defs.lua:1797-1893`

**Step 1: Delete generateTooltipUI function**

Remove the entire `generateTooltipUI` function (lines 1797-1893). This function creates the legacy tooltip entities that are no longer needed.

**Step 2: Commit**

```bash
git add assets/scripts/ui/ui_defs.lua
git commit -m "refactor(tooltips): delete legacy generateTooltipUI function"
```

---

## Task 18: Update Card Tooltip Spacing

**Files:**
- Modify: `assets/scripts/core/gameplay.lua:3110-3130`

**Step 1: Update card tooltip to use outerPadding**

Find the card tooltip layout code around line 3110 and update to use `tooltipStyle.outerPadding`:

```lua
    -- Single column layout for card tooltips
    local outerPadding = tooltipStyle.outerPadding or 6
    local v = dsl.vbox {
        config = {
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_TOP),
            color = tooltipStyle.innerColor,
            padding = outerPadding
        },
        children = rows
    }

    local root = dsl.root {
        config = {
            color = tooltipStyle.bgColor,
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
            padding = outerPadding,
            outlineThickness = 2,
            outlineColor = tooltipStyle.outlineColor,
            shadow = true
        },
        children = { v }
    }
```

**Step 2: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "style(tooltips): update card tooltip to use outerPadding"
```

---

## Task 19: Update Player Stats Tooltip Spacing

**Files:**
- Modify: `assets/scripts/core/gameplay.lua` (find makePlayerStatsTooltip function)

**Step 1: Find and update player stats tooltip**

Search for `makePlayerStatsTooltip` and update to use `tooltipStyle.outerPadding` for consistency.

**Step 2: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "style(tooltips): update player stats tooltip to use outerPadding"
```

---

## Task 20: Final Testing and Cleanup

**Step 1: Build and run**

Run: `just build-debug && ./build/raylib-cpp-cmake-template`

**Step 2: Test all tooltip types**

- [ ] Card tooltips - hover over cards in hand/deck
- [ ] Player stats tooltip - hover over player stats area
- [ ] Avatar tooltips - hover over avatars in strip
- [ ] Joker tooltips - hover over jokers in strip
- [ ] Creature button tooltips - hover over gold digger, healer, damage cushion buttons
- [ ] Relic tooltips - hover over owned relics and shop relics
- [ ] Any other tooltips found during testing

**Step 3: Verify visual consistency**

- [ ] All tooltips use same font (JetBrains Mono)
- [ ] All tooltips have consistent padding (pills tight, outer breathing room)
- [ ] All tooltips have consistent colors (dark bg, apricot cream outline)
- [ ] Pills are not oversized for their text

**Step 4: Final commit**

```bash
git add -A
git commit -m "test(tooltips): verify all tooltip types working with unified system"
```

---

## Summary

**Files Modified:**
- `assets/scripts/core/gameplay.lua` - Add helpers, adjust spacing, export functions
- `assets/scripts/ui/avatar_joker_strip.lua` - Migrate to DSL tooltips
- `assets/scripts/ui/ui_defs.lua` - Migrate buttons, delete legacy function
- `assets/scripts/util/util.lua` - Migrate relics, delete legacy functions
- `assets/scripts/core/entity_factory.lua` - Migrate entity tooltips
- `assets/scripts/ui/cast_execution_graph_ui.lua` - Migrate fallback tooltips
- `assets/scripts/ui/ui_syntax_sugar.lua` - Migrate DSL hover tooltips
- `assets/scripts/core/main.lua` - Update tooltip hide timer

**Total Tasks:** 20

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
