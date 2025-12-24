# Save System Design

**Date:** 2025-12-24
**Status:** Approved

## Overview

A robust, performant, and extensible saving system for roguelike meta-progression. Runs are ephemeral, but unlock progress (avatars, discoveries, achievements) persists between runs.

## Key Decisions

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| Save model | Roguelike meta-progression | Runs ephemeral, unlocks persist |
| Profiles | Single profile | Simple; architecture supports slots later |
| Timing | Auto-save on change | Most robust against crashes |
| Logic owner | Lua-primary | Game state lives in Lua; easier to extend |
| Versioning | Sequential migrations | Handles any schema evolution |
| Corruption | Atomic writes + backup | Bulletproof reliability |
| Threading | Async (queue-based) | No main thread blocking or jitter |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        SAVE SYSTEM                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐   │
│  │   Gameplay   │───▶│ SaveManager  │───▶│  C++ File I/O    │   │
│  │    (Lua)     │    │    (Lua)     │    │   (Bindings)     │   │
│  └──────────────┘    └──────────────┘    └──────────────────┘   │
│         │                   │                     │              │
│         │                   ▼                     ▼              │
│         │           ┌──────────────┐      ┌─────────────┐       │
│         │           │  Migrations  │      │  saves/     │       │
│         └──────────▶│   (Lua)      │      │  profile.json│      │
│      Collectors     └──────────────┘      │  profile.bak │      │
│                                           └─────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

### Components

1. **SaveManager** (`core/save_manager.lua`) - Central API for save/load operations
2. **Collectors** - Each system registers functions to collect/distribute its saveable state
3. **Migrations** (`core/save_migrations.lua`) - Version-indexed transformation functions
4. **C++ Bindings** - Minimal layer for file I/O with platform-specific async handling

## Async Save Architecture

### Desktop (Native)

```
Main Thread                    Save Thread
     │                              │
     │  queue_save(data) ──────────▶│
     │                              │ JSON encode
     │                              │ Write temp file
     │                              │ Atomic rename
     │                              │ Copy backup
     │◀─────── signal complete ─────│
```

### Web (Emscripten)

```
Main Thread
     │
     │  Write to MEMFS (sync, fast ~1ms)
     │  FS.syncfs(false, callback)  ──▶  IndexedDB (async)
     │  Continue immediately             Persists in background
```

Write to MEMFS is instant; `FS.syncfs()` persists asynchronously. Game never blocks.

## Save Data Schema

**File:** `saves/profile.json`

```json
{
  "version": 1,
  "saved_at": "2025-12-24T10:30:00Z",

  "avatars": {
    "unlocked": ["warrior", "mage", "rogue"],
    "equipped": "mage",
    "progress": {
      "kills_with_fire": 142,
      "damage_blocked": 8500,
      "distance_moved": 12000
    }
  },

  "discoveries": {
    "tags": ["Fire", "Ice", "Projectile"],
    "spell_types": ["fireball", "frost_nova"],
    "patterns": ["double_cast"]
  },

  "unlocks": {
    "jokers": ["lucky_coin", "glass_cannon"],
    "cards": ["FIREBALL_2", "CHAIN_LIGHTNING"]
  },

  "statistics": {
    "runs_completed": 47,
    "highest_wave": 23,
    "total_kills": 3842,
    "total_gold_earned": 125000,
    "playtime_seconds": 72000
  },

  "settings": {
    "master_volume": 0.8,
    "sfx_volume": 1.0,
    "music_volume": 0.6
  }
}
```

**Estimated size:** ~6KB

## Collector Pattern

Systems register how to save/load their data:

```lua
-- In avatar_system.lua
SaveManager.register("avatars", {
    collect = function()
        return {
            unlocked = player.avatar_state.unlocked,
            equipped = player.avatar_state.equipped,
            progress = player.avatar_progress
        }
    end,

    distribute = function(data)
        player.avatar_state.unlocked = data.unlocked or {}
        player.avatar_state.equipped = data.equipped or "warrior"
        player.avatar_progress = data.progress or {}
    end
})
```

**Benefits:**
- Systems own their save logic (no central "god file")
- Adding new save data = one `register()` call
- Easy to test each collector in isolation

## Migration System

Sequential migrations transform old saves to current format:

```lua
local migrations = {}

-- Version 1 → 2: Added statistics tracking
migrations[2] = function(data)
    data.statistics = data.statistics or {
        runs_completed = 0,
        highest_wave = 0,
        total_kills = 0
    }
    return data
end

-- Version 2 → 3: Renamed field
migrations[3] = function(data)
    if data.unlocked_jokers then
        data.unlocks = data.unlocks or {}
        data.unlocks.jokers = data.unlocked_jokers
        data.unlocked_jokers = nil
    end
    return data
end

return migrations
```

**Migration runner:**

```lua
local function migrate(data)
    local save_version = data.version or 1

    while save_version < SAVE_VERSION do
        local next_version = save_version + 1
        if migrations[next_version] then
            data = migrations[next_version](data)
            data.version = next_version
        end
        save_version = next_version
    end

    return data
end
```

After migration, save immediately so next load skips re-migration.

## Clash Prevention

### Rapid Saves (Race Conditions)

Queue-based serialization ensures latest state always wins:

```lua
function SaveManager.save_async(callback)
    local data = SaveManager.collect_all()

    if SaveManager.save_in_progress then
        SaveManager.pending_save = { data = data, callback = callback }
        return
    end

    SaveManager.save_in_progress = true

    file_io.save_async(SAVE_PATH, json.encode(data), function(success)
        SaveManager.save_in_progress = false
        if callback then callback(success) end

        if SaveManager.pending_save then
            local queued = SaveManager.pending_save
            SaveManager.pending_save = nil
            SaveManager.save_async(queued.callback)
        end
    end)
end
```

### Power Loss / Corruption

Atomic writes with backup:

```cpp
bool write_atomic(path, content) {
    write_file(path + ".tmp", content)  // Crash here = temp garbage, main safe
    sync(path + ".tmp")                 // Flush to disk
    rename(path + ".tmp", path)         // Atomic operation
    copy(path, path + ".bak")           // Backup after success
}
```

## C++ Bindings

Minimal platform-aware layer:

```cpp
namespace save_io {

// Synchronous (for load)
std::optional<std::string> load_file(const std::string& path);
bool file_exists(const std::string& path);

// Asynchronous (for save)
void save_file_async(const std::string& path,
                     const std::string& content,
                     sol::function on_complete);

void register_lua_bindings(sol::state& lua);

}
```

## Lua API

```lua
local SaveManager = {}

-- Called once at game startup
function SaveManager.init()

-- Register a collector (called by each system)
function SaveManager.register(key, collector)

-- Trigger a save (call after meta-progression change)
function SaveManager.save(callback)

-- Check if data exists (for "Continue" button)
function SaveManager.has_save()

-- Delete all progress (for "New Game")
function SaveManager.delete_save()

-- Get specific data without full load (for UI)
function SaveManager.peek(key)

return SaveManager
```

**Gameplay usage:**

```lua
function unlock_avatar(avatar_id)
    player.avatar_state.unlocked[avatar_id] = true
    signal.emit("avatar_unlocked", avatar_id)
    SaveManager.save()  -- One line!
end
```

## Error Handling

```lua
function SaveManager.load()
    local content = file_io.load_file(SAVE_PATH)

    if content then
        local success, data = pcall(json.decode, content)
        if success and data then
            return SaveManager.apply_save(data)
        end
    end

    -- Try backup
    local backup = file_io.load_file(BACKUP_PATH)
    if backup then
        local success, data = pcall(json.decode, backup)
        if success and data then
            SaveManager.apply_save(data)
            SaveManager.save()  -- Repair main save
            return
        end
    end

    -- Fresh start
    SaveManager.create_new()
end
```

**Principle:** Never block gameplay. Never show scary errors. Log everything, recover silently.

## File Structure

```
src/systems/save/
├── save_file_io.hpp          # C++ header
└── save_file_io.cpp          # C++ implementation

assets/scripts/core/
├── save_manager.lua          # Main API (~150 lines)
└── save_migrations.lua       # Migrations (~50 lines)

saves/                        # Created at runtime
├── profile.json              # Main save
├── profile.json.bak          # Backup
└── profile.json.tmp          # Temp (deleted after rename)
```

## Initialization Flow

```lua
function main.init()
    SaveManager.init()

    -- Systems register collectors on require
    require("wand.avatar_system")
    require("wand.discovery_journal")
    require("wand.joker_system")
    require("core.statistics")

    -- Load and distribute
    SaveManager.load()
end
```

## Implementation Estimate

| Component | Lines |
|-----------|-------|
| C++ layer | ~100 |
| Lua SaveManager | ~150 |
| Migrations | ~20 (grows) |
| System integrations | ~10 each |
| **Total** | **~400** |
