# Patch Notes Modal Spec

> Display patch notes in a modal overlay accessible from the main menu.

## Overview

A simple, localized patch notes system that shows the current version's changes in a modal overlay. Players access it via a corner icon on the main menu, with a red notification dot indicating unread notes.

---

## Data Architecture

### Source Format
- **Bundled with build** - Patch notes are static JSON files shipped with each release
- **Separate file per locale** - e.g., `assets/localization/patch_notes_en_us.json`, `assets/localization/patch_notes_ko_kr.json`
- **Current version only** - No historical patch notes, just the current release

### JSON Structure

```json
{
  "version": "0.9.2",
  "date": "2026-01-02",
  "title": "Patch Notes",
  "content": "- Added new card: Inferno Blast\n- Fixed bug where enemies would clip through walls\n- Balanced mana costs for Fire spells\n- Improved performance on web builds"
}
```

### Fallback Behavior
- If locale-specific patch notes file is missing, **fall back to English** (`patch_notes_en_us.json`)
- Log a warning for missing localization to aid debugging

### Read State Persistence
- **Stored in save file** - Track `last_read_patch_version` string
- Compare against current `version` field to determine if badge should show
- Cleared when modal is opened (not when closed)

---

## Entry Point

### Icon Button
- **Position**: Bottom-left corner of main menu
- **Asset**: Use existing sprite (scroll/document icon from asset library)
- **Behavior**: Opens modal on click

### Notification Badge
- **Style**: Red dot overlapping the icon (standard notification indicator)
- **Visibility**: Shows when `last_read_patch_version ~= current_version`
- **Clears**: When modal is opened (immediately, not on close)

---

## Modal Design

### Layout
```
┌─────────────────────────────────────────┐
│                                    [✕]  │  ← Red X close button (top-right)
│                                         │
│         📜 Patch Notes                  │  ← Localized title
│         Version 0.9.2                   │  ← Version string
│         January 2, 2026                 │  ← Formatted date
│  ───────────────────────────────────    │
│                                         │
│  - Added new card: Inferno Blast        │  ← Plain text content
│  - Fixed bug where enemies would...     │     (scrollable)
│  - Balanced mana costs for Fire...      │
│  - Improved performance on web...       │
│                                         │  ← Standard scrollbar
│                                         │     on right edge
└─────────────────────────────────────────┘
```

### Visual Specifications
- **Size**: Fixed dimensions (e.g., 500x400 px - adjust based on UI scale)
- **Background**: Dimmed overlay behind modal (semi-transparent black)
- **Close button**: Red X in top-right corner (matches common "cancel/close" color convention)
- **Animation**: None (instant open/close)
- **Scrollbar**: Standard scrollbar on right side for overflow content

### Header Elements
1. **Title**: Localized "Patch Notes" text (add to localization files)
2. **Version**: Display version string from JSON (e.g., "Version 0.9.2")
3. **Date**: Formatted release date from JSON

### Content Area
- **Format**: Plain text only (no inline icons or rich formatting)
- **Scroll**: Vertical scroll with standard scrollbar when content overflows
- **Text style**: Match existing UI text styling

---

## Dismissal Behavior

Modal closes via any of:
1. **X button** - Close button in top-right corner
2. **Click outside** - Clicking the dimmed background area
3. **ESC key** - Keyboard escape key

---

## Auto-Open Behavior

- **Never auto-opens** - Badge draws attention, player chooses to open
- Modal only appears when player explicitly clicks the icon

---

## Localization Requirements

### New Localization Keys
Add to `en_us.json` and `ko_kr.json`:

```json
{
  "ui": {
    "patch_notes_title": "Patch Notes",
    "patch_notes_version": "Version %s",
    "patch_notes_date": "%s"
  }
}
```

### Patch Notes Files
Create new files:
- `assets/localization/patch_notes_en_us.json`
- `assets/localization/patch_notes_ko_kr.json`

---

## Implementation Notes

### UI System Integration
Use the existing UI DSL (`ui.ui_syntax_sugar`) for modal construction:

```lua
local dsl = require("ui.ui_syntax_sugar")

local patchNotesModal = dsl.root {
    config = { ... },
    children = {
        dsl.vbox {
            children = {
                -- Close button
                -- Title
                -- Version + date header
                -- Scrollable content area
            }
        }
    }
}
```

### Signal Events
- `signal.emit("patch_notes_opened")` - When modal opens
- `signal.emit("patch_notes_closed")` - When modal closes

### Save Integration
```lua
-- Check if unread
local function hasUnreadPatchNotes()
    local currentVersion = patchNotes.version
    local lastRead = save_manager.get("last_read_patch_version", "")
    return currentVersion ~= lastRead
end

-- Mark as read
local function markPatchNotesRead()
    save_manager.set("last_read_patch_version", patchNotes.version)
end
```

---

## File Checklist

New files to create:
- [ ] `assets/localization/patch_notes_en_us.json`
- [ ] `assets/localization/patch_notes_ko_kr.json`
- [ ] `assets/scripts/ui/patch_notes_modal.lua`

Files to modify:
- [ ] `assets/localization/en_us.json` - Add UI keys
- [ ] `assets/localization/ko_kr.json` - Add UI keys
- [ ] `assets/scripts/ui/main_menu.lua` - Add icon button
- [ ] Save system - Add `last_read_patch_version` field

---

## Open Questions

None - spec is complete.

---

## Summary

| Aspect | Decision |
|--------|----------|
| Data source | Bundled JSON per locale |
| Version history | Current only |
| Entry point | Bottom-left corner icon |
| Badge style | Red dot until opened |
| Modal type | Centered overlay with dim |
| Modal size | Fixed dimensions |
| Content format | Plain text, simple scroll |
| Scrollbar | Standard right-side scrollbar |
| Animation | None (instant) |
| Dismissal | X button, click outside, ESC |
| Auto-open | Never |
| Localization | Yes (title + content) |
| Locale fallback | English |
| Read state | Save file |
