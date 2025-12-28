# SHARED_TASK_NOTES.md
## Current Task: Fix Wand Resource Bar Inconsistency

### Problem Statement
"Entering/exiting action phase changes the values in the wand resource bar" - reported inconsistency in wand resource bar values during phase transitions.

### Investigation Summary

#### Key Files Analyzed
- `assets/scripts/ui/wand_cooldown_ui.lua` - Wand resource bar UI (lines 86-255)
- `assets/scripts/wand/wand_executor.lua` - Wand state management (lines 215-370)
- `assets/scripts/core/gameplay.lua` - Phase transitions (lines 7288-7430)

#### Data Flow During Phase Transitions

**Entering Action Phase (`startActionPhase()`, line 7288):**
1. Line 7317: `activate_state(ACTION_STATE)` - enables UI updates
2. Line 7328: `loadWandsIntoExecutorFromBoards()` which:
   - Line 6976: `WandExecutor.cleanup()` - clears all wand states
   - Line 6977: `WandExecutor.init()` - reinitializes
   - Creates new wand states with `currentMana = wandDef.mana_max`

**Exiting Action Phase (`startPlanningPhase()`, line 7387):**
1. Line 7392: `WandExecutor.cleanup()` - clears wand states
2. `WandCooldownUI` entries are NOT explicitly cleared

### Potential Root Causes

#### Hypothesis 1: Stale UI Entries (MOST LIKELY)
`WandCooldownUI.entries` persists across phase transitions. While entries are updated on next ACTION_STATE update, there could be a brief window where:
- Old entries exist with old mana/cooldown values
- State is nil or different, causing display issues

**Evidence:**
- `WandCooldownUI.init()` only called once at line 9051 (initial setup)
- No `WandCooldownUI.clear()` call in `startActionPhase()`

#### Hypothesis 2: `cooldownMax` Tracking Issue
Line 117-119 in `wand_cooldown_ui.lua`:
```lua
if currentCooldown > (entry.cooldownMax or 0) + 0.01 then
    entry.cooldownMax = currentCooldown
end
```
This only updates `cooldownMax` when a NEW higher cooldown is detected. After phase transition, `cooldownMax` retains old value, potentially causing incorrect progress display.

#### Hypothesis 3: Wand State Timing
`WandExecutor.getWandState()` might return nil briefly during initialization, causing entries to retain old values from previous phase (line 106 guard: `if state then`).

### Proposed Fixes

#### Option A: Clear WandCooldownUI on Phase Entry (Recommended)
Add `WandCooldownUI.clear()` call at start of `startActionPhase()`:
```lua
-- In gameplay.lua startActionPhase() after line 7301:
WandCooldownUI.clear()
```
This ensures fresh entries are created with correct values.

#### Option B: Reset cooldownMax on Entry Creation
Modify `ensureEntry()` to reset `cooldownMax` based on wand definition:
```lua
local function ensureEntry(wandId, wandDef)
    local entry = WandCooldownUI.entries[wandId]
    if not entry then
        local baseCooldown = 0
        if wandDef and wandDef.recharge_time then
            baseCooldown = wandDef.recharge_time / 1000  -- Convert ms to seconds
        end
        entry = {
            label = (wandDef and wandDef.id) or tostring(wandId),
            cooldownMax = baseCooldown,
            cooldownRemaining = 0,
        }
        WandCooldownUI.entries[wandId] = entry
    end
    return entry
end
```

#### Option C: Force Entry Refresh on Phase Entry
Add a flag to force complete refresh of all entries:
```lua
function WandCooldownUI.forceRefresh()
    WandCooldownUI.entries = {}
end
```
Call this in `startActionPhase()`.

### Fixes Implemented

#### Fix 1: Clear UI Entries on Phase Entry
**File:** `assets/scripts/core/gameplay.lua` (line 7303-7306)
```lua
-- Clear wand cooldown UI entries to prevent stale values on re-entry
if WandCooldownUI and WandCooldownUI.clear then
    WandCooldownUI.clear()
end
```
This ensures all UI entries are cleared when entering action phase, forcing fresh creation with current values.

#### Fix 2: Improved Entry Initialization
**File:** `assets/scripts/ui/wand_cooldown_ui.lua` (line 59-77)
- `cooldownMax` now initialized from `wandDef.recharge_time` (converted from ms to seconds)
- Added `currentMana` and `maxMana` fields to initial entry structure

### Verification
- Both Lua files pass syntax check (`luac -p`)
- No C++ changes required

### Next Steps for Testing
1. Build and run the game
2. Enter action phase, cast spells to consume mana/trigger cooldowns
3. Exit to planning phase
4. Re-enter action phase
5. Verify resource bar shows correct values (full mana, ready cooldown)

### If Issues Persist
If the user still sees inconsistencies after these fixes, additional investigation may be needed:
- Add debug logging to phase transitions
- Check for race conditions with timer callbacks
- Investigate if any signals modify wand state unexpectedly
