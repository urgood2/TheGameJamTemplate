# Wand Resource Bar Inconsistency Fix

## Status: FIX APPLIED - NEEDS TESTING

## What Was Fixed

**Root Cause**: `loadWandsIntoExecutorFromBoards()` in `gameplay.lua:6975` was calling `WandExecutor.cleanup()` + `WandExecutor.init()` which cleared all wand states (mana, cooldowns, charges). When action phase started, wands got fresh state with full mana/zero cooldown instead of preserving values.

**Fix Applied**: Added capture-restore pattern at `gameplay.lua:6976-6983`:
```lua
local preservedStates = WandExecutor.wandStates or {}
WandExecutor.cleanup()
WandExecutor.init()
WandExecutor.wandStates = preservedStates
```

## Next Steps

1. **Manual Test**: Play through planning -> action -> planning cycle. Verify:
   - Mana bar doesn't reset to full when entering action phase
   - Cooldowns persist across phase transitions
   - Charges don't reset unexpectedly

2. **Edge Cases to Check**:
   - What happens when wand definitions change between phases? (new cards added)
   - Does removing a wand properly clean up its preserved state?
   - Behavior on first action phase (no preserved state yet)

3. **If Bug Persists**: Check if UI (`wand_cooldown_ui.lua`) has its own state that needs syncing, or if there's another code path that resets wand state.

## Key Files

- `assets/scripts/core/gameplay.lua:6975-6983` - The fix location
- `assets/scripts/wand/wand_executor.lua:177-224` - cleanup/init functions
- `assets/scripts/wand/wand_executor.lua:286-333` - state creation/retrieval
- `assets/scripts/ui/wand_cooldown_ui.lua:95-130` - UI state sync
