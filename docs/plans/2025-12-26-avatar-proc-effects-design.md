# Avatar Proc Effects Implementation

**Date:** 2025-12-26
**Status:** Implemented
**Scope:** `proc` effect type (Phase 2)

## Overview

Implement avatar proc effects that trigger on gameplay events (kills, casts, movement). Procs register signal handlers on equip and clean up on unequip.

## Design Decisions

1. **Effect Registry** — Separates "what happens" from "when it triggers"
2. **Trigger Handlers Registry** — Each trigger type has isolated setup logic with closure-based state
3. **Lifecycle Integration** — Procs register/cleanup inside existing `equip()`/`unequip()` methods

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    AvatarSystem.equip()                 │
│         (orchestrates all effect types)                 │
└─────────────────────────────────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
    ┌──────────┐   ┌──────────┐   ┌──────────┐
    │stat_buff │   │  proc    │   │rule_change│
    │(Phase 1) │   │(Phase 2) │   │(Phase 3)  │
    └──────────┘   └──────────┘   └──────────┘
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
   ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
   │TRIGGER_HDLRS│ │PROC_EFFECTS │ │signal_group │
   │(when)       │ │(what)       │ │(cleanup)    │
   └─────────────┘ └─────────────┘ └─────────────┘
```

**State storage:**
- `player.avatar_state._proc_handlers` — SignalGroup instance for cleanup

## Implementation

### Effect Registry (PROC_EFFECTS)

Maps effect names to execution functions:

```lua
local PROC_EFFECTS = {
    heal = function(player, effect)
        local combatActor = player.combatTable
        if combatActor and combatActor.heal then
            combatActor:heal(effect.value or 0)
        end
    end,

    global_barrier = function(player, effect)
        local combatActor = player.combatTable
        if combatActor and combatActor.stats then
            local maxHp = combatActor.stats:get("max_hp") or 100
            local barrier = math.floor(maxHp * (effect.value / 100))
            combatActor:addBarrier(barrier)
        end
    end,

    poison_spread = function(player, effect)
        local Q = require("core.Q")
        local px, py = Q.center(player:handle())
        applyPoisonInRadius(px, py, effect.radius or 5)
    end,
}
```

### Trigger Handlers Registry (TRIGGER_HANDLERS)

Maps trigger types to signal registration logic:

```lua
local TRIGGER_HANDLERS = {
    on_kill = function(handlers, player, effect)
        handlers:on("enemy_killed", function(enemyEntity)
            execute_effect(player, effect)
        end)
    end,

    on_cast_4th = function(handlers, player, effect)
        local count = 0
        handlers:on("on_spell_cast", function(castData)
            count = count + 1
            if count % 4 == 0 then
                execute_effect(player, effect)
            end
        end)
    end,

    distance_moved_5m = function(handlers, player, effect)
        local accumulated = 0
        local THRESHOLD = 5 * 16  -- 5 meters in pixels
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

### New Functions in avatar_system.lua

```lua
-- Register proc handlers for avatar effects
AvatarSystem.register_procs(player, avatarId)

-- Cleanup all proc handlers
AvatarSystem.cleanup_procs(player)
```

### Updated equip/unequip

```lua
function AvatarSystem.equip(player, avatarId)
    -- ... existing unlock check ...
    if state.equipped and state.equipped ~= avatarId then
        AvatarSystem.remove_stat_buffs(player)
        AvatarSystem.cleanup_procs(player)  -- NEW
    end
    state.equipped = avatarId
    AvatarSystem.apply_stat_buffs(player, avatarId)
    AvatarSystem.register_procs(player, avatarId)  -- NEW
    return true
end

function AvatarSystem.unequip(player)
    AvatarSystem.cleanup_procs(player)  -- NEW
    AvatarSystem.remove_stat_buffs(player)
    state.equipped = nil
    return true
end
```

## Supported Procs (from avatars.lua)

| Avatar | Trigger | Effect | Value |
|--------|---------|--------|-------|
| citadel | `on_cast_4th` | `global_barrier` | 10% HP |
| miasma | `distance_moved_5m` | `poison_spread` | radius 8 |
| bloodgod | `on_kill` | `heal` | 5 HP |

## Files Changed

| File | Change |
|------|--------|
| `assets/scripts/wand/avatar_system.lua` | +60 lines: PROC_EFFECTS, TRIGGER_HANDLERS, register_procs, cleanup_procs, updated equip/unequip |
| `assets/scripts/tests/test_avatar_system.lua` | +50 lines: proc registration, trigger firing, cleanup tests |

## Test Coverage

- Effect execution (heal, barrier, poison_spread)
- Trigger registration (on_kill fires on enemy_killed)
- Counting triggers (on_cast_4th fires on 4th, 8th, etc.)
- Distance accumulation (distance_moved_5m)
- Cleanup removes all handlers
- Switching avatars cleans up old procs

## Future Phases

- **Phase 3:** `rule_change` effects (use `has_rule()` in wand execution for conditional behavior)

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
