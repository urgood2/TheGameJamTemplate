# Path of Achra: Cultures Reference

## Overview

Cultures are one of three primary character creation choices in Path of Achra. There are **24 cultures**, each with:
- Unique abilities (triggered effects)
- Starting stats (Life, Speed, STR, DEX, WIL)
- Elemental resistances (positive = resist, negative = vulnerability)

Cultures focus more on passive bonuses and resistances compared to Classes which define combat style.

---

## Design Patterns

### Stat Distribution Analysis

| Stat | Range | Average | Notes |
|------|-------|---------|-------|
| Life | +50 to +400 | ~180 | Non-humans get higher HP pools |
| Speed | +2 to +10 | ~4.5 | Tengu highest (+10), slow giants (+2) |
| STR | +1 to +5 | ~2 | Physical cultures get +3-5 |
| DEX | +1 to +4 | ~1.7 | Agile cultures get +3-4 |
| WIL | +1 to +6 | ~1.8 | Magical creatures get +3-6 |

### Resistance Patterns

| Resistance Type | Range | Common At |
|-----------------|-------|-----------|
| Physical (Slash/Pierce/Blunt) | +25% to +50% | Warriors, Undead |
| Fire | -50% to +75% | Desert dwellers (+), Plants (-) |
| Ice | +25% to +75% | Northern cultures |
| Lightning | -50% to +75% | Storm creatures |
| Poison | +50% to +75% | Reptiles, Undead |
| Death | +25% to +75% | Undead, Dark creatures |
| Psychic | -25% to +75% | Mindless creatures (+), Apes (-) |
| Astral | -25% to +75% | Divine/Void beings |
| Blood | +50% to +75% | Barbarians, Undead |

---

## Culture Archetypes

### Human/Nomad Cultures

#### Stran (Desert Wanderer)
- **Stats**: Life +250, Speed +5, STR +1, DEX +1, WIL +1
- **Resistances**: Slash +25%
- **Abilities**:
  - On entrance: Summon a loyal Tugar familiar
  - On prayer: Tugar gains +25% Hit and heals 25% of max Life
- **Design Notes**: Pet class with prayer-powered familiar buffs.

#### Naqui (Mountain Temple-lands)
- **Stats**: Life +225, Speed +4, STR +1, DEX +1, WIL +2
- **Resistances**: Fire +25%
- **Abilities**:
  - On prayer: Increase Attune stacks by 20% (min +2, max +30)
  - On entrance: Apply 5 Attune (+5 per fully charged prayer)
  - On being attacked: Apply 1 Attune to yourself
- **Design Notes**: Attunement stacking culture. Rewards prayer management.

#### Albaz (Northern Ice Caves)
- **Stats**: Life +150, Speed +5, STR +1, DEX +2, WIL +1
- **Resistances**: Ice +25%
- **Abilities**:
  - On prayer or game turn, if enemies live: Heal yourself (100 + DEX * 10)
- **Design Notes**: Sustained healing culture. Scales with DEX.

#### Alhaja (Desert of Gods)
- **Stats**: Life +250, Speed +5, STR +2, DEX +1, WIL +1
- **Resistances**: Psychic +25%
- **Abilities**:
  - On entrance: Grant 1 charge to each known prayer
  - On prayer: Perform hit against 1 enemy in 2 tile range (Hit = Main-hand)
- **Design Notes**: Prayer attacker. Entrance bonus accelerates prayer cycle.

#### Virya (Northern Foothills)
- **Stats**: Life +300, Speed +8, STR +2, DEX +2, WIL +1
- **Resistances**: Fire +20%, Ice +20%, Lightning +20%
- **Abilities**:
  - On picking up Slash weapon: Transform into Mighty Blade
  - Transforms class weapons regardless of damage type
- **Design Notes**: Weapon transformer. Forces Slash/Greatsword builds.

### Barbarian/Warrior Cultures

#### Lochra (Deep Forest)
- **Stats**: Life +300, Speed +3, STR +3, DEX +1, WIL +1
- **Resistances**: Psychic -10%, Blood +50%
- **Abilities**:
  - On being dealt damage: Apply 2 Berserk (+1 if self-damage)
- **Design Notes**: Berserker culture. Self-damage synergy.

#### Arjana (Northern Snow)
- **Stats**: Life +200, Speed +4, STR +2, DEX +1, WIL +1
- **Resistances**: Fire +25%, Ice +25%
- **Abilities**:
  - On apply Blind or Freeze: +DEX stacks applied
  - On hit: Apply 1 Blind to target
- **Design Notes**: CC amplifier. Blind/Freeze specialist.

#### Valr (Frozen Waste)
- **Stats**: Life +125, Speed +4, STR +2, DEX +2, WIL +2
- **Resistances**: Pierce +25%, Ice +25%, Astral +25%
- **Abilities**:
  - +25% block chance
  - On ally death: Deal Death damage to 1 enemy at any range (20% of Block)
  - On divine intervention: Perform 3x
- **Design Notes**: Defensive death mage. Ally death triggers offense.

#### Cyclops (Giant Island)
- **Stats**: Life +300, Speed +2, STR +5, DEX +1, WIL +1
- **Resistances**: Slash +50%, Pierce +50%
- **Abilities**:
  - On attack: Deal Blunt damage to adjacent units (50% of current Life)
- **Design Notes**: Slow giant. Life-based AoE cleave.

#### Ape (Forest/Mountain Caves)
- **Stats**: Life +350, Speed +5, STR +5, DEX +1, WIL +1
- **Resistances**: Psychic -25%
- **Abilities**:
  - Per empty armor slot: +5% all Resistances
  - Per equipped armor: -10% all Resistances
  - On adjacent attack: Apply Inflame equal to STR
- **Design Notes**: Naked fighter. Punishes armor equipping.

### Agile/Scout Cultures

#### Kull (Underground Tunnels)
- **Stats**: Life +200, Speed +7, STR +1, DEX +4, WIL +1
- **Resistances**: Death +25%
- **Abilities**:
  - On step or dodge: Apply 3 Evasion to yourself
- **Design Notes**: Evasion stacker. Movement-based defense.

#### Tengu (Storm Temple Exile)
- **Stats**: Life +100, Speed +10, STR +1, DEX +3, WIL +1
- **Resistances**: Lightning +75%
- **Abilities**:
  - On attack: Apply 2 Charge to yourself, Deal 50 Lightning to 1 enemy at any range
- **Design Notes**: Fastest culture. Lightning attacker.

#### Imp (Infernal Plane Exile)
- **Stats**: Life +50, Speed +5, STR +1, DEX +2, WIL +1
- **Resistances**: None
- **Abilities**:
  - -2 Inflexibility
  - On dealing damage: Change damage type to random type
- **Design Notes**: Chaotic damage. Unpredictable but flexible.

### Magical/Mystical Cultures

#### Qamar (Astral Wall)
- **Stats**: Life +200, Speed +6, STR +1, DEX +1, WIL +3
- **Resistances**: Astral +75%
- **Abilities**:
  - On teleport, per empty armor slot: Deal 100 Astral in path to enemy in 3 range
  - On stand still, if enemies live: Teleport random, Apply 5 Stasis
  - On game turn: Remove Stasis from yourself
- **Design Notes**: Teleport mage. Rewards naked armor build + standing still.

#### Ihra (Divine Spirit)
- **Stats**: Life +100, Speed +5, STR +2, DEX +2, WIL +2
- **Resistances**: Psychic +25%, Astral +25%
- **Abilities**:
  - On entrance or game turn: Apply 1 Protection to yourself
  - On picking up leg armor: Transform into Ihranic Gem
- **Design Notes**: Divine protector. Item transformer.

#### Siku (High Glaciers)
- **Stats**: Life +100, Speed +2, STR +2, DEX +1, WIL +2
- **Resistances**: Ice +75%
- **Abilities**:
  - +3 Inflexibility
  - Inflexibility no longer divides WIL Damage Bonus
  - On being attacked or stand still: Deal Ice damage in path (Inflexibility * WIL)
- **Design Notes**: Ice beam caster. Inflexibility synergy removes penalty.

#### Koszmar (Infernal Chasm)
- **Stats**: Life +100, Speed +3, STR +1, DEX +1, WIL +6
- **Resistances**: Slash -20%, Blunt -20%, Pierce -20%, Psychic +75%
- **Abilities**:
  - Accuracy limited to 20
  - On being dealt damage: Deal Psychic damage to enemy at any range (= damage received, 3x if unencumbered)
- **Design Notes**: Damage reflection. Glass cannon with psychic revenge.

### Non-Human Cultures

#### Skeleton (Undead)
- **Stats**: Life +50, Speed +2, STR +1, DEX +1, WIL +1
- **Resistances**: Slash +25%, Pierce +25%, Poison +75%, Death +75%, Psychic +75%, Astral -25%, Blood +75%
- **Design Notes**: Massive resistances but low stats. Item-scaling through bag mechanic.
- **Abilities**:
  - Per item in bag: Gain Armor and Block equal to Glory

#### Arba (Plant-folk)
- **Stats**: Life +400, Speed +2, STR +1, DEX +1, WIL +1
- **Resistances**: Fire -50%, Poison +75%
- **Abilities**:
  - Per point of Inflexibility: +5% all Resistances
  - On stand still: Summon Vinespawn
- **Design Notes**: Slow tank summoner. Inflexibility boosts defense.

#### Volkite (Lava Flats)
- **Stats**: Life +300, Speed +2, STR +2, DEX +1, WIL +1
- **Resistances**: Fire +75%
- **Abilities**:
  - Per point of Encumbrance: +5% Armor
  - On being hit by adjacent enemy: Deal Fire damage in 2 range (Encumbrance * 20)
- **Design Notes**: Heavy armor tank. Encumbrance = power.

#### Saurian (Reptilian)
- **Stats**: Life +100, Speed +3, STR +2, DEX +3, WIL +1
- **Resistances**: Fire +75%, Poison +75%
- **Abilities**:
  - Per point of DEX: +1 summon limit
  - On step or stand still: Deal Poison in path to enemy in 3 range (10 * (STR + DEX))
- **Design Notes**: Poison spitter. Summon scaling + ranged poison.

### Special/Unique Cultures

#### Brud (Filth-valleys)
- **Stats**: Life +400, Speed +3, STR +3, DEX +1, WIL +1
- **Resistances**: Poison +50%, Lightning -50%, Death +50%, Blood +50%
- **Abilities**:
  - On being dealt damage: Apply 5 Doom to 1 enemy in 5 range
  - On attack: Heal yourself (target's Doom + Bleed + Plague stacks)
- **Design Notes**: Affliction feeder. Spreads and consumes debuffs.

#### Goblin (Tunnel-dweller)
- **Stats**: Life +50, Speed +3, STR +1, DEX +1, WIL +1
- **Resistances**: None
- **Abilities**:
  - On sacrifice: +1 base Speed, +25 max Life
- **Design Notes**: Item sacrificer. Permanent upgrades from gear.

#### Morlock (Deep Tunnels)
- **Stats**: Life +50, Speed +6, STR +2, DEX +2, WIL +2
- **Resistances**: Slash +25%, Blunt +25%, Pierce +25%
- **Abilities**:
  - On entrance, per empty armor slot: Grant 1 prayer charge, Deal 20% Blood self-damage, Summon Sacred Skin familiar
- **Design Notes**: Naked summoner with prayer synergy. Self-harm for power.

---

## Stat Formulas Used

| Formula | Cultures | Purpose |
|---------|----------|---------|
| `Heal = 100 + DEX * 10` | Albaz | Regen scaling |
| `Damage = DEX` | Arjana | Blind/Freeze stacks |
| `Damage = 20% of Block` | Valr | Block-based offense |
| `Damage = 50% current Life` | Cyclops | Life-based cleave |
| `Damage = Inflexibility * WIL` | Siku | Ice beam |
| `Damage = Encumbrance * 20` | Volkite | Weight-based fire |
| `Damage = 10 * (STR + DEX)` | Saurian | Poison damage |
| `Armor/Block = Glory` | Skeleton | Progression scaling |

---

## Resistance Distribution Summary

| Culture | Total Resist % | Notable |
|---------|----------------|---------|
| Skeleton | +275% (7 types) | Most resistances, Astral weakness |
| Brud | +150% (4 types) | Lightning weakness |
| Cyclops | +100% (2 types) | Physical immunity focus |
| Volkite | +75% (1 type) | Pure Fire immune |
| Tengu | +75% (1 type) | Lightning immune |
| Qamar | +75% (1 type) | Astral immune |
| Siku | +75% (1 type) | Ice immune |
| Koszmar | +15% net | Physical weaknesses, Psychic immune |
| Ape | -25% (1 type) | Psychic vulnerability |
| Arba | +25% net | Fire vulnerability |

---

## Implementation Notes for Survivors-like Game

### Supported Mechanics (Easy)
- Stat bonuses (Life, Speed, STR, DEX, WIL)
- Resistances per damage type
- Triggered abilities (on attack, on prayer, on step, etc.)
- Stack-based effects (Attune, Evasion, Berserk, etc.)
- Summon mechanics (familiars)

### Requires Custom Implementation
- Attune/Meditate effect systems
- Inflexibility/Encumbrance stat conversions
- Item transformation mechanics (Virya, Ihra)
- Prayer charge system
- Bag-based scaling (Skeleton)
- Sacrifice mechanics (Goblin)
- Teleport system with damage (Qamar)

### Culture Design Principles Observed

1. **Thematic Coherence**: Each culture has a clear theme (desert, ice, forest, undead)
2. **Stat-Ability Synergy**: High DEX cultures get DEX-scaling abilities
3. **Risk-Reward**: Vulnerabilities paired with powerful abilities
4. **Build Diversity**: Some cultures force specific playstyles (naked, heavy armor)
5. **Trigger Variety**: Different cultures use different trigger conditions

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
