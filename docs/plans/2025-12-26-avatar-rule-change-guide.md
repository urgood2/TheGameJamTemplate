# Avatar Rule Change Implementation Guide

**Date:** 2025-12-26
**Status:** Phase 3 - Hook Points Established
**Scope:** `rule_change` effect type integration

## Overview

This guide documents how to implement the 6 `rule_change` effects defined in `assets/scripts/data/avatars.lua`. Each rule modifies core gameplay mechanics when the corresponding avatar is equipped.

### How Rule Checking Works

```lua
local AvatarSystem = require("wand.avatar_system")

-- Check if a rule is active for the player
if AvatarSystem.has_rule(player, "rule_name") then
    -- Apply the rule's effect
end
```

The `has_rule(player, rule)` function (defined in `avatar_system.lua:410`):
1. Gets the player's equipped avatar via `get_equipped(player)`
2. Looks up the avatar definition in `avatars.lua`
3. Searches effects for `type = "rule_change"` with matching `rule` field
4. Returns `true` if found, `false` otherwise

### When to Check Rules

Rules should be checked at their integration point during wand execution. The execution context (`context`) provides access to `context.playerScript` which is the player's script table needed for `has_rule()`.

---

## Rules Reference

### 1. missing_hp_dmg

> "Gain +1% Damage for every 1% missing HP."

**Avatar:** Blood God
**Location:** `wand_modifiers.lua` → `mergePlayerStats()` or new helper function
**Stub Location:** Line ~575 (after stat snapshot)

#### Logic

```lua
-- Calculate missing HP percentage
local combatActor = player.combatTable
if combatActor and combatActor.stats then
    local currentHp = combatActor.stats:get("hp") or combatActor.hp or 0
    local maxHp = combatActor.stats:get("max_hp") or 100
    local missingHpPct = math.max(0, (1 - currentHp / maxHp) * 100)

    -- Apply as additive damage percentage
    agg.damageMultiplier = agg.damageMultiplier * (1 + missingHpPct / 100)
end
```

#### Dependencies
- Player must have `combatTable` with `stats` object
- Stats object must have `hp` and `max_hp` fields

#### Edge Cases
- **Dead player (0 HP):** Would give +100% damage, but dead players can't cast
- **No combatTable:** Skip the rule (combat not initialized)
- **Max HP is 0:** Guard against division by zero

#### Testing
```lua
-- Mock player at 50% HP
local player = {
    combatTable = {
        stats = { get = function(_, stat)
            if stat == "hp" then return 50 end
            if stat == "max_hp" then return 100 end
        end }
    },
    avatar_state = { equipped = "bloodgod", unlocked = { bloodgod = true } }
}
-- Expected: +50% damage multiplier
```

---

### 2. crit_chains

> "Critical hits always Chain to a nearby enemy."

**Avatar:** Stormlord
**Location:** `wand_actions.lua` → `handleProjectileHit()` or hit processing
**Stub Location:** After crit detection in hit handler

#### Logic

```lua
-- After determining this was a critical hit
if isCriticalHit then
    local nearestEnemy = context.findNearestEnemy(hitPosition, 200) -- 200px range
    if nearestEnemy and nearestEnemy ~= hitTarget then
        -- Spawn chain projectile toward nearestEnemy
        -- Use reduced damage (50%?) to prevent infinite scaling
        spawnChainProjectile({
            origin = hitPosition,
            target = nearestEnemy,
            damage = originalDamage * 0.5,
            canChain = false  -- Prevent chain-chains
        })
    end
end
```

#### Dependencies
- Crit detection system (already exists in combat)
- `findNearestEnemy()` helper (exists in `wand_executor.lua:1209`)
- Chain projectile spawning (may need to add)

#### Edge Cases
- **No nearby enemies:** Don't chain (already handled by check)
- **Chain to self:** Exclude the hit target from search
- **Chain-chains:** Chained projectiles should NOT trigger more chains (infinite loop)
- **Multiple crits in multicast:** Each crit chains independently

#### Open Questions
- Should chained projectiles inherit modifiers from the original?
- What's the chain range? (Suggest: 150-200 pixels)
- What's the chain damage falloff? (Suggest: 50%)

---

### 3. multicast_loops

> "Multicast modifiers now Loop the cast block instead of simultaneous cast."

**Avatar:** Wildfire
**Location:** `wand_executor.lua` → `executeCastBlock()` around line 746
**Stub Location:** Before multicast angle calculation

#### Logic

Currently, multicast fires N projectiles simultaneously with spread angles. With this rule:

```lua
-- Current behavior (parallel):
local angles = WandModifiers.calculateMulticastAngles(modifiers, baseAngle)
for _, angle in ipairs(angles) do
    spawnProjectile(angle)  -- All spawn at once
end

-- New behavior (loop):
if AvatarSystem.has_rule(player, "multicast_loops") then
    -- Execute the entire cast block N times sequentially
    for i = 1, modifiers.multicastCount do
        -- Re-evaluate and execute the block
        -- Each iteration uses the same base angle (no spread)
        executeBlockOnce(block, context, modifiers)
    end
else
    -- Original parallel behavior
    local angles = WandModifiers.calculateMulticastAngles(modifiers, baseAngle)
    ...
end
```

#### Dependencies
- Refactor to separate "execute block once" from "execute with multicast"
- Timer delays between loop iterations (optional, for visual clarity)

#### Edge Cases
- **Mana cost:** Should each loop iteration cost mana? (Suggest: No, total cost unchanged)
- **Cooldown:** Should be calculated once for all loops
- **Nested multicast:** Multiple multicast modifiers multiply; loops should too

#### Complexity
This is a medium-complexity change because it requires restructuring how multicast is handled. The current flow is:
1. Calculate angles → 2. Spawn all at once

New flow:
1. Check rule → 2a. If loop: iterate block N times → 2b. Else: original behavior

---

### 4. move_casts_trigger_onhit

> "Wands triggered by Movement now trigger 'On Hit' effects."

**Avatar:** Miasma
**Location:** `wand_triggers.lua` → movement trigger registration
**Stub Location:** Where trigger type is set on execution context

#### Logic

Movement-triggered wands normally don't trigger on-hit effects (for performance/balance). This rule overrides that:

```lua
-- In trigger registration or execution context creation
if triggerType == "movement" then
    context.isMovementTrigger = true

    if AvatarSystem.has_rule(player, "move_casts_trigger_onhit") then
        context.enableOnHitEffects = true  -- Override the default
    end
end

-- In wand_actions.lua hit handling
if context.enableOnHitEffects or not context.isMovementTrigger then
    applyOnHitEffects(...)
end
```

#### Dependencies
- Understanding of current movement trigger flow
- Context flag propagation from trigger → executor → actions

#### Edge Cases
- **Performance:** On-hit effects on every movement cast could be expensive
- **Effect stacking:** Rapid movement = rapid on-hits; may need internal cooldown

#### Investigation Needed
- Find where movement triggers are registered in `wand_triggers.lua`
- Trace how trigger type flows into execution context

---

### 5. summons_inherit_block

> "Summons inherit 100% of your Block Chance and Thorns."

**Avatar:** Citadel
**Location:** Summon creation code (TBD)
**Stub Location:** Where summon entities are spawned

#### Logic

```lua
-- When creating a summon entity
local summon = createSummonEntity(...)

if AvatarSystem.has_rule(player, "summons_inherit_block") then
    local playerStats = player.combatTable and player.combatTable.stats
    if playerStats then
        local blockChance = playerStats:get("block_chance") or 0
        local thorns = playerStats:get("thorns") or 0

        -- Apply to summon's stats
        summon.combatTable.stats:set("block_chance", blockChance)
        summon.combatTable.stats:set("thorns", thorns)
    end
end
```

#### Dependencies
- Locate summon creation code (likely in combat or a summon system)
- Summons must have a `combatTable.stats` structure
- Stats system must support `block_chance` and `thorns`

#### Investigation Needed
```bash
# Find summon creation
grep -r "summon" assets/scripts/ --include="*.lua" | grep -i "create\|spawn"
```

#### Edge Cases
- **Summon doesn't have stats:** May need to initialize stats structure
- **Player stats change mid-summon:** Should summon update? (Suggest: No, snapshot at creation)
- **Multiple summons:** Each inherits independently

---

### 6. summon_cast_share

> "When you cast a projectile, your Summons also cast a copy of it."

**Avatar:** Voidwalker
**Location:** `wand_actions.lua` → after projectile spawn
**Stub Location:** End of `executeProjectileAction()` or similar

#### Logic

```lua
-- After player's projectile is spawned
if AvatarSystem.has_rule(player, "summon_cast_share") then
    local summons = findPlayerSummons(player)
    for _, summon in ipairs(summons) do
        -- Spawn copy from summon's position toward same direction
        local summonPos = getSummonPosition(summon)
        spawnProjectileCopy({
            origin = summonPos,
            angle = originalAngle,
            damage = originalDamage * 0.5,  -- Reduced damage
            owner = summon,  -- Summon is the owner (for aggro/on-hit)
            fromSummonShare = true  -- Prevent recursion
        })
    end
end
```

#### Dependencies
- `findPlayerSummons(player)` helper function
- Summon tracking system (which entities are player's summons?)
- Projectile spawning that accepts arbitrary origin

#### Edge Cases
- **Recursion prevention:** Summon-cast projectiles must NOT trigger more summon casts
- **Summon count scaling:** Many summons = many projectiles; performance concern
- **Damage attribution:** Who gets credit for kills? (Suggest: Summon, not player)
- **Multicast interaction:** If player multicasts, do summons also multicast?

#### Complexity
This is the most complex rule because it requires:
1. Tracking which entities are the player's summons
2. Finding their positions at cast time
3. Spawning projectiles from each
4. Preventing recursive summon-casting

---

## Testing Checklist

### Stub Verification
- [ ] Each stub prints `[AvatarRule] <rule_name> would apply here` when conditions met
- [ ] No prints when avatar is not equipped
- [ ] No prints when different avatar is equipped
- [ ] No crashes when `playerScript` is nil

### Integration Verification
- [ ] Equipping avatar enables rules
- [ ] Unequipping avatar disables rules
- [ ] Switching avatars changes active rules

### Manual Test Script
```lua
-- Add to test file or run in console
local AvatarSystem = require("wand.avatar_system")
local player = getPlayerScript()  -- However you get player

-- Unlock and equip bloodgod
player.avatar_state = { unlocked = { bloodgod = true }, equipped = "bloodgod" }

-- Verify rules
print("Has missing_hp_dmg:", AvatarSystem.has_rule(player, "missing_hp_dmg"))  -- true
print("Has crit_chains:", AvatarSystem.has_rule(player, "crit_chains"))        -- false
```

---

## Implementation Order

Recommended order based on complexity and dependencies:

| Priority | Rule | Effort | Notes |
|----------|------|--------|-------|
| 1 | `missing_hp_dmg` | Low | Pure math, no side effects |
| 2 | `crit_chains` | Medium | Needs chain spawning, but clear hook |
| 3 | `multicast_loops` | Medium | Requires execution flow refactor |
| 4 | `move_casts_trigger_onhit` | Medium | Context flag propagation |
| 5 | `summons_inherit_block` | High | Must find summon creation code |
| 6 | `summon_cast_share` | High | Complex summon tracking + recursion prevention |

---

## Cross-Rule Interactions

### Potential Interactions to Consider

1. **`crit_chains` + `multicast_loops`**
   - Each looped cast can crit independently
   - Each crit chains independently
   - Could create many chain projectiles

2. **`summon_cast_share` + `missing_hp_dmg`**
   - Should summon copies use player's damage bonus? (Suggest: No)
   - Summons have their own HP, so their "missing HP" differs

3. **`summon_cast_share` + `crit_chains`**
   - If summon's copy crits, does it chain?
   - Suggest: Yes, but chained projectiles can't summon-share (recursion)

### Design Principle
When in doubt, prefer **isolated effects** over **compounding effects**. Each rule should work independently, and interactions should be explicitly designed rather than emergent.

---

## Files Modified (Stubs Only)

| File | Change |
|------|--------|
| `wand_modifiers.lua` | +10 lines: `missing_hp_dmg` stub in `mergePlayerStats()` |
| `wand_actions.lua` | +15 lines: `crit_chains` and `summon_cast_share` stubs |
| `wand_executor.lua` | +10 lines: `multicast_loops` stub in `executeCastBlock()` |
| `wand_triggers.lua` | +10 lines: `move_casts_trigger_onhit` stub |
| TBD (summon code) | +10 lines: `summons_inherit_block` stub |

---

## Future Work

After stubs are in place:
1. Implement `missing_hp_dmg` (simplest, good first win)
2. Add chain projectile spawning for `crit_chains`
3. Refactor multicast execution for `multicast_loops`
4. Create summon tracking system for `summon_*` rules
5. Add comprehensive tests for each rule
