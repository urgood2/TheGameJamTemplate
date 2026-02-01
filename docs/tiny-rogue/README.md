# Tiny Rogues Design Reference

> Design documentation extracted from [Tiny Rogues](https://store.steampowered.com/app/2088570/Tiny_Rogues/) via [Roguepedia Wiki](https://roguepedia.net/w/Main_Page) for reference in developing an inspired roguelike game.

---

## Quick Navigation

| Document | Content | Status |
|----------|---------|--------|
| [Items](items.md) | Weapons, armor, accessories, consumables, rarity system | Complete |
| [Progression](progression.md) | Leveling, stats, traits, world tiers, mastery perks | Complete |
| [Classes](classes.md) | All 34 classes with stats, abilities, unlock conditions | Complete |
| [Design Insights](design-insights.md) | Analysis of 5 notable design patterns | Complete |

---

## Document Summaries

### Items (`items.md`)

**Coverage**: 400 weapons, 467 armor pieces, 109 accessories, 73 charms, 122 companions

Key topics:
- Weapon categories (Melee/Ranged/Magic) and stat scaling (STR/DEX/INT)
- Scaling grades (S/A/B/C/D) with soft caps
- Equipment rarity system (Common → Legendary → Set)
- Attunement mechanics (equipment activation delay)
- Upgrade paths and legendary evolution

### Progression (`progression.md`)

**Coverage**: Complete per-run and meta-progression systems

Key topics:
- Level curve (max 6 per run, food-based XP)
- Food system (12 regular + 10 golden foods with stat bonuses)
- 137+ traits across stat categories
- Stat system (core/defensive/offensive/resource)
- Soft caps and diminishing returns
- World Tier progression (8 tiers)
- Mastery Perks (30 points, 4 branches)
- Alignment system (Good/Evil, Lawful/Chaotic)

### Classes (`classes.md`)

**Coverage**: All 34 playable classes

Per-class documentation:
- Base stats table (HP, Armor, Mana, Stamina, STR, DEX, INT, Crit%, CritX, Speed)
- Unique innate ability/mechanic
- Starting equipment
- Unlock conditions

Organization:
- Roster 1: 17 starting classes
- Roster 2: 17 advanced classes (throne/guardian unlocks)
- Special: 1 seasonal class (Santa)

### Design Insights (`design-insights.md`)

**Coverage**: 5 notable design patterns with analysis

Patterns documented:
1. Build diversity through multiplicative systems
2. Commitment mechanics preventing optimization paralysis
3. Layered progression (within-run / meta / endgame)
4. Class design as build constraint system
5. Risk-reward tension in resource systems

---

## Scope & Exclusions

### Included

- All mechanical systems (stats, scaling, progression)
- Equipment categories with representative examples
- Class breakdowns with full stat tables
- Unlock progression paths
- Design pattern analysis

### Excluded (per plan)

- Story/lore content
- Achievements/meta-unlocks
- Cosmetics/skins
- Detailed individual item stats (representative examples only)

---

## Data Quality Notes

| Category | Completeness | Notes |
|----------|--------------|-------|
| Classes | Complete | All 34 classes with full stats |
| Progression | Complete | All systems documented |
| Items | Partial | Categories complete, individual items summarized |
| Charms | Incomplete | Count accurate, effects need expansion |
| Companions | Incomplete | Types listed, individual entries needed |

Unknown/missing data is marked with `???` or `UNKNOWN` throughout.

---

## Cross-Reference Guide

| If you're looking for... | See... |
|--------------------------|--------|
| Weapon damage scaling | [Items > Stat Scaling System](items.md#stat-scaling-system) |
| Stat soft caps | [Progression > Soft & Hard Caps](progression.md#soft--hard-caps) |
| Class stat priorities | [Classes > Base Stats](classes.md) (per-class sections) |
| Food stat bonuses | [Progression > Food System](progression.md#food-system-floors-1-10) |
| Equipment rarity | [Items > Equipment Rarity System](items.md#equipment-rarity-system) |
| Trait categories | [Progression > Trait System](progression.md#trait-system) |
| Unlock requirements | [Classes > Unlock Progression Paths](classes.md#unlock-progression-paths) |
| Design patterns | [Design Insights](design-insights.md) |

---

## Source

All data extracted from [Roguepedia.net](https://roguepedia.net/w/Main_Page), the community wiki for Tiny Rogues.

**Extraction Date**: 2026-01-08  
**Game Version**: Early Access (version current as of extraction date)

---

## Usage

This documentation is for **design reference only**. Use it to:
- Understand Tiny Rogues' mechanical design choices
- Extract patterns applicable to similar projects
- Reference specific numbers when designing comparable systems

**Do not**: Copy content verbatim for commercial use without proper licensing.

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
