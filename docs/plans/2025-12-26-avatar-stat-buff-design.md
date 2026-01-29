# Avatar Stat Buff Implementation

**Date:** 2025-12-26
**Status:** Implemented
**Scope:** `stat_buff` effect type (phase 1)

## Overview

Implement avatar stat buff application so equipped avatars modify player stats. Stat buffs are applied **once on equip** to the player's combat stats (not per-cast).

## Design Decision

**Stat buffs apply once to `player.combatTable.stats`** (like items), not per-cast. This means:
- Avatar stat buffs affect ALL systems that read player stats (wand, combat, UI)
- Buffs are removed when switching/unequipping avatars
- Follows the same pattern as the item system

**Rule changes and procs** will be checked per-cast via `context.equippedAvatar` (future phases).

## Implementation

### New Functions in `avatar_system.lua`

```lua
-- Apply stat_buff effects to player's combat stats
AvatarSystem.apply_stat_buffs(player, avatarId)

-- Remove previously applied stat buffs
AvatarSystem.remove_stat_buffs(player)

-- Unequip current avatar (removes stat buffs)
AvatarSystem.unequip(player)

-- Check if player has a specific avatar rule active
AvatarSystem.has_rule(player, rule) -> boolean
```

### Updated `equip()` Function

The `equip()` function now:
1. Removes old avatar's stat buffs if switching
2. Sets `state.equipped = avatarId`
3. Applies new avatar's stat buffs via `apply_stat_buffs()`

### Stat Application Details

- Uses `stats:add_add_pct(stat, value)` for percentage buffs
- Tracks applied buffs in `player.avatar_state._applied_buffs`
- Calls `stats:recompute()` after application
- Handles missing `combatTable` gracefully (stores `_pending_avatar_buffs`)

## Files Changed

| File | Change |
|------|--------|
| `assets/scripts/wand/avatar_system.lua` | +80 lines: `apply_stat_buffs`, `remove_stat_buffs`, `unequip`, `has_rule`, updated `equip()` |
| `assets/scripts/tests/test_avatar_system.lua` | +70 lines: tests for stat buff application, removal, and rule checking |

## Test Coverage

- `has_rule()` correctly identifies avatar rules
- `apply_stat_buffs()` handles missing combatTable gracefully
- Stat buffs correctly apply to combat stats
- `remove_stat_buffs()` reverses applied buffs
- `unequip()` removes stat buffs and clears equipped

## Usage Example

```lua
local AvatarSystem = require("wand.avatar_system")

-- Unlock and equip stormlord
player.avatar_state = { unlocked = { stormlord = true } }
AvatarSystem.equip(player, "stormlord")
-- Player now has +50% cast_speed applied to combat stats

-- Check if avatar rule is active
if AvatarSystem.has_rule(player, "crit_chains") then
    -- Apply crit chaining logic
end

-- Switch to different avatar
AvatarSystem.equip(player, "wildfire")
-- Old buffs removed, new buffs applied

-- Unequip entirely
AvatarSystem.unequip(player)
```

## Future Phases

- **Phase 2:** `proc` effects (signal handlers for on_kill, on_cast_4th, etc.)
- **Phase 3:** `rule_change` effects (use `has_rule()` in wand execution for conditional behavior)

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
