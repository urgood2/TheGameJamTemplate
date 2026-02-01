# Event System (Signals)

The codebase has two event systems that work together. Understanding when to use each is crucial.

## Quick Reference

| System | Use For | Example |
|--------|---------|---------|
| `signal` (hump.signal) | Gameplay events, cross-system communication | `signal.emit("enemy_killed", entity)` |
| `ctx.bus` (EventBus) | Combat system internals | `ctx.bus:emit("OnDeath", { entity = actor })` |

## 1. Signal (hump.signal)

The primary event system for gameplay events.

### Basic Usage

```lua
local signal = require("external.hump.signal")

-- Register a handler
signal.register("enemy_killed", function(entity)
    print("Enemy killed:", entity)
end)

-- Emit an event (entity first, then data table)
signal.emit("enemy_killed", enemy, { killer = player })
```

### Pattern: Scoped Handlers with signal_group

Prevent memory leaks by using `signal_group` for cleanup:

```lua
local signal_group = require("core.signal_group")

-- Create a group for this module
local handlers = signal_group.new("combat_ui")

-- Register handlers (tracked for cleanup)
handlers:on("enemy_killed", function(entity)
    updateKillCount()
end)

handlers:on("player_damaged", function(entity, data)
    showDamageFlash()
end)

-- When done (scene unload, entity destroyed):
handlers:cleanup()  -- Removes ALL handlers at once
```

### Common Events

| Event | Parameters | Description |
|-------|------------|-------------|
| `"enemy_spawned"` | `entity, { preset_id }` | Enemy created |
| `"enemy_killed"` | `entity` | Enemy destroyed |
| `"projectile_spawned"` | `entity, { direction, speed, owner }` | Projectile created |
| `"pickup_spawned"` | `entity, { pickup_type }` | Pickup created |
| `"player_level_up"` | `{ xp, level }` | Level progression |
| `"deck_changed"` | `{ source }` | Card inventory modified |
| `"stats_recomputed"` | `nil` | Stats recalculated |

## 2. EventBus (Combat System)

Internal to the combat system, accessed via `ctx.bus`.

```lua
-- Inside combat scripts
ctx.bus:emit("OnDeath", { entity = combatActor, killer = src })
ctx.bus:on("OnDamage", function(data)
    print("Damage:", data.amount)
end)
```

### Event Bridge

The `core/event_bridge.lua` automatically forwards most combat bus events to the signal system. This prevents disconnection bugs.

**Bridged Events:**
- `OnDamage` → forwards to signal
- `OnHeal` → forwards to signal
- `OnBuffApplied` → forwards to signal
- `OnBuffRemoved` → forwards to signal

**Special Case - OnDeath:**

Combat bus emits `actor` (combat object), but wave system expects entity ID:

```lua
-- In gameplay.lua, manual conversion:
local enemyEntity = combatActorToEntity[actor]
signal.emit("enemy_killed", enemyEntity)
```

## Best Practices

### DO: Use signal for cross-system events
```lua
signal.emit("wave_complete", { wave_number = 5 })
signal.emit("boss_spawned", bossEntity)
```

### DO: Use signal_group for cleanup
```lua
-- In module init
local handlers = signal_group.new("my_module")

-- In module cleanup
handlers:cleanup()
```

### DON'T: Use publishLuaEvent
```lua
-- Old (deprecated)
publishLuaEvent("enemy_killed", { entity = e })

-- New (preferred)
signal.emit("enemy_killed", e)
```

### DON'T: Forget to unregister handlers
```lua
-- BAD: Handler leaks when scene reloads
signal.register("event", myHandler)

-- GOOD: Use signal_group for automatic cleanup
handlers:on("event", myHandler)
```

## Adding New Bridged Events

If a combat bus event should be visible outside the combat system:

1. Open `core/event_bridge.lua`
2. Add event name to `BRIDGED_EVENTS` table
3. If event data contains combat actors (not entity IDs), add manual conversion

```lua
-- In event_bridge.lua
BRIDGED_EVENTS["MyNewEvent"] = true
```

## See Also

- [signal_group.lua](../../assets/scripts/core/signal_group.lua) - Scoped cleanup
- [event_bridge.lua](../../assets/scripts/core/event_bridge.lua) - Bus bridging
- [hump.signal docs](../../docs/external/hump_README.md) - Upstream library

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
