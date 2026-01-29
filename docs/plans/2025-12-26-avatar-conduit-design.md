# Avatar of the Conduit - Design Document

## Overview

A lightning-themed avatar that rewards aggressive play by converting incoming physical damage into stacking damage buffs.

**Flavor:** *"Pain becomes power. Lightning becomes you."*

## Unlock Condition

- **Metric:** `chain_lightning_propagations = 20`
- **Counting:** Per-jump (each enemy hit by chain lightning arc counts as 1)

## Effects

### 1. Lightning Resistance (+30%)

- **Type:** `stat_buff`
- **Stat:** `lightning_resist_pct`
- **Value:** 30

Applied via existing `AvatarSystem.apply_stat_buffs()` when equipped.

### 2. Lightning Damage (+30%)

- **Type:** `stat_buff`
- **Stat:** `lightning_modifier_pct`
- **Value:** 30

Multiplicative with `all_damage_pct` in damage pipeline (combat_system.lua:2261-2263).

### 3. Conduit Charge System

Converts physical damage taken into stacking damage bonus.

| Parameter | Value |
|-----------|-------|
| Damage per stack | 10 physical damage = 1 stack |
| Max stacks | 20 |
| Bonus per stack | +5% all_damage_pct |
| Max bonus | +100% damage (at 20 stacks) |
| Decay rate | 1 stack per 5 seconds (linear) |

**Implementation approach:**
- Single permanent status entry (no `until_time`)
- Tracks stack count directly (not multiple entries)
- External decay timer managed by avatar proc system
- Uses `timer.every_opts()` with group for cleanup

## Implementation Plan

### File Changes

#### 1. `assets/scripts/data/avatars.lua`

Add avatar definition:

```lua
conduit = {
    name = "Avatar of the Conduit",
    description = "Pain becomes power. Lightning becomes you.",

    unlock = {
        chain_lightning_propagations = 20
    },

    effects = {
        {
            type = "stat_buff",
            stat = "lightning_resist_pct",
            value = 30
        },
        {
            type = "stat_buff",
            stat = "lightning_modifier_pct",
            value = 30
        },
        {
            type = "proc",
            trigger = "on_physical_damage_taken",
            effect = "conduit_charge",
            config = {
                damage_per_stack = 10,
                max_stacks = 20,
                damage_bonus_per_stack = 5,
                decay_interval = 5.0,
            }
        }
    }
}
```

#### 2. `assets/scripts/wand/wand_actions.lua`

In `spawnChainLightning`, after each successful chain hit:

```lua
-- Track chain propagation for avatar unlock
local playerScript = context and context.playerScript
if playerScript then
    local AvatarSystem = require("wand.avatar_system")
    AvatarSystem.record_progress(playerScript, "chain_lightning_propagations", 1)
end
```

#### 3. `assets/scripts/wand/avatar_system.lua`

**New trigger handler:**

```lua
TRIGGER_HANDLERS.on_physical_damage_taken = function(handlers, player, effect)
    handlers:on("player_damaged", function(data)
        if data.damage_type ~= "physical" then return end

        local config = effect.config or {}
        local damage_per_stack = config.damage_per_stack or 10
        local max_stacks = config.max_stacks or 20
        local bonus_per_stack = config.damage_bonus_per_stack or 5

        local stacks_gained = math.floor(data.amount / damage_per_stack)
        if stacks_gained < 1 then return end

        -- Get or create conduit state
        player.conduit_stacks = player.conduit_stacks or 0
        local old_stacks = player.conduit_stacks
        player.conduit_stacks = math.min(max_stacks, old_stacks + stacks_gained)
        local actual_gained = player.conduit_stacks - old_stacks

        if actual_gained > 0 then
            -- Apply damage bonus
            local stats = player.combatTable and player.combatTable.stats
            if stats then
                stats:add_add_pct("all_damage_pct", actual_gained * bonus_per_stack)
                stats:recompute()
            end
        end
    end)
end
```

**New proc effect:**

```lua
PROC_EFFECTS.conduit_charge = function(player, effect)
    local config = effect.config or {}
    local decay_interval = config.decay_interval or 5.0
    local bonus_per_stack = config.damage_bonus_per_stack or 5

    local timer = require("core.timer")

    -- Start decay timer
    timer.every_opts({
        delay = decay_interval,
        action = function()
            if player.conduit_stacks and player.conduit_stacks > 0 then
                player.conduit_stacks = player.conduit_stacks - 1

                -- Remove one stack's worth of bonus
                local stats = player.combatTable and player.combatTable.stats
                if stats then
                    stats:add_add_pct("all_damage_pct", -bonus_per_stack)
                    stats:recompute()
                end
            end
        end,
        tag = "conduit_decay",
        group = "avatar_conduit"
    })
end
```

**Cleanup on unequip** (modify `AvatarSystem.cleanup_procs`):

```lua
-- Add to cleanup_procs:
if player.conduit_stacks and player.conduit_stacks > 0 then
    local stats = player.combatTable and player.combatTable.stats
    if stats then
        local bonus_per_stack = 5  -- or read from config
        stats:add_add_pct("all_damage_pct", -player.conduit_stacks * bonus_per_stack)
        stats:recompute()
    end
    player.conduit_stacks = 0
end
timer.kill_group("avatar_conduit")
```

#### 4. Signal Emission

Ensure `player_damaged` signal is emitted with damage type. Check if this already exists; if not, add to damage application in combat system or projectile system.

## Testing

1. **Unlock test:** Cast chain lightning, verify 20 propagations unlocks avatar
2. **Resistance test:** Take lightning damage, verify 30% reduction
3. **Damage test:** Deal lightning damage, verify 30% increase
4. **Stack gain test:** Take 50 physical damage, verify 5 stacks gained
5. **Stack cap test:** Take massive physical damage, verify capped at 20 stacks
6. **Decay test:** Wait 5 seconds, verify 1 stack lost
7. **Damage bonus test:** At 10 stacks, verify +50% all damage
8. **Cleanup test:** Unequip avatar, verify stacks and bonus removed

## Notes

- The Conduit Charge status uses no intrinsic timer (`until_time = nil`), which is valid per combat_system.lua patterns for equipment/aura effects
- Decay is linear (1 per 5s) not per-stack-timer, matching the spec "decays at a rate of 1 per 5 seconds"
- Stack tracking lives on `player.conduit_stacks` for simplicity; could migrate to formal status system later if needed

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
