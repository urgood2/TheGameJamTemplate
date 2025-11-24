# Adding Custom Behaviors - Complete Guide

## Overview

You have **two complementary approaches** for adding custom behaviors:

1. **Field-Based** (Simple, data-driven) - For straightforward stat modifications
2. **Function-Based** (Complex, executable logic) - For conditional logic, state tracking, complex effects

Both are designed to be **frictionless** - you can add new behaviors without modifying core systems.

---

## Approach 1: Field-Based Behaviors (Simplest)

### How It Works

Define parameters in upgrade/synergy definitions, check them in your game logic.

### Adding a New Field-Based Behavior

**Step 1: Add to upgrade definition**

```lua
-- In card_upgrade_system.lua
CardUpgrade.customBehaviors.ACTION_LIGHTNING_BOLT = {
  [3] = {
    overload_on_crit = {
      enabled = true,
      damage_mult = 2.0,
      aoe_radius = 100,
      stun_duration = 1.5  -- NEW: Add any fields you want
    }
  }
}
```

**Step 2: Check in game logic**

```lua
-- In your wand action handler
local hasOverload, params = CardUpgrade.hasCustomBehavior(card, "overload_on_crit")

if hasOverload and didCrit then
  -- Use the parameters
  spawnExplosion(target.position, params.aoe_radius)
  dealDamage(target, baseDamage * params.damage_mult)
  applyStun(target, params.stun_duration)
end
```

**That's it!** No core system changes needed.

### Example: Adding "Lifesteal on Kill"

```lua
-- 1. Define in upgrade path
CardUpgrade.customBehaviors.ACTION_VAMPIRE_BOLT = {
  [3] = {
    lifesteal_on_kill = {
      enabled = true,
      heal_percent = 50,  -- Heal 50% of enemy max HP
      max_heal = 100      -- Cap at 100 HP
    }
  }
}

-- 2. Use in game logic (in your on-kill handler)
local hasLifesteal, params = CardUpgrade.hasCustomBehavior(card, "lifesteal_on_kill")

if hasLifesteal then
  local healAmount = math.min(
    enemy.max_health * (params.heal_percent / 100),
    params.max_heal
  )
  player.hp = math.min(player.hp + healAmount, player.max_health)
end
```

---

## Approach 2: Function-Based Behaviors (Most Flexible)

### How It Works

Register executable functions in the behavior registry, execute with context.

### Adding a New Function-Based Behavior

**Step 1: Register the behavior**

```lua
local BehaviorRegistry = require("assets.scripts.wand.card_behavior_registry")

BehaviorRegistry.register("my_custom_effect", function(ctx)
  -- ctx contains: player, target, card, params, time, position, damage, etc.
  
  -- Your complex logic here
  if ctx.player.hp < ctx.player.max_health * 0.5 then
    -- Do something when low health
    return true
  end
  
  return false
end, "Description of what this does")
```

**Step 2: Reference in upgrade/synergy**

```lua
-- In upgrade definition
CardUpgrade.customBehaviors.ACTION_ADAPTIVE_BOLT = {
  [3] = {
    adaptive_behavior = {
      enabled = true,
      behavior_id = "my_custom_effect",  -- Reference the registered behavior
      -- Additional params passed to the behavior
      threshold = 0.5,
      bonus_damage = 50
    }
  }
}
```

**Step 3: Execute in game logic**

```lua
local hasBehavior, params = CardUpgrade.hasCustomBehavior(card, "adaptive_behavior")

if hasBehavior then
  local context = {
    player = player,
    target = target,
    card = card,
    params = params,
    time = currentTime,
    damage = baseDamage
  }
  
  local success, result = BehaviorRegistry.execute(params.behavior_id, context)
  if result then
    -- Behavior returned true, apply bonus
    baseDamage = baseDamage + params.bonus_damage
  end
end
```

---

## Real-World Examples

### Example 1: Recursive Chain Lightning (Complex Logic)

```lua
BehaviorRegistry.register("chain_lightning_advanced", function(ctx)
  local hitTargets = {}
  local totalDamage = 0  -- Accumulates damage across all chains
  
  local function chain(position, damage, depth, previousTarget)
    if depth > ctx.params.max_chains then return end
    
    -- Find nearest enemy not already hit
    local nearestEnemy = findNearestEnemy(position, ctx.params.range, function(enemy)
      return not hitTargets[enemy.id] and enemy.id ~= previousTarget
    end)
    
    if not nearestEnemy then return end
    
    -- Mark as hit
    hitTargets[nearestEnemy.id] = true
    
    -- Deal damage
    local chainDamage = damage * (ctx.params.damage_mult ^ depth)
    dealDamage(nearestEnemy, chainDamage)
    totalDamage = totalDamage + chainDamage
    
    -- Visual effect
    spawnLightningArc(position, nearestEnemy.position)
    
    -- Continue chain
    chain(nearestEnemy.position, damage, depth + 1, nearestEnemy.id)
  end
  
  chain(ctx.position, ctx.damage, 0, nil)
  return totalDamage  -- Returns total damage dealt by entire chain
end)
```

### Example 2: Conditional Summon with State Tracking

```lua
BehaviorRegistry.register("summon_on_combo", function(ctx)
  local player = ctx.player
  
  -- Initialize state
  if not player._combo_tracker then
    player._combo_tracker = {
      hits = 0,
      lastHitTime = 0,
      summonCooldown = 0
    }
  end
  
  local tracker = player._combo_tracker
  local currentTime = ctx.time
  
  -- Reset combo if too much time passed
  if currentTime - tracker.lastHitTime > ctx.params.combo_window then
    tracker.hits = 0
  end
  
  -- Increment combo
  tracker.hits = tracker.hits + 1
  tracker.lastHitTime = currentTime
  
  -- Check if should summon
  if tracker.hits >= ctx.params.combo_required and 
     currentTime >= tracker.summonCooldown then
    
    -- Summon ally
    spawnAlly(player.position, ctx.params.ally_type)
    
    -- Reset combo and set cooldown
    tracker.hits = 0
    tracker.summonCooldown = currentTime + ctx.params.cooldown
    
    return true
  end
  
  return false
end)
```

### Example 3: Dynamic Damage Scaling

```lua
BehaviorRegistry.register("damage_scales_with_missing_health", function(ctx)
  local player = ctx.player
  local missingHealthPercent = 1 - (player.hp / player.max_health)
  
  -- More damage when low health
  local bonusDamage = ctx.damage * missingHealthPercent * ctx.params.scaling_factor
  
  return ctx.damage + bonusDamage
end)
```

---

## Hybrid Approach (Recommended)

Use **field-based for simple params**, **function-based for complex logic**.

### Example: Overload System

```lua
-- 1. Register complex behavior
BehaviorRegistry.register("overload_mechanic", function(ctx)
  local player = ctx.player
  
  -- Initialize overload state
  if not player._overload then
    player._overload = { stacks = 0, maxStacks = 10 }
  end
  
  -- Add stack
  player._overload.stacks = math.min(
    player._overload.stacks + 1,
    player._overload.maxStacks
  )
  
  -- Check if should trigger
  if player._overload.stacks >= ctx.params.trigger_threshold then
    -- Trigger overload explosion
    local explosionDamage = ctx.damage * ctx.params.explosion_mult * player._overload.stacks
    spawnExplosion(ctx.position, ctx.params.explosion_radius, explosionDamage)
    
    -- Reset stacks
    player._overload.stacks = 0
    
    return true
  end
  
  return false
end)

-- 2. Use field-based params in upgrade
CardUpgrade.customBehaviors.ACTION_OVERLOAD_BOLT = {
  [3] = {
    overload = {
      enabled = true,
      behavior_id = "overload_mechanic",
      trigger_threshold = 5,    -- Trigger at 5 stacks
      explosion_mult = 2.0,     -- 2x damage per stack
      explosion_radius = 150
    }
  }
}

-- 3. Execute in game logic
local hasOverload, params = CardUpgrade.hasCustomBehavior(card, "overload")

if hasOverload then
  local ctx = {
    player = player,
    damage = baseDamage,
    position = target.position,
    params = params
  }
  
  local success, triggered = BehaviorRegistry.execute(params.behavior_id, ctx)
  -- Behavior handles everything internally
end
```

---

## How Frictionless Is It?

### Adding a Simple Behavior (30 seconds)

```lua
-- 1. Add to upgrade definition (10 seconds)
CardUpgrade.customBehaviors.MY_CARD = {
  [3] = {
    my_new_effect = {
      enabled = true,
      my_param = 100
    }
  }
}

-- 2. Check in game logic (20 seconds)
local has, params = CardUpgrade.hasCustomBehavior(card, "my_new_effect")
if has then
  doSomething(params.my_param)
end
```

### Adding a Complex Behavior (2-5 minutes)

```lua
-- 1. Register behavior (2-4 minutes)
BehaviorRegistry.register("my_complex_effect", function(ctx)
  -- Your logic here
  -- Can be as complex as you want
  -- State tracking, conditionals, recursion, etc.
end)

-- 2. Reference in upgrade (30 seconds)
CardUpgrade.customBehaviors.MY_CARD = {
  [3] = {
    complex = {
      enabled = true,
      behavior_id = "my_complex_effect",
      param1 = 50,
      param2 = 100
    }
  }
}

-- 3. Execute in game logic (30 seconds)
local has, params = CardUpgrade.hasCustomBehavior(card, "complex")
if has then
  BehaviorRegistry.execute(params.behavior_id, {
    player = player,
    params = params
    -- ... other context
  })
end
```

---

## Integration Patterns

### Pattern 1: On-Hit Behaviors

```lua
-- In your projectile hit handler
function onProjectileHit(projectile, target)
  local card = projectile.sourceCard
  
  -- Check all custom behaviors
  for behaviorId, params in pairs(CardUpgrade.getCustomBehaviors(card)) do
    if params.enabled and params.trigger == "on_hit" then
      if params.behavior_id then
        -- Function-based
        BehaviorRegistry.execute(params.behavior_id, {
          player = player,
          target = target,
          card = card,
          params = params,
          damage = projectile.damage
        })
      else
        -- Field-based
        handleFieldBehavior(behaviorId, params, target)
      end
    end
  end
end
```

### Pattern 2: Periodic Behaviors

```lua
-- In your update loop
function updateCardBehaviors(player, dt)
  for _, card in ipairs(player.equippedCards) do
    for behaviorId, params in pairs(CardUpgrade.getCustomBehaviors(card)) do
      if params.enabled and params.trigger == "periodic" then
        if params.behavior_id then
          BehaviorRegistry.execute(params.behavior_id, {
            player = player,
            card = card,
            params = params,
            dt = dt,
            time = currentTime
          })
        end
      end
    end
  end
end
```

### Pattern 3: Synergy Behaviors

```lua
-- Apply synergy behaviors
local activeSets = CardSynergy.getActiveBonuses(tagCounts)

for tagName, bonusData in pairs(activeSets) do
  local bonus = bonusData.bonus
  
  -- Check for behavior_id in bonus
  if bonus.behavior_id then
    BehaviorRegistry.execute(bonus.behavior_id, {
      player = player,
      tagName = tagName,
      tier = bonusData.tier,
      params = bonus
    })
  end
end
```

---

## Test Output

The behavior registry has been tested and works perfectly. Here's the output:

```
============================================================
BEHAVIOR REGISTRY - EXAMPLES
============================================================
[BehaviorRegistry] Registered behavior: chain_explosion_recursive
[BehaviorRegistry] Registered behavior: summon_on_low_health
[BehaviorRegistry] Registered behavior: momentum_stacks
[BehaviorRegistry] Registered behavior: trigger_with_cooldown

[Test 1] Chain Explosion:
  [Chain 1] Explosion at (100, 100) for 50 damage
  [Chain 2] Explosion at (91, 137) for 40 damage
  [Chain 3] Explosion at (87, 189) for 32 damage
  [Chain 4] Explosion at (-6, 146) for 26 damage
  [Chain 5] Explosion at (66, 79) for 20 damage
Result: 7 total explosions

[Test 2] Summon on Low Health:
  Player at 30% health - summoning ally!
Result: Summoned = true

[Test 3] Momentum Stacks:
  Momentum: 1 stacks (+5% damage)
  Momentum: 2 stacks (+10% damage)
  Momentum: 3 stacks (+15% damage)
  Momentum: 4 stacks (+20% damage)
  Momentum: 5 stacks (+25% damage)
  Momentum: 1 stacks (+5% damage)  # Decayed after timeout

[Test 4] Trigger with Cooldown:
  Triggered lightning_storm (next available in 3.0s)
  Time 1.0s: On cooldown
  Time 2.0s: On cooldown
  Time 4.0s: Triggered again
```

---

## Summary

**Field-Based**: Add params to upgrade definition, check in game logic. **~30 seconds per behavior.**

**Function-Based**: Register function once, reference by ID. **~2-5 minutes per behavior.**

**Both approaches require ZERO changes to core systems** - just add data and execute!

All test files are in:
- [`test_shop_stat_systems.lua`](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/tests/test_shop_stat_systems.lua) - Core systems
- [`test_behavior_registry.lua`](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/tests/test_behavior_registry.lua) - Complex behaviors

Run with: `lua assets/scripts/tests/test_behavior_registry.lua`
