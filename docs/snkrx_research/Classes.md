# SNKRX Classes - Complete Synergy Guide

> **Source**: [a327ex/SNKRX](https://github.com/a327ex/SNKRX/blob/master/player.lua)
> **Total Classes**: 16
> **Synergy Types**: Tier 1 (3/6), Tier 2 (2/4), Special

---

## Class System Overview

### How Synergies Work
1. Each unit belongs to 1-3 classes
2. Having multiple units of the same class activates synergy bonuses
3. Synergies have threshold levels (e.g., 3 units = Level 1, 6 units = Level 2)
4. Bonuses are **additive within class, multiplicative between classes**

### Class Stat Multipliers
Every class modifies base stats. Multi-class units multiply these together.

```lua
-- Example: Mage + Nuker unit
HP = Base_HP × 0.6 (Mage) × 0.9 (Nuker) = 0.54× Base_HP
```

---

## Tier 1 Classes (3/6 Thresholds)

### Ranger
**Color**: Green  
**Thresholds**: 3 / 6 units

| Level | Bonus |
|-------|-------|
| 1 (3 Rangers) | 8% chance to barrage (shoot 4 projectiles instead of 1) |
| 2 (6 Rangers) | 16% chance to barrage |

**Stat Multipliers**:
| HP | DMG | ASPD | AoE DMG | AoE Size | DEF | MVSPD |
|----|-----|------|---------|----------|-----|-------|
| 1.0 | 1.2 | **1.5** | 1.0 | 1.0 | 0.9 | 1.2 |

**Strategic Notes**:
- Barrage = 4× projectile output on proc
- High attack speed (1.5×) = more barrage procs
- Best for projectile-focused builds
- Synergizes with: Ballista item, Divine Machine Arrow

**Units**:
| Tier | Unit |
|------|------|
| 1 | Archer |
| 2 | Dual Gunner, Sentry |
| 3 | Barrager |
| 4 | Cannoneer, Corruptor |

---

### Warrior
**Color**: Yellow  
**Thresholds**: 3 / 6 units

| Level | Bonus |
|-------|-------|
| 1 (3 Warriors) | -25 enemy defense |
| 2 (6 Warriors) | -50 enemy defense |

**Stat Multipliers**:
| HP | DMG | ASPD | AoE DMG | AoE Size | DEF | MVSPD |
|----|-----|------|---------|----------|-----|-------|
| **1.4** | 1.1 | 0.9 | 1.0 | 1.0 | **1.25** | 0.9 |

**Strategic Notes**:
- Defense reduction applies to ALL damage sources
- -50 defense = ~33% damage increase vs 100 DEF enemies
- Tankiest class (1.4× HP, 1.25× DEF)
- **Universal synergy** - good in every build

**Units**:
| Tier | Unit |
|------|------|
| 1 | Swordsman |
| 2 | Outlaw, Squire, Barbarian |
| 3 | Juggernaut |
| 4 | Blade, Highlander |

---

### Mage
**Color**: Blue  
**Thresholds**: 3 / 6 units

| Level | Bonus |
|-------|-------|
| 1 (3 Mages) | -15 enemy defense |
| 2 (6 Mages) | -30 enemy defense |

**Stat Multipliers**:
| HP | DMG | ASPD | AoE DMG | AoE Size | DEF | MVSPD |
|----|-----|------|---------|----------|-----|-------|
| 0.6 | **1.4** | 1.0 | **1.25** | 1.2 | 0.75 | 1.0 |

**Strategic Notes**:
- Glass cannon class (0.6× HP, 0.75× DEF)
- Highest base damage multiplier (1.4×)
- Defense reduction stacks with Warrior
- Best for AoE builds

**Units**:
| Tier | Unit |
|------|------|
| 1 | Magician |
| 2 | Wizard, Chronomancer, Cryomancer |
| 3 | Elementor, Spellblade, Pyromancer |
| 4 | Psykino |

---

### Rogue
**Color**: Red  
**Thresholds**: 3 / 6 units

| Level | Bonus |
|-------|-------|
| 1 (3 Rogues) | 15% critical hit chance (4× damage) |
| 2 (6 Rogues) | 30% critical hit chance (4× damage) |

**Stat Multipliers**:
| HP | DMG | ASPD | AoE DMG | AoE Size | DEF | MVSPD |
|----|-----|------|---------|----------|-----|-------|
| 0.8 | 1.3 | 1.1 | 0.6 | 0.6 | 0.8 | **1.4** |

**Strategic Notes**:
- **Highest DPS potential** (30% × 4× = +90% average damage)
- Fastest movement speed (1.4×)
- Weak AoE (0.6× multiplier)
- Synergizes with: Assassination item, Critical Strike item

**Units**:
| Tier | Unit |
|------|------|
| 1 | Scout |
| 2 | Outlaw, Dual Gunner, Beastmaster, Jester |
| 3 | Spellblade, Assassin |
| 4 | Thief |

---

### Nuker
**Color**: Red  
**Thresholds**: 3 / 6 units

| Level | Bonus |
|-------|-------|
| 1 (3 Nukers) | +15% AoE damage and size |
| 2 (6 Nukers) | +25% AoE damage and size |

**Stat Multipliers**:
| HP | DMG | ASPD | AoE DMG | AoE Size | DEF | MVSPD |
|----|-----|------|---------|----------|-----|-------|
| 0.9 | 1.0 | 0.75 | **1.5** | **1.5** | 1.0 | 1.0 |

**Strategic Notes**:
- Massive AoE multipliers (1.5× base + 25% synergy)
- Slow attack speed (0.75×)
- Best for wave clear
- Synergizes with: Amplify item, Magnify item

**Units**:
| Tier | Unit |
|------|------|
| 2 | Wizard, Bomber, Sage |
| 3 | Elementor, Pyromancer |
| 4 | Blade, Cannoneer, Plague Doctor, Vulcanist |

---

## Tier 2 Classes (2/4 Thresholds)

### Healer
**Color**: Green  
**Thresholds**: 2 / 4 units

| Level | Bonus |
|-------|-------|
| 1 (2 Healers) | 15% chance to spawn healing orb on pickup |
| 2 (4 Healers) | 30% chance to spawn healing orb on pickup |

**Stat Multipliers**:
| HP | DMG | ASPD | AoE DMG | AoE Size | DEF | MVSPD |
|----|-----|------|---------|----------|-----|-------|
| 1.2 | 1.0 | **0.5** | 1.0 | 1.0 | 1.2 | 1.0 |

**Strategic Notes**:
- Very slow attack speed (0.5×)
- Tanky for a support class
- Healing orb chain = sustained healing
- Synergizes with: Blessing item, Divine Blessing item

**Units**:
| Tier | Unit |
|------|------|
| 1 | Cleric |
| 2 | Carver |
| 3 | Psykeeper |
| 4 | Fairy, Priest |

---

### Conjurer (Builder)
**Color**: Orange  
**Thresholds**: 2 / 4 units

| Level | Bonus |
|-------|-------|
| 1 (2 Conjurers) | +25% buff to summoned units |
| 2 (4 Conjurers) | +50% buff to summoned units |

**Stat Multipliers**:
| HP | DMG | ASPD | AoE DMG | AoE Size | DEF | MVSPD |
|----|-----|------|---------|----------|-----|-------|
| 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |

**Strategic Notes**:
- Balanced stats (all 1.0×)
- Buffs turrets, critters, automatons
- Essential for summon builds
- Synergizes with: Swarmer class

**Units**:
| Tier | Unit |
|------|------|
| 2 | Bomber, Sentry, Carver |
| 3 | Engineer, Artificer |

---

### Enchanter
**Color**: Blue  
**Thresholds**: 2 / 4 units

| Level | Bonus |
|-------|-------|
| 1 (2 Enchanters) | +15% damage to all allies |
| 2 (4 Enchanters) | +25% damage to all allies |

**Stat Multipliers**:
| HP | DMG | ASPD | AoE DMG | AoE Size | DEF | MVSPD |
|----|-----|------|---------|----------|-----|-------|
| 1.2 | 1.0 | 1.0 | 1.0 | 1.0 | 1.2 | 1.2 |

**Strategic Notes**:
- Global damage buff
- Tanky support (1.2× HP, 1.2× DEF)
- Stacks with everything
- **Best support class**

**Units**:
| Tier | Unit |
|------|------|
| 2 | Squire, Chronomancer |
| 3 | Stormweaver, Flagellant |
| 4 | Fairy |

---

### Psyker
**Color**: White/Foreground  
**Thresholds**: 2 / 4 units

| Level | Bonus |
|-------|-------|
| 1 (2 Psykers) | +2 total orbs, +1 orb per Psyker |
| 2 (4 Psykers) | +4 total orbs, +1 orb per Psyker |

**Stat Multipliers**:
| HP | DMG | ASPD | AoE DMG | AoE Size | DEF | MVSPD |
|----|-----|------|---------|----------|-----|-------|
| **1.5** | 1.0 | 1.0 | 1.0 | 1.0 | **0.5** | 1.0 |

**Strategic Notes**:
- High HP (1.5×) but very low DEF (0.5×)
- Orbs deal damage to nearby enemies
- 4 Psykers = 4 + 4 = 8 orbs
- Synergizes with: Psychosink, Orbitism items

**Units**:
| Tier | Unit |
|------|------|
| 1 | Vagrant |
| 2 | Psychic |
| 3 | Psykeeper, Flagellant |
| 4 | Psykino |

---

### Curser
**Color**: Purple  
**Thresholds**: 2 / 4 units

| Level | Bonus |
|-------|-------|
| 1 (2 Cursers) | +1 max cursed enemies |
| 2 (4 Cursers) | +3 max cursed enemies |

**Stat Multipliers**:
| HP | DMG | ASPD | AoE DMG | AoE Size | DEF | MVSPD |
|----|-----|------|---------|----------|-----|-------|
| 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 0.75 | 1.0 |

**Strategic Notes**:
- Low defense (0.75×)
- Curses apply various debuffs
- More curse targets = more effects
- Synergizes with: Hextouch, Malediction items

**Units**:
| Tier | Unit |
|------|------|
| 2 | Barbarian, Jester, Silencer |
| 3 | Bane, Infestor, Usurer |

---

### Forcer
**Color**: Yellow  
**Thresholds**: 2 / 4 units

| Level | Bonus |
|-------|-------|
| 1 (2 Forcers) | +25% knockback force |
| 2 (4 Forcers) | +50% knockback force |

**Stat Multipliers**:
| HP | DMG | ASPD | AoE DMG | AoE Size | DEF | MVSPD |
|----|-----|------|---------|----------|-----|-------|
| 1.25 | 1.1 | 0.9 | 0.75 | 0.75 | 1.2 | 1.0 |

**Strategic Notes**:
- Tanky (1.25× HP, 1.2× DEF)
- Weak AoE (0.75×)
- Knockback enables wall-slam damage
- Synergizes with: Heavy Impact, Fracture items

**Units**:
| Tier | Unit |
|------|------|
| 2 | Sage |
| 3 | Juggernaut, Barrager |
| 4 | Psykino, Warden |

---

### Swarmer
**Color**: Orange  
**Thresholds**: 2 / 4 units

| Level | Bonus |
|-------|-------|
| 1 (2 Swarmers) | +1 HP to all critters |
| 2 (4 Swarmers) | +3 HP to all critters |

**Stat Multipliers**:
| HP | DMG | ASPD | AoE DMG | AoE Size | DEF | MVSPD |
|----|-----|------|---------|----------|-----|-------|
| 1.2 | 1.0 | 1.25 | 1.0 | 1.0 | 0.75 | 0.75 |

**Strategic Notes**:
- Fast attack speed (1.25×)
- Low defense and movement (0.75×)
- Critter HP = critter survivability
- Synergizes with: Conjurer class, Hive item

**Units**:
| Tier | Unit |
|------|------|
| 2 | Beastmaster |
| 3 | Host, Infestor |
| 4 | Corruptor |

---

### Voider
**Color**: Purple  
**Thresholds**: 2 / 4 units

| Level | Bonus |
|-------|-------|
| 1 (2 Voiders) | +20% damage over time (DoT) |
| 2 (4 Voiders) | +40% damage over time (DoT) |

**Stat Multipliers**:
| HP | DMG | ASPD | AoE DMG | AoE Size | DEF | MVSPD |
|----|-----|------|---------|----------|-----|-------|
| 0.75 | 1.3 | 1.0 | 0.8 | 0.75 | 0.6 | 0.8 |

**Strategic Notes**:
- Glass cannon (0.75× HP, 0.6× DEF)
- High damage multiplier (1.3×)
- DoT buff is massive (+40%)
- Synergizes with: Call of the Void, Chronomancer

**Units**:
| Tier | Unit |
|------|------|
| 2 | Cryomancer, Witch |
| 3 | Pyromancer, Assassin, Bane, Usurer |
| 4 | Plague Doctor |

---

### Mercenary
**Color**: Gold  
**Thresholds**: 2 / 4 units

| Level | Bonus |
|-------|-------|
| 1 (2 Mercenaries) | 8% chance to drop gold on enemy kill (4× multiplier) |
| 2 (4 Mercenaries) | 16% chance to drop gold on enemy kill (4× multiplier) |

**Stat Multipliers**:
| HP | DMG | ASPD | AoE DMG | AoE Size | DEF | MVSPD |
|----|-----|------|---------|----------|-----|-------|
| 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |

**Strategic Notes**:
- Balanced stats (all 1.0×)
- Gold generation = economy advantage
- 4× multiplier = 4 gold per drop
- Synergizes with: Dividends, Gambler

**Units**:
| Tier | Unit |
|------|------|
| 1 | Merchant |
| 2 | Miner |
| 3 | Usurer, Gambler |
| 4 | Thief |

---

## Special Classes

### Sorcerer
**Color**: Cyan  
**Thresholds**: 2 / 4 / 6 units (THREE LEVELS!)

| Level | Bonus |
|-------|-------|
| 1 (2 Sorcerers) | Attacks repeat after hitting 4 enemies |
| 2 (4 Sorcerers) | Attacks repeat after hitting 3 enemies |
| 3 (6 Sorcerers) | Attacks repeat after hitting 2 enemies |

**Stat Multipliers**:
| HP | DMG | ASPD | AoE DMG | AoE Size | DEF | MVSPD |
|----|-----|------|---------|----------|-----|-------|
| 0.8 | 1.3 | 1.0 | 1.2 | 1.0 | 0.8 | 1.0 |

**Strategic Notes**:
- **Only class with 3 synergy levels**
- Attack repeat = effective 2× damage
- Level 3 (2 enemies) = almost always repeats
- Extremely powerful for AoE builds

**Units**:
| Tier | Unit |
|------|------|
| 1 | Arcanist |
| 2 | Psychic, Witch, Silencer |
| 3 | Artificer, Gambler |
| 4 | Vulcanist, Warden |

---

### Explorer
**Color**: White  
**Thresholds**: 1 unit (PASSIVE)

| Level | Bonus |
|-------|-------|
| 1 (1 Explorer) | +15% attack speed and damage per active class set |

**Stat Multipliers**:
| HP | DMG | ASPD | AoE DMG | AoE Size | DEF | MVSPD |
|----|-----|------|---------|----------|-----|-------|
| 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | **1.25** |

**Strategic Notes**:
- **Only Vagrant has Explorer class**
- Scales with build diversity
- 10 active class sets = +150% ASPD/DMG
- Rewards diverse builds over stacking one class

**Units**:
| Tier | Unit |
|------|------|
| 1 | Vagrant (ONLY) |

---

## Synergy Combinations

### Offensive Combos

#### Rogue + Ranger (Crit Barrage)
- 30% crit (4× damage) + 16% barrage (4 projectiles)
- Result: Massive burst potential
- Key Units: Scout, Dual Gunner, Thief, Archer

#### Mage + Nuker (AoE Nuke)
- -30 enemy DEF + +25% AoE damage/size
- Result: Devastating wave clear
- Key Units: Wizard, Elementor, Pyromancer, Cannoneer

#### Voider + Curser (DoT Hell)
- +40% DoT + curse effects
- Result: Sustained damage over time
- Key Units: Cryomancer, Witch, Bane, Assassin

#### Sorcerer + Nuker (Repeat Nuke)
- Attack repeat + AoE amplification
- Result: Double AoE damage
- Key Units: Vulcanist, Wizard, Pyromancer

---

### Defensive Combos

#### Warrior + Healer (Tank Sustain)
- +50 DEF reduction + healing orbs
- Result: Tanky with sustain
- Key Units: Juggernaut, Squire, Psykeeper, Priest

#### Enchanter + Psyker (Orb Tank)
- +25% damage + orb damage
- Result: Damage + survivability
- Key Units: Flagellant, Psykeeper, Fairy

---

### Economy Combos

#### Mercenary + Explorer (Gold Scaling)
- 16% gold drop + +15% per class
- Result: Gold generation + scaling
- Key Units: Merchant, Miner, Thief, Vagrant

---

### Summon Combos

#### Conjurer + Swarmer (Critter Army)
- +50% summon buff + +3 critter HP
- Result: Durable critter swarm
- Key Units: Engineer, Host, Infestor, Corruptor

---

## Class Tier List

### S-Tier (Build-Defining)
| Class | Why |
|-------|-----|
| **Rogue** | 30% crit at 4× = +90% average DPS |
| **Warrior** | Universal defense reduction |
| **Enchanter** | +25% damage to ALL allies |
| **Sorcerer** | Attack repeat = 2× damage |

### A-Tier (Very Strong)
| Class | Why |
|-------|-----|
| **Nuker** | +25% AoE damage and size |
| **Voider** | +40% DoT damage |
| **Psyker** | 8 orbs at Level 2 |
| **Explorer** | Exponential scaling |

### B-Tier (Good)
| Class | Why |
|-------|-----|
| **Ranger** | 16% barrage chance |
| **Mage** | Defense reduction |
| **Healer** | Sustain |
| **Forcer** | Wall-slam potential |

### C-Tier (Situational)
| Class | Why |
|-------|-----|
| **Conjurer** | Requires summon units |
| **Swarmer** | Requires critter generation |
| **Curser** | Niche effects |
| **Mercenary** | Economy-focused |

---

## Build Archetypes

### 1. Rogue Crit Build
**Core Classes**: Rogue (6), Warrior (3)
**Key Units**: Scout, Thief, Dual Gunner, Assassin, Outlaw, Swordsman
**Items**: Assassination, Critical Strike, Flying Daggers

### 2. Nuker AoE Build
**Core Classes**: Nuker (6), Mage (3), Enchanter (2)
**Key Units**: Wizard, Elementor, Pyromancer, Cannoneer, Chronomancer
**Items**: Amplify, Magnify, Echo Barrage

### 3. Sorcerer Chain Build
**Core Classes**: Sorcerer (6), Nuker (3)
**Key Units**: Arcanist, Vulcanist, Witch, Artificer, Wizard
**Items**: Chronomancy, Burning Field

### 4. Psyker Orb Build
**Core Classes**: Psyker (4), Enchanter (2)
**Key Units**: Vagrant, Psykeeper, Psykino, Flagellant, Fairy
**Items**: Psychosink, Orbitism, Psyker Orbs

### 5. Voider DoT Build
**Core Classes**: Voider (4), Curser (2), Mage (3)
**Key Units**: Cryomancer, Pyromancer, Witch, Bane, Chronomancer
**Items**: Call of the Void, Deceleration, Seeping

### 6. Explorer Diversity Build
**Core Classes**: Explorer (1), + as many 2-unit synergies as possible
**Key Units**: Vagrant + diverse picks
**Items**: Universal damage items

---

## References

- [SNKRX Source Code - player.lua](https://github.com/a327ex/SNKRX/blob/master/player.lua)
- [SNKRX Source Code - main.lua](https://github.com/a327ex/SNKRX/blob/master/main.lua)
