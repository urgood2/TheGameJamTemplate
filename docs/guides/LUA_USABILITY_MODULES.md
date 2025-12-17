# Lua Usability Modules

This guide covers three utility modules designed to reduce friction in Lua development:

1. **Schema** - Data validation & typo detection
2. **TimerScope** - Scoped timer management with auto-cleanup
3. **CardFactory** - Declarative card definition DSL

All modules are **opt-in** and don't affect existing code.

---

## Table of Contents

- [Schema Validation](#schema-validation)
  - [Basic Usage](#schema-basic-usage)
  - [Checking vs Validating](#checking-vs-validating)
  - [Batch Validation](#batch-validation)
  - [Custom Schemas](#custom-schemas)
  - [Production Mode](#production-mode)
- [Timer Scope](#timer-scope)
  - [Basic Usage](#timerscope-basic-usage)
  - [Entity-Bound Scopes](#entity-bound-scopes)
  - [Scope Lifecycle](#scope-lifecycle)
  - [Common Patterns](#timerscope-patterns)
- [Card Factory](#card-factory)
  - [Basic Usage](#cardfactory-basic-usage)
  - [Type Presets](#type-presets)
  - [Custom Presets](#custom-presets)
  - [Migration Guide](#migration-guide)

---

## Schema Validation

`core/schema.lua` validates data tables at load time to catch:
- Missing required fields
- Wrong types
- Invalid enum values
- Unknown fields (typo detection)

### Schema Basic Usage

```lua
local Schema = require("core.schema")

-- Define a card
local my_card = {
    id = "FIREBALL",
    type = "action",
    tags = { "Fire", "Projectile" },
    damage = 25,
    mana_cost = 12,
}

-- Validate it
Schema.validate(my_card, Schema.CARD, "Card:FIREBALL")
-- Throws error if invalid, does nothing if valid
```

### Checking vs Validating

**`Schema.check()`** - Returns results without throwing:

```lua
local ok, errors, warnings = Schema.check(my_card, Schema.CARD)

if not ok then
    print("Errors:")
    for _, err in ipairs(errors) do
        print("  - " .. err)
    end
end

if #warnings > 0 then
    print("Warnings (possible typos):")
    for _, warn in ipairs(warnings) do
        print("  - " .. warn)
    end
end
```

**`Schema.validate()`** - Throws on error, logs warnings:

```lua
-- Will throw: "[Schema] Card:BAD validation failed: missing required field 'id'"
Schema.validate({ type = "action", tags = {} }, Schema.CARD, "Card:BAD")
```

### Catching Typos

Schema warns about unknown fields - perfect for catching typos:

```lua
local typo_card = {
    id = "OOPS",
    type = "action",
    tags = {},
    mana_cosy = 10,  -- Typo! Should be mana_cost
    damge = 25,      -- Typo! Should be damage
}

local ok, errors, warnings = Schema.check(typo_card, Schema.CARD)
-- ok = true (typos are warnings, not errors)
-- warnings = { "unknown field 'mana_cosy' (typo?)", "unknown field 'damge' (typo?)" }
```

### Batch Validation

Validate an entire table of items:

```lua
local Cards = {
    FIREBALL = { id = "FIREBALL", type = "action", tags = { "Fire" } },
    ICE_BOLT = { id = "ICE_BOLT", type = "action", tags = { "Ice" } },
    DAMAGE_UP = { id = "DAMAGE_UP", type = "modifier", tags = { "Buff" } },
}

-- Validates all cards, throws on first error
Schema.validateAll(Cards, Schema.CARD, "Card")
```

### Available Schemas

```lua
Schema.CARD       -- Cards (action, modifier, trigger)
Schema.JOKER      -- Joker definitions
Schema.PROJECTILE -- Projectile presets
Schema.ENEMY      -- Enemy definitions
```

### Custom Schemas

Create your own schemas for custom content:

```lua
local MySchema = {
    _name = "POWERUP",
    _fields = {
        id          = { type = "string",  required = true },
        name        = { type = "string",  required = true },
        duration    = { type = "number",  required = false },
        multiplier  = { type = "number",  required = false },
        rarity      = { type = "string",  required = true,
                        enum = { "common", "rare", "legendary" } },
    }
}

local powerup = { id = "SPEED_BOOST", name = "Speed Boost", rarity = "rare" }
Schema.validate(powerup, MySchema, "Powerup:SPEED_BOOST")
```

### Production Mode

Disable validation for performance in production:

```lua
-- At game startup
Schema.ENABLED = false  -- All validation calls become no-ops
```

---

## Timer Scope

`core/timer_scope.lua` provides scoped timer management with automatic cleanup.

### Why Use TimerScope?

**Problem:** Timer leaks when systems/entities are destroyed:
```lua
-- OLD WAY: Must manually track and cancel each timer
local my_timer_tag = timer.after(2.0, doSomething, "my_tag")
-- ... later, if entity dies, must remember to:
timer.cancel("my_tag")  -- Easy to forget!
```

**Solution:** Scoped timers auto-clean on destroy:
```lua
-- NEW WAY: All timers cleaned automatically
local scope = TimerScope.new("my_system")
scope:after(2.0, doSomething)
scope:every(0.5, updateLoop)
-- ... later:
scope:destroy()  -- All scoped timers cancelled at once
```

### TimerScope Basic Usage

```lua
local TimerScope = require("core.timer_scope")

-- Create a scope for your system/feature
local scope = TimerScope.new("enemy_ai")

-- Schedule timers (same API as timer module)
scope:after(2.0, function()
    print("Delayed action!")
end)

scope:every(0.5, function()
    print("Repeating action!")
end, 10)  -- 10 times max

-- Later, clean up everything
scope:destroy()
```

### Entity-Bound Scopes

Create scopes tied to specific entities:

```lua
local function setupEnemy(entity)
    -- Create scope for this enemy
    local scope = TimerScope.for_entity(entity)

    -- All timers are tied to this entity's lifecycle
    scope:after(1.0, function()
        -- Attack after 1 second
        performAttack(entity)
    end)

    scope:every(0.5, function()
        -- Update AI every 0.5 seconds
        updateAI(entity)
    end)

    -- Store scope for later cleanup
    local script = getScriptTableFromEntityID(entity)
    script.timerScope = scope
end

local function destroyEnemy(entity)
    local script = getScriptTableFromEntityID(entity)
    if script and script.timerScope then
        script.timerScope:destroy()  -- All enemy timers cancelled
    end
end
```

### Scope Lifecycle

```lua
local scope = TimerScope.new("my_scope")

-- Check if scope is active
print(scope:active())  -- true

-- Count active timers
scope:after(1.0, fn1)
scope:after(2.0, fn2)
print(scope:count())  -- 2

-- Cancel specific timer
local tag = scope:after(3.0, fn3, "my_tag")
scope:cancel("my_tag")
print(scope:count())  -- 2

-- Destroy cancels all
scope:destroy()
print(scope:active())  -- false
print(scope:count())   -- 0

-- Destroyed scopes reject new timers
local result = scope:after(1.0, fn4)
print(result)  -- nil
```

### TimerScope Patterns

**Pattern 1: System Lifecycle**
```lua
local MySystem = {}
local _scope

function MySystem.init()
    _scope = TimerScope.new("MySystem")
    _scope:every(1.0, MySystem.update)
end

function MySystem.shutdown()
    if _scope then
        _scope:destroy()
        _scope = nil
    end
end
```

**Pattern 2: State Machine**
```lua
local function enterCombatState(entity)
    -- Clean up previous state timers
    if entity.stateScope then
        entity.stateScope:destroy()
    end

    -- Create new scope for combat state
    entity.stateScope = TimerScope.new("combat_" .. entity.id)
    entity.stateScope:every(0.1, function()
        updateCombat(entity)
    end)
end

local function enterIdleState(entity)
    if entity.stateScope then
        entity.stateScope:destroy()
    end

    entity.stateScope = TimerScope.new("idle_" .. entity.id)
    entity.stateScope:every(2.0, function()
        lookAround(entity)
    end)
end
```

**Pattern 3: UI Animations**
```lua
local function showNotification(message)
    local scope = TimerScope.new("notification")

    -- Fade in
    scope:after(0.0, function() setAlpha(0) end)
    scope:after(0.1, function() setAlpha(0.5) end)
    scope:after(0.2, function() setAlpha(1.0) end)

    -- Stay visible
    scope:after(2.0, function()
        -- Fade out
        scope:after(0.0, function() setAlpha(0.7) end)
        scope:after(0.1, function() setAlpha(0.3) end)
        scope:after(0.2, function()
            setAlpha(0)
            scope:destroy()  -- Clean up
        end)
    end)

    return scope  -- Return so caller can cancel early if needed
end
```

---

## Card Factory

`core/card_factory.lua` reduces boilerplate when defining cards.

### Why Use CardFactory?

**Problem:** Repetitive card definitions with many default values:
```lua
-- OLD WAY: 20+ lines per card
Cards.FIREBALL = {
    id = "FIREBALL",              -- Must match key
    type = "action",
    tags = { "Fire", "Projectile" },
    test_label = "FIRE\nBALL",    -- Manual formatting
    mana_cost = 12,
    damage = 25,
    damage_type = "fire",
    projectile_speed = 500,       -- Default anyway
    lifetime = 2000,              -- Default anyway
    max_uses = -1,                -- Default anyway
    spread_angle = 0,             -- Default anyway
    cast_delay = 0,               -- Default anyway
    -- ... more defaults
}
```

**Solution:** Only specify what differs from defaults:
```lua
-- NEW WAY: 5 lines, same result
Cards.FIREBALL = CardFactory.create("FIREBALL", {
    type = "action",
    tags = { "Fire", "Projectile" },
    damage = 25,
    damage_type = "fire",
})
```

### CardFactory Basic Usage

```lua
local CardFactory = require("core.card_factory")

-- Create a single card
local fireball = CardFactory.create("FIREBALL", {
    type = "action",
    tags = { "Fire", "Projectile" },
    damage = 25,
    damage_type = "fire",
})

-- What you get:
-- {
--     id = "FIREBALL",           -- Auto-set from first param
--     type = "action",
--     tags = { "Fire", "Projectile" },
--     test_label = "FIREBALL",   -- Auto-generated
--     damage = 25,
--     damage_type = "fire",
--     mana_cost = 10,            -- Default
--     projectile_speed = 500,    -- Default
--     lifetime = 2000,           -- Default
--     max_uses = -1,             -- Default
--     ... other defaults
-- }
```

### Type Presets

Shortcuts for common card types:

```lua
-- Action/Projectile card
local bolt = CardFactory.projectile("ICE_BOLT", {
    damage = 20,
    damage_type = "ice",
    tags = { "Ice", "Projectile" },
})

-- Modifier card
local buff = CardFactory.modifier("DAMAGE_UP", {
    damage_modifier = 10,
    tags = { "Buff" },
})

-- Trigger card
local trap = CardFactory.trigger("EXPLODE_ON_HIT", {
    trigger_on_collision = true,
    tags = { "Trap" },
})
```

### Batch Processing

Process multiple cards at once:

```lua
local Cards = CardFactory.batch({
    FIREBALL = {
        type = "action",
        damage = 25,
        damage_type = "fire",
        tags = { "Fire", "Projectile" },
    },
    ICE_BOLT = {
        type = "action",
        damage = 20,
        damage_type = "ice",
        tags = { "Ice", "Projectile" },
    },
    DAMAGE_UP = {
        type = "modifier",
        damage_modifier = 10,
        tags = { "Buff" },
    },
})

-- All cards have id set and defaults applied
print(Cards.FIREBALL.id)        -- "FIREBALL"
print(Cards.ICE_BOLT.mana_cost) -- 10 (default)
```

### Custom Presets

Register reusable templates:

```lua
-- Register presets
CardFactory.register_presets({
    basic_fireball = {
        type = "action",
        damage_type = "fire",
        projectile_speed = 400,
        tags = { "Fire", "Projectile" },
    },
    homing_missile = {
        type = "action",
        homing_strength = 10,
        projectile_speed = 300,
        tags = { "Projectile", "Homing" },
    },
})

-- Use presets
local small_fire = CardFactory.from_preset("SMALL_FIRE", "basic_fireball", {
    damage = 15,
    mana_cost = 5,
})

local big_fire = CardFactory.from_preset("BIG_FIRE", "basic_fireball", {
    damage = 50,
    mana_cost = 20,
    radius_of_effect = 60,
})

local seeker = CardFactory.from_preset("SEEKER", "homing_missile", {
    damage = 30,
})
```

### Extending Base Cards

Create variants of existing cards:

```lua
-- Base definition
local base_spell = {
    type = "action",
    damage_type = "arcane",
    projectile_speed = 400,
    tags = { "Arcane" },
}

-- Variants
local weak_spell = CardFactory.extend("WEAK_SPELL", base_spell, {
    damage = 10,
    mana_cost = 5,
})

local strong_spell = CardFactory.extend("STRONG_SPELL", base_spell, {
    damage = 50,
    mana_cost = 25,
    tags = { "Arcane", "AoE" },  -- Override tags entirely
})
```

### With Schema Validation

Enable validation during development:

```lua
-- Validates against Schema.CARD, throws on error
local card = CardFactory.create("MY_CARD", {
    type = "action",
    tags = { "Fire" },
}, { validate = true })

-- Catches errors immediately
local bad_card = CardFactory.create("BAD", {
    type = "invalid_type",  -- Will throw!
    tags = {},
}, { validate = true })
```

### Migration Guide

**Before (existing cards.lua pattern):**
```lua
Cards.TEST_PROJECTILE = {
    id = "TEST_PROJECTILE",
    type = "action",
    max_uses = -1,
    mana_cost = 5,
    damage = 10,
    damage_type = "physical",
    radius_of_effect = 0,
    spread_angle = 5,
    projectile_speed = 500,
    lifetime = 2000,
    cast_delay = 100,
    recharge_time = 0,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    weight = 1,
    tags = { "Projectile" },
    test_label = "TEST\nprojectile",
}
```

**After (using CardFactory):**
```lua
Cards.TEST_PROJECTILE = CardFactory.projectile("TEST_PROJECTILE", {
    mana_cost = 5,
    damage = 10,
    spread_angle = 5,
    cast_delay = 100,
    tags = { "Projectile" },
})
-- All other fields use defaults, test_label auto-generated
```

**Gradual Migration:**
```lua
-- You can mix both styles in the same file
local CardFactory = require("core.card_factory")

-- Old style (still works)
Cards.OLD_CARD = {
    id = "OLD_CARD",
    type = "action",
    -- ... all fields explicit
}

-- New style
Cards.NEW_CARD = CardFactory.create("NEW_CARD", {
    type = "action",
    damage = 30,
    tags = { "Fire" },
})
```

---

## Quick Reference

### Schema

```lua
local Schema = require("core.schema")

-- Available schemas
Schema.CARD, Schema.JOKER, Schema.PROJECTILE, Schema.ENEMY

-- Check (returns results)
local ok, errors, warnings = Schema.check(data, schema)

-- Validate (throws on error)
Schema.validate(data, schema, "Name:ID")

-- Batch validate
Schema.validateAll(items_table, schema, "Prefix")

-- Production mode
Schema.ENABLED = false
```

### TimerScope

```lua
local TimerScope = require("core.timer_scope")

-- Create scope
local scope = TimerScope.new("name")
local scope = TimerScope.for_entity(entity_id)

-- Schedule timers
scope:after(delay, callback, tag?)
scope:every(delay, callback, times?, immediate?, after?, tag?)

-- Management
scope:cancel(tag)
scope:destroy()
scope:count()
scope:active()
```

### CardFactory

```lua
local CardFactory = require("core.card_factory")

-- Create cards
CardFactory.create(id, def, opts?)
CardFactory.projectile(id, def, opts?)
CardFactory.modifier(id, def, opts?)
CardFactory.trigger(id, def, opts?)

-- Batch
CardFactory.batch(cards_table, opts?)

-- Presets
CardFactory.register_presets(presets_table)
CardFactory.from_preset(id, preset_name, overrides?, opts?)

-- Extend
CardFactory.extend(id, base_def, overrides, opts?)

-- Options
{ validate = true }  -- Enable schema validation
```

---

## See Also

- [Content Creation Guide](../content-creation/README.md) - Full card/joker/projectile docs
- [Timer System](../api/timer.md) - Core timer API
- [Troubleshooting](../TROUBLESHOOTING.md) - Common issues
