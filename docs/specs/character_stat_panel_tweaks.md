# Character Stat Panel Tweaks Spec

## Overview

Improve the character stats panel (`stats_panel_v2.lua`) to fix toggle behavior, add visual consistency with player inventory panel, and enhance readability.

---

## Requirements

### 0. UI Panel Guide Compliance (Mandatory)

This work must follow the UI panel rules in `docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md`:
- Move BOTH the entity Transform and `UIBoxComponent.uiRoot` when showing/hiding.
- Call `ui.box.AddStateTagToUIBox` after initial spawn AND after any `ReplaceChildren`.
- Call `ui.box.RenewAlignment` after any `ReplaceChildren` or child offset changes.
- Add `ScreenSpaceCollisionMarker` to any clickable UI element (tab marker, close button, tabs).

### 1. Toggle Fix (Critical Bug)

**Current Issue:** Pressing 'C' creates a new panel entity each time instead of toggling the existing one.

**Fix:**
- Check for existing panel entity before creation in `StatsPanel.show()`
- If panel exists, simply make it visible (slide in) rather than recreating
- Track panel entity in module state and reuse across toggles

---

### 2. Tab Marker Addition

**Asset:** `character-tab-marker.png` (new sprite needed)

**Position:** Left edge of panel, near top
- Tab "sticks out" from left side when panel is visible
- Tab remains visible when panel is hidden (always visible as entry point)

**Visibility + Positioning Clarification:**
- Create a separate marker entity anchored to the screen edge (not parented to the panel).
- When the panel is visible, update marker X/Y to align with the panel's left edge.
- When hidden, clamp the marker to the screen edge so it remains visible and clickable.

**Behavior:**
- Clickable to toggle panel (same as inventory tab marker pattern)
- Hover state for visual feedback
- Add `ScreenSpaceCollisionMarker` for click detection

---

### 3. UI_SCALE Integration

**Current Issue:** Stats panel uses hardcoded sizes, missing `UI_SCALE` constant that inventory uses.

**Fix:**
- Import and apply `UI_SCALE` to all font sizes
- Apply to padding, margins, and spacing values
- Apply to panel dimensions where appropriate (keep 340px base width, scaled)
- Keep screen anchoring unscaled; clamp panel width if it exceeds viewport

---

### 4. Dotted Line Filler (DSL Addition)

**New DSL Feature:** Add dotted line filler for stat label-to-value spacing.

**Visual:** `Attack Power......125`

**Behavior:**
- Dots scale proportionally with text size
- Fills remaining horizontal space between label and right-aligned value
- Configurable dot character and spacing
- Recompute dot count on layout or resize changes

**Suggested API:**
```lua
dsl.dotFiller({ dot = ".", spacing = 1, minDots = 2 })
```

**Example DSL Usage:**
```lua
dsl.hbox {
    children = {
        dsl.label("Attack Power"),
        dsl.dotFiller(),  -- NEW
        dsl.label("125", { align = "right" })
    }
}
```

---

### 5. Visual Consistency with Inventory

#### Background
- Use same panel sprite/nine-patch as inventory panel
- Match border, shadow, and corner styling

#### Header Bar
- Add header bar with title "Stats" (left-aligned)
- Add close button (X) in top-right corner (same as inventory)
- Header styling matches inventory header

#### Internal Tabs (Combat, Resist, Elements, DoTs, Utility)
- Match inventory tab button sprites/colors
- Same hover and selected states
- Keep 5 tabs, same organization

---

### 6. Animation & Positioning

**Slide Direction:** Keep right-side slide-in (0.3s easeOutQuad)
- Panel slides in from right edge of screen
- Distinct from inventory's bottom-up slide

**Panel Width:** 340px (keep current, apply UI_SCALE)

**Coexistence:** Fully independent from inventory
- Both panels can be open simultaneously
- No automatic repositioning or mutual exclusion

---

### 7. Input Handling

**Toggle Key:** 'C' (via `toggle_stats_panel` action)

**ESC Behavior:** Closes panel in all states (PLANNING, ACTION, SHOP)
- If multiple panels are open, define priority (e.g., close the most recently opened panel first). Document the chosen rule.

**Tab Memory:** Remember last selected internal tab
- Opens to previously viewed tab on next toggle
- Default tab on first open if no previous selection exists
- Persists across hide/show cycles

---

## Technical Implementation Notes

### Files to Modify

1. **`assets/scripts/ui/stats_panel_v2.lua`**
   - Fix toggle/recreation bug
   - Add UI_SCALE integration
   - Add header bar with close button
   - Add tab marker entity and positioning
   - Match internal tab styling to inventory
   - Implement tab memory

2. **`assets/scripts/ui/dsl/` (or equivalent DSL module)**
   - Add `dsl.dotFiller()` element type
   - Implement dot scaling based on parent text size
   - Recompute dots when layout changes

3. **Assets needed:**
   - `character-tab-marker.png` (create or export from Aseprite)
   - Define size, hover/pressed frames (single sprite vs 2-frame anim)
   - Add/verify sprite registration in the asset pipeline if required

### Key Patterns from Inventory to Copy

```lua
-- Tab marker positioning (from player_inventory.lua)
local function getTabMarkerPosition()
    local markerX = state.panelX + TAB_MARKER_OFFSET_X
    local markerY = state.panelY + TAB_MARKER_OFFSET_Y
    return markerX, markerY
end

-- Clickable tab marker definition
local tabDef = dsl.hbox {
    config = {
        canCollide = true,
        hover = true,
        buttonCallback = function()
            StatsPanel.toggle()
        end
    },
    children = {
        dsl.anim("character-tab-marker.png", { w = TAB_MARKER_WIDTH, h = TAB_MARKER_HEIGHT })
    }
}
```

### Toggle Fix Pattern

```lua
-- In StatsPanel.show()
function StatsPanel.show()
    if state.panelEntity and registry:valid(state.panelEntity) then
        -- Panel exists, just make visible
        state.isVisible = true
        -- Trigger slide-in animation
        return
    end

    -- Only create if doesn't exist
    state.panelEntity = createPanelEntity()
    state.isVisible = true
end
```

---

## Out of Scope

- Stat content changes (keep current groupings)
- New stat categories
- Stats panel repositioning/dragging
- Mutual exclusion with other panels

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
