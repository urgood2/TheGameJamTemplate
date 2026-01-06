# Path of Achra: Classes Reference

## Overview

Classes are one of three primary character creation choices in Path of Achra. There are **24 classes**, each with:
- Unique abilities (triggered effects)
- Starting stats (Life, Speed, STR, DEX, WIL)
- Starting equipment (weapons, armor)

---

## Design Patterns

### Stat Distribution Analysis

| Stat | Range | Average | Notes |
|------|-------|---------|-------|
| Life | +25 to +200 | ~85 | Tanks get +150-200, casters get +25-50 |
| Speed | +3 to +10 | ~5.5 | Assassin highest (+10), Warrior lowest (+4) |
| STR | 0 to +5 | ~2 | Melee fighters get +3-5 |
| DEX | 0 to +5 | ~2 | Ranged/agile get +3-5 |
| WIL | 0 to +4 | ~2 | Casters/summoners get +3-4 |

### Ability Trigger Categories

Classes use the following trigger types for their abilities:

| Trigger Type | Classes Using | Example |
|--------------|---------------|---------|
| **On entrance** | Amir, Templar, Zealot, Druid, Apostle, Baghatar | Summoning, applying buffs at level start |
| **On game turn** | Warrior, Gala, Secutor | Passive regeneration/buff application |
| **On attack** | Adbi, Mubarizun, Nartaka, Tengu, Reaver, Cyclops | Extra damage, bonus hits |
| **On kill** | Templar | Stacking buffs on kills |
| **On prayer** | Templar, Adbi, Warlock, Druid, Baghatar, Sorcerer | Prayer-synergy abilities |
| **On stand still** | Ascetic, Unataak, Druid, Gala, Apostle, Sorcerer | Meditation/channeling effects |
| **On step** | Peltast, Mubarizun, Nartaka | Movement-triggered effects |
| **On hit** | Nartaka, Sorcerer | On successful damage |
| **On being attacked** | Aslan, Upuat | Defensive reactions |
| **On block/dodge** | Mubarizun | Counter-attack abilities |
| **On shrug-off** | Reaver | Armor-based retaliation |
| **On Glory rising** | Adbi | Progression-based upgrades |
| **On ally death** | Warlock | Death synergy |
| **On divine intervention** | Apostle | Religion-specific trigger |

---

## Class Archetypes

### Melee Fighters (High STR, Medium-High Life)

#### Warrior
- **Stats**: Life +200, Speed +4, STR +4, DEX +2
- **Equipment**: Spatha, Shield, Bronze Helm, Bronze Chestplate, Bronze Armguards, Bronze Girdle
- **Abilities**:
  - +3 stacks of any Poise applied by you
  - On game turn: Apply 7 Poise to yourself
- **Design Notes**: Tank archetype with passive defense stacking. Good for sustained combat.

#### Reaver
- **Stats**: Life +50, Speed +5, STR +5
- **Equipment**: Axe, Green Crown
- **Abilities**:
  - Per 1% missing Life: +1% Hit total (berserker mechanic)
  - On shrug-off or initial attack, if Two-handing, per empty armor slot: Perform extra attack
- **Design Notes**: Glass cannon berserker. Low armor, high damage scaling with damage taken.

#### Aslan
- **Stats**: Life +150, Speed +4, STR +3, DEX +3, WIL +3
- **Equipment**: Dull-gold Greatsword, Dull-gold Circlet, Dull-gold Mantle, Dull-gold Breechcloth
- **Abilities**:
  - On being attacked: Perform a 50 damage hit against the attacker
  - On prayer, if enemies live: Deal Pierce self-damage (75% of max Life)
- **Design Notes**: Balanced fighter with retribution mechanic. Anti-prayer synergy creates interesting choices.

### Agile Fighters (High DEX, High Speed)

#### Assassin
- **Stats**: Life +50, Speed +10, DEX +5
- **Equipment**: Dagger, Hood, Vest
- **Abilities**:
  - 20% chance to deal +200% physical damage (critical strike)
  - Per point of Dexterity: +20 damage dealt to adjacent enemies
- **Design Notes**: Highest speed class. Critical strike mechanic for burst damage.

#### Mubarizun
- **Stats**: Life +75, Speed +8, STR +2, DEX +3, WIL +1
- **Equipment**: Lance, Iq-Shafra, Hood, Sirwal
- **Abilities**:
  - On step, block or dodge: Perform extra attack against adjacent enemy
  - On attack, if Single-handing: Perform 10 damage hit against adjacent enemy
- **Design Notes**: Mobile duelist. Rewards constant movement and evasion.

#### Peltast
- **Stats**: Life +75, Speed +6, STR +1, DEX +3
- **Equipment**: Javelins, Pelte, Helmet, Skirt
- **Abilities**:
  - On step: Apply Mark to all visible enemies (Mark applied = attack range)
- **Design Notes**: Ranged kiter. Movement triggers debuffs on enemies.

### Summoners (WIL-focused)

#### Amir
- **Stats**: Life +100, Speed +8, STR +2, DEX +2, WIL +2
- **Equipment**: Pilum, Kaffiyeh, Sirwal
- **Abilities**:
  - On entrance: Summon Nomad familiars (1 + Glory/5, max 10)
- **Design Notes**: Army commander. Scales with Glory progression.

#### Druid
- **Stats**: Life +25, Speed +3, STR +1, DEX +1, WIL +2
- **Equipment**: Staff, Bracelets, Sash
- **Abilities**:
  - On entrance: Summon 1 Cobra familiar
  - On prayer: Summon 3 Serpents
  - On stand still, if enemies live: Summon 1 Hatchling
- **Design Notes**: Multiple summon triggers. Diverse minion army.

#### Summoner
- **Stats**: Life +25, Speed +3, WIL +2
- **Equipment**: Scroll, Hood, Robe
- **Abilities**:
  - Allies immune to damage dealt by you
  - Per point of Willpower, summoned allies gain: +10% Life, +10 Hit
- **Design Notes**: Pure summoner. Buffs minions based on WIL.

### Casters/Mystics (WIL-focused, elemental damage)

#### Warlock
- **Stats**: Life +50, Speed +3, WIL +4
- **Equipment**: Staff, Jeweled Wrap, Sash
- **Abilities**:
  - +2 stacks of any Inflame applied by you
  - On prayer or ally death: Apply 3 Inflame to yourself, Deal 100 Fire damage to closest enemy
- **Design Notes**: Fire mage with ally death synergy. Dark magic theme.

#### Nartaka
- **Stats**: Life +50, Speed +7, DEX +4, WIL +1
- **Equipment**: Dastaana, Kamarband
- **Abilities**:
  - On step or hit: Deal Lightning damage to 1 enemy in 4 tile range (Damage = DEX * WIL)
- **Design Notes**: Lightning dancer. Movement + combat triggers ranged damage.

#### Sorcerer
- **Stats**: Life +25, Speed +6, DEX +1, WIL +3
- **Equipment**: Crystal Hand, Pale Mask, Sigil-skirt
- **Abilities**:
  - Dodge, Block, Armor limited to Willpower * 10
  - On prayer, stand still or hit: Deal damage path to enemy at any range (Damage = Glory * 5)
- **Design Notes**: Glass cannon ranged caster. Limited defenses, powerful ranged attacks.

### Priests/Religious (Prayer-focused)

#### Zealot
- **Stats**: Life +200, Speed +4, WIL +1
- **Equipment**: Flail, Hood, Sash
- **Abilities**:
  - On entrance: Grant 3 charges to each known prayer
- **Design Notes**: Prayer specialist. High tank stats for a caster.

#### Templar
- **Stats**: Life +75, Speed +6, STR +2, DEX +2, WIL +2
- **Equipment**: Sherkegar, Brass Visage, Brass Bracers, Brass Greaves
- **Abilities**:
  - On entrance or prayer: Apply 2 Anoint to yourself
  - On kill, if you have Anoint: Apply 3 Anoint to yourself
- **Design Notes**: Holy warrior. Kill-chain buff stacking.

#### Adbi
- **Stats**: Life +75, Speed +5, STR +3, DEX +2, WIL +1
- **Equipment**: Varichakram, Turban, Kachhera
- **Abilities**:
  - On attack, per fully charged prayer: Perform 100 damage hit
  - On Glory rising: Permanently upgrade Main-hand Hit by +20
- **Design Notes**: Prayer-powered attacker. Permanent weapon upgrades.

### Monks/Ascetics (Stand still, special mechanics)

#### Ascetic
- **Stats**: Life +25, Speed +3, WIL +4
- **Equipment**: Asclepa, Robe
- **Abilities**:
  - +1 stacks of any Meditate applied by you
  - On stand still: Apply 4 Meditate to yourself
- **Design Notes**: Meditation specialist. Rewards patience.

#### Unataak
- **Stats**: Life +125, Speed +5, STR +3, WIL +2
- **Equipment**: Tikaani Crook, Yellow Mask, Gilt-cloth Trabea, Gilt-cloth Glove
- **Abilities**:
  - On stand still: Remove random effect from yourself, Perform extra attack, Repeat per Bare Fist
- **Design Notes**: Cleansing monk. Combines unarmed combat with debuff removal.

### Specialists (Unique mechanics)

#### Priest
- **Stats**: Life +50, Speed +3, WIL +3
- **Equipment**: Fire Knife, Vital Crest, Robe
- **Abilities**:
  - Apply +50% stacks of all effects (max +100 stacks)
- **Design Notes**: Effect amplifier. Synergizes with any stack-based build.

#### Myrmidon
- **Stats**: Life +75, Speed +4, STR +2, DEX +2, WIL +2
- **Equipment**: Ivory Lance, Dread Hoplon, White Horns, Ivory Legplates
- **Abilities**:
  - Block doubled against non-adjacent attacks
  - Per 5 DEX: +1 Inflexibility
  - Per Inflexibility: +20% physical damage
- **Design Notes**: Rigid lancer. Trades flexibility for power.

#### Apostle
- **Stats**: Life +100, Speed +3, WIL +4
- **Equipment**: Blade, Mask, Cloth
- **Abilities**:
  - On attack/stand still, if enemies live: Deal 15 Astral self-damage
  - On divine intervention: Heal 600, Deal 1000 Astral damage in 5 tile range
- **Design Notes**: Self-harm for divine power. High risk, high reward.

#### Secutor
- **Stats**: Life +100, Speed +4, STR +1, DEX +2, WIL +2
- **Equipment**: Jade Gladius, Grey Buckler, Grey Helm, Manica, Subligaculum
- **Abilities**:
  - On game turn, if enemies live: Apply random martial effect (stacks = highest attribute)
  - Heal yourself equal to your highest effect stacks
- **Design Notes**: Gladiator with random buffs and sustain.

#### Upuat
- **Stats**: Life +150, Speed +8, STR +3, DEX +2
- **Equipment**: Sling, Painted Loincloth
- **Abilities**:
  - On being attacked, if chest armor empty: Apply 3 Jackalform to yourself
- **Design Notes**: Shapeshifter. Rewards unarmored playstyle.

#### Baghatar
- **Stats**: Life +100, Speed +8, STR +2, DEX +1, WIL +2
- **Equipment**: Kilij, Helm, Bracer, Salaa
- **Abilities**:
  - Deal +5% damage per empty prayer charge
  - On prayer: Apply 3 Gust to yourself
- **Design Notes**: Prayer management. Rewards using prayers strategically.

#### Gala
- **Stats**: Life +25, Speed +3, STR +2, DEX +1, WIL +3
- **Equipment**: Staff, Shield, Cloth
- **Abilities**:
  - On stand still or prayer, if enemies live, per empty armor slot: Heal self and all allies (1% max Life)
  - On game turn, if enemies live: If no War Priest, summon one
- **Design Notes**: Support healer with auto-summoning companion.

---

## Stat Formulas Used

| Formula | Classes | Purpose |
|---------|---------|---------|
| `Damage = DEX * WIL` | Nartaka | Lightning damage scaling |
| `Damage = Glory * 5` | Sorcerer | Progression-based damage |
| `Hit% = 1% per 1% missing Life` | Reaver | Berserker damage scaling |
| `Summons = 1 + Glory/5` | Amir | Scaling summon count |
| `Inflexibility = DEX / 5` | Myrmidon | Stat conversion |
| `Damage = Inflexibility * 20%` | Myrmidon | Damage modifier |

---

## Implementation Notes for Survivors-like Game

### Supported Mechanics (Easy to implement)
- Basic stat bonuses (Life, Speed, STR, DEX, WIL)
- Trigger-based abilities (on attack, on kill, on step, etc.)
- Stack-based buffs (Poise, Meditate, Inflame, etc.)
- Summon mechanics
- Damage type variations (Fire, Lightning, Astral, etc.)

### Requires Custom Implementation
- Prayer system (charge-based abilities)
- Glory/progression system
- Inflexibility/Encumbrance mechanics
- Two-handing/Single-handing conditionals
- Divine intervention triggers
- Equipment slot conditions (empty armor slot)

### Trigger Frequency Observed

| Trigger | Frequency in Classes |
|---------|---------------------|
| On entrance | 7 classes |
| On attack | 6 classes |
| On prayer | 7 classes |
| On stand still | 6 classes |
| On game turn | 3 classes |
| On step | 3 classes |
| On hit | 3 classes |
| On being attacked | 3 classes |
| On kill | 1 class |
| On block/dodge | 1 class |
| On shrug-off | 1 class |
| On Glory rising | 1 class |
| On ally death | 1 class |
| On divine intervention | 1 class |
