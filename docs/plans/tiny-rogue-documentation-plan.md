# Tiny Rogue Documentation Plan

> **Purpose:** Extract and document itemization and progression mechanics from Tiny Rogue as design reference for developing an inspired roguelike.

## Overview

| Aspect | Decision |
|--------|----------|
| **Audience** | Development reference + Claude Code context |
| **Source** | [roguepedia.net](https://roguepedia.net/w/Main_Page) (systematic crawl) |
| **Output Location** | `docs/tiny-rogue/` |
| **Format** | Category markdown files matching existing doc style |
| **Scope** | Representative examples from each category |
| **Granularity** | Mechanical only (no lore/flavor) |
| **Missing Data** | Mark with `???` or `UNKNOWN` |
| **Cross-References** | Inline markdown links |

## Exclusions

- Story/lore content
- Achievements/meta-unlocks
- Cosmetics/skins

## Priority Categories

### 1. Items & Equipment (`items.md`)

**Focus Areas:**
- Upgrade paths (enhancement systems, crafting, material costs)
- Proc/trigger mechanics (on-hit effects, cooldowns, activation conditions)

**Data Points per Item:**
| Field | Description | Required |
|-------|-------------|----------|
| Name | Item name | Yes |
| Category | Weapon/Armor/Consumable/Accessory | Yes |
| Slot | Equipment slot (if applicable) | Yes |
| Base Stats | Primary stat effects | Yes |
| Special Effects | Proc effects, triggers, passives | Yes |
| Upgrade Path | Enhancement options, materials needed | If exists |
| Acquisition | How to obtain (drop, craft, buy) | Yes |
| Synergies | Notable combos with other items/classes | If notable |

**Representative Coverage Target:**
- 3-5 weapons per weapon type (showing stat variance, effect variety)
- 2-3 armor pieces per slot (demonstrating defensive mechanics)
- 5-8 accessories (focusing on build-defining effects)
- Key consumables (healing, buffs, utility)
- Upgrade materials (explaining the enhancement economy)

### 2. Character Progression (`progression.md`)

**Focus Areas:**
- Skill trees/unlocks (ability progressions, talent choices)
- Class differentiation (what makes each class mechanically unique)
- XP/pacing (level curve, stat gains, power gates)

**Data Points:**
| System | Data to Capture |
|--------|-----------------|
| **Level Curve** | XP per level, stat gains per level, milestone unlocks |
| **Classes** | Starting stats, unique abilities, playstyle archetype |
| **Skill Trees** | Structure, branching, respec options |
| **Stat System** | Which stats exist, what they affect, soft/hard caps |

**Representative Coverage Target:**
- All classes (full mechanical breakdown)
- Complete skill tree structure (not every skill, but structure + key examples)
- Full level curve formula/table
- Stat system overview with scaling examples

### 3. Classes (`classes.md`)

**Per-Class Template:**
```markdown
## [Class Name]

**Archetype:** [Melee/Ranged/Hybrid/Support]

### Base Stats
| Stat | Value |
|------|-------|
| HP | ??? |
| Attack | ??? |
| Defense | ??? |
| Speed | ??? |

### Unique Mechanics
- [What makes this class special]

### Skill Progression
| Level | Unlock |
|-------|--------|
| 1 | Starting ability |
| N | Key milestone abilities |

### Playstyle Notes
[Brief insight on intended gameplay loop]

### Notable Synergies
- [Items/builds that work well with this class]
```

## Output File Structure

```
docs/tiny-rogue/
├── README.md              # Overview, links, quick reference
├── items.md               # Equipment, consumables, materials
├── progression.md         # XP, leveling, stat system
├── classes.md             # Class breakdowns
└── design-insights.md     # Brief analysis of notable patterns
```

## Design Insights to Capture (`design-insights.md`)

As extraction proceeds, note observations about:

1. **Item Synergies** - How does TR create emergent build diversity?
   - What combinations feel intentionally designed vs. emergent?
   - How do items reference each other mechanically?

2. **Procedural Variety** - How does TR maintain run freshness?
   - Drop table structure
   - Class-specific item weighting?
   - Progression pacing variance

3. **Balance Philosophy** - What numerical patterns emerge?
   - Damage scaling curves
   - Defensive stat importance
   - Consumable economy

## Extraction Process

### Phase 1: Wiki Structure Discovery
1. Fetch wiki main page
2. Identify navigation structure and category pages
3. Map out all item/class/progression pages to crawl
4. Create extraction queue

### Phase 2: Category Extraction
For each priority category:
1. Fetch category overview page
2. Extract linked entity pages
3. Parse entity data into structured format
4. Mark missing/ambiguous data with `???`
5. Write to category markdown file

### Phase 3: Cross-Reference Pass
1. Review extracted data for relationship patterns
2. Add inline links between related entries
3. Populate synergy/combo sections

### Phase 4: Design Analysis
1. Review complete dataset
2. Note interesting mechanical patterns
3. Write brief insights in `design-insights.md`

## Document Style Guide

Follow existing doc conventions from `docs/content-creation/`:

### Tables
```markdown
| Field | Type | Description |
|-------|------|-------------|
| name | string | Display name |
```

### Entry Format
```markdown
### Item Name

**Type:** Category | **Slot:** Equipment Slot

| Stat | Value |
|------|-------|
| Damage | +15 |

**Special Effect:** [Natural language description of mechanics]

**Upgrade Path:** Material A (x3) + Gold (500) → Enhanced version

**Notes:** [Brief insight if notable]
```

### Cross-References
```markdown
Synergizes well with [Warrior](classes.md#warrior) due to...
Requires [Fire Essence](items.md#fire-essence) to upgrade.
```

### Unknown Data
```markdown
| Defense | ??? |
**Acquisition:** UNKNOWN - not documented on wiki
```

## Success Criteria

- [ ] All wiki item categories mapped
- [ ] Representative items documented per category
- [ ] All classes fully documented
- [ ] Progression system (XP, stats) captured
- [ ] Cross-references added where relationships exist
- [ ] Design insights document captures 3+ notable patterns
- [ ] Documentation readable without wiki access

## Implementation Notes

- Use `WebFetch` for wiki page extraction
- Parse HTML to markdown, extracting tabular data where present
- Wiki may have inconsistent formatting - normalize during extraction
- If wiki has rate limiting, pace requests appropriately
- Prioritize pages with most mechanical content over stub pages
