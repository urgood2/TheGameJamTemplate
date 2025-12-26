# Avatar Proc Effects Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement proc effects that trigger on gameplay events (kills, casts, movement) and execute effects (heal, barrier, poison).

**Architecture:** Two registries (TRIGGER_HANDLERS for "when", PROC_EFFECTS for "what") connected by execute_effect(). Signal handlers managed via signal_group for automatic cleanup on unequip.

**Tech Stack:** Lua, hump.signal, signal_group.lua, avatar_system.lua

---

### Task 1: Add PROC_EFFECTS Registry

**Files:**
- Modify: `assets/scripts/wand/avatar_system.lua:25-30` (after loadDefs)

**Step 1: Add effect registry table**

Add after `local avatarDefs = nil` (line 25):

```lua
--[[
================================================================================
PROC EFFECTS REGISTRY
================================================================================
Maps effect names to execution functions. Each receives (player, effect).
]]--

local PROC_EFFECTS = {
    --- Heal the player for flat HP
    --- @param player table Player script table
    --- @param effect table Effect definition with .value
    heal = function(player, effect)
        local combatActor = player.combatTable
        if combatActor and combatActor.heal then
            combatActor:heal(effect.value or 0)
        end
    end,

    --- Apply barrier as % of max HP
    --- @param player table Player script table
    --- @param effect table Effect definition with .value (percentage)
    global_barrier = function(player, effect)
        local combatActor = player.combatTable
        if combatActor and combatActor.stats and combatActor.addBarrier then
            local maxHp = combatActor.stats:get("max_hp") or 100
            local barrier = math.floor(maxHp * ((effect.value or 0) / 100))
            combatActor:addBarrier(barrier)
        end
    end,

    --- Spread poison in radius around player
    --- @param player table Player script table
    --- @param effect table Effect definition with .radius
    poison_spread = function(player, effect)
        -- TODO: Implement when poison system is ready
        -- For now, just log that it would trigger
        print(string.format("[AvatarProc] poison_spread triggered, radius=%d", effect.radius or 5))
    end,
}
```

**Step 2: Commit**

```bash
git add assets/scripts/wand/avatar_system.lua
git commit -m "feat(avatars): add PROC_EFFECTS registry for heal, barrier, poison"
```

---

### Task 2: Add execute_effect Helper

**Files:**
- Modify: `assets/scripts/wand/avatar_system.lua` (after PROC_EFFECTS)

**Step 1: Add execute_effect function**

Add after the PROC_EFFECTS table:

```lua
--- Execute a proc effect by name
--- @param player table Player script table
--- @param effect table Effect definition with .effect field
local function execute_effect(player, effect)
    if not effect or not effect.effect then return end

    local handler = PROC_EFFECTS[effect.effect]
    if handler then
        handler(player, effect)
    else
        print(string.format("[AvatarSystem] Unknown proc effect: %s", tostring(effect.effect)))
    end
end
```

**Step 2: Commit**

```bash
git add assets/scripts/wand/avatar_system.lua
git commit -m "feat(avatars): add execute_effect helper function"
```

---

### Task 3: Add TRIGGER_HANDLERS Registry

**Files:**
- Modify: `assets/scripts/wand/avatar_system.lua` (after execute_effect)

**Step 1: Add trigger handlers table**

```lua
--[[
================================================================================
TRIGGER HANDLERS REGISTRY
================================================================================
Maps trigger types to signal registration logic. Each receives (handlers, player, effect).
State (counters, accumulators) lives in closures - cleaned up with signal_group.
]]--

local TRIGGER_HANDLERS = {
    --- Trigger on enemy kill
    --- @param handlers SignalGroup Signal group for cleanup
    --- @param player table Player script table
    --- @param effect table Effect definition
    on_kill = function(handlers, player, effect)
        handlers:on("enemy_killed", function(enemyEntity)
            execute_effect(player, effect)
        end)
    end,

    --- Trigger every 4th spell cast
    --- @param handlers SignalGroup Signal group for cleanup
    --- @param player table Player script table
    --- @param effect table Effect definition
    on_cast_4th = function(handlers, player, effect)
        local count = 0
        handlers:on("on_spell_cast", function(castData)
            count = count + 1
            if count % 4 == 0 then
                execute_effect(player, effect)
            end
        end)
    end,

    --- Trigger every 5 meters moved
    --- @param handlers SignalGroup Signal group for cleanup
    --- @param player table Player script table
    --- @param effect table Effect definition
    distance_moved_5m = function(handlers, player, effect)
        local accumulated = 0
        local THRESHOLD = 80  -- ~5 meters in pixels (16px per unit)
        handlers:on("player_moved", function(data)
            accumulated = accumulated + (data.delta or 0)
            while accumulated >= THRESHOLD do
                accumulated = accumulated - THRESHOLD
                execute_effect(player, effect)
            end
        end)
    end,
}
```

**Step 2: Commit**

```bash
git add assets/scripts/wand/avatar_system.lua
git commit -m "feat(avatars): add TRIGGER_HANDLERS registry for on_kill, on_cast_4th, distance_moved_5m"
```

---

### Task 4: Add register_procs Function

**Files:**
- Modify: `assets/scripts/wand/avatar_system.lua` (after TRIGGER_HANDLERS, before equip)

**Step 1: Add register_procs function**

```lua
--- Register proc handlers for an avatar's effects
--- @param player table Player script table
--- @param avatarId string Avatar ID to register procs for
function AvatarSystem.register_procs(player, avatarId)
    if not player or not avatarId then return end

    local defs = loadDefs()
    local avatar = defs and defs[avatarId]
    if not avatar or not avatar.effects then return end

    local state = ensureState(player)

    -- Create signal group for cleanup
    local signal_group = require("core.signal_group")
    local handlers = signal_group.new("avatar_procs_" .. avatarId)
    state._proc_handlers = handlers

    -- Register each proc effect
    for _, effect in ipairs(avatar.effects) do
        if effect.type == "proc" then
            local triggerHandler = TRIGGER_HANDLERS[effect.trigger]
            if triggerHandler then
                triggerHandler(handlers, player, effect)
            else
                print(string.format("[AvatarSystem] Unknown trigger: %s", tostring(effect.trigger)))
            end
        end
    end
end
```

**Step 2: Commit**

```bash
git add assets/scripts/wand/avatar_system.lua
git commit -m "feat(avatars): add register_procs function"
```

---

### Task 5: Add cleanup_procs Function

**Files:**
- Modify: `assets/scripts/wand/avatar_system.lua` (after register_procs)

**Step 1: Add cleanup_procs function**

```lua
--- Cleanup all proc handlers for player
--- @param player table Player script table
function AvatarSystem.cleanup_procs(player)
    local state = player and player.avatar_state
    if state and state._proc_handlers then
        state._proc_handlers:cleanup()
        state._proc_handlers = nil
    end
end
```

**Step 2: Commit**

```bash
git add assets/scripts/wand/avatar_system.lua
git commit -m "feat(avatars): add cleanup_procs function"
```

---

### Task 6: Update equip() to Register Procs

**Files:**
- Modify: `assets/scripts/wand/avatar_system.lua:207-224` (equip function)

**Step 1: Update equip function**

Replace the existing equip function with:

```lua
-- Equip an already-unlocked avatar (for session-based choice)
-- Handles stat buff and proc handler application/removal when switching avatars
function AvatarSystem.equip(player, avatarId)
    local state = ensureState(player)
    if not state or not state.unlocked[avatarId] then
        return false, "avatar_locked"
    end

    -- Remove old avatar's effects if switching
    if state.equipped and state.equipped ~= avatarId then
        AvatarSystem.cleanup_procs(player)
        AvatarSystem.remove_stat_buffs(player)
    end

    state.equipped = avatarId

    -- Apply new avatar's effects
    AvatarSystem.apply_stat_buffs(player, avatarId)
    AvatarSystem.register_procs(player, avatarId)

    return true
end
```

**Step 2: Commit**

```bash
git add assets/scripts/wand/avatar_system.lua
git commit -m "feat(avatars): update equip() to register procs"
```

---

### Task 7: Update unequip() to Cleanup Procs

**Files:**
- Modify: `assets/scripts/wand/avatar_system.lua:229-236` (unequip function)

**Step 1: Update unequip function**

Replace the existing unequip function with:

```lua
--- Unequip current avatar (removes stat buffs and procs)
--- @param player table Player script table
--- @return boolean success
function AvatarSystem.unequip(player)
    local state = player and player.avatar_state
    if not state or not state.equipped then return true end

    AvatarSystem.cleanup_procs(player)
    AvatarSystem.remove_stat_buffs(player)
    state.equipped = nil
    return true
end
```

**Step 2: Commit**

```bash
git add assets/scripts/wand/avatar_system.lua
git commit -m "feat(avatars): update unequip() to cleanup procs"
```

---

### Task 8: Write Tests for Proc System

**Files:**
- Modify: `assets/scripts/tests/test_avatar_system.lua`

**Step 1: Add proc system tests**

Add at the end of the test file (before final return if present):

```lua
--[[
================================================================================
PROC SYSTEM TESTS
================================================================================
]]--

--- Test that register_procs creates a signal group
local function test_register_procs_creates_handlers()
    local player = {
        avatar_state = { unlocked = { bloodgod = true }, equipped = nil },
        avatar_progress = {},
    }

    AvatarSystem.register_procs(player, "bloodgod")

    assert(player.avatar_state._proc_handlers ~= nil, "Should create _proc_handlers")
    assert(player.avatar_state._proc_handlers:count() > 0, "Should have registered handlers")

    -- Cleanup
    AvatarSystem.cleanup_procs(player)
    print("[PASS] test_register_procs_creates_handlers")
end

--- Test that cleanup_procs removes the signal group
local function test_cleanup_procs_removes_handlers()
    local player = {
        avatar_state = { unlocked = { bloodgod = true }, equipped = nil },
        avatar_progress = {},
    }

    AvatarSystem.register_procs(player, "bloodgod")
    assert(player.avatar_state._proc_handlers ~= nil, "Should have handlers before cleanup")

    AvatarSystem.cleanup_procs(player)
    assert(player.avatar_state._proc_handlers == nil, "Should remove handlers after cleanup")

    print("[PASS] test_cleanup_procs_removes_handlers")
end

--- Test that equip() registers procs
local function test_equip_registers_procs()
    local player = {
        avatar_state = { unlocked = { bloodgod = true }, equipped = nil },
        avatar_progress = {},
    }

    AvatarSystem.equip(player, "bloodgod")

    assert(player.avatar_state._proc_handlers ~= nil, "equip() should register procs")

    -- Cleanup
    AvatarSystem.unequip(player)
    print("[PASS] test_equip_registers_procs")
end

--- Test that unequip() cleans up procs
local function test_unequip_cleans_up_procs()
    local player = {
        avatar_state = { unlocked = { bloodgod = true }, equipped = nil },
        avatar_progress = {},
    }

    AvatarSystem.equip(player, "bloodgod")
    AvatarSystem.unequip(player)

    assert(player.avatar_state._proc_handlers == nil, "unequip() should cleanup procs")

    print("[PASS] test_unequip_cleans_up_procs")
end

--- Test that switching avatars cleans up old procs
local function test_switch_avatar_cleans_old_procs()
    local player = {
        avatar_state = { unlocked = { bloodgod = true, citadel = true }, equipped = nil },
        avatar_progress = {},
    }

    AvatarSystem.equip(player, "bloodgod")
    local oldHandlers = player.avatar_state._proc_handlers

    AvatarSystem.equip(player, "citadel")

    assert(oldHandlers:isCleanedUp(), "Old handlers should be cleaned up")
    assert(player.avatar_state._proc_handlers ~= oldHandlers, "Should have new handlers")

    -- Cleanup
    AvatarSystem.unequip(player)
    print("[PASS] test_switch_avatar_cleans_old_procs")
end

-- Run proc tests
local function run_proc_tests()
    print("\n=== PROC SYSTEM TESTS ===")
    test_register_procs_creates_handlers()
    test_cleanup_procs_removes_handlers()
    test_equip_registers_procs()
    test_unequip_cleans_up_procs()
    test_switch_avatar_cleans_old_procs()
    print("=== ALL PROC TESTS PASSED ===\n")
end
```

**Step 2: Add run_proc_tests to the main test runner**

Find the existing test runner function and add `run_proc_tests()` call.

**Step 3: Run tests to verify**

```bash
# Run lua tests via game executable
./build/raylib-cpp-cmake-template --run-lua-tests --headless
```

Expected: All proc tests pass.

**Step 4: Commit**

```bash
git add assets/scripts/tests/test_avatar_system.lua
git commit -m "test(avatars): add proc system tests"
```

---

### Task 9: Update Design Doc Status

**Files:**
- Modify: `docs/plans/2025-12-26-avatar-proc-effects-design.md:4`

**Step 1: Update status**

Change line 4 from:
```markdown
**Status:** Design Complete
```

To:
```markdown
**Status:** Implemented
```

**Step 2: Commit**

```bash
git add docs/plans/2025-12-26-avatar-proc-effects-design.md
git commit -m "docs(avatars): mark Phase 2 proc effects as implemented"
```

---

## Verification Checklist

After all tasks complete:

1. [ ] `PROC_EFFECTS` has heal, global_barrier, poison_spread
2. [ ] `TRIGGER_HANDLERS` has on_kill, on_cast_4th, distance_moved_5m
3. [ ] `register_procs()` creates signal group and registers handlers
4. [ ] `cleanup_procs()` cleans up signal group
5. [ ] `equip()` calls `register_procs()` after stat buffs
6. [ ] `unequip()` calls `cleanup_procs()` before stat buff removal
7. [ ] Switching avatars cleans up old procs before registering new
8. [ ] All tests pass
