# Design Insights: Tiny Rogues

Analysis of notable design patterns observed during documentation extraction. These insights focus on mechanical design choices that contribute to Tiny Rogues' gameplay depth and replayability.

---

## Table of Contents

1. [Build Diversity Through Multiplicative Systems](#1-build-diversity-through-multiplicative-systems)
2. [Commitment Mechanics Prevent Optimization Paralysis](#2-commitment-mechanics-prevent-optimization-paralysis)
3. [Layered Progression Creates Satisfying Meta-Loop](#3-layered-progression-creates-satisfying-meta-loop)
4. [Class Design as Build Constraint System](#4-class-design-as-build-constraint-system)
5. [Risk-Reward Tension in Resource Systems](#5-risk-reward-tension-in-resource-systems)

---

## 1. Build Diversity Through Multiplicative Systems

### Observation

Tiny Rogues creates emergent build diversity by layering **multiplicative bonuses** on top of **additive base systems**.

### Evidence

**Stat Scaling (Additive Foundation)**:
- Each stat point adds flat +5% damage (pre-soft cap)
- Simple, predictable power growth

**Golden Foods (Multiplicative Layer)**:
- `Golden Steak`: +10% non-crit damage
- `Golden Broccoli`: +15% crit multiplier
- `Golden Candy`: +2.5% crit chance

**Class Innates (Multiplicative Modifiers)**:
- Knight's `Defiance`: x1.10 damage per Armor Container
- Thief's `Reliable Talent`: +1% crit per 10 gold
- Pyromancer's `Inner Flame`: +20% tick speed per Mana Container

### Why It Works

1. **Early game simplicity**: New players can focus on "more STR = more damage"
2. **Late game depth**: Experienced players optimize multiplicative stacking
3. **No single "best" build**: Different multiplicative layers favor different strategies

### Design Principle

> Additive systems provide linear growth; multiplicative systems create exponential payoffs that reward optimization without punishing casual play.

---

## 2. Commitment Mechanics Prevent Optimization Paralysis

### Observation

Multiple systems force players to commit early, reducing analysis paralysis and creating meaningful choices.

### Evidence

**Attunement System**:
- Equipment requires 1-3 combat rooms to activate
- Prevents mid-fight gear swapping
- Creates commitment to loadout decisions

**Trait System**:
- Max 6 traits per run (1 per level)
- No respec available
- Early trait picks lock out late-game flexibility

**Mastery Perks**:
- Permanent choices across all runs
- Choice nodes are mutually exclusive
- No respec system

**Alignment System**:
- Early alignment shifts affect endgame access
- Reaching +4 Good or -4 Evil requires multiple decisions
- Cannot pivot mid-run

### Why It Works

1. **Reduces decision fatigue**: Once committed, stop second-guessing
2. **Creates identity**: "I'm a crit build" vs. "I'm a tank build"
3. **Increases replayability**: Different choices = different experiences
4. **Raises stakes**: Choices matter because they're permanent

### Design Principle

> Commitment mechanics create meaningful decisions. When everything is reversible, nothing feels important.

---

## 3. Layered Progression Creates Satisfying Meta-Loop

### Observation

Progression operates on **three distinct layers**, each with different time horizons and reward structures.

### Evidence

**Layer 1: Within-Run Progression** (5-30 minutes)
- Level 1-6 (6 traits)
- Equipment upgrades (level 1-4)
- Stat accumulation (food choices)
- **Reward**: Immediate power growth

**Layer 2: Meta-Progression** (hours)
- Mastery Perks (30 points)
- Class unlocks (34 classes)
- World Tier advancement (8 tiers)
- **Reward**: Permanent power/options

**Layer 3: Endgame Goals** (days/weeks)
- Throne ascensions
- Guardian defeats
- Alignment completionism
- **Reward**: Content access + prestige

### Progression Math

| Layer | Time Investment | Reward Type | Carries Over |
|-------|-----------------|-------------|--------------|
| Within-Run | Minutes | Power | No |
| Meta-Progression | Hours | Options | Yes |
| Endgame | Days | Content | Yes |

### Why It Works

1. **Short sessions feel rewarding**: Always gaining something (XP, unlocks)
2. **Long sessions feel rewarding**: Making progress on meta-goals
3. **Veteran players stay engaged**: Endgame goals provide long-term hooks
4. **New players aren't overwhelmed**: Layer 1 is simple and satisfying

### Design Principle

> Multiple progression layers ensure every play session feels rewarding, regardless of length or skill level.

---

## 4. Class Design as Build Constraint System

### Observation

Classes don't just provide starting bonuses - they **constrain and direct** build choices through innate mechanics.

### Evidence

**Stat Constraints**:
- Barbarian starts with 6 STR, 1 DEX, 1 INT
- Effectively forces STR-scaling weapon builds
- Other stats become "luxury" investments

**Mechanic Constraints**:
- Necromancer's `Soul Reaper`: Companion damage scales with souls
- Forces companion-heavy builds, discourages solo play
- Wizard's `Wisdom`: Gains mana at levels 2, 4, 6
- Rewards mana-scaling weapons specifically

**Unlock Constraints**:
- Roster 2 classes require specific base class achievements
- Paladin requires Knight → Celestial Throne
- Creates natural build progression: Knight builds → Paladin builds

### Build Diversity Analysis

| Class | Viable Build Archetypes | Constrained Away From |
|-------|-------------------------|----------------------|
| Knight | Tank, Block-focused | Pure DPS, glass cannon |
| Thief | Crit, gold-farming | Tank, defensive |
| Necromancer | Summoner, companion | Solo, weapon-focused |
| Doppelganger | Any (shapechanger) | Consistency |

### Why It Works

1. **Reduces choice overload**: Can't pick "everything good"
2. **Creates class identity**: Each class feels distinct
3. **Encourages experimentation**: "How do I make X work with this class?"
4. **Enables balance**: Developers can balance around expected builds

### Design Principle

> Constraints enable creativity. Classes that do everything become classes that feel like nothing.

---

## 5. Risk-Reward Tension in Resource Systems

### Observation

Multiple systems create **tension** between safety and power, forcing player agency.

### Evidence

**Penalty Foods**:
- `Sausage`: +2 STR, -1 INT
- Higher reward but permanently reduces flexibility
- Decision: Power now vs. options later

**Tipsiness (Booze)**:
- 3 stacks maximum
- High stacks = big buffs + potential debuffs
- Decision: How much risk to take?

**Deprived Class**:
- 1 HP, +10% stats per curse
- Extreme glass cannon design
- Decision: Accept vulnerability for power?

**Demon Hunter's Tainted Rooms**:
- More enemies, x2 rewards
- Risk death for faster progression
- Decision: Fight harder for more loot?

**Thief's Gold-Crit Scaling**:
- Holding gold = more crit chance
- Spending gold = lose crit chance
- Decision: Hoard for power or spend for items?

### Risk-Reward Matrix

| System | Risk | Reward | Player Agency |
|--------|------|--------|---------------|
| Penalty Foods | Stat loss | Stat gain | Permanent build choice |
| Tipsiness | Debuffs | Buffs | Per-encounter tuning |
| Deprived | Low HP | High stats | Class selection |
| Tainted Rooms | Harder combat | More loot | Room-by-room decision |
| Thief Gold | Can't shop | Crit chance | Economy management |

### Why It Works

1. **Creates tension**: Every resource decision matters
2. **Enables player expression**: Risk-takers vs. safe players
3. **Provides comeback mechanics**: Risky plays can recover bad runs
4. **Increases skill ceiling**: Optimal play requires risk assessment

### Design Principle

> Risk-reward systems create engagement through tension. Players invest emotionally when something is at stake.

---

## Summary: Core Design Pillars

| Pillar | Implementation | Player Effect |
|--------|----------------|---------------|
| **Multiplicative Depth** | Layered bonus systems | Rewards optimization |
| **Commitment** | Attunement, permanent traits | Creates meaningful choices |
| **Layered Progression** | Run/Meta/Endgame loops | Every session feels rewarding |
| **Constraint-Driven Classes** | Stat/mechanic constraints | Enables diverse playstyles |
| **Risk-Reward Tension** | Trade-off systems | Creates engagement/stakes |

---

## Applicability to Our Project

### Recommended Adoptions

1. **Multiplicative layering**: Keep additive base stats, add multiplicative modifiers via equipment/cards
2. **Commitment mechanics**: Card deck composition, permanent upgrade choices
3. **Multi-layer progression**: Per-run upgrades + meta-unlocks + long-term goals
4. **Class constraints**: Starter decks/abilities that push toward specific archetypes

### Cautions

1. **Soft caps require tuning**: Too aggressive = feels bad; too lenient = infinite scaling
2. **Commitment needs escape valves**: Some way to recover from truly bad choices
3. **Risk-reward needs floor**: Pure punishment without comeback potential feels unfair

---

**Document Version**: 1.0  
**Last Updated**: 2026-01-08  
**Purpose**: Design reference for inspired roguelike development
