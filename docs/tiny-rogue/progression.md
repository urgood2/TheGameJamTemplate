# Progression Systems

This document covers all progression mechanics in Tiny Rogues, including per-run leveling, meta-progression, stat systems, and world tier unlocks.

---

## Table of Contents

1. [Level Curve & XP](#level-curve--xp)
2. [Stat Gains Per Level](#stat-gains-per-level)
3. [Trait System](#trait-system)
4. [Stat System](#stat-system)
5. [Soft & Hard Caps](#soft--hard-caps)
6. [World Tier Progression](#world-tier-progression)
7. [Mastery Perks System](#mastery-perks-system)
8. [Alignment System](#alignment-system)

---

## Level Curve & XP

### Per-Run Leveling

Tiny Rogues uses a per-run leveling system that resets each adventure.

| Property | Value |
|----------|-------|
| **Maximum Level** | 6 per run (hard cap) |
| **XP Source** | Food items (+1 EXP each) |
| **Level Rewards** | Trait selection at each level |

#### XP Modifiers

| Modifier | Source | Effect |
|----------|--------|--------|
| **Head Start** | Mastery perk | +1 EXP at run start |
| **Shortcut** | Mastery perk | +5 EXP at start, but costs +1 EXP per level thereafter |

**Example**: With `Shortcut`, you need 2 EXP for level 2, 3 EXP for level 3, etc.

### Meta-Progression (Mastery Perks)

Permanent progression system that persists across runs.

| Property | Value |
|----------|-------|
| **Maximum Points** | 30 total (hard cap) |
| **XP Source** | Boss Crowns fill EXP bar |
| **Acceleration** | Cinders increase EXP gained per crown |

**Progression Loop**: More Cinders (difficulty) → More EXP per crown → Faster mastery unlock

See [Mastery Perks System](#mastery-perks-system) for details on perk trees.

---

## Stat Gains Per Level

### Food System (Floors 1-10)

Food items provide **+1 EXP** and stat bonuses when consumed. Players choose food at each level to shape their build.

#### Single-Stat Foods

| Food | Stat Bonus | Notes |
|------|------------|-------|
| `Beef` | +1 STR | Balanced strength gain |
| `Sausage` | +2 STR, -1 INT | High strength, INT penalty |
| `Meat Shank` | +3 STR | Maximum strength gain |
| `Pear` | +1 DEX | Balanced dexterity gain |
| `Salad` | +2 DEX, -1 STR | High dexterity, STR penalty |
| `Broccoli` | +3 DEX | Maximum dexterity gain |
| `Candy` | +1 INT | Balanced intelligence gain |
| `Chocolate` | +2 INT, -1 DEX | High intelligence, DEX penalty |
| `Lollipop` | +3 INT | Maximum intelligence gain |

#### Hybrid Foods

| Food | Stat Bonus | Build Synergy |
|------|------------|---------------|
| `Burger` | +1 STR, +1 DEX | Melee-mobile hybrid |
| `Cake` | +1 DEX, +1 INT | Caster-mobile hybrid |
| `Fish N Chips` | +1 INT, +1 STR | Melee-caster hybrid |

**Strategic Note**: Penalty foods (+2/-1) are optimal for min-maxing builds but reduce flexibility.

### Golden Food (Floors 11-12)

Golden foods appear in late-game floors and provide **multiplicative bonuses** instead of raw stats.

| Food | Effect | Optimal Build |
|------|--------|---------------|
| `Golden Steak` | +10% non-crit damage | High base damage builds |
| `Golden Candy` | +2.5% Crit chance | Crit-focused builds |
| `Golden Pear` | +2.5% Attack speed | Fast weapon builds |
| `Golden Meat Shank` | +15 Equip load | Heavy armor/weapon builds |
| `Golden Broccoli` | +15% Crit multiplier | High crit chance builds |
| `Golden Lollipop` | +2.5% Mana drain refund | Mana weapon builds |
| `Ambrosia` | +1 to highest stat | Stat-scaling builds |
| `Golden Croissant` | +10% Companion damage | Summoner builds |
| `Golden Cherries` | +10% Trigger damage | Trigger-heavy builds |
| `Golden Clover` | +2.5% Lucky Hit chance | Lucky Hit builds |

**Late-Game Strategy**: Golden foods are **multiplicative**, making them stronger for optimized builds than raw stat foods.

---

## Trait System

Traits are permanent passive upgrades earned at each level (max 6 per run).

### Trait Categories

| Category | Count | Examples |
|----------|-------|----------|
| **Strength Traits** | 33+ | Damage boosts, armor penetration, heavy weapon bonuses |
| **Dexterity Traits** | 33+ | Attack speed, movement speed, dodge bonuses |
| **Intelligence Traits** | 33+ | Crit chance, mana regen, spell damage |
| **Class-Specific** | Varies | Unique traits tied to class mechanics |
| **Conditional** | Varies | Require specific equipment (e.g., shield equipped) |

**Total Traits**: 137+

### Trait Selection Mechanics

| Mechanic | Item | Effect |
|----------|------|--------|
| **Reroll** | `Ethereal Dice` | Reroll current trait options |
| **Reroll (Rare)** | `Obsidian Dice` | Reroll with rarity weighting |
| **Lock Traits** | (None in base game) | Cannot lock selections |

**Conditional Traits**: Some traits require specific equipment. For example:
- Shield traits require a shield equipped
- Dual-wield traits require two weapons
- Spell traits may require mana-scaling weapons

**Strategic Note**: Trait choice is permanent for the run. Plan around weapon/armor availability.

---

## Stat System

### Core Stats

Core stats scale weapon damage, attack speed, and utility.

| Stat | Primary Effects | Secondary Effects |
|------|-----------------|-------------------|
| **Strength (STR)** | Weapon scaling (STR grade), Damage dealt | Equip load capacity |
| **Dexterity (DEX)** | Weapon scaling (DEX grade), Attack speed | Movement speed |
| **Intelligence (INT)** | Weapon scaling (INT grade), Crit chance | Mana regeneration |

**Weapon Scaling**: Each weapon has a grade (S/A/B/C/D) for each stat. Higher grades = more damage per point. See [Soft & Hard Caps](#soft--hard-caps) for scaling details.

### Defensive Stats

| Stat | Effect | Notes |
|------|--------|-------|
| **HP (Hearts)** | Health pool | Lost on damage, can be healed |
| **Soul Hearts** | Temporary hearts | Lost before HP, cannot be healed |
| **Armor** | Damage reduction | Flat reduction per hit |
| **Shield** | Regenerating barrier | Regenerates after avoiding damage |
| **Block** | Chance to negate physical damage | Percentage-based |
| **Evade** | Chance to dodge attacks | Percentage-based |
| **Suppression** | Reduces enemy damage output | Debuff applied to enemies |

### Offensive Stats

| Stat | Base Value | Effect |
|------|------------|--------|
| **Crit Chance** | 5% | Chance to deal critical hit |
| **Crit Multiplier** | 200% | Damage multiplier on crit (2x base) |
| **Lucky Hit Chance** | 0% | Chance to trigger Lucky Hit effects |
| **Attack Speed** | 100% | Attacks per second multiplier |
| **Power** | 100% | Global damage multiplier |

**Crit Mechanics**: Base 5% chance, 200% damage (2x). Intelligence increases crit chance. Golden Broccoli increases multiplier.

### Resource Stats

| Stat | Mechanics | Notes |
|------|-----------|-------|
| **Mana** | +10% damage per point to mana-scaling weapons | Consumed by mana weapons, regenerates over time |
| **Stamina** | 3s recovery delay after use, 0.5s regen per point | Used for dodges/abilities, delayed recovery |

**Mana Scaling**: Each point of max mana increases mana weapon damage by **+10%**. High-INT builds benefit from mana stacking.

**Stamina Recovery**: After spending stamina, there's a **3-second delay** before regeneration begins. Each stamina point regenerates in **0.5 seconds** once recovery starts.

---

## Soft & Hard Caps

### Damage Scaling Soft Caps

Weapon stat scaling has **soft caps** based on weapon grade. After the cap, each stat point gives reduced returns.

| Grade | Soft Cap | Pre-Cap Scaling | Post-Cap Scaling |
|-------|----------|-----------------|------------------|
| **S** | 50 | +5% per point | +0.5% per point |
| **A** | 40 | +5% per point | +0.5% per point |
| **B** | 30 | +5% per point | +0.5% per point |
| **C** | 20 | +5% per point | +0.5% per point |
| **D** | 10 | +5% per point | +0.5% per point |

**Example**: An **S-grade STR weapon** gains +5% damage per STR point until 50 STR, then +0.5% per point after.

**Strategic Implication**: Diminishing returns after soft cap. Consider diversifying stats or switching to multiplicative bonuses (e.g., Golden Food).

### Hard Caps

| System | Hard Cap | Notes |
|--------|----------|-------|
| **Traits per Run** | 6 | One per level, no way to exceed |
| **Tipsiness (Booze Buffs)** | 3 (+1 per Cheese) | Alcohol buff stacking limit |
| **Mastery Perks** | 30 points | Total points across all branches |
| **Thief Crit Bonus** | +100% (at 1000 Gold) | +1% crit per 10 Gold held |

**Thief Class Example**: Carrying 500 Gold = +50% crit chance (added to base 5% = 55% total crit).

---

## World Tier Progression

World Tiers unlock new content and increase difficulty. Each tier requires defeating specific bosses or zones.

| Tier | Unlock Requirement | New Content |
|------|-------------------|-------------|
| **1** | Start the game | Base enemy sets, basic floors |
| **2** | Defeat `Death` (final boss) | Alternate floor layouts, new random events |
| **3** | Defeat `Death` with 5 different classes | `Shadow Planes` gate unlocked |
| **4** | Defeat `Shadow Planes` guardian | Ethereal shops, Ethereal-tier classes |
| **5** | Defeat `Primal Death` | `Burning Hells` & `High Heavens` gates unlocked |
| **6** | Defeat `Burning Hells` guardian | Infernal shops, Infernal-tier classes |
| **7** | Defeat `High Heavens` guardian | Angelic shops, Angelic-tier classes |
| **8** | Sit on both thrones (Hell & Heaven) | `Abyss` access (endgame zone) |

### Progression Path

```
World Tier 1 (Base Game)
  ↓
Defeat Death → World Tier 2
  ↓
Defeat Death with 5 classes → World Tier 3
  ↓
Shadow Planes → World Tier 4
  ↓
Primal Death → World Tier 5
  ↓
Burning Hells (Evil path) → World Tier 6
High Heavens (Good path) → World Tier 7
  ↓
Both Thrones → World Tier 8 (Abyss)
```

**Dual-Path System**: Tiers 5-8 require alignment-based progression (see [Alignment System](#alignment-system)).

---

## Mastery Perks System

Meta-progression tree with **30 total points** distributed across four directional branches.

### Branch Overview

| Branch | Focus | Example Perks |
|--------|-------|---------------|
| **North** | Survival & Economy | HP boosts, gold gain, healing bonuses |
| **East** | Loot & Gambling | Increased item drops, reroll discounts, chest quality |
| **South** | Weapons & Enchantments | Weapon damage, enchantment slots, scaling bonuses |
| **West** | Combat & Rewards | XP gain, boss rewards, combat bonuses |

### Perk Types

| Type | Description | Example |
|------|-------------|---------|
| **Linear** | Incremental bonuses | +5% HP per point (stackable) |
| **Choice Node** | Mutually exclusive options | Choose: "Start with +1 EXP" OR "Start with 50 Gold" |
| **Unlock** | Binary unlock | Unlock: "Ethereal shops appear" |

**Choice Nodes**: Some nodes offer 2-3 mutually exclusive perks. Choosing one locks out the others permanently.

### Progression Strategy

| Strategy | Branch Priority | Goal |
|----------|-----------------|------|
| **Early Power** | West (Combat & Rewards) | Faster leveling, better boss loot |
| **Survivability** | North (Survival & Economy) | More HP, sustain through runs |
| **Loot Farming** | East (Loot & Gambling) | Better item quality, more rerolls |
| **Scaling** | South (Weapons & Enchantments) | Late-game damage ceiling |

**Respec**: No respec system. Mastery choices are permanent.

---

## Alignment System

Four-axis morality system affecting shop access, item effects, and endgame gates.

### Alignment Axes

| Axis | Range | Neutral |
|------|-------|---------|
| **Good / Evil** | -4 to +4 | 0 |
| **Lawful / Chaotic** | -4 to +4 | 0 |

**Range**: Each axis goes from -4 (extreme) to +4 (extreme), with 0 being neutral.

### Alignment Effects

| Alignment | Shop Access | Item Effects | Endgame Gates |
|-----------|-------------|--------------|---------------|
| **Good (+4)** | Angelic shops | Holy damage bonuses | `High Heavens` gate |
| **Evil (-4)** | Infernal shops | Void/curse bonuses | `Burning Hells` gate |
| **Lawful (+4)** | Order-aligned merchants | Defense, armor bonuses | (None) |
| **Chaotic (-4)** | Chaos-aligned merchants | Crit, chaos bonuses | (None) |

### Alignment Shift Events

| Event Type | Alignment Change | Example |
|------------|------------------|---------|
| **Spare Enemy** | +1 Good | Spare mini-boss instead of killing |
| **Execute Enemy** | +1 Evil | Execute downed enemy |
| **Follow Rules** | +1 Lawful | Complete event without cheating |
| **Break Rules** | +1 Chaotic | Steal from shop, break event rules |

**Strategic Note**: Extreme alignment (±4) required for endgame gates. Plan alignment shifts early in run.

### Endgame Gate Requirements

| Gate | Alignment Requirement | World Tier Unlock |
|------|----------------------|-------------------|
| `High Heavens` | Good +4 | Tier 7 |
| `Burning Hells` | Evil -4 | Tier 6 |
| `Abyss` | Sit on both thrones | Tier 8 |

**Both Thrones**: Requires completing runs at both Good +4 and Evil -4 alignments. Not achievable in single run.

---

## Cross-References

- **Weapons & Scaling**: See [Items](items.md) for weapon grades and damage formulas
  - [Stat Scaling System](items.md#stat-scaling-system) - STR/DEX/INT weapon grades
  - [Equipment Rarity](items.md#equipment-rarity-system) - Drop rates and quality tiers
- **Classes**: See [Classes](classes.md) for class-specific traits and stat priorities
  - [Archetype Distribution](classes.md#archetype-distribution) - Build archetypes overview
  - [Unlock Progression](classes.md#unlock-progression-paths) - Class unlock requirements
- **Design Patterns**: See [Design Insights](design-insights.md) for analysis
  - [Layered Progression](design-insights.md#3-layered-progression-creates-satisfying-meta-loop) - Why this system works
  - [Risk-Reward Tension](design-insights.md#5-risk-reward-tension-in-resource-systems) - Penalty foods analysis

---

## Quick Reference Tables

### Food Stat Priority by Build

| Build Type | Primary Food | Secondary Food | Golden Food Priority |
|------------|--------------|----------------|----------------------|
| **Melee STR** | Meat Shank (+3 STR) | Burger (STR+DEX) | Golden Steak, Golden Meat Shank |
| **Crit DEX** | Broccoli (+3 DEX) | Cake (DEX+INT) | Golden Broccoli, Golden Candy |
| **Mana INT** | Lollipop (+3 INT) | Fish N Chips (INT+STR) | Golden Lollipop, Ambrosia |
| **Hybrid** | Burger/Cake/Fish N Chips | Match highest stat | Ambrosia, Golden Steak |

### Level Efficiency

| Level | EXP Required (Base) | EXP Required (Shortcut) | Cumulative EXP |
|-------|---------------------|-------------------------|----------------|
| 1 | 0 (start) | 0 (start + 5) | 0 |
| 2 | 1 | 2 | 1/2 |
| 3 | 1 | 3 | 2/5 |
| 4 | 1 | 4 | 3/9 |
| 5 | 1 | 5 | 4/14 |
| 6 | 1 | 6 | 5/20 |

**Shortcut Trade-off**: Get to level 6 faster early, but costs +15 total EXP vs. base +5 EXP.

---

**Document Version**: 1.0  
**Last Updated**: 2026-01-08  
**Maintainer**: Design Documentation Team
