# DCSS Combat Mechanics

This guide provides a detailed look at the combat formulas and mechanics in Dungeon Crawl Stone Soup (DCSS).

## Accuracy and Evasion

### Hit Chance
The chance to hit an enemy is determined by your accuracy vs. their evasion.
- **Accuracy Factors**: Weapon skill, Fighting skill, Dexterity, Slaying bonuses, and weapon base accuracy.
- **Evasion (EV)**: The defender's ability to dodge. It is penalized by heavy armor.

### Shields (SH)
Shields provide a chance to block attacks entirely.
- **Block Chance**: Depends on your Shields skill, Dexterity, and the base block value of the shield.

---

## Damage Calculation

### Melee Damage
`Damage = (Base_Damage * Stat_Modifier * Skill_Modifier) + Slaying - AC_Reduction`
- **Base Damage**: The weapon's inherent damage value.
- **Stat Modifier**: Strength increases melee damage.
- **Skill Modifier**: Your weapon skill and Fighting skill increase damage.
- **AC Reduction**: The defender's Armor Class (AC) reduces incoming physical damage.

### Ranged Damage
Similar to melee, but Dexterity often plays a larger role in accuracy and sometimes damage (depending on the weapon type).

---

## Attack Speed (Delay)

Attack speed is measured in "deciturns" (10 deciturns = 1 normal turn).
- **Base Delay**: The weapon's starting speed.
- **Minimum Delay**: The fastest speed a weapon can reach with enough skill.
- **Skill Reduction**: Every 2 levels of weapon skill reduce delay by 0.1 deciturns.

---

## Stabbing

Stabbing is a special mechanic for stealthy characters.
- **Requirements**: The enemy must be unaware, sleeping, confused, or otherwise distracted.
- **Damage**: Stabs deal massive bonus damage, scaling with Stealth and Short Blades skill.

---

## Status Effects in Combat

- **Poison**: Deals damage over time.
- **Confusion**: Causes the victim to move or attack randomly.
- **Paralysis**: Prevents all actions for a few turns.
- **Slow**: Increases the time taken for all actions.
- **Haste**: Decreases the time taken for all actions.
- **Might**: Increases Strength and melee damage.

---

## Resistances

- **Fire/Cold/Electricity Resistance**: Reduces damage from corresponding elemental attacks.
- **Poison Resistance**: Grants immunity to poison damage.
- **Negative Energy Resistance**: Reduces damage from life-draining attacks and torment.
- **Willpower (MR)**: Protects against mental status effects like confusion and paralysis.

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
