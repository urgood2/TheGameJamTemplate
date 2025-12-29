# Adding Trigger Cards & Wiring Events

This guide covers the complete workflow for adding **trigger cards** (automatic wand activation) and **joker triggers** (passive spell modifiers), including how to wire up new game events.

## Overview: Two Trigger Systems

This codebase has **two distinct trigger systems** that serve different purposes:

| System | Purpose | Location | When to Use |
|--------|---------|----------|-------------|
| **Trigger Cards** | Control WHEN a wand automatically fires | `data/cards.lua` (TriggerCards) | Timer-based, event-based wand activation |
| **Jokers** | Control HOW spells are modified when fired | `data/jokers.lua` | Passive bonuses, tag synergies, damage mods |

**Flow**: Trigger Card fires -> Wand executes -> Jokers modify the effects

```
Event Occurs (dash, timer, bump)
       |
       v
signal.emit("on_dash", eventData)
       |
       v
WandTriggers.handleEvent()
  - Checks all registered wands for matching trigger type
       |
       v
WandExecutor.execute(wandId)
  - Executes the wand's spell queue
       |
       v
JokerSystem.trigger_event("on_spell_cast", context)
  - All equipped jokers run calculate()
  - Results aggregated
       |
       v
WandModifiers.applyJokerEffects(modifiers, effects)
  - Joker effects applied to modifier table
       |
       v
WandActions.execute(card, modifiers)
  - Projectile spawned with all modifications
```

---

## Part 1: Adding a Trigger Card

Trigger cards determine WHEN a wand automatically casts its spell queue.

### Available Trigger Types

| Trigger Type | ID | Description |
|--------------|-----|-------------|
| Timer | `every_N_seconds` | Fires every N seconds |
| Cooldown | `on_cooldown` | Fires when wand is off cooldown |
| Collision | `on_bump_enemy` | Fires when player bumps an enemy |
| Dash | `on_dash` | Fires when player dashes |
| Distance | `on_distance_traveled` | Fires after traveling N pixels |
| Pickup | `on_pickup` | Fires when player picks up an item |
| Low Health | `on_low_health` | Fires when health drops below threshold |
| Kill | `on_kill` | Fires when an enemy is killed (NOT YET WIRED - see note below) |

> **Note**: The `on_kill` trigger is defined but not currently emitted. See "Wiring a New Event" section below.

### Step 1: Define the Trigger Card

Add to `assets/scripts/data/cards.lua` in the `TriggerCards` section:

```lua
TriggerCards.MY_TRIGGER_ON_CRIT = {
    id = "on_crit",                    -- Must match event name in wand_triggers.lua
    type = "trigger",                  -- Required: identifies as trigger card
    max_uses = -1,                     -- -1 = infinite uses
    mana_cost = 0,                     -- Triggers typically cost no mana
    weight = 0,                        -- 0 = not in random pools
    tags = { "Combat" },               -- Tags for joker synergies
    description = "Casts spells when you land a critical hit",
    trigger_type = "crit",             -- For UI categorization
    test_label = "TRIGGER\non\ncrit",  -- Display label
    sprite = "trigger-on-crit.png",    -- Visual
}
```

### Step 2: Register the Event in WandTriggers

Edit `assets/scripts/wand/wand_triggers.lua`:

**A) Add to registration logic (~line 130):**
```lua
elseif triggerType == "on_crit" then
    registration.eventType = triggerType
```

**B) Add to event subscriptions (~line 250):**
```lua
local eventNames = {
    "on_player_attack",
    "on_bump_enemy",
    "on_dash",
    "on_pickup",
    "on_low_health",
    "on_crit",  -- ADD THIS
}
```

**C) (Optional) Add condition check if needed (~line 306):**
```lua
if triggerType == "on_crit" then
    -- Check if crit actually happened
    return eventData.was_crit == true
end
```

### Step 3: Emit the Event

Find where the event should fire and emit it via signal:

```lua
-- Example: in your damage resolution code
local signal = require("external.hump.signal")

if was_critical_hit then
    signal.emit("on_crit", {
        damage = final_damage,
        target = enemy_entity,
        was_crit = true,
    })
end
```

### Step 4: Add Display Name (Optional)

In `wand_triggers.lua` at `getTriggerDisplayName()`:

```lua
local names = {
    -- ... existing entries
    on_crit = "On Critical Hit",
}
```

---

## Part 2: Adding a Joker (Passive Trigger)

Jokers passively modify spells based on events and tags. See [ADDING_JOKERS.md](ADDING_JOKERS.md) for full details.

### Quick Example

Add to `assets/scripts/data/jokers.lua`:

```lua
crit_amplifier = {
    id = "crit_amplifier",
    name = "Crit Amplifier",
    description = "+50% damage on critical hits. +1 chain on Lightning crits.",
    rarity = "Rare",
    sprite = "joker-crit-amplifier.png",
    
    calculate = function(self, context)
        -- React to spell casts
        if context.event == "on_spell_cast" then
            -- Check for Lightning tag
            if context.tags and context.tags.Lightning then
                return {
                    damage_mult = 1.5,      -- +50% damage
                    extra_chain = 1,        -- +1 chain target
                    message = "Crit Amp!"   -- UI popup
                }
            end
        end
        
        -- React to player damage
        if context.event == "on_player_damaged" then
            if context.source == "enemy_projectile" then
                return {
                    damage_reduction = 5,
                    message = "Blocked!"
                }
            end
        end
    end
}
```

### Available Joker Events

| Event | Triggered By | Context Fields |
|-------|--------------|----------------|
| `on_spell_cast` | Wand fires | `tags`, `spell_type`, `tag_analysis`, `player`, `wand_id` |
| `on_player_damaged` | Player takes damage | `damage`, `damage_type`, `source` |
| `calculate_damage` | Damage calculation | `base_damage`, `damage_type`, `player.tag_counts` |
| `on_chain_hit` | Chain lightning | `damage_type`, `target` |
| `on_dot_tick` | DoT damage tick | `dot_type`, `damage` |

### Available Return Effects

**Pre-defined effects (automatically wired):**

| Effect | Mode | Description |
|--------|------|-------------|
| `damage_mod` | add | Flat damage bonus |
| `damage_mult` | multiply | Damage multiplier (1.5 = +50%) |
| `repeat_cast` | add | Cast spell N additional times |
| `extra_chain` | add | +N chain lightning targets |
| `extra_pierce` | add | +N pierce count |
| `extra_bounce` | add | +N bounces |
| `crit_chance` | add | +N% crit chance |
| `heal_on_hit` | add | Heal N HP on hit |
| `mana_restore` | add | Restore N mana |
| `damage_reduction` | add | Reduce incoming damage by N |
| `message` | collect | UI popup text |

---

## Part 3: Wiring a New Event (Complete Example)

This section shows how to add a completely new event from scratch.

### Example: Adding "On Heal" Trigger

#### 1. Define the Trigger Card

```lua
-- In assets/scripts/data/cards.lua
TriggerCards.TRIGGER_ON_HEAL = {
    id = "on_heal",
    type = "trigger",
    max_uses = -1,
    mana_cost = 0,
    weight = 0,
    tags = { "Defense", "Holy" },
    description = "Casts spells when you receive healing",
    trigger_type = "heal",
    test_label = "TRIGGER\non\nheal",
    sprite = "trigger-on-heal.png",
}
```

#### 2. Register in WandTriggers

```lua
-- In assets/scripts/wand/wand_triggers.lua

-- Line ~140: Add registration case
elseif triggerType == "on_heal" then
    registration.eventType = triggerType
    registration.minHealAmount = triggerDef.minHealAmount or 1

-- Line ~250: Add to subscribeToEvents()
local eventNames = {
    -- ... existing
    "on_heal",
}

-- Line ~306: Add condition check in checkEventCondition()
if triggerType == "on_heal" then
    return (eventData.amount or 0) >= (registration.minHealAmount or 1)
end

-- Line ~486: Add display name in getTriggerDisplayName()
on_heal = "On Heal",
```

#### 3. Emit the Event

```lua
-- In your healing code (e.g., core/gameplay.lua or combat/effects.lua)
local signal = require("external.hump.signal")

function healPlayer(amount)
    player.health = math.min(player.health + amount, player.maxHealth)
    
    signal.emit("on_heal", {
        amount = amount,
        source = "potion",
        player = playerScript,
    })
end
```

#### 4. Create a Synergy Joker (Optional)

```lua
-- In assets/scripts/data/jokers.lua
healer_fury = {
    id = "healer_fury",
    name = "Healer's Fury",
    description = "Spells cast from healing triggers deal +20% damage.",
    rarity = "Uncommon",
    
    calculate = function(self, context)
        if context.event == "on_spell_cast" then
            -- Check if this cast came from a heal trigger
            if context.trigger_source == "on_heal" then
                return {
                    damage_mult = 1.2,
                    message = "Healer's Fury!"
                }
            end
        end
    end
}
```

---

## Part 4: Fixing the `on_kill` Trigger

The `on_kill` trigger card exists but is **not currently wired**. The codebase uses `enemy_killed` instead.

### Current State

| Signal | Emitted From | Purpose |
|--------|--------------|---------|
| `signal.emit("enemy_killed", e, ctx)` | `enemy_factory.lua:361` | Wave system, avatar hooks |
| `ctx.bus:emit("OnDeath", {...})` | `combat_system.lua:2385` | Combat internals |

### Fix Option A: Bridge `enemy_killed` to `on_kill`

Add to `assets/scripts/combat/enemy_factory.lua` after line 361:

```lua
signal.emit("enemy_killed", e, ctx)
signal.emit("on_kill", { enemy = e, context = ctx })  -- ADD THIS
```

### Fix Option B: Change trigger to use `enemy_killed`

In `cards.lua`, change the trigger ID:

```lua
TriggerCards.TRIGGER_ON_KILL = {
    id = "enemy_killed",  -- Match existing signal
    ...
}
```

And update `wand_triggers.lua` to subscribe to `"enemy_killed"` instead of `"on_kill"`.

---

## Part 5: Adding Custom Joker Effects

If you need a new effect not in the schema:

### Step 1: Add to Schema

In `assets/scripts/wand/wand_modifiers.lua`:

```lua
WandModifiers.JOKER_EFFECT_SCHEMA = {
    -- ... existing
    my_effect = { mode = "add", target = "myEffect" },
}
```

### Step 2: Add Default Value

In `createAggregate()`:

```lua
myEffect = 0,
```

### Step 3: Consume the Effect

In `wand_actions.lua`:

```lua
-- In applyToAction or handleProjectileHit
if modifiers.myEffect > 0 then
    -- Do something with the effect
end
```

### Aggregation Modes

| Mode | Behavior | Use For |
|------|----------|---------|
| `add` | Values sum together | `damage_mod`, `extra_chain` |
| `multiply` | Values multiply together | `damage_mult` |
| `max` | Highest value wins | Range bonuses |
| `min` | Lowest value wins | Cost reductions |
| `set` | Last value overwrites | Flags |

---

## Testing

### 1. Validate Syntax
```lua
dofile("assets/scripts/tools/content_validator.lua")
```

### 2. Test Trigger Registration
```lua
-- In-game console or test script
local WandTriggers = require("wand.wand_triggers")
WandTriggers.register("test_wand", { id = "on_heal" }, function(wandId, eventType)
    print("Trigger fired!", wandId, eventType)
end)

-- Then emit the event
local signal = require("external.hump.signal")
signal.emit("on_heal", { amount = 10 })
```

### 3. Test Joker
```lua
local JokerSystem = require("wand.joker_system")
JokerSystem.add_joker("healer_fury")

local effects = JokerSystem.trigger_event("on_spell_cast", {
    trigger_source = "on_heal",
    tags = { Holy = true },
})

print("Damage mult:", effects.damage_mult)  -- Should be 1.2
```

---

## File Reference

| What | Where |
|------|-------|
| Trigger card definitions | `assets/scripts/data/cards.lua` (TriggerCards table) |
| Joker definitions | `assets/scripts/data/jokers.lua` |
| Trigger event handling | `assets/scripts/wand/wand_triggers.lua` |
| Joker aggregation | `assets/scripts/wand/joker_system.lua` |
| Effect schema | `assets/scripts/wand/wand_modifiers.lua` |
| Effect application | `assets/scripts/wand/wand_actions.lua` |
| Card metadata (rarity) | `assets/scripts/core/card_metadata.lua` |
| Event bridge (combat<->signal) | `assets/scripts/core/event_bridge.lua` |

---

## Common Mistakes

1. **Event not subscribed** - Add event name to `eventNames` in `wand_triggers.lua`
2. **Signal never emitted** - Verify `signal.emit()` is called somewhere
3. **Wrong event name** - Event names are case-sensitive and must match exactly
4. **Missing nil check in joker** - Always check `context.tags and context.tags.Fire`
5. **Joker not returning** - Forgot `return` statement in calculate function
6. **Effect not in schema** - Custom effects need schema entry or auto-convert via snake_case
