# Path of Achra: Design Summary & Implementation Guide

## Overview

This document synthesizes findings from all Path of Achra research to provide actionable design guidance for implementing a survivors-like game inspired by its mechanics.

---

## Core Design Philosophy

### Event-Driven Everything
Path of Achra's defining characteristic is that **almost no abilities are directly activated**. Instead, abilities trigger based on game events:
- Player actions (attack, step, stand still, pray)
- Defensive events (being attacked, dodging, blocking)
- Combat results (hit, kill, damage dealt)
- State changes (entering area, leveling up)

**Why This Matters for Survivors-Like**: This creates emergent gameplay where builds feel unique based on trigger combinations, not button mashing.

### Stat Synergy Chains
Stats don't just scale damage - they enable cascading effects:
- Speed -> Movement triggers -> Extra attacks -> Kill triggers -> Heal/buff
- Armor -> Shrug-off triggers -> Counterattack -> Damage -> Kill chain

### Three-Layer Character Building
1. **Class** - Base stats, equipment, signature abilities
2. **Culture** - Resistances, stat bonuses, passive effects
3. **Religion** - Active prayers, divine intervention, playstyle definition

---

## Stat Distribution Analysis

### Primary Stats Across All Sources

| Stat | Classes | Cultures | Religions | Total Instances | Average Bonus |
|------|---------|----------|-----------|-----------------|---------------|
| STR | 15 | 12 | 16 | 43 | +2.1 |
| DEX | 14 | 10 | 12 | 36 | +2.0 |
| WIL | 12 | 10 | 18 | 40 | +2.3 |
| Life | 8 | 6 | 12 | 26 | +62 |
| Speed | 6 | 4 | 8 | 18 | +6.2 |

**Design Insight**: WIL (magic/summoning) is most universally valuable. Speed is rare but powerful.

### Resistance Distribution

| Damage Type | Items with Resist | Max Resist | Notes |
|-------------|-------------------|------------|-------|
| Fire | 25+ | 50% | Very common |
| Ice | 20+ | 50% | Common, often paired with Fire |
| Poison | 20+ | 50% | Common |
| Death | 15+ | 50% | Medium frequency |
| Astral | 15+ | 50% | Medium frequency |
| Lightning | 12+ | 50% | Medium frequency |
| Psychic | 12+ | 50% | Medium frequency |
| Blood | 10+ | 50% | Less common |
| Physical (Slash/Pierce/Blunt) | 8+ | 30% | Rarer, usually grouped |

**Design Insight**: Elemental resistance is more common than physical. Build diversity comes from stacking specific resistances.

---

## Trigger Frequency Analysis

### Most Common Triggers (Priority for Implementation)

| Trigger | Usage Frequency | Complexity | Priority |
|---------|-----------------|------------|----------|
| On hit | Very High | Low | 1 |
| On attack | Very High | Low | 1 |
| On kill | High | Low | 1 |
| On being attacked | High | Medium | 2 |
| On stand still | High | Medium | 2 |
| On prayer | High | Medium | 2 |
| On entrance (area) | High | Low | 2 |
| On apply [effect] | Medium | Medium | 3 |
| On dodge | Medium | Medium | 3 |
| On block | Medium | Medium | 3 |
| On self-damage | Low | High | 4 |
| On teleport | Low | High | 4 |

### Trigger Chain Examples

**Fire Caster Chain**:
```
On stand still -> Deal Fire damage -> Apply Scorch -> 
On apply Scorch -> Deal bonus damage -> On kill -> Heal
```

**Speed Assassin Chain**:
```
On step -> Deal Slash damage -> On hit -> Apply Bleed ->
On apply Bleed -> Extra attack -> On kill -> +Speed
```

**Tank Chain**:
```
On being attacked -> Apply Poise -> On shrug-off -> 
Counterattack -> On hit -> Heal = Armor
```

---

## Status Effect Taxonomy

### Damaging Effects (DoT)
| Effect | Damage Type | Tick Rate | Removed By |
|--------|-------------|-----------|------------|
| Scorch | Fire | Per turn | Willpower, prayer |
| Freeze | Ice | Per turn | Willpower, movement |
| Sickness | Poison | Per turn | Willpower, prayer |
| Doom | Death | Threshold | Willpower (hard) |
| Bleed | Blood | Per turn | Willpower, healing |
| Plague | Death/Poison | Spreading | Hard to remove |
| Corrosion | Armor reduction | Persistent | Willpower |

### Buff Effects
| Effect | Primary Benefit | Scaling |
|--------|-----------------|---------|
| Poise | +Armor, +Block, +Accuracy | Per stack |
| Inflame | +Hit, +damage | Per stack |
| Charge | +Speed | Per stack |
| Grace | +various | Per stack, prayer-specific |
| Meditate | +Magic damage | Per stack |
| Repulsion | +Block, +Psychic damage | Per stack |
| Bloodrage | +Hit, attack bonuses | Per stack |

### Transformation Effects
| Effect | Benefits | Duration |
|--------|----------|----------|
| Drakeform | +Armor, +Hit, special attacks | Stack-based decay |
| Newtform | Fire immunity, +Fire damage | Stack-based decay |
| Snakeform | +Dodge, Poison bonuses | Stack-based decay |
| Batform | +Lifesteal, mobility | Stack-based decay |
| Geistform | +Ice, intangibility | Stack-based decay |

### Control Effects
| Effect | Impact | Counter |
|--------|--------|---------|
| Entangle | Movement reduction | Willpower, cutting |
| Stasis | Action freeze | Time-based |
| Blind | Accuracy reduction | Time-based |
| Mark | Detonation target | Triggered |

---

## Build Archetype Analysis

### From Class/Culture/Religion Combinations

#### 1. Glass Cannon Speed Build
- **Class**: Amir (+Speed), Duelist (extra attacks)
- **Culture**: Vani/Mau (+Speed, +Dodge)
- **Religion**: Tengri (Speed -> damage conversion)
- **Powers**: Electromancy, Technique, Herja
- **Key Stats**: Speed 40+, Dodge 300+, low Armor
- **Playstyle**: Never stop moving, kill before being hit

#### 2. Immortal Tank
- **Class**: Warden (+Armor), Gladiator (+Block)
- **Culture**: Tusker/Slanik (+Life, +Physical resist)
- **Religion**: Dorok (Poise stacking, injury rewards)
- **Powers**: Heavyweight, Guard, Frost Armor
- **Key Stats**: Armor 200+, Life 500+, Block 100+
- **Playstyle**: Absorb damage, counterattack, never die

#### 3. Summoner Swarm
- **Class**: Beastmaster, Druid
- **Culture**: Keliot (+WIL, summon bonuses)
- **Religion**: Formus (Ant army) or Eresh (Undead)
- **Powers**: Necromancy, Innervation, Invigoration
- **Key Stats**: WIL 10+, Summon Limit 50+
- **Playstyle**: Overwhelm with numbers, buff minions

#### 4. Self-Damage Berserker
- **Class**: Berserker, Blood Knight
- **Culture**: Irga (+Blood resist, self-damage synergy)
- **Religion**: Phoenix or Apophis (self-damage -> power)
- **Powers**: Gore Cleave, Batform, Amplify Pain
- **Key Stats**: Life 400+, Blood Resist 50%+
- **Playstyle**: Hurt yourself to hurt enemies more

#### 5. Status Effect Stacker
- **Class**: Venomancer, Blight Knight
- **Culture**: Brud (+Poison), Heliot (+Corrosion)
- **Religion**: The Worm (Corrosion aura) or Takhal (Plague)
- **Powers**: Morbumancy, Acidify, Master Doom
- **Key Stats**: WIL 8+, Effect application bonuses
- **Playstyle**: Stack debuffs, watch enemies melt

---

## Implementation Roadmap for Survivors-Like

### Phase 1: Core Systems (Essential)

#### Event Bus
```lua
-- Required events to support most abilities
local CORE_EVENTS = {
    "on_attack",
    "on_hit", 
    "on_kill",
    "on_being_attacked",
    "on_being_hit",
    "on_damage_dealt",
    "on_damage_taken",
    "on_step",
    "on_stand_still",
    "on_entrance"
}
```

#### Stat System
- Base stats: STR, DEX, WIL, Life, Speed
- Derived stats: Hit, Accuracy, Armor, Block, Dodge
- Damage types: At least 6 (Slash, Pierce, Blunt, Fire, Ice, Poison)
- Resistances: Per damage type, 0-100%

#### Effect System
- Stack-based buffs (Inflame, Poise, etc.)
- DoT effects (Scorch, Bleed, Sickness)
- Mark/detonation system

### Phase 2: Combat Mechanics (Important)

#### Attack Sequence
```
1. Trigger on_attack
2. Roll accuracy vs dodge
3. If hit: trigger on_hit, calculate damage
4. Apply damage modifiers (armor, resistance)
5. Trigger on_damage_dealt / on_damage_taken
6. Check kill -> trigger on_kill
```

#### Defense Mechanics
- Dodge (avoid hit entirely)
- Block (reduce damage)
- Armor (flat damage reduction)
- Shrug-off (negate hit if armor > damage)

#### Extra Attacks
Many triggers grant "extra attacks" - must handle recursion limits.

### Phase 3: Character Building (Build Diversity)

#### Class System
- Starting stats
- Signature abilities (2-3 per class)
- Equipment restrictions/bonuses

#### Culture System (can simplify)
- Resistance package
- One passive ability
- Stat bonuses

#### Religion/Prayer System (can simplify)
- 3 active abilities
- Charge/cooldown mechanics
- Divine intervention (emergency mechanic)

### Phase 4: Advanced Mechanics (Polish)

#### Summoning
- Minion stats scale with player
- Minion death triggers
- Summon limits

#### Transformations
- Stacking transformation buffs
- Form-specific abilities
- Decay mechanics

#### Equipment System
- Weapon types with different triggers
- Armor slots with effects
- Set bonuses (optional)

---

## Simplified Survivors-Like Adaptation

### What to Keep
1. **Event-driven abilities** - Core identity
2. **Status effect stacking** - Build depth
3. **Multiple damage types** - Resistance strategy
4. **Stat scaling** - Build diversity

### What to Simplify
1. **Reduce damage types**: 4-6 instead of 15
2. **Simplify defense**: Dodge + Armor only (skip Block/Shrug-off)
3. **Merge Class/Culture**: Single "Origin" choice
4. **Streamline prayers**: 1-2 active abilities instead of 3

### Survivors-Specific Additions
1. **Auto-attack**: Remove manual attack, trigger on proximity
2. **Area damage**: Most abilities should be AoE
3. **Scaling waves**: Enemy count/HP increases over time
4. **Power-up drops**: Replace equipment with temporary buffs

---

## Key Takeaways

### Design Principles
1. **Triggers over cooldowns** - Abilities fire based on events, not timers
2. **Synergy over power** - Weak triggers that combo > strong isolated effects
3. **Scaling stats** - Everything should scale with *something*
4. **Risk/reward** - Self-damage, empty armor, low life builds are valid

### Implementation Priorities
1. Event system (everything depends on this)
2. Status effects (defines build diversity)
3. Damage types + resistances (strategic layer)
4. Triggers for abilities (actual gameplay loop)

### Avoid
- Direct-activation abilities (breaks the trigger paradigm)
- Flat damage numbers (no scaling = no builds)
- Universal best options (every choice should have trade-offs)

---

## Document Index

| Document | Content |
|----------|---------|
| [Classes.md](Classes.md) | 24 classes with stats, abilities, equipment |
| [Cultures.md](Cultures.md) | 24 cultures with resistances, passives |
| [Religions.md](Religions.md) | 24 religions with prayers, divine intervention |
| [Powers.md](Powers.md) | 70+ powers across 10 elements |
| [Items.md](Items.md) | Weapons, armor, triggered effects |
| [Triggers.md](Triggers.md) | Complete trigger list, attack sequence |

---

## Quick Reference Tables

### Stat Bonuses by Source (Maximum)
| Stat | Classes | Cultures | Religions | Items |
|------|---------|----------|-----------|-------|
| STR | +4 | +4 | +4 | +∞ (scaling) |
| DEX | +4 | +4 | +4 | +∞ (scaling) |
| WIL | +4 | +4 | +4 | +∞ (scaling) |
| Life | +150 | +100 | +100 | +∞ (scaling) |
| Speed | +15 | +10 | +10 | +∞ (scaling) |

### Common Trigger -> Effect Patterns
| Trigger | Common Effects |
|---------|----------------|
| On hit | Apply status, deal bonus damage, heal |
| On kill | Heal, apply buff, summon, chain attack |
| On being attacked | Counter damage, apply debuff, gain defense |
| On stand still | AoE damage, apply status, regenerate |
| On step | Deal damage, apply buff, trigger movement ability |
| On apply [status] | Deal damage, spread status, gain buff |
