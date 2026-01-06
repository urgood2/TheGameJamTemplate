# Path of Achra: Religions Reference

## Overview

Religion is one of the three primary character creation choices. Each of the 24 religions provides:
- **Starting Stats** - Small stat bonuses
- **Passive Abilities** - Triggered effects that define playstyle
- **Three Prayers** - Active abilities with charge mechanics
- **Divine Intervention** - Emergency mechanic when Life reaches 0

---

## Prayer System Mechanics

### Charge System
- Each prayer has a **max charge count** (varies per prayer)
- Prayers unlock progressively: Prayer I (start), Prayer II (Glory 10), Prayer III (Glory 20)
- Each prayer has a unique **charge condition** (on kill, on entrance, etc.)
- Using a prayer **consumes all charges** or a specific amount

### Divine Intervention
When Life reaches 0 with at least one fully-charged prayer:
1. Life restored to 25% of max (50% for Apophis worshippers)
2. One random fully-charged prayer is drained
3. Triggers all "on divine intervention" effects

---

## Religion Categories

### Combat-Focused Religions (Damage/Attack)

#### Humbaba - Blood Rage Warrior
**Theme**: Bloodrage amplification and healing through kills

| Stat | Bonus |
|------|-------|
| STR | +2 |
| DEX | +2 |

**Passive Abilities**:
- On entrance: Apply 2 Bloodrage to yourself
- On kill: Heal 10

| Prayer | Max Charges | Effect | Recharge |
|--------|-------------|--------|----------|
| Sum Uri | 2 | Apply 5 Bloodrage, remove Bleed, convert to Bloodrage | On kill while Bloodrage active |
| Ur Halhala | 5 | Deal Blood damage AoE (2 tiles), add charge to Sum Uri | On entrance (+2) |
| Ur Damu | 5 | Heal 25% max Life, apply 10 Bleed to self | On entrance (+2) |

**Survivors-Like Translation**: Self-damage stacking builds, heal-on-kill sustain

---

#### Hadad - Storm & Fire Dancer
**Theme**: Lightning + Fire damage through pure combat

| Stat | Bonus |
|------|-------|
| Speed | +5 |

**Passive Abilities**:
- On attack, per fully-charged prayer: Deal 30 Lightning + 30 Fire damage to enemy in 4 tile range, apply 2 Charge

| Prayer | Max Charges | Effect | Recharge |
|--------|-------------|--------|----------|
| Nesh Ti | 3 | Uses all charges, heal 200 per charge, remove Scorch | On entrance (+1) |
| Nesh Zatu | 1 | Deal 200 Fire+Lightning to 5 enemies, repeat per Nesh Ti charges | On entrance (+1) |
| Nesh Girra | 6 | Uses all charges, deal Fire+Lightning to adjacent units per Nesh Ti charge | On attack (+1) |

**Survivors-Like Translation**: Prayer charge synergies, combo system

---

#### Dorok - Stoic Tank
**Theme**: Perseverance through injury, Poise stacking

| Stat | Bonus |
|------|-------|
| Life | +100 |
| STR | +3 |

**Passive Abilities**:
- On being attacked: Apply 3 Poise to yourself

| Prayer | Max Charges | Effect | Recharge |
|--------|-------------|--------|----------|
| Grim Contemplation | 10 | Heal 20% max Life, remove all non-Poise effects, each charge grants +10 Armor/Block | On entrance (+1) |
| Sober Punishment | 10 | Deal Blunt damage to furthest enemy = missing Life | On damage taken (+1), on heal (-1) |
| Rigid Violence | 1 | Extra attack per point of Inflexibility | On adjacent enemy game turn |

**Survivors-Like Translation**: Damage-taken scaling, low-health power spike

---

#### Tengri - Speed Assassin
**Theme**: Speed conversion to offensive power

| Stat | Bonus |
|------|-------|
| Speed | +10 |

**Passive Abilities**:
- Per point of Speed: -10 Armor, -10 Block, +10 Dodge
- On step: Deal Slash damage (2 x Speed) to enemy in 3 tile range

| Prayer | Max Charges | Effect | Recharge |
|--------|-------------|--------|----------|
| Hurah | 7 | Heal 5 x Speed | On kill (+1) |
| Yirah | 3 | Remove Entangle/Freeze/Sickness | On dodge (+1) |
| Salem | 5 | Deal Slash damage (50 x Speed) AoE 2 tiles | On step adjacent to enemy (+1), on hit (-1) |

**Survivors-Like Translation**: Glass cannon, movement-based damage

---

### Summoner Religions

#### Formus - Ant Army
**Theme**: Swarm summoning

| Stat | Bonus |
|------|-------|
| Life | +25 |
| STR | +1 |
| WIL | +1 |

**Passive Abilities**:
- On game turn/entrance (if enemies live): Summon random Ant familiar

| Prayer | Max Charges | Effect | Recharge |
|--------|-------------|--------|----------|
| Turba | 1 | Per allied Ant, summon another random Ant | On entrance (+1) |
| Spera | 5 | Grant +10 Speed and +100 Hit to allies | On adjacent ally damaged (+1) |
| Viva Formica | 30 | Summon a random Ant familiar | On Ant kill (+1) |

**Survivors-Like Translation**: Minion swarm scaling

---

#### Eresh - Necromancer
**Theme**: Ally death benefits, item synergy

| Stat | Bonus |
|------|-------|
| Life | +75 |

**Passive Abilities**:
- On ally death: Heal and deal Death damage = 5 x number of items in bag

| Prayer | Max Charges | Effect | Recharge |
|--------|-------------|--------|----------|
| Gibija | 5 | Summon 5 Slouching Dead | On entrance (+1) |
| Sluga | 1 | Summon 1 Slouching Dead | On enemy death in 2 tile range (+1) |
| Razaranja | 5 | Summon Mouth of Eresh, apply 25 Doom to self | On Glory rise (+1) |

**Survivors-Like Translation**: Minion death cycling, inventory synergy

---

#### Ikshana - Prisma Summoner
**Theme**: Colored prismatic summons

| Stat | Bonus |
|------|-------|
| WIL | +2 |

**Passive Abilities**:
- +20 summon limit

| Prayer | Max Charges | Effect | Recharge |
|--------|-------------|--------|----------|
| Eranya | 5 | Summon 2 Teal Prismas | On step if not adjacent to enemy (+1) |
| Omranya | 6 | Summon 4 Topaz Prismas | On entrance (+2) |
| Anranya | 5 | Summon 1 Garnet Prisma | On step if not adjacent to enemy (+1) |

**Survivors-Like Translation**: Positioning-based summon management

---

### Transformation Religions

#### Azhdaha - Dragon Form
**Theme**: Drakeform transformation

| Stat | Bonus |
|------|-------|
| Life | +50 |
| WIL | +2 |

**Passive Abilities**:
- On prayer: Apply 5 Drakeform to yourself

| Prayer | Max Charges | Effect | Recharge |
|--------|-------------|--------|----------|
| Proso Drow | 1 | Heal 500 | On entrance (+1) |
| Proso Moc | 1 | Deal damage (100 x Drakeform stacks) AoE 3 tiles, main-hand type | On entrance (+1) |
| Proso Miana | 5 | Apply 5 Drakeform, remove all harmful effects | On recite Proso Moc (+1) |

**Survivors-Like Translation**: Transformation stacking for damage multiplier

---

### Elemental/Magic Religions

#### Mehtar - Ice & Dreams
**Theme**: Dream stacking, phantom summons

| Stat | Bonus |
|------|-------|
| WIL | +3 |

**Passive Abilities**:
- On prayer/game turn: Apply 1 Dream, summon Phantasm, deal 10 damage to enemy (repeat per Dream stack, max 5)

| Prayer | Max Charges | Effect | Recharge |
|--------|-------------|--------|----------|
| Het Dorova | 3 | Heal 20 per Dream stack, remove Freeze | On entrance (+3) |
| Va Tyrana | 4 | Double current Dream stacks | On entrance (+2) |
| Ra Muruga | 10 | Deal Ice+Psychic damage = 10 x Dream stacks AoE 4 tiles | On entrance (+2) |

**Survivors-Like Translation**: Stack multiplication mechanic

---

#### Agara - Elemental Sorcerer
**Theme**: Four-element magic (Astral, Lightning, Fire, Ice)

| Stat | Bonus |
|------|-------|
| WIL | +3 |

**Passive Abilities**:
- On prayer: Perform all "stand still" actions
- On stand still/being hit: Deal 30 Astral/Lightning/Fire/Ice damage AoE 2 tiles

| Prayer | Max Charges | Effect | Recharge |
|--------|-------------|--------|----------|
| Ag' Auzom | 3 | Deal 100 Astral + 100 Lightning to enemy at any range | On entrance (+2) |
| Ag' Ragna | 3 | Deal 500 Fire + 500 Ice to adjacent units | On entrance (+2) |
| Ag' Agara | 6 | Add 1 charge to Ag' Auzom and Ag' Ragna | On entrance (+3) |

**Survivors-Like Translation**: Multi-element damage, prayer combo system

---

#### The Worm - Psychic Corrosion
**Theme**: Corrosion aura damage

| Stat | Bonus |
|------|-------|
| WIL | +2 |

**Passive Abilities**:
- On enemy step/attack (if Du' Eird not full): Apply 3 Corrosion, deal Psychic damage = Corrosion stacks, heal self

| Prayer | Max Charges | Effect | Recharge |
|--------|-------------|--------|----------|
| Du' Eird | 3 | Apply 20 Corrosion to self; if no enemies, deal 300 Psychic self-damage | On entrance (+1) |
| Eiqab | 5 | Deal 200 Psychic to all enemies with Corrosion | On stand still (+1) |
| Muejab | 10 | Deal 25% max Life as Psychic to enemy at any range | On enemy with Corrosion stepping (+1) |

**Survivors-Like Translation**: DoT aura, punishment mechanic for enemy movement

---

### Defensive/Utility Religions

#### Ashem - Grace Stacking
**Theme**: Grace buff stacking

| Stat | Bonus |
|------|-------|
| STR | +1 |
| DEX | +1 |
| WIL | +2 |

**Passive Abilities**:
- On prayer: Apply 3 Grace to yourself
- On being attacked: Apply 1 Grace to yourself

| Prayer | Max Charges | Effect | Recharge |
|--------|-------------|--------|----------|
| Med Vohu | 3 | Heal 200 | On entrance (+1) |
| Yazata | 3 | Deal 100 Astral damage AoE 4 tiles | On recite Med Vohu (+2) |
| Vendi | 1 | Deal 200 Astral damage, repeat per Grace stack | On recite Yazata (+1) |

**Survivors-Like Translation**: Buff stacking for prayer scaling

---

#### Pallas - Shield Combat
**Theme**: Off-hand/shield specialist

| Stat | Bonus |
|------|-------|
| Life | +50 |
| Speed | +2 |
| STR | +2 |
| DEX | +2 |

**Passive Abilities**:
- On attack/block (if single-handing): Deal Pierce damage = 10% Off-hand Hit to 2 enemies
- On picking up shield: Transform to Hoplon

| Prayer | Max Charges | Effect | Recharge |
|--------|-------------|--------|----------|
| Ygeia | 1 | Heal = Block; +50% Block chance if full | On entrance (+1) |
| Doru | 5 | Deal 50 Pierce, repeat per total Weapon Size | On block (+1) |
| Tekton | 15 | Permanently upgrade Off-hand Hit/Block by +30 | On entrance (+1) |

**Survivors-Like Translation**: Shield-specific builds, permanent upgrades

---

#### Dumuzi - Armor Collector
**Theme**: Armor-based scaling, gilded equipment

| Stat | Bonus |
|------|-------|
| Life | +25 |
| WIL | +1 |

**Passive Abilities**:
- On picking up armor (2+ Encumbrance): Transform to Gilded armor
- On entrance: Summon Gilded Dead per known prayer

| Prayer | Max Charges | Effect | Recharge |
|--------|-------------|--------|----------|
| Senheb | 3 | Heal = Armor, remove Corrosion/Doom | On summon Gilded Dead (+1) |
| Sedjhet | 6 | Deal Death damage = Armor AoE 2 tiles | On summon Gilded Dead (+1) |
| Neter Ammah | 6 | Deal Fire damage = 2 x Armor to closest enemy | On summon Gilded Dead (+1) |

**Survivors-Like Translation**: Armor stacking as damage stat

---

### Nature/Life Religions

#### Ninhurs - Divine Grass
**Theme**: Terrain creation, healing on grass

| Stat | Bonus |
|------|-------|
| Life | +50 |
| STR | +1 |

**Passive Abilities**:
- On entrance: Create divine grass path to exit (+50% healing received)
- On summon: Create divine grass in 1 tile range
- On game turn (enemy on grass): Apply 10 Entangle

| Prayer | Max Charges | Effect | Recharge |
|--------|-------------|--------|----------|
| Leget Mhor | 2 | Heal 150, heal allies 150, remove Sickness | On enemy death on grass (+1) |
| Uttuk Alu | 30 | Uses all charges, deal 50 x charges Poison AoE 2 tiles, create grass | On enemy death on grass (+1) |
| Loh Musma | 6 | Summon Musmahu, set Uttuk Alu to 30 charges | On Glory rise (+1) |

**Survivors-Like Translation**: Zone control, terrain synergy

---

#### Yu - Slow Power
**Theme**: Speed limitation, effect amplification

| Stat | Bonus |
|------|-------|
| Life | +100 |
| STR | +4 |
| DEX | +4 |
| WIL | +4 |

**Passive Abilities**:
- Speed limited to 5
- Apply +5 stacks to all effects
- On game turn: Re-apply effects by 10%, apply Refraction = WIL

| Prayer | Max Charges | Effect | Recharge |
|--------|-------------|--------|----------|
| Bahu | 10 | Heal 50, apply 5 Refraction | On game turn without adjacent enemies (+1) |
| Chundu | 2 | Re-apply all self-effects by 50% | On entrance (+1) |
| Gongu | 5 | Deal Poison damage = 2500 + total effect stacks | On kill (+1) |

**Survivors-Like Translation**: Effect/buff stacking to extreme values

---

### Chaos/Teleport Religions

#### Fawdaa - Chaos Teleporter
**Theme**: Random teleportation, Stasis management

| Stat | Bonus |
|------|-------|
| Speed | +4 |
| STR | +1 |
| DEX | +1 |
| WIL | +2 |

**Passive Abilities**:
- On game turn (if enemies live): Teleport to random tile, apply 5 Stasis
- On stand still: Remove Stasis
- On any teleport: Deal random 1-400 Psychic/Death/Poison/Astral damage to enemy at any range

| Prayer | Max Charges | Effect | Recharge |
|--------|-------------|--------|----------|
| Yahrub | 3 | Teleport self and allies randomly, apply 5 Stasis to each | On entrance (+1) |
| Wizara | 10 | Teleport all enemies randomly, apply 5 Stasis to each | On stand still adjacent to enemy (+1) |
| Yamur | 20 | Teleport random enemy adjacent to you | On teleport (+1) |

**Survivors-Like Translation**: Teleport-based damage, positioning chaos

---

### Self-Damage Religions

#### Phoenix - Rebirth Through Fire
**Theme**: Self-damage for power, divine intervention benefits

| Stat | Bonus |
|------|-------|
| None | |

**Passive Abilities**:
- On stand still/prayer (if enemies live), per fully-charged prayer: Deal Fire self-damage = 1% max Life x WIL
- On divine intervention: +1 WIL (once per area), deal 200 Fire AoE

| Prayer | Max Charges | Effect | Recharge |
|--------|-------------|--------|----------|
| Glyad | 10 | Apply Blind = Glory to all enemies | On kill (+1) |
| Goret | 5 | Apply Scorch = Glory to all enemies | On Glory rise (+5) |
| Krasota | 6 | Deal 1000 Fire self-damage; +100% damage if not fully charged | On divine intervention (+1) |

**Survivors-Like Translation**: Intentional divine intervention triggering

---

#### Apophis - Serpent of Destruction
**Theme**: Scaling Strength through self-destruction

| Stat | Bonus |
|------|-------|
| None | |

**Passive Abilities**:
- On entrance: +1 Strength
- On being attacked: Deal 7% max Life Astral self-damage
- Divine intervention restores 50% Life instead of 25%

| Prayer | Max Charges | Effect | Recharge |
|--------|-------------|--------|----------|
| Pha Isfet | 9 | Deal Astral self-damage and AoE = 15 x STR | On enemy death (+1) |
| Pha Hetep | 9 | Remove all harmful effects | On enemy death (+1) |
| Pha Neheb | 9 | Uses all charges, deal Astral self-damage and to all enemies = 30 x STR | On Glory rise (+2) |

**Survivors-Like Translation**: Permanent stat growth, self-damage builds

---

#### Angra - Ally Sacrifice
**Theme**: Ally death for power

| Stat | Bonus |
|------|-------|
| Life | +50 |
| Speed | +3 |
| STR | +1 |
| DEX | +1 |
| WIL | +1 |

**Passive Abilities**:
- On ally attack/being attacked: Ally deals 100% max Life Blood damage to itself

| Prayer | Max Charges | Effect | Recharge |
|--------|-------------|--------|----------|
| Prakara | 50 | Uses all charges, deal Blood+Poison = charges x missing Life AoE 4 tiles | On being attacked by adjacent enemy (+1) |
| Ksudha | 5 | Heal = 20 x Prakara charges | On adjacent enemy death (+1) |
| Rogoga | 3 | Apply Sickness+Bleed = Prakara charges to all enemies | On entrance (+1) |

**Survivors-Like Translation**: Minion suicide bombing, charge accumulation

---

### Item Transformation Religions

#### Oros - Vestige Wearer
**Theme**: Equipment transformation to vestiges/orbs

| Stat | Bonus |
|------|-------|
| None | |

**Passive Abilities**:
- On picking up armor: Transform to Vestige
- On picking up weapon: Transform to Shimmering Orb

| Prayer | Max Charges | Effect | Recharge |
|--------|-------------|--------|----------|
| Oriad | 1 | Heal to full Life | On item transform (+1) |
| Teth Mira | 10 | Summon 3 Tentacles | On Bare Fist attack (+1) |
| Teth Ogra | 1 | Summon 6 Tentacles | On adjacent enemy death (+1) |

**Survivors-Like Translation**: Unarmed combat, tentacle minions

---

#### Mardok - Beast Helm
**Theme**: Encumbrance scaling, beast summons

| Stat | Bonus |
|------|-------|
| Life | +75 |
| STR | +2 |
| DEX | +2 |

**Passive Abilities**:
- Per Encumbrance: +40 Hit, +10 Accuracy
- On picking up head armor: Transform to Helm of Mardok

| Prayer | Max Charges | Effect | Recharge |
|--------|-------------|--------|----------|
| Gula | 20 | Heal self and allies 10% max Life | On adjacent attack (+1) |
| Umam | 5 | Summon Beast of Mardok familiar | On entrance (+1) |
| Nam-Kalag | 2 | Allied familiars gain +50% Hit | On entrance (+1) |

**Survivors-Like Translation**: Heavy armor builds, familiar buffing

---

### Unique Mechanic Religions

#### Eris - Silent Power
**Theme**: Passive power through fully-charged prayers

| Stat | Bonus |
|------|-------|
| None | |

**Passive Abilities**:
- Per fully-charged prayer: +25% Accuracy, +25% Hit, +25% Dodge, +25% Block, +25% Armor
- On tower guardian death: Permanently upgrade Main-hand Hit/Accuracy/Block by +50%

| Prayer | Max Charges | Effect | Recharge |
|--------|-------------|--------|----------|
| Prota | 10 | "Eris is silent..." (no active effect) | On entrance (+1) |
| Defteros | 10 | "Eris is silent..." | On entrance (+1) |
| Tritos | 10 | "Eris is silent..." | On entrance (+1) |

**Survivors-Like Translation**: Passive-only religion, prayer management for buffs

---

#### Takhal - Plague God
**Theme**: Plague spreading, max Life growth

| Stat | Bonus |
|------|-------|
| Life | +75 |
| WIL | +1 |

**Passive Abilities**:
- On being dealt damage: Apply 3 Plague to enemy at any range

| Prayer | Max Charges | Effect | Recharge |
|--------|-------------|--------|----------|
| Enq | 6 | Heal 10 per enemy | On entrance (+2) |
| Cheren | 10 | Gain +20 max Life, deal Death self-damage = 100 x enemies | On item pickup (+1), on ally death (-1) |
| Khairkhan | 3 | Deal 50 Poison self-damage per enemy | On entrance (+1) |

**Survivors-Like Translation**: Enemy count scaling, max Life growth

---

## Design Patterns for Survivors-Like

### Prayer Charge Mechanics
Most valuable for survivors-like:
1. **Auto-recharge triggers** - On kill, on entrance, on damage taken
2. **Charge synergies** - Prayers that interact with each other's charges
3. **Full-charge bonuses** - Passive benefits while prayer is full

### Stat Scaling Categories
Religions scale with different stats:
- **Speed**: Tengri, Hadad
- **Armor**: Dumuzi, Dorok
- **Missing Life**: Dorok, Angra
- **Effect Stacks**: Yu, Mehtar
- **Summon Count**: Formus, Eresh
- **Item Count**: Eresh

### Self-Damage as Resource
Several religions use self-damage as a mechanic:
- Phoenix: Self-damage triggers divine intervention for WIL growth
- Apophis: Self-damage from being attacked, stronger divine intervention
- Angra: Ally self-destruction for charge accumulation

### Transformation Systems
Equipment transformation religions:
- Oros: All gear becomes vestiges/orbs
- Dumuzi: Heavy armor becomes gilded
- Pallas: Shields become hoplons
- Mardok: Head armor becomes helms

---

## Implementation Priority for Survivors-Like

### High Priority (Core Mechanics)
1. **Charge System** - Recharging active abilities
2. **Divine Intervention** - Emergency heal mechanic
3. **Effect Stacking** - Grace, Dream, Drakeform, etc.
4. **Transformation Buffs** - Drakeform, Newtform, etc.

### Medium Priority (Build Diversity)
1. **Self-Damage Builds** - Phoenix, Apophis, Angra
2. **Summoner Scaling** - Formus, Eresh, Ikshana
3. **Armor Scaling** - Dumuzi, Dorok
4. **Speed Scaling** - Tengri, Hadad

### Lower Priority (Advanced)
1. **Terrain Effects** - Ninhurs divine grass
2. **Item Transformation** - Oros, Mardok
3. **Silent Prayers** - Eris passive-only system
4. **Teleport Chaos** - Fawdaa random positioning
