# Logging Console Improvements Design

**Date:** 2025-12-16
**Status:** Approved
**Branch:** `feature/logging-improvements`

## Overview

Improve the ImGui console to support checkbox-based filtering by system/subsystem, plus developer productivity features like clickable entity IDs, bookmarks, and log export.

## Goals

1. Reduce log noise by filtering per system/subsystem
2. Speed up debugging with clickable entity inspection
3. Improve workflow with bookmarks and export

## Logging API

### Lua API

New tag-based functions for all log levels:

```lua
-- Tag-based logging (recommended)
log_debug("physics", "Body created for entity", entity)
log_info("combat", "Projectile spawned")
log_warn("ai", "Pathfinding fallback used")
log_error("ui", "Failed to load sprite")

-- Backward compatible: no tag defaults to "general"
log_debug("Simple message")  -- tagged as [general]
log_info("Another message")  -- tagged as [general]
```

### Predefined Tags

Official tags with persistent checkboxes:

| Tag | Covers |
|-----|--------|
| `physics` | Collision, bodies, sync |
| `combat` | Projectiles, damage, cards, jokers |
| `ai` | Enemy behavior, pathfinding |
| `ui` | Layouts, tooltips, DSL |
| `input` | Controller, mouse, keyboard |
| `audio` | Sound effects, music |
| `scripting` | Lua VM, hot-reload |
| `render` | Shaders, layers, draw commands |
| `entity` | Creation, destruction, components |

Unknown tags work but appear in dynamic "Other" filter section.

### C++ Changes

Extend `csys::Item` to store tag:

```cpp
struct Item {
    ItemType m_Type;      // ERROR, WARNING, INFO, etc.
    std::string m_Tag;    // "physics", "combat", etc. (NEW)
    std::string m_Text;
    int64_t m_TimeStamp;
    // ... existing fields
};
```

New logging wrapper:

```cpp
void luaLogWithTag(spdlog::level::level_enum level,
                   const std::string& tag,
                   const std::string& message);
```

## Filter UI

### Layout

```
┌─ Console ──────────────────────────────────────────┐
│ [▼ Filters]                                        │
│ ┌────────────────────────────────────────────────┐ │
│ │ Levels: [✓Error][✓Warn][✓Info][✓Debug]         │ │
│ │ Systems: [✓physics][✓combat][✓ai][✓ui]         │ │
│ │          [✓input][✓audio][✓scripting][✓render] │ │
│ │          [✓entity]                             │ │
│ │ Other:   [✓my_prototype][✓temp_debug]          │ │
│ │                        [All] [None] [Invert]   │ │
│ └────────────────────────────────────────────────┘ │
│ Filter: [_______________]                          │
│ ──────────────────────────────────────────────────│
│ [physics] Body created for entity 42              │
│ [combat] Projectile spawned                       │
│ [my_prototype] Testing new feature                │
│                                                    │
│ > _                                                │
└────────────────────────────────────────────────────┘
```

### Behavior

- Collapsible header (collapsed by default)
- Checkboxes persist across sessions (saved to imgui.ini)
- "Other" section auto-populates when unknown tags appear
- `[All]` / `[None]` / `[Invert]` buttons for quick toggling
- Message shows only if **both** level AND tag checkboxes are checked
- Text filter still works on top of checkbox filters

## Clickable Entity IDs

### Detection

Regex scan log messages for entity patterns:
- `entity 42`
- `eid:42`
- `[42]`
- Bare numbers after keywords like "spawned", "destroyed", "entity"

Detected IDs rendered as clickable links (underlined, accent color).

### Click Behaviors

| Action | Result |
|--------|--------|
| **Click** | Print entity summary to console |
| **Ctrl+Click** | Open inspector popup with full component tree |
| **Shift+Click** | Highlight entity in-game (flash outline 1-2 sec) |

### Console Output (Click)

```
[inspector] Entity 42:
  Transform: (150, 200) 32x32 z=5
  Tag: "enemy"
  Script: { health=80, faction="goblin", state="patrol" }
```

### Inspector Popup (Ctrl+Click)

- ImGui window titled "Entity 42"
- Collapsible tree: Transform, Physics, Script Table, Animation, etc.
- Live-updating values (refreshes each frame while open)
- "Copy" button to copy entity state as Lua table

## Bookmarks

| Feature | Implementation |
|---------|----------------|
| Add bookmark | Right-click log line → "Bookmark" (or Ctrl+B) |
| Visual indicator | Yellow star icon in left margin |
| Navigation | `[◀ Prev]` `[Next ▶]` buttons, or Ctrl+Up/Down |
| Clear | "Clear Bookmarks" in right-click menu |
| Persistence | Cleared on console clear (not saved across sessions) |

## Export/Copy

| Feature | Implementation |
|---------|----------------|
| Copy filtered | Toolbar button `[📋 Copy]` - copies visible logs to clipboard |
| Format | Plain text: `[12:34:56] [physics] Message here` |
| Copy single line | Right-click → "Copy line" |
| Copy selection | Shift+Click to select range, then copy |

## Files to Modify

| File | Changes |
|------|---------|
| `src/third_party/imgui_console/imgui_console.cpp` | Filter UI, bookmarks, clickable IDs, export |
| `src/third_party/imgui_console/imgui_console.h` | Filter state, bookmark storage |
| `src/third_party/imgui_console/csys/item.h` | Add `m_Tag` field |
| `src/third_party/imgui_console/csys_console_sink.cpp` | Pass tag through spdlog |
| `src/systems/scripting/scripting_functions.cpp` | New Lua bindings |
| `assets/scripts/chugget_code_definitions.lua` | LuaLS annotations |

## New Files

| File | Purpose |
|------|---------|
| `src/systems/ui/entity_inspector.cpp/.h` | Inspector popup (optional, could inline) |

## Implementation Priority

| Priority | Features |
|----------|----------|
| **Core** | Tag-based API, level checkboxes, system checkboxes, persistence |
| **Enhancement** | Clickable entity IDs, inspector popup, in-game highlight |
| **Enhancement** | Bookmarks with navigation |
| **Enhancement** | Copy filtered logs |

## Non-Goals

- Log persistence across sessions (file-based history)
- Remote logging / log server
- Log rotation / size limits

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
