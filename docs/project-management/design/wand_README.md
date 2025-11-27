# Wand Execution Engine

Complete wand evaluation-to-execution pipeline for Lua/C++ game engine.

## Quick Start

```lua
-- 1. Initialize
local WandExecutor = require("wand.wand_executor")
WandExecutor.init()

-- 2. Load a wand
local cardEval = require("core.card_eval_order_test")

local wandId = WandExecutor.loadWand(
    {id = "my_wand", mana_max = 50, cast_block_size = 2},  -- wand def
    {cardEval.create_card_from_template(...)},              -- cards
    {id = "every_N_seconds", interval = 1.0}                -- trigger
)

-- 3. Update every frame
function update(dt)
    WandExecutor.update(dt)
end
```

## Features

✅ **Trigger System**
- Timer-based (every_N_seconds, on_cooldown)
- Event-based (on_player_attack, on_bump_enemy, on_dash, on_distance_traveled, on_pickup)
- Condition-based (on_low_health)

✅ **Action Execution**
- Projectile spawning (via ProjectileSystem)
- Effect application (heal, buff, shield)
- Hazard creation (AoE zones, traps)
- Summon/teleport actions

✅ **Modifier System**
- Speed/damage/size/lifetime modifiers
- Behaviors (pierce, bounce, explode, homing)
- Multicast (2x, 3x, circular patterns)
- On-hit effects (freeze, chain lightning, life steal)
- Trigger chaining (cast on hit, timer, death)

✅ **State Management**
- Cooldown tracking
- Mana tracking with regeneration
- Charge tracking with regeneration
- Cast block sequencing
- Sub-cast execution

## File Structure

```
assets/scripts/wand/
├── README.md                         (this file)
├── WAND_EXECUTION_ARCHITECTURE.md   (detailed architecture)
├── wand_executor.lua                 (main orchestrator)
├── wand_triggers.lua                 (trigger system)
├── wand_actions.lua                  (action execution)
├── wand_modifiers.lua                (modifier application)
└── wand_test_examples.lua            (test suite)
```

## Examples

Run the test suite:

```lua
local WandTests = require("wand.wand_test_examples")
WandTests.runAllTests()
```

Available examples:
1. **Basic Fire Bolt** - Simple projectile with timer trigger
2. **Piercing Ice Shard** - Pierce modifier + attack trigger
3. **Triple Shot** - Multicast in spread pattern
4. **Explosive Rounds** - Explosion modifier + AoE damage
5. **Homing Missiles** - Homing behavior + auto-aim
6. **Chain Lightning** - On-hit trigger spawning chains
7. **Timer Bomb** - Delayed sub-cast execution

## Integration with Task 1 (Projectile System)

The wand system fully integrates with the projectile system:

```lua
-- Modifiers from wand cards are applied to projectiles
local ProjectileSystem = require("combat.projectile_system")

ProjectileSystem.spawn({
    -- Position from wand context
    position = context.playerPosition,
    angle = context.playerAngle,

    -- Properties from action card + modifiers
    baseSpeed = modifiedProps.speed,
    damage = modifiedProps.damage,
    lifetime = modifiedProps.lifetime,

    -- Behavior from modifiers
    movementType = ProjectileSystem.MovementType.HOMING,
    collisionBehavior = ProjectileSystem.CollisionBehavior.PIERCE,
    maxPierceCount = modifiers.pierceCount,

    -- Event hooks for on-hit effects
    onHit = function(proj, target, data)
        -- Apply freeze, chain lightning, etc.
    end,
})
```

## API Reference

### WandExecutor

**Core Functions:**
- `WandExecutor.init()` - Initialize system
- `WandExecutor.update(dt)` - Update per frame
- `WandExecutor.loadWand(wandDef, cardPool, triggerDef)` - Load wand
- `WandExecutor.execute(wandId, triggerType)` - Execute wand
- `WandExecutor.canCast(wandId)` - Check if can cast

**State Queries:**
- `WandExecutor.getCooldown(wandId)` - Get cooldown remaining
- `WandExecutor.getMana(wandId)` - Get current mana
- `WandExecutor.getCharges(wandId)` - Get current charges
- `WandExecutor.getWandState(wandId)` - Get full state

### WandTriggers

**Trigger Management:**
- `WandTriggers.register(wandId, triggerDef, executor)` - Register trigger
- `WandTriggers.unregister(wandId)` - Unregister trigger
- `WandTriggers.enable(wandId)` - Enable trigger
- `WandTriggers.disable(wandId)` - Disable trigger

### WandModifiers

**Modifier Functions:**
- `WandModifiers.aggregate(modifierCards)` - Aggregate modifiers
- `WandModifiers.applyToAction(actionCard, modifiers)` - Apply to action
- `WandModifiers.getCollisionBehavior(modifiers)` - Get collision behavior
- `WandModifiers.calculateMulticastAngles(modifiers, baseAngle)` - Get angles

### WandActions

**Action Execution:**
- `WandActions.execute(actionCard, modifiers, context)` - Execute action
- `WandActions.spawnSingleProjectile(...)` - Spawn projectile
- `WandActions.handleProjectileHit(...)` - Handle on-hit
- `WandActions.applyHealing(entity, amount)` - Apply healing

## Documentation

**Full documentation:**
- **Architecture**: `/assets/scripts/wand/WAND_EXECUTION_ARCHITECTURE.md`
- **Completion Report**: `/WAND_EXECUTION_REPORT.md`
- **Projectile Integration**: `/assets/scripts/combat/WAND_INTEGRATION_GUIDE.md`

## Performance

**Targets:**
- 60 FPS with 10+ active wands
- 100+ simultaneous projectiles
- <1ms per wand execution (typical)

**Optimizations:**
- State caching (persistent wand states)
- Single-pass modifier aggregation
- Lazy card evaluation
- Event throttling
- Object reuse

## Extension Points

### Add Custom Action Type
```lua
-- In wand_actions.lua
WandActions.executors["my_action"] = function(card, mods, ctx)
    -- Custom logic
end
```

### Add Custom Modifier
```lua
-- In wand_modifiers.lua
function WandModifiers.applyCardToAggregate(agg, card)
    if card.my_modifier then
        agg.myProperty = card.my_modifier
    end
end
```

### Add Custom Trigger
```lua
-- In wand_triggers.lua
WandTriggers.handlers["my_trigger"] = function(wandId, triggerDef)
    -- Custom trigger logic
    return shouldFire
end
```

## Dependencies

**Required:**
- `core.timer` - Timer system
- `core.card_eval_order_test` - Card evaluation
- `combat.projectile_system` - Projectile spawning (Task 1)

**Optional:**
- `combat.combat_system` - Damage/effects
- `core.component_cache` - Entity components
- Event system (`subscribeToLuaEvent`, `publishLuaEvent`)

## Status

✅ **Complete and production-ready**

All features implemented, tested, and documented.

---

**Questions? See:**
- Architecture doc: `WAND_EXECUTION_ARCHITECTURE.md`
- Examples: `wand_test_examples.lua`
- Report: `/WAND_EXECUTION_REPORT.md`
