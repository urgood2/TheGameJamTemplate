# Combat Systems API

Complete reference for triggers, status effects, and equipment systems in the combat engine.

## Overview

The combat system provides three interconnected APIs:

- **Triggers**: Event-based hooks for reacting to game events (attacks, damage, movement, etc.)
- **Status Effects**: DoTs (damage over time), buffs, debuffs, and detonatable marks with stacking behavior
- **Equipment**: Gear with stats, procs (trigger-based effects), damage conversions, and slot management

All three systems work together: equipment procs subscribe to triggers, triggers emit events that status effects respond to, and status effects can modify equipment behavior.

---

## 1. Triggers API

### Quick Start

```lua
local Triggers = require("data.triggers")
local signal = require("external.hump.signal")

-- Subscribe to a trigger
signal.register(Triggers.COMBAT.ON_HIT, function(target, data)
    print("Hit entity:", target)
    print("Attacker:", data.source)
    print("Damage:", data.amount)
end)
```

### Trigger Categories

#### COMBAT Triggers

| Constant | String Value | Description |
|----------|--------------|-------------|
| `ON_ATTACK` | `"on_attack"` | When entity initiates an attack (before damage is calculated) |
| `ON_HIT` | `"on_hit"` | When an attack successfully lands (after mitigation) |
| `ON_KILL` | `"on_kill"` | When entity kills another entity |
| `ON_CRIT` | `"on_crit"` | When entity scores a critical hit |
| `ON_MISS` | `"on_miss"` | When an attack fails to connect |
| `ON_BASIC_ATTACK` | `"on_basic_attack"` | When entity performs a basic attack (non-spell) |
| `ON_SPELL_CAST` | `"on_spell_cast"` | When entity casts a spell |
| `ON_CHAIN_HIT` | `"on_chain_hit"` | When chained lightning/chain damage hits |
| `ON_PROJECTILE_HIT` | `"on_projectile_hit"` | When projectile hits a target |
| `ON_PROJECTILE_SPAWN` | `"on_projectile_spawn"` | When projectile is created |

#### DEFENSIVE Triggers

| Constant | String Value | Description |
|----------|--------------|-------------|
| `ON_BEING_ATTACKED` | `"on_being_attacked"` | When entity is targeted by an attack |
| `ON_BEING_HIT` | `"on_being_hit"` | When entity is hit (after mitigation) |
| `ON_PLAYER_DAMAGED` | `"on_player_damaged"` | When player takes damage |
| `ON_BLOCK` | `"on_block"` | When entity successfully blocks an attack |
| `ON_DODGE` | `"on_dodge"` | When entity dodges an attack |
| `ON_SHRUG_OFF` | `"on_shrug_off"` | When entity shrugs off damage (reduced to 0) |
| `ON_COUNTER_ATTACK` | `"on_counter_attack"` | When entity performs a counter attack |

#### MOVEMENT Triggers

| Constant | String Value | Description |
|----------|--------------|-------------|
| `ON_STEP` | `"on_step"` | When entity takes a step (movement) |
| `ON_STAND_STILL` | `"on_stand_still"` | When entity remains stationary for a period |
| `ON_TELEPORT` | `"on_teleport"` | When entity teleports |
| `ON_DASH` | `"on_dash"` | When entity dashes |

#### STATUS Triggers

| Constant | String Value | Description |
|----------|--------------|-------------|
| `ON_APPLY_STATUS` | `"on_apply_status"` | When any status is applied to entity |
| `ON_REMOVE_STATUS` | `"on_remove_status"` | When any status is removed from entity |
| `ON_STATUS_EXPIRED` | `"on_status_expired"` | When a timed status expires naturally |
| `ON_APPLY_BURN` | `"on_apply_burn"` | When burn is applied |
| `ON_APPLY_FREEZE` | `"on_apply_freeze"` | When freeze is applied |
| `ON_APPLY_POISON` | `"on_apply_poison"` | When poison is applied |
| `ON_APPLY_BLEED` | `"on_apply_bleed"` | When bleed is applied |
| `ON_APPLY_DOOM` | `"on_apply_doom"` | When doom is applied |
| `ON_APPLY_ELECTROCUTE` | `"on_apply_electrocute"` | When electrocute is applied |
| `ON_APPLY_CORROSION` | `"on_apply_corrosion"` | When corrosion is applied |
| `ON_DOT_TICK` | `"on_dot_tick"` | When DoT damage ticks (e.g., burn, poison) |
| `ON_DOT_EXPIRED` | `"on_dot_expired"` | When DoT expires |
| `ON_MARK_APPLIED` | `"on_mark_applied"` | When detonatable mark is applied |
| `ON_MARK_DETONATED` | `"on_mark_detonated"` | When mark detonates (triggered) |

#### BUFF Triggers

| Constant | String Value | Description |
|----------|--------------|-------------|
| `ON_BUFF_APPLIED` | `"on_buff_applied"` | When buff is applied |
| `ON_BUFF_REMOVED` | `"on_buff_removed"` | When buff is removed |
| `ON_BUFF_EXPIRED` | `"on_buff_expired"` | When buff expires |
| `ON_POISE_GAIN` | `"on_poise_gain"` | When poise is gained |
| `ON_CHARGE_GAIN` | `"on_charge_gain"` | When charge is gained |
| `ON_INFLAME_GAIN` | `"on_inflame_gain"` | When inflame is gained |
| `ON_BLOODRAGE_GAIN` | `"on_bloodrage_gain"` | When bloodrage is gained |

#### PROGRESSION Triggers

| Constant | String Value | Description |
|----------|--------------|-------------|
| `ON_ENTRANCE` | `"on_entrance"` | When entity enters combat/arena |
| `ON_WAVE_START` | `"on_wave_start"` | When a new wave starts |
| `ON_WAVE_CLEAR` | `"on_wave_clear"` | When a wave is cleared |
| `ON_LEVEL_UP` | `"on_level_up"` | When entity gains a level |
| `ON_EXPERIENCE_GAINED` | `"on_experience_gained"` | When entity gains experience |

#### RESOURCE Triggers

| Constant | String Value | Description |
|----------|--------------|-------------|
| `ON_HEAL` | `"on_heal"` | When entity is healed |
| `ON_MANA_SPENT` | `"on_mana_spent"` | When mana is spent |
| `ON_MANA_RESTORED` | `"on_mana_restored"` | When mana is restored |
| `ON_LOW_HEALTH` | `"on_low_health"` | When entity drops below health threshold |
| `ON_FULL_HEALTH` | `"on_full_health"` | When entity reaches full health |
| `ON_SELF_DAMAGE` | `"on_self_damage"` | When entity damages itself |

#### ENTITY Triggers

| Constant | String Value | Description |
|----------|--------------|-------------|
| `ON_SUMMON` | `"on_summon"` | When entity is summoned |
| `ON_MINION_DEATH` | `"on_minion_death"` | When a minion dies |
| `ON_ENEMY_SPAWN` | `"on_enemy_spawn"` | When enemy spawns |
| `ON_DEATH` | `"on_death"` | When entity dies |
| `ON_RESURRECT` | `"on_resurrect"` | When entity is resurrected |

#### EQUIPMENT Triggers

| Constant | String Value | Description |
|----------|--------------|-------------|
| `ON_EQUIP` | `"on_equip"` | When item is equipped |
| `ON_UNEQUIP` | `"on_unequip"` | When item is unequipped |

#### TICK Triggers

| Constant | String Value | Description |
|----------|--------------|-------------|
| `ON_TICK` | `"on_tick"` | Every game tick (called every frame) |
| `ON_TURN_START` | `"on_turn_start"` | When a turn starts (turn-based combat) |
| `ON_TURN_END` | `"on_turn_end"` | When a turn ends (turn-based combat) |

#### CALCULATION Triggers

| Constant | String Value | Description |
|----------|--------------|-------------|
| `CALCULATE_DAMAGE` | `"calculate_damage"` | When damage is being calculated |
| `CALCULATE_HEALING` | `"calculate_healing"` | When healing is being calculated |
| `CALCULATE_CRIT` | `"calculate_crit"` | When crit chance is being calculated |
| `CALCULATE_RESIST` | `"calculate_resist"` | When resistance is being calculated |

### Subscribing to Triggers

#### Using signal.register

```lua
local signal = require("external.hump.signal")
local Triggers = require("data.triggers")

-- Register a single handler
signal.register(Triggers.COMBAT.ON_KILL, function(target, data)
    print("Killed:", target)
    print("Killer:", data.source)
end)
```

#### Using signal_group for Cleanup

```lua
local signal_group = require("core.signal_group")
local Triggers = require("data.triggers")

-- Create a group for automatic cleanup
local handlers = signal_group.new("combat_module")

-- Register multiple handlers
handlers:on(Triggers.COMBAT.ON_HIT, function(target, data)
    applyVFX(target, "hit_flash")
end)

handlers:on(Triggers.COMBAT.ON_KILL, function(target, data)
    grantXP(data.source, 50)
end)

-- When done (e.g., scene unload, entity destroyed):
handlers:cleanup()  -- Removes ALL handlers in this group
```

### Event Data Format

Event data varies by trigger. Common patterns:

```lua
-- ON_HIT event data
{
    source = attackerEntity,     -- Who dealt the damage
    target = targetEntity,       -- First param (the entity hit)
    amount = 25,               -- Damage dealt
    damage_type = "fire",        -- Damage type
    tags = { fire = true },     -- Additional tags
}

-- ON_KILL event data
{
    source = killerEntity,       -- First param (the killer)
    target = victimEntity,       -- Who died (if available)
    damage_type = "physical",
}

-- ON_APPLY_STATUS event data
{
    source = sourceEntity,      -- Who applied the status
    status_id = "burning",      -- Status effect ID
    stacks = 3,                -- Number of stacks applied
}

-- ON_HEAL event data
{
    source = healerEntity,       -- Who performed the heal
    target = targetEntity,      -- First param (who was healed)
    amount = 50,               -- Amount healed
}
```

### Trigger Validation

```lua
local Triggers = require("data.triggers")

-- Check if a trigger is valid
if Triggers.isValid("on_hit") then
    print("Valid trigger")
end

-- Get trigger category
local category = Triggers.getCategory("on_hit")
-- Returns: "COMBAT"
```

---

## 2. Status Effects API

### Quick Start

```lua
local StatusEngine = require("combat.combat_system").StatusEngine

-- Apply a status effect
local stacks = StatusEngine.apply(ctx, enemy, "burning", {
    stacks = 5,
    duration = 10,
    source = player,
})

-- Check status
if StatusEngine.hasStatus(enemy, "burning") then
    print("Enemy is burning with", StatusEngine.getStacks(enemy, "burning"), "stacks")
end

-- Remove status
StatusEngine.remove(ctx, enemy, "burning")

-- Clear all statuses
StatusEngine.clearAll(ctx, enemy)
```

### StatusEngine Methods

#### apply()

Apply a status effect to an entity.

```lua
StatusEngine.apply(ctx, target, status_id, opts)
```

**Parameters:**
- `ctx`: Combat context (contains bus, time, etc.)
- `target`: Entity to apply status to
- `status_id`: String ID of status effect (e.g., `"burning"`)
- `opts`: Optional configuration table
  - `stacks` (number): Number of stacks to add (default: 1)
  - `duration` (number): Duration in seconds (overrides status definition)
  - `source` (entity): Entity that applied the status (for damage attribution)

**Returns:** Number of stacks after application

```lua
local stacks = StatusEngine.apply(ctx, enemy, "poison", {
    stacks = 3,
    source = player,
    duration = 8,
})
```

#### remove()

Remove a status effect from an entity.

```lua
StatusEngine.remove(ctx, target, status_id, stacks_to_remove)
```

**Parameters:**
- `ctx`: Combat context
- `target`: Entity to remove status from
- `status_id`: String ID of status effect
- `stacks_to_remove` (optional): Number of stacks to remove (omitted = remove all)

**Returns:** Number of stacks remaining (0 if fully removed)

```lua
-- Remove 2 stacks
local remaining = StatusEngine.remove(ctx, enemy, "poison", 2)

-- Remove all stacks
StatusEngine.remove(ctx, enemy, "poison")
```

#### getStacks()

Get current stack count for a status effect.

```lua
StatusEngine.getStacks(target, status_id)
```

**Parameters:**
- `target`: Entity to check
- `status_id`: String ID of status effect

**Returns:** Number of stacks (0 if not present)

```lua
local poisonStacks = StatusEngine.getStacks(enemy, "poison")
if poisonStacks > 0 then
    print("Poison stacks:", poisonStacks)
end
```

#### hasStatus()

Check if entity has a specific status effect.

```lua
StatusEngine.hasStatus(target, status_id)
```

**Parameters:**
- `target`: Entity to check
- `status_id`: String ID of status effect

**Returns:** Boolean

```lua
if StatusEngine.hasStatus(enemy, "frozen") then
    print("Enemy is frozen!")
end
```

#### clearAll()

Remove all status effects from an entity.

```lua
StatusEngine.clearAll(ctx, target)
```

**Parameters:**
- `ctx`: Combat context
- `target`: Entity to clear statuses from

```lua
-- On death or boss phase change
StatusEngine.clearAll(ctx, boss)
```

### Stacking Modes

Status effects support four stacking behaviors, defined in `stack_mode` field:

#### REPLACE Mode

Replaces existing stacks with new stacks. Duration resets.

```lua
StatusEffects.haste = {
    id = "haste",
    stack_mode = "replace",      -- <-- REPLACE mode
    max_stacks = 1,
    duration = 5,
    stat_mods = { attack_speed = 0.3 },
}

-- Applying multiple times resets duration, stacks stay at 1
StatusEngine.apply(ctx, entity, "haste")  -- stacks = 1, time = 5s
StatusEngine.apply(ctx, entity, "haste")  -- stacks = 1, time = 5s (reset)
```

**Use when:** Status is binary (present or not) and refreshing is desired.

#### TIME_EXTEND Mode

Adds stacks, each stack extends duration by `duration_per_stack`.

```lua
StatusEffects.frozen = {
    id = "frozen",
    stack_mode = "time_extend",     -- <-- TIME_EXTEND mode
    max_stacks = 20,
    duration_per_stack = 0.5,     -- Each stack adds 0.5 seconds
    stat_mods = { run_speed = -50 },
}

-- Each application adds 0.5s duration
StatusEngine.apply(ctx, entity, "frozen", { stacks = 1 })   -- duration = 0.5s
StatusEngine.apply(ctx, entity, "frozen", { stacks = 1 })   -- duration = 1.0s
StatusEngine.apply(ctx, entity, "frozen", { stacks = 2 })   -- duration = 2.0s
```

**Use when:** More stacks = longer duration (crowd control effects).

#### INTENSITY Mode

Adds stacks up to `max_stacks`. Duration refreshes if `duration` is set.

```lua
StatusEffects.burning = {
    id = "burning",
    stack_mode = "intensity",      -- <-- INTENSITY mode
    max_stacks = 99,
    duration = 5,
    base_dps = 5,
}

-- Stacks accumulate, duration resets
StatusEngine.apply(ctx, entity, "burning", { stacks = 3 })   -- stacks = 3, time = 5s
StatusEngine.apply(ctx, entity, "burning", { stacks = 2 })   -- stacks = 5, time = 5s
StatusEngine.apply(ctx, entity, "burning", { stacks = 10 })  -- stacks = 15, time = 5s
```

**Use when:** More stacks = stronger effect (damage per second scales with stacks).

#### COUNT Mode

Adds stacks up to `max_stacks`. Duration is set once, doesn't reset on reapply.

```lua
StatusEffects.some_status = {
    id = "some_status",
    stack_mode = "count",          -- <-- COUNT mode
    max_stacks = 10,
    duration = 10,
}

-- Stacks accumulate, duration set on first apply only
StatusEngine.apply(ctx, entity, "some_status", { stacks = 3 })   -- stacks = 3, time = 10s
StatusEngine.apply(ctx, entity, "some_status", { stacks = 2 })   -- stacks = 5, time = 10s (no reset)
```

**Use when:** Counter-based effect with fixed window.

### DoT (Damage Over Time) System

DoT status effects automatically deal damage at intervals.

```lua
StatusEffects.electrocute = {
    id = "electrocute",
    dot_type = true,              -- <-- Mark as DoT
    damage_type = "lightning",
    stack_mode = "intensity",
    max_stacks = 99,
    duration = 5,
    base_dps = 5,               -- Damage per stack per second
    scaling = "linear",
}
```

**DoT Behavior:**
- Damage ticks every 1.0 second
- Damage per tick = `base_dps * stacks * tick_interval`
- Uses full damage pipeline (resists, armor, block, absorbs)
- Can trigger retaliation (OnHitResolved events)
- Source entity gets credit for kills

**Example:**
```lua
-- Apply 5 stacks of electrocute
StatusEngine.apply(ctx, enemy, "electrocute", { stacks = 5, source = player })

-- Damage calculation:
-- base_dps = 5, stacks = 5, tick = 1.0
-- Damage per tick = 5 * 5 * 1.0 = 25 lightning damage
```

### Stat Modifiers

Status effects can modify stats in two ways:

#### Fixed Modifiers (stat_mods)

Applied once when status is first applied (when stacks go from 0 to >0).

```lua
StatusEffects.barrier = {
    id = "barrier",
    stat_mods = { flat_absorb = 50 },   -- Fixed +50 absorb
}
```

#### Per-Stack Modifiers (stat_mods_per_stack)

Applied for each stack. Added when stacks increase, removed when stacks decrease.

```lua
StatusEffects.poise = {
    id = "poise",
    stat_mods_per_stack = {            -- Per stack
        armor = 5,                   -- +5 armor per stack
        offensive_ability = 2,          -- +2 offensive ability per stack
    },
}

-- 5 stacks = +25 armor, +10 offensive ability
StatusEngine.apply(ctx, entity, "poise", { stacks = 5 })
```

### Creating New Status Effects

Status effects are defined in `assets/scripts/data/status_effects.lua`:

```lua
local StatusEffects = {}

StatusEffects.my_custom_status = {
    id = "my_custom_status",           -- Unique ID
    stack_mode = "intensity",          -- Stacking behavior
    max_stacks = 10,                  -- Maximum stacks
    duration = 8,                     -- Duration in seconds

    -- Optional: DoT
    dot_type = true,
    damage_type = "fire",
    base_dps = 4,

    -- Optional: Stat modifiers
    stat_mods = {
        health = 50,
    },
    stat_mods_per_stack = {
        armor = 2,
    },

    -- Optional: Visuals
    icon = "status-my-status.png",
    icon_position = "above",
    show_stacks = true,
    shader = "fire_tint",
    shader_uniforms = { intensity = 0.4 },
}

return StatusEffects
```

**Status Type Options:**
- `dot_type = true`: Damage over time (burn, poison, electrocute)
- `is_mark = true`: Detonatable mark (static_charge, exposed)
- Neither: Simple buff/debuff (slowed, stunned)

### Marks (Detonatable Statuses)

Marks are special status effects that trigger when certain damage types hit the entity.

```lua
StatusEffects.static_charge = {
    id = "static_charge",
    is_mark = true,                    -- <-- Mark type

    -- What triggers detonation
    trigger = "lightning",             -- Damage type: "lightning", "fire", "any", "on_damaged"

    -- Passive effects while marked
    vulnerable = 15,                  -- +15% damage taken

    -- Effects on detonation
    damage = 25,                      -- Bonus damage per stack
    chain = 150,                      -- Chain to marked enemies in range

    -- Meta
    max_stacks = 3,
    duration = 8,
}
```

**Trigger Options for Marks:**
- `"lightning"`, `"fire"`, etc.: Detonates when that damage type hits
- `"any"`: Detonates on any damage
- `"on_damaged"`: Detonates when THIS entity takes damage (defensive marks)
- `{ "fire", "lightning" }`: Array of damage types (any of them triggers)
- `function(hit)`: Custom function returning true to detonate

**Example - Defensive Mark:**
```lua
StatusEffects.static_shield = {
    id = "static_shield",
    is_mark = true,
    trigger = "on_damaged",            -- <-- Trigger when holder is hit

    -- Passive while active
    block = 15,

    -- On trigger (when hit)
    damage = 25,                      -- Deal 25 lightning to attacker
    chain = 120,                      -- Chain to others
    apply = "static_charge",           -- Apply mark to attacker

    -- Meta
    max_stacks = 1,
    duration = 6,
    uses = 3,                        -- Trigger up to 3 times
}
```

---

## 3. Equipment API

### Quick Start

```lua
local Equipment = require("data.equipment")
local Items = require("combat.combat_system").Items

-- Equip an item
local sword = Equipment.flaming_sword
local ok, err = Items.equip(ctx, player, sword)

-- Unequip from slot
Items.unequip(ctx, player, "main_hand")

-- Check what's equipped
local equipped = Items.get_equipped(player, "main_hand")
```

### Equipment Slots

| Slot | Description | Example Items |
|-------|-------------|----------------|
| `main_hand` | Primary weapon | swords, staffs, wands |
| `off_hand` | Shield or secondary weapon | shields, daggers, tomes |
| `head` | Helmet or headgear | helmets, crowns, masks |
| `chest` | Body armor | breastplates, robes |
| `glove` | Gloves or gauntlets | gloves, gauntlets |
| `necklace` | Amulet or necklace | amulets, pendants |
| `ring1` | First ring slot | rings |
| `ring2` | Second ring slot | rings |
| `boots` | Footwear | boots, shoes |
| `pants` | Leg armor | pants, leggings |

### Equipment Structure

```lua
local Equipment = {}

Equipment.flaming_sword = {
    id = "flaming_sword",                  -- Unique identifier
    name = "Flaming Sword",                -- Display name
    slot = "main_hand",                   -- Equipment slot
    rarity = "Rare",                      -- Rarity tier

    -- Direct stat modifiers
    stats = {
        weapon_min = 50,                  -- Min damage
        weapon_max = 80,                  -- Max damage
        fire_damage = 20,                  -- Bonus fire damage
        attack_speed = 0.1,               -- +10% attack speed
    },

    -- Attribute requirements
    requires = {
        attribute = "physique",            -- Required attribute
        value = 20,                       -- Minimum value
        mode = "sole",                    -- "sole" = only this attribute, "with_other" = allows others
    },

    -- Proc effects (trigger-based)
    procs = {
        {
            trigger = Triggers.COMBAT.ON_HIT,
            chance = 30,                  -- 30% chance to proc
            effect = function(ctx, src, ev)
                -- Apply burning on hit
                StatusEngine.apply(ctx, ev.target, "burning", {
                    stacks = 3,
                    source = src,
                })
            end,
        },
    },

    -- Damage conversions
    conversions = {
        { from = "physical", to = "fire", pct = 50 },  -- Convert 50% physical to fire
    },
}
```

### Proc System

Procs are trigger-based effects that equipment can have.

**Proc Entry Structure:**
```lua
{
    trigger = Triggers.COMBAT.ON_HIT,    -- Which trigger to subscribe to
    chance = 30,                       -- Chance to trigger (0-100), omitted = 100%
    filter = function(ev)               -- Optional filter (default: only proc when ev.source == owner)
        return ev.damage_type == "fire"  -- Only proc on fire damage
    end,
    effect = function(ctx, src, ev)     -- Effect function
        -- ctx: Combat context
        -- src: Entity wearing the equipment (owner)
        -- ev: Event data (varies by trigger)
        applyEffects(ev.target)
    end,
}
```

**Proc Example - On Hit Apply Status:**
```lua
{
    trigger = Triggers.COMBAT.ON_HIT,
    chance = 30,
    effect = function(ctx, src, ev)
        StatusEngine.apply(ctx, ev.target, "burning", {
            stacks = 3,
            source = src,
        })
    end,
}
```

**Proc Example - On Kill Spread Status:**
```lua
{
    trigger = Triggers.COMBAT.ON_KILL,
    effect = function(ctx, src, ev)
        local Q = require("core.Q")
        if ctx.get_enemies_of then
            local enemies = ctx.get_enemies_of(src)
            for _, e in ipairs(enemies) do
                if Q.isInRange(src, e, 100) then
                    StatusEngine.apply(ctx, e, "burning", {
                        stacks = 5,
                        source = src,
                    })
                end
            end
        end
    end,
}
```

**Proc Example - Low Health Trigger:**
```lua
{
    trigger = Triggers.RESOURCE.ON_LOW_HEALTH,
    effect = function(ctx, src, ev)
        StatusEngine.apply(ctx, src, "fortify", {
            stacks = 5,
            source = src,
            duration = 5,
        })
    end,
}
```

### Damage Conversions

Conversions transform one damage type into another.

```lua
conversions = {
    { from = "physical", to = "fire", pct = 50 },  -- Convert 50% physical to fire
    { from = "lightning", to = "void", pct = 100 }, -- Convert all lightning to void
}
```

**How Conversions Work:**
- Conversions are applied in order
- Percent of damage is converted from `from` type to `to` type
- Converted damage respects the target's resistance to the new type
- Conversions are stored on entity in `e.gear_conversions`

**Example:**
```lua
-- Sword: 50-100 physical damage
-- Equipment: 20 fire damage, 50% physical → fire conversion

-- On hit calculation:
-- Base: 50-100 physical
-- After conversion: 25-50 physical, 25-50 fire
-- Add flat: +20 fire damage
-- Total: 25-50 physical, 45-70 fire
```

### Equipment Helper Functions

```lua
local Equipment = require("data.equipment")

-- Get equipment by ID
local sword = Equipment.get("flaming_sword")

-- Get all equipment
local allItems = Equipment.getAll()

-- Get equipment by slot
local helmets = Equipment.getBySlot("head")

-- Get equipment by rarity
local rareItems = Equipment.getByRarity("Rare")
```

### Equipment Lifecycle

#### equip()

```lua
local ok, err = Items.equip(ctx, entity, item)
```

**What happens on equip:**
1. Validates requirements (attribute checks)
2. If slot is occupied, automatically unequips old item
3. Applies stat modifiers (tracked for reversal)
4. Installs damage conversions
5. Subscribes proc handlers to event bus
6. Grants active spells (if any)
7. Recomputes entity stats
8. Calls optional `item.on_equip()` hook

**Returns:**
- `ok`: Boolean success/failure
- `err`: Error message string if failed

```lua
local sword = Equipment.flaming_sword
local ok, err = Items.equip(ctx, player, sword)

if not ok then
    print("Failed to equip:", err)
end
```

#### unequip()

```lua
Items.unequip(ctx, entity, slot)
```

**What happens on unequip:**
1. Removes stat modifiers (perfect reversal of what was added)
2. Removes damage conversions
3. Unsubscribes all proc handlers
4. Removes active spells (if any)
5. Recomputes entity stats
6. Calls optional `item.on_unequip()` hook

```lua
Items.unequip(ctx, player, "main_hand")
```

### Equipment with Custom Hooks

```lua
Equipment.custom_amulet = {
    id = "custom_amulet",
    name = "Custom Amulet",
    slot = "necklace",

    stats = {
        health = 100,
    },

    -- Called on equip (can return cleanup function)
    on_equip = function(ctx, entity)
        print("Amulet equipped!")
        -- Setup something that needs cleanup
        local handler = signal.register("on_player_death", function()
            print("Amulet dropped!")
        end)
        -- Return cleanup function
        return function()
            signal.unregister("on_player_death", handler)
        end
    end,

    -- Called on unequip
    on_unequip = function(ctx, entity)
        print("Amulet unequipped!")
    end,
}
```

### Set Bonuses (Optional)

While not built-in, you can implement set bonuses by tracking equipped items:

```lua
-- Example: Track set bonuses
local function checkSetBonuses(ctx, entity)
    local equipped = entity.equipped or {}
    local hasSetItem = false

    for slot, item in pairs(equipped) do
        if item.set == "flaming" then
            hasSetItem = true
        end
    end

    if hasSetItem then
        StatusEngine.apply(ctx, entity, "burning", { stacks = 1, duration = 9999 })
    end
end

-- Call after equip/unequip
local originalEquip = Items.equip
Items.equip = function(ctx, entity, item)
    local ok, err = originalEquip(ctx, entity, item)
    if ok then
        checkSetBonuses(ctx, entity)
    end
    return ok, err
end
```

---

## 4. Examples

### Example 1: Create a Fire Mage Staff

```lua
local Triggers = require("data.triggers")
local StatusEngine = require("combat.combat_system").StatusEngine

Equipment.fire_mage_staff = {
    id = "fire_mage_staff",
    name = "Fire Mage Staff",
    slot = "main_hand",
    rarity = "Epic",

    stats = {
        weapon_min = 60,
        weapon_max = 100,
        fire_damage = 30,
        cast_speed = 0.2,
    },

    requires = { attribute = "spirit", value = 25, mode = "sole" },

    procs = {
        {
            trigger = Triggers.COMBAT.ON_SPELL_CAST,
            chance = 20,
            effect = function(ctx, src, ev)
                -- Apply burning to target
                if ev.target then
                    StatusEngine.apply(ctx, ev.target, "burning", {
                        stacks = 5,
                        source = src,
                    })
                end
            end,
        },
        {
            trigger = Triggers.COMBAT.ON_KILL,
            effect = function(ctx, src, ev)
                -- Heal on kill
                if src.hp and src.max_health then
                    src.hp = math.min(src.hp + 20, src.max_health)
                end
            end,
        },
    },

    conversions = {
        { from = "physical", to = "fire", pct = 30 },
    },
}
```

### Example 2: Create a Defensive Shield

```lua
Equipment.thorned_shield = {
    id = "thorned_shield",
    name = "Thorned Shield",
    slot = "off_hand",
    rarity = "Uncommon",

    stats = {
        armor = 50,
        block_chance_pct = 15,
        shield_block = 100,
    },

    requires = { attribute = "physique", value = 20, mode = "sole" },

    procs = {
        {
            trigger = Triggers.DEFENSIVE.ON_BLOCK,
            effect = function(ctx, src, ev)
                -- Deal damage back to attacker
                StatusEngine.apply(ctx, ev.attacker, "bleed", {
                    stacks = 2,
                    source = src,
                })
            end,
        },
        {
            trigger = Triggers.DEFENSIVE.ON_BEING_HIT,
            chance = 10,
            effect = function(ctx, src, ev)
                -- Chance to gain armor on hit
                StatusEngine.apply(ctx, src, "fortify", {
                    stacks = 1,
                    source = src,
                    duration = 3,
                })
            end,
        },
    },
}
```

### Example 3: Create a Custom Status Effect with Particles

```lua
local Particles = require("core.particles")

StatusEffects.void_touched = {
    id = "void_touched",
    stack_mode = "intensity",
    max_stacks = 10,
    duration = 6,
    stat_mods_per_stack = {
        void_modifier_pct = 5,
        damage_taken_reduction_pct = 2,
    },

    -- Visuals
    icon = "status-void.png",
    icon_position = "above",
    show_stacks = true,
    shader = "void_tint",
    shader_uniforms = { intensity = 0.3 },

    -- Particles
    particles = function()
        return Particles.define()
            :shape("circle")
            :size(2, 4)
            :color("purple", "black")
            :velocity(20, 40)
            :lifespan(0.2, 0.3)
            :fade()
    end,
    particle_rate = 0.15,
}
```

### Example 4: Respond to Multiple Triggers

```lua
local signal_group = require("core.signal_group")
local Triggers = require("data.triggers")

-- Create handler group for cleanup
local combatHandlers = signal_group.new("enemy_ai")

-- On taking damage, check health
combatHandlers:on(Triggers.DEFENSIVE.ON_BEING_HIT, function(target, data)
    if target.hp < target.max_health * 0.3 then
        -- Enraged! Apply buff
        local StatusEngine = require("combat.combat_system").StatusEngine
        StatusEngine.apply(ctx, target, "bloodrage", {
            stacks = 5,
            source = target,
        })
    end
end)

-- On low health, heal self
combatHandlers:on(Triggers.RESOURCE.ON_LOW_HEALTH, function(entity, data)
    local StatusEngine = require("combat.combat_system").StatusEngine
    StatusEngine.apply(ctx, entity, "inflame", {
        stacks = 3,
        source = entity,
        duration = 8,
    })
end)

-- Later, cleanup all handlers
combatHandlers:cleanup()
```

### Example 5: Equipment with Conditional Proc

```lua
Equipment.executioner_axe = {
    id = "executioner_axe",
    name = "Executioner's Axe",
    slot = "main_hand",
    rarity = "Legendary",

    stats = {
        weapon_min = 80,
        weapon_max = 120,
        attack_speed = 0.15,
    },

    procs = {
        {
            trigger = Triggers.COMBAT.ON_HIT,
            -- Filter: only proc on low health targets
            filter = function(ev)
                return ev.target and ev.target.hp and ev.target.max_health and
                       ev.target.hp < (ev.target.max_health * 0.2)
            end,
            effect = function(ctx, src, ev)
                -- Deal bonus damage to low health targets
                local Effects = require("combat.combat_system").Effects
                Effects.deal_damage({
                    components = { { type = "physical", amount = 50 } },
                    tags = { execution = true },
                })(ctx, src, ev.target)
            end,
        },
    },
}
```

### Example 6: Mark and Detonate Combo

```lua
local Triggers = require("data.triggers")
local StatusEngine = require("combat.combat_system").StatusEngine

Equipment.lightning_staff = {
    id = "lightning_staff",
    name = "Lightning Staff",
    slot = "main_hand",
    rarity = "Rare",

    stats = {
        weapon_min = 50,
        weapon_max = 80,
        lightning_damage = 25,
    },

    procs = {
        {
            trigger = Triggers.COMBAT.ON_HIT,
            chance = 25,
            effect = function(ctx, src, ev)
                -- Apply static_charge mark
                StatusEngine.apply(ctx, ev.target, "static_charge", {
                    stacks = 1,
                    source = src,
                })
            end,
        },
    },
}

-- Static charge mark definition (in status_effects.lua)
StatusEffects.static_charge = {
    id = "static_charge",
    is_mark = true,
    trigger = "lightning",  -- Detonates on lightning damage
    damage = 25,            -- Bonus damage per stack on detonation
    chain = 150,            -- Chain to marked enemies in range
    vulnerable = 15,        -- +15% damage taken while marked
    max_stacks = 3,
    duration = 8,
}

-- Usage:
-- 1. Hit with staff -> applies static_charge mark (25% chance)
-- 2. Hit again with lightning damage -> mark detonates for 25 bonus damage per stack
-- 3. Chains to other marked enemies within 150 pixels
```

---

## See Also

- [Combat README](../systems/combat/README.md) - Combat system overview
- [Status Effects Data](../../assets/scripts/data/status_effects.lua) - All status definitions
- [Equipment Data](../../assets/scripts/data/equipment.lua) - All equipment definitions
- [Triggers Data](../../assets/scripts/data/triggers.lua) - All trigger constants
- [Signal System](signal_system.md) - Event system and signal_group cleanup
