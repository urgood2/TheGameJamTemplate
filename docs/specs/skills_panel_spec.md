# Skills Panel UI Specification

## Overview

A slide-out panel on the **left edge** of the screen displaying all available skills organized by element. The panel has a **tab marker on the right** that remains visible when the panel is closed, allowing players to click it to open the panel.

---

## Layout Structure

### Panel Position & Behavior
- **Alignment:** Left edge of screen
- **Tab marker:** Sticks out on the RIGHT side of the panel (opposite to panel edge)
- **Dismiss direction:** Slides off LEFT of screen when closed
- **Animation:** Matches inventory panel pattern (snap positioning, not animated slide)
- **Tab visibility:** Always visible on left edge, even when panel closed

### Grid Layout
```
+------------------+----------------+
|  SKILLS PANEL    |  [Tab Marker]  |
|                  |  (icon)        |
|  Skill Points:   |                |
|     5/10         |                |
+------------------+                |
|  Fire | Ice | Lit | Void*        |
|  -----+-----+-----+-------        |
|  [1]  | [1] | [1] | [🔒]         |
|  [2]  | [2] | [2] | [🔒]         |
|  [2]  | [2] | [2] | [🔒]         |
|  [3]  | [3] | [3] | [🔒]         |
|  [3]  | [3] | [3] | [🔒]         |
|  [4]  | [4] | [4] | [🔒]         |
|  [4]  | [4] | [4] | [🔒]         |
|  [5]  | [5] | [5] | [🔒]         |
+------------------+----------------+

* Void column locked for demo
```

### Dimensions
- **Columns:** 4 (Fire, Ice, Lightning, Void)
- **Rows:** 8 (sorted by skill cost: 1→5)
- **Cell size:** Match inventory slot sizing (~48-64px per slot with ui_scale)
- **Demo:** First 3 columns unlocked, 4th column (Void) shows locked sprite

---

## Visual States

### Skill Button States
1. **Unlearned (available):** Normal skill icon, clickable
2. **Learned:** Skill icon + green checkmark overlay
3. **Locked column:** Skill icon replaced with locked sprite
4. **Insufficient points:** Dimmed/grayed appearance (optional visual feedback)

### Header
- Shows "Skill Points: X/Y" (e.g., "Skill Points: 5/10")
- Updates dynamically when skills are learned

### Tab Marker
- Icon-based (similar to inventory tab marker sprite)
- Click to toggle panel open/close
- Always visible regardless of game phase

---

## Interaction Flow

### Opening Panel
1. Click tab marker OR press K key
2. Panel slides in from left edge
3. All skills visible in grid

### Clicking a Skill
1. User clicks an unlocked, unlearned skill
2. **Centered modal popup appears** with:
   - Skill name
   - Skill description
   - Cost in skill points
   - Current skill points remaining
   - **Confirm button** (learns skill if points available)
   - **Cancel/X button** (closes popup)
3. Modal requires explicit Cancel/X click to dismiss (no click-outside dismiss)

### Learning a Skill
1. User clicks Confirm in modal
2. If sufficient points: skill is learned, checkmark appears, points deducted
3. If insufficient points: show error feedback in modal
4. Signal emitted: `skill_learned` (existing signal from skill_system.lua)

### Closing Panel
1. Click tab marker OR press K key OR press ESC
2. Panel slides off left edge
3. Tab marker remains visible

---

## Data Integration

### Skill Data Source
- Primary: `assets/scripts/data/skills.lua` (needs expansion to 32 skills)
- Reference: `/Users/joshuashin/.claude/plans/final-demo-content-spec.md` (Part 5: Skills)

### Current Skills (10) → Needs Expansion to 32
The existing `skills.lua` has 10 skills. Per the demo content spec, we need:
- **Fire (8):** Kindle, Pyrokinesis, Fire Healing, Combustion, Flame Familiar, Roil, Scorch Master, Fire Form
- **Ice (8):** Frostbite, Cryokinesis, Ice Armor, Shatter Synergy, Frost Familiar, Frost Turret, Freeze Master, Ice Form
- **Lightning (8):** Spark, Electrokinesis, Chain Lightning, Surge, Storm Familiar, Amplify Pain, Charge Master, Storm Form
- **Void (8):** Entropy, Necrokinesis, Cursed Flesh, Grave Summon, Doom Mark, Anchor of Doom, Doom Master, Void Form

### Skill System Integration
```lua
local SkillSystem = require("core.skill_system")

-- Check if skill is learned
SkillSystem.has_skill(player, skillId)

-- Learn a skill
SkillSystem.learn_skill(player, skillId)

-- Get all learned skills
SkillSystem.get_learned_skills(player)

-- Get total skills learned
SkillSystem.get_total_skills_learned(player)
```

### Skill Points
- Source: Player state (needs implementation or reference to existing XP/level system)
- Per demo spec: ~10 skill points per run
- Level 2-6 grants +2 points each

---

## Configuration

### Demo Mode
```lua
local SKILLS_PANEL_CONFIG = {
    -- Which element columns are unlocked for demo
    unlocked_elements = { "fire", "ice", "lightning" },
    locked_elements = { "void" },

    -- Locked column sprite
    locked_sprite = "skill-locked.png",

    -- Learned overlay sprite
    learned_overlay = "skill-checkmark.png",
}
```

### Element Lock (DISABLED for demo)
- Per spec: "players pick from 4 elements but are locked to first 3 they invest in"
- For demo: This enforcement is **ignored**
- Future: Can be re-enabled by checking invested elements and graying out 4th

---

## Accessibility

### Hotkey
- **K key** toggles panel open/close
- **ESC key** closes panel if open

### Game Phase Availability
- **Always accessible** (unlike inventory which is PLANNING-phase only)
- Can open during any game phase

---

## File Structure

### New Files
- `assets/scripts/ui/skills_panel.lua` - Main panel module
- `assets/scripts/ui/skill_confirmation_modal.lua` - Centered confirmation popup
- `assets/scripts/ui/skills_tab_marker.lua` - Tab marker on left edge

### Modified Files
- `assets/scripts/data/skills.lua` - Expand from 10 to 32 skills
- `assets/scripts/core/skill_system.lua` - May need skill point tracking

### Asset Requirements
- `skills-panel-background.png` - Panel nine-patch sprite
- `skills-tab-marker.png` - Tab marker icon
- `skill-locked.png` - Locked skill overlay
- `skill-checkmark.png` - Learned skill overlay
- Individual skill icons (32 total, or placeholder set)

---

## Reference Implementation

Base implementation on `player_inventory.lua` patterns:
1. Module-level state
2. DSL-based panel creation
3. setEntityVisible for show/hide
4. Timer group for cleanup
5. Signal handlers for events
6. ui.box.AddStateTagToUIBox after spawn

Key differences from inventory:
- Left-aligned (not centered)
- No grid drag-drop (skills are not items)
- Confirmation modal on click (not immediate action)
- Always accessible (no phase restriction)

---

## Implementation Plan (Pre-Implementation)

### Phase 0: Discovery and Alignment
- Review `assets/scripts/ui/player_inventory.lua` and `docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md` for required UIBox patterns.
- Confirm skill data shape in `assets/scripts/data/skills.lua` and APIs in `assets/scripts/core/skill_system.lua`.
- Validate skill points source and signals: `hero.skill_points` (awarded in `assets/scripts/combat/combat_system.lua`) and `player_level_up` emission in `assets/scripts/core/gameplay.lua`.
- Inventory slot sizing reference: reuse the same `ui_scale` or slot sizing constants as inventory where possible.

### Phase 1: Data Layer Expansion
- Expand `assets/scripts/data/skills.lua` to 32 skills and add consistent fields per entry:
  - `id`, `name`, `description`, `element`, `icon`, `cost` (skill points), `order` (tie-breaker).
  - Optional `tier` or `row` if we want to fix slot placement instead of sorting by cost.
- Add helper functions in `assets/scripts/data/skills.lua` for UI ordering:
  - `getOrderedByElement(element)` returns a cost-sorted list (then `order` or name).
  - `getAllOrdered()` for building the full grid deterministically.
- Keep `Skills.getLocalizedName/Description` for modal text.

### Phase 2: Skill Points Accounting
- Define the points model the UI will use:
  - `total_points = hero.skill_points` (current leveling code adds +3 per level).
  - `spent_points = SkillSystem.get_total_skills_learned(hero)`.
  - `available_points = total_points - spent_points`.
- Add helper API in `assets/scripts/core/skill_system.lua` if needed:
  - `get_skill_points_remaining(player)` and `can_learn_skill(player, skillId)` to centralize checks.
- Document the mismatch between spec (+2 per level 2-6) and current leveling (+3 per level) and decide which source of truth to follow before implementation.

### Phase 3: Skills Panel Module (`assets/scripts/ui/skills_panel.lua`)
- Follow the UI Panel Implementation Guide patterns:
  - Module-level `state` with `initialized`, `isVisible`, `panelEntity`, `gridRoot`, `skillButtons`, `skillPointsText`, `activeModal`, `signalHandlers`, `TIMER_GROUP`.
  - `setEntityVisible` that updates both `Transform` and `UIBoxComponent.uiRoot` for left-aligned show/hide.
  - Spawn offscreen to the left for hidden state (snap move, no tween).
  - `ui.box.AddStateTagToUIBox` after spawn and after any `ReplaceChildren`.
- Layout plan (DSL, no drag/drop):
  - `spritePanel` background (left-aligned panel).
  - Header row with `Skill Points: X/Y`.
  - Column headers for Fire/Ice/Lightning/Void.
  - 4 columns x 8 rows of `spriteButton` slots sized to inventory slots, built from skill data.
  - Store `skillId -> buttonEntity` map for visual state updates.
- Visual state rules:
  - Learned: overlay checkmark (decoration or child sprite) and disable click.
  - Locked column: replace icon with `locked_sprite`, disable click.
  - Insufficient points: disabled/dim appearance (use disabled sprite state or tint).

### Phase 4: Tab Marker Module (`assets/scripts/ui/skills_tab_marker.lua`)
- Separate UI entity that always stays visible.
- On panel open, move marker to `panelX + panelWidth - markerOverlap` so it appears attached to the panel edge.
- On panel closed, move marker to the left screen edge (still clickable).
- Clicking marker toggles `SkillsPanel.toggle()`.

### Phase 5: Confirmation Modal (`assets/scripts/ui/skill_confirmation_modal.lua`)
- Centered modal with:
  - Skill name, description, cost, and current points.
  - Confirm and Cancel buttons; no click-outside dismiss.
- Behavior:
  - Confirm emits `skill_learn_requested`, checks points, calls `SkillSystem.learn_skill`.
  - If insufficient points, show inline error text in modal.
  - Block panel toggle hotkeys while modal is open.

### Phase 6: Input and Signals
- Keyboard:
  - `K` toggles panel (if no modal).
  - `ESC` closes panel (if no modal).
- Signals:
  - Listen: `skill_learned`, `skill_unlearned`, `player_level_up` to refresh UI.
  - Emit: `skills_panel_opened`, `skills_panel_closed`, `skill_learn_requested`.

### Phase 7: Validation and Cleanup
- Ensure `ui.box.RenewAlignment` after dynamic layout changes.
- Kill timers via `timer.kill_group(TIMER_GROUP)` on destroy.
- Remove signal handlers to avoid leaks.
- Verify tab marker remains clickable when panel is hidden.

### Open Decisions
- Finalize skill point progression to match demo spec vs current leveling.
- Confirm icon naming and availability for all 32 skills.
- Decide if skill costs are uniform or vary by tier (affects sorting and row placement).

---

## Signals

### Emitted
- `skills_panel_opened` - Panel opened
- `skills_panel_closed` - Panel closed
- `skill_learn_requested` - User clicked Confirm (before learning)

### Listened
- `skill_learned` - Update checkmark overlay when skill learned
- `skill_unlearned` - Remove checkmark if skill unlearned
- `player_level_up` - Update skill points display

---

## Approval Checklist

- [ ] Panel layout (4 columns × 8 rows)
- [ ] Tab marker on right side of left-aligned panel
- [ ] 3 columns unlocked, 1 locked for demo
- [ ] Checkmark overlay for learned skills
- [ ] Centered modal confirmation popup
- [ ] Skill Points display in header
- [ ] K key hotkey
- [ ] Always accessible (any game phase)
- [ ] Explicit Cancel to dismiss modal
- [ ] Snap animation (match inventory)

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
