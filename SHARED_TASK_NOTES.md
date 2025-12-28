# Wand Resource Bar Inconsistency - Investigation Notes

## Status: PARTIAL FIX APPLIED - Design Decision Needed

### Completed:
- [x] Fixed property name typo (`.wand_def` → `.wandDef`) on line 1826
- [x] Added `WandCooldownUI.clear()` + `init()` in `startActionPhase()` to prevent stale data

### Remaining:
- [ ] **DESIGN DECISION:** Should mana persist between action phases?

## Issue Summary
Entering/exiting action phase changes values in the wand resource bar.

## Root Cause Identified

### Primary Issue: Wand State Resets on Every Action Phase Entry

**Data Flow:**
1. `startActionPhase()` → `loadWandsIntoExecutorFromBoards()` (line 7328)
2. `loadWandsIntoExecutorFromBoards()` → `WandExecutor.cleanup()` + `WandExecutor.init()` (lines 6976-6977)
3. `WandExecutor.cleanup()` resets `wandStates = {}` (line 219)
4. `WandExecutor.loadWand()` → `createWandState()` which sets `currentMana = wandDef.mana_max` (line 303)

**Result:** Every time the player enters action phase, wand mana is reset to full. Any mana spent in the previous action phase is lost.

### Is This a Bug or Intentional Design?

This needs design decision:
- **Option A (Current):** Mana resets each action phase (like a "fresh start" each combat)
- **Option B:** Mana persists across action phases (resource management matters)

### Secondary Issue: UI Entry Stale Data

`WandCooldownUI.entries` is never cleared during phase transitions:
- `WandCooldownUI.init()` only called once at game start (line 9051)
- `WandCooldownUI.clear()` is never called

This means `cooldownMax` and other cached values can be stale, though the current `computeProgress()` handles this gracefully.

### Third Issue: Property Name Typo

Line 1826 in gameplay.lua:
```lua
local currentWandDef = board_sets[current_board_set_index].wand_def  -- WRONG
```
Should be:
```lua
local currentWandDef = board_sets[current_board_set_index].wandDef   -- CORRECT
```
This causes `currentWandDef` to always be `nil`, breaking wand stat display.

## Recommended Fixes

### Fix 1: Preserve Wand State Between Action Phases (if desired)

In `loadWandsIntoExecutorFromBoards()`, DON'T call `cleanup()` if states should persist:

```lua
local function loadWandsIntoExecutorFromBoards()
    -- Save existing mana states before reloading
    local savedMana = {}
    for wandId, state in pairs(WandExecutor.wandStates) do
        savedMana[wandId] = {
            currentMana = state.currentMana,
            cooldownRemaining = state.cooldownRemaining
        }
    end

    WandExecutor.cleanup()
    WandExecutor.init()

    -- ... load wands ...

    -- Restore saved mana for existing wands
    for wandId, saved in pairs(savedMana) do
        local state = WandExecutor.wandStates[wandId]
        if state then
            state.currentMana = saved.currentMana
            state.cooldownRemaining = saved.cooldownRemaining
        end
    end
end
```

### Fix 2: Clear UI Entries on Phase Entry

In `startActionPhase()`, add:
```lua
WandCooldownUI.clear()
WandCooldownUI.init()
```

### Fix 3: Fix Property Name Typo

Line 1826: Change `.wand_def` to `.wandDef`

## Files to Modify

1. `assets/scripts/core/gameplay.lua`:
   - Line 1826: Fix `.wand_def` → `.wandDef`
   - Line 7328 area: Add mana state preservation if needed
   - Line ~7329: Add `WandCooldownUI.clear()` call

2. `assets/scripts/wand/wand_executor.lua`:
   - Consider adding a `WandExecutor.saveState()` / `restoreState()` API

## Next Steps

1. **CLARIFY WITH USER:** Should mana persist between action phases? (Design decision)
2. Apply Fix 3 (property name typo) - this is clearly a bug
3. Apply Fix 2 (clear UI entries) - prevents stale data display
4. Apply Fix 1 only if mana should persist (design decision)

## Testing

### Test the applied fixes:
1. Run the game, go to action phase
2. Cast spells to reduce mana (e.g., 30/50)
3. Exit to planning phase
4. Re-enter action phase
5. **Verify:** Mana shows fresh value (50/50) - UI should NOT show stale values from previous phase

### If mana persistence is desired:
If mana should carry over between action phases (Option B), apply Fix 1 from above, then:
1. Repeat the test above
2. **Verify:** Mana shows carried-over value (30/50) when re-entering action phase

### Wand stat display (fixed typo):
1. In planning phase, hover over a wand or check wand stats display
2. **Verify:** Wand stats (mana_max, cast_delay, etc.) are now visible (previously showed nothing due to nil)
