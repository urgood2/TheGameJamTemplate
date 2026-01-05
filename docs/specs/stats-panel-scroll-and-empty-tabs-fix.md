# Stats Panel: Scroll and Empty Tabs Fix

## Problem Summary

Two issues with the current stats panel implementation:

1. **ScrollPane becomes unresponsive after tab switch**: Mouse wheel scrolling stops working entirely after switching tabs, though section collapse/expand buttons still work.

2. **Non-Combat tabs show "No stats in this category"**: Tabs 2-5 (Resist, Mods, DoTs, Utility) display the fallback message. Combat tab partially works (consistent pattern - some sections always empty).

## Root Cause Analysis

### Issue 1: Scroll Stops Working

**Root cause**: Entity ID mismatch after panel rebuild.

The input system tracks the currently hovered scroll pane in `inputState.activeScrollPane` (entity ID). When `_rebuildTabContent()` is called:

1. `_createPanel()` destroys the old panel entity (including the scroll pane)
2. A new panel with new scroll pane entity is created (different entity ID)
3. `inputState.activeScrollPane` still holds the OLD entity ID
4. The check at `input_functions.cpp:194-199` fails because:
   - `registry.valid(inputState.activeScrollPane)` returns false (entity destroyed)
   - OR the entity is not in `nodes_at_cursor` (it's a different entity now)
5. Scroll input is ignored until mouse leaves and re-enters the panel

**Evidence**: Section headers (buttons) still work because they're processed via `buttonCallback` which uses the new entities. Scroll relies on the cached `activeScrollPane` reference.

### Issue 2: Empty Tabs

**Root cause**: `createStatPill()` returns `nil` when `StatTooltipSystem.DEFS` doesn't have an entry for the stat key.

Looking at `createStatPill()` lines 587-670:
```lua
local def = defs[statKey]
-- ...
if def and def.keys then
    value = snapshot[def.keys[1]]
else
    value = snapshot[statKey]
end
```

If `def` is nil (stat not in DEFS), `value` becomes `nil`, and even with `showZeros = true`, the pill is skipped.

**Affected stats**: Many stats in `TAB_LAYOUTS` (resist, mods, dots, utility) are not defined in `StatTooltipSystem.DEFS`, or are named differently.

## Requirements

### Scroll Fix Requirements
- [x] Preserve scroll position per-tab (save offset before switch, restore after)
- [x] ScrollPane must respond to mouse wheel immediately after tab switch
- [x] Fix applies to both tab switches AND stat-change rebuilds

### Empty Stats Fix Requirements
- [x] Show ALL stats defined in `TAB_LAYOUTS`, even if value is 0%
- [x] Stats not in `StatTooltipSystem.DEFS` should still display with fallback formatting
- [x] Consistent display across all 5 tabs

### Performance Consideration
- [ ] Optional: Address the lag on stat updates (every 0.5s rebuild)
  - Not in scope for this fix, but noted for future optimization

## Implementation Plan

### Phase 1: Fix Scroll State Preservation

**File**: `assets/scripts/ui/stats_panel.lua`

#### 1.1 Add per-tab scroll state storage

Add to `StatsPanel._state`:
```lua
tabScrollOffsets = {},  -- { [tabIndex] = scrollOffset }
```

#### 1.2 Save scroll offset before rebuild

In `_rebuildTabContent()`, before calling `_createPanel()`:
```lua
-- Save current scroll offset for this tab
local currentScrollOffset = StatsPanel._getScrollOffset()
if currentScrollOffset then
    state.tabScrollOffsets[state.currentTab] = currentScrollOffset
end
```

#### 1.3 Create helper to get scroll offset from entity

New function:
```lua
function StatsPanel._getScrollOffset()
    local state = StatsPanel._state
    if not state.panelEntity or not entity_cache.valid(state.panelEntity) then
        return nil
    end

    -- Find scroll pane child by ID
    local scrollPane = ui.box.GetUIEByID(registry, state.panelEntity, "stats_panel_scroll")
    if not scrollPane or not entity_cache.valid(scrollPane) then
        return nil
    end

    -- Get UIScrollComponent offset
    local scrollComp = component_cache.get(scrollPane, UIScrollComponent)
    if scrollComp then
        return scrollComp.offset
    end
    return nil
end
```

#### 1.4 Restore scroll offset after rebuild

New function called at end of `_createPanel()`:
```lua
function StatsPanel._restoreScrollOffset()
    local state = StatsPanel._state
    local savedOffset = state.tabScrollOffsets[state.currentTab]
    if not savedOffset or savedOffset == 0 then return end

    local scrollPane = ui.box.GetUIEByID(registry, state.panelEntity, "stats_panel_scroll")
    if not scrollPane or not entity_cache.valid(scrollPane) then return end

    local scrollComp = component_cache.get(scrollPane, UIScrollComponent)
    if scrollComp then
        -- Clamp to valid range
        scrollComp.offset = math.min(savedOffset, scrollComp.maxOffset)
        scrollComp.prevOffset = scrollComp.offset

        -- Apply displacement to children (same as input system does)
        ui.box.TraverseUITreeBottomUp(registry, scrollPane, function(child)
            local go = component_cache.get(child, GameObject)
            if go then
                go.scrollPaneDisplacement = { x = 0, y = -scrollComp.offset }
            end
        end, true)
    end
end
```

#### 1.5 Fix input system stale reference

**Option A (Preferred - Lua side)**: After panel rebuild, briefly move mouse or trigger re-detection.

In `_restoreScrollOffset()`, after restoring offset:
```lua
-- Clear stale activeScrollPane reference by triggering cursor update
-- The input system will detect the new scroll pane on next frame
if input and input.refresh_cursor_collision then
    input.refresh_cursor_collision()
end
```

**Option B (If A not available)**: Expose `inputState.activeScrollPane = entt::null` to Lua so we can clear it.

**File**: `src/systems/input/input_function_bindings.cpp` (if needed)
```cpp
// Add to Lua bindings
lua["input"]["clearActiveScrollPane"] = [&inputState]() {
    inputState.activeScrollPane = entt::null;
};
```

Then call from Lua:
```lua
if input.clearActiveScrollPane then
    input.clearActiveScrollPane()
end
```

### Phase 2: Fix Empty Stats Display

**File**: `assets/scripts/ui/stats_panel.lua`

#### 2.1 Modify `createStatPill()` to handle undefined stats

Current behavior returns `nil` if stat not in DEFS. Change to:

```lua
local function createStatPill(statKey, snapshot, opts)
    opts = opts or {}
    local defs = getStatDefs()
    local def = defs[statKey]

    local value
    if def and def.keys then
        value = snapshot[def.keys[1]]
    elseif def then
        value = snapshot[statKey]
    else
        -- Fallback: try to get value directly from snapshot
        value = snapshot[statKey]
    end

    -- If still nil, use 0 for display
    if value == nil then
        value = 0
    end

    local isZero = type(value) == "number" and math.abs(value) < 0.001
    if isZero and not opts.showZeros then
        return nil  -- Only skip if showZeros is false
    end

    -- Continue with formatting...
    -- For undefined stats, use fallback label/format
    local label = def and getStatLabel(statKey) or formatFallbackLabel(statKey)
    -- ...
end
```

#### 2.2 Add fallback label formatter

```lua
local function formatFallbackLabel(statKey)
    -- Convert "fire_modifier_pct" -> "Fire Modifier"
    local label = statKey
        :gsub("_pct$", "")      -- Remove _pct suffix
        :gsub("_", " ")          -- Underscores to spaces
        :gsub("(%a)([%w]*)", function(first, rest)
            return first:upper() .. rest
        end)
    return label
end
```

#### 2.3 Ensure formatStatValue handles undefined stats

```lua
local function formatStatValue(statKey, value, snapshot, showDelta)
    -- If StatTooltipSystem not available or stat not defined, use fallback
    if StatTooltipSystem and StatTooltipSystem.formatValue then
        local formatted = StatTooltipSystem.formatValue(statKey, value, snapshot, false)
        if formatted then
            -- Add delta if requested...
            return formatted
        end
    end

    -- Fallback formatting
    if type(value) == "number" then
        if statKey:match("_pct$") then
            return string.format("%d%%", math.floor(value + 0.5))
        else
            return tostring(math.floor(value + 0.5))
        end
    end
    return tostring(value or "0")
end
```

### Phase 3: Verify and Test

#### 3.1 Test scroll preservation
- [ ] Open panel, scroll down in Combat tab
- [ ] Switch to Resist tab, scroll down
- [ ] Switch back to Combat tab - should preserve Combat scroll position
- [ ] Switch back to Resist - should preserve Resist scroll position
- [ ] Mouse wheel should work immediately after tab switch (no need to move mouse out and back)

#### 3.2 Test empty stats fix
- [ ] Combat tab shows all Offense + Melee stats (even if 0)
- [ ] Resist tab shows all Defense + Damage Reduction stats
- [ ] Mods tab shows all Elemental + Physical damage mods
- [ ] DoTs tab shows all duration/burn/poison modifiers
- [ ] Utility tab shows all movement/resource/buff/summon/hazard stats

## Files Modified

1. `assets/scripts/ui/stats_panel.lua`
   - Add `tabScrollOffsets` to state
   - Add `_getScrollOffset()` helper
   - Add `_restoreScrollOffset()` helper
   - Modify `_rebuildTabContent()` to save/restore scroll
   - Modify `createStatPill()` for fallback handling
   - Add `formatFallbackLabel()` helper

2. (Optional) `src/systems/input/input_function_bindings.cpp`
   - Add `clearActiveScrollPane` Lua binding if needed

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| `UIScrollComponent` not exposed to Lua | Check if already available; if not, add simple binding |
| Scroll offset exceeds new content height | Clamp to `maxOffset` when restoring |
| Performance impact of traverse on restore | Only traverse if offset > 0 |

## Success Criteria

1. Mouse wheel scrolling works immediately after tab switch
2. Scroll position is preserved per-tab across switches
3. All 5 tabs display stats (no "No stats" message unless genuinely empty)
4. Stats with 0 values display as "0" or "0%" consistently
