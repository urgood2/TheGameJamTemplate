# Wand Execution Engine Architecture

## Overview

The Wand Execution Engine connects the card evaluation system (Task 1) with the projectile system (Task 2), providing a complete pipeline from card definitions to actual gameplay effects.

## System Components

```
┌─────────────────────────────────────────────────────────────┐
│                    WAND EXECUTION PIPELINE                   │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐      ┌──────────────┐                     │
│  │   Trigger    │─────>│    Wand      │                     │
│  │    System    │      │   Executor   │                     │
│  └──────────────┘      └──────┬───────┘                     │
│         │                     │                              │
│         │                     v                              │
│         │            ┌────────────────┐                      │
│         │            │  Card          │                      │
│         └───────────>│  Evaluator     │                      │
│                      │  (existing)    │                      │
│                      └────────┬───────┘                      │
│                               │                              │
│                               v                              │
│                      ┌────────────────┐                      │
│                      │   Modifier     │                      │
│                      │  Application   │                      │
│                      └────────┬───────┘                      │
│                               │                              │
│                               v                              │
│                      ┌────────────────┐                      │
│                      │    Action      │                      │
│                      │   Execution    │                      │
│                      └────────┬───────┘                      │
│                               │                              │
│                               v                              │
│                      ┌────────────────┐                      │
│                      │  Projectile    │                      │
│                      │    System      │                      │
│                      │  (Task 1)      │                      │
│                      └────────────────┘                      │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Trigger Activation
```lua
-- Timer-based trigger
Trigger: "every_N_seconds" -> WandExecutor.execute(wandId)

-- Event-based trigger
Event: "player_pressed_attack" -> WandExecutor.execute(wandId)
Event: "on_bump_enemy" -> WandExecutor.execute(wandId)
```

### 2. Wand Execution
```lua
WandExecutor.execute(wandId) ->
  1. Check cooldown & mana
  2. Call card evaluator (simulate_wand from card_eval_order_test.lua)
  3. Receive cast blocks with actions + modifiers
  4. Execute each cast block sequentially
```

### 3. Cast Block Execution
```lua
For each cast block:
  1. Aggregate modifiers
  2. For each action card:
     a. Apply modifiers to action
     b. Execute action (spawn projectile, apply effect, etc.)
     c. Handle sub-cast blocks (timers, triggers)
  3. Apply cast delay
  4. Track state for next block
```

### 4. Action Execution
```lua
Action Card -> Action Executor ->
  - Projectile actions: Spawn via ProjectileSystem.spawn()
  - Effect actions: Apply buffs/debuffs via combat system
  - Hazard actions: Create AoE zones
  - Utility actions: Teleport, heal, summon
  - Meta actions: Recast, add mana, etc.
```

## Core Data Structures

### WandState
```lua
{
  wandId = string,

  -- Cooldown tracking
  cooldownRemaining = number,      -- seconds
  lastCastTime = number,           -- timestamp

  -- Charge tracking
  charges = number,                -- current charges
  maxCharges = number,             -- max charges
  chargeRegenTime = number,        -- seconds per charge
  lastChargeTime = number,         -- timestamp

  -- Cast execution state
  currentBlockIndex = number,      -- which cast block we're on
  deckIndex = number,              -- position in deck
  isRecharging = boolean,          -- waiting for full recharge

  -- Mana tracking
  currentMana = number,
  maxMana = number,
  manaRegenRate = number,          -- per second

  -- Runtime state
  activeCastBlocks = {},           -- queued cast blocks
  pendingSubCasts = {},            -- delayed/triggered sub-casts
}
```

### ExecutionContext
```lua
{
  wandState = WandState,
  wandDefinition = table,          -- from card_eval_order_test
  playerEntity = entity_id,
  playerPosition = {x, y},
  playerAngle = number,            -- facing direction
  timestamp = number,              -- current time

  -- Helper functions
  getPlayerPosition = function,
  getPlayerFacingAngle = function,
  findNearestEnemy = function,
  canAffordCast = function,
}
```

### ModifierAggregate
```lua
{
  -- Speed modifiers
  speedMultiplier = number,        -- 1.0 = normal

  -- Damage modifiers
  damageMultiplier = number,       -- 1.0 = normal
  damageBonus = number,            -- flat bonus

  -- Size modifiers
  sizeMultiplier = number,

  -- Lifetime modifiers
  lifetimeMultiplier = number,

  -- Behavior modifiers
  pierceCount = number,
  bounceCount = number,
  explosionRadius = number,
  homingEnabled = boolean,
  homingStrength = number,

  -- Multicast
  multicastCount = number,
  circularPattern = boolean,
  spreadAngle = number,

  -- On-hit effects
  onHitEffects = {},               -- list of effect cards
  freezeOnHit = boolean,
  chainLightning = boolean,
  lifesteal = number,

  -- Trigger chaining
  triggerOnCollision = boolean,
  triggerOnTimer = number,
  triggerOnDeath = boolean,
  nextCastBlock = table,           -- sub-cast to execute
}
```

## Module Breakdown

### 1. wand_executor.lua
**Responsibilities:**
- Main execution orchestrator
- Wand state management
- Cooldown tracking
- Mana/charge tracking
- Cast block sequencing

**Key Functions:**
```lua
WandExecutor.init()
WandExecutor.update(dt)
WandExecutor.execute(wandId, triggerId)
WandExecutor.canCast(wandId)
WandExecutor.getWandState(wandId)
WandExecutor.resetWand(wandId)
```

### 2. wand_triggers.lua
**Responsibilities:**
- Trigger registration and activation
- Timer-based triggers
- Event-based triggers
- Trigger condition checking

**Key Functions:**
```lua
WandTriggers.register(wandId, triggerDef)
WandTriggers.update(dt)
WandTriggers.handleEvent(eventName, eventData)
WandTriggers.checkCondition(wandId, triggerDef)
```

**Trigger Types:**
- `every_N_seconds`: Timer-based, fires every N seconds
- `on_cooldown`: Timer-based, fires when off cooldown
- `on_player_attack`: Event-based, fires on attack input
- `on_bump_enemy`: Event-based, collision detection
- `on_dash`: Event-based, dash input
- `on_distance_traveled`: Event-based, movement tracking
- `on_pickup`: Event-based, item pickup
- `on_low_health`: Condition-based, health threshold

### 3. wand_actions.lua
**Responsibilities:**
- Action card execution
- Projectile spawning via ProjectileSystem
- Effect application
- Hazard creation
- Utility actions

**Key Functions:**
```lua
WandActions.execute(actionCard, modifiers, context)
WandActions.spawnProjectile(actionCard, modifiers, context)
WandActions.applyEffect(actionCard, modifiers, context)
WandActions.createHazard(actionCard, modifiers, context)
WandActions.summonEntity(actionCard, modifiers, context)
```

**Action Types:**
- **Projectile Actions**: Spawn projectiles with modifiers
- **Effect Actions**: Buffs, debuffs, healing
- **Hazard Actions**: AoE zones, spike traps
- **Utility Actions**: Teleport, shield, summon
- **Meta Actions**: Add mana, recast, wand refresh

### 4. wand_modifiers.lua
**Responsibilities:**
- Modifier aggregation from card stack
- Modifier application to actions
- Multicast handling
- On-hit effect tracking

**Key Functions:**
```lua
WandModifiers.aggregate(modifierCards)
WandModifiers.apply(modifiers, actionCard)
WandModifiers.getCollisionBehavior(modifiers)
WandModifiers.expandMulticast(modifiers, baseAngle)
```

**Modifier Categories:**
- **Speed**: Increase/decrease projectile speed
- **Damage**: Multiply/add damage
- **Size**: Scale projectile size
- **Lifetime**: Extend/reduce lifetime
- **Behavior**: Pierce, bounce, explode, homing
- **Multicast**: Cast N spells, circular patterns
- **On-Hit**: Effects triggered by projectile hits
- **Trigger**: Chain casting on events

## Integration Points

### With Card Evaluation System
```lua
-- Use existing simulate_wand function
local cardEval = require("core.card_eval_order_test")
local result = cardEval.simulate_wand(wandDef, cardPool)

-- result contains:
-- - blocks: array of cast blocks
-- - total_cast_delay: cumulative delay
-- - total_recharge_time: cumulative recharge
-- - card_execution: execution status per card
```

### With Projectile System (Task 1)
```lua
local ProjectileSystem = require("combat.projectile_system")

-- Spawn projectile with full modifier support
local projId = ProjectileSystem.spawn({
  position = context.playerPosition,
  angle = context.playerAngle,
  baseSpeed = actionCard.projectile_speed,
  damage = actionCard.damage,
  damageType = actionCard.damage_type,
  owner = context.playerEntity,

  -- Movement type from modifiers
  movementType = modifiers.homingEnabled
    and ProjectileSystem.MovementType.HOMING
    or ProjectileSystem.MovementType.STRAIGHT,
  homingTarget = modifiers.homingTarget,
  homingStrength = modifiers.homingStrength,

  -- Collision behavior from modifiers
  collisionBehavior = WandModifiers.getCollisionBehavior(modifiers),
  maxPierceCount = modifiers.pierceCount,
  maxBounces = modifiers.bounceCount,
  explosionRadius = modifiers.explosionRadius,

  -- Apply multipliers
  speedMultiplier = modifiers.speedMultiplier,
  damageMultiplier = modifiers.damageMultiplier,
  sizeMultiplier = modifiers.sizeMultiplier,

  -- Lifetime
  lifetime = actionCard.lifetime / 1000 * modifiers.lifetimeMultiplier,

  -- Visual
  sprite = actionCard.sprite or "projectile_default",

  -- Event hooks for on-hit effects
  onHit = function(proj, target, data)
    WandActions.handleProjectileHit(proj, target, data, modifiers)
  end,
})
```

### With Combat System
```lua
-- Apply damage (called from projectile system or directly)
if CombatSystem and CombatSystem.applyDamage then
  CombatSystem.applyDamage({
    target = targetEntity,
    source = context.playerEntity,
    damage = finalDamage,
    damageType = actionCard.damage_type,
  })
end

-- Apply status effects
if CombatSystem and CombatSystem.applyStatusEffect then
  CombatSystem.applyStatusEffect(targetEntity, "frozen", 2.0)
end
```

### With Timer System
```lua
local timer = require("core.timer")

-- Schedule delayed cast
timer.after(delaySeconds, function()
  WandExecutor.executeSubCast(wandId, subCastBlock, context)
end, "wand_" .. wandId .. "_subcast")

-- Periodic trigger
timer.every(triggerInterval, function()
  if WandExecutor.canCast(wandId) then
    WandExecutor.execute(wandId, "timer_trigger")
  end
end, -1, false, nil, "wand_" .. wandId .. "_trigger")
```

### With Event System
```lua
-- Subscribe to game events
subscribeToLuaEvent("player_pressed_attack", function(event)
  for wandId, trigger in pairs(WandTriggers.activeTriggers) do
    if trigger.type == "on_player_attack" then
      WandExecutor.execute(wandId, "attack_trigger")
    end
  end
end)

subscribeToLuaEvent("player_bump_enemy", function(event)
  for wandId, trigger in pairs(WandTriggers.activeTriggers) do
    if trigger.type == "on_bump_enemy" then
      WandExecutor.execute(wandId, "bump_trigger")
    end
  end
end)
```

## Execution Flow Example

### Example: Fire Bolt with Double Damage and Pierce

**Wand Definition:**
```lua
{
  id = "fire_wand",
  trigger = "every_N_seconds",
  triggerInterval = 1.0,
  castBlockSize = 2,
  cardSlots = {
    "MOD_DAMAGE_UP",              -- Modifier
    "ACTION_BASIC_PROJECTILE",     -- Action
  }
}
```

**Execution Flow:**
1. **Trigger fires** (timer reaches 1.0s)
   - `WandTriggers.checkTrigger()` → `WandExecutor.execute("fire_wand")`

2. **Check preconditions**
   - `WandExecutor.canCast("fire_wand")` → checks cooldown, mana
   - Returns `true`

3. **Evaluate cards**
   - Call `simulate_wand(wandDef, cardPool)`
   - Returns cast blocks:
     ```lua
     blocks = {
       {
         cards = {ACTION_BASIC_PROJECTILE},
         applied_modifiers = {MOD_DAMAGE_UP},
         total_cast_delay = 100,
         total_recharge = 0,
       }
     }
     ```

4. **Execute cast block**
   - Aggregate modifiers: `{damageMultiplier = 2.0, pierceCount = 2}`
   - Execute action: `ACTION_BASIC_PROJECTILE`

5. **Spawn projectile**
   - Call `ProjectileSystem.spawn()` with:
     - `damage = 10 * 2.0 = 20`
     - `collisionBehavior = PIERCE`
     - `maxPierceCount = 2`

6. **Apply delays**
   - Cast delay: 100ms
   - Update wand state: set cooldown, update mana

7. **Projectile hits enemy**
   - `ProjectileSystem` calls `onHit` callback
   - Apply damage via `CombatSystem`
   - Projectile pierces (count: 1/2 remaining)

## State Machine

```
┌─────────┐
│  IDLE   │<────────────────────┐
└────┬────┘                     │
     │                          │
     │ Trigger fires            │
     v                          │
┌─────────┐                     │
│ CASTING │                     │
└────┬────┘                     │
     │                          │
     │ For each cast block:     │
     │ - Execute actions        │
     │ - Apply delays           │
     │                          │
     v                          │
┌──────────┐                    │
│COOLDOWN  │                    │
└────┬─────┘                    │
     │                          │
     │ Cooldown expires         │
     └──────────────────────────┘
```

## Performance Considerations

1. **Object Pooling**: Reuse modifier aggregates and context objects
2. **Batch Spawning**: Spawn multiple projectiles in same frame for multicast
3. **Event Throttling**: Limit trigger checks per frame
4. **State Caching**: Cache wand states, only update when changed
5. **Lazy Evaluation**: Don't evaluate cards until trigger fires

## Testing Strategy

### Unit Tests
- Test modifier aggregation with various combinations
- Test collision behavior selection logic
- Test multicast angle calculations
- Test cooldown tracking

### Integration Tests
- Test full execution pipeline from trigger to projectile
- Test sub-cast blocks (timer, collision)
- Test modifier inheritance in sub-casts
- Test wand state persistence

### Example Test Wands
1. **Basic Fire Bolt**: Simple projectile, no modifiers
2. **Piercing Ice Shard**: Pierce modifier + action
3. **Triple Shot**: Multicast modifier + action
4. **Explosive Rounds**: Explosion modifier + action
5. **Homing Missiles**: Homing modifier + action
6. **Chain Lightning**: On-hit trigger + sub-cast
7. **Timer Bomb**: Timer trigger + delayed sub-cast

## Cast Origin Resolution

The wand system supports configurable spawn positions for projectiles through a unified origin resolution system.

### Origin Priority Chain

When spawning projectiles, the system resolves the spawn position using this priority:

1. **Sub-cast projectile position** - For collision/death triggers, spawn at the projectile's location
2. **Event position** - For event-based triggers (enemy_killed, on_bump), spawn at the event location
3. **Player position** - Default fallback

### Origin Modifiers

Modifiers can override or transform the resolved origin:

| Modifier | Effect | Example Use |
|----------|--------|-------------|
| `castFromEvent` | Prefer event position over player | Corpse explosion on kill |
| `teleportCastFromEnemy` | Find nearest enemy, spawn there | Teleporting strikes |
| `longDistanceCast` | Offset 120px forward from origin | Sniper-style spells |

### API

```lua
-- Resolve cast origin with full modifier support
local origin = WandExecutor.resolveCastOrigin(context, modifiers, subcastMeta)
-- Returns: { pos = {x, y}, kind = "player"|"event"|"projectile"|"nearest_enemy" }
```

### Event Position Snapshotting

Event-based triggers now include position data, snapshotted at emit time:

```lua
-- enemy_killed signal includes death position
signal.emit("enemy_killed", enemyEntity, { 
    position = { x = deathX, y = deathY }, 
    entity = enemyEntity 
})

-- on_bump_enemy signal includes bump position
signal.emit("on_bump_enemy", enemyEntity, {
    position = { x = bumpX, y = bumpY },
    entity = enemyEntity
})
```

### Behavior by Trigger Type

| Trigger | Default Origin | With `cast_from_event` Modifier |
|---------|---------------|--------------------------------|
| `enemy_killed` | Player | Enemy death position |
| `on_bump_enemy` | Player | Enemy position |
| `on_dash` | Player | Dash position |
| `every_N_seconds` | Player | Player (no event) |
| `trigger_on_collision` | Hit position | Hit position |
| `trigger_on_death` | Projectile position | Projectile position |

### Example: Corpse Explosion Wand

```lua
-- Wand that spawns explosions at enemy death locations
{
    trigger = "enemy_killed",
    cards = {
        "MOD_CAST_FROM_EVENT",  -- Spawn at kill location
        "ACTION_EXPLOSION"       -- Explosion action
    }
}
```

### Example: Teleporting Strike

```lua
-- Projectile spawns at nearest enemy
{
    trigger = "every_N_seconds",
    cards = {
        "MOD_TELEPORT_CAST",    -- Find nearest enemy
        "ACTION_SPARK_BOLT"     -- Fires FROM the enemy
    }
}
```

## Extension Points

### Adding New Action Types
```lua
-- In wand_actions.lua
WandActions.executors["my_custom_action"] = function(card, mods, ctx)
  -- Custom execution logic
end
```

### Adding New Modifier Types
```lua
-- In wand_modifiers.lua
WandModifiers.aggregators["my_custom_mod"] = function(agg, card)
  agg.customProperty = (agg.customProperty or 0) + card.customValue
end
```

### Adding New Trigger Types
```lua
-- In wand_triggers.lua
WandTriggers.handlers["my_custom_trigger"] = function(wandId, triggerDef)
  -- Custom trigger logic
  return shouldFire
end
```

## File Structure

```
assets/scripts/wand/
├── WAND_EXECUTION_ARCHITECTURE.md   (this file)
├── wand_executor.lua                 (main orchestrator)
├── wand_triggers.lua                 (trigger system)
├── wand_actions.lua                  (action execution)
├── wand_modifiers.lua                (modifier application)
├── wand_helpers.lua                  (utility functions)
└── wand_test_examples.lua            (test wands)
```

## Success Metrics

- ✅ Trigger activates at correct time
- ✅ Cards are evaluated correctly
- ✅ Modifiers apply to actions
- ✅ Projectiles spawn with correct properties
- ✅ Multicast works (2+, circular)
- ✅ Sub-casts execute (timer, collision)
- ✅ Cooldowns enforced
- ✅ Mana/charges tracked
- ✅ Performance: 60fps with 10+ wands active
- ✅ Extensible: new cards don't require engine changes
