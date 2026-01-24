# Main Menu UI Overhaul Spec

**Created:** 2026-01-24
**Status:** Draft

## Overview

Redesign the main menu to use a minimalist, text-based aesthetic with transparent backgrounds, hover decorator sprites, and full keyboard/gamepad navigation support.

## Current Implementation

The existing main menu (`assets/scripts/core/main.lua:initMainMenu`) uses:
- `UIElementTemplateNodeBuilder` with colored backgrounds (`muted_plum`, `purple_slate`, etc.)
- Emboss effects, shadows, and hover states on button containers
- Discord/Bluesky icons next to text
- 3 decorative "special items" in the center
- Input text field at the bottom
- Tab demo panel on the right (development UI)

## Design Requirements

### Visual Style

| Element | Current | New |
|---------|---------|-----|
| Button backgrounds | Colored panels with emboss | **Transparent/invisible** |
| Button text | 30px with color effects | **36-40px, white (normal), gold (hover)** |
| Icons | Discord/Bluesky icons visible | **Text only, no icons** |
| Hover indicator | Button panel highlight | **Decorator sprites on both sides** |
| Special items | 3 prismatic items in center | **Removed** |
| Input field | Text input at bottom | **Removed** |

### Layout

```
+--------------------------------------------------+
|                                                  |
|              [LOGO - Center Aligned]             |
|                  (subtle bob animation)          |
|                                                  |
|   [Left-aligned menu buttons, ~20% from left]    |
|                                                  |
|   ◆ Start Game ◆                                 |
|   Discord                                        |
|   Bluesky                                        |
|   Language                                       |
|                                                  |
|                              [Tab Demo Panel] →  |
|                                                  |
| [Patch Notes Icon]                [Lang Icon]    |
+--------------------------------------------------+
```

- **Menu X position:** ~20% from left edge of screen
- **Button spacing:** Tight (12-16px vertical gap)
- **Logo:** Centered horizontally, positioned above menu buttons
- **Logo animation:** Subtle bob/float (re-enable existing commented code)

### Hover & Selection Behavior

#### Main Menu Buttons

1. **Normal state:**
   - White text (36-40px font)
   - No background
   - No decorators visible

2. **Hover/Selected state:**
   - Gold text color
   - DynamicMotion effect via `transform.InjectDynamicMotion(entity, intensity, frequency)`
   - Decorator sprites appear instantly on both sides of text
   - Right decorator must be **horizontally flipped**
   - Selection sound plays on hover

3. **Click:**
   - Keep existing click sound (`playSoundEffect("effects", "button-click")`)

#### Keyboard/Gamepad Navigation

- Arrow keys / D-pad navigate between options
- Enter / A button selects
- **Selection indicator:** Same as hover (decorators + gold text + DynamicMotion)
- Must track `selectedIndex` for keyboard navigation state
- Mouse hover should also update `selectedIndex`
- **No wrap:** Up on first / Down on last does nothing
- Hover vs keyboard: mouse hover updates selection immediately; keyboard input also updates selection; last selection persists when the mouse leaves the menu

### Corner Buttons (Language & Patch Notes)

| Property | Value |
|----------|-------|
| Style | Icon-only sprites (no text) |
| Hover effect | Simple scale up (1.15x) |
| Position | Bottom corners (existing positions) — Patch Notes left, Language right |

### Audio

| Event | Sound |
|-------|-------|
| Button click | Keep existing `button-click` |
| Hover/selection change | Add new hover sound |

## Technical Implementation

### New Components/Patterns Needed

1. **Menu Button Entity Structure:**
   ```lua
   -- Each button needs:
   -- - Text entity (white → gold color transition)
   -- - Left decorator sprite (hidden by default)
   -- - Right decorator sprite (hidden by default, horizontally flipped)
   -- - Collision/hover detection
   ```

2. **Keyboard Navigation State:**
   ```lua
   local menuState = {
       selectedIndex = 1,
       buttons = {}, -- array of button entities
       decorators = {}, -- left/right decorator pairs per button
   }
   ```

3. **Decorator Sprite System:**
   - Use any existing sprite as placeholder
   - Must support horizontal flip for right decorator
   - Instant show/hide (no animation)
   - Avoid layout jitter: keep decorator nodes in layout with fixed width; toggle visibility/alpha only

### Layout Math & Scaling
- Use `ui_scale.ui()` for font sizes, spacing, and icon sizes to keep layout consistent across resolutions.
- Suggested values: `FONT=ui_scale.ui(38)`, `GAP=ui_scale.ui(14)`, `DECORATOR_OFFSET=ui_scale.ui(16)`, `ICON=ui_scale.ui(26)`.
- Positioning: `menuX = screenW * 0.20`, `menuY = screenH * 0.50` and left-align the container at that point.

### Files to Modify

1. **`assets/scripts/core/main.lua`**
   - Refactor `initMainMenu()` function
   - Remove: special items, input field, button backgrounds
   - Add: new minimalist button creation
   - Add: keyboard navigation system
   - Add: decorator sprite management
   - Re-enable: logo bob animation (currently commented out)

2. **New module (optional): `assets/scripts/ui/main_menu_buttons.lua`**
   - Encapsulate menu button creation logic
   - Handle hover/selection state
   - Manage decorator visibility

### Decorator Sprite Approach Options

**Option A: Child entities**
- Create decorator sprites as child entities of each button
- Toggle visibility on hover

**Option B: Pooled sprites**
- Single pair of decorator sprites
- Reposition to current hovered button

**Recommended:** Option A for simplicity, as we have only 4-5 buttons.

## Menu Items (Final List)

1. **Start Game** - Transitions to IN_GAME state (existing callback)
2. **Discord** - Opens Discord link (existing callback, remove icon)
3. **Bluesky** - Opens Bluesky link (existing callback, remove icon)
4. **Language** - Cycles language (existing callback, text only now)

Corner icons (separate from main menu list):
- **Patch Notes icon** (bottom-left) - Placeholder sprite
- **Language icon** (bottom-right) - Placeholder sprite

## Implementation Phases

### Phase 1: Core Refactor
- [ ] Remove special items from main menu
- [ ] Remove input text field
- [ ] Remove button background colors (make transparent)
- [ ] Change font size to 36-40px
- [ ] Update text colors (white normal, gold hover)
- [ ] Remove Discord/Bluesky icons

### Phase 2: Decorator System
- [ ] Create decorator sprite entities (left/right per button)
- [ ] Implement show/hide on hover
- [ ] Apply horizontal flip to right decorators
- [ ] Integrate DynamicMotion on hover

### Phase 3: Keyboard Navigation
- [ ] Add navigation state tracking
- [ ] Implement arrow key handlers
- [ ] Implement Enter/A button selection
- [ ] Sync mouse hover with selection state

### Phase 4: Logo & Polish
- [ ] Re-enable logo entity creation
- [ ] Re-enable logo bob animation
- [ ] Add hover sound effect
- [ ] Update corner buttons to icon-only with scale hover

### Phase 5: Layout Tuning
- [ ] Position menu at ~20% from left edge
- [ ] Set button spacing to 12-16px
- [ ] Center logo above menu
- [ ] Test on different resolutions

## Decisions & Defaults

1. **Corner positions:** Keep existing positions (Patch Notes left, Language right).
2. **Hover vs keyboard:** Mouse hover updates selection; keyboard input also updates it; selection persists when mouse leaves.
3. **Navigation wrap:** None (no wrap at ends).
4. **Decorator sprite asset:** Use an existing sprite from `assets/sprites/` (no new art required).
5. **Hover sound:** Use an existing UI hover/selection SFX (no new audio required).
6. **Focus handling:** No special focus arbitration with the Tab demo panel; keep current behavior.
7. **DynamicMotion parameters:** Start with `transform.InjectDynamicMotion(entity, 0.7, 16)` and tune as needed.

## Success Criteria

- [ ] Main menu displays with transparent button backgrounds
- [ ] Hovering shows decorator sprites on both sides
- [ ] Text changes from white to gold on hover
- [ ] DynamicMotion activates on hover
- [ ] Arrow keys navigate between options
- [ ] Enter selects current option
- [ ] Logo floats with subtle animation
- [ ] Click and hover sounds play appropriately
- [ ] Corner icons scale on hover
- [ ] Tab demo panel remains functional
