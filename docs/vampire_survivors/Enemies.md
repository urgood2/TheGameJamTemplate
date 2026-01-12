# Vampire Survivors: Enemies Reference

## Overview

Vampire Survivors features **360+ unique enemies** across the base game and DLCs. Enemies spawn in waves, scale with time and player level, and culminate in boss encounters.

---

## Enemy Mechanics

### Spawn System
- **Wave Frequency**: One wave per minute
- **Spawn Cap**: 300 enemies max alive at once
- **Spawn Location**: Just outside screen boundaries
- **Despawn**: Enemies despawn if player moves too far (bosses teleport back)

### Scaling Mechanics

#### Curse System
Curse increases enemy stats and spawn frequency:

| Curse Level | Effect |
|-------------|--------|
| 100% (base) | Normal stats |
| 150% | +50% HP, +50% Speed, +50% spawn rate |
| 200% | +100% HP, +100% Speed, +100% spawn rate |

**Formula**: `effectiveSpawnInterval = spawnInterval / totalCurse`

**Sources**: PowerUp (+10%/rank), Skull O'Maniac, Gold Ring, Metaglio Right, Torrona's Box

#### HP x Level Skill
Many enemies have HP that scales with player level:
- HP multiplied by player's level at spawn time
- Does NOT update if player levels up while enemy is alive
- Common on bosses and elite enemies

---

## Common Enemy Types

### Basic Enemies

| Enemy | HP | Power | Speed | Behavior |
|-------|----|----|-------|----------|
| **Bat (Pipeestrello)** | Low | 4 | 160 | Fast chase, flying |
| **Skeleton** | Low | Variable | Variable | Standard chase |
| **Zombie** | Low | Variable | Slow | Slow chase |
| **Ghost** | Low | Variable | Medium | Phases through obstacles |
| **Mudman** | Low | Variable | Slow | Ground-based |
| **Werewolf** | Medium | Variable | Fast | Aggressive melee |
| **Merman** | Low-Med | Variable | Medium | Standard chase |

### Advanced Enemies

| Enemy | HP | Special | Notes |
|-------|----|----|-------|
| **Flower Wall** | HP x Level | Stationary | Cannot move |
| **Dust Elemental** | HP x Level | Colossal variant | Large hitbox |
| **Lionhead** | HP x Level | Standard | Common in Library |
| **Dragon Shrimp** | HP x Level | 2 variants | Dairy Plant |
| **Sig.ra Rossi** | HP x Level | Self-destruct | Explodes on death |
| **Poltergeist** | HP x Level | Self-destruct | Explodes on death |

### Ranged Enemies

| Enemy | Attack | Range | Fire Rate |
|-------|--------|-------|-----------|
| **Undead Mage** | Bullets | Medium | 2s intervals |
| **Twin Snakes** | Bullets | Medium | 2s intervals |
| **Twin Demons** | Bullets | Medium | 1.5s intervals |
| **Lost Twin** | Bullets | Medium | 1s intervals |

---

## Elite Enemies

Elites are regular enemies with 1-3 random modifiers:

### Stat Modifiers

| Modifier | Effect |
|----------|--------|
| **Tanky** | 2x HP, 1.3x size |
| **Fast** | 1.5x speed |
| **Deadly** | 1.75x damage |
| **Armored** | 50% damage reduction |

### Behavior Modifiers

| Modifier | Effect |
|----------|--------|
| **Vampiric** | Heals 50% of damage dealt |
| **Explosive Death** | Explodes on death (50 radius, 15 damage) |
| **Summoner** | Spawns minions every 6 seconds |
| **Enraged** | 1.5x speed/damage at <30% HP |
| **Shielded** | Immune for first 3 seconds |
| **Regenerating** | Heals 2% max HP per second |
| **Teleporter** | Teleports near player every 5 seconds |

### Visual Indicators
- Larger size (if Tanky)
- Glowing shader effect
- Distinct color palette

---

## Boss Enemies

### The Reaper (Time Limit Boss)

| Stat | Value |
|------|-------|
| **HP** | 655,350 × Player Level |
| **Power** | 65,535 (instant kill) |
| **Speed** | 1,200 |
| **Spawn** | Stage time limit (30/20/15 min) |
| **Resistances** | Freeze, Instant Kill, Debuff |

**Behavior**: Relentlessly chases player, cannot be outrun

**Variants**:
- Standard Reaper (most stages)
- Cappella Magna variant
- Weak Reaper (Eudaimonia Machine): 10 HP, 5 Power, 140 Speed

**Strategy to Defeat**:
- Max PowerUps (except Greed/Curse)
- Prioritize Revival (Tirajisú, Krochi, Awake Arcana)
- High sustained DPS builds
- Infinite Corridor (halves HP repeatedly)

---

### The Ender (Final Boss)

| Stat | Value |
|------|-------|
| **HP** | 1,270★ – 2,550★ (scales with level) |
| **Location** | Cappella Magna (30:00), Boss Rash |
| **Resistances** | Freeze, Debuff, Instant Kill, Knockback (all immune) |

**Attacks**:
- Fires Scythe Bullets every 5 seconds (rate increases as HP decreases)
- Creates damaging beams/zones
- Patterns based on Reaper Trainees, coffins, fire explosions

**Shield**: Temporary damage absorption (90s in Cappella Magna, 45s in Boss Rash)

**Composition**: Amalgamation of The Reaper, The Trickster, The Stalker, The Drowner, The Maddener

---

### Stage-Specific Bosses

#### Mad Forest Bosses

| Boss | HP | Spawn | Special |
|------|----|-------|---------|
| **Giant Blue Venus** | HP x Level | 25:00 | Hyper unlock |
| **Giant Bat** | HP x Level | Wave-based | Flying |
| **Giant Werewolf** | HP x Level | Wave-based | Fast |
| **Giant Mummy** | HP x Level | Wave-based | Tanky |

#### Inlaid Library Bosses

| Boss | HP | Spawn | Resistances |
|------|----|-------|-------------|
| **Hag** | HP x Level | 25:00 | Freeze, Rosary, Debuff, Knockback |
| **Nesufritto** | HP x Level | Wave-based | Freeze |
| **Queen Medusa** | HP x Level | Wave-based | None |
| **Master Witch** | HP x Level | Wave-based | None |

#### Dairy Plant Bosses

| Boss | HP | Spawn | Special |
|------|----|-------|---------|
| **Sword Guardian** | HP x Level | 25:00 | Hyper unlock |
| **Minotaur Boss** | HP x Level | Wave-based | Charge attack |
| **King Triton** | HP x Level | Wave-based | Ranged |

#### Gallo Tower Bosses

| Boss | HP | Spawn | Special |
|------|----|-------|---------|
| **Giant Enemy Crab** | HP x Level | 25:00 | Hyper unlock |

#### Cappella Magna Bosses

| Boss | HP | Spawn | Special |
|------|----|-------|---------|
| **Trinacria** | HP x Level | 25:00 | Hyper unlock |
| **The Ender** | Scales | 30:00 | Final boss |

---

### DLC Bosses

#### Ode to Castlevania

| Boss | HP | Location | Special |
|------|----|----------|---------|
| **Death** | 3,000 | Tower throne room | Robs player of everything |
| **Dracula** | Variable | Dracula's Castle | Multiple forms |
| **Giant Bat** | Variable | Castle | Flying |
| **Puppet Master** | Variable | Castle | Summons puppets |
| **Paranoia** | Variable | Castle | Mirror attacks |
| **Abaddon** | Variable | Castle | Locust swarms |
| **Eligor** | Variable | Castle | Mounted |
| **Menace** | Variable | Castle | Large hitbox |

---

## Enemy Resistances

### Resistance Types

| Resistance | Effect |
|------------|--------|
| **Freeze** | Immune to Clock Lancet, freeze effects |
| **Instant Kill** | Immune to Pentagram, Gorgeous Moon, Rosary |
| **Debuff** | Immune to knockback/freeze reduction, slow |
| **Knockback** | Reduces or negates pushback |

### Common Resistance Patterns

| Enemy Type | Typical Resistances |
|------------|---------------------|
| **Regular** | None |
| **Elite** | May have Armored (50% DR) |
| **Mini-Boss** | Freeze, Knockback |
| **Boss** | Freeze, Instant Kill, Debuff, Knockback |
| **The Reaper** | All resistances |

---

## Spawn Patterns

### Wave Events
- Tied to specific wave timing
- Trigger at same second marks every time
- Multiple events can occur per wave

### Trap Events
- Circular pressure plates (Dairy Plant, Gallo Tower)
- Trigger unavoidable events when stepped on
- Global cooldown affected by Luck

### Special Events
- One-time events on global timer
- Unique trigger conditions
- Not part of regular waves

### Swarm Events

| Event | Enemies | Behavior |
|-------|---------|----------|
| **Bat Swarm** | 50+ Bats | Fast diagonal cross |
| **Ghost Swarm** | 30+ Ghosts | Phase through obstacles |
| **Skull Swarm** | 40+ Skulls | Bouncing pattern |
| **Medusa Wall** | 20+ Medusa Heads | Horizontal wave |

---

## Enemy Behavior Patterns

### Movement Types

| Pattern | Description | Examples |
|---------|-------------|----------|
| **Chase** | Homes toward player | 99% of enemies |
| **Fixed Direction** | Straight line | Some variants |
| **Floaty/Medusa** | Wavy movement | Medusa Heads |
| **Swarm** | Fast diagonal | Bats, Ghosts |
| **Stationary** | Cannot move | Flower Wall, Turrets |

### Special Behaviors

| Behavior | Description |
|----------|-------------|
| **Self-Destruct** | Explodes on death/contact |
| **Projectile Firing** | Shoots at intervals |
| **Summoning** | Spawns additional enemies |
| **Teleportation** | Blinks around arena |
| **Phasing** | Moves through obstacles |

---

## Enemy Unlock Requirements

Some characters require killing specific enemy counts:

| Enemy | Kill Count | Unlocks |
|-------|------------|---------|
| **Skeletons** | 3,000 | Mortaccio |
| **Lion Heads** | 6,000 | Yatta Cavallo |
| **Milk Elementals** | 3,000 | Bianca Ramba |
| **Dragon Shrimps** | 6,000 | O'Sole Meeo |
| **Stage Killers** | 6,000 | Ambrojoe |
| **The Reaper** | 1 | Red Death (1665 coins) |

---

## Bestiary System

### Unlocking
- Find **Ars Gouda** relic in Dairy Plant

### Information Displayed
- HP, Power, Speed
- Resistances
- Skills (HP x Level, etc.)
- Location
- Variants

### Yellow Names
Enemies with yellow names in bestiary are required for character unlocks.

---

## Implementation Patterns

### Enemy Definition (Lua Example)
```lua
enemies.zombie = {
    sprite = "zombie.png",
    hp = 30,
    speed = 40,
    damage = 5,
    size = { 32, 32 },
    
    behaviors = { "chase" },
    
    on_death = function(e, ctx, helpers)
        helpers.spawn_xp_gem(e, 1)
    end,
}

enemies.elite_zombie = {
    base = "zombie",
    modifiers = { "tanky", "vampiric" },
    hp_multiplier = 2.0,
    size_multiplier = 1.3,
}
```

### Behavior Types
- **chase**: Move toward player
- **wander**: Random movement
- **flee**: Move away from player
- **kite**: Maintain distance (ranged)
- **dash**: Periodic dash attack
- **summon**: Spawn minions
- **teleport**: Blink around arena
