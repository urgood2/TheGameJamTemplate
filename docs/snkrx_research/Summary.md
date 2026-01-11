# SNKRX - Game Design Analysis

> **Source**: [a327ex/SNKRX](https://github.com/a327ex/SNKRX) - Open source roguelike auto-battler by a327ex
> **Genre**: Auto-battler + Snake hybrid
> **Platform**: PC (Steam, itch.io)
> **Engine**: LÖVE2D (Lua)

---

## Executive Summary

SNKRX is a roguelike auto-battler where you control a snake made of heroes. Each hero attacks automatically while you focus on movement and positioning. The game combines **auto-chess unit synergies** with **snake game movement** and **roguelike progression**.

### Core Innovation
- **Snake as Party**: Your party IS the snake - each unit is a segment
- **Auto-Attack Combat**: Units attack automatically, player controls movement only
- **Synergy Stacking**: Class bonuses compound multiplicatively
- **Economy Depth**: Interest system rewards saving gold

---

## Core Gameplay Loop

```
┌─────────────────────────────────────────────────────────────┐
│                        RUN STRUCTURE                        │
├─────────────────────────────────────────────────────────────┤
│  Level 1 → Shop → Level 2 → Shop → ... → Level 25 → Boss   │
│                                                              │
│  Every 3rd level: ITEM SHOP (passive items)                 │
│  Every 6th level: BOSS FIGHT                                │
│  Level 25: FINAL BOSS (Randomizer)                          │
└─────────────────────────────────────────────────────────────┘
```

### Phase 1: Combat (Wave-Based)
1. Snake spawns in arena center
2. Enemies spawn from corners/edges
3. Units auto-attack based on their abilities
4. Player controls snake movement (avoid damage, position units)
5. Clear all waves to complete level

### Phase 2: Unit Shop (After Each Level)
1. Offered 4 random units from tier pool
2. Can reroll for 2 gold (unlimited)
3. Buy units to add to snake or upgrade existing
4. Sell units for 1 gold (regardless of tier)
5. Interest: +1 gold per 5 gold saved (max +5)

### Phase 3: Item Shop (Every 3rd Level)
1. Offered 4 random passive items
2. Can reroll for 5 gold
3. Maximum 8 items at once
4. Items can be leveled up (5 gold per XP)

---

## Stat System

### Base Stats (Level 1)
| Stat | Base Value | Per Level |
|------|------------|-----------|
| HP | 100 | ×2 per level |
| Damage | 10 | ×2 per level |
| Attack Speed | 1.0 | Class-based |
| Movement Speed | 1.0 | Class-based |
| Defense | 0 | Class-based |

### Stat Scaling Formula
```lua
-- HP and Damage double each level
stat = base_stat × 2^(level - 1)

-- Level 1: 100 HP, 10 DMG
-- Level 2: 200 HP, 20 DMG  
-- Level 3: 400 HP, 40 DMG
```

### Defense Formula
```lua
-- Defense reduces incoming damage
final_damage = base_damage × (100 / (100 + defense))

-- 50 DEF = 33% damage reduction
-- 100 DEF = 50% damage reduction
-- 200 DEF = 67% damage reduction
```

### Class Stat Multipliers

| Class | HP | DMG | ASPD | AoE DMG | AoE Size | DEF | MVSPD |
|-------|-----|-----|------|---------|----------|-----|-------|
| **Ranger** | 1.0 | 1.2 | **1.5** | 1.0 | 1.0 | 0.9 | 1.2 |
| **Warrior** | **1.4** | 1.1 | 0.9 | 1.0 | 1.0 | **1.25** | 0.9 |
| **Mage** | 0.6 | **1.4** | 1.0 | **1.25** | 1.2 | 0.75 | 1.0 |
| **Rogue** | 0.8 | 1.3 | 1.1 | 0.6 | 0.6 | 0.8 | **1.4** |
| **Healer** | 1.2 | 1.0 | **0.5** | 1.0 | 1.0 | 1.2 | 1.0 |
| **Enchanter** | 1.2 | 1.0 | 1.0 | 1.0 | 1.0 | 1.2 | 1.2 |
| **Nuker** | 0.9 | 1.0 | 0.75 | **1.5** | **1.5** | 1.0 | 1.0 |
| **Conjurer** | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |
| **Psyker** | **1.5** | 1.0 | 1.0 | 1.0 | 1.0 | **0.5** | 1.0 |
| **Curser** | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 0.75 | 1.0 |
| **Forcer** | 1.25 | 1.1 | 0.9 | 0.75 | 0.75 | 1.2 | 1.0 |
| **Swarmer** | 1.2 | 1.0 | 1.25 | 1.0 | 1.0 | 0.75 | 0.75 |
| **Voider** | 0.75 | 1.3 | 1.0 | 0.8 | 0.75 | 0.6 | 0.8 |
| **Sorcerer** | 0.8 | 1.3 | 1.0 | 1.2 | 1.0 | 0.8 | 1.0 |
| **Mercenary** | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |
| **Explorer** | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | **1.25** |

**Multi-Class Units**: Stats multiply. Mage+Nuker = 0.6×0.9 = 0.54× HP

---

## Economy System

### Gold Sources
| Source | Amount | Notes |
|--------|--------|-------|
| Wave Clear | 3-5 gold | Scales with level |
| Enemy Kill | 0-1 gold | 8-16% chance (Mercenary class) |
| Interest | +1 per 5 gold | Max +5 (or +10 with Merchant Lv3) |
| Sell Unit | 1 gold | Flat rate regardless of tier |

### Interest System
```lua
-- Standard interest
interest = math.floor(gold / 5)  -- Max 5

-- With Merchant Level 3
interest = math.floor(gold / 10)  -- Max 10
```

**Strategic Implication**: Saving 25+ gold = +5 gold per round = snowball economy

### Shop Costs
| Action | Cost |
|--------|------|
| Buy Tier 1 Unit | 1 gold |
| Buy Tier 2 Unit | 2 gold |
| Buy Tier 3 Unit | 3 gold |
| Buy Tier 4 Unit | 4 gold |
| Reroll Units | 2 gold |
| Reroll Items | 5 gold |
| Level Up Item | 5 gold per XP |

### Shop Tier Odds

| Level | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|-------|--------|--------|--------|--------|
| 1-3 | 70% | 25% | 5% | 0% |
| 4-6 | 55% | 30% | 13% | 2% |
| 7-9 | 45% | 33% | 17% | 5% |
| 10-12 | 35% | 35% | 22% | 8% |
| 13-15 | 25% | 35% | 28% | 12% |
| 16-18 | 20% | 30% | 33% | 17% |
| 19-21 | 15% | 25% | 35% | 25% |
| 22-25 | 10% | 20% | 35% | 35% |

---

## Unit Upgrade System

### Level Progression
```
Level 1 → Level 2: Combine 2× Level 1 copies
Level 2 → Level 3: Combine 2× Level 2 copies (4 total Level 1s)
```

### Level 3 Power Spike
Every unit gains a **unique Level 3 ability** that dramatically increases power:

| Unit | Level 3 Ability | Effect |
|------|-----------------|--------|
| Scout | Dagger Resonance | +25% damage per chain, +3 chains |
| Wizard | Magic Missile | Projectile chains 2 times |
| Assassin | Toxic Delivery | Poison crits deal 8× damage |
| Highlander | Moulinet | Attack repeats 3 times (15× total) |
| Thief | Ultrakill | Crit = 10× damage, 10 chains, +1 gold |

---

## Synergy System

### Tier 1 Classes (3/6 Thresholds)
| Class | Level 1 (3 units) | Level 2 (6 units) |
|-------|-------------------|-------------------|
| **Ranger** | 8% barrage chance | 16% barrage chance |
| **Warrior** | -25 enemy defense | -50 enemy defense |
| **Mage** | -15 enemy defense | -30 enemy defense |
| **Rogue** | 15% crit (4× dmg) | 30% crit (4× dmg) |
| **Nuker** | +15% AoE dmg/size | +25% AoE dmg/size |

### Tier 2 Classes (2/4 Thresholds)
| Class | Level 1 (2 units) | Level 2 (4 units) |
|-------|-------------------|-------------------|
| **Healer** | 15% healing orb on pickup | 30% healing orb on pickup |
| **Conjurer** | +25% summon buff | +50% summon buff |
| **Enchanter** | +15% damage to all | +25% damage to all |
| **Psyker** | +2 orbs, +1 per Psyker | +4 orbs, +1 per Psyker |
| **Curser** | +1 max curse targets | +3 max curse targets |
| **Forcer** | +25% knockback | +50% knockback |
| **Swarmer** | +1 HP to critters | +3 HP to critters |
| **Voider** | +20% DoT damage | +40% DoT damage |
| **Mercenary** | 8% gold drop (4× mult) | 16% gold drop (4× mult) |

### Special Classes
| Class | Thresholds | Effect |
|-------|------------|--------|
| **Sorcerer** | 2/4/6 | Attacks repeat every 4/3/2 hits |
| **Explorer** | 1 (passive) | +15% ASPD & DMG per active class |

---

## Positioning System

### Snake Position Effects
| Position | Strategic Value |
|----------|-----------------|
| **Position 1 (Head)** | Takes most damage, leads movement |
| **Position 2-3** | Protected, good for glass cannons |
| **Position 4-5** | Middle, balanced exposure |
| **Position 6-7** | Tail, last to enter danger |

### Position-Based Items
| Item | Effect |
|------|--------|
| Damage 4 | Position 4 has +30% damage |
| Speed 3 | Position 3 has +50% attack speed |
| Shoot 5 | Position 5 shoots 3 projectiles/sec |
| Death 6 | Position 6 takes 10% HP damage every 3s |
| Lasting 7 | Position 7 stays alive 10s after dying |
| Defensive Stance | First & Last positions +10/20/30% DEF |
| Offensive Stance | First & Last positions +10/20/30% DMG |

---

## Boss System

### Boss Schedule
| Level | Boss Type | Special Ability |
|-------|-----------|-----------------|
| 6 | Speed Booster | Buffs 4 nearby enemies with 3× speed |
| 12 | Exploder | Converts enemy into mine (8 projectiles) |
| 18 | Swarmer | Converts enemy into 4-6 critters |
| 24 | Forcer | Pull vortex → push enemies at player |
| 25 | Randomizer | Uses all 4 abilities randomly |

### Boss Mechanics
- 3-second countdown before spawn
- Continuous enemy waves during fight
- Must kill boss + clear all enemies to win
- Bosses have 80% push resistance

---

## New Game Plus (NG+)

### Difficulty Scaling
| NG+ | Enemy HP | Enemy DMG | Max Snake Size |
|-----|----------|-----------|----------------|
| 0 | Base | Base | 7 |
| 1 | +15% | +25% | 8 |
| 2 | +30% | +50% | 9 |
| 3 | +45% | +75% | 10 |
| 4 | +60% | +100% | 11 |
| 5 | +75% | +125% | 12 (cap) |

### NG+ Formula
```lua
-- Enemy HP scaling
base_hp = 22 + (NG * 3) + (15 + NG * 2.7) × level_factor

-- Enemy Damage scaling  
base_dmg = (4 + NG * 1.15) + (2 + NG * 0.83) × level_factor

-- Boss HP scaling
boss_hp = 100 + (NG * 5) + (90 + NG * 10) × level_factor
```

---

## Design Philosophy

### 1. **Simplicity in Control, Depth in Strategy**
- Player only controls movement
- All combat is automatic
- Depth comes from unit composition and synergies

### 2. **Multiplicative Scaling**
- Class multipliers stack multiplicatively
- Synergy bonuses compound
- Level 3 abilities often double or triple effectiveness

### 3. **Economy as Strategy**
- Interest rewards patience
- Rerolling costs opportunity
- Selling is always 1 gold (no tier penalty)

### 4. **Positional Importance**
- Snake head takes most damage
- Position-based items create build diversity
- Movement skill matters in combat

### 5. **Clear Power Spikes**
- Level 3 units are dramatically stronger
- Synergy thresholds (3/6, 2/4) are clear goals
- Boss levels every 6 stages create rhythm

---

## Implementation Roadmap

### Phase 1: Core Snake Mechanics
1. Snake movement (head follows mouse/input)
2. Body segments follow head
3. Collision with walls/enemies
4. Basic auto-attack system

### Phase 2: Unit System
1. Unit data structure (stats, abilities, classes)
2. Unit shop with tier odds
3. Unit upgrade system (combine duplicates)
4. Level 3 ability triggers

### Phase 3: Synergy System
1. Class detection (count units per class)
2. Synergy threshold checks
3. Synergy bonus application
4. Visual synergy indicators

### Phase 4: Economy
1. Gold tracking
2. Interest calculation
3. Shop reroll system
4. Sell functionality

### Phase 5: Combat
1. Wave spawning
2. Enemy AI (chase, attack)
3. Damage calculation
4. Death/respawn handling

### Phase 6: Progression
1. Level progression (25 levels)
2. Boss encounters
3. Item shop (every 3rd level)
4. NG+ scaling

---

## Key Metrics

| Metric | Value |
|--------|-------|
| Total Units | 52 |
| Total Classes | 16 |
| Total Items | 40+ |
| Levels per Run | 25 |
| Max Snake Size | 7-12 (NG+ dependent) |
| Max NG+ | 5 |
| Boss Fights | 5 per run |
| Item Shops | 8 per run |

---

## References

- [SNKRX Source Code](https://github.com/a327ex/SNKRX)
- [SNKRX Steam Page](https://store.steampowered.com/app/915310/SNKRX/)
- [a327ex Blog](https://a327ex.com/) - Developer insights
