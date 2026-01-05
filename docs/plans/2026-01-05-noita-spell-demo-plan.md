# Noita Spell System: Demo Card Selection & Implementation Plan

**Date:** 2026-01-05  
**Reference:** `docs/references/noita-spells-reference.md` (DO NOT MODIFY)  
**Goal:** Select ~40 cards for maximum gameplay breadth + plan missing system implementations

---

## Executive Summary

Noita has ~393 spells across 8 categories. After analyzing the existing codebase against the reference, I've identified:

- **~30 cards** that can be implemented with EXISTING systems
- **~15 cards** that require NEW systems
- **14 major system gaps** ranked by demo impact

---

## Part 1: Card Selection for Maximum Demo Breadth

### Selection Criteria
1. Cover ALL Noita spell categories
2. Showcase different mechanical interactions
3. Balance immediate implementation vs. new system requirements
4. Prioritize "feel-good" spells that demonstrate the engine's power

---

### Category A: Basic Projectiles (8 cards) - EXISTING SYSTEMS

| Card ID | Name | Key Mechanic | System Status |
|---------|------|--------------|---------------|
| `SPARK_BOLT` | Spark Bolt | Fast, cheap, accurate | ✅ Ready |
| `BOUNCING_BURST` | Bouncing Burst | Long lifetime, bounces | ✅ Ready |
| `MAGIC_ARROW` | Magic Arrow | Gravity arc, knockback | ✅ Ready |
| `MAGIC_MISSILE` | Magic Missile | Accelerating homing | ✅ Ready |
| `FIREBOLT` | Firebolt | Bouncing fire projectile | ✅ Ready |
| `FIREBALL` | Fireball | Explosive, terrain destruction | ✅ Ready |
| `ICEBALL` | Iceball | Explosive + freeze status | ✅ Ready |
| `BOMB` | Bomb | High damage, large radius, gravity | ✅ Ready |

**Implementation Notes:**
- All use existing `ProjectileSystem.spawn()` with appropriate params
- Firebolt/Fireball/Iceball need `apply_status` field (already supported)
- Bomb uses `gravity_affected = true` (already supported)

---

### Category B: Special Projectiles (6 cards) - EXISTING + MINOR EXTENSIONS

| Card ID | Name | Key Mechanic | System Status |
|---------|------|--------------|---------------|
| `CHAINSAW` | Chainsaw | Melee-range, rapid hits, negative cast delay | ✅ Ready |
| `LUMINOUS_DRILL` | Luminous Drill | Piercing beam, terrain drill | ⚠️ Needs terrain drilling |
| `DEATH_CROSS` | Death Cross | Large, slow, piercing | ✅ Ready |
| `GLOWING_LANCE` | Glowing Lance | Long beam, high damage | ✅ Ready |
| `LIGHTNING_BOLT` | Lightning Bolt | Fast, water electrification | ⚠️ Needs water interaction |
| `DORMANT_CRYSTAL` | Dormant Crystal | Explodes when hit by explosion | ⚠️ Needs chain explosion trigger |

**Implementation Notes:**
- Chainsaw: Use very short lifetime + negative cast_delay + melee damage type
- Luminous Drill: Needs new `terrain_destruction` flag
- Lightning Bolt: Needs water electrification system (status effect propagation)
- Dormant Crystal: Needs `explode_on_explosion_contact` behavior

---

### Category C: Teleport Spells (4 cards) - NEW SYSTEM REQUIRED

| Card ID | Name | Key Mechanic | System Status |
|---------|------|--------------|---------------|
| `TELEPORT_BOLT` | Teleport Bolt | Teleport caster to impact | ❌ NEW: Teleport system |
| `SMALL_TELEPORT_BOLT` | Small Teleport | Short-range teleport | ❌ NEW: Teleport system |
| `SWAPPER` | Swapper | Swap positions with enemy | ❌ NEW: Position swap |
| `RETURN` | Return | Teleport to spawn/checkpoint | ❌ NEW: Checkpoint system |

**Required System: Teleport Manager**
```lua
-- Proposed API
TeleportManager.teleportTo(entity, x, y, effects)
TeleportManager.swap(entityA, entityB)
TeleportManager.returnToCheckpoint(entity)
```

---

### Category D: Circle/Field Spells (6 cards) - NEW SYSTEM REQUIRED

| Card ID | Name | Key Mechanic | System Status |
|---------|------|--------------|---------------|
| `CIRCLE_VIGOUR` | Circle of Vigour | Healing field | ❌ NEW: Field system |
| `CIRCLE_SHIELDING` | Circle of Shielding | Projectile reflection | ❌ NEW: Field system |
| `CIRCLE_STILLNESS` | Circle of Stillness | Freeze enemies inside | ❌ NEW: Field system |
| `CIRCLE_THUNDER` | Circle of Thunder | Electric damage field | ❌ NEW: Field system |
| `HORIZONTAL_BARRIER` | Horizontal Barrier | Temporary wall | ❌ NEW: Barrier system |
| `VERTICAL_BARRIER` | Vertical Barrier | Temporary wall | ❌ NEW: Barrier system |

**Required System: Field/Zone Manager**
```lua
-- Proposed API
FieldManager.create({
    type = "circle", -- or "barrier"
    position = {x, y},
    radius = 100,
    lifetime = 5.0,
    effect = "heal",  -- "damage", "freeze", "reflect", "push"
    effectParams = { healPerSecond = 10 }
})
```

---

### Category E: Modifiers (10 cards) - MOSTLY EXISTING

| Card ID | Name | Key Mechanic | System Status |
|---------|------|--------------|---------------|
| `HEAVY_SHOT` | Heavy Shot | +damage, -speed | ✅ Ready |
| `LIGHT_SHOT` | Light Shot | -damage, +speed | ✅ Ready |
| `REDUCE_SPREAD` | Reduce Spread | Accuracy boost | ✅ Ready |
| `INCREASE_LIFETIME` | Increase Lifetime | Range extension | ✅ Ready |
| `REDUCE_LIFETIME` | Reduce Lifetime | Machine gun builds | ✅ Ready |
| `HOMING` | Homing | Seek enemies | ✅ Ready |
| `EXPLOSIVE_PROJECTILE` | Explosive Projectile | Add explosion | ✅ Ready |
| `FREEZE_CHARGE` | Freeze Charge | Add freeze status | ✅ Ready |
| `ELECTRIC_CHARGE` | Electric Charge | Add electric status | ✅ Ready |
| `BOOMERANG` | Boomerang | Return to caster | ⚠️ Needs return path |

**Implementation Notes:**
- Most modifiers already work via `wand_modifiers.lua`
- Boomerang needs new movement type: `MovementType.BOOMERANG`

---

### Category F: Path Modifiers (4 cards) - NEW MOVEMENT TYPES

| Card ID | Name | Key Mechanic | System Status |
|---------|------|--------------|---------------|
| `SPIRAL_ARC` | Spiral Arc | Corkscrew path | ⚠️ New movement type |
| `ORBITING_ARC` | Orbiting Arc | Circles around caster | ⚠️ Partially exists |
| `PING_PONG_PATH` | Ping-Pong Path | Zigzag movement | ⚠️ New movement type |
| `PHASING_ARC` | Phasing Arc | Pass through terrain | ⚠️ New collision mode |

**Required: New Movement Types**
```lua
MovementType.SPIRAL = "spiral"
MovementType.PINGPONG = "pingpong"
MovementType.PHASING = "phasing"  -- ignores terrain collision
```

---

### Category G: Multicast & Formations (6 cards) - PARTIAL SUPPORT

| Card ID | Name | Key Mechanic | System Status |
|---------|------|--------------|---------------|
| `DOUBLE_SPELL` | Double Spell | Cast 2 spells | ✅ Ready (multicast_count) |
| `TRIPLE_SPELL` | Triple Spell | Cast 3 spells | ✅ Ready |
| `QUADRUPLE_SPELL` | Quadruple Spell | Cast 4 spells | ✅ Ready |
| `FORMATION_PENTAGON` | Pentagon | 5 directions | ❌ NEW: Formation system |
| `FORMATION_HEXAGON` | Hexagon | 6 directions | ❌ NEW: Formation system |
| `FORMATION_BEHIND_BACK` | Behind Your Back | Also cast backwards | ❌ NEW: Formation system |

**Required System: Formation Patterns**
```lua
-- Proposed API (extend wand_actions.lua)
Formations = {
    PENTAGON = { angles = {0, 72, 144, 216, 288} },
    HEXAGON = { angles = {0, 60, 120, 180, 240, 300} },
    BEHIND_BACK = { angles = {0, 180} },
    BIFURCATED = { angles = {-15, 15} },
    TRIFURCATED = { angles = {-20, 0, 20} },
}
```

---

### Category H: Divide Spells (2 cards) - NEW SYSTEM REQUIRED

| Card ID | Name | Key Mechanic | System Status |
|---------|------|--------------|---------------|
| `DIVIDE_BY_2` | Divide By 2 | Create 2 copies | ❌ NEW: Divide system |
| `DIVIDE_BY_4` | Divide By 4 | Create 4 copies | ❌ NEW: Divide system |

**Key Difference from Multicast:**
- **Multicast**: Consumes N spells from wand, casts simultaneously
- **Divide**: Takes 1 spell, creates N identical copies

```lua
-- Divide creates projectile copies with same modifiers
-- Each copy is a full projectile entity, not just visual
```

---

### Category I: Conditional/Requirement Spells (3 cards) - NEW SYSTEM REQUIRED

| Card ID | Name | Key Mechanic | System Status |
|---------|------|--------------|---------------|
| `REQ_LOW_HEALTH` | Requirement - Low HP | Cast only when hurt | ❌ NEW: Conditional casting |
| `REQ_ENEMIES_NEARBY` | Requirement - Enemies | Cast only in combat | ❌ NEW: Conditional casting |
| `REQ_EVERY_OTHER` | Every Other | Alternate casts | ❌ NEW: Cast state tracking |

**Required: Conditional Casting System**
```lua
-- Proposed API (extend wand_executor.lua)
ConditionalCasting = {
    checkCondition = function(conditionType, context)
        if conditionType == "low_health" then
            return context.casterHealth < context.casterMaxHealth * 0.3
        elseif conditionType == "enemies_nearby" then
            return #context.nearbyEnemies > 0
        elseif conditionType == "every_other" then
            return context.castCount % 2 == 0
        end
    end
}
```

---

## Part 2: System Implementation Priority

### Tier 1: HIGH IMPACT, LOW EFFORT (Implement First)

| System | Cards Enabled | Effort | Demo Impact |
|--------|---------------|--------|-------------|
| **Formation Patterns** | 5 | Low | High - Visual variety |
| **New Movement Types** | 4 | Medium | High - Unique spell feel |
| **Boomerang Path** | 1 | Low | Medium - Fun mechanic |

**Estimated Time:** 2-3 days

---

### Tier 2: HIGH IMPACT, MEDIUM EFFORT

| System | Cards Enabled | Effort | Demo Impact |
|--------|---------------|--------|-------------|
| **Teleport Manager** | 4 | Medium | Very High - Mobility |
| **Divide System** | 2+ | Medium | High - Damage scaling |
| **Field/Zone System** | 6 | High | Very High - Area control |

**Estimated Time:** 1-2 weeks

---

### Tier 3: MEDIUM IMPACT, HIGH EFFORT

| System | Cards Enabled | Effort | Demo Impact |
|--------|---------------|--------|-------------|
| **Conditional Casting** | 3+ | High | Medium - Advanced builds |
| **Material System** | 10+ | Very High | Medium - Environmental |
| **Terrain Destruction** | 2+ | High | Medium - Digging |

**Estimated Time:** 2-4 weeks

---

### Tier 4: LOW PRIORITY (Post-Demo)

| System | Cards Enabled | Effort | Demo Impact |
|--------|---------------|--------|-------------|
| Greek Letter Spells | 8 | Very High | Low - Niche |
| Music/Note Spells | 13 | Low | Very Low - Easter egg |
| Touch/Transmutation | 6 | Very High | Low - Requires material system |

---

## Part 3: Implementation Roadmap

### Phase 1: Immediate (This Week)
**Goal:** 25 cards playable

1. Add missing card definitions to `cards.lua`:
   - Spark Bolt, Bouncing Burst, Magic Arrow
   - Magic Missile, Firebolt, Iceball, Bomb
   - Heavy/Light Shot, Reduce Lifetime, Freeze/Electric Charge

2. Implement Formation System:
   - Extend `wand_actions.lua` with formation angle calculations
   - Add Pentagon, Hexagon, Behind Back, Bifurcated, Trifurcated

3. Add Boomerang movement type:
   - Extend `projectile_system.lua` with `updateBoomerangMovement()`

### Phase 2: Short-term (Next 2 Weeks)
**Goal:** 35 cards playable

1. Implement Teleport Manager:
   - `core/teleport_manager.lua`
   - Teleport Bolt, Small Teleport, Swapper
   - Visual effects (particles, screen flash)

2. Implement Divide System:
   - Modify wand execution to support spell duplication
   - Different from multicast (copies vs consumes)

3. Add Spiral/PingPong/Phasing movement types

### Phase 3: Medium-term (Month 1)
**Goal:** 45 cards playable

1. Implement Field/Zone System:
   - `core/field_manager.lua`
   - Circle spells (Vigour, Shielding, Thunder, Stillness)
   - Barrier spells

2. Implement Conditional Casting:
   - Requirement spells
   - Cast state tracking

### Phase 4: Long-term (Post-Demo)
1. Material System (water, oil, acid physics)
2. Terrain Destruction
3. Greek Letter Spells
4. Touch/Transmutation Spells

---

## Part 4: Card Definitions to Add

### Immediate Cards (Copy to cards.lua)

```lua
-- BASIC PROJECTILES
Cards.SPARK_BOLT = {
    id = "SPARK_BOLT",
    type = "action",
    mana_cost = 5,
    damage = 3,
    projectile_speed = 800,
    lifetime = 666,  -- 40 frames at 60fps
    cast_delay = 50,
    spread_angle = -1,
    critical_hit_chance = 5,
    tags = { "Projectile", "Arcane" },
    description = "A weak but enchanting sparkling projectile",
}

Cards.BOUNCING_BURST = {
    id = "BOUNCING_BURST",
    type = "action",
    mana_cost = 5,
    damage = 3,
    projectile_speed = 700,
    lifetime = 12500,  -- 750 frames
    cast_delay = -30,  -- negative!
    ricochet_count = 10,
    spread_angle = -1,
    tags = { "Projectile" },
    description = "A weak but enchanting bouncing projectile",
}

Cards.MAGIC_MISSILE = {
    id = "MAGIC_MISSILE",
    type = "action",
    max_uses = 10,
    mana_cost = 70,
    damage = 75,
    radius_of_effect = 15,
    projectile_speed = 85,
    lifetime = 6000,  -- accelerates
    cast_delay = 1000,
    homing_strength = 5,
    accelerating = true,
    tags = { "Projectile", "Arcane", "AoE" },
    description = "A magical missile that homes in on enemies",
}

Cards.FIREBOLT = {
    id = "FIREBOLT",
    type = "action",
    max_uses = 25,
    mana_cost = 50,
    damage = 15,
    damage_type = "fire",
    projectile_speed = 265,
    lifetime = 8333,
    cast_delay = 500,
    ricochet_count = 3,
    apply_status = "burning",
    status_duration = 3,
    tags = { "Fire", "Projectile" },
    description = "A bouncing bolt of fire",
}

Cards.ICEBALL = {
    id = "ICEBALL",
    type = "action",
    max_uses = 15,
    mana_cost = 90,
    damage = 50,
    damage_type = "ice",
    radius_of_effect = 15,
    projectile_speed = 165,
    lifetime = 1000,
    cast_delay = 1330,
    apply_status = "frozen",
    status_duration = 2,
    tags = { "Ice", "Projectile", "AoE" },
    description = "An explosive ball of ice",
}

Cards.BOMB = {
    id = "BOMB",
    type = "action",
    max_uses = 3,
    mana_cost = 25,
    damage = 125,
    radius_of_effect = 60,
    projectile_speed = 60,
    lifetime = 3000,
    cast_delay = 1670,
    gravity_affected = true,
    tags = { "AoE", "Brute" },
    description = "A bomb that explodes on impact",
}

-- MODIFIERS
Cards.MOD_HEAVY_SHOT = {
    id = "MOD_HEAVY_SHOT",
    type = "modifier",
    mana_cost = 7,
    damage_modifier = 12,
    speed_modifier = -2,
    tags = { "Brute" },
    description = "Slower but more damaging projectile",
}

Cards.MOD_LIGHT_SHOT = {
    id = "MOD_LIGHT_SHOT",
    type = "modifier",
    mana_cost = 5,
    damage_modifier = -3,
    speed_modifier = 3,
    tags = { "Mobility" },
    description = "Faster but weaker projectile",
}

Cards.MOD_FREEZE_CHARGE = {
    id = "MOD_FREEZE_CHARGE",
    type = "modifier",
    mana_cost = 10,
    apply_status = "frozen",
    status_duration = 1.5,
    tags = { "Ice", "Debuff" },
    description = "Adds freezing effect to projectile",
}

Cards.MOD_BOOMERANG = {
    id = "MOD_BOOMERANG",
    type = "modifier",
    mana_cost = 10,
    boomerang = true,  -- NEW FIELD
    tags = { "Projectile" },
    description = "Projectile returns to caster",
}

-- FORMATIONS
Cards.FORMATION_PENTAGON = {
    id = "FORMATION_PENTAGON",
    type = "modifier",
    mana_cost = 5,
    formation = "pentagon",  -- NEW FIELD
    tags = { "Arcane", "AoE" },
    description = "Casts in 5 directions",
}

Cards.FORMATION_HEXAGON = {
    id = "FORMATION_HEXAGON",
    type = "modifier",
    mana_cost = 6,
    formation = "hexagon",
    tags = { "Arcane", "AoE" },
    description = "Casts in 6 directions",
}

Cards.FORMATION_BEHIND_BACK = {
    id = "FORMATION_BEHIND_BACK",
    type = "modifier",
    mana_cost = 0,
    formation = "behind_back",
    tags = { "Defense" },
    description = "Also casts behind you",
}

-- TELEPORT (requires new system)
Cards.TELEPORT_BOLT = {
    id = "TELEPORT_BOLT",
    type = "action",
    mana_cost = 40,
    projectile_speed = 800,
    lifetime = 666,
    cast_delay = 50,
    teleport_caster_on_hit = true,  -- NEW FIELD
    tags = { "Mobility", "Arcane" },
    description = "Teleports you to where the bolt lands",
}

-- DIVIDE (requires new system)
Cards.DIVIDE_BY_2 = {
    id = "DIVIDE_BY_2",
    type = "modifier",
    mana_cost = 35,
    cast_delay = 330,
    divide_count = 2,  -- NEW FIELD
    tags = { "Arcane" },
    description = "Splits the next spell into 2 copies",
}
```

---

## Part 5: Quick Reference - Card Field Support

### Currently Supported Fields
| Field | Type | Description |
|-------|------|-------------|
| `damage` | number | Base damage |
| `damage_type` | string | fire, ice, lightning, etc. |
| `projectile_speed` | number | Pixels per second |
| `lifetime` | number | Milliseconds |
| `cast_delay` | number | Ms before next cast |
| `spread_angle` | number | Degrees |
| `ricochet_count` | number | Bounces before destroy |
| `homing_strength` | number | Homing intensity |
| `seek_strength` | number | Gentle seeking |
| `gravity_affected` | boolean | Falls with gravity |
| `multicast_count` | number | Spells consumed |
| `trigger_on_collision` | boolean | Trigger payload on hit |
| `timer_ms` | number | Timer trigger delay |
| `trigger_on_death` | boolean | Trigger on expiry |
| `apply_status` | string | Status effect name |
| `status_duration` | number | Seconds |

### Fields Needing Implementation
| Field | Type | System Required |
|-------|------|-----------------|
| `boomerang` | boolean | Movement type |
| `formation` | string | Formation system |
| `teleport_caster_on_hit` | boolean | Teleport manager |
| `divide_count` | number | Divide system |
| `accelerating` | boolean | Acceleration movement |
| `phasing` | boolean | Terrain pass-through |
| `condition` | string | Conditional casting |

---

## Summary

**Total Cards Selected:** 49
- **Ready Now:** 20 cards
- **Minor Extensions:** 8 cards  
- **New Systems Required:** 21 cards

**Implementation Priority:**
1. Formations (5 cards) - 1-2 days
2. Boomerang movement - 1 day
3. Teleport system (4 cards) - 3-5 days
4. Divide system (2 cards) - 2-3 days
5. Field/Zone system (6 cards) - 1 week

**Demo Target:** 35+ playable cards showcasing mechanical variety
