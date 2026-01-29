# Vampire Survivors: Design Summary & Implementation Guide

## Overview

This document synthesizes findings from Vampire Survivors research to provide actionable design guidance for implementing a survivors-like game inspired by its mechanics.

---

## Core Design Philosophy

### Auto-Attack Simplicity
Vampire Survivors' defining characteristic is that **the player only controls movement**. All attacks are automatic:
- Weapons fire based on cooldown timers
- Targeting is automatic (nearest enemy, random, directional)
- Player skill = positioning and build decisions

**Why This Matters for Survivors-Like**: Removes execution barrier, focuses on strategic choices.

### Exponential Power Scaling
The game creates satisfying progression through multiplicative systems:
- Weapons level 1-8 with increasing stats
- Passive items multiply weapon effectiveness
- Evolutions dramatically increase power
- PowerUps provide permanent progression

### Risk/Reward via Curse
The Curse stat increases enemy spawn rate, speed, and health while also increasing rewards:
- Higher Curse = more enemies = more XP = faster leveling
- Creates self-balancing difficulty curve
- Experienced players intentionally increase Curse

---

## Stat System Analysis

### Primary Stats

| Stat | Effect | Sources | Scaling |
|------|--------|---------|---------|
| **Might** | +% Damage | PowerUp, Spinach, Characters | Multiplicative |
| **Area** | +% Weapon size | PowerUp, Candelabrador | Multiplicative |
| **Speed** | +% Projectile velocity | PowerUp, Bracer | Multiplicative |
| **Duration** | +% Effect duration | PowerUp, Spellbinder | Multiplicative |
| **Amount** | +N Projectiles | PowerUp, Duplicator, Characters | Additive |
| **Cooldown** | -% Time between attacks | PowerUp, Empty Tome | Multiplicative |
| **Armor** | Flat damage reduction | PowerUp, Armor item | Additive |
| **Max Health** | +% Maximum HP | PowerUp, Hollow Heart | Multiplicative |
| **Recovery** | +N HP/second | PowerUp, Pummarola | Additive |
| **Luck** | +% Crit/drops | PowerUp, Clover | Multiplicative |
| **Growth** | +% XP gain | PowerUp, Crown | Multiplicative |
| **Greed** | +% Coin gain | PowerUp, Stone Mask | Multiplicative |
| **Magnet** | +% Pickup range | PowerUp, Attractorb | Multiplicative |
| **MoveSpeed** | +% Character speed | PowerUp, Wings | Multiplicative |
| **Curse** | +% Enemy stats/spawns | PowerUp, Characters | Multiplicative |

### Stat Priority for Build Diversity

| Build Type | Priority Stats |
|------------|----------------|
| **DPS** | Might > Amount > Cooldown > Area |
| **Survival** | Armor > Max Health > Recovery > MoveSpeed |
| **Farming** | Greed > Growth > Magnet > Luck |
| **Speed Clear** | Cooldown > Amount > Area > MoveSpeed |

---

## Weapon Design Patterns

### Weapon Archetypes

| Archetype | Examples | Characteristics |
|-----------|----------|-----------------|
| **Directional** | Knife, Whip | Fires in faced direction |
| **Homing** | Magic Wand, Fire Wand | Targets nearest/random enemy |
| **Orbital** | King Bible, Garlic | Circles around player |
| **Area** | Santa Water, Pentagram | Creates damage zones |
| **Boomerang** | Cross, Axe | Returns to player |
| **Chain** | Lightning Ring | Jumps between enemies |

### Weapon Stat Progression (Level 1-8)

| Level | Typical Bonuses |
|-------|-----------------|
| 1 | Base stats |
| 2 | +Damage or +Area |
| 3 | +Amount or +Speed |
| 4 | +Damage |
| 5 | +Amount or +Duration |
| 6 | +Damage or +Area |
| 7 | +Amount or +Pierce |
| 8 | Major bonus (ready for evolution) |

### Evolution System

The evolution system creates build depth:
1. **Weapon + Passive = Evolution**: Each weapon has a paired passive item
2. **Max Level Required**: Weapon must be level 8
3. **Chest Trigger**: Evolution occurs when opening treasure chest
4. **Power Spike**: Evolutions are significantly stronger than base weapons

---

## Enemy Design Patterns

### Spawn Scaling

| Time | Enemy Behavior |
|------|----------------|
| 0-5 min | Slow enemies, low density |
| 5-10 min | Medium speed, medium density |
| 10-20 min | Fast enemies, high density |
| 20-25 min | Elite enemies, very high density |
| 25-30 min | Boss spawns, maximum density |
| 30+ min | Death spawns (instant kill) |

### Enemy Types

| Type | Behavior | Counter Strategy |
|------|----------|------------------|
| **Swarm** | Many weak enemies | Area weapons |
| **Tank** | High HP, slow | High damage weapons |
| **Fast** | Quick, low HP | Homing weapons |
| **Ranged** | Attacks from distance | Movement, orbital weapons |
| **Boss** | Massive HP, special attacks | Sustained DPS |

### The Death Mechanic

At 30 minutes, Death spawns:
- Instant kill on contact
- Forces run completion
- Can be defeated with specific builds (unlocks secret character)

---

## Progression Systems

### Per-Run Progression

```
Kill Enemies → XP Gems → Level Up → Choose Weapon/Item
                                  ↓
                            Max Weapon → Open Chest → Evolution
```

### Meta Progression

```
Complete Run → Earn Gold → Buy PowerUps → Stronger Next Run
                        ↓
                   Unlock Characters → New Starting Weapons
                        ↓
                   Unlock Stages → New Challenges
```

### Unlock Chains

Many unlocks chain together:
1. Survive X minutes → Unlock Character A
2. Use Character A → Unlock Weapon B
3. Max Weapon B → Unlock Item C
4. Combine B + C → Unlock Evolution D

---

## Build Archetype Analysis

### 1. Area Clear Build
- **Weapons**: Santa Water, Garlic, King Bible
- **Passives**: Candelabrador, Spellbinder, Attractorb
- **Strategy**: Maximize area coverage, walk through enemies
- **Evolutions**: La Borra, Soul Eater, Unholy Vespers

### 2. Projectile Spam Build
- **Weapons**: Knife, Magic Wand, Runetracer
- **Passives**: Bracer, Empty Tome, Duplicator
- **Strategy**: Fill screen with projectiles
- **Evolutions**: Thousand Edge, Holy Wand, NO FUTURE

### 3. High Damage Build
- **Weapons**: Fire Wand, Axe, Lightning Ring
- **Passives**: Spinach, Candelabrador, Duplicator
- **Strategy**: Maximize single-hit damage
- **Evolutions**: Hellfire, Death Spiral, Thunder Loop

### 4. Survival Build
- **Weapons**: Garlic, Laurel, Clock Lancet
- **Passives**: Armor, Hollow Heart, Pummarola
- **Strategy**: Tank damage, outlast enemies
- **Evolutions**: Soul Eater, Crimson Shroud, Infinite Corridor

---

## Implementation Roadmap for Survivors-Like

### Phase 1: Core Systems (Essential)

#### Auto-Attack System
```lua
-- Weapons fire automatically based on cooldown
local WEAPON_TEMPLATE = {
    cooldown = 1.0,      -- seconds between attacks
    damage = 10,         -- base damage
    area = 1.0,          -- size multiplier
    amount = 1,          -- projectiles per attack
    speed = 200,         -- projectile velocity
    duration = 1.0,      -- effect duration
    pierce = 1,          -- enemies hit before expiring
}
```

#### Stat System
- Base stats from character
- Additive bonuses from items
- Multiplicative bonuses from passives
- Final calculation: `base * (1 + sum(multipliers))`

#### XP/Leveling
- Gems drop from enemies
- Magnet pulls gems to player
- Level up presents 3-4 random choices
- Reroll/Skip options (limited uses)

### Phase 2: Content Systems (Important)

#### Weapon Variety
- Implement 6-8 weapon archetypes
- Each weapon levels 1-8
- Distinct visual/audio feedback

#### Passive Items
- 10-15 passive items
- Each boosts specific stats
- Pair with weapons for evolutions

#### Evolution System
- Track weapon levels
- Track passive ownership
- Trigger evolution on chest open

### Phase 3: Meta Systems (Polish)

#### PowerUps
- Permanent stat upgrades
- Gold currency from runs
- Increasing costs per purchase

#### Unlocks
- Characters unlock from achievements
- Weapons unlock from character use
- Stages unlock from survival time

#### Arcanas (Optional)
- Run modifiers
- Unlocked separately
- Choose at run start + from bosses

---

## Key Takeaways

### Design Principles
1. **Simplicity over complexity** - One input (movement) creates emergent gameplay
2. **Multiplicative scaling** - Stats compound for satisfying power growth
3. **Clear feedback** - Numbers, effects, and sounds communicate damage
4. **Horizontal progression** - Many viable builds, not one optimal path
5. **Risk/reward balance** - Curse system lets players choose difficulty

### Implementation Priorities
1. Auto-attack weapon system (core loop)
2. XP and leveling (progression feel)
3. Stat system (build diversity)
4. Evolution system (power spikes)
5. Enemy scaling (challenge curve)

### Avoid
- Manual attack inputs (breaks the genre)
- Linear stat scaling (feels flat)
- Single optimal build (reduces replayability)
- Instant difficulty spikes (frustrating)

---

## Document Index

| Document | Content |
|----------|---------|
| [Characters.md](Characters.md) | All playable characters with stats and unlocks |
| [Weapons.md](Weapons.md) | All weapons with stats and leveling |
| [PassiveItems.md](PassiveItems.md) | All passive items with effects |
| [Evolutions.md](Evolutions.md) | Complete evolution tree |
| [Stages.md](Stages.md) | All stages with features and unlocks |
| [Arcanas.md](Arcanas.md) | All arcana cards with effects |
| [Enemies.md](Enemies.md) | Enemy types and spawn patterns |

---

## Quick Reference Tables

### Stat Caps (Soft/Hard)

| Stat | Soft Cap | Hard Cap | Notes |
|------|----------|----------|-------|
| Cooldown | -80% | -90% | Diminishing returns |
| MoveSpeed | +100% | +200% | Character dependent |
| Amount | +5 | +10 | Weapon dependent |
| Area | +100% | None | Unlimited scaling |
| Might | +100% | None | Unlimited scaling |

### Common Trigger Patterns

| Trigger | Common Effects |
|---------|----------------|
| On level up | Choose weapon/item |
| On kill | XP gem drop, gold chance |
| On chest open | Evolution check, item grant |
| On timer | Boss spawn, enemy wave |
| On damage taken | Armor reduction, retaliation |

### Evolution Priority (Early Game)

| Priority | Weapon | Passive | Evolution |
|----------|--------|---------|-----------|
| 1 | Whip | Hollow Heart | Bloody Tear |
| 2 | King Bible | Spellbinder | Unholy Vespers |
| 3 | Fire Wand | Spinach | Hellfire |
| 4 | Santa Water | Attractorb | La Borra |
| 5 | Garlic | Pummarola | Soul Eater |

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
