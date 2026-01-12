# DCSS Magic System & Spells Guide

This guide provides a comprehensive overview of the magic system in Dungeon Crawl Stone Soup (DCSS), including spell schools, mechanics, and spell lists.

## Magic System Overview

Magic in DCSS is powered by Magic Points (MP) and governed by several skills. To cast a spell, you must learn it from a spellbook, have enough MP, and succeed in a casting check.

### Key Mechanics
- **Spell Power**: Determines the effectiveness (damage, duration, etc.) of a spell. It scales with your skill levels and Intelligence.
- **Success Rate**: The chance to successfully cast a spell. It depends on your Spellcasting skill, specific school skills, Intelligence, and the encumbrance of your armor.
- **Spell Levels**: Each spell has a level (1-9). Higher-level spells cost more MP and are harder to cast.
- **Spell Slots**: You have a limited number of spell slots based on your Spellcasting skill.

---

## Spell Schools

### Conjurations
The school of raw magical force and destructive energy.
- **Philosophy**: Direct damage and offensive power.
- **Key Spells**: Magic Dart (L1), Searing Ray (L2), Fulminant Prism (L4), Orb of Destruction (L7).

### Fire Magic
The school of heat and combustion.
- **Philosophy**: High damage, area of effect, and lingering fire.
- **Key Spells**: Foxfire (L1), Fireball (L5), Ignition (L8), Fire Storm (L9).

### Ice Magic
The school of cold and freezing.
- **Philosophy**: Control, slowing enemies, and defensive buffs.
- **Key Spells**: Freeze (L1), Frozen Ramparts (L3), Ozocubu's Armour (L3), Polar Vortex (L9).

### Air Magic
The school of wind and electricity.
- **Philosophy**: Speed, mobility, and chain-lightning effects.
- **Key Spells**: Shock (L1), Swiftness (L3), Airstrike (L4), Chain Lightning (L9).

### Earth Magic
The school of stone and physical matter.
- **Philosophy**: Physical damage, terrain manipulation, and high AC penetration.
- **Key Spells**: Sandblast (L1), Stone Arrow (L3), Lee's Rapid Deconstruction (L5), Shatter (L9).

### Poison Magic (Historical/Alchemy)
The school of toxins and debilitation.
- **Philosophy**: Damage over time and status effects.
- **Key Spells**: Sting (L1), Mephitic Cloud (L3), Olgreb's Toxic Radiance (L4).
- *Note: In recent versions, Poison Magic has been integrated into the Alchemy school.*

### Necromancy
The school of death and the undead.
- **Philosophy**: Raising allies, draining life, and unholy power.
- **Key Spells**: Animate Dead (L4), Borgnjor's Vile Clutch (L5), Haunt (L7), Death's Door (L9).

### Summonings
The school of calling creatures from other planes.
- **Philosophy**: Creating allies to fight for you.
- **Key Spells**: Summon Small Mammal (L1), Call Canine Familiar (L3), Summon Mana Viper (L5), Dragon's Call (L9).

### Translocations
The school of space and movement.
- **Philosophy**: Repositioning, escape, and battlefield control.
- **Key Spells**: Blink (L2), Passage of Golubria (L4), Manifold Assault (L7).

### Hexes
The school of mental manipulation and debilitation.
- **Philosophy**: Disabling enemies and status effects.
- **Key Spells**: Slow (L1), Ensorcelled Hibernation (L2), Confusing Touch (L3), Discord (L8).

### Alchemy
The school of chemical reactions and transformations.
- **Philosophy**: Combining elements for various effects (replaces Transmutations and Poison Magic in newer versions).
- **Key Spells**: Petrify (L4), Irradiate (L5).

---

## Spell Power and Formulas

### Raw Spell Power
Raw power is calculated based on:
`Raw Power = (Skill_Average + Spellcasting/2) * Enhancers * (Intelligence / 10)`

### Spell Success
Success rate is determined by:
`Success = 100% - (Difficulty - (Casting_Skill * 2 + Intelligence))`
(Simplified; actual formula involves step-downs and armor penalties).

---

## Magical Items

### Spellbooks
The primary source of spells. You must read a book to learn the spells within.

### Magical Staves
Enhance the power of specific schools (e.g., Staff of Fire, Staff of Earth). They also serve as effective melee weapons that scale with Evocations.

### Wands
Allow the use of magical effects without spending MP or knowing spells. Power scales with the Evocations skill.

---

## Anti-Magic Mechanics

- **Willpower (MR)**: Protects against mental attacks and hexes.
- **Silence**: Prevents all spellcasting in an area.
- **Antimagic Brand**: Weapons that drain MP and increase spell failure on hit.
- **Elemental Resistances**: Reduce damage from Fire, Cold, Electricity, etc.
