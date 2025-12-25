# Lightning System Enhancement Design

**Date:** 2025-12-25
**Status:** Approved
**Goal:** Add Status Effects, Mark/Combo System, and Defensive/Counter mechanics using Chain Lightning as the testbed.

---

## Overview

This design introduces three interconnected systems to maximize build variety:

1. **Status Effects** - DoTs with visual indicators (electrocute, burn, etc.)
2. **Mark/Combo System** - "Setup + Payoff" gameplay with detonatable marks
3. **Defensive/Counter** - Reactive abilities that trigger when taking damage

All three systems are demonstrated through a cohesive "Lightning Package" including cards, jokers, an origin, and avatar enhancements.

---

## System 1: Status Effects with Visual Indicators

### Status Effect Definition

New file: `assets/scripts/data/status_effects.lua`

```lua
local Particles = require("core.particles")

local StatusEffects = {
    electrocute = {
        id = "electrocute",
        dot_type = true,

        -- Visual indicator (sprite icon)
        indicator = {
            sprite = "status-electrocute.png",
            position = "above",
            offset = { x = 0, y = -12 },
            scale = 0.5,
            bob = true,
        },

        -- Entity shader effect
        shader = {
            name = "electric_crackle",
            uniforms = { intensity = 0.6 },
        },

        -- Looping particles
        particles = {
            definition = function()
                return Particles.define()
                    :shape("line")
                    :size(2, 4)
                    :color("cyan", "white")
                    :velocity(30, 60)
                    :lifespan(0.15, 0.25)
                    :fade()
            end,
            rate = 0.1,
            orbit = true,
        },
    },

    burning = {
        id = "burning",
        dot_type = true,
        indicator = { sprite = "status-burn.png", position = "above" },
        shader = { name = "fire_tint", uniforms = { intensity = 0.4 } },
    },

    frozen = {
        id = "frozen",
        dot_type = false,
        indicator = { sprite = "status-frozen.png", position = "above" },
        shader = { name = "ice_tint", uniforms = { intensity = 0.7 } },
    },
}

return StatusEffects
```

### Status Indicator System

New file: `assets/scripts/systems/status_indicator_system.lua`

```lua
local StatusIndicatorSystem = {
    active_indicators = {},  -- { [entity] = { [status_id] = indicator_data } }
    MAX_FLOATING_ICONS = 2,
}

function StatusIndicatorSystem.show(entity, status_id, duration)
    -- Create indicator entity as child of target
    -- Start shader effect if defined
    -- Begin particle emitter if defined
    -- Schedule removal after duration
end

function StatusIndicatorSystem.hide(entity, status_id)
    -- Remove indicator sprite
    -- Remove shader effect
    -- Stop particle emitter
end

function StatusIndicatorSystem.updateDisplay(entity)
    local statuses = self.active_indicators[entity]
    local count = table_length(statuses)

    if count <= self.MAX_FLOATING_ICONS then
        -- Show individual floating icons, hide bar
        self:showFloatingIcons(entity, statuses)
        self:hideStatusBar(entity)
    else
        -- Hide floating icons, show condensed bar
        self:hideFloatingIcons(entity)
        self:showStatusBar(entity, statuses)
    end
end

function StatusIndicatorSystem.update(dt)
    -- Update bob animations
    -- Manage particle spawning
    -- Check for expired/dead entities
end

return StatusIndicatorSystem
```

### Display Logic

- **1-2 statuses:** Floating icons above entity
- **3+ statuses:** Condensed horizontal bar with mini-icons

```
     [icon][icon][icon][icon]     <- Condensed bar (3+ statuses)
            Entity

     [Icon]                       <- Floating icon (1-2 statuses)
     Entity
```

### Integration with ActionAPI

In `assets/scripts/combat/action_api.lua`, modify `apply_dot`:

```lua
function ActionAPI.apply_dot(ctx, source, target, damage_type, dps, duration, tick_rate)
    -- Existing DoT application logic...

    -- NEW: Show visual indicator
    local StatusIndicatorSystem = require("systems.status_indicator_system")
    local target_entity = target.entity or target  -- Handle actor vs entity
    StatusIndicatorSystem.show(target_entity, damage_type, duration)
end
```

---

## System 2: Mark/Combo System

### Mark Definition (Flat Key-Value)

Marks are defined in `status_effects.lua` with simple flat keys:

```lua
StatusEffects.static_charge = {
    -- What pops it (required)
    trigger = "lightning",           -- damage type, "any", or function

    -- While active (all optional, flat numbers)
    slow = 0,                        -- % movement speed reduction
    vulnerable = 15,                 -- % extra damage taken
    weaken = 0,                      -- % reduced damage dealt

    -- On pop (all optional, flat values)
    damage = 25,                     -- Bonus damage (per stack)
    stun = 0,                        -- Stun duration
    apply = nil,                     -- Apply another status on pop
    chain = 150,                     -- Chain range to other marked enemies
    radius = 0,                      -- AoE radius on pop

    -- Meta
    max_stacks = 3,
    duration = 8,

    -- Visual
    icon = "mark-static-charge.png",
    show_stacks = true,
}
```

### Trigger Options

| Value | Meaning |
|-------|---------|
| `"lightning"` | Damage type matches |
| `"fire"` | Damage type matches |
| `{ "fire", "lightning" }` | Any of these types |
| `"any"` | Any damage pops it |
| `"on_damaged"` | When THIS entity takes damage (for defensive marks) |
| `function(hit)` | Custom logic, return true to pop |

### Callback Escape Hatch

For complex behavior, use optional callbacks:

```lua
StatusEffects.weird_mark = {
    trigger = "physical",

    -- Optional: runs every frame while mark exists
    on_tick = function(target, stacks, dt)
        -- Custom passive behavior
    end,

    -- Optional: runs when mark pops
    on_pop = function(target, stacks, source, hit)
        -- Full control: spawn projectiles, teleport, heal, etc.
    end,
}
```

### Detonation Processing

In combat damage pipeline:

```lua
function processDamage(source, target, amount, damage_type, tags)
    local marks = target.marks or {}

    for mark_id, mark_data in pairs(marks) do
        local def = StatusEffects[mark_id]
        if shouldDetonate(def, damage_type, tags) then
            -- Apply passive vulnerable bonus
            if def.vulnerable then
                amount = amount * (1 + def.vulnerable / 100)
            end

            -- Apply detonate damage
            if def.damage then
                amount = amount + (def.damage * (mark_data.stacks or 1))
            end

            -- Apply other effects
            if def.stun and def.stun > 0 then
                ActionAPI.apply_stun(ctx, target, def.stun)
            end
            if def.apply then
                applyMark(target, def.apply, 1)
            end
            if def.chain and def.chain > 0 then
                chainToMarkedEnemies(target, mark_id, def.chain)
            end

            -- Run custom callback if defined
            if def.on_pop then
                def.on_pop(target, mark_data.stacks, source, hit)
            end

            -- Consume mark
            mark_data.stacks = mark_data.stacks - 1
            if mark_data.stacks <= 0 then
                marks[mark_id] = nil
            end
        end
    end

    applyDamage(target, amount, damage_type)
end
```

### Example Marks

```lua
-- Fire + Ice interaction
StatusEffects.heat_buildup = {
    trigger = "ice",
    vulnerable = 25,
    damage = 40,
    radius = 60,
    icon = "mark-heat.png",
}

-- Simple vulnerability
StatusEffects.exposed = {
    trigger = "any",
    vulnerable = 30,
    duration = 5,
    icon = "mark-exposed.png",
}

-- Poison + Fire combo
StatusEffects.oil_slick = {
    trigger = "fire",
    slow = 40,
    damage = 50,
    apply = "burning",
    radius = 80,
    icon = "mark-oil.png",
}
```

---

## System 3: Defensive/Counter Marks

Defensive marks use `trigger = "on_damaged"` variants:

```lua
StatusEffects.static_shield = {
    trigger = "on_damaged",          -- Pops when player takes damage

    -- Passive while active
    block = 15,                      -- Block 15 damage per hit

    -- On pop
    damage = 25,                     -- Counter-attack damage
    chain = 120,                     -- Chains to nearby enemies
    apply = "static_charge",         -- Marks the attacker

    max_stacks = 1,
    duration = 6,
    uses = 3,                        -- Pops up to 3 times

    icon = "mark-static-shield.png",
}

StatusEffects.mirror_ward = {
    trigger = "on_damaged",
    reflect = 50,                    -- Reflect 50% damage back
    duration = 4,
    uses = -1,                       -- Unlimited uses
    icon = "mark-mirror.png",
}

StatusEffects.mana_barrier = {
    trigger = "on_damaged",
    absorb_to_mana = 0.5,            -- 50% damage becomes mana
    block = 10,
    duration = 5,
    icon = "mark-mana-barrier.png",
}
```

### Defensive Trigger Variants

| Trigger | When it fires |
|---------|---------------|
| `"on_damaged"` | Any damage to this entity |
| `"on_damaged_projectile"` | Hit by projectile |
| `"on_damaged_melee"` | Hit by melee/collision |
| `"on_damaged_fire"` | Hit by fire damage specifically |

---

## Lightning Package: Content Definitions

### Cards

Add to `assets/scripts/data/cards.lua`:

```lua
-- Enhance existing chain lightning
Cards.ACTION_CHAIN_LIGHTNING = {
    id = "ACTION_CHAIN_LIGHTNING",
    type = "action",
    mana_cost = 8,
    damage = 12,
    damage_type = "lightning",
    projectile_speed = 500,
    lifetime = 2000,

    -- Chain fields
    chain_count = 3,
    chain_range = 150,
    chain_damage_mult = 0.5,

    -- NEW: Status effect application
    apply_status = "electrocute",
    status_dps = 5,
    status_duration = 3,

    tags = { "Lightning", "Arcane" },
    sprite = "action-chain-lightning.png",
}

-- Setup card: applies mark
Cards.ACTION_STATIC_CHARGE = {
    id = "ACTION_STATIC_CHARGE",
    type = "action",
    mana_cost = 4,
    damage = 5,
    damage_type = "lightning",
    projectile_speed = 600,
    lifetime = 1500,

    apply_mark = "static_charge",
    mark_duration = 8,

    tags = { "Lightning", "Debuff" },
    sprite = "action-static-charge.png",
}

-- Defensive counter
Cards.ACTION_STATIC_SHIELD = {
    id = "ACTION_STATIC_SHIELD",
    type = "action",
    mana_cost = 8,

    apply_mark = "static_shield",
    apply_to = "self",

    tags = { "Lightning", "Defense" },
    sprite = "action-static-shield.png",
}
```

### Jokers

Add to `assets/scripts/data/jokers.lua`:

```lua
Jokers.conductor = {
    id = "conductor",
    name = "The Conductor",
    description = "Chain lightning applies Static Charge. Mark detonations chain to other marked enemies.",
    rarity = "Rare",
    sprite = "joker-conductor.png",

    calculate = function(self, context)
        if context.event == "on_chain_hit" then
            return {
                apply_mark = "static_charge",
                message = "Charged!"
            }
        end

        if context.event == "on_mark_detonated" then
            return {
                chain_to_marked = 200,
                message = "Conducted!"
            }
        end
    end
}

Jokers.storm_battery = {
    id = "storm_battery",
    name = "Storm Battery",
    description = "+5% damage per Static Charge stack on any enemy.",
    rarity = "Uncommon",
    sprite = "joker-storm-battery.png",

    calculate = function(self, context)
        if context.event == "calculate_damage" and context.damage_type == "lightning" then
            local total_stacks = countMarksOnAllEnemies("static_charge")
            if total_stacks > 0 then
                return {
                    damage_mult = 1 + (total_stacks * 0.05),
                    message = string.format("Battery +%d%%", total_stacks * 5)
                }
            end
        end
    end
}

Jokers.arc_reactor = {
    id = "arc_reactor",
    name = "Arc Reactor",
    description = "Electrocute heals you for 2 HP per tick.",
    rarity = "Rare",
    sprite = "joker-arc-reactor.png",

    calculate = function(self, context)
        if context.event == "on_dot_tick" and context.dot_type == "electrocute" then
            return {
                heal_player = 2,
                message = "Arc Heal!"
            }
        end
    end
}
```

### Origin

Add to `assets/scripts/data/origins.lua`:

```lua
Origins.storm_caller = {
    name = "Storm Caller",
    description = "Born in the heart of the tempest.",
    tags = { "Lightning", "Arcane" },

    passive_stats = {
        lightning_modifier_pct = 15,
        chain_count_bonus = 1,
        electrocute_duration_pct = 20,
    },

    prayer = "thunderclap",

    tag_weights = {
        Lightning = 1.5,
        Arcane = 1.2,
    },

    starting_cards = {
        "ACTION_CHAIN_LIGHTNING",
        "ACTION_STATIC_CHARGE",
    },
}
```

### Prayer

Add to prayers data (or create new file):

```lua
Prayers.thunderclap = {
    id = "thunderclap",
    name = "Thunderclap",
    description = "Stun all nearby enemies and apply Static Charge.",
    cooldown = 15,

    on_cast = function(ctx, caster)
        local nearby = findEnemiesInRange(caster, 150)
        for _, enemy in ipairs(nearby) do
            ActionAPI.apply_stun(ctx, enemy, 1.5)
            applyMark(enemy, "static_charge", 1)
        end
        playSoundEffect("effects", "thunderclap")
    end
}
```

### Avatar Enhancement

Modify in `assets/scripts/data/avatars.lua`:

```lua
Avatars.stormlord = {
    name = "Avatar of the Storm",
    description = "Ride the lightning.",

    unlock = {
        electrocute_kills = 50,
        OR_lightning_tags = 7,
    },

    effects = {
        {
            type = "rule_change",
            rule = "crit_chains",
            desc = "Critical hits always Chain to a nearby enemy."
        },
        {
            type = "rule_change",
            rule = "chain_applies_marks",
            desc = "All chain effects apply Static Charge."
        },
        {
            type = "stat_buff",
            stat = "chain_count_bonus",
            value = 2
        },
        {
            type = "proc",
            trigger = "on_mark_detonated",
            effect = "electrocute_nearby",
            radius = 100
        }
    }
}
```

---

## Implementation Order

1. **Status Indicator System** - Core visual feedback
2. **Mark System** - Definition parsing and detonation logic
3. **Defensive Marks** - `on_damaged` trigger handling
4. **Lightning Cards** - Static Charge, Static Shield
5. **Lightning Jokers** - Conductor, Storm Battery, Arc Reactor
6. **Lightning Origin** - Storm Caller + Thunderclap prayer
7. **Avatar Enhancement** - Stormlord upgrades
8. **Chain Lightning Integration** - Apply electrocute + status visuals

---

## Files to Create/Modify

### New Files
- `assets/scripts/data/status_effects.lua`
- `assets/scripts/systems/status_indicator_system.lua`
- `assets/scripts/data/prayers.lua` (if doesn't exist)

### Modified Files
- `assets/scripts/data/cards.lua` - Add lightning cards
- `assets/scripts/data/jokers.lua` - Add lightning jokers
- `assets/scripts/data/origins.lua` - Add Storm Caller
- `assets/scripts/data/avatars.lua` - Enhance Stormlord
- `assets/scripts/combat/action_api.lua` - Indicator integration
- `assets/scripts/wand/wand_actions.lua` - Electrocute on chain hit

### New Assets Needed
- `status-electrocute.png`
- `status-burn.png`
- `mark-static-charge.png`
- `mark-static-shield.png`
- `action-static-charge.png`
- `action-static-shield.png`
- `joker-conductor.png`
- `joker-storm-battery.png`
- `joker-arc-reactor.png`

---

## System Interconnections

```
Origin (Storm Caller)
    ├── Starting cards: Chain Lightning + Static Charge
    ├── +15% lightning damage
    └── +1 chain target

Chain Lightning (Card)
    ├── Deals lightning damage
    ├── Applies Electrocute DoT ──────────────► StatusIndicatorSystem
    └── Triggers static_charge marks ─────────► Mark detonation

Static Charge (Mark)
    ├── +15% damage taken while marked
    ├── Detonated by lightning damage
    ├── +25 bonus damage per stack
    └── Chains to other marked enemies

Static Shield (Defensive Mark)
    ├── Blocks 15 damage
    ├── Counter-attacks on hit
    └── Applies static_charge to attackers

Conductor (Joker)
    ├── Chain hits apply static_charge
    └── Detonations chain further

Stormlord (Avatar)
    ├── Crits always chain
    ├── All chains apply marks
    └── Detonations electrocute nearby
```

---

## Testing Checklist

- [ ] Electrocute DoT shows floating icon above enemy
- [ ] 3+ statuses collapse into condensed bar
- [ ] Static Charge stacks display count on icon
- [ ] Lightning damage detonates static_charge marks
- [ ] Detonation bonus damage scales with stacks
- [ ] Static Shield triggers counter-attack when player hit
- [ ] Conductor joker applies marks on chain hits
- [ ] Storm Caller origin starts with correct cards
- [ ] Thunderclap prayer stuns and marks enemies
- [ ] Stormlord avatar crits trigger chains
