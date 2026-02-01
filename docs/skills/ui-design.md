# /ui-design Command

**Description**: Design game UI with mockups, review loops, and implementation specs

**Scope**: project

---

## Command Instructions

# UI Design Workflow

Design game UI through visual mockups and structured specifications.

## Sub-Commands

### `/ui-design mockup <description>`
Generate an HTML mockup and present for review.

**Process:**
1. Parse the UI description
2. Generate HTML/CSS mockup matching game style (dark theme, Resurrect 64 palette)
3. Render via Playwright → screenshot
4. Present in review webgui
5. Iterate based on feedback until approved
6. Save approved mockup to `docs/ui-specs/mockups/<name>.png`

**Example:**
```
/ui-design mockup "A settings panel with audio/video/controls tabs, each with sliders and toggles"
```

### `/ui-design spec <name>`
Generate implementation spec from an approved mockup or description.

**Process:**
1. If mockup exists at `docs/ui-specs/mockups/<name>.png`, reference it
2. Otherwise, ask for description or generate mockup first
3. Analyze requirements and map to DSL components
4. Generate spec file at `docs/ui-specs/<name>.md`
5. Present spec in review webgui for approval

**Example:**
```
/ui-design spec settings-panel
```

### `/ui-design full <description>`
Complete workflow: mockup → review → spec → review.

**Process:**
1. Generate mockup from description
2. Review loop until mockup approved
3. Generate spec with component mapping
4. Review loop until spec approved
5. Output final spec file

**Example:**
```
/ui-design full "Inventory grid with 4 tabs: Equipment, Wands, Triggers, Actions. Drag-drop slots, hover tooltips, sort/filter."
```

---

## Mockup Style Guide

Generated HTML mockups should match the game's visual style:

### Colors (Resurrect 64 Palette)
| Name | Hex | Use |
|------|-----|-----|
| blackberry | #1a1a2e | Panel backgrounds |
| dark_lavender | #2d2d4a | Headers, borders |
| purple_slate | #3a3a5a | Secondary panels |
| gold | #ffd700 | Titles, highlights |
| muted_plum | #6a5a8a | Buttons |
| deep_teal | #2a4a4a | Accent panels |
| jade_green | #3a6a3a | Success/confirm buttons |
| darkred | #8b0000 | Close/cancel buttons |

### Typography
- Titles: 18-24px, gold, text-shadow
- Body: 12-14px, white/lightgray
- Labels: 10-11px, gray
- Font: System UI or pixel-style fallback

### Component Styling
- Embossed panels (2-3px depth effect)
- Rounded corners (6-12px)
- Nine-patch sprite panels where possible
- Tab bars with icon + label
- Grid slots with hover states (border highlight, slight lift)
- Tooltips with stat tables and colored values

### Element Colors by Type
| Element | Background Gradient | Border |
|---------|---------------------|--------|
| Fire | #8b2a2a → #5a1a1a | #ff6b6b |
| Ice | #2a4a8b → #1a2a5a | #6bcfff |
| Lightning | #8b8b2a → #5a5a1a | #ffff6b |
| Arcane | #6a2a8b → #4a1a5a | #cf6bff |
| Neutral | #4a3a6a → #3a2a5a | #6a5a8a |

---

## Spec File Template

Location: `docs/ui-specs/<ui-name>.md`

```markdown
# [UI Name] Specification

**Status**: Draft | Approved
**Created**: [date]

## Overview
[Brief description]

## Visual Mockup
![Mockup](./mockups/<name>.png)

## Layout Structure
[Container hierarchy using dsl.* notation]

## Components Used
| Component | Purpose | Config |
|-----------|---------|--------|

## Interactive Behavior
[User interactions table]

## Data Bindings
[Dynamic content sources]

## Shaders/Effects
[Visual effects if any]

## Implementation Checklist
- [ ] Task 1
- [ ] Task 2

## Open Questions
[Unresolved decisions]

## Implementation Notes
[Gotchas, tips, references]
```

---

## Key DSL Components Reference

Quick reference for component mapping:

### Containers
| UI Need | DSL Component | Key Config |
|---------|---------------|------------|
| Root panel | `dsl.root` | `color`, `padding`, `emboss` |
| Nine-patch panel | `dsl.spritePanel` | `sprite`, `borders`, `decorations` |
| Vertical stack | `dsl.vbox` | `spacing`, `padding` |
| Horizontal stack | `dsl.hbox` | `spacing`, `padding` |
| Titled section | `dsl.section` | `title`, `collapsed` |

### Interactive
| UI Need | DSL Component | Key Config |
|---------|---------------|------------|
| Tab system | `dsl.tabs` | `tabs[]`, `activeTab`, `contentMinHeight` |
| Item grid | `dsl.inventoryGrid` | `rows`, `cols`, `slotSize`, `slotGap` |
| Button | `dsl.button` | `onClick`, `color`, `hover` |
| Sprite button | `dsl.spriteButton` | `states{}`, `borders`, `label` |
| Progress bar | `dsl.progressBar` | `getValue`, `emptyColor`, `fullColor` |

### Content
| UI Need | DSL Component | Key Config |
|---------|---------------|------------|
| Static text | `dsl.text` | `fontSize`, `color`, `shadow` |
| Dynamic text | `dsl.dynamicText` | `fn()`, `fontSize`, `effect` |
| Rich text | `dsl.richText` | Supports `[text](color=red)` markup |
| Animated sprite | `dsl.anim` | `id`, `w`, `h`, `isAnimation` |
| Icon + label | `dsl.iconLabel` | `icon`, `text` |

### Layout Helpers
| UI Need | DSL Component | Key Config |
|---------|---------------|------------|
| Empty space | `dsl.spacer` | `width`, `height` |
| Line divider | `dsl.divider` | `direction`, `color`, `thickness` |
| Conditional | `dsl.when` | `condition`, `node` |
| Data list | `dsl.list` | `data`, `mapperFn` |
| Uniform grid | `dsl.grid` | `rows`, `cols`, `genFn` |

---

## Dependencies

- **Playwright MCP**: For browser rendering and screenshots
- **Review webgui**: `~/.claude-review/` for approval loops
- **UI DSL**: `assets/scripts/ui/ui_syntax_sugar.lua`
- **Sprite assets**: `assets/sprites/ui/` for panel backgrounds

---

## Example Workflow Session

```
User: /ui-design full "Character stats panel showing HP, MP, and equipment slots"

Claude: 
1. Generating HTML mockup...
2. [Opens browser, renders, takes screenshot]
3. [Presents in review webgui]

User: [Reviews, requests changes: "Make HP bar red, MP bar blue"]

Claude:
1. Updating mockup...
2. [Re-renders, new screenshot]
3. [Presents updated mockup]

User: [Approves]

Claude:
1. Generating spec file...
2. [Creates docs/ui-specs/character-stats-panel.md]
3. [Presents spec in review webgui]

User: [Approves]

Claude:
Done! Created:
- docs/ui-specs/mockups/character-stats-panel.png
- docs/ui-specs/character-stats-panel.md
```

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
