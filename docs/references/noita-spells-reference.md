# Noita Spells Reference

A comprehensive reference of all Noita spells organized by category, with complete stats and mechanics for game design inspiration.

**Total Spells in Noita:** ~393 spells across 8 categories

**Note:** Damage values shown in-game for explosions are often displayed 4x higher than actual damage. This document lists actual damage values where known.

---

## Table of Contents

1. [Spell Attributes](#spell-attributes)
2. [Damage Types](#damage-types)
3. [Projectile Spells](#projectile-spells)
4. [Static Projectile Spells](#static-projectile-spells)
5. [Passive Spells](#passive-spells)
6. [Utility Spells](#utility-spells)
7. [Projectile Modifier Spells](#projectile-modifier-spells)
8. [Material Spells](#material-spells)
9. [Multicast Spells](#multicast-spells)
10. [Other Spells](#other-spells)
11. [Key Mechanics](#key-mechanics)

---

## Spell Attributes

| Attribute | Description |
|-----------|-------------|
| **Uses** | Number of times a spell can be cast before depletion. ∞ = unlimited. Restored at Holy Mountains. |
| **Mana Drain** | Mana required to cast. If insufficient, spell is skipped. |
| **Damage** | Damage dealt, listed by type (projectile, explosion, fire, ice, electric, slice, drill, melee, healing). |
| **Radius** | Radius of circular damage area in pixels. |
| **Spread (DEG)** | Deviation from aimed direction in degrees. Lower = more accurate. |
| **Speed** | Projectile travel rate in pixels/second. |
| **Lifetime** | Duration projectile remains active in frames (~60fps). |
| **Cast Delay** | Modifier to wand's base cast delay before next spell. |
| **Recharge Time** | Modifier to wand's recharge time after last spell cast. |
| **Spread Modifier** | Modifier to wand spread. Negative = more accurate. |
| **Speed Modifier** | Multiplier to projectile speed. |
| **Lifetime Modifier** | Modifier to projectile lifetime in frames. |
| **Bounces** | Number of times projectile bounces before expiring. |
| **Critical Chance** | Bonus chance to deal 5x damage on hit. |

---

## Damage Types

### Standard Damage Types

| Type | Description | Special Properties |
|------|-------------|-------------------|
| **Projectile (Impact)** | Most common damage type from ranged attacks | Robots and Lukki resistant |
| **Explosion** | Area damage from explosive spells | Displayed 4x higher than actual in-game |
| **Fire** | Burning damage, ignites targets | Causes panic state, sets environment ablaze |
| **Ice** | Freezing damage | Can freeze enemies and liquids |
| **Electric** | Electrical damage | Stuns targets, conducts through liquids/metal |
| **Slice** | Cutting damage | Increases bleeding, robots resistant |
| **Drill** | Digging damage | Effective against stationary targets |
| **Melee** | Contact damage | Instantly kills frozen enemies |
| **Healing** | Negative damage (restores HP) | Always has friendly fire enabled |
| **Poison** | DoT from Poison stains | ~2% max HP per 1.5s, can't kill below 5% HP |
| **Radioactive** | DoT from Toxic Sludge | ~2% max HP per 1.5s, can't kill below 5% HP |
| **Curse** | Universal effectiveness | Used by Holy Mountain collapse |

### Esoteric Damage Types

| Type | Description |
|------|-------------|
| **Bite** | Worm boss melee damage, ignores melee multiplier |
| **Impact (Physics)** | Collision with physics objects, scales with velocity |
| **Crush** | Collision with Collapsed Concrete |
| **Blackhole** | Gravity well damage from Giga/Omega Black Holes |
| **Fall** | Landing damage (rare, mostly disabled for creatures) |
| **Material** | Per-pixel damage from touching substances (acid, lava) |
| **Midas** | Touch of Gold conversion damage (100x current HP) |
| **Suffocation** | Drowning damage when air depletes |
| **Stomach** | Overeating damage (player only) |

---

## Projectile Spells

### Basic Projectiles

---

#### Spark Bolt

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 5 |
| Projectile Damage | 3 |
| Radius | 2 |
| Speed | 800 |
| Lifetime | 40 |
| Cast Delay | +0.05s |
| Spread Modifier | -1° |
| Critical Chance | +5% |

**Description:** "A weak but enchanting sparkling projectile"

**Special Properties:**
- The most basic projectile spell in the game
- One of the possible starting wand spells
- Very low mana drain makes it excellent for early game and fast-firing wands
- Can be made infinite with just one Reduce Lifetime modifier
- Trigger/Timer variants are the cheapest and most efficient ways to deliver spells at range
- High speed (800) makes it reliable for hitting targets

**Variants:**
- **Spark Bolt w/ Trigger** (10 mana): Casts another spell on collision
- **Spark Bolt w/ Double Trigger** (15 mana): Casts two spells on collision, adds 2.5 explosion damage
- **Spark Bolt w/ Timer** (10 mana): Casts another spell after timer expires

---

#### Spitter Bolt

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 5 |
| Radius | 2 |
| Speed | 500 |
| Lifetime | 25 |
| Cast Delay | -0.02s |
| Critical Chance | 6% |

**Description:** "A weak but enchanting sparkling projectile"

**Special Properties:**
- Enemy-style projectile (mimics Hämähäkki spider attacks)
- **Negative cast delay** (-0.02s) makes it useful for machine gun builds
- Slower and shorter-lived than Spark Bolt
- Scales up in the Large and Giant variants with better stats

**Variants:**
- **Spitter Bolt w/ Timer** (10 mana)
- **Large Spitter Bolt** (25 mana): -0.03s delay, 8% crit, 700 speed, 30 lifetime
- **Large Spitter Bolt w/ Timer** (30 mana)
- **Giant Spitter Bolt** (40 mana): -0.07s delay, 9% crit, 900 speed, 35 lifetime
- **Giant Spitter Bolt w/ Timer** (45 mana)

---

#### Bouncing Burst

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 5 |
| Projectile Damage | 3 |
| Speed | 700 |
| Lifetime | 750 |
| Cast Delay | -0.03s |
| Spread Modifier | -1° |

**Description:** "A weak but enchanting bouncing projectile"

**Special Properties:**
- Extremely long lifetime (750 frames = ~12.5 seconds)
- Bounces off surfaces multiple times
- Negative cast delay aids rapid fire builds
- Can fill enclosed spaces with projectiles
- **Warning:** Can bounce back and hit you in tight corridors

---

#### Bubble Spark

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 5 |
| Radius | 4 |
| Speed | 250 |
| Lifetime | 100 |
| Cast Delay | -0.08s |
| Spread | 22.9° |

**Description:** "A bouncy, inaccurate spell"

**Special Properties:**
- Very slow-moving projectile (250 speed)
- High innate spread (22.9°) makes it inaccurate
- Excellent negative cast delay (-0.08s)
- Bounces off terrain
- Good for filling areas with projectiles
- Trigger variant available (16 mana)

---

#### Burst of Air

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 5 |
| Speed | 400 |
| Lifetime | 40 |
| Cast Delay | +0.05s |
| Spread Modifier | -2° |

**Description:** "A puff of air that pushes things around"

**Special Properties:**
- Deals no direct damage
- Pushes entities and materials away from impact point
- Can extinguish fires
- Useful for manipulating physics objects
- Spreads liquids and powders

---

#### Magic Arrow

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 20 |
| Projectile Damage | 10 |
| Radius | 2 |
| Spread | 0.6° |
| Speed | 625 |
| Lifetime | 40 |
| Cast Delay | +0.07s |
| Spread Modifier | +2° |
| Critical Chance | +5% |

**Description:** "A handy magical arrow"

**Special Properties:**
- Upgraded version of Spark Bolt with better damage
- Slightly affected by gravity (arcing trajectory)
- Better knockback than Spark Bolt
- Applies "Dazed" status effect on hit
- **Safe to use:** Will not harm the caster (unlike Summon Arrow)
- Useful throughout the entire game due to decent stats

**Variants:**
- **Magic Arrow w/ Trigger** (35 mana): Casts spell on collision
- **Magic Arrow w/ Timer** (35 mana): Casts spell after timer

---

#### Magic Bolt

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 30 |
| Radius | 6 |
| Speed | 675 |
| Lifetime | 30 |
| Cast Delay | +0.12s |
| Spread | 2.9° |
| Critical Chance | +5% |

**Description:** "A powerful magic projectile"

**Special Properties:**
- Higher mana cost but larger radius
- Faster than Magic Arrow (675 vs 625)
- Shorter lifetime (30 vs 40)
- Less accurate than Magic Arrow (2.9° spread)

**Variants:**
- **Magic Bolt w/ Trigger** (40 mana)
- **Magic Bolt w/ Timer** (40 mana)

---

#### Arrow

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 15 |
| Speed | 600 |
| Lifetime | 750 |
| Cast Delay | +0.17s |
| Spread Modifier | -20° |

**Description:** "A sharp arrow that flies far"

**Special Properties:**
- Extremely long lifetime (750 frames)
- Massive accuracy bonus (-20° spread modifier)
- Affected by gravity significantly
- Can pin enemies to walls
- Very long range due to high lifetime

---

#### Pollen

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 10 |
| Radius | 7 |
| Speed | 200 |
| Cast Delay | +0.03s |
| Critical Chance | 20% |

**Description:** "A puff of pollen"

**Special Properties:**
- Very high critical chance (20%)
- Slow-moving projectile (200 speed)
- Larger radius than most basic projectiles
- Affected heavily by gravity and wind

### Magic Missiles

---

#### Magic Missile

| Stat | Value |
|------|-------|
| Uses | 10 |
| Mana Drain | 70 |
| Projectile Damage | 75 |
| Explosion Damage | ~26 (shown 105) |
| Radius | 15 |
| Speed | 85 (accelerates) |
| Lifetime | 360 |
| Cast Delay | +1.00s |

**Description:** "A magical missile that homes in on enemies"

**Special Properties:**
- **Accelerates over time** due to negative air friction
- **Has friendly fire** - can damage you if it loops back
- Slow initial speed (85) but picks up considerably
- One of the best mid-game damage spells
- Limited uses (10) but restored at Holy Mountains
- Explosion damage shown in-game (105) is 4x actual (~26)
- Homing is weak - works better on stationary targets

**Variants:**
- **Large Magic Missile** (8 uses, 90 mana): 100 proj damage, ~29 expl, radius 32, +1.50s delay
- **Giant Magic Missile** (6 uses, 120 mana): 125 proj damage, ~32 expl, radius 42, +2.00s delay

### Firebolts

---

#### Firebolt

| Stat | Value |
|------|-------|
| Uses | 25 |
| Mana Drain | 50 |
| Fire Damage | Yes (ignites) |
| Radius | 7 |
| Speed | 265 |
| Lifetime | 500 |
| Cast Delay | +0.50s |
| Spread | 2.9° |

**Description:** "A bouncing bolt of fire"

**Special Properties:**
- **Bounces off surfaces** before detonating
- Sets targets and terrain on fire
- Causes enemies to panic when ignited
- Moderate cast delay (+0.50s)
- Good for hitting targets around corners
- Fire can spread to oil and other flammables
- **Warning:** Can bounce back at you

**Variants:**
- **Firebolt w/ Trigger** (50 mana): Casts spell on collision
- **Large Firebolt** (20 uses, 90 mana): Radius 25, +0.83s delay
- **Giant Firebolt** (20 uses, 90 mana): Radius 40, +1.33s delay
- **Odd Firebolt** (25 uses, 50 mana): Behaves unpredictably

### Explosive Projectiles

---

#### Fireball

| Stat | Value |
|------|-------|
| Uses | 15 |
| Mana Drain | 70 |
| Fire Damage | Yes |
| Explosion Damage | ~50 (shown 200) |
| Radius | 15 |
| Speed | 165 |
| Lifetime | 60 |
| Cast Delay | +0.83s |

**Description:** "An explosive ball of fire"

**Special Properties:**
- Classic fireball that explodes on impact
- Sets terrain and enemies on fire
- Explosion destroys soft terrain
- **Has friendly fire** - can damage you
- Moderate speed makes it easy to use

---

#### Iceball

| Stat | Value |
|------|-------|
| Uses | 15 |
| Mana Drain | 90 |
| Ice Damage | 6 |
| Explosion Damage | ~50 (shown 200) |
| Radius | 15 |
| Speed | 165 |
| Lifetime | 60 |
| Cast Delay | +1.33s |

**Description:** "An explosive ball of ice"

**Special Properties:**
- Freezes liquids in the explosion area
- Can freeze enemies with enough hits
- **Frozen enemies take massive melee damage** (kicks, Tentacle)
- Slightly higher mana cost than Fireball
- Longer cast delay (+1.33s vs +0.83s)

---

#### Bomb

| Stat | Value |
|------|-------|
| Uses | 3 |
| Mana Drain | 25 |
| Explosion Damage | ~125 (shown 500) |
| Radius | 60 |
| Speed | 60 |
| Lifetime | 180 |
| Cast Delay | +1.67s |

**Description:** "A bomb that explodes on impact"

**Special Properties:**
- Very large explosion radius (60)
- Low speed - arcs significantly due to gravity
- High damage for low mana cost
- Limited uses (3)
- **Excellent terrain destruction**
- Can destroy dense materials

---

#### Dynamite (TNT)

| Stat | Value |
|------|-------|
| Uses | 16 |
| Mana Drain | 50 |
| Explosion Damage | Yes |
| Radius | 28 |
| Speed | 800 |
| Lifetime | 50 |
| Cast Delay | +0.83s |

**Description:** "A stick of dynamite"

**Special Properties:**
- Very fast projectile (800 speed)
- Explodes on impact or after timer
- Good balance of damage and usability
- Destroys terrain effectively
- Less chaotic than Bomb due to straight trajectory

---

#### Glitter Bomb

| Stat | Value |
|------|-------|
| Uses | 16 |
| Mana Drain | 70 |
| Explosion Damage | Yes |
| Radius | 16 |
| Speed | 800 |
| Lifetime | 50 |
| Cast Delay | +0.83s |

**Description:** "A bomb that sparkles"

**Special Properties:**
- Creates a shower of sparks on explosion
- Sparks can ignite flammable materials
- Smaller radius than TNT but additional visual effects
- Same speed and trajectory as Dynamite

---

#### Bomb Cart

| Stat | Value |
|------|-------|
| Uses | 6 |
| Mana Drain | 75 |
| Explosion Damage | Yes |
| Radius | 40 |
| Speed | 30 |
| Lifetime | 420 |
| Cast Delay | +1.00s |

**Description:** "A mine cart loaded with explosives"

**Special Properties:**
- Very slow-moving (30 speed)
- Rolls along surfaces following terrain
- Extremely long lifetime (420 frames = 7 seconds)
- Can roll down slopes toward enemies
- **Humorous:** Actually spawns a physical cart

---

#### Propane Tank

| Stat | Value |
|------|-------|
| Uses | 10 |
| Mana Drain | 75 |
| Explosion Damage | Yes |
| Radius | 60 |
| Cast Delay | +1.67s |

**Description:** "A propane tank that explodes"

**Special Properties:**
- Very large explosion radius (60)
- Spawns an actual physics object
- Tank can roll and bounce
- **Extremely dangerous** in enclosed spaces
- Explosion creates fire

---

#### Holy Bomb

| Stat | Value |
|------|-------|
| Uses | 2 |
| Mana Drain | 300 |
| Explosion Damage | Yes |
| Radius | 180 |
| Speed | 170 |
| Cast Delay | +0.67s |
| Recharge Time | +1.33s |

**Description:** "A bomb blessed by the gods"

**Special Properties:**
- **Massive explosion radius (180 pixels)**
- One of the largest explosions in the game
- Very high mana cost (300)
- Only 2 uses
- Destroys almost all terrain
- **Warning:** Extremely dangerous to user

---

#### Giga Holy Bomb

| Stat | Value |
|------|-------|
| Uses | 2 |
| Mana Drain | 600 |
| Explosion Damage | Yes |
| Radius | 320 |
| Speed | 60 |
| Cast Delay | +2.00s |
| Recharge Time | +2.67s |

**Description:** "An even holier bomb"

**Special Properties:**
- **Enormous explosion radius (320 pixels)**
- Slow projectile speed (60)
- Extreme mana cost (600)
- Can clear entire biome sections
- **Near-certain death** if used at close range

---

#### Fireworks!

| Stat | Value |
|------|-------|
| Uses | 25 |
| Mana Drain | 70 |
| Fire Damage | Yes |
| Explosion Damage | Yes |
| Radius | 15 |
| Speed | 75 |
| Lifetime | 30 |
| Cast Delay | +1.00s |

**Description:** "Celebratory explosives!"

**Special Properties:**
- Launches upward then explodes into multiple sparks
- Sparks spread fire in area
- Festive visual effect
- Short lifetime (30 frames)
- Good for setting large areas on fire

---

#### Firebomb

| Stat | Value |
|------|-------|
| Uses | 10 |
| Mana Drain | 7 |
| Fire Damage | Yes |
| Speed | 130 |
| Lifetime | 70 |

**Description:** "A ball of fire that spreads flames"

**Special Properties:**
- Very low mana cost (7)
- Spreads fire on impact
- Does not explode - just ignites area
- Good for setting up oil/alcohol traps
- Efficient fire-starter

---

#### Meteor

| Stat | Value |
|------|-------|
| Uses | 10 |
| Mana Drain | 150 |
| Fire Damage | 56 |
| Explosion Damage | ~125 (shown 500) |
| Radius | 45 |
| Speed | 350 |
| Lifetime | 200 |

**Description:** "A flaming rock from the sky"

**Special Properties:**
- High speed projectile (350)
- Large explosion radius (45)
- Combines fire and explosion damage
- Leaves burning terrain
- **Screen shake on impact**
- One of the most satisfying explosives

### Nukes

---

#### Nuke

| Stat | Value |
|------|-------|
| Uses | 1 |
| Mana Drain | 200 |
| Projectile Damage | 75 |
| Explosion Damage | ~250 (shown 1000) |
| Radius | 250 |
| Speed | 300 |
| Lifetime | 360 |
| Cast Delay | +0.33s |
| Recharge Time | +10.00s |

**Description:** "A nuclear bomb"

**Special Properties:**
- **Destroys dense materials** that most spells can't touch
- Generates falling concrete debris
- **High recoil** - pushes caster back
- Massive explosion radius (250 pixels)
- Only 1 use per spell
- Extremely long recharge (+10 seconds)
- Creates radioactive fallout area
- **Will almost certainly kill you** if used nearby

---

#### Giga Nuke

| Stat | Value |
|------|-------|
| Uses | 1 |
| Mana Drain | 500 |
| Projectile Damage | 250 |
| Explosion Damage | ~500 (shown 2000) |
| Radius | 400 |
| Speed | 900 |
| Cast Delay | +0.83s |
| Recharge Time | +13.33s |

**Description:** "A gigantic nuclear bomb"

**Special Properties:**
- **Transmutes liquids to Toxic Sludge** in explosion area
- Enormous explosion radius (400 pixels)
- Very fast projectile (900 speed)
- Destroys virtually all terrain types
- **Extreme recoil** - can launch you across the map
- Generates massive concrete rain
- Will destroy Holy Mountains if used nearby
- **Near-instant death** at any reasonable range

### Energy Projectiles

---

#### Energy Orb

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 30 |
| Projectile Damage | 11.25 |
| Explosion Damage | ~4.5 (shown 18) |
| Radius | 15 |
| Speed | 210 |
| Lifetime | 50 |
| Cast Delay | +0.10s |
| Critical Chance | 4% |

**Description:** "A slow but powerful orb of energy"

**Special Properties:**
- **Completely harmless to player** - cannot self-damage
- Applies "Dazed" status effect on hit
- **Can dig through dense rock** that resists other spells
- Excellent safe spell for beginners
- Unlimited uses
- Moderate damage for safe gameplay

**Variants:**
- **Energy Orb w/ Trigger** (50 mana): 10% crit, +0.42s delay
- **Energy Orb w/ Timer** (50 mana): Same stats as base

---

#### Energy Sphere

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 20 |
| Radius | 2 |
| Speed | 450 |
| Lifetime | 750 |
| Cast Delay | +0.17s |

**Description:** "A sphere of crackling energy"

**Special Properties:**
- Extremely long lifetime (750 frames = ~12.5 seconds)
- Passes through terrain
- Fast projectile (450 speed)
- Low mana cost for its utility
- Good for triggering things at range

**Variants:**
- **Energy Sphere w/ Timer** (50 mana)

---

#### Expanding Sphere

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 70 |
| Damage | Scales with expansion |
| Speed | 50 |
| Cast Delay | +0.50s |

**Description:** "A sphere that grows over time"

**Special Properties:**
- **Damage increases as it expands**
- Very slow-moving (50 speed)
- Grows larger the longer it travels
- Maximum damage at full expansion
- Good for hitting large targets

---

#### Pinpoint of Light

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 65 |
| Radius | 20 |
| Speed | 850 |
| Lifetime | 90 |
| Cast Delay | +0.67s |
| Critical Chance | 6% |

**Description:** "A focused beam of light"

**Special Properties:**
- Very fast projectile (850 speed)
- Large radius (20) despite small appearance
- Good for sniping distant targets
- Moderate cast delay
- Pierces some materials

### Death Cross Spells

---

#### Death Cross

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 80 |
| Explosion Damage | ~75 (shown 300) |
| Radius | 25 |
| Speed | 68 |
| Cast Delay | +0.67s |

**Description:** "A cross-shaped explosion that homes in"

**Special Properties:**
- **Hidden homing** - targets passive creatures too
- Creates cross-shaped explosion pattern
- **Does not create fire** unlike most explosives
- Can be modified with freeze/electric for elemental crosses
- Slow-moving projectile (68 speed)
- Unlimited uses despite high damage

---

#### Giga Death Cross

| Stat | Value |
|------|-------|
| Uses | 8 |
| Mana Drain | 150 |
| Explosion Damage | ~100 (shown 400) |
| Radius | 35 |
| Speed | 50 |
| Cast Delay | +1.17s |

**Description:** "A massive cross of death"

**Special Properties:**
- Larger explosion pattern than standard Death Cross
- Even slower projectile (50 speed)
- Limited uses (8)
- Higher damage and radius
- Same homing behavior

---

#### Plasma Beam Cross

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 80 |
| Damage | Beam (continuous) |
| Radius | 40 |
| Cast Delay | +0.25s |

**Description:** "A cross made of plasma beams"

**Special Properties:**
- Creates four beams in cross pattern
- Continuous damage while beams are active
- Short cast delay (+0.25s)
- Large effective radius (40)
- Good for hitting multiple targets

### Black Holes

---

#### Black Hole

| Stat | Value |
|------|-------|
| Uses | 3 |
| Mana Drain | 180 |
| Speed | 40 |
| Lifetime | 120 |
| Cast Delay | +1.33s |

**Description:** "A vortex that consumes matter"

**Special Properties:**
- **Does NO damage** to enemies or player
- **Consumes solid terrain only** - creates tunnels
- Pulls loose materials and liquids toward center
- Excellent for digging/exploration
- Limited uses (3)
- Destroyed materials are gone permanently
- **Safe to touch** - won't hurt you directly

---

#### Black Hole w/ Death Trigger

| Stat | Value |
|------|-------|
| Uses | 3 |
| Mana Drain | 200 |
| Speed | 40 |
| Lifetime | 120 |
| Cast Delay | +1.50s |

**Description:** "A black hole that casts a spell when it expires"

**Special Properties:**
- Same terrain-eating behavior as standard Black Hole
- **Casts the next spell in wand** when black hole expires
- Great for delivering dangerous spells underground
- Combine with explosives for tunnel-bombing
- Slightly higher mana cost and cast delay

### Electric Projectiles

---

#### Lightning Bolt

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 70 |
| Electric Damage | 25 |
| Explosion Damage | ~125 (shown 500) |
| Radius | 35 |
| Speed | Very fast (instant) |
| Lifetime | ~2s |
| Cast Delay | +0.83s |

**Description:** "A bolt of lightning"

**Special Properties:**
- **Innate piercing** - passes through multiple enemies
- **Ignores terminal velocity** - travels instantly
- **Electrifies water** - deadly for submerged enemies
- **Electrifies wands** - can shock you while holding
- Stuns enemies on hit
- Creates bright flash effect
- Unlimited uses despite high damage

---

#### Ball Lightning

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 70 |
| Electric Damage | 0.5 (per tick) |
| Radius | 15 |
| Speed | 800 |
| Lifetime | 30 |
| Cast Delay | +0.83s |

**Description:** "A sphere of electrical energy"

**Special Properties:**
- Continuous damage (0.5 per tick) to nearby enemies
- Very fast projectile (800 speed)
- Stuns enemies in contact
- Electrifies liquids it passes through
- Short lifetime (30 frames = 0.5 seconds)
- Good for chain-stunning groups

---

#### Thunder Charge

| Stat | Value |
|------|-------|
| Uses | 3 |
| Mana Drain | 120 |
| Electric Damage | High |
| Radius | 50 |
| Speed | 110 |
| Lifetime | 100 |
| Cast Delay | +2.00s |

**Description:** "A charged ball of thunder"

**Special Properties:**
- Large damage radius (50)
- Moderate speed (110)
- Limited uses (3)
- Long cast delay (+2.00s)
- Massive electrical discharge on impact
- **Excellent for water-filled areas**
- Creates thunder sound effect

### Beam Weapons

---

#### Plasma Beam

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 60 |
| Damage | 3 per frame (beam) |
| Radius | 40 |
| Cast Delay | +0.10s |

**Description:** "A continuous beam of plasma"

**Special Properties:**
- **Continuous damage** as long as beam touches target
- Deals ~180 damage per second at 60fps
- Cuts through terrain
- Large effective radius (40)
- Short cast delay
- **Drains mana continuously** while active

---

#### Plasma Cutter

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 40 |
| Damage | Beam (continuous) |
| Radius | 40 |
| Cast Delay | +0.17s |

**Description:** "A cutting beam of plasma"

**Special Properties:**
- Similar to Plasma Beam but lower mana cost
- Excellent for cutting through terrain
- Industrial feel to the effect
- Good utility spell for exploration

---

#### Luminous Drill

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 10 |
| Projectile Damage | 10 |
| Speed | 1400 |
| Lifetime | ~2s |
| Cast Delay | -0.58s |
| Recharge Time | -0.17s |

**Description:** "A drilling beam of light"

**Special Properties:**
- **Ignores projectile shields** - bypasses enemy defenses
- **Can penetrate any solid** - nothing stops it
- Extremely fast (1400 speed)
- **Negative cast delay** (-0.58s) enables machine gun builds
- **Negative recharge** causes rapid mana depletion
- Unlimited uses
- Excellent digging tool

**Variants:**
- **Luminous Drill w/ Timer** (30 mana): Casts spell after delay

---

#### Concentrated Light

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 30 |
| Damage | Beam |
| Radius | 3 |
| Speed | 140 |
| Lifetime | 30 |
| Cast Delay | -0.37s |

**Description:** "A focused beam of light"

**Special Properties:**
- Slower beam than other laser spells
- Small radius (3) - precision targeting
- Negative cast delay (-0.37s)
- Short lifetime (30 frames)
- Good accuracy

---

#### Intense Concentrated Light

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 110 |
| Damage | Beam (high) |
| Speed | 1 |
| Lifetime | 32 |
| Cast Delay | +1.50s |

**Description:** "An extremely focused beam of light"

**Special Properties:**
- **Extremely slow projectile** (speed 1)
- Very high damage output
- High mana cost (110)
- Long cast delay (+1.50s)
- Short range due to low speed
- Essentially point-blank laser

### Acid/Slime Projectiles

---

#### Acid Ball

| Stat | Value |
|------|-------|
| Uses | 20 |
| Mana Drain | 20 |
| Projectile Damage | 6 |
| Radius | 9 |
| Speed | 99 |
| Lifetime | 330 |
| Cast Delay | +0.17s |

**Description:** "A corrosive ball of acid"

**Special Properties:**
- **Leaves acid trail** as it travels
- **Explodes into acid pool** on impact
- Acid dissolves most materials except glass
- Long lifetime (330 frames = ~5.5 seconds)
- Slow speed makes aiming challenging
- **Warning:** Acid can dissolve terrain under you
- Limited uses (20)

---

#### Slimeball

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 20 |
| Damage | Poison (DoT) |
| Radius | 9 |
| Speed | 102 |
| Lifetime | 330 |
| Cast Delay | +0.17s |

**Description:** "A bouncy ball of slime"

**Special Properties:**
- Applies poison effect to targets
- Bounces off surfaces
- Creates slime puddles on impact
- Slime slows movement
- Unlimited uses
- Similar trajectory to Acid Ball

---

#### Glue Ball

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 25 |
| Speed | 325 |
| Cast Delay | +0.50s |

**Description:** "A sticky ball of glue"

**Special Properties:**
- **Sticks enemies in place** temporarily
- Creates glue puddles that slow movement
- Faster than acid/slime variants (325 speed)
- No direct damage
- Utility spell for crowd control
- Can trap flying enemies

### Flame Weapons

---

#### Flamethrower

| Stat | Value |
|------|-------|
| Uses | 60 |
| Mana Drain | 20 |
| Fire Damage | 11.25 |
| Explosion Damage | ~12.5 (shown 50) |
| Radius | 8 |
| Speed | 165 |
| Lifetime | 80 |
| Cast Delay | None |

**Description:** "A stream of fire"

**Special Properties:**
- Continuous stream of fire particles
- **No cast delay** - rapid fire capability
- Sets everything on fire
- Short range (165 speed, 80 lifetime)
- High uses (60) for extended burning
- **Friendly fire** - can ignite yourself
- Creates fire that spreads to flammables

---

#### Path of Dark Flame

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 60 |
| Damage | Dark Fire |
| Speed | 250 |
| Lifetime | 100 |
| Cast Delay | +0.33s |

**Description:** "A path of dark, cursed flames"

**Special Properties:**
- **Dark fire** - special fire variant
- Dark fire is harder to extinguish
- Creates trail of flames as it travels
- Higher mana cost than regular Flamethrower
- Unlimited uses
- Moderate cast delay

### Mist Spells

---

#### Blood Mist

| Stat | Value |
|------|-------|
| Uses | 10 |
| Mana Drain | 40 |
| Material | Blood |
| Speed | 500 |
| Cast Delay | +0.17s |

**Description:** "A cloud of blood"

**Special Properties:**
- Creates cloud of blood particles
- Blood can trigger certain alchemical reactions
- Limited uses (10)
- Fast-moving cloud (500 speed)
- Blood stains entities and terrain

---

#### Mist of Spirits

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 40 |
| Material | Alcohol |
| Speed | 100 |
| Cast Delay | +0.17s |

**Description:** "A cloud of alcohol"

**Special Properties:**
- Creates alcohol mist cloud
- **Highly flammable** - ignites explosively
- Slower than other mists (100 speed)
- Causes "Drunk" status effect
- Unlimited uses
- **Combo:** Ignite with any fire spell for explosion

---

#### Slime Mist

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 40 |
| Material | Slime |
| Speed | 500 |
| Cast Delay | +0.17s |

**Description:** "A cloud of slime"

**Special Properties:**
- Creates slime particle cloud
- Slows enemies on contact
- Can create slime puddles
- Fast movement (500 speed)
- Unlimited uses

---

#### Toxic Mist

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 40 |
| Material | Toxic Sludge |
| Speed | 500 |
| Cast Delay | +0.17s |

**Description:** "A cloud of toxic sludge"

**Special Properties:**
- Creates toxic sludge cloud
- Applies toxic damage over time
- Stains entities with toxic material
- Fast movement (500 speed)
- **Warning:** Toxic sludge damages you too

### Sawblades

---

#### Disc Projectile

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 20 |
| Damage | Slice |
| Speed | 400 |
| Lifetime | 750 |
| Cast Delay | +0.17s |
| Critical Chance | 2% |

**Description:** "A spinning disc of death"

**Special Properties:**
- Deals slice damage (causes bleeding)
- **Very long lifetime** (750 frames = ~12.5 seconds)
- Bounces off surfaces
- Fast projectile (400 speed)
- Unlimited uses
- **Robots are resistant** to slice damage
- Can cut through soft materials

---

#### Giga Disc Projectile

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 38 |
| Damage | Slice (higher) |
| Speed | 250 |
| Lifetime | 300 |
| Cast Delay | +0.33s |
| Critical Chance | 3% |

**Description:** "A larger spinning disc"

**Special Properties:**
- Larger size than standard Disc
- Higher damage per hit
- Slower speed (250)
- Shorter lifetime (300 frames)
- Still bounces off surfaces
- More intimidating visual

---

#### Summon Omega Sawblade

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 70 |
| Damage | Slice (massive) |
| Speed | 150 |
| Lifetime | 500 |
| Cast Delay | +0.67s |
| Critical Chance | 6% |

**Description:** "The ultimate sawblade"

**Special Properties:**
- **Enormous sawblade** - fills corridors
- Highest slice damage of the series
- Slowest of the sawblades (150 speed)
- Long lifetime (500 frames)
- **Can kill most enemies in one pass**
- Bounces around enclosed spaces
- Higher crit chance (6%)

### Summon Spells

---

#### Summon Rock

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 3 |
| Damage | Physics-based |
| Radius | 100 |

**Description:** "Summons a rock"

**Special Properties:**
- Creates a physics rock object
- **Damage based on velocity** - throw it fast for more damage
- Very low mana cost (3)
- Can be kicked for extra damage
- Blocks projectiles temporarily
- Good for crushing enemies below

---

#### Summon Egg

| Stat | Value |
|------|-------|
| Uses | 2 |
| Mana Drain | 100 |
| Damage | Varies |
| Radius | 3 |

**Description:** "Summons a mysterious egg"

**Special Properties:**
- Hatches into a **random creature**
- Creature can be friendly or hostile
- Very limited uses (2)
- High mana cost (100)
- Eggs can be kicked before hatching
- **Gamble:** You don't know what you'll get

---

#### Summon Hollow Egg

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 30 |
| Damage | Varies |
| Radius | 3 |
| Cast Delay | -0.20s |

**Description:** "Summons an empty egg shell"

**Special Properties:**
- Empty shell - no creature inside
- Can be filled with materials
- **Negative cast delay** (-0.20s)
- Unlimited uses
- Physics object - can be thrown
- Creative utility spell

---

#### Summon Deercoy

| Stat | Value |
|------|-------|
| Uses | 10 |
| Mana Drain | 120 |
| Damage | Explodes on death |
| Speed | 265 |
| Cast Delay | +1.33s |

**Description:** "Summons a deer decoy"

**Special Properties:**
- Creates a deer that **attracts enemy attention**
- **Explodes when killed** or after timeout
- Enemies target the deer instead of you
- Useful for distracting groups
- Limited uses (10)
- High mana cost

---

#### Summon Missile

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 20 |
| Explosion Damage | ~60 (shown 240) |
| Radius | 10 |
| Speed | 80 |
| Cast Delay | +0.50s |

**Description:** "Summons a homing missile"

**Special Properties:**
- **Homes toward enemies** weakly
- Explodes on impact
- Slow but persistent (80 speed)
- Unlimited uses
- Moderate cast delay
- Good fire-and-forget spell

---

#### Summon Tentacle

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 20 |
| Damage | Melee |
| Radius | 8 |
| Speed | 60 |
| Cast Delay | +0.67s |

**Description:** "Summons a grasping tentacle"

**Special Properties:**
- Creates tentacle that **attacks nearby enemies**
- Deals melee damage (instant kills frozen enemies)
- Slow movement (60 speed)
- Unlimited uses
- Good for close-range crowd control
- Timer variant available

---

#### Summon Rock Spirit

| Stat | Value |
|------|-------|
| Uses | 10 |
| Mana Drain | 120 |
| Speed | 230 |
| Lifetime | 60 |
| Cast Delay | +1.33s |

**Description:** "Summons a spirit of stone"

**Special Properties:**
- Creates a **friendly rock golem**
- Attacks enemies automatically
- Limited lifetime (60 frames)
- High mana cost
- Limited uses (10)
- Provides temporary ally

---

#### Summon Explosive Box

| Stat | Value |
|------|-------|
| Uses | 15 |
| Mana Drain | 40 |
| Explosion Damage | Yes |
| Radius | 40 |
| Speed | 60 |

**Description:** "Summons an explosive crate"

**Special Properties:**
- Creates physics box that **explodes when damaged**
- Can be kicked toward enemies
- Large explosion radius (40)
- Can chain-react with other explosives
- **Danger:** Can explode near you

**Variants:**
- **Summon Large Explosive Box** (same stats, radius 60)

### Healing Projectiles

---

#### Healing Bolt

| Stat | Value |
|------|-------|
| Uses | 20 |
| Mana Drain | 15 |
| Healing | 8.75 HP |
| Radius | 2 |
| Speed | 625 |
| Lifetime | 60 |
| Cast Delay | +0.07s |
| Critical Chance | 2% |

**Description:** "A bolt that heals"

**Special Properties:**
- **One of the few reliable healing sources** in the game
- **Has friendly fire** - will also heal enemies!
- **CRITICAL WARNING:** Damage modifiers convert healing to HARM
  - Adding "Damage Plus" makes it deal damage instead
- **Cannot benefit from Unlimited Spells perk**
- Healing is **increased by Berserkium** effect
- Healing is **increased by Glass Cannon** perk
- Limited uses (20)
- Fast projectile (625 speed)

### Special Projectiles

---

#### BULLET???

| Stat | Value |
|------|-------|
| Uses | 5 |
| Mana Drain | 2 |
| Speed | 450 |
| Cast Delay | -0.05s |
| Bounces | +1 |

**Description:** "What even is this?"

**Special Properties:**
- Mysterious/glitched projectile
- Very low mana cost (2)
- Negative cast delay
- Bounces once
- Limited uses (5)
- Easter egg spell

---

#### Chain Bolt

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 80 |
| Radius | 40 |
| Speed | 44 |
| Cast Delay | +0.75s |

**Description:** "A bolt that chains between enemies"

**Special Properties:**
- **Jumps between nearby enemies** automatically
- Slow-moving projectile (44 speed)
- Large effective radius (40)
- Good for groups of enemies
- High mana cost (80)
- Unlimited uses

---

#### Chainsaw

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 1 |
| Damage | Slice |
| Radius | 3 |
| Speed | 1 |
| Cast Delay | 0.00s |
| Recharge Time | -0.17s |
| Critical Chance | 6% |

**Description:** "BRRRRRRR"

**Special Properties:**
- **Extremely low mana cost (1)**
- **Zero cast delay** - instant cast
- **Negative recharge** (-0.17s) - rapid fire
- Essentially point-blank melee attack
- **Key spell for machine gun builds**
- Used to reduce wand delays
- Causes bleeding (slice damage)

---

#### Cursed Sphere

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 40 |
| Damage | Curse |
| Radius | 1 |
| Speed | 120 |
| Cast Delay | +0.33s |

**Description:** "A sphere of pure curse"

**Special Properties:**
- Applies **bad luck effect** to targets
- Curse damage ignores most resistances
- Small radius (1) - precision targeting
- Moderate speed
- Unlimited uses

---

#### Digging Bolt

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 0 |
| Drill Damage | 6 |
| Radius | 2 |
| Cast Delay | +0.02s |
| Recharge Time | -0.17s |

**Description:** "A bolt that digs through terrain"

**Special Properties:**
- **Zero mana cost** - completely free
- Digs through soft terrain
- Tiny cast delay (+0.02s)
- Negative recharge for rapid digging
- Essential exploration tool
- Unlimited uses

---

#### Digging Blast

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 0 |
| Drill Damage | 7 |
| Radius | 2 |
| Cast Delay | +0.02s |
| Recharge Time | -0.17s |

**Description:** "A blast that digs through terrain"

**Special Properties:**
- Slightly more damage than Digging Bolt (7 vs 6)
- Otherwise identical stats
- Zero mana cost
- Good for faster terrain removal

---

#### Glowing Lance

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 30 |
| Projectile Damage | 35 |
| Radius | 1 |
| Speed | 350 |
| Lifetime | 300 |
| Cast Delay | +0.33s |
| Spread Modifier | -20° |

**Description:** "A lance of pure light"

**Special Properties:**
- **Massive accuracy bonus** (-20° spread)
- Pierces through soft materials
- High damage (35)
- Fast projectile (350 speed)
- Long lifetime (300 frames)
- Excellent sniper spell

---

#### Triplicate Bolt

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 25 |
| Radius | 4 |
| Speed | 550 |
| Lifetime | 120 |
| Cast Delay | +0.13s |
| Critical Chance | 14% |

**Description:** "A bolt that splits into three"

**Special Properties:**
- Fires three projectiles at once
- High critical chance (14%)
- Fast speed (550)
- Short cast delay
- Good spread coverage

---

#### Spiral Shot

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 15 |
| Speed | 110 |
| Lifetime | 100 |
| Cast Delay | +0.33s |

**Description:** "A shot that spirals"

**Special Properties:**
- Travels in **whirlwind/spiral pattern**
- Slow-moving (110 speed)
- Unpredictable trajectory
- Can hit targets behind cover
- Useful for clearing areas

---

#### Infestation

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 40 |
| Speed | 550 |
| Lifetime | 600 |
| Cast Delay | -0.03s |
| Critical Chance | 25% |

**Description:** "Bugs that spread to nearby enemies"

**Special Properties:**
- **Spreads to nearby enemies** on hit
- Very high crit chance (25%)
- Negative cast delay (-0.03s)
- Long lifetime (600 frames)
- Fast movement (550 speed)
- Can chain through groups

---

#### Dropper Bolt

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 35 |
| Explosion Damage | ~80 (shown 320) |
| Radius | 16 |
| Speed | 65 |
| Lifetime | 500 |
| Cast Delay | +0.67s |

**Description:** "A very heavy bolt"

**Special Properties:**
- **Very heavy** - affected strongly by gravity
- Arcs downward quickly
- Good for hitting enemies below
- Explodes on impact
- Slow speed (65)
- Long lifetime for reaching depths

---

#### Flock of Ducks

| Stat | Value |
|------|-------|
| Uses | 20 |
| Mana Drain | 100 |
| Radius | 25 |
| Speed | 265 |
| Cast Delay | +0.33s |
| Recharge Time | +1.0s |

**Description:** "QUACK QUACK QUACK"

**Special Properties:**
- Summons **multiple duck projectiles**
- Ducks home toward enemies
- Humorous visual effect
- High mana cost (100)
- Limited uses (20)
- Long recharge (+1.0s)

---

#### Freezing Gaze

| Stat | Value |
|------|-------|
| Uses | 20 |
| Mana Drain | 45 |
| Damage | Ice |
| Speed | 220 |
| Lifetime | 25 |
| Cast Delay | +0.33s |

**Description:** "A gaze that freezes hearts"

**Special Properties:**
- Creates **freezing aura** around projectile
- Freezes enemies on contact
- Short lifetime (25 frames)
- Limited uses (20)
- Short-range freeze effect

---

#### Worm Launcher

| Stat | Value |
|------|-------|
| Uses | 10 |
| Mana Drain | 150 |
| Damage | Worm attack |
| Speed | 250 |
| Lifetime | 100 |
| Cast Delay | +1.33s |
| Recharge Time | +0.67s |

**Description:** "Launches a worm"

**Special Properties:**
- **Spawns an actual worm enemy** that attacks
- Worm burrows through terrain
- Can turn against you if not careful
- Very high mana cost (150)
- Limited uses (10)
- Chaotic but powerful

---

#### Eldritch Portal

| Stat | Value |
|------|-------|
| Uses | 5 |
| Mana Drain | 140 |
| Speed | 800 |
| Cast Delay | +0.50s |

**Description:** "Opens a portal to somewhere"

**Special Properties:**
- Creates **one-way portal** on impact
- Very fast projectile (800 speed)
- Teleports you to portal location
- Limited uses (5)
- High mana cost
- Escape/exploration utility

---

#### Earthquake

| Stat | Value |
|------|-------|
| Uses | 3 |
| Mana Drain | 240 |
| Damage | Terrain destruction |
| Radius | 2 |
| Speed | 110 |
| Lifetime | 30 |

**Description:** "Calls the earth's anger"

**Special Properties:**
- **Destroys terrain in large area**
- Creates falling debris
- Can crush enemies with debris
- Very high mana cost (240)
- Only 3 uses
- Causes screen shake

### Crystal Spells

---

#### Dormant Crystal

| Stat | Value |
|------|-------|
| Uses | 20 |
| Mana Drain | 20 |
| Explosion Damage | ~30 (shown 120) |
| Speed | 265 |
| Cast Delay | +0.50s |
| Speed Modifier | 0.75x |
| Spread Modifier | -1° |

**Description:** "A crystal that waits"

**Special Properties:**
- **Explodes when caught in an explosion** - chain reaction
- Sticks to surfaces when it lands
- Slows other projectiles (0.75x speed mod)
- Slight accuracy bonus (-1° spread)
- Limited uses (20)
- Set up multiple crystals, then detonate with explosion

**Variants:**
- **Dormant Crystal w/ Trigger** (20 uses): Casts spell on detonation

---

#### Unstable Crystal

| Stat | Value |
|------|-------|
| Uses | 15 |
| Mana Drain | 20 |
| Explosion Damage | ~30 (shown 120) |
| Speed | 265 |
| Cast Delay | +0.50s |
| Speed Modifier | 0.75x |
| Spread Modifier | -1° |

**Description:** "A crystal that might explode"

**Special Properties:**
- Similar to Dormant Crystal
- **More likely to explode on impact**
- Same chain reaction potential
- Slightly fewer uses (15 vs 20)
- Same modifier stats

**Variants:**
- **Unstable Crystal w/ Trigger** (15 uses): Casts spell on detonation

### Teleport Spells

---

#### Teleport Bolt

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 40 |
| Radius | 2 |
| Speed | 800 |
| Lifetime | 40 |
| Cast Delay | +0.05s |
| Spread Modifier | -2° |

**Description:** "Teleports you to where the bolt lands"

**Special Properties:**
- **Teleports you to impact point**
- Fast projectile (800 speed)
- Accuracy bonus (-2° spread)
- Essential mobility spell
- Short cast delay
- Can teleport into walls (death!)
- **Tip:** Aim at open spaces

---

#### Small Teleport Bolt

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 20 |
| Radius | 2 |
| Speed | 1350 |
| Lifetime | 8 |
| Spread Modifier | -2° |

**Description:** "A short-range teleport"

**Special Properties:**
- **Very short range** (lifetime 8)
- Extremely fast (1350 speed)
- Lower mana cost (20)
- Good for quick repositioning
- Safer - less likely to teleport into walls
- No cast delay

---

#### Swapper

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 5 |
| Radius | 2 |
| Speed | 800 |
| Lifetime | 40 |
| Cast Delay | +0.05s |
| Spread Modifier | -2° |

**Description:** "Swaps positions with target"

**Special Properties:**
- **Swaps your position with enemy** hit
- Very low mana cost (5)
- Can reposition dangerous enemies
- Great for tactical combat
- Enemy ends up where you were
- Unlimited uses

---

#### Return

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 40 |
| Radius | 2 |
| Speed | 240 |
| Cast Delay | +0.05s |
| Spread Modifier | -2° |

**Description:** "Returns you to the mountain"

**Special Properties:**
- **Teleports you back to spawn/Holy Mountain**
- Slow projectile (240 speed)
- Emergency escape spell
- Can save runs
- Unlimited uses
- Works from anywhere in the world

---

#### Homebringer Teleport Bolt

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 20 |
| Radius | 2 |
| Speed | 800 |
| Lifetime | 8 |
| Spread Modifier | -2° |

**Description:** "Teleports you home"

**Special Properties:**
- Short-range version of Return
- Fast projectile (800 speed)
- Short lifetime (8 frames)
- Lower mana cost (20)
- Quick escape option

### Magic Guard

---

#### Magic Guard

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 40 |
| Orbiting Lights | 4 |
| Cast Delay | +0.33s |

**Description:** "Summons protective lights"

**Special Properties:**
- Creates **4 orbiting lights** around you
- Lights damage enemies on contact
- Provides some protection
- Lights persist for duration
- Can block some projectiles
- Unlimited uses

---

#### Big Magic Guard

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 60 |
| Orbiting Lights | 8 |
| Cast Delay | +0.50s |

**Description:** "Summons more protective lights"

**Special Properties:**
- Creates **8 orbiting lights** (double)
- Better protection than standard
- Higher mana cost (60)
- Longer cast delay (+0.50s)
- More consistent damage shield
- Unlimited uses

---

## Static Projectile Spells

### Circle Spells

---

#### Circle of Vigour

| Stat | Value |
|------|-------|
| Uses | 2 |
| Mana Drain | 80 |
| Lifetime | 260 frames (~4.3s) |
| Cast Delay | +0.25s |

**Description:** "A circle that heals those within"

**Special Properties:**
- Heals **10% max HP per second** + 1.25 flat healing
- **Cannot benefit from Unlimited Spells** perk
- Healing scales with your maximum HP
- Very limited uses (2)
- Short duration compared to other circles
- **Best healing spell** in the game
- Can heal other creatures too

---

#### Circle of Shielding

| Stat | Value |
|------|-------|
| Uses | 10 |
| Mana Drain | 20 |
| Lifetime | 7200 frames (~2 minutes) |
| Cast Delay | +0.25s |

**Description:** "A circle that reflects projectiles"

**Special Properties:**
- **Reflects incoming enemy projectiles** back at shooters
- Very long duration (2 minutes)
- Low mana cost (20)
- Great defensive tool
- Doesn't stop melee attacks
- Can reflect your own projectiles if not careful

---

#### Circle of Stillness

| Stat | Value |
|------|-------|
| Uses | 15 |
| Mana Drain | 50 |
| Lifetime | 7200 frames (~2 minutes) |
| Cast Delay | +0.25s |

**Description:** "A circle that freezes those within"

**Special Properties:**
- **Freezes enemies** who enter the circle
- Frozen enemies take massive melee damage
- Long duration (2 minutes)
- Good crowd control
- Also freezes liquids in the area

---

#### Circle of Thunder

| Stat | Value |
|------|-------|
| Uses | 15 |
| Mana Drain | 60 |
| Lifetime | 7200 frames (~2 minutes) |
| Cast Delay | +0.25s |

**Description:** "A circle that electrifies those within"

**Special Properties:**
- Creates **electric damage field**
- Stuns enemies on contact
- Damages continuously while inside
- Long duration (2 minutes)
- **Electrifies liquids** in the area
- Can damage you if you enter

---

#### Circle of Fervour

| Stat | Value |
|------|-------|
| Uses | 15 |
| Mana Drain | 30 |
| Lifetime | 7200 frames (~2 minutes) |
| Cast Delay | +0.25s |

**Description:** "A circle that increases fire rate"

**Special Properties:**
- **Increases cast speed** for entities inside
- Applies to both you and enemies
- Long duration (2 minutes)
- Low mana cost (30)
- Good for machine gun builds
- Stacks with wand modifiers

---

#### Circle of Buoyancy

| Stat | Value |
|------|-------|
| Uses | 15 |
| Mana Drain | 10 |
| Lifetime | 7200 frames (~2 minutes) |
| Cast Delay | +0.25s |

**Description:** "A circle that makes things float"

**Special Properties:**
- **Float in liquids** while inside circle
- Very low mana cost (10)
- Long duration (2 minutes)
- Useful for crossing water/lava areas
- Affects physics objects too
- Place strategically for safety

---

#### Circle of Displacement

| Stat | Value |
|------|-------|
| Uses | 15 |
| Mana Drain | 30 |
| Lifetime | 7200 frames (~2 minutes) |
| Cast Delay | +0.25s |

**Description:** "A circle that pushes things away"

**Special Properties:**
- **Pushes entities** away from center
- Knockback effect on contact
- Long duration (2 minutes)
- Good for area denial
- Can push you too if you enter

---

#### Circle of Unstable Metamorphosis

| Stat | Value |
|------|-------|
| Uses | 10 |
| Mana Drain | 20 |
| Lifetime | 7200 frames (~2 minutes) |
| Cast Delay | +0.25s |

**Description:** "A circle of chaotic transformation"

**Special Properties:**
- **Random polymorph** on creatures who enter
- Can transform enemies into weaker forms
- **Can transform you** - very dangerous
- Unpredictable results
- Long duration (2 minutes)

---

#### Circle of Transmogrification

| Stat | Value |
|------|-------|
| Uses | 5 |
| Mana Drain | 50 |
| Lifetime | 7200 frames (~2 minutes) |
| Cast Delay | +0.25s |

**Description:** "A circle that transforms creatures"

**Special Properties:**
- **Transforms creatures** into other forms
- More controlled than Unstable Metamorphosis
- Limited uses (5)
- Higher mana cost (50)
- Long duration (2 minutes)
- Use cautiously near yourself

### Barrier Spells

---

#### Horizontal Barrier

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 70 |
| Lifetime | 3 seconds |
| Cast Delay | +0.08s |

**Description:** "Creates a horizontal energy wall"

**Special Properties:**
- Creates **horizontal barrier** at impact point
- Blocks projectiles from passing through
- Short duration (3 seconds)
- Unlimited uses
- Good for creating temporary cover
- Blocks enemies briefly

---

#### Vertical Barrier

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 70 |
| Lifetime | 3 seconds |
| Cast Delay | +0.08s |

**Description:** "Creates a vertical energy wall"

**Special Properties:**
- Creates **vertical barrier** at impact point
- Blocks projectiles from passing through
- Short duration (3 seconds)
- Good for blocking corridors
- Unlimited uses

---

#### Square Barrier

| Stat | Value |
|------|-------|
| Uses | 20 |
| Mana Drain | 70 |
| Lifetime | 3 seconds |
| Cast Delay | +0.33s |

**Description:** "Creates a square energy barrier"

**Special Properties:**
- Creates **square barrier** enclosure
- Traps or protects entities inside
- Limited uses (20)
- Longer cast delay (+0.33s)
- Can trap enemies or protect yourself
- Short duration (3 seconds)

### Cloud Spells

---

#### Rain Cloud

| Stat | Value |
|------|-------|
| Uses | 10 |
| Mana Drain | 30 |
| Material | Water |
| Lifetime | 600 frames (~10s) |
| Cast Delay | +0.25s |

**Description:** "Summons a rain cloud"

**Special Properties:**
- Creates cloud that **rains water** in area
- Extinguishes fires
- Fills pools with water
- Can wash off stains
- Moderate duration (10 seconds)

---

#### Oil Cloud

| Stat | Value |
|------|-------|
| Uses | 15 |
| Mana Drain | 20 |
| Material | Oil |
| Lifetime | 600 frames (~10s) |
| Cast Delay | +0.25s |

**Description:** "Summons an oil cloud"

**Special Properties:**
- Creates cloud that **rains oil**
- Oil is **highly flammable**
- Sets up fire traps
- Covers enemies in oil for fire damage
- Low mana cost (20)

---

#### Blood Cloud

| Stat | Value |
|------|-------|
| Uses | 3 |
| Mana Drain | 60 |
| Material | Blood |
| Lifetime | 600 frames (~10s) |
| Cast Delay | +0.50s |

**Description:** "Summons a cloud of blood"

**Special Properties:**
- Creates cloud that **rains blood**
- Blood can trigger alchemical reactions
- Limited uses (3)
- Higher mana cost (60)
- Stains entities with blood

---

#### Acid Cloud

| Stat | Value |
|------|-------|
| Uses | 4 |
| Mana Drain | 120 |
| Material | Acid |
| Lifetime | 400 frames (~6.7s) |
| Cast Delay | +0.25s |

**Description:** "Summons an acid cloud"

**Special Properties:**
- Creates cloud that **rains acid**
- Acid dissolves terrain and damages enemies
- Very high mana cost (120)
- Limited uses (4)
- Shorter duration than other clouds
- **Warning:** Acid damages you too

---

#### Thundercloud

| Stat | Value |
|------|-------|
| Uses | 5 |
| Mana Drain | 90 |
| Material | Electric rain |
| Lifetime | 600 frames (~10s) |
| Cast Delay | +0.50s |

**Description:** "Summons an electric storm cloud"

**Special Properties:**
- Creates cloud with **lightning strikes**
- Electrifies the rain and area below
- High mana cost (90)
- Limited uses (5)
- **Electrifies water** beneath it
- Very dangerous in wet areas

### Explosion Spells

---

#### Explosion

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 80 |
| Explosion Damage | ~68.75 (shown 275) |
| Radius | 15 |
| Cast Delay | +0.05s |

**Description:** "Creates an explosion at cast point"

**Special Properties:**
- **Static explosion** - detonates where cast
- Standard explosion damage
- Destroys soft terrain
- Short cast delay (+0.05s)
- Unlimited uses
- **Has friendly fire** - damages you if too close

---

#### Explosion of Brimstone

| Stat | Value |
|------|-------|
| Uses | 10 |
| Mana Drain | 30 |
| Damage | Explosion + Fire |
| Cast Delay | +0.05s |

**Description:** "Creates a fiery explosion"

**Special Properties:**
- Explosion that also **sets area on fire**
- Lower mana cost than standard (30)
- Limited uses (10)
- Fire spreads to flammables
- Creates lasting fire hazard

---

#### Explosion of Poison

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 30 |
| Damage | Explosion + Poison |
| Radius | 9 |
| Cast Delay | +0.05s |

**Description:** "Creates a poisonous explosion"

**Special Properties:**
- Explosion that **spreads poison**
- Applies poison damage over time
- Unlimited uses
- Lower mana cost (30)
- Poison stains entities

---

#### Explosion of Spirits

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 30 |
| Damage | Explosion + Drunk |
| Radius | 12 |
| Cast Delay | +0.05s |

**Description:** "Creates an intoxicating explosion"

**Special Properties:**
- Explosion that **applies drunk effect**
- Drunk enemies stumble and have impaired aim
- Unlimited uses
- Larger radius (12)
- Low mana cost (30)

---

#### Explosion of Thunder

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 110 |
| Damage | Explosion + Electric |
| Radius | 28 |
| Cast Delay | +0.25s |

**Description:** "Creates an electric explosion"

**Special Properties:**
- Explosion with **electric damage**
- Stuns enemies on hit
- **Electrifies liquids** in radius
- Large radius (28)
- High mana cost (110)
- Longer cast delay (+0.25s)

---

#### Magical Explosion

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 80 |
| Explosion Damage | ~35 (shown 140) |
| Cast Delay | +0.05s |

**Description:** "A magical explosion that doesn't destroy terrain"

**Special Properties:**
- **Does not destroy terrain** - purely damages entities
- Good for combat without collateral damage
- Unlimited uses
- Same mana as standard Explosion
- Safe for use in Holy Mountains

---

#### Destruction

| Stat | Value |
|------|-------|
| Uses | 5 |
| Mana Drain | 600 |
| Damage | Massive |
| Cast Delay | +1.67s |
| Recharge Time | +5.00s |

**Description:** "Pure destruction"

**Special Properties:**
- **Massive explosion**
- Extremely high mana cost (600)
- Limited uses (5)
- Very long cast delay (+1.67s)
- Very long recharge (+5.00s)
- Destroys almost everything
- **Near-certain death** at close range

### Sade Spells

---

#### Matosade

| Stat | Value |
|------|-------|
| Uses | 2 |
| Mana Drain | 225 |
| Lifetime | 400 frames (~6.7s) |
| Cast Delay | +1.67s |
| Recharge Time | +1.0s |

**Description:** "Summons a rain of worms"

**Special Properties:**
- **Spawns multiple worms** from above
- Worms attack everything, including you
- Very high mana cost (225)
- Limited uses (2)
- Chaotic and dangerous
- Worms burrow through terrain

---

#### Meteorisade

| Stat | Value |
|------|-------|
| Uses | 2 |
| Mana Drain | 225 |
| Lifetime | 600 frames (~10s) |
| Cast Delay | +1.67s |
| Recharge Time | +1.0s |

**Description:** "Summons a meteor shower"

**Special Properties:**
- **Rains meteors** from above
- Each meteor explodes on impact
- Massive area damage
- Very high mana cost (225)
- Limited uses (2)
- **Extremely dangerous** to stand under

### Field Spells

---

#### Glittering Field

| Stat | Value |
|------|-------|
| Uses | 20 |
| Mana Drain | 90 |
| Lifetime | 600 frames (~10s) |
| Cast Delay | +0.17s |
| Recharge Modifier | -2.00s |

**Description:** "A field of sparkling energy"

**Special Properties:**
- **Reduces wand recharge time** by 2 seconds while active
- Great for rapid-fire builds
- High mana cost (90)
- Limited uses (20)
- Moderate duration (10 seconds)
- Must stay in field for effect

---

#### Projectile Transmutation Field

| Stat | Value |
|------|-------|
| Uses | 6 |
| Mana Drain | 120 |
| Lifetime | 7200 frames (~2 minutes) |
| Cast Delay | +0.25s |

**Description:** "A field that transforms projectiles"

**Special Properties:**
- **Transforms enemy projectiles** into something else
- Very long duration (2 minutes)
- High mana cost (120)
- Limited uses (6)
- Great defensive tool
- Unpredictable transformations

---

#### Projectile Gravity Field

| Stat | Value |
|------|-------|
| Uses | 3 |
| Mana Drain | 120 |
| Lifetime | 7200 frames (~2 minutes) |
| Cast Delay | +0.25s |

**Description:** "A field that attracts projectiles"

**Special Properties:**
- **Attracts projectiles** toward center
- Bends enemy shots away from you
- Very long duration (2 minutes)
- Very limited uses (3)
- High mana cost (120)
- Can redirect your own shots

---

#### Projectile Thunder Field

| Stat | Value |
|------|-------|
| Uses | 3 |
| Mana Drain | 140 |
| Lifetime | 7200 frames (~2 minutes) |
| Cast Delay | +0.25s |

**Description:** "A field that electrifies projectiles"

**Special Properties:**
- **Adds electric damage** to projectiles passing through
- Affects both enemy and your projectiles
- Very long duration (2 minutes)
- Very limited uses (3)
- Highest field mana cost (140)

---

#### Powder Vacuum Field

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 20 |
| Lifetime | 300 frames (~5s) |
| Cast Delay | +0.17s |

**Description:** "A field that absorbs powders"

**Special Properties:**
- **Sucks up powder materials** (sand, coal, etc.)
- Good for cleaning up debris
- Low mana cost (20)
- Unlimited uses
- Short duration (5 seconds)

---

#### Liquid Vacuum Field

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 20 |
| Lifetime | 300 frames (~5s) |
| Cast Delay | +0.17s |

**Description:** "A field that absorbs liquids"

**Special Properties:**
- **Sucks up liquid materials** (water, acid, blood, etc.)
- Good for draining pools
- Low mana cost (20)
- Unlimited uses
- Short duration (5 seconds)

---

#### Vacuum Field

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 20 |
| Lifetime | 20 frames (~0.33s) |
| Cast Delay | +0.17s |

**Description:** "A field that absorbs everything"

**Special Properties:**
- **Absorbs all matter** briefly
- Very short duration (0.33 seconds)
- Absorbs both powders and liquids
- Low mana cost (20)
- Unlimited uses
- Instant cleanup

---

#### Delayed Spellcast

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 20 |
| Lifetime | 100 frames (~1.7s) |
| Cast Delay | +0.17s |

**Description:** "Casts the next spell after a delay"

**Special Properties:**
- **Casts next spell after delay**
- Creates delayed trap/trigger
- Low mana cost (20)
- Unlimited uses
- Useful for timing attacks

### Black Hole Variants

---

#### Giga Black Hole

| Stat | Value |
|------|-------|
| Uses | 6 |
| Mana Drain | 240 |
| Radius | 1 (grows) |
| Lifetime | 500 frames (~8.3s) |
| Cast Delay | +1.33s |

**Description:** "A massive black hole"

**Special Properties:**
- **Larger than standard Black Hole**
- Consumes more terrain per second
- No damage to entities (terrain only)
- Limited uses (6)
- High mana cost (240)
- Great for large-scale digging

---

#### Omega Black Hole

| Stat | Value |
|------|-------|
| Uses | 6 |
| Mana Drain | 500 |
| Lifetime | 1000 frames (~16.7s) |
| Cast Delay | +2.0s |
| Recharge Time | +1.67s |

**Description:** "The ultimate black hole"

**Special Properties:**
- **Enormous terrain consumption**
- Very long duration (~17 seconds)
- Extremely high mana cost (500)
- Limited uses (6)
- Long cast delay (+2.0s)
- Can consume entire biome sections
- **Does damage** (unlike standard black holes)

### Summon Swarm Spells

---

#### Summon Friendly Fly

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 120 |
| Lifetime | 1800 frames (~30s) |
| Cast Delay | +1.33s |
| Recharge Time | +0.67s |
| Critical Chance | 24% |

**Description:** "Summons a friendly fly companion"

**Special Properties:**
- Creates **single powerful fly ally**
- Very high crit chance (24%)
- Long duration (30 seconds)
- Attacks nearby enemies
- High mana cost (120)
- Unlimited uses

---

#### Summon Fly Swarm

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 70 |
| Lifetime | 750 frames (~12.5s) |
| Cast Delay | +1.00s |
| Recharge Time | +0.33s |
| Critical Chance | 6% |

**Description:** "Summons a swarm of flies"

**Special Properties:**
- Creates **multiple fly allies**
- Lower individual damage
- Moderate duration (12.5 seconds)
- Good area coverage
- Lower mana cost (70)
- Unlimited uses

---

#### Summon Firebug Swarm

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 80 |
| Lifetime | 850 frames (~14s) |
| Cast Delay | +1.00s |
| Recharge Time | +0.33s |
| Critical Chance | 12% |

**Description:** "Summons a swarm of firebugs"

**Special Properties:**
- Creates **fire-damage dealing bugs**
- Sets enemies on fire
- Better crit than flies (12%)
- Longer duration (14 seconds)
- Slightly higher mana (80)
- **Can ignite flammable materials**

---

#### Summon Wasp Swarm

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 90 |
| Lifetime | 1100 frames (~18s) |
| Cast Delay | +1.00s |
| Recharge Time | +0.33s |
| Critical Chance | 24% |

**Description:** "Summons a swarm of wasps"

**Special Properties:**
- Creates **aggressive wasp allies**
- Very high crit chance (24%)
- Longest swarm duration (18 seconds)
- Highest swarm mana cost (90)
- Most dangerous swarm type
- Unlimited uses

### Other Static

---

#### Explosive Detonator

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 50 |
| Radius | 26 |

**Description:** "Detonates nearby explosives"

**Special Properties:**
- **Triggers nearby explosive objects**
- Detonates TNT, propane tanks, etc.
- Radius 26 for detecting explosives
- Useful for chain reactions
- Moderate mana cost (50)
- Unlimited uses

---

#### Random Static Projectile

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 20 |

**Description:** "Casts a random static spell"

**Special Properties:**
- Casts **random static projectile spell**
- Unpredictable results
- Low mana cost (20)
- Unlimited uses
- Can be any static spell type
- **Gamble spell** - results vary wildly

---

## Passive Spells

Passive spells remain active as long as they're equipped on the wand you're holding.

---

#### Torch

| Stat | Value |
|------|-------|
| Mana Drain | 0 |

**Description:** "Provides light"

**Special Properties:**
- **No mana cost** - always free
- Illuminates area around you
- Essential for dark areas
- Light reveals hidden things
- Passive - always active while held
- **Can ignite flammable materials** near you

---

#### Electric Torch

| Stat | Value |
|------|-------|
| Mana Drain | 0 |

**Description:** "Provides electric light"

**Special Properties:**
- **No mana cost** - always free
- Blue/white electric light
- Same illumination as regular torch
- **Electrifies water** you touch
- Can shock enemies in water
- **Warning:** Dangerous in wet areas

---

#### Energy Shield

| Stat | Value |
|------|-------|
| Mana Drain | 10 |

**Description:** "A protective energy barrier"

**Special Properties:**
- Creates **shield around you**
- Blocks some incoming projectiles
- Costs mana to maintain (10)
- Passive protection while held
- Doesn't block all damage types
- Good for ranged combat

---

#### Energy Shield Sector

| Stat | Value |
|------|-------|
| Mana Drain | 10 |

**Description:** "A directional energy shield"

**Special Properties:**
- Creates **shield in one direction**
- Points toward cursor/aim direction
- Only blocks from that direction
- Same mana cost as full shield (10)
- Better focused protection
- Leaves other sides vulnerable

---

#### Summon Tiny Ghost

| Stat | Value |
|------|-------|
| Mana Drain | 0 |

**Description:** "Summons a tiny ghost companion"

**Special Properties:**
- **No mana cost** - always free
- Creates small ghost ally
- Ghost attacks nearby enemies
- Weak but persistent damage
- Provides companionship
- Passive - stays while wand is held

---

## Utility Spells

---

#### Blood Magic

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | -100 (restores mana) |
| Cast Delay | -0.33s |
| Recharge Time | -0.33s |
| HP Cost | 4 HP per cast |

**Description:** "Sacrifice health for mana"

**Special Properties:**
- **Restores 100 mana** per cast
- **Costs 4 HP** each use
- Negative cast delay and recharge (faster)
- Unlimited uses
- Essential for mana-hungry builds
- **Warning:** Can kill you if HP runs out

---

#### All-Seeing Eye

| Stat | Value |
|------|-------|
| Uses | 10 |
| Mana Drain | 100 |

**Description:** "See beyond normal sight"

**Special Properties:**
- **Reveals hidden areas** temporarily
- Shows secrets and treasures
- High mana cost (100)
- Limited uses (10)
- Vision effect has duration
- Useful for exploration

---

#### Wand Refresh

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 20 |
| Cast Delay | -0.42s |

**Description:** "Resets the wand's spell order"

**Special Properties:**
- **Resets wand to beginning** of spell order
- Enables infinite spell loops
- Negative cast delay (-0.42s)
- Low mana cost (20)
- Key component of many builds
- Unlimited uses

---

#### Blood To Power

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 20 |

**Description:** "Blood stains increase damage"

**Special Properties:**
- **Increases damage** based on blood stains on you
- More blood = more damage
- Low mana cost (20)
- Unlimited uses
- Synergizes with Blood Magic
- Rewards aggressive play

---

#### Gold To Power

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 30 |

**Description:** "Gold increases damage"

**Special Properties:**
- **Increases damage** based on gold collected
- More gold = more damage
- Slightly higher mana (30)
- Unlimited uses
- Rewards exploration and looting
- Damage bonus scales with wealth

---

#### Long-Distance Cast

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 0 |
| Cast Delay | -0.08s |
| Projectile Speed | 1800 |
| Projectile Lifetime | 4 frames |

**Description:** "Cast spells at extreme range"

**Special Properties:**
- **No mana cost**
- Extremely fast projectile (1800 speed)
- Very short lifetime (4 frames)
- Negative cast delay
- Creates fast, short-range cast point
- Useful for precise placement

---

#### Teleporting Cast

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 100 |
| Cast Delay | +0.33s |

**Description:** "Cast spells from a distance"

**Special Properties:**
- **Teleports spells** to cast from afar
- High mana cost (100)
- Unlimited uses
- Safer casting of dangerous spells
- Positive cast delay (+0.33s)

---

#### Warp Cast

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 20 |
| Cast Delay | +0.17s |
| Projectile Speed | 100 |
| Projectile Lifetime | 5 frames |

**Description:** "Cast through a warp"

**Special Properties:**
- Slow projectile (100 speed)
- Short lifetime (5 frames)
- Low mana cost (20)
- Unlimited uses
- Creates slow cast point
- Different timing than Long-Distance

---

#### Summon Platform

| Stat | Value |
|------|-------|
| Uses | 20 |
| Mana Drain | 30 |
| Cast Delay | +0.67s |

**Description:** "Creates a temporary platform"

**Special Properties:**
- **Creates solid platform** at cast point
- Platform is temporary
- Good for crossing gaps
- Limited uses (20)
- Can create stepping stones
- Useful for traversal puzzles

---

#### Summon Wall

| Stat | Value |
|------|-------|
| Uses | 20 |
| Mana Drain | 40 |
| Cast Delay | +0.67s |

**Description:** "Creates a temporary wall"

**Special Properties:**
- **Creates vertical wall** at cast point
- Wall is temporary
- Blocks projectiles and enemies
- Limited uses (20)
- Higher mana than platform (40)
- Good for creating cover

---

#### Summon Taikasauva

| Stat | Value |
|------|-------|
| Uses | 1 |
| Mana Drain | 300 |

**Description:** "Summons a special wand"

**Special Properties:**
- **Spawns a wand** in the world
- Only 1 use
- Very high mana cost (300)
- Wand has random spells
- Can be useful or useless
- **Gamble spell** - results vary

### Spells To Conversion

These utility spells convert the following spells into a specific type.

---

#### Spells To Acid

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 200 |
| Cast Delay | +1.67s |
| Recharge Time | +1.67s |

**Description:** "Converts following spells to acid"

**Special Properties:**
- **Transforms spells into Acid Balls**
- Very high mana cost (200)
- Long delays
- Unlimited uses
- Converts multiple spell types

---

#### Spells To Black Holes

| Stat | Value |
|------|-------|
| Uses | 10 |
| Mana Drain | 200 |
| Cast Delay | +1.67s |
| Recharge Time | +1.67s |

**Description:** "Converts following spells to black holes"

**Special Properties:**
- **Transforms spells into Black Holes**
- Limited uses (10)
- High mana cost (200)
- Long delays
- Great for digging builds

---

#### Spells To Death Crosses

| Stat | Value |
|------|-------|
| Uses | 15 |
| Mana Drain | 80 |
| Cast Delay | +0.67s |
| Recharge Time | +0.67s |

**Description:** "Converts following spells to death crosses"

**Special Properties:**
- **Transforms spells into Death Crosses**
- Lower mana cost (80)
- Moderate delays
- Limited uses (15)
- Adds homing behavior

---

#### Spells To Giga Sawblades

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 100 |
| Cast Delay | +0.83s |
| Recharge Time | +0.83s |

**Description:** "Converts following spells to giga sawblades"

**Special Properties:**
- **Transforms spells into Giga Sawblades**
- Unlimited uses
- Moderate mana (100)
- Creates bouncing sawblades
- Great for enclosed combat

---

#### Spells To Magic Missiles

| Stat | Value |
|------|-------|
| Uses | 10 |
| Mana Drain | 100 |
| Cast Delay | +0.83s |
| Recharge Time | +0.83s |

**Description:** "Converts following spells to magic missiles"

**Special Properties:**
- **Transforms spells into Magic Missiles**
- Limited uses (10)
- Moderate mana (100)
- Adds homing and acceleration
- Good damage conversion

---

#### Spells To Nukes

| Stat | Value |
|------|-------|
| Uses | 2 |
| Mana Drain | 600 |
| Cast Delay | +1.67s |
| Recharge Time | +1.67s |

**Description:** "Converts following spells to nukes"

**Special Properties:**
- **Transforms spells into Nukes**
- Only 2 uses
- Extremely high mana (600)
- Long delays
- **Extremely dangerous** - likely self-kill
- Maximum destruction

---

## Projectile Modifier Spells

Modifier spells change the properties of the next projectile spell in the wand. They don't fire on their own - they enhance other spells.

### Damage Modifiers

---

#### Damage Plus

| Stat | Value |
|------|-------|
| Mana Drain | 5 |
| Cast Delay | +0.08s |
| Damage Bonus | +10 projectile |

**Description:** "Increases projectile damage"

**Special Properties:**
- Adds flat +10 damage to projectiles
- Low mana cost (5)
- Small cast delay penalty
- Stacks with multiple copies
- **Key modifier** for damage builds

---

#### Heavy Shot

| Stat | Value |
|------|-------|
| Mana Drain | 7 |
| Cast Delay | +0.17s |
| Damage Bonus | +43.75 |
| Speed Modifier | 0.30x |

**Description:** "Massive damage, much slower"

**Special Properties:**
- **Huge damage boost** (+43.75)
- **Severely reduces speed** (0.30x)
- Higher cast delay (+0.17s)
- Good for slow, hard-hitting builds
- Combine with Speed Up to offset

---

#### Light Shot

| Stat | Value |
|------|-------|
| Mana Drain | 5 |
| Cast Delay | -0.05s |
| Damage Modifier | -10 |
| Speed Modifier | 7.50x |

**Description:** "Less damage, much faster"

**Special Properties:**
- **Massive speed boost** (7.50x)
- Reduces damage by 10
- **Negative cast delay** (-0.05s)
- Great for rapid-fire builds
- Makes projectiles nearly instant

---

#### Critical Plus

| Stat | Value |
|------|-------|
| Mana Drain | 5 |
| Critical Chance | +15% |

**Description:** "Increases critical hit chance"

**Special Properties:**
- Adds flat +15% crit chance
- No cast delay penalty
- Low mana cost (5)
- Stacks with spell's base crit
- Crits deal 5x damage

---

#### Random Damage

| Stat | Value |
|------|-------|
| Mana Drain | 15 |
| Cast Delay | +0.08s |

**Description:** "Random damage modifier"

**Special Properties:**
- Applies **random damage bonus or penalty**
- Unpredictable results
- Higher mana cost (15)
- Can be very good or very bad
- Gamble modifier

---

#### Mana To Damage

| Stat | Value |
|------|-------|
| Mana Drain | 20 |
| Cast Delay | +0.25s |

**Description:** "Converts remaining mana to damage"

**Special Properties:**
- **More mana = more damage**
- Consumes excess mana
- High mana cost (20)
- Great for high-mana wands
- Scales with mana pool

---

#### Bloodlust

| Stat | Value |
|------|-------|
| Mana Drain | 2 |
| Cast Delay | +0.13s |
| Critical Chance | +6% |

**Description:** "Damage increases with kills"

**Special Properties:**
- **Damage stacks with kills**
- Bonus +6% crit
- Very low mana cost (2)
- Rewards aggressive play
- Resets on wand switch

### Speed Modifiers

---

#### Speed Up

| Stat | Value |
|------|-------|
| Mana Drain | 3 |
| Speed Modifier | 2.50x |

**Description:** "Faster projectile"

**Special Properties:**
- **2.5x speed increase**
- Very low mana (3)
- No cast delay penalty
- Essential modifier
- Stacks multiplicatively

---

#### Accelerating Shot

| Stat | Value |
|------|-------|
| Mana Drain | 20 |
| Cast Delay | +0.13s |
| Initial Speed | 0.32x |

**Description:** "Starts slow, accelerates over time"

**Special Properties:**
- Starts at 0.32x speed
- **Accelerates continuously**
- Higher mana (20)
- Good for long-range shots
- Reaches very high speeds

---

#### Decelerating Shot

| Stat | Value |
|------|-------|
| Mana Drain | 10 |
| Cast Delay | -0.13s |
| Initial Speed | 1.68x |

**Description:** "Starts fast, decelerates over time"

**Special Properties:**
- Starts at 1.68x speed
- **Slows down over time**
- **Negative cast delay** (-0.13s)
- Good for close-range burst
- Moderate mana (10)

### Homing Modifiers

---

#### Homing

| Stat | Value |
|------|-------|
| Mana Drain | 70 |

**Description:** "Projectile seeks enemies"

**Special Properties:**
- **Homes toward nearest enemy**
- Accelerates while homing
- High mana cost (70)
- Can loop around obstacles
- Standard homing strength

---

#### Short-range Homing

| Stat | Value |
|------|-------|
| Mana Drain | 40 |

**Description:** "Limited range homing"

**Special Properties:**
- Only homes at **close range**
- Lower mana than full homing (40)
- Good for accuracy boost
- Won't chase distant targets
- More predictable trajectory

---

#### Accelerative Homing

| Stat | Value |
|------|-------|
| Mana Drain | 60 |

**Description:** "Builds speed while homing"

**Special Properties:**
- **Gains speed as it homes**
- Gets faster the longer it chases
- Moderate mana (60)
- Can reach very high speeds
- Aggressive tracking

---

#### Rotate Towards Foes

| Stat | Value |
|------|-------|
| Mana Drain | 40 |

**Description:** "Gradually turns toward enemies"

**Special Properties:**
- **Gentle turn toward targets**
- Doesn't accelerate
- Moderate mana (40)
- More predictable than homing
- Good for wide-spread shots

---

#### Auto-Aim

| Stat | Value |
|------|-------|
| Mana Drain | 25 |

**Description:** "Automatically targets enemies"

**Special Properties:**
- **Aims at enemies on cast**
- Doesn't adjust mid-flight
- Lower mana (25)
- Initial aim correction
- Good for fast projectiles

---

#### Aiming Arc

| Stat | Value |
|------|-------|
| Mana Drain | 30 |

**Description:** "Curved path toward enemies"

**Special Properties:**
- Creates **arcing trajectory**
- Curves toward targets
- Moderate mana (30)
- Can hit behind cover
- Graceful homing style

### Bounce Modifiers

---

#### Bounce

| Stat | Value |
|------|-------|
| Mana Drain | 0 |
| Bounces | +10 |

**Description:** "Adds bounces to projectile"

**Special Properties:**
- **Free modifier** (0 mana)
- Adds 10 bounces
- Essential for bounce builds
- No cast delay
- Can fill rooms with projectiles

---

#### Larpa Bounce

| Stat | Value |
|------|-------|
| Mana Drain | 80 |
| Cast Delay | +0.53s |
| Bounces | +1 |

**Description:** "Spawns projectiles on bounce"

**Special Properties:**
- **Spawns larpa on each bounce**
- Only +1 bounce
- High mana (80)
- Long cast delay
- Creates projectile storms

---

#### Explosive Bounce

| Stat | Value |
|------|-------|
| Mana Drain | 20 |
| Cast Delay | +0.42s |
| Bounces | +1 |

**Description:** "Explodes on bounce"

**Special Properties:**
- **Explosion on each bounce**
- Only +1 bounce
- Moderate mana (20)
- Long cast delay
- Dangerous in enclosed spaces

---

#### Plasma Beam Bounce

| Stat | Value |
|------|-------|
| Mana Drain | 40 |
| Cast Delay | +0.20s |
| Bounces | +1 |

**Description:** "Fires beam on bounce"

**Special Properties:**
- **Plasma beam on bounce**
- Only +1 bounce
- Higher mana (40)
- Moderate cast delay
- Good damage addition

---

#### Concentrated Light Bounce

| Stat | Value |
|------|-------|
| Mana Drain | 30 |
| Cast Delay | +0.20s |
| Bounces | +1 |

**Description:** "Light beam on bounce"

**Special Properties:**
- **Light beam on bounce**
- Only +1 bounce
- Moderate mana (30)
- Precision damage
- Good for tight spaces

---

#### Bubbly Bounce

| Stat | Value |
|------|-------|
| Mana Drain | 13 |
| Cast Delay | +0.13s |
| Bounces | +1 |

**Description:** "Spawns bubbles on bounce"

**Special Properties:**
- **Bubble sparks on bounce**
- Only +1 bounce
- Low mana (13)
- Short cast delay
- Area coverage

---

#### Remove Bounce

| Stat | Value |
|------|-------|
| Mana Drain | 0 |

**Description:** "Removes bounces"

**Special Properties:**
- **Free modifier** (0 mana)
- Removes all bounces
- Useful for piercing builds
- Prevents friendly fire return
- Makes projectiles expire on hit

### Lifetime Modifiers

---

#### Increase Lifetime

| Stat | Value |
|------|-------|
| Mana Drain | 40 |
| Cast Delay | +0.22s |
| Lifetime | +75 frames |

**Description:** "Projectile lasts longer"

**Special Properties:**
- **+75 frames (~1.25 seconds)**
- High mana (40)
- Moderate cast delay
- Essential for long-range
- Stacks for infinite builds

---

#### Reduce Lifetime

| Stat | Value |
|------|-------|
| Mana Drain | 10 |
| Cast Delay | -0.25s |
| Lifetime | -42 frames |

**Description:** "Projectile expires sooner"

**Special Properties:**
- **-42 frames (~0.7 seconds)**
- Low mana (10)
- **Negative cast delay** (-0.25s)
- Key for machine gun builds
- Can make spells infinite

---

#### Nolla

| Stat | Value |
|------|-------|
| Mana Drain | 1 |
| Cast Delay | -0.25s |
| Lifetime | Sets to 1 |

**Description:** "Instant expiration"

**Special Properties:**
- **Sets lifetime to 1 frame**
- Nearly free (1 mana)
- **Negative cast delay** (-0.25s)
- Triggers death effects instantly
- Used for trigger combos

### Path Modifiers

---

#### Boomerang

| Stat | Value |
|------|-------|
| Mana Drain | 10 |

**Description:** "Returns to caster"

**Special Properties:**
- **Projectile returns** after distance
- Low mana (10)
- Can hit twice
- Good for recovery
- **Warning:** Can hit you on return

---

#### Linear Arc

| Stat | Value |
|------|-------|
| Mana Drain | 0 |
| Cast Delay | -0.07s |

**Description:** "Perfectly straight path"

**Special Properties:**
- **Removes gravity/curves**
- Free modifier (0 mana)
- Negative cast delay
- Laser-straight trajectory
- Removes inherited arcs

---

#### Horizontal Path

| Stat | Value |
|------|-------|
| Mana Drain | 0 |
| Cast Delay | -0.10s |

**Description:** "Flies only horizontally"

**Special Properties:**
- **Locks to horizontal**
- Free modifier (0 mana)
- Negative cast delay
- Ignores vertical aim
- Good for sweeping attacks

---

#### Slithering Path

| Stat | Value |
|------|-------|
| Mana Drain | 0 |
| Speed Modifier | 2.00x |

**Description:** "Snake-like movement"

**Special Properties:**
- **Weaving snake pattern**
- Free modifier (0 mana)
- 2x speed bonus
- Can hit targets at angles
- Unpredictable but useful

---

#### Ping-Pong Path

| Stat | Value |
|------|-------|
| Mana Drain | 0 |
| Bounces | +25 |

**Description:** "Zigzag pattern"

**Special Properties:**
- **Zigzag movement** pattern
- Free modifier (0 mana)
- Adds 25 bounces
- Good area coverage
- Fills corridors

---

#### Phasing Arc

| Stat | Value |
|------|-------|
| Mana Drain | 2 |
| Cast Delay | -0.10s |
| Lifetime | +80 frames |
| Speed | 0.33x |

**Description:** "Phases through terrain"

**Special Properties:**
- **Passes through solid terrain**
- Much slower (0.33x speed)
- Longer lifetime (+80)
- Hit enemies through walls
- Very low mana (2)

---

#### Spiral Arc

| Stat | Value |
|------|-------|
| Mana Drain | 0 |
| Cast Delay | -0.10s |
| Lifetime | +50 frames |

**Description:** "Spiraling path"

**Special Properties:**
- **Corkscrew spiral path**
- Free modifier (0 mana)
- Negative cast delay
- Extended lifetime (+50)
- Wide area coverage

---

#### Orbiting Arc

| Stat | Value |
|------|-------|
| Mana Drain | 0 |
| Cast Delay | -0.10s |
| Lifetime | +25 frames |

**Description:** "Orbits around caster"

**Special Properties:**
- **Circles around you**
- Free modifier (0 mana)
- Extended lifetime (+25)
- Defensive use
- Creates shield of projectiles

---

#### Chaotic Path

| Stat | Value |
|------|-------|
| Mana Drain | 0 |
| Speed Modifier | 2.00x |

**Description:** "Random movement"

**Special Properties:**
- **Erratic random movement**
- Free modifier (0 mana)
- 2x speed bonus
- Unpredictable trajectory
- Area denial

---

#### Floating Arc

| Stat | Value |
|------|-------|
| Mana Drain | 0 |
| Cast Delay | +0.17s |

**Description:** "Floats gently"

**Special Properties:**
- **Slow floating movement**
- Free modifier (0 mana)
- Positive cast delay
- Hangs in air
- Good for traps

---

#### Avoiding Arc

| Stat | Value |
|------|-------|
| Mana Drain | 0 |
| Cast Delay | +0.17s |

**Description:** "Avoids terrain"

**Special Properties:**
- **Steers around obstacles**
- Free modifier (0 mana)
- Positive cast delay
- Navigates maze-like areas
- Smart pathfinding

### Gravity Modifiers

---

#### Gravity

| Stat | Value |
|------|-------|
| Mana Drain | 1 |

**Description:** "Adds gravity"

**Special Properties:**
- Makes projectile **fall downward**
- Nearly free (1 mana)
- Creates arcing shots
- Useful for lobbing attacks
- Stacks for heavy drop

---

#### Anti-Gravity

| Stat | Value |
|------|-------|
| Mana Drain | 1 |

**Description:** "Rises upward"

**Special Properties:**
- Makes projectile **rise upward**
- Nearly free (1 mana)
- Creates rising shots
- Good for hitting flying enemies
- Counters natural gravity

---

#### Fly Upwards

| Stat | Value |
|------|-------|
| Mana Drain | 0 |
| Cast Delay | -0.05s |

**Description:** "Flies straight up"

**Special Properties:**
- **Forces upward flight**
- Free modifier (0 mana)
- Negative cast delay
- Ignores aim direction
- Good for rain effects

---

#### Fly Downwards

| Stat | Value |
|------|-------|
| Mana Drain | 0 |
| Cast Delay | -0.05s |

**Description:** "Flies straight down"

**Special Properties:**
- **Forces downward flight**
- Free modifier (0 mana)
- Negative cast delay
- Ignores aim direction
- Good for bombing runs

### Explosion Modifiers

---

#### Explosive Projectile

| Stat | Value |
|------|-------|
| Mana Drain | 30 |
| Cast Delay | +0.67s |
| Radius | +15 |
| Explosion Damage | +1.25 |
| Speed | 0.75x |

**Description:** "Adds explosion to projectile"

**Special Properties:**
- **Adds explosion on impact**
- Larger radius (+15)
- Slight speed reduction
- Long cast delay (+0.67s)
- Has friendly fire

---

#### Concentrated Explosion

| Stat | Value |
|------|-------|
| Mana Drain | 40 |
| Cast Delay | +0.25s |
| Radius | -30 |

**Description:** "Smaller, focused explosion"

**Special Properties:**
- **Reduces explosion radius** (-30)
- Higher damage density
- Moderate mana (40)
- Less terrain destruction
- Safer to use

---

#### Remove Explosion

| Stat | Value |
|------|-------|
| Mana Drain | 0 |
| Cast Delay | -0.25s |
| Radius | -30 |

**Description:** "Removes explosion"

**Special Properties:**
- **Removes explosion component**
- Free modifier (0 mana)
- Negative cast delay
- Keeps impact damage
- No friendly fire from explosion

### Elemental Modifiers

---

#### Freeze Charge

| Stat | Value |
|------|-------|
| Mana Drain | 10 |
| Ice Damage | +5 |

**Description:** "Adds freezing effect"

**Special Properties:**
- **Freezes targets** on hit
- +5 ice damage
- Low mana (10)
- Frozen enemies take massive melee damage
- Freezes liquids

---

#### Electric Charge

| Stat | Value |
|------|-------|
| Mana Drain | 8 |

**Description:** "Adds electric damage"

**Special Properties:**
- **Adds electric damage**
- Low mana (8)
- Stuns enemies
- **Electrifies water**
- Chains through liquids

---

#### Petrify

| Stat | Value |
|------|-------|
| Mana Drain | 10 |

**Description:** "Turns targets to stone"

**Special Properties:**
- **Petrifies enemies**
- Low mana (10)
- Enemies become statues
- Statues can be destroyed
- Removes enemy threat

### Trail Modifiers

---

#### Water Trail

| Stat | Value |
|------|-------|
| Mana Drain | 10 |

**Description:** "Leaves water trail"

**Special Properties:**
- Leaves **water** as projectile travels
- Low mana (10)
- Extinguishes fires
- Conducts electricity
- Cleans stains

---

#### Oil Trail

| Stat | Value |
|------|-------|
| Mana Drain | 10 |

**Description:** "Leaves oil trail"

**Special Properties:**
- Leaves **oil** as projectile travels
- Low mana (10)
- **Highly flammable**
- Sets up fire traps
- Slippery surface

---

#### Fire Trail

| Stat | Value |
|------|-------|
| Mana Drain | 10 |

**Description:** "Leaves fire trail"

**Special Properties:**
- Leaves **fire** as projectile travels
- Low mana (10)
- Ignites enemies and terrain
- Creates burning paths
- **Warning:** Can ignite oil

---

#### Gunpowder Trail

| Stat | Value |
|------|-------|
| Mana Drain | 10 |

**Description:** "Leaves gunpowder trail"

**Special Properties:**
- Leaves **gunpowder** trail
- Low mana (10)
- Explodes when ignited
- Creates explosive paths
- Combine with fire

---

#### Poison Trail

| Stat | Value |
|------|-------|
| Mana Drain | 10 |

**Description:** "Leaves poison trail"

**Special Properties:**
- Leaves **poison** trail
- Low mana (10)
- Damages over time
- Stains enemies
- Area denial

---

#### Acid Trail

| Stat | Value |
|------|-------|
| Mana Drain | 15 |

**Description:** "Leaves acid trail"

**Special Properties:**
- Leaves **acid** trail
- Slightly higher mana (15)
- **Dissolves terrain**
- Damages enemies
- **Warning:** Dissolves ground beneath

---

#### Burning Trail

| Stat | Value |
|------|-------|
| Mana Drain | 5 |

**Description:** "Leaves flame trail"

**Special Properties:**
- Leaves **burning flames**
- Very low mana (5)
- Similar to Fire Trail
- Ignites flammables
- Creates fire paths

---

#### Rainbow Trail

| Stat | Value |
|------|-------|
| Mana Drain | 0 |

**Description:** "Leaves rainbow colors"

**Special Properties:**
- **Purely visual** rainbow
- Free modifier (0 mana)
- No gameplay effect
- Fabulous appearance
- Easter egg modifier

### Arc Modifiers

---

#### Gunpowder Arc

| Stat | Value |
|------|-------|
| Mana Drain | 15 |

**Description:** "Arc of gunpowder"

**Special Properties:**
- Spawns **gunpowder arc** around projectile
- Moderate mana (15)
- Explosive when ignited
- Wide coverage
- Combine with fire spells

---

#### Fire Arc

| Stat | Value |
|------|-------|
| Mana Drain | 15 |

**Description:** "Arc of fire"

**Special Properties:**
- Spawns **fire arc** around projectile
- Moderate mana (15)
- Ignites area
- Wide fire coverage
- **Warning:** Friendly fire

---

#### Poison Arc

| Stat | Value |
|------|-------|
| Mana Drain | 15 |

**Description:** "Arc of poison"

**Special Properties:**
- Spawns **poison arc** around projectile
- Moderate mana (15)
- Poisons large area
- Area denial
- DoT coverage

---

#### Electric Arc

| Stat | Value |
|------|-------|
| Mana Drain | 15 |

**Description:** "Arc of electricity"

**Special Properties:**
- Spawns **electric arc** around projectile
- Moderate mana (15)
- Stuns enemies
- Chains through water
- Wide shock coverage

### Critical Condition Modifiers

---

#### Critical On Burning

| Stat | Value |
|------|-------|
| Mana Drain | 10 |

**Description:** "Critical hits on burning targets"

**Special Properties:**
- **Guaranteed crit** vs burning enemies
- Low mana (10)
- Synergizes with fire spells
- 5x damage on burning
- Essential fire build modifier

---

#### Critical On Oiled Enemies

| Stat | Value |
|------|-------|
| Mana Drain | 10 |

**Description:** "Critical hits on oiled targets"

**Special Properties:**
- **Guaranteed crit** vs oiled enemies
- Low mana (10)
- Synergizes with Oil Trail
- 5x damage on oiled
- Setup required

---

#### Critical On Bloody Enemies

| Stat | Value |
|------|-------|
| Mana Drain | 10 |

**Description:** "Critical hits on bloody targets"

**Special Properties:**
- **Guaranteed crit** vs bloody enemies
- Low mana (10)
- Works on wounded enemies
- 5x damage on bloody
- Combat synergy

---

#### Critical On Wet Enemies

| Stat | Value |
|------|-------|
| Mana Drain | 10 |

**Description:** "Critical hits on wet targets"

**Special Properties:**
- **Guaranteed crit** vs wet enemies
- Low mana (10)
- Synergizes with Water Trail
- 5x damage on wet
- Easy to proc in caves

### Explosion Condition Modifiers

---

#### Explosion On Drunk Enemies

| Stat | Value |
|------|-------|
| Mana Drain | 20 |

**Description:** "Explodes drunk targets"

**Special Properties:**
- **Triggers explosion** on drunk enemies
- Moderate mana (20)
- Requires drunk status
- Chain reaction potential
- Combine with Mist of Spirits

---

#### Giant Explosion On Drunk

| Stat | Value |
|------|-------|
| Mana Drain | 20 |
| Radius | +200 |

**Description:** "Massive explosion on drunk"

**Special Properties:**
- **Huge explosion** (+200 radius) on drunk
- Same mana as regular (20)
- Requires drunk status
- Devastating damage
- **Warning:** Very dangerous

---

#### Explosion On Slimy Enemies

| Stat | Value |
|------|-------|
| Mana Drain | 20 |

**Description:** "Explodes slimy targets"

**Special Properties:**
- **Triggers explosion** on slimy enemies
- Moderate mana (20)
- Requires slime stain
- Synergizes with Slimeball
- Chain reactions

---

#### Giant Explosion On Slimy

| Stat | Value |
|------|-------|
| Mana Drain | 20 |
| Radius | +200 |

**Description:** "Massive explosion on slimy"

**Special Properties:**
- **Huge explosion** (+200 radius) on slimy
- Same mana as regular (20)
- Requires slime stain
- Massive area damage
- Very dangerous

### Piercing & Shield

---

#### Piercing Shot

| Stat | Value |
|------|-------|
| Mana Drain | 140 |
| Damage | -15 |

**Description:** "Passes through enemies"

**Special Properties:**
- **Projectile pierces enemies**
- Reduces damage by 15
- Very high mana (140)
- Hits multiple enemies
- Essential for crowds

---

#### Drilling Shot

| Stat | Value |
|------|-------|
| Mana Drain | 160 |
| Cast Delay | +0.83s |
| Recharge Time | +0.67s |

**Description:** "Drills through terrain"

**Special Properties:**
- **Passes through terrain**
- Very high mana (160)
- Long delays
- Hit enemies through walls
- Powerful but slow

---

#### Projectile Energy Shield

| Stat | Value |
|------|-------|
| Mana Drain | 5 |
| Speed | 0.40x |

**Description:** "Shield around projectile"

**Special Properties:**
- Creates **shield around projectile**
- Very low mana (5)
- Slows projectile (0.40x)
- Blocks enemy projectiles
- Defensive projectile

### Orbit Modifiers

---

#### Fireball Orbit

| Stat | Value |
|------|-------|
| Mana Drain | 40 |

**Description:** "Orbiting fireballs"

**Special Properties:**
- **Fireballs orbit** the main projectile
- Moderate mana (40)
- Extra fire damage
- Creates fire spread
- Good area damage

---

#### Sawblade Orbit

| Stat | Value |
|------|-------|
| Mana Drain | 70 |

**Description:** "Orbiting sawblades"

**Special Properties:**
- **Sawblades orbit** the main projectile
- Higher mana (70)
- Slice damage
- Good vs soft targets
- Creates cutting field

---

#### Plasma Beam Orbit

| Stat | Value |
|------|-------|
| Mana Drain | 100 |

**Description:** "Orbiting plasma beams"

**Special Properties:**
- **Plasma beams orbit** projectile
- High mana (100)
- Continuous beam damage
- Very powerful
- Creates death sphere

---

#### Nuke Orbit

| Stat | Value |
|------|-------|
| Mana Drain | 250 |
| Uses | 3 |

**Description:** "Orbiting nuke"

**Special Properties:**
- **Nuke orbits** the projectile
- Extremely high mana (250)
- Limited uses (3)
- Massive explosion on impact
- **Near-certain death** if close

---

#### Orbit Larpa

| Stat | Value |
|------|-------|
| Mana Drain | 90 |

**Description:** "Orbiting larpa"

**Special Properties:**
- **Larpa projectiles orbit**
- High mana (90)
- Spawns extra projectiles
- Complex patterns
- High damage potential

### Larpa Modifiers

---

#### Upwards Larpa

| Stat | Value |
|------|-------|
| Mana Drain | 120 |
| Cast Delay | +0.25s |

**Description:** "Spawns upward projectiles"

**Special Properties:**
- **Projectiles spawn upward**
- High mana (120)
- Creates rain of spells
- Good for ceilings
- Area coverage

---

#### Downwards Larpa

| Stat | Value |
|------|-------|
| Mana Drain | 120 |
| Cast Delay | +0.25s |

**Description:** "Spawns downward projectiles"

**Special Properties:**
- **Projectiles spawn downward**
- High mana (120)
- Carpet bombing effect
- Good for floors
- Area coverage

---

#### Chaos Larpa

| Stat | Value |
|------|-------|
| Mana Drain | 100 |
| Cast Delay | +0.25s |

**Description:** "Random direction spawns"

**Special Properties:**
- **Projectiles spawn randomly**
- Moderate mana (100)
- Unpredictable coverage
- Fills enclosed spaces
- Chaotic but effective

---

#### Larpa Explosion

| Stat | Value |
|------|-------|
| Mana Drain | 90 |
| Cast Delay | +0.25s |
| Radius | 30 |

**Description:** "Explosions spawn"

**Special Properties:**
- **Spawns explosions** along path
- Moderate mana (90)
- 30 radius explosions
- Trail of destruction
- **Warning:** Friendly fire

### Transmutation Modifiers

---

#### Water To Poison

| Stat | Value |
|------|-------|
| Mana Drain | 30 |
| Cast Delay | +0.17s |

**Description:** "Converts water to poison"

**Special Properties:**
- **Transforms water** to poison
- Moderate mana (30)
- Area effect
- Makes water deadly
- Environmental warfare

---

#### Toxic Sludge To Acid

| Stat | Value |
|------|-------|
| Mana Drain | 50 |
| Cast Delay | +0.17s |

**Description:** "Converts toxic sludge to acid"

**Special Properties:**
- **Transforms toxic sludge** to acid
- Higher mana (50)
- More dangerous result
- Acid dissolves terrain
- Powerful transmutation

---

#### Lava To Blood

| Stat | Value |
|------|-------|
| Mana Drain | 30 |
| Cast Delay | +0.17s |

**Description:** "Converts lava to blood"

**Special Properties:**
- **Transforms lava** to blood
- Moderate mana (30)
- Neutralizes lava
- Creates blood pools
- Safety transmutation

---

#### Blood To Acid

| Stat | Value |
|------|-------|
| Mana Drain | 30 |
| Cast Delay | +0.17s |

**Description:** "Converts blood to acid"

**Special Properties:**
- **Transforms blood** to acid
- Moderate mana (30)
- Creates acid from corpses
- Dissolves terrain
- Combo potential

---

#### Ground To Sand

| Stat | Value |
|------|-------|
| Mana Drain | 70 |
| Cast Delay | +1.00s |
| Uses | 8 |

**Description:** "Converts terrain to sand"

**Special Properties:**
- **Transforms solid terrain** to sand
- High mana (70)
- Long cast delay (+1.00s)
- Limited uses (8)
- Creates falling sand

---

#### Chaotic Transmutation

| Stat | Value |
|------|-------|
| Mana Drain | 80 |
| Cast Delay | +0.33s |
| Uses | 8 |

**Description:** "Random material conversion"

**Special Properties:**
- **Random transmutation**
- High mana (80)
- Unpredictable results
- Limited uses (8)
- Gamble modifier

---

#### Liquid Detonation

| Stat | Value |
|------|-------|
| Mana Drain | 40 |
| Cast Delay | +0.33s |

**Description:** "Explodes liquids"

**Special Properties:**
- **Detonates liquid materials**
- Moderate mana (40)
- Creates explosions from pools
- Chain reactions
- Area control

### Thrower Modifiers

---

#### Fireball Thrower

| Stat | Value |
|------|-------|
| Mana Drain | 110 |
| Uses | 16 |

**Description:** "Spawns fireballs"

**Special Properties:**
- **Continuously spawns fireballs**
- High mana (110)
- Limited uses (16)
- Creates fire streams
- Heavy damage output

---

#### Lightning Thrower

| Stat | Value |
|------|-------|
| Mana Drain | 110 |
| Uses | 16 |

**Description:** "Spawns lightning"

**Special Properties:**
- **Continuously spawns lightning**
- High mana (110)
- Limited uses (16)
- Electric damage
- Stuns enemies

---

#### Tentacler

| Stat | Value |
|------|-------|
| Mana Drain | 110 |
| Uses | 16 |

**Description:** "Spawns tentacles"

**Special Properties:**
- **Continuously spawns tentacles**
- High mana (110)
- Limited uses (16)
- Melee damage allies
- Area control

---

#### Plasma Beam Thrower

| Stat | Value |
|------|-------|
| Mana Drain | 110 |
| Uses | 16 |

**Description:** "Spawns plasma beams"

**Special Properties:**
- **Continuously spawns plasma**
- High mana (110)
- Limited uses (16)
- Continuous damage
- Very powerful

---

#### Two-Way Fireball Thrower

| Stat | Value |
|------|-------|
| Mana Drain | 130 |
| Uses | 20 |

**Description:** "Bidirectional fireballs"

**Special Properties:**
- **Spawns fireballs both directions**
- Higher mana (130)
- More uses (20)
- Double coverage
- Area denial

---

#### Personal Fireball Thrower

| Stat | Value |
|------|-------|
| Mana Drain | 90 |
| Uses | 20 |
| Lifetime | 5000 |

**Description:** "Personal fireball spawner"

**Special Properties:**
- **Attaches to you**
- Lower mana (90)
- Very long lifetime (5000)
- Personal fire aura
- Passive damage

---

#### Personal Lightning Caster

| Stat | Value |
|------|-------|
| Mana Drain | 90 |
| Uses | 20 |
| Lifetime | 5000 |

**Description:** "Personal lightning spawner"

**Special Properties:**
- **Attaches to you**
- Lower mana (90)
- Very long lifetime (5000)
- Personal lightning aura
- Stun aura

---

#### Personal Tentacler

| Stat | Value |
|------|-------|
| Mana Drain | 90 |
| Uses | 20 |
| Lifetime | 5000 |

**Description:** "Personal tentacle spawner"

**Special Properties:**
- **Attaches to you**
- Lower mana (90)
- Very long lifetime (5000)
- Personal melee allies
- Defensive aura

---

#### Personal Gravity Field

| Stat | Value |
|------|-------|
| Mana Drain | 110 |
| Uses | 20 |
| Lifetime | 7200 |

**Description:** "Personal gravity field"

**Special Properties:**
- **Attaches to you**
- Moderate mana (110)
- Very long lifetime (7200)
- Pulls projectiles toward you
- **Defensive/offensive** use

### Curse Modifiers

---

#### Venomous Curse

| Stat | Value |
|------|-------|
| Mana Drain | 30 |

**Description:** "Applies poison curse"

**Special Properties:**
- **Curse damage over time**
- Moderate mana (30)
- Stacking DoT
- Ignores armor
- Long-lasting effect

---

#### Weakening Curse - Projectiles

| Stat | Value |
|------|-------|
| Mana Drain | 50 |
| Vulnerability | +0.25 projectile |

**Description:** "Increases projectile damage taken"

**Special Properties:**
- Target takes **+25% projectile damage**
- Higher mana (50)
- Debuff on hit
- Synergizes with projectile spells
- Team damage boost

---

#### Weakening Curse - Electricity

| Stat | Value |
|------|-------|
| Mana Drain | 50 |
| Vulnerability | +0.25 electric |

**Description:** "Increases electric damage taken"

**Special Properties:**
- Target takes **+25% electric damage**
- Higher mana (50)
- Synergizes with Electric Charge
- Debuff stacking
- Lightning builds

---

#### Weakening Curse - Explosives

| Stat | Value |
|------|-------|
| Mana Drain | 50 |
| Vulnerability | +0.25 explosion |

**Description:** "Increases explosion damage taken"

**Special Properties:**
- Target takes **+25% explosion damage**
- Higher mana (50)
- Synergizes with explosives
- Debuff stacking
- Nuke builds

---

#### Weakening Curse - Melee

| Stat | Value |
|------|-------|
| Mana Drain | 50 |
| Vulnerability | +0.25 melee |

**Description:** "Increases melee damage taken"

**Special Properties:**
- Target takes **+25% melee damage**
- Higher mana (50)
- Synergizes with Tentacle
- Kick damage boost
- Frozen enemy combo

---

#### Charm On Toxic Sludge

| Stat | Value |
|------|-------|
| Mana Drain | 70 |

**Description:** "Charms slimed targets"

**Special Properties:**
- **Charms enemies** covered in slime
- High mana (70)
- Converts enemies to allies
- Requires slime setup
- Powerful control

### Other Modifiers

---

#### Add Mana

| Stat | Value |
|------|-------|
| Mana Drain | -30 (restores) |
| Cast Delay | +0.17s |

**Description:** "Restores mana"

**Special Properties:**
- **Restores 30 mana**
- Positive cast delay
- Enables infinite casts
- Key for mana builds
- Offsets expensive spells

---

#### Reduce Spread

| Stat | Value |
|------|-------|
| Mana Drain | 1 |
| Spread | -60° |

**Description:** "Increases accuracy"

**Special Properties:**
- **-60° spread** reduction
- Nearly free (1 mana)
- Massive accuracy boost
- Essential for shotgun spells
- Stacks for laser accuracy

---

#### Heavy Spread

| Stat | Value |
|------|-------|
| Mana Drain | 2 |
| Cast Delay | -0.12s |
| Recharge Time | -0.25s |
| Spread | 720° |

**Description:** "Massive spread, faster casting"

**Special Properties:**
- **720° spread** (full circle)
- Negative cast delay
- Negative recharge
- Fires in all directions
- Shotgun/area builds

---

#### Knockback

| Stat | Value |
|------|-------|
| Mana Drain | 5 |

**Description:** "Increased knockback"

**Special Properties:**
- **More knockback** on hit
- Low mana (5)
- Pushes enemies away
- Crowd control
- Environmental kills

---

#### Recoil

| Stat | Value |
|------|-------|
| Mana Drain | 5 |

**Description:** "Increased recoil"

**Special Properties:**
- **More recoil** on cast
- Low mana (5)
- Pushes you backward
- Can be used for movement
- Rocket jumping

---

#### Recoil Damper

| Stat | Value |
|------|-------|
| Mana Drain | 5 |

**Description:** "Reduced recoil"

**Special Properties:**
- **Less recoil** on cast
- Low mana (5)
- Stable firing position
- Counters high-recoil spells
- Precision builds

---

#### Reduce Recharge Time

| Stat | Value |
|------|-------|
| Mana Drain | 12 |
| Cast Delay | -0.17s |
| Recharge Time | -0.33s |

**Description:** "Faster wand recharge"

**Special Properties:**
- **-0.33s recharge time**
- Also reduces cast delay
- Moderate mana (12)
- Faster overall casting
- Essential modifier

---

#### Slow But Steady

| Stat | Value |
|------|-------|
| Mana Drain | 0 |
| Cast Delay | +1.50s |

**Description:** "Slow cast, steady aim"

**Special Properties:**
- **Very long cast delay** (+1.50s)
- Free modifier (0 mana)
- Improved accuracy
- For precise shots
- Anti-machine gun

---

#### Light

| Stat | Value |
|------|-------|
| Mana Drain | 1 |

**Description:** "Projectile emits light"

**Special Properties:**
- **Illuminates** projectile path
- Nearly free (1 mana)
- Reveals dark areas
- Visual utility
- No combat effect

---

#### Necromancy

| Stat | Value |
|------|-------|
| Mana Drain | 20 |
| Cast Delay | +0.17s |

**Description:** "Resurrects killed enemies"

**Special Properties:**
- **Resurrects killed enemies** as allies
- Moderate mana (20)
- Converts kills to allies
- Army building
- Chaotic results

---

#### Damage Field

| Stat | Value |
|------|-------|
| Mana Drain | 30 |

**Description:** "Area damage effect"

**Special Properties:**
- Creates **damage field** around projectile
- Moderate mana (30)
- Continuous area damage
- Good for crowds
- Passive damage

---

#### Matter Eater

| Stat | Value |
|------|-------|
| Mana Drain | 120 |
| Uses | 10 |

**Description:** "Consumes terrain"

**Special Properties:**
- **Eats through terrain**
- High mana (120)
- Limited uses (10)
- Creates tunnels
- Powerful digging

---

#### Firecrackers

| Stat | Value |
|------|-------|
| Mana Drain | 15 |

**Description:** "Spawns firecrackers"

**Special Properties:**
- **Spawns firecrackers** on impact
- Low mana (15)
- Extra explosions
- Fun visual effect
- Bonus damage

---

#### Chain Spell

| Stat | Value |
|------|-------|
| Mana Drain | 70 |
| Spread | -5° |
| Lifetime | +10 |
| Speed | -30 |

**Description:** "Chains to more targets"

**Special Properties:**
- **Projectile chains** to nearby enemies
- High mana (70)
- Slight accuracy boost
- Extended lifetime
- Hits multiple targets

---

#### Copy Trail

| Stat | Value |
|------|-------|
| Mana Drain | 150 |
| Cast Delay | +0.33s |

**Description:** "Copies spell along trail"

**Special Properties:**
- **Duplicates spell** along path
- Very high mana (150)
- Creates spell trail
- Multiplication effect
- Powerful but expensive

---

#### Fizzle

| Stat | Value |
|------|-------|
| Mana Drain | 0 |
| Cast Delay | -0.17s |
| Lifetime | 1.20x |

**Description:** "Fizzles out"

**Special Properties:**
- **Extended lifetime** (1.20x)
- Free modifier (0 mana)
- Negative cast delay
- Subtle improvement
- No downsides

---

#### Quantum Split

| Stat | Value |
|------|-------|
| Mana Drain | 10 |
| Cast Delay | +0.08s |

**Description:** "Splits projectile"

**Special Properties:**
- **Splits into multiple** projectiles
- Low mana (10)
- Small cast delay
- Multiplies damage
- Good for single-target

---

#### Projectile Area Teleport

| Stat | Value |
|------|-------|
| Mana Drain | 60 |
| Cast Delay | +0.13s |
| Spread | +6° |
| Lifetime | 0.75x |

**Description:** "Teleports projectile area"

**Special Properties:**
- **Teleports projectile** randomly
- High mana (60)
- Reduced lifetime
- Unpredictable
- Can bypass obstacles

---

#### Earthquake Shot

| Stat | Value |
|------|-------|
| Mana Drain | 45 |
| Uses | 15 |

**Description:** "Terrain destruction"

**Special Properties:**
- **Destroys terrain** on impact
- Moderate mana (45)
- Limited uses (15)
- Creates falling debris
- Area destruction

---

#### Essence To Power

| Stat | Value |
|------|-------|
| Mana Drain | 110 |
| Cast Delay | +0.33s |

**Description:** "Converts essence to damage"

**Special Properties:**
- **Consumes essence** for damage
- High mana (110)
- Scales with collected essence
- Endgame modifier
- High damage potential

---

#### Spells To Power

| Stat | Value |
|------|-------|
| Mana Drain | 110 |
| Cast Delay | +0.33s |

**Description:** "Converts spells to damage"

**Special Properties:**
- **Consumes spell charges** for damage
- High mana (110)
- Uses up limited spells
- High burst damage
- Sacrifices versatility

### Glimmer Modifiers (Visual)

All Glimmer modifiers are **purely visual** with 0 mana cost and -0.13s cast delay.

---

#### Rainbow Glimmer

**Description:** "Rainbow visual effect"
- Cycles through rainbow colors
- Free and reduces cast delay

---

#### Invisible Spell

**Description:** "Makes projectile invisible"
- Projectile cannot be seen
- Enemies still affected

---

#### Blue/Green/Orange/Purple/Red/Yellow Glimmer

**Description:** "Colored visual effect"
- Changes projectile color
- Free and reduces cast delay

### Bolt Bundle Modifiers

---

#### Octagonal Bolt Bundle

| Stat | Value |
|------|-------|
| Mana Drain | 100 |
| Cast Delay | +0.33s |
| Spread | 12° |
| Projectiles | 8 |

**Description:** "8 projectiles in octagon pattern"

**Special Properties:**
- **Spawns 8 projectiles** in octagon
- High mana (100)
- Moderate spread (12°)
- Area coverage
- Multiplies damage

---

#### Downwards Bolt Bundle

| Stat | Value |
|------|-------|
| Mana Drain | 90 |
| Cast Delay | +0.42s |
| Spread | 12° |

**Description:** "Downward pattern"

**Special Properties:**
- **Spawns projectiles downward**
- Moderate mana (90)
- Carpet bombing effect
- Good for aerial attacks
- Longer cast delay

### Random Modifier

---

#### Random Modifier Spell

| Stat | Value |
|------|-------|
| Mana Drain | 20 |

**Description:** "Applies random modifier"

**Special Properties:**
- **Random modifier** applied
- Low mana (20)
- Unpredictable results
- Can be very good or bad
- Gamble modifier

---

## Material Spells

Material spells create, spawn, or manipulate materials in the world. They're essential for environmental manipulation, terrain modification, and setting up elemental combos.

### Basic Material Spells

---

#### Water

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 0 |
| Speed | 129 |
| Lifetime | 360 |
| Cast Delay | -0.25s |
| Recharge | -0.17s |

**Description:** "Shoots water"

**Special Properties:**
- **Free spell** (0 mana, infinite uses)
- **Negative cast delay** and recharge
- Extinguishes fire
- Conducts electricity - **dangerous with electric spells**
- Cleans stains (blood, toxic sludge)
- Synergizes with Freeze Charge to create ice
- Can drown enemies if submerged

---

#### Oil

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 0 |
| Speed | 129 |
| Lifetime | 360 |
| Cast Delay | -0.25s |
| Recharge | -0.17s |

**Description:** "Shoots oil"

**Special Properties:**
- **Free spell** (0 mana, infinite uses)
- **Highly flammable** - ignites easily
- Makes surfaces slippery
- Great for fire trap setups
- Synergizes with Critical on Oiled
- Oil fire burns longer than regular fire
- **Warning:** Can ignite unexpectedly

---

#### Blood

| Stat | Value |
|------|-------|
| Uses | 250 |
| Mana Drain | 0 |
| Speed | 129 |
| Lifetime | 360 |
| Cast Delay | -0.25s |
| Recharge | -0.17s |

**Description:** "Shoots blood"

**Special Properties:**
- Free but **limited uses** (250)
- Synergizes with **Critical on Bloody**
- Attracts some enemies
- Can be used with Vampirism perk for healing
- Stains enemies for crit conditions
- No inherent danger

---

#### Acid

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 0 |
| Speed | 129 |
| Lifetime | 360 |
| Cast Delay | -0.25s |
| Recharge | -0.17s |

**Description:** "Shoots acid"

**Special Properties:**
- **Free spell** (0 mana, infinite uses)
- **Dissolves terrain** and enemies
- Creates new pathways through rock
- **Warning:** Dissolves ground beneath you
- **Warning:** Can damage you on contact
- Most dangerous basic material spell
- Great for digging but risky

---

#### Cement

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 0 |
| Speed | 129 |
| Lifetime | 360 |
| Cast Delay | -0.25s |
| Recharge | -0.17s |

**Description:** "Shoots cement"

**Special Properties:**
- **Free spell** (0 mana, infinite uses)
- **Solidifies into rock** after landing
- Creates platforms and barriers
- Can trap enemies
- Blocks pathways
- Useful for defense and terrain modification
- Safe to use

---

#### Chunk Of Soil

| Stat | Value |
|------|-------|
| Uses | 5 |
| Mana Drain | 15 |
| Speed | 1 |

**Description:** "Throws a chunk of soil"

**Special Properties:**
- **Very limited uses** (5)
- Moderate mana (15)
- Extremely slow projectile
- Creates soil on impact
- Minimal combat use
- More of a terrain tool
- Can fill holes

### Circle of Material Spells

Circle spells create a ring of material around the cast point. Good for area coverage and defensive setups.

---

#### Circle Of Water

| Stat | Value |
|------|-------|
| Uses | 15 |
| Mana Drain | 20 |
| Lifetime | 260 |
| Cast Delay | +0.33s |

**Description:** "Creates a circle of water"

**Special Properties:**
- Creates **ring of water**
- Moderate uses (15)
- Extinguishes fire in area
- Useful for clearing burning terrain
- **Conducts electricity** - combo potential
- Good defensive spell

---

#### Circle Of Oil

| Stat | Value |
|------|-------|
| Uses | 15 |
| Mana Drain | 20 |
| Lifetime | 260 |
| Cast Delay | +0.33s |

**Description:** "Creates a circle of oil"

**Special Properties:**
- Creates **ring of oil**
- Moderate uses (15)
- Sets up fire traps
- **Highly flammable** on ignition
- Good for preparing areas
- Combo with fire spells

---

#### Circle Of Acid

| Stat | Value |
|------|-------|
| Uses | 4 |
| Mana Drain | 40 |
| Lifetime | 260 |
| Cast Delay | +0.33s |

**Description:** "Creates a circle of acid"

**Special Properties:**
- Creates **ring of acid**
- **Very limited uses** (4)
- Higher mana cost (40)
- **Dissolves everything** in the circle
- Area denial
- **Warning:** Can damage you
- Dangerous terrain manipulation

---

#### Circle Of Fire

| Stat | Value |
|------|-------|
| Uses | 15 |
| Mana Drain | 20 |
| Lifetime | 260 |
| Cast Delay | +0.33s |

**Description:** "Creates a circle of fire"

**Special Properties:**
- Creates **ring of fire**
- Moderate uses (15)
- Burns enemies caught inside
- Ignites flammables
- Area denial
- **Warning:** Can burn you
- Synergizes with Critical on Burning

### Sea Spells

Sea spells create massive floods of material. **Very powerful but limited uses.**

---

#### Sea Of Water

| Stat | Value |
|------|-------|
| Uses | 3 |
| Mana Drain | 140 |
| Lifetime | 300 |
| Cast Delay | +0.25s |

**Description:** "Massive flood of water"

**Special Properties:**
- Creates **enormous water flood**
- **Only 3 uses**
- High mana (140)
- Floods entire areas
- Can drown enemies
- Extinguishes massive fires
- **Electricity combo** potential
- Can wash away materials

---

#### Sea Of Oil

| Stat | Value |
|------|-------|
| Uses | 3 |
| Mana Drain | 140 |
| Lifetime | 300 |
| Cast Delay | +0.25s |

**Description:** "Massive flood of oil"

**Special Properties:**
- Creates **enormous oil flood**
- **Only 3 uses**
- High mana (140)
- **EXTREMELY DANGEROUS** if ignited
- Sets up massive fire traps
- Can cover entire biomes in oil
- **Warning:** Area becomes fire hazard

---

#### Sea Of Alcohol

| Stat | Value |
|------|-------|
| Uses | 3 |
| Mana Drain | 140 |
| Lifetime | 300 |
| Cast Delay | +0.25s |

**Description:** "Massive flood of alcohol"

**Special Properties:**
- Creates **enormous alcohol flood**
- **Only 3 uses**
- High mana (140)
- **Gets enemies drunk**
- Synergizes with Explosion on Drunk
- Flammable but burns quickly
- Can enable drunk-based combos

---

#### Sea Of Acid

| Stat | Value |
|------|-------|
| Uses | 3 |
| Mana Drain | 140 |
| Lifetime | 300 |
| Cast Delay | +0.25s |

**Description:** "Massive flood of acid"

**Special Properties:**
- Creates **enormous acid flood**
- **Only 3 uses**
- High mana (140)
- **Dissolves everything** in its path
- Destroys terrain rapidly
- **EXTREMELY DANGEROUS**
- **Warning:** Will dissolve you instantly
- Use with Acid Immunity or from distance

---

#### Sea Of Lava

| Stat | Value |
|------|-------|
| Uses | 3 |
| Mana Drain | 140 |
| Lifetime | 300 |
| Cast Delay | +0.25s |

**Description:** "Massive flood of lava"

**Special Properties:**
- Creates **enormous lava flood**
- **Only 3 uses**
- High mana (140)
- Burns everything
- Ignites all flammables
- Creates permanent fire hazard
- **Warning:** Instant death on contact
- Use with Fire Immunity

---

#### Sea Of Flammable Gas

| Stat | Value |
|------|-------|
| Uses | 3 |
| Mana Drain | 140 |
| Lifetime | 300 |
| Cast Delay | +0.25s |

**Description:** "Massive cloud of flammable gas"

**Special Properties:**
- Creates **enormous gas cloud**
- **Only 3 uses**
- High mana (140)
- **Explodes violently** when ignited
- Fills enclosed spaces
- **MASSIVE explosion potential**
- **Warning:** Single spark = inferno
- Use with extreme caution

### Touch Of Spells

**CRITICAL WARNING: Touch spells cause INSTANT DEATH if cast directly!** The "touch" transforms the caster unless cast at distance. Always use with Trigger spells, Long-Distance Cast, or other delivery methods.

---

#### Touch Of Blood

| Stat | Value |
|------|-------|
| Uses | 3 |
| Mana Drain | 270 |
| Lifetime | 4 |

**Description:** "Transforms target to blood"

**Special Properties:**
- **Transmutes target to blood**
- **Only 3 uses**
- Very high mana (270)
- **INSTANT DEATH** if self-cast
- Destroys terrain/enemies completely
- Combo: Touch of Blood + Vampirism = **infinite healing**
- Must use trigger or distance cast

---

#### Touch Of Gold

| Stat | Value |
|------|-------|
| Uses | 1 |
| Mana Drain | 300 |
| Lifetime | 4 |

**Description:** "Transforms target to gold"

**Special Properties:**
- **Transmutes target to gold**
- **Only 1 use** - extremely rare
- Highest mana (300)
- **INSTANT DEATH** if self-cast
- Converts terrain/enemies to gold nuggets
- **Free gold** from everything
- Must use trigger or distance cast

---

#### Touch Of Oil

| Stat | Value |
|------|-------|
| Uses | 5 |
| Mana Drain | 260 |
| Lifetime | 4 |

**Description:** "Transforms target to oil"

**Special Properties:**
- **Transmutes target to oil**
- Limited uses (5)
- Very high mana (260)
- **INSTANT DEATH** if self-cast
- Creates oil from anything
- Can set up massive fire traps
- Must use trigger or distance cast

---

#### Touch Of Smoke

| Stat | Value |
|------|-------|
| Uses | 5 |
| Mana Drain | 230 |
| Lifetime | 4 |

**Description:** "Transforms target to smoke"

**Special Properties:**
- **Transmutes target to smoke**
- Limited uses (5)
- High mana (230)
- **INSTANT DEATH** if self-cast
- Target simply vanishes into smoke
- Clears obstacles
- Must use trigger or distance cast

---

#### Touch Of Spirits

| Stat | Value |
|------|-------|
| Uses | 5 |
| Mana Drain | 240 |
| Lifetime | 4 |

**Description:** "Transforms target to alcohol"

**Special Properties:**
- **Transmutes target to alcohol**
- Limited uses (5)
- High mana (240)
- **INSTANT DEATH** if self-cast
- Creates alcohol from anything
- Synergizes with Explosion on Drunk
- Must use trigger or distance cast

---

#### Touch Of Water

| Stat | Value |
|------|-------|
| Uses | 5 |
| Mana Drain | 280 |
| Lifetime | 4 |

**Description:** "Transforms target to water"

**Special Properties:**
- **Transmutes target to water**
- Limited uses (5)
- Very high mana (280)
- **INSTANT DEATH** if self-cast
- Converts anything to water
- Can flood areas
- Must use trigger or distance cast

### Touch Spell Safety Guide

**How to safely use Touch spells:**

1. **Spark Bolt with Trigger** + Touch Of X
   - Spark Bolt travels, triggers Touch on impact

2. **Long-Distance Cast** + Touch Of X
   - Casts Touch at range instead of on self

3. **Timer spells** + Touch Of X
   - Delays Touch until projectile is away from you

4. **Any projectile trigger** + Touch Of X
   - Arrow, Magic Bolt, etc. can carry Touch spells

**Vampirism Combo:**
Touch of Blood + Vampirism perk = Standing in the created blood **heals you infinitely**. One of the strongest healing combos in the game.

---

## Multicast Spells

Multicast spells are **the most important spells in the game** for wand building. They allow casting multiple spells simultaneously, and critically, **modifiers applied before or within a multicast affect ALL spells at no extra mana cost**.

### Tuple Spells (Standard Multicast)

These cast multiple spells simultaneously in the same direction. The most fundamental wand building blocks.

---

#### Double Spell

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 0 |
| Spells Cast | 2 |

**Description:** "Casts 2 spells simultaneously"

**Special Properties:**
- **Completely free** (0 mana, infinite uses)
- Casts the next 2 spells together
- **Modifiers before it affect both spells**
- Foundation of most wand builds
- Can be chained with other multicasts
- Essential spell - never discard

---

#### Triple Spell

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 2 |
| Spells Cast | 3 |

**Description:** "Casts 3 spells simultaneously"

**Special Properties:**
- Nearly free (2 mana)
- Casts the next 3 spells together
- **Modifiers before it affect all three spells**
- Great value for mana spent
- Often better than Double Spell

---

#### Quadruple Spell

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 5 |
| Spells Cast | 4 |

**Description:** "Casts 4 spells simultaneously"

**Special Properties:**
- Low cost (5 mana) for 4 spells
- **Modifiers affect all four spells**
- Great damage multiplication
- Enables powerful burst builds
- Still very mana efficient

---

#### Octuple Spell

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 30 |
| Spells Cast | 8 |

**Description:** "Casts 8 spells simultaneously"

**Special Properties:**
- Moderate cost (30 mana) for 8 spells
- **Modifiers affect all eight spells**
- Found in **Coral Chest** (rare)
- Massive damage potential
- Requires high-capacity wand
- Less common but very powerful

---

#### Myriad Spell

| Stat | Value |
|------|-------|
| Uses | 30 |
| Mana Drain | 50 |
| Spells Cast | All remaining |

**Description:** "Casts all remaining spells at once"

**Special Properties:**
- **Limited uses** (30)
- Higher cost (50 mana)
- **Casts EVERY remaining spell on wand**
- Devastating burst damage
- Consumes entire wand in one cast
- Best for high-capacity wands with many spells

### Scatter Spells (Spread Multicast)

Scatter spells cast multiple spells with added spread, creating a shotgun-like effect. Good for coverage but less accurate.

---

#### Double Scatter Spell

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 0 |
| Spells Cast | 2 |
| Spread | +10° |

**Description:** "Casts 2 spells with spread"

**Special Properties:**
- **Completely free** (0 mana)
- Adds 10° spread between projectiles
- Shotgun-like effect
- Good for close range
- Less accurate than Double Spell

---

#### Triple Scatter Spell

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 1 |
| Spells Cast | 3 |
| Spread | +20° |

**Description:** "Casts 3 spells with spread"

**Special Properties:**
- Nearly free (1 mana)
- Adds 20° spread between projectiles
- Wider coverage area
- Good for crowd control
- Combine with Reduce Spread for accuracy

---

#### Quadruple Scatter Spell

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 2 |
| Spells Cast | 4 |
| Spread | +40° |

**Description:** "Casts 4 spells with spread"

**Special Properties:**
- Low cost (2 mana)
- Adds 40° spread - very wide
- Room-clearing capability
- Less useful at range
- Combine with Reduce Spread if needed

### Formation Spells

Formation spells cast projectiles in specific geometric patterns. Useful for covering angles and creating unique attack patterns.

---

#### Formation - Behind Your Back

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 0 |

**Description:** "Also casts behind you"

**Special Properties:**
- **Completely free** (0 mana)
- Casts one spell **backwards**
- Good for retreating combat
- Can hit enemies chasing you
- Defensive formation

---

#### Formation - Above And Below

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 3 |

**Description:** "Casts vertically"

**Special Properties:**
- Low cost (3 mana)
- Casts spells **up and down**
- Vertical coverage
- Good in shafts and tunnels
- Hits flying enemies above

---

#### Formation - Pentagon

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 5 |

**Description:** "5-point star pattern"

**Special Properties:**
- Moderate cost (5 mana)
- **5 directions** in pentagon
- 360° coverage
- Area denial
- Defensive use

---

#### Formation - Hexagon

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 6 |

**Description:** "6-point star pattern"

**Special Properties:**
- Moderate cost (6 mana)
- **6 directions** in hexagon
- Even better 360° coverage
- Slightly denser than Pentagon
- Great for surrounded situations

---

#### Formation - Bifurcated

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 2 |

**Description:** "Splits into 2 directions"

**Special Properties:**
- Low cost (2 mana)
- **V-shape split**
- Forward-angled projectiles
- Good spread coverage
- Cone-like attack pattern

---

#### Formation - Trifurcated

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 3 |

**Description:** "Splits into 3 directions"

**Special Properties:**
- Low cost (3 mana)
- **Trident-shape split**
- Forward and angled projectiles
- Wider coverage than Bifurcated
- Classic shotgun pattern

### How Multicast Works

**The Key Mechanic:**
- **Modifiers BEFORE a multicast affect ALL spells in that multicast**
- Example: Heavy Shot + Double Spell + Spark Bolt + Spark Bolt = Both bolts get Heavy Shot
- This applies damage modifiers, speed modifiers, trails, EVERYTHING

**Multicast Chaining:**
- You can chain multicasts: Double Spell + Triple Spell = 5 spells cast
- Or: Quadruple Spell + Double Spell + Double Spell = 8 spells cast
- Complex chains enable extreme damage

**Mana Efficiency:**
- One modifier affecting 8 spells via Octuple = 8x value
- This is why multicast spells are considered the most important
- Always think: "How can I make one modifier affect more spells?"

---

## Other Spells

This category contains specialized spells that don't fit other categories: trigger additions, divide spells, Greek letter spells, music spells, random spells, conditional logic, and unique special spells.

### Trigger/Timer Addition

These spells add triggering behavior to other spells, enabling complex spell combos.

---

#### Add Trigger

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 10 |

**Description:** "Adds collision trigger to spell"

**Special Properties:**
- Makes next spell **trigger on collision**
- Low mana (10)
- The triggered spell casts its payload
- Essential for Touch spell safety
- Enables combo deliveries
- Works with any projectile

---

#### Add Timer

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 20 |

**Description:** "Adds timer trigger to spell"

**Special Properties:**
- Makes next spell **trigger after delay**
- Moderate mana (20)
- Timer based on spell's lifetime
- Good for delayed detonations
- Useful for timed combos
- Can create mine-like effects

---

#### Add Expiration Trigger

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 20 |

**Description:** "Adds death trigger to spell"

**Special Properties:**
- Makes next spell **trigger on expiration**
- Moderate mana (20)
- Activates when projectile naturally expires
- Combines with Nolla for instant triggers
- Creates endpoint explosions
- Good for timed area control

### Divide Spells

Divide spells create copies of the affected spell. Powerful for damage multiplication but expensive.

---

#### Divide By 2

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 35 |
| Cast Delay | +0.33s |

**Description:** "Splits into 2 copies"

**Special Properties:**
- Creates **2 copies** of next spell
- Moderate mana (35)
- Positive cast delay
- Simple multiplication
- Good for doubling damage

---

#### Divide By 3

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 50 |
| Cast Delay | +0.58s |

**Description:** "Splits into 3 copies"

**Special Properties:**
- Creates **3 copies** of next spell
- Higher mana (50)
- Longer cast delay
- Triple damage potential
- More expensive per copy

---

#### Divide By 4

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 70 |
| Cast Delay | +0.83s |

**Description:** "Splits into 4 copies"

**Special Properties:**
- Creates **4 copies** of next spell
- High mana (70)
- Long cast delay
- Quadruple damage
- Significant slowdown

---

#### Divide By 10

| Stat | Value |
|------|-------|
| Uses | 5 |
| Mana Drain | 200 |
| Cast Delay | +1.33s |
| Recharge | +0.33s |

**Description:** "Splits into 10 copies"

**Special Properties:**
- Creates **10 copies** of next spell
- **Very limited uses** (5)
- Extremely high mana (200)
- Very long cast delay
- Massive damage multiplication
- Rare and powerful

### Greek Letter Spells

Greek letter spells are advanced wand-building tools that manipulate spell order, create copies, and enable complex trigger chains. These are for advanced players.

---

#### Alpha

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 30 |
| Cast Delay | +0.25s |

**Description:** "Casts first spell in wand"

**Special Properties:**
- **Jumps to first spell** in wand
- Moderate mana (30)
- Creates loops
- Enables infinite cast builds
- Advanced wand mechanic

---

#### Gamma

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 30 |
| Cast Delay | +0.25s |

**Description:** "Casts third spell in wand"

**Special Properties:**
- **Jumps to third spell** in wand
- Moderate mana (30)
- Skips spells
- Creates non-linear casting
- Precise control

---

#### Tau

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 80 |
| Cast Delay | +0.58s |

**Description:** "Delayed execution"

**Special Properties:**
- **Delays spell execution**
- Higher mana (80)
- Creates timing gaps
- Advanced combo setup
- Temporal manipulation

---

#### Sigma

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 120 |
| Cast Delay | +0.50s |

**Description:** "Sum/accumulation effect"

**Special Properties:**
- **Accumulates spell effects**
- High mana (120)
- Stacks spell properties
- Advanced wand building
- Creates powerful combos

---

#### Phi

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 120 |
| Cast Delay | +0.83s |

**Description:** "Golden ratio effect"

**Special Properties:**
- **Special ratio-based effect**
- High mana (120)
- Long cast delay
- Mathematical spell behavior
- Unique projectile patterns

---

#### Zeta

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 10 |

**Description:** "Variable effect"

**Special Properties:**
- **Variable spell effect**
- Low mana (10)
- Changes behavior
- Unpredictable results
- Experimental spell

---

#### Mu

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 120 |
| Cast Delay | +0.83s |

**Description:** "Multiplier effect"

**Special Properties:**
- **Multiplies spell effects**
- High mana (120)
- Long cast delay
- Damage multiplication
- Stacks with other modifiers

---

#### Omega

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 300 |
| Cast Delay | +0.83s |

**Description:** "Final/ultimate effect"

**Special Properties:**
- **Ultimate spell effect**
- Very high mana (300)
- Long cast delay
- Most powerful Greek spell
- Endgame wand building

### Note Spells (Kantele)

Kantele note spells are **musical projectiles** that deal minor damage but have unique interactions. They're obtained from the Kantele instrument.

---

#### Kantele Notes (A, D, D+, E, G)

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 1 |
| Speed | 350 |
| Lifetime | 2 |
| Cast Delay | +0.25s |

**Description:** "Musical note projectile"

**Special Properties:**
- **Plays musical note** on cast
- Very low mana (1 each)
- Fast projectiles (350)
- Very short lifetime (2)
- Primarily for music/fun
- Can be used as cheap projectiles
- 5 different notes available

### Note Spells (Ocarina)

Ocarina note spells are similar to Kantele but with more notes. Obtained from the Ocarina.

---

#### Ocarina Notes (A, B, C, D, E, F, G+, A2)

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 1 |
| Speed | 350 |
| Lifetime | 2 |
| Cast Delay | +0.25s |

**Description:** "Musical note projectile"

**Special Properties:**
- **Plays musical note** on cast
- Very low mana (1 each)
- Fast projectiles (350)
- Very short lifetime (2)
- 8 different notes available
- Can play melodies
- Easter egg: specific songs have effects

### Random Spells

Random spells introduce unpredictability. Can be very powerful or backfire spectacularly.

---

#### Random Spell

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 5 |

**Description:** "Casts a random spell"

**Special Properties:**
- **Casts ANY spell randomly**
- Low mana (5)
- Can cast rare spells
- **Warning:** Can cast dangerous spells
- Unpredictable results
- Gamble spell

---

#### Copy Random Spell

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 20 |

**Description:** "Copies a random spell from wand"

**Special Properties:**
- **Copies random spell from YOUR wand**
- Moderate mana (20)
- More controlled than Random Spell
- Uses your existing spells
- Good for wand variety

---

#### Copy Random Spell Thrice

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 50 |

**Description:** "Copies a random spell 3 times"

**Special Properties:**
- **Copies same random spell 3x**
- Higher mana (50)
- Triple cast of one random spell
- Can create powerful bursts
- Same spell each time

---

#### Copy Three Random Spells

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 40 |

**Description:** "Copies 3 different random spells"

**Special Properties:**
- **Copies 3 DIFFERENT random spells**
- Moderate mana (40)
- More variety than Thrice
- Each spell different
- Higher chaos potential

### Requirement Spells (Conditional)

Requirement spells add **conditional logic** to wands. They only cast subsequent spells when conditions are met. Advanced wand building tools.

---

#### Requirement - Projectile Spells

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 0 |

**Description:** "Next must be a projectile"

**Special Properties:**
- **Free** (0 mana)
- Only casts if next is projectile type
- Filters spell types
- Prevents modifier waste
- Wand logic building

---

#### Requirement - Low Health

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 0 |

**Description:** "Activates when HP is low"

**Special Properties:**
- **Free** (0 mana)
- Only casts **when you're hurt**
- Defensive spell trigger
- Enables emergency spells
- "When hurt, cast healing" builds

---

#### Requirement - Enemies

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 0 |

**Description:** "Activates when enemies nearby"

**Special Properties:**
- **Free** (0 mana)
- Only casts **when enemies are near**
- Combat awareness
- Conserves expensive spells
- Automatic combat mode

---

#### Requirement - Every Other

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 0 |

**Description:** "Alternates between casts"

**Special Properties:**
- **Free** (0 mana)
- **Alternates on/off** each cast
- Creates A-B-A-B patterns
- Useful for variety
- Rhythm-based casting

---

#### Requirement - Otherwise

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 0 |

**Description:** "Else condition"

**Special Properties:**
- **Free** (0 mana)
- **If previous requirement failed**, cast this
- Creates if-else logic
- Fallback spell casting
- Complex wand logic

---

#### Requirement - Endpoint

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 0 |

**Description:** "Ends requirement chain"

**Special Properties:**
- **Free** (0 mana)
- **Terminates requirement logic**
- Closes conditional block
- Returns to normal casting
- Structure spell

### Special Spells

Unique spells with powerful or unusual effects.

---

#### Spell Duplication

| Stat | Value |
|------|-------|
| Uses | ∞ |
| Mana Drain | 250 |
| Cast Delay | +0.33s |
| Recharge | +0.33s |

**Description:** "Duplicates the next spell"

**Special Properties:**
- **Creates permanent copy** of next spell
- Extremely high mana (250)
- Adds delays
- Valuable for duplicating rare spells
- Generates new spell for your wand
- One of the most valuable spells

---

#### Summon Portal

| Stat | Value |
|------|-------|
| Uses | 8 |
| Mana Drain | 90 |
| Cast Delay | -0.33s |
| Recharge | +1.0s |

**Description:** "Creates a portal"

**Special Properties:**
- **Creates teleportation portal**
- Limited uses (8)
- High mana (90)
- **Negative cast delay** bonus
- Creates portal pair for fast travel
- Useful for escape

---

#### The End Of Everything

| Stat | Value |
|------|-------|
| Uses | 1 |
| Mana Drain | 600 |
| Cast Delay | +1.67s |
| Recharge | +1.67s |

**Description:** "Ultimate destruction"

**Special Properties:**
- **ONLY 1 USE** - extremely rare
- Highest mana cost (600)
- Very long delays
- **Destroys EVERYTHING** in massive radius
- **Will kill you** without immunity
- Endgame spell
- Use with extreme caution

---

## Key Mechanics

### Wand Stats

| Stat | Description |
|------|-------------|
| **Shuffle** | If yes, spells cast in random order |
| **Spells/Cast** | Number of spells cast per click |
| **Cast Delay** | Time between individual spell casts |
| **Recharge Time** | Time to reload after all spells cast |
| **Mana** | Current/max mana pool |
| **Mana Charge Speed** | Mana regeneration rate |
| **Capacity** | Maximum spells the wand can hold |
| **Spread** | Base accuracy deviation in degrees |

### Terminal Velocity

Most projectiles cap at ~1000 px/s. Notable exceptions:
- **Lightning Bolt** - Ignores cap, extreme speed/range possible
- **Luminous Drill** - Already at 1400 px/s max speed

### Trigger vs Timer

| Type | Behavior |
|------|----------|
| **Trigger** | Casts payload spell on collision with enemy/terrain |
| **Timer** | Casts payload spell after fixed delay (timer duration) |
| **Death Trigger** | Casts payload when projectile expires naturally |
| **Double Trigger** | Casts TWO payload spells on collision |

### Critical Hits

- Base critical hits deal **5x damage**
- Critical chance over 100% adds bonus damage (115% = 575% damage)
- Some spells have innate critical chance bonuses
- Critical Plus modifier adds +15%
- Condition modifiers (Crit on Burning, etc.) grant 100% crit vs affected targets

### Explosion Damage Display Bug

Explosion damage shown on spell cards is often displayed **4x higher** than actual damage. This affects:
- `<config_explosion>` damage values in projectiles
- Does NOT affect `c.damage_explosion_add` from modifiers

Example: Nuke shows 1000 damage but actually deals 250.

### Friendly Fire

Spells with friendly fire enabled can damage the caster. Common sources:
- Healing spells (intentional - for self-healing)
- Piercing Shot
- Lightning Bolt (via water electrification)
- Most beam weapons
- Glowing Lance

### Infinite Lifetime Spells

Certain spell combinations can create infinite lifetime projectiles:
- Spark Bolt + Reduce Lifetime (sets lifetime to specific calculation result)
- Bouncing Burst with specific modifiers
- See Guide To Infinite Lifetime Spells for detailed mechanics

### Digging Strength

Materials have durability ratings. Higher digging strength = better excavation:
- Basic spells: ~8 (can dig soft materials)
- Plasma Beam: 11 (digs through most things)
- Luminous Drill: Penetrates ANY solid

---

## Sources

- [Noita Wiki (wiki.gg) - Spell Information Table](https://noita.wiki.gg/wiki/Spell_Information_Table)
- [Noita Fandom Wiki - Spells](https://noita.fandom.com/wiki/Spells)
- [Noita Fandom Wiki - Spell Information Table](https://noita.fandom.com/wiki/Spell_Information_Table)
- [Noita Fandom Wiki - Damage Types](https://noita.fandom.com/wiki/Damage_Types)
