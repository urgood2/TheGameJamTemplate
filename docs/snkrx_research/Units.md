# SNKRX Units - Complete Database

> **Source**: [a327ex/SNKRX](https://github.com/a327ex/SNKRX/blob/master/main.lua)
> **Total Units**: 52
> **Tiers**: 4 (cost 1-4 gold)

---

## Unit Mechanics

### Stat Calculation
```lua
-- Base stats scale with level
HP = 100 × 2^(level - 1)
Damage = 10 × 2^(level - 1)

-- Class multipliers apply
Final_HP = Base_HP × Class_HP_Multiplier
Final_DMG = Base_DMG × Class_DMG_Multiplier
```

### Leveling System
| Level | Copies Required | Total Copies | Stat Multiplier |
|-------|-----------------|--------------|-----------------|
| 1 | 1 | 1 | 1× |
| 2 | 2× Level 1 | 2 | 2× |
| 3 | 2× Level 2 | 4 | 4× + Special Ability |

---

## Tier 1 Units (Cost: 1 Gold)

### Vagrant
| Stat | Value |
|------|-------|
| **Classes** | Explorer, Psyker |
| **HP Mult** | 1.5× (Explorer) × 1.5× (Psyker) = 2.25× |
| **DEF Mult** | 1.0× × 0.5× = 0.5× |
| **MVSPD Mult** | 1.25× |

**Ability**: Shoots a projectile at any nearby enemy (medium range)

**Level 3 - "Experience"**: +15% attack speed and damage per active class set

**Strategic Notes**: 
- Only unit with Explorer class
- Scales exponentially with diverse builds
- With 10 active class sets = +150% ASPD/DMG
- Best as position 1 (tank) due to high HP

---

### Swordsman
| Stat | Value |
|------|-------|
| **Classes** | Warrior |
| **HP Mult** | 1.4× |
| **DMG Mult** | 1.1× |
| **DEF Mult** | 1.25× |
| **ASPD Mult** | 0.9× |

**Ability**: Deals damage in an area, deals extra 15% damage per unit hit

**Level 3 - "Cleave"**: Damage is doubled (4× total from base)

**Strategic Notes**:
- Excellent wave clear
- Scales with enemy density
- Core Warrior for 3/6 synergy

---

### Magician
| Stat | Value |
|------|-------|
| **Classes** | Mage |
| **HP Mult** | 0.6× |
| **DMG Mult** | 1.4× |
| **AoE DMG Mult** | 1.25× |
| **AoE Size Mult** | 1.2× |

**Ability**: Creates a small area that deals AoE damage

**Level 3 - "Quick Cast"**: +50% attack speed every 12 seconds for 6 seconds

**Strategic Notes**:
- Glass cannon (low HP)
- Good for Mage synergy filler
- Quick Cast provides burst windows

---

### Archer
| Stat | Value |
|------|-------|
| **Classes** | Ranger |
| **DMG Mult** | 1.2× |
| **ASPD Mult** | 1.5× |
| **MVSPD Mult** | 1.2× |
| **DEF Mult** | 0.9× |

**Ability**: Shoots an arrow that pierces enemies (long range)

**Level 3 - "Bounce Shot"**: Arrow ricochets off walls 3 times

**Strategic Notes**:
- High attack speed = consistent DPS
- Pierce makes it effective vs groups
- Wall bounces add coverage in enclosed arenas

---

### Scout
| Stat | Value |
|------|-------|
| **Classes** | Rogue |
| **DMG Mult** | 1.3× |
| **ASPD Mult** | 1.1× |
| **MVSPD Mult** | 1.4× |
| **HP Mult** | 0.8× |

**Ability**: Throws a knife that chains 3 times

**Level 3 - "Dagger Resonance"**: +25% damage per chain and +3 chains (6 total)

**Strategic Notes**:
- Core Rogue unit
- Chains = multiplicative damage scaling
- Level 3 is massive power spike (6 chains × 1.25^6 = 3.8× damage)
- Synergizes with Flying Daggers item

---

### Cleric
| Stat | Value |
|------|-------|
| **Classes** | Healer |
| **HP Mult** | 1.2× |
| **DEF Mult** | 1.2× |
| **ASPD Mult** | 0.5× |

**Ability**: Creates 1 healing orb every 8 seconds

**Level 3 - "Mass Heal"**: Creates 4 healing orbs every 8 seconds

**Strategic Notes**:
- Primary sustain unit
- Low attack speed = minimal DPS contribution
- Level 3 quadruples healing output
- Essential for Healer synergy

---

### Arcanist
| Stat | Value |
|------|-------|
| **Classes** | Sorcerer |
| **HP Mult** | 0.8× |
| **DMG Mult** | 1.3× |
| **AoE DMG Mult** | 1.2× |

**Ability**: Launches a slow moving orb that releases projectiles

**Level 3 - "Arcane Orb"**: +50% attack speed for the orb and 2 projectiles per cast

**Strategic Notes**:
- Sorcerer synergy enabler
- Orb provides area denial
- Level 3 doubles projectile output

---

### Merchant
| Stat | Value |
|------|-------|
| **Classes** | Mercenary |
| **All Stats** | 1.0× (balanced) |

**Ability**: Gain +1 interest for every 10 gold, up to max of +10

**Level 3 - "Item Shop"**: Your first item reroll is always free

**Strategic Notes**:
- **Economy powerhouse**
- Doubles interest cap (5 → 10)
- Free item reroll saves 5 gold per item shop
- Essential for gold-focused builds

---

## Tier 2 Units (Cost: 2 Gold)

### Wizard
| Stat | Value |
|------|-------|
| **Classes** | Mage, Nuker |
| **HP Mult** | 0.6× × 0.9× = 0.54× |
| **DMG Mult** | 1.4× |
| **AoE DMG Mult** | 1.25× × 1.5× = 1.875× |
| **AoE Size Mult** | 1.2× × 1.5× = 1.8× |

**Ability**: Shoots a projectile that deals AoE damage on contact

**Level 3 - "Magic Missile"**: Projectile chains 2 times

**Strategic Notes**:
- **Extremely fragile** (0.54× HP)
- Massive AoE damage potential
- Chaining at Level 3 = 3× coverage
- Core Nuker unit

---

### Outlaw
| Stat | Value |
|------|-------|
| **Classes** | Warrior, Rogue |
| **HP Mult** | 1.4× × 0.8× = 1.12× |
| **DMG Mult** | 1.1× × 1.3× = 1.43× |
| **MVSPD Mult** | 0.9× × 1.4× = 1.26× |

**Ability**: Throws a fan of 5 knives, each dealing damage

**Level 3 - "Flying Daggers"**: +50% attack speed and knives seek enemies

**Strategic Notes**:
- Dual-class flexibility
- 5 knives = high single-target burst
- Seeking knives at Level 3 = guaranteed hits
- Good for Warrior+Rogue hybrid builds

---

### Bomber
| Stat | Value |
|------|-------|
| **Classes** | Nuker, Conjurer |
| **HP Mult** | 0.9× |
| **AoE DMG Mult** | 1.5× |
| **AoE Size Mult** | 1.5× |

**Ability**: Plants a bomb that deals 2× damage AoE when it explodes

**Level 3 - "Demoman"**: +100% bomb area and damage (4× total)

**Strategic Notes**:
- Delayed damage (bomb timer)
- Massive AoE at Level 3
- Good for area denial
- Synergizes with Conjurer builds

---

### Sage
| Stat | Value |
|------|-------|
| **Classes** | Nuker, Forcer |
| **HP Mult** | 0.9× × 1.25× = 1.125× |
| **DEF Mult** | 1.0× × 1.2× = 1.2× |
| **AoE Mult** | 1.5× × 0.75× = 1.125× |

**Ability**: Shoots a slow projectile that draws enemies in

**Level 3 - "Dimension Compression"**: When projectile expires, deal 3× damage to all enemies under its influence

**Strategic Notes**:
- Crowd control + damage combo
- Groups enemies for AoE follow-up
- Level 3 burst is devastating
- Good with wall-slam Forcer builds

---

### Squire
| Stat | Value |
|------|-------|
| **Classes** | Warrior, Enchanter |
| **HP Mult** | 1.4× × 1.2× = 1.68× |
| **DEF Mult** | 1.25× × 1.2× = 1.5× |
| **ASPD Mult** | 0.9× |

**Ability**: +20% damage and defense to all allies (passive aura)

**Level 3 - "Shiny Gear"**: +30% damage, attack speed, movement speed and defense to all allies

**Strategic Notes**:
- **Best support unit in game**
- Passive aura = always active
- Level 3 buffs EVERYTHING
- Essential for any build

---

### Dual Gunner
| Stat | Value |
|------|-------|
| **Classes** | Ranger, Rogue |
| **HP Mult** | 1.0× × 0.8× = 0.8× |
| **DMG Mult** | 1.2× × 1.3× = 1.56× |
| **ASPD Mult** | 1.5× × 1.1× = 1.65× |

**Ability**: Shoots two parallel projectiles, each dealing damage

**Level 3 - "Gun Kata"**: Every 5th attack shoot in rapid succession for 2 seconds

**Strategic Notes**:
- Highest sustained DPS in Tier 2
- Dual projectiles = 2× hit rate
- Gun Kata = massive burst windows
- Core for Ranger+Rogue builds

---

### Sentry
| Stat | Value |
|------|-------|
| **Classes** | Ranger, Conjurer |
| **DMG Mult** | 1.2× |
| **ASPD Mult** | 1.5× |

**Ability**: Spawns a rotating turret that shoots 4 projectiles

**Level 3 - "Sentry Barrage"**: +50% turret attack speed and projectiles ricochet twice

**Strategic Notes**:
- Summon-based damage
- Turret persists = area control
- Ricocheting projectiles at Level 3
- Good for Conjurer synergy

---

### Chronomancer
| Stat | Value |
|------|-------|
| **Classes** | Mage, Enchanter |
| **HP Mult** | 0.6× × 1.2× = 0.72× |
| **DMG Mult** | 1.4× |
| **MVSPD Mult** | 1.0× × 1.2× = 1.2× |

**Ability**: +20% attack speed to all allies (passive aura)

**Level 3 - "Quicken"**: Enemies take damage over time 50% faster

**Strategic Notes**:
- Attack speed aura stacks with Squire
- Level 3 buffs ALL DoT (Voider synergy)
- Fragile but high utility
- Core for Enchanter builds

---

### Barbarian
| Stat | Value |
|------|-------|
| **Classes** | Curser, Warrior |
| **HP Mult** | 1.0× × 1.4× = 1.4× |
| **DMG Mult** | 1.0× × 1.1× = 1.1× |
| **DEF Mult** | 0.75× × 1.25× = 0.9375× |

**Ability**: Deals AoE damage and stuns enemies hit for 4 seconds

**Level 3 - "Seism"**: Stunned enemies also take 100% increased damage

**Strategic Notes**:
- Crowd control + damage amp
- 4-second stun is massive
- Level 3 doubles damage to stunned
- Good for burst combos

---

### Cryomancer
| Stat | Value |
|------|-------|
| **Classes** | Mage, Voider |
| **HP Mult** | 0.6× × 0.75× = 0.45× |
| **DMG Mult** | 1.4× × 1.3× = 1.82× |
| **AoE Size Mult** | 1.2× × 0.75× = 0.9× |

**Ability**: Nearby enemies take damage per second

**Level 3 - "Frostbite"**: Enemies are also slowed by 60% while in the area

**Strategic Notes**:
- **Extremely fragile** (0.45× HP)
- Constant DoT aura
- 60% slow at Level 3 = massive CC
- Core Voider unit

---

### Beastmaster
| Stat | Value |
|------|-------|
| **Classes** | Rogue, Swarmer |
| **HP Mult** | 0.8× × 1.2× = 0.96× |
| **DMG Mult** | 1.3× |
| **ASPD Mult** | 1.1× × 1.25× = 1.375× |

**Ability**: Throws a knife that deals damage, spawn 2 critters if it crits

**Level 3 - "Call of the Wild"**: Spawn 4 small critters if the beastmaster gets hit

**Strategic Notes**:
- Crit-based critter generation
- Level 3 = defensive critter spawning
- Synergizes with Rogue crit chance
- Core Swarmer unit

---

### Jester
| Stat | Value |
|------|-------|
| **Classes** | Curser, Rogue |
| **HP Mult** | 1.0× × 0.8× = 0.8× |
| **DMG Mult** | 1.0× × 1.3× = 1.3× |
| **ASPD Mult** | 1.0× × 1.1× = 1.1× |

**Ability**: Curses 6 nearby enemies for 6 seconds, they explode into 4 knives on death

**Level 3 - "Pandemonium"**: All knives seek enemies and pierce 2 times

**Strategic Notes**:
- Death-triggered damage
- 6 enemies × 4 knives = 24 projectiles
- Seeking + piercing at Level 3
- Good for wave clear

---

### Carver
| Stat | Value |
|------|-------|
| **Classes** | Conjurer, Healer |
| **HP Mult** | 1.0× × 1.2× = 1.2× |
| **DEF Mult** | 1.0× × 1.2× = 1.2× |
| **ASPD Mult** | 1.0× × 0.5× = 0.5× |

**Ability**: Carves a statue that creates 1 healing orb every 6 seconds

**Level 3 - "World Tree"**: Carves a tree that creates healing orbs twice as fast (every 3 seconds)

**Strategic Notes**:
- Summon-based healing
- Statue persists = sustained healing
- Level 3 doubles healing rate
- Good for Conjurer+Healer builds

---

### Psychic
| Stat | Value |
|------|-------|
| **Classes** | Sorcerer, Psyker |
| **HP Mult** | 0.8× × 1.5× = 1.2× |
| **DMG Mult** | 1.3× |
| **DEF Mult** | 0.8× × 0.5× = 0.4× |

**Ability**: Creates a small area that deals AoE damage

**Level 3 - "Mental Strike"**: Attack can happen from any distance and repeats once

**Strategic Notes**:
- Global range at Level 3
- Attack repeats = 2× damage
- Very low defense (0.4×)
- Good for Psyker orb builds

---

### Witch
| Stat | Value |
|------|-------|
| **Classes** | Sorcerer, Voider |
| **HP Mult** | 0.8× × 0.75× = 0.6× |
| **DMG Mult** | 1.3× × 1.3× = 1.69× |
| **DEF Mult** | 0.8× × 0.6× = 0.48× |

**Ability**: Creates an area that ricochets and deals damage per second

**Level 3 - "Death Pool"**: Area releases projectiles that deal damage and chain once

**Strategic Notes**:
- High damage multiplier
- Extremely fragile
- DoT + projectile hybrid
- Core Voider unit

---

### Silencer
| Stat | Value |
|------|-------|
| **Classes** | Sorcerer, Curser |
| **HP Mult** | 0.8× |
| **DMG Mult** | 1.3× |
| **DEF Mult** | 0.8× × 0.75× = 0.6× |

**Ability**: Curses 5 nearby enemies for 6 seconds, preventing special attacks

**Level 3 - "Arcane Curse"**: Curse also deals damage per second

**Strategic Notes**:
- Disables enemy abilities
- Level 3 adds DoT
- Good vs special enemies
- Curser synergy enabler

---

### Miner
| Stat | Value |
|------|-------|
| **Classes** | Mercenary |
| **All Stats** | 1.0× (balanced) |

**Ability**: Picking up gold releases 4 homing projectiles that each deal damage

**Level 3 - "Golden Bolts"**: Release 8 homing projectiles instead and they pierce twice

**Strategic Notes**:
- Gold pickup = damage
- Synergizes with Mercenary gold drops
- Level 3 doubles projectiles + pierce
- Good for economy builds

---

## Tier 3 Units (Cost: 3 Gold)

### Elementor
| Stat | Value |
|------|-------|
| **Classes** | Mage, Nuker |
| **HP Mult** | 0.6× × 0.9× = 0.54× |
| **DMG Mult** | 1.4× |
| **AoE DMG Mult** | 1.25× × 1.5× = 1.875× |
| **AoE Size Mult** | 1.2× × 1.5× = 1.8× |

**Ability**: Deals AoE damage in a large area centered on a random target

**Level 3 - "Windfield"**: Slows enemies by 60% for 6 seconds on hit

**Strategic Notes**:
- Random targeting = unpredictable
- Massive AoE coverage
- Level 3 adds crowd control
- Upgrade from Wizard

---

### Stormweaver
| Stat | Value |
|------|-------|
| **Classes** | Enchanter |
| **HP Mult** | 1.2× |
| **DEF Mult** | 1.2× |
| **MVSPD Mult** | 1.2× |

**Ability**: Infuses projectiles with chain lightning that deals 20% damage to 2 enemies

**Level 3 - "Wide Lightning"**: Chain lightning's trigger AoE and number of units hit is doubled

**Strategic Notes**:
- Buffs ALL projectile units
- Chain lightning = bonus damage
- Level 3 doubles chain targets
- Core Enchanter unit

---

### Spellblade
| Stat | Value |
|------|-------|
| **Classes** | Mage, Rogue |
| **HP Mult** | 0.6× × 0.8× = 0.48× |
| **DMG Mult** | 1.4× × 1.3× = 1.82× |
| **ASPD Mult** | 1.0× × 1.1× = 1.1× |

**Ability**: Throws knives that pierce and spiral outwards

**Level 3 - "Spiralism"**: Faster projectile speed and tighter turns

**Strategic Notes**:
- **Extremely fragile** (0.48× HP)
- Highest damage multiplier in Tier 3
- Spiral pattern = area coverage
- Good for Mage+Rogue builds

---

### Psykeeper
| Stat | Value |
|------|-------|
| **Classes** | Healer, Psyker |
| **HP Mult** | 1.2× × 1.5× = 1.8× |
| **DEF Mult** | 1.2× × 0.5× = 0.6× |
| **ASPD Mult** | 0.5× |

**Ability**: Creates 3 healing orbs every time the psykeeper takes 25% of its max HP in damage

**Level 3 - "Crucio"**: Deal double the damage taken by the psykeeper to all enemies

**Strategic Notes**:
- **Tank + healer hybrid**
- Damage taken = healing output
- Level 3 = damage reflection
- Best in position 1 (head)
- Core Psyker unit

---

### Engineer
| Stat | Value |
|------|-------|
| **Classes** | Conjurer |
| **All Stats** | 1.0× (balanced) |

**Ability**: Drops turrets that shoot bursts of projectiles

**Level 3 - "Upgrade!!!"**: Drops 2 additional turrets and grants all turrets +50% damage and attack speed

**Strategic Notes**:
- Multiple turrets = area control
- Level 3 triples turret count
- +50% buff to ALL turrets
- Core Conjurer unit

---

### Juggernaut
| Stat | Value |
|------|-------|
| **Classes** | Forcer, Warrior |
| **HP Mult** | 1.25× × 1.4× = 1.75× |
| **DMG Mult** | 1.1× × 1.1× = 1.21× |
| **DEF Mult** | 1.2× × 1.25× = 1.5× |

**Ability**: Deals AoE damage and pushes enemies away with strong force

**Level 3 - "Brutal Impact"**: Enemies pushed by juggernaut take 4× damage if they hit a wall

**Strategic Notes**:
- **Tankiest unit in game** (1.75× HP, 1.5× DEF)
- Wall slam = massive damage
- Core Forcer unit
- Best in position 1

---

### Pyromancer
| Stat | Value |
|------|-------|
| **Classes** | Mage, Nuker, Voider |
| **HP Mult** | 0.6× × 0.9× × 0.75× = 0.405× |
| **DMG Mult** | 1.4× × 1.0× × 1.3× = 1.82× |
| **AoE DMG Mult** | 1.25× × 1.5× × 0.8× = 1.5× |
| **AoE Size Mult** | 1.2× × 1.5× × 0.75× = 1.35× |

**Ability**: Nearby enemies take damage per second

**Level 3 - "Ignite"**: Enemies killed by pyromancer explode, dealing AoE damage

**Strategic Notes**:
- **Triple class** (Mage+Nuker+Voider)
- Extremely fragile (0.405× HP)
- Death explosions chain
- Core for DoT builds

---

### Assassin
| Stat | Value |
|------|-------|
| **Classes** | Rogue, Voider |
| **HP Mult** | 0.8× × 0.75× = 0.6× |
| **DMG Mult** | 1.3× × 1.3× = 1.69× |
| **ASPD Mult** | 1.1× |

**Ability**: Throws a piercing knife that deals damage + damage per second

**Level 3 - "Toxic Delivery"**: Poison inflicted from crits deals 8× damage

**Strategic Notes**:
- Crit + DoT synergy
- 8× poison on crits = massive damage
- Requires Rogue synergy for crits
- Core Voider unit

---

### Host
| Stat | Value |
|------|-------|
| **Classes** | Swarmer |
| **HP Mult** | 1.2× |
| **ASPD Mult** | 1.25× |
| **DEF Mult** | 0.75× |

**Ability**: Periodically spawn 1 small critter

**Level 3 - "Invasion"**: +100% critter spawn rate and spawn 2 critters instead

**Strategic Notes**:
- Passive critter generation
- Level 3 = 4× critter output
- Core Swarmer unit
- Good with Conjurer buff

---

### Bane
| Stat | Value |
|------|-------|
| **Classes** | Curser, Voider |
| **HP Mult** | 1.0× × 0.75× = 0.75× |
| **DMG Mult** | 1.0× × 1.3× = 1.3× |
| **DEF Mult** | 0.75× × 0.6× = 0.45× |

**Ability**: Curses 6 nearby enemies for 6 seconds, they create small void rifts on death

**Level 3 - "Nightmare"**: 100% increased area for bane's void rifts

**Strategic Notes**:
- Death-triggered void zones
- Level 3 doubles rift size
- Very fragile (0.45× DEF)
- Good for Curser+Voider builds

---

### Barrager
| Stat | Value |
|------|-------|
| **Classes** | Ranger, Forcer |
| **HP Mult** | 1.0× × 1.25× = 1.25× |
| **DMG Mult** | 1.2× × 1.1× = 1.32× |
| **ASPD Mult** | 1.5× × 0.9× = 1.35× |

**Ability**: Shoots a barrage of 3 arrows, each dealing damage and pushing enemies

**Level 3 - "Barrage"**: Every 3rd attack shoots 15 projectiles and they push harder

**Strategic Notes**:
- Knockback + damage
- Level 3 = 15 projectiles burst
- Good for wall-slam builds
- Core Forcer unit

---

### Infestor
| Stat | Value |
|------|-------|
| **Classes** | Curser, Swarmer |
| **HP Mult** | 1.0× × 1.2× = 1.2× |
| **ASPD Mult** | 1.0× × 1.25× = 1.25× |
| **DEF Mult** | 0.75× × 0.75× = 0.5625× |

**Ability**: Curses 8 nearby enemies for 6 seconds, they release 2 critters on death

**Level 3 - "Infestation"**: Triples the number of critters released (6 total)

**Strategic Notes**:
- Death-triggered critter swarm
- 8 enemies × 6 critters = 48 critters
- Core Swarmer unit
- Synergizes with Curser builds

---

### Flagellant
| Stat | Value |
|------|-------|
| **Classes** | Psyker, Enchanter |
| **HP Mult** | 1.5× × 1.2× = 1.8× |
| **DEF Mult** | 0.5× × 1.2× = 0.6× |
| **MVSPD Mult** | 1.0× × 1.2× = 1.2× |

**Ability**: Deals 2× damage to self and grants +4% damage to all allies per cast

**Level 3 - "Zealotry"**: 2× flagellant max HP and grants +12% damage to all allies per cast instead

**Strategic Notes**:
- Self-damage = team buff
- Level 3 = 3× buff effect
- High HP (1.8×) sustains self-damage
- Core Enchanter unit

---

### Artificer
| Stat | Value |
|------|-------|
| **Classes** | Sorcerer, Conjurer |
| **HP Mult** | 0.8× |
| **DMG Mult** | 1.3× |
| **AoE DMG Mult** | 1.2× |

**Ability**: Spawns an automaton that shoots projectiles

**Level 3 - "Spell Formula Efficiency"**: Automatons shoot and move 50% faster and release 12 projectiles on death

**Strategic Notes**:
- Summon-based damage
- Death explosion at Level 3
- Good for Conjurer builds
- Sorcerer synergy enabler

---

### Usurer
| Stat | Value |
|------|-------|
| **Classes** | Curser, Mercenary, Voider |
| **HP Mult** | 1.0× × 1.0× × 0.75× = 0.75× |
| **DMG Mult** | 1.0× × 1.0× × 1.3× = 1.3× |
| **DEF Mult** | 0.75× × 1.0× × 0.6× = 0.45× |

**Ability**: Curses 3 nearby enemies indefinitely with debt, dealing damage per second

**Level 3 - "Bankruptcy"**: If same enemy is cursed 3 times it takes 10× damage

**Strategic Notes**:
- **Triple class** (Curser+Mercenary+Voider)
- Permanent curse = sustained DoT
- 10× damage on triple curse
- Very fragile

---

### Gambler
| Stat | Value |
|------|-------|
| **Classes** | Mercenary, Sorcerer |
| **HP Mult** | 1.0× × 0.8× = 0.8× |
| **DMG Mult** | 1.0× × 1.3× = 1.3× |
| **AoE DMG Mult** | 1.0× × 1.2× = 1.2× |

**Ability**: Deal 2X damage to a single random enemy where X is how much gold you have

**Level 3 - "Multicast"**: 60/40/20% chance to cast the attack 2/3/4 times

**Strategic Notes**:
- Gold scaling damage
- 50 gold = 100 bonus damage
- Multicast = up to 4× damage
- Core for economy builds

---

## Tier 4 Units (Cost: 4 Gold)

### Blade
| Stat | Value |
|------|-------|
| **Classes** | Warrior, Nuker |
| **HP Mult** | 1.4× × 0.9× = 1.26× |
| **DMG Mult** | 1.1× |
| **AoE DMG Mult** | 1.0× × 1.5× = 1.5× |
| **AoE Size Mult** | 1.0× × 1.5× = 1.5× |

**Ability**: Throws multiple blades that deal AoE damage

**Level 3 - "Blade Resonance"**: Deal additional damage per enemy hit

**Strategic Notes**:
- Tanky AoE dealer
- Scales with enemy density
- Good for Warrior+Nuker builds
- Solid all-around unit

---

### Cannoneer
| Stat | Value |
|------|-------|
| **Classes** | Ranger, Nuker |
| **HP Mult** | 1.0× × 0.9× = 0.9× |
| **DMG Mult** | 1.2× |
| **AoE DMG Mult** | 1.0× × 1.5× = 1.5× |
| **AoE Size Mult** | 1.0× × 1.5× = 1.5× |
| **ASPD Mult** | 1.5× |

**Ability**: Shoots a projectile that deals 2× AoE damage

**Level 3 - "Cannon Barrage"**: Showers hit area in 7 additional cannon shots that deal AoE damage

**Strategic Notes**:
- High attack speed + AoE
- Level 3 = 8 total explosions
- Core for Ranger+Nuker builds
- Massive wave clear

---

### Psykino
| Stat | Value |
|------|-------|
| **Classes** | Mage, Psyker, Forcer |
| **HP Mult** | 0.6× × 1.5× × 1.25× = 1.125× |
| **DMG Mult** | 1.4× × 1.0× × 1.1× = 1.54× |
| **AoE DMG Mult** | 1.25× × 1.0× × 0.75× = 0.9375× |
| **AoE Size Mult** | 1.2× × 1.0× × 0.75× = 0.9× |

**Ability**: Pulls enemies together for 2 seconds

**Level 3 - "Magnetic Force"**: Enemies take 4× damage and are pushed away when the area expires

**Strategic Notes**:
- **Triple class** (Mage+Psyker+Forcer)
- Crowd control + burst
- 4× damage on release
- Core for combo builds

---

### Highlander
| Stat | Value |
|------|-------|
| **Classes** | Warrior |
| **HP Mult** | 1.4× |
| **DMG Mult** | 1.1× |
| **DEF Mult** | 1.25× |

**Ability**: Deals 5× AoE damage

**Level 3 - "Moulinet"**: Quickly repeats the attack 3 times (15× total damage)

**Strategic Notes**:
- **Highest burst damage in game**
- 15× damage at Level 3
- Tanky (Warrior stats)
- Core for Warrior builds

---

### Fairy
| Stat | Value |
|------|-------|
| **Classes** | Enchanter, Healer |
| **HP Mult** | 1.2× × 1.2× = 1.44× |
| **DEF Mult** | 1.2× × 1.2× = 1.44× |
| **MVSPD Mult** | 1.2× |

**Ability**: Creates 1 healing orb and grants 1 unit +100% attack speed for 6 seconds

**Level 3 - "Whimsy"**: Creates 2 healing orbs and grants 2 units +100% attack speed

**Strategic Notes**:
- Healing + attack speed buff
- Level 3 doubles both effects
- Tanky for a support
- Core for Enchanter+Healer builds

---

### Priest
| Stat | Value |
|------|-------|
| **Classes** | Healer |
| **HP Mult** | 1.2× |
| **DEF Mult** | 1.2× |
| **ASPD Mult** | 0.5× |

**Ability**: Creates 3 healing orbs every 12 seconds

**Level 3 - "Divine Intervention"**: Picks 3 units at random and grants them a buff that prevents death once

**Strategic Notes**:
- Burst healing
- Level 3 = death prevention
- Core Healer unit
- Good for survival builds

---

### Plague Doctor
| Stat | Value |
|------|-------|
| **Classes** | Nuker, Voider |
| **HP Mult** | 0.9× × 0.75× = 0.675× |
| **DMG Mult** | 1.0× × 1.3× = 1.3× |
| **AoE DMG Mult** | 1.5× × 0.8× = 1.2× |
| **AoE Size Mult** | 1.5× × 0.75× = 1.125× |

**Ability**: Creates an area that deals damage per second

**Level 3 - "Black Death Steam"**: Nearby enemies take an additional damage per second (doubled DoT)

**Strategic Notes**:
- DoT zone
- Level 3 doubles DoT
- Good for Voider builds
- Fragile (0.675× HP)

---

### Vulcanist
| Stat | Value |
|------|-------|
| **Classes** | Sorcerer, Nuker |
| **HP Mult** | 0.8× × 0.9× = 0.72× |
| **DMG Mult** | 1.3× |
| **AoE DMG Mult** | 1.2× × 1.5× = 1.8× |
| **AoE Size Mult** | 1.0× × 1.5× = 1.5× |

**Ability**: Creates a volcano that explodes the nearby area 4 times, dealing AoE damage

**Level 3 - "Lava Burst"**: Number and speed of explosions is doubled (8 explosions)

**Strategic Notes**:
- Massive AoE burst
- 8 explosions at Level 3
- Core for Sorcerer+Nuker builds
- Good wave clear

---

### Warden
| Stat | Value |
|------|-------|
| **Classes** | Sorcerer, Forcer |
| **HP Mult** | 0.8× × 1.25× = 1.0× |
| **DMG Mult** | 1.3× × 1.1× = 1.43× |
| **DEF Mult** | 0.8× × 1.2× = 0.96× |

**Ability**: Creates a force field around a random unit that prevents enemies from entering

**Level 3 - "Magnetic Field"**: Creates the force field around 2 units

**Strategic Notes**:
- Defensive utility
- Protects fragile units
- Level 3 doubles protection
- Good for survival builds

---

### Corruptor
| Stat | Value |
|------|-------|
| **Classes** | Ranger, Swarmer |
| **HP Mult** | 1.0× × 1.2× = 1.2× |
| **DMG Mult** | 1.2× |
| **ASPD Mult** | 1.5× × 1.25× = 1.875× |

**Ability**: Shoots an arrow that deals damage, spawn 3 critters if it kills

**Level 3 - "Corruption"**: Spawn 2 small critters if the corruptor hits an enemy (doesn't need kill)

**Strategic Notes**:
- **Highest attack speed** (1.875×)
- Guaranteed critter spawn at Level 3
- Core Swarmer unit
- Good for Ranger+Swarmer builds

---

### Thief
| Stat | Value |
|------|-------|
| **Classes** | Rogue, Mercenary |
| **HP Mult** | 0.8× |
| **DMG Mult** | 1.3× |
| **ASPD Mult** | 1.1× |

**Ability**: Throws a knife that deals 2× damage and chains 5 times

**Level 3 - "Ultrakill"**: If knife crits it deals 10× damage, chains 10 times and grants 1 gold

**Strategic Notes**:
- **Best single-target DPS**
- 10× crit damage + 10 chains + gold
- Requires Rogue synergy for crits
- Core for Rogue+Mercenary builds

---

## Unit Tier List

### S-Tier (Build-Defining)
| Unit | Why |
|------|-----|
| **Squire** | +30% all stats to team at Level 3 |
| **Thief** | 10× crit damage + gold generation |
| **Highlander** | 15× burst damage |
| **Psykeeper** | Tank + healer + damage reflection |
| **Vagrant** | +15% per class = exponential scaling |

### A-Tier (Very Strong)
| Unit | Why |
|------|-----|
| **Scout** | 6 chains × 1.25^6 = massive damage |
| **Chronomancer** | +20% ASPD aura + DoT acceleration |
| **Cannoneer** | 8 explosions at Level 3 |
| **Fairy** | Healing + 100% ASPD buff |
| **Juggernaut** | Tankiest unit + wall slam |

### B-Tier (Good)
| Unit | Why |
|------|-----|
| **Wizard** | High AoE but fragile |
| **Dual Gunner** | Consistent DPS |
| **Assassin** | 8× poison crits |
| **Merchant** | Economy powerhouse |
| **Stormweaver** | Chain lightning buff |

### C-Tier (Situational)
| Unit | Why |
|------|-----|
| **Magician** | Filler for Mage synergy |
| **Archer** | Outclassed by Tier 2+ Rangers |
| **Cleric** | Basic healing |
| **Arcanist** | Slow orb |
| **Swordsman** | Basic Warrior |

---

## References

- [SNKRX Source Code - main.lua](https://github.com/a327ex/SNKRX/blob/master/main.lua)
- [SNKRX Source Code - player.lua](https://github.com/a327ex/SNKRX/blob/master/player.lua)
